import firebase_admin
from firebase_admin import credentials, firestore
import vertexai
from vertexai.language_models import TextEmbeddingModel
import requests
import re
import time

# --- CONFIGURATION ---
# URL des règles officielles (Format Texte) - Mise à jour régulièrement par WotC
RULES_URL = "https://media.wizards.com/2024/downloads/MagicCompRules%2020240802.txt"
PROJECT_ID = "magic-companion-rag"  # Remplacez par votre ID de projet si différent
LOCATION = "us-central1"

def init_services():
    print("🔌 Connexion à Firebase & Vertex AI...")
    # Utilise vos identifiants locaux (générés via 'firebase login')
    try:
        app = firebase_admin.initialize_app()
    except ValueError:
        app = firebase_admin.get_app()
    
    db = firestore.client()
    vertexai.init(project=PROJECT_ID, location=LOCATION)
    return db

def download_rules():
    print(f"📥 Téléchargement des règles depuis {RULES_URL}...")
    response = requests.get(RULES_URL)
    response.encoding = 'utf-8' # Force l'encodage correct
    return response.text

def parse_rules(text):
    print("✂️ Découpage des règles...")
    # Regex pour capturer les règles du type "100.1. Texte..."
    # On ignore les sommaires et les glossaires pour ce POC
    rule_pattern = re.compile(r'^(\d{3}\.\d+[a-z]?)\.?\s+(.+)$', re.MULTILINE)
    
    chunks = []
    matches = rule_pattern.findall(text)
    
    for rule_number, rule_text in matches:
        # On garde des morceaux de taille raisonnable
        content = f"Règle {rule_number}: {rule_text.strip()}"
        chunks.append({
            "id": rule_number,
            "content": content
        })
    
    print(f"✅ {len(chunks)} règles extraites.")
    return chunks

def generate_embeddings(chunks, model):
    print("🧠 Génération des vecteurs (Batching)...")
    # Vertex AI accepte des batchs (max 5 pour text-embedding-004 par appel pour éviter les quotas)
    BATCH_SIZE = 5
    embedded_chunks = []
    
    for i in range(0, len(chunks), BATCH_SIZE):
        batch = chunks[i:i+BATCH_SIZE]
        texts = [c["content"] for c in batch]
        
        try:
            embeddings = model.get_embeddings(texts)
            for j, embedding in enumerate(embeddings):
                batch[j]["embedding"] = embedding.values
            embedded_chunks.extend(batch)
            print(f"   Traité {i + len(batch)} / {len(chunks)}", end='\r')
            time.sleep(0.1) # Petite pause pour ménager l'API
        except Exception as e:
            print(f"\n❌ Erreur sur le batch {i}: {e}")
            
    print("\n✅ Vectorisation terminée.")
    return embedded_chunks

def upload_to_firestore(db, data):
    print("☁️ Envoi vers Firestore...")
    batch = db.batch()
    collection = db.collection("magic_rules")
    count = 0
    total = len(data)

    for item in data:
        doc_ref = collection.document(item["id"])
        # Firestore Vector Search requiert que le champ soit un VectorValue
        # Le SDK Python gère souvent la liste float directement, mais soyons précis
        batch.set(doc_ref, {
            "content": item["content"],
            "embedding": item["embedding"] # Firestore accepte Array<Float> comme vecteur
        })
        count += 1
        
        # Firestore batch limit is 500
        if count % 50 == 0: 
            batch.commit()
            batch = db.batch()
            print(f"   Envoyé {count} / {total}", end='\r')
            
    batch.commit()
    print(f"\n✅ Terminé ! {total} documents indexés.")

def main():
    db = init_services()
    raw_text = download_rules()
    
    # 1. On récupère TOUTES les règles (plus de limite [:200])
    chunks = parse_rules(raw_text) 
    
    print(f"🚀 Démarrage de l'ingestion de {len(chunks)} règles...")
    
    # 2. On utilise le modèle Vertex AI
    embedding_model = TextEmbeddingModel.from_pretrained("text-embedding-004")
    
    # 3. Vectorisation (Attention : cela peut prendre 5-10 minutes et coûter quelques centimes)
    vector_data = generate_embeddings(chunks, embedding_model)
    
    # 4. Envoi par paquets de 50 pour éviter l'erreur "Transaction too big"
    upload_to_firestore(db, vector_data)
    
    print("\n🎉 BASE DE CONNAISSANCE COMPLÈTE À JOUR !")

if __name__ == "__main__":
    main()