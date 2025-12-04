import os
import glob
import random
from typing import List

# LangChain imports
from langchain_community.document_loaders import TextLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter, Language
from langchain_chroma import Chroma
from langchain_core.documents import Document
from langchain_core.embeddings import Embeddings

# --- 1. CLASSE DE SIMULATION (MOCK) ---
class FakeEmbeddings(Embeddings):
    """Génère des vecteurs aléatoires pour contourner le proxy/firewall."""
    def __init__(self, size: int = 384):
        self.size = size

    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        # Simule un vecteur pour chaque document
        return [[random.random() for _ in range(self.size)] for _ in texts]

    def embed_query(self, text: str) -> List[float]:
        # Simule un vecteur pour la question
        return [random.random() for _ in range(self.size)]

# --- 2. CONFIGURATION ---
FLUTTER_PROJECT_PATH = "../" 
DB_PATH = "./chroma_db" 

def load_flutter_files(path: str) -> List[Document]:
    documents = []
    dart_files = glob.glob(os.path.join(path, "lib/**/*.dart"), recursive=True)
    yaml_files = glob.glob(os.path.join(path, "pubspec.yaml"), recursive=False)
    all_files = dart_files + yaml_files
    
    print(f"🔍 {len(all_files)} fichiers trouvés...")

    for file_path in all_files:
        if ".g.dart" in file_path or ".freezed.dart" in file_path:
            continue
            
        try:
            loader = TextLoader(file_path, encoding='utf-8')
            docs = loader.load()
            for doc in docs:
                doc.metadata["source"] = file_path
                documents.append(doc)
        except Exception as e:
            pass # On ignore silencieusement les erreurs pour aller vite

    print(f"✅ {len(documents)} fichiers chargés.")
    return documents

def split_documents(documents: List[Document]) -> List[Document]:
    # On utilise JAVA car la syntaxe est proche de Dart
    splitter = RecursiveCharacterTextSplitter.from_language(
        language=Language.JAVA, 
        chunk_size=1000,
        chunk_overlap=200
    )
    chunks = splitter.split_documents(documents)
    print(f"✂️ Code découpé en {len(chunks)} chunks.")
    return chunks

def save_to_chroma(chunks: List[Document]):
    print("💾 Génération des Fake Embeddings (Simulation)...")
    
    # UTILISATION DU MOCK ICI
    embeddings = FakeEmbeddings(size=384)
    
    # On force la suppression de l'ancienne DB si elle existe pour éviter les conflits de dimension
    if os.path.exists(DB_PATH):
        import shutil
        try:
            shutil.rmtree(DB_PATH)
            print("  (Ancienne DB supprimée)")
        except:
            pass

    db = Chroma.from_documents(
        documents=chunks, 
        embedding=embeddings, 
        persist_directory=DB_PATH
    )
    
    print(f"🚀 Terminé ! Base de données (Simulée) créée dans {DB_PATH}")

if __name__ == "__main__":
    print("--- Ingestion Locale (Mode Simulation / Offline) ---")
    docs = load_flutter_files(FLUTTER_PROJECT_PATH)
    if docs:
        chunks = split_documents(docs)
        save_to_chroma(chunks)