# 🏛️ Architecture Technique : Magic Companion

> *Généré automatiquement le 06/01/2026 à 00:21 par Retro-Doc (Local AI)*

## 🏗️ Architecture Globale
- **State management** : Riverpod
- **Services** : ['BackupService', 'GoogleDriveService']

## 🧠 Modèles de Domaine (Business Logic)
| Classe | Description |
| :--- | :--- |
| `Card` | Represents a Magic: The Gathering card with properties like name, mana_cost, and type. |
| `Deck` | Represents a collection of cards forming a deck for playing Magic: The Gathering. |
| `User` | Represents a user with attributes such as email and authentication status. |

## 🔒 Audit de Sécurité (IA)
- ⚠️ Sensitive data handling in BackupService and GoogleDriveService

