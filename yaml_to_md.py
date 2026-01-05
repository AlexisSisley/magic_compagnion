import yaml
import os
from datetime import datetime

def render_md():
    input_file = "architecture_doc.yaml"
    output_file = "ARCHITECTURE.md"

    if not os.path.exists(input_file):
        print(f"❌ Fichier {input_file} introuvable.")
        return

    with open(input_file, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    # En-tête
    md = f"# 🏛️ Architecture Technique : {data.get('project_name', 'Projet Inconnu')}\n\n"
    md += f"> *Généré automatiquement le {datetime.now().strftime('%d/%m/%Y à %H:%M')} par Retro-Doc (Local AI)*\n\n"

    # Section 1 : Architecture Globale
    arch = data.get('architecture', {})
    md += "## 🏗️ Architecture Globale\n"
    if isinstance(arch, dict):
        for key, value in arch.items():
            nice_key = key.replace('_', ' ').capitalize()
            md += f"- **{nice_key}** : {value}\n"
    md += "\n"

    # Section 2 : Modèles de Domaine
    models = data.get('domain_models', [])
    if models:
        md += "## 🧠 Modèles de Domaine (Business Logic)\n"
        md += "| Classe | Description |\n"
        md += "| :--- | :--- |\n"
        for m in models:
            name = m.get('name', 'N/A')
            desc = m.get('desc', m.get('description', ''))
            md += f"| `{name}` | {desc} |\n"
        md += "\n"

    # Section 3 : Points de Sécurité (Hotspots)
    security = data.get('security_hotspots', [])
    if security:
        md += "## 🔒 Audit de Sécurité (IA)\n"
        for point in security:
            md += f"- ⚠️ {point}\n"
        md += "\n"

    # Sauvegarde
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(md)
    
    print(f"✨ Rapport généré : {output_file}")

if __name__ == "__main__":
    render_md()