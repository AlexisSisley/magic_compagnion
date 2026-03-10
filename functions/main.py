from firebase_functions import https_fn
from firebase_admin import initialize_app, firestore
import requests  # Pour appeler Scryfall
import anthropic
import os

app = initialize_app()
db = None

def get_card_text(query):
    """
    Tente de trouver une carte Magic mentionnée dans la question via Scryfall.
    """
    # On nettoie un peu la requête pour aider la recherche floue
    clean_query = query.replace("?", "").replace(".", "").strip()
    
    # Appel API Scryfall (Recherche floue/intelligente)
    url = f"https://api.scryfall.com/cards/named?fuzzy={clean_query}"
    
    try:
        response = requests.get(url, timeout=2)
        if response.status_code == 200:
            card = response.json()
            name = card.get('name')
            
            # Gestion des faces multiples
            if 'card_faces' in card:
                text = "\n//\n".join([f"{f.get('name')}: {f.get('oracle_text')}" for f in card['card_faces']])
            else:
                text = card.get('oracle_text', '')
                
            type_line = card.get('type_line', '')
            return f"CARTE TROUVÉE : {name}\nTYPE : {type_line}\nTEXTE : {text}"
    except Exception:
        pass # Si on ne trouve pas ou erreur réseau, on ignore silencieusement
    
    return None

@https_fn.on_call()
def ask_oracle(req: https_fn.CallableRequest) -> any:
    global db
    
    import vertexai
    from vertexai.language_models import TextEmbeddingModel

    # Import robuste de DistanceMeasure
    try:
        from google.cloud.firestore import DistanceMeasure
    except ImportError:
        try:
            from google.cloud.firestore_v1.vector import DistanceMeasure
        except ImportError:
            from google.cloud.firestore_v1.base_vector_query import DistanceMeasure

    query_text = req.data.get("query")
    
    if not query_text:
        return {"response": "Le mana est faible..."}

    try:
        if db is None:
            db = firestore.client()

        vertexai.init(location="us-central1")
        embedding_model = TextEmbeddingModel.from_pretrained("text-embedding-004")

        # --- ÉTAPE 1 : RECHERCHE DE CARTE (NOUVEAU) ---
        # On regarde si Scryfall connaît une carte qui porte le nom de la recherche
        # (Ou un mot clé important de la phrase)
        card_context = get_card_text(query_text)
        
        # --- ÉTAPE 2 : RECHERCHE DE RÈGLES (VECTORIELLE) ---
        embeddings = embedding_model.get_embeddings([query_text])
        query_vector = embeddings[0].values

        collection = db.collection("magic_rules")
        vector_query = collection.find_nearest(
            vector_field="embedding",
            query_vector=query_vector,
            distance_measure=DistanceMeasure.COSINE,
            limit=5
        )
        docs = vector_query.get()
        rules_context = "\n".join([f"- {doc.to_dict().get('content', '')}" for doc in docs])

        # --- ÉTAPE 3 : ASSEMBLAGE DU PROMPT ---
        final_context = f"RÈGLES OFFICIELLES :\n{rules_context}"
        
        if card_context:
            final_context += f"\n\nCONTEXTE CARTE IDENTIFIÉE :\n{card_context}"

        # --- ÉTAPE 4 : GÉNÉRATION VIA CLAUDE ---
        client = anthropic.Anthropic()

        system_prompt = (
            "Tu es l'Oracle de Magic: The Gathering. "
            "Réponds aux questions des joueurs en te basant sur le contexte fourni (règles officielles et cartes). "
            "Si une carte est identifiée dans le contexte, explique son interaction précise avec les règles citées. "
            "Sois précis et concis."
        )

        user_prompt = f"""CONTEXTE :
{final_context}

QUESTION JOUEUR :
{query_text}"""

        message = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=system_prompt,
            messages=[{"role": "user", "content": user_prompt}],
        )
        return {"response": message.content[0].text}

    except Exception as e:
        print(f"Erreur: {e}")
        return {"response": "Erreur interne de l'Oracle."}