import os
import yaml
import anthropic

# Configuration
ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")
MODEL_NAME = "claude-sonnet-4-20250514"


def clean_yaml_output(text):
    """Nettoyage des blocs markdown eventuels dans la reponse."""
    text = text.replace("```yaml", "").replace("```", "").strip()
    return text


def generate_documentation():
    print(f"Demarrage de la Retro-Documentation (Claude : {MODEL_NAME})...")

    if not ANTHROPIC_API_KEY:
        print("Erreur : ANTHROPIC_API_KEY non definie.")
        exit(1)

    try:
        with open("repomix-output.xml", "r", encoding="utf-8") as f:
            code_context = f.read()
    except FileNotFoundError:
        print("Erreur : 'repomix-output.xml' introuvable. Lancez repomix d'abord.")
        exit(1)

    prompt = f"""
[ROLE]
Tu es un architecte logiciel expert en Flutter.

[CONTEXTE]
Voici le code source d'une application (format XML compacte) :
{code_context}

[MISSION]
Analyse ce code et genere une documentation architecturale au format YAML strict.

[FORMAT ATTENDU]
project_name: "Nom du projet"
architecture:
  state_management: "ex: Riverpod"
  navigation: "ex: GoRouter"
  services: ["Service1", "Service2"]
domain_models:
  - name: "NomClasse"
    desc: "Description courte"
security_hotspots:
  - "Point de vigilance"
tech_debt:
  - "Point de dette technique"

[REGLES CRITIQUES DE SYNTAXE]
1. Reponds UNIQUEMENT le YAML brut, sans blocs markdown, sans commentaires, sans texte introductif.
2. UTILISE TOUJOURS DES GUILLEMETS DOUBLES pour les descriptions textuelles.
   - CORRECT : desc: "Represents a Magic: The Gathering card"
   - INCORRECT : desc: Represents a Magic: The Gathering card
3. Ne mets aucun texte avant ou apres le YAML.
"""

    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

    print("Analyse par Claude en cours...")
    try:
        message = client.messages.create(
            model=MODEL_NAME,
            max_tokens=4096,
            messages=[
                {"role": "user", "content": prompt}
            ],
        )
        result_text = message.content[0].text
    except anthropic.APIError as e:
        print(f"Erreur API Anthropic : {e}")
        exit(1)

    clean_content = clean_yaml_output(result_text)
    output_file = "architecture_doc.yaml"

    try:
        yaml_data = yaml.safe_load(clean_content)
        with open(output_file, "w", encoding="utf-8") as f:
            yaml.dump(yaml_data, f, allow_unicode=True, sort_keys=False)
        print(f"Succes ! Documentation generee dans '{output_file}'.")
    except yaml.YAMLError as exc:
        print(f"YAML Invalide. Erreur de parsing : {exc}")
        with open("architecture_doc_BRUT.yaml", "w", encoding="utf-8") as f:
            f.write(clean_content)
        print("Resultat brut sauvegarde dans 'architecture_doc_BRUT.yaml'.")
        exit(1)


if __name__ == "__main__":
    generate_documentation()
