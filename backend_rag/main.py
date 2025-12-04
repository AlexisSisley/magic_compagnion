import os
import random
from typing import List
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# LangChain imports
from langchain_chroma import Chroma
from langchain_core.embeddings import Embeddings

# --- 1. MÊME CLASSE DE SIMULATION QUE L'INGESTION ---
# Il est CRUCIAL d'utiliser la même logique d'embedding
class FakeEmbeddings(Embeddings):
    def __init__(self, size: int = 384):
        self.size = size
    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        return [[random.random() for _ in range(self.size)] for _ in texts]
    def embed_query(self, text: str) -> List[float]:
        return [random.random() for _ in range(self.size)]

# --- 2. SETUP APP ---
app = FastAPI()
DB_PATH = "./chroma_db"

# Chargement de la base vectorielle existante
db = Chroma(
    persist_directory=DB_PATH, 
    embedding_function=FakeEmbeddings()
)

# Modèle de données pour la requête (ce que Flutter va envoyer)
class QueryRequest(BaseModel):
    query: str

# --- 3. ENDPOINT CHAT ---
@app.post("/chat")
async def chat_endpoint(request: QueryRequest):
    print(f"📩 Question reçue : {request.query}")
    
    # 1. Recherche (Simulation : renverra des morceaux aléatoires)
    # k=3 signifie qu'on récupère les 3 morceaux de code les plus "proches"
    results = db.similarity_search(request.query, k=3)
    
    # 2. Construction du contexte (le code trouvé)
    context_text = ""
    for doc in results:
        source = doc.metadata.get("source", "inconnu")
        context_text += f"--- Fichier: {source} ---\n{doc.page_content}\n\n"

    # 3. Génération de réponse (Simulation LLM)
    # Normalement ici on envoie `context_text` + `query` à GPT/Ollama.
    # Pour le POC offline, on renvoie une fausse réponse explicative.
    
    fake_response = (
        f"🤖 **Réponse Simulée (Mode Offline)**\n\n"
        f"J'ai analysé votre code pour répondre à : *{request.query}*\n\n"
        f"Voici les fichiers qui semblent pertinents (trouvés aléatoirement pour le test) :\n"
        f"{context_text[:500]}...\n\n" # On coupe pour pas inonder la console
        f"*(Note : Une fois chez toi avec Ollama, cette réponse sera générée intelligemment par l'IA)*"
    )

    return {
        "response": fake_response,
        "sources": [doc.metadata.get("source") for doc in results]
    }

# --- 4. LANCEMENT ---
if __name__ == "__main__":
    import uvicorn
    # Ecoute sur 0.0.0.0 pour être accessible par l'émulateur Android
    uvicorn.run(app, host="0.0.0.0", port=8000)