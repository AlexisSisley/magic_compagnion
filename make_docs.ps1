Write-Host "🚀 DÉMARRAGE DU PIPELINE RETRO-DOC (LOCAL)" -ForegroundColor Cyan

# 1. Nettoyage
if (Test-Path "repomix-output.xml") { Remove-Item "repomix-output.xml" }

# 2. Compactage du code
Write-Host "📦 Étape 1/3 : Compactage du code (Repomix)..." -ForegroundColor Yellow
repomix --style xml
if ($LASTEXITCODE -ne 0) { Write-Error "Echec de Repomix"; exit 1 }

# 3. Analyse IA
Write-Host "🧠 Étape 2/3 : Analyse IA (Ollama)..." -ForegroundColor Yellow
python generate_doc_local.py
if ($LASTEXITCODE -ne 0) { Write-Error "Echec de la génération"; exit 1 }

# 4. Conversion Markdown
Write-Host "📝 Étape 3/3 : Génération du rapport Markdown..." -ForegroundColor Yellow
python yaml_to_md.py

Write-Host "✅ TERMINÉ ! Ouvrez le fichier ARCHITECTURE.md" -ForegroundColor Green