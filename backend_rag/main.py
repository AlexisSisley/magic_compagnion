from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from langchain_chroma import Chroma
from langchain_ollama import OllamaEmbeddings, ChatOllama
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnablePassthrough

app = FastAPI()
DB_PATH = "./chroma_db"

print("🔥 Démarrage du serveur RAG...")

# 1. Configuration des composants IA
try:
    embeddings = OllamaEmbeddings(model="nomic-embed-text")
    db = Chroma(persist_directory=DB_PATH, embedding_function=embeddings)
    
    # Le Retriver va chercher les 5 morceaux de code les plus pertinents
    retriever = db.as_retriever(search_kwargs={"k": 5})
    
    # Le LLM (Cerveau)
    llm = ChatOllama(model="mistral")
except Exception as e:
    print(f"❌ Erreur critique au chargement de l'IA: {e}")
    raise e

# 2. Le Prompt (Les instructions données à l'IA)
template = """
Tu es un expert senior en développement Flutter (Dart).
Utilise les extraits de code ci-dessous (CONTEXTE) pour répondre à la question de l'utilisateur.

Si la réponse se trouve dans le code fourni, explique-la en citant les fichiers.
Si la réponse ne se trouve PAS dans le code, dis "Je ne trouve pas cette info dans le code fourni" mais essaie de répondre avec tes connaissances générales de Flutter.

CONTEXTE (Code source de l'app):
{context}

QUESTION:
{question}
"""
prompt = ChatPromptTemplate.from_template(template)

# 3. La Pipeline RAG (Chaîne de traitement)
def format_docs(docs):
    return "\n\n".join(f"--- FICHIER: {doc.metadata.get('source', 'Inconnu')} ---\n{doc.page_content}" for doc in docs)

rag_chain = (
    {"context": retriever | format_docs, "question": RunnablePassthrough()}
    | prompt
    | llm
)

class QueryRequest(BaseModel):
    query: str

@app.post("/chat")
async def chat_endpoint(request: QueryRequest):
    print(f"📩 Question reçue : {request.query}")
    
    try:
        # On invoque la chaîne. Cela peut prendre quelques secondes (selon ton GPU/CPU)
        response_message = rag_chain.invoke(request.query)
        
        # LangChain retourne un objet AIMessage, on veut juste le contenu texte
        response_text = response_message.content if hasattr(response_message, 'content') else str(response_message)
        
        return {"response": response_text}
    except Exception as e:
        print(f"❌ Erreur pendant la génération: {e}")
        return {"response": "Désolé, une erreur est survenue lors de l'analyse."}

if __name__ == "__main__":
    import uvicorn
    # Écoute sur 0.0.0.0 pour être accessible depuis le mobile
    uvicorn.run(app, host="0.0.0.0", port=8000)