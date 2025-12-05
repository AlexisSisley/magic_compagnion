import os
import glob
import shutil
from typing import List
from langchain_community.document_loaders import TextLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter, Language
from langchain_ollama import OllamaEmbeddings 
from langchain_chroma import Chroma
from langchain_core.documents import Document

# Configuration
FLUTTER_PROJECT_PATH = "../" 
DB_PATH = "./chroma_db" 

def load_flutter_files(path: str) -> List[Document]:
    documents = []
    # On inclut les fichiers Dart, YAML (pubspec) et Markdown (README)
    patterns = ["lib/**/*.dart", "pubspec.yaml", "*.md"]
    all_files = []
    for pattern in patterns:
        all_files.extend(glob.glob(os.path.join(path, pattern), recursive=True))
    
    print(f"🔍 {len(all_files)} fichiers trouvés...")

    for file_path in all_files:
        # On ignore les fichiers générés
        if ".g.dart" in file_path or ".freezed.dart" in file_path:
            continue
            
        try:
            loader = TextLoader(file_path, encoding='utf-8')
            docs = loader.load()
            for doc in docs:
                # On stocke le chemin relatif pour que l'IA puisse citer le fichier
                relative_path = os.path.relpath(file_path, path)
                doc.metadata["source"] = relative_path
                documents.append(doc)
        except Exception as e:
            print(f"⚠️ Ignoré {file_path}: {e}")

    print(f"✅ {len(documents)} fichiers chargés.")
    return documents

def save_to_chroma(chunks: List[Document]):
    print("💾 Génération des VRAIS Embeddings avec Ollama (nomic-embed-text)...")
    
    # 1. Nettoyage : On supprime l'ancienne base Fake pour éviter les conflits
    if os.path.exists(DB_PATH):
        try:
            shutil.rmtree(DB_PATH)
            print("  (Ancienne base supprimée)")
        except Exception as e:
            print(f"  (Attention: impossible de supprimer l'ancienne DB: {e})")

    # 2. Création de la nouvelle base
    embeddings = OllamaEmbeddings(model="nomic-embed-text")
    
    db = Chroma.from_documents(
        documents=chunks, 
        embedding=embeddings, 
        persist_directory=DB_PATH
    )
    print(f"🚀 Indexation terminée ! Base sauvegardée dans {DB_PATH}")

if __name__ == "__main__":
    print("--- Démarrage de l'ingestion (Mode Ollama) ---")
    docs = load_flutter_files(FLUTTER_PROJECT_PATH)
    if docs:
        # Découpage intelligent du code
        splitter = RecursiveCharacterTextSplitter.from_language(
            language=Language.JAVA, # Syntaxe proche du Dart
            chunk_size=1000, 
            chunk_overlap=200
        )
        chunks = splitter.split_documents(docs)
        print(f"✂️  Code découpé en {len(chunks)} morceaux.")
        
        save_to_chroma(chunks)