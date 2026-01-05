import os
import yaml
import requests
import json
import re

# Configuration
OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "qwen2.5-coder:7b" 

def clean_yaml_output(text):
    """Tentative de nettoyage basique pour les erreurs courantes"""
    # Enlever les blocs markdown
    text = text.replace("```yaml", "").replace("```", "").strip()
    return text

def generate_documentation():
    print(f"🚀 Démarrage de la Rétro-Documentation V2 (Mode Local : {MODEL_NAME})...")

    try:
        with open("repomix-output.xml", "r", encoding="utf-8") as f:
            code_context = f.read()
    except FileNotFoundError:
        print("❌ Erreur : 'repomix-output.xml' introuvable.")
        exit(1)

    # PROMPT RENFORCÉ POUR LE YAML
    prompt = f"""
    [ROLE]
    Tu es un architecte logiciel expert en Flutter.
    
    [CONTEXTE]
    Voici le code source d'une application (format XML compacté) :
    {code_context}
    
    [MISSION]
    Analyse ce code et génère une documentation architecturale au format YAML strict.
    
    [FORMAT ATTENDU]
    project_name: "Nom du projet"
    architecture:
      state_management: "ex: Riverpod"
      services: ["Service1", "Service2"]
    domain_models:
      - name: "NomClasse"
        desc: "Description courte"
    security_hotspots:
      - "Point de vigilance"

    [RÈGLES CRITIQUES DE SYNTAXE]
    1. Réponds UNIQUEMENT le YAML brut.
    2. UTILISE TOUJOURS DES GUILLEMETS DOUBLES pour les descriptions textuelles.
       - CORRECT : desc: "Represents a Magic: The Gathering card"
       - INCORRECT : desc: Represents a Magic: The Gathering card
    3. Ne mets pas de commentaires ou de texte introductif.
    """

    payload = {
        "model": MODEL_NAME,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0.1, # Encore plus bas pour être très rigide
            "num_ctx": 8192
        }
    }

    print("⏳ Analyse locale par l'IA (Tentative sécurisée)...")
    try:
        response = requests.post(OLLAMA_URL, json=payload)
        response.raise_for_status()
        result_text = response.json()['response']
    except Exception as e:
        print(f"❌ Erreur de connexion à Ollama : {e}")
        exit(1)

    clean_content = clean_yaml_output(result_text)
    output_file = "architecture_doc.yaml"
    
    try:
        yaml_data = yaml.safe_load(clean_content)
        with open(output_file, "w", encoding="utf-8") as f:
            yaml.dump(yaml_data, f, allow_unicode=True, sort_keys=False)
        print(f"✅ Succès ! Documentation générée dans '{output_file}'.")
    except yaml.YAMLError as exc:
        print(f"❌ YAML Invalide. Le modèle a encore fait une erreur de syntaxe.")
        print(f"Détail : {exc}")
        # Sauvegarde du fichier brut pour que tu puisses le corriger manuellement si besoin
        with open("architecture_doc_BRUT.yaml", "w", encoding="utf-8") as f:
            f.write(clean_content)
        print("⚠️ J'ai sauvegardé le résultat brut dans 'architecture_doc_BRUT.yaml'. Vous pouvez essayer de le corriger manuellement.")

if __name__ == "__main__":
    generate_documentation()
