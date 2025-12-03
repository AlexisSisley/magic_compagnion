from firebase_functions import https_fn
from firebase_admin import initialize_app, firestore

# On initialise Firebase Admin au niveau global
app = initialize_app()
db = None

@https_fn.on_call()
def ask_oracle(req: https_fn.CallableRequest) -> any:
    """
    Fonction Oracle RAG : Répond aux questions sur Magic en utilisant Firestore Vector Search + Gemini.
    """
    global db
    
    # --- IMPORTS DIFFÉRÉS (LAZY LOADING) ---
    # On importe tout ici pour éviter les crashs au déploiement
    import vertexai
    from vertexai.language_models import TextEmbeddingModel
    from vertexai.generative_models import GenerativeModel
    
    # --- CORRECTION IMPORT ROBUSTE ---
    # On cherche DistanceMeasure à plusieurs endroits pour être sûr de le trouver
    try:
        # Essai 1 : Racine (Standard)
        from google.cloud.firestore import DistanceMeasure
    except ImportError:
        try:
            # Essai 2 : Sous-module Vector (Versions récentes)
            from google.cloud.firestore_v1.vector import DistanceMeasure
        except ImportError:
            # Essai 3 : Base (Interne)
            from google.cloud.firestore_v1.base_vector_query import DistanceMeasure

    query_text = req.data.get("query")
    
    if not query_text:
        return {"response": "Le mana est faible... Pose une vraie question."}

    try:
        # Initialisation DB si pas encore fait (Cold Start)
        if db is None:
            db = firestore.client()

        # Initialisation Vertex AI
        vertexai.init(location="us-central1")
        
        # Chargement des modèles
        embedding_model = TextEmbeddingModel.from_pretrained("text-embedding-004")
        gen_model = GenerativeModel("gemini-1.5-flash")

        # 1. Vectorisation de la question (Embedding)
        embeddings = embedding_model.get_embeddings([query_text])
        query_vector = embeddings[0].values

        # 2. Recherche Vectorielle (RAG) dans Firestore
        collection = db.collection("magic_rules")
        
        vector_query = collection.find_nearest(
            vector_field="embedding",
            query_vector=query_vector,
            distance_measure=DistanceMeasure.COSINE,
            limit=5
        )
        
        docs = vector_query.get()
        
        if not docs:
            return {"response": "Je ne trouve rien dans les archives à ce sujet."}

        # Assemblage du contexte
        context_text = "\n\n".join([f"- {doc.to_dict().get('content', '')}" for doc in docs])

        # 3. Prompt pour Gemini
        prompt = f"""
        Tu es l'Oracle de Magic: The Gathering.
        Utilise UNIQUEMENT le contexte ci-dessous pour répondre à la question du joueur.
        Si la réponse n'est pas dans le contexte, dis que tu ne sais pas.
        Cite les numéros de règles si possible.

        CONTEXTE :
        {context_text}

        QUESTION :
        {query_text}
        """

        # 4. Génération
        response = gen_model.generate_content(prompt)
        
        return {"response": response.text}

    except Exception as e:
        print(f"Erreur Oracle: {e}")
        return {"response": f"Une perturbation dans l'éther m'empêche de répondre. ({str(e)})"}