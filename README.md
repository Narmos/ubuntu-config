# Ma configuration Ubuntu

Script d'automatisation pour configurer et mettre à jour mon système Ubuntu (base Ubuntu Desktop Minimal).

> [!NOTE]
> Ce script est conçu exclusivement pour **Ubuntu Desktop** utilisant l'environnement de bureau **GNOME**.

---

## 🧪 Versions testées
* Ubuntu 26.04 LTS
* Ubuntu 24.04 LTS

---

## 🔍 Ce que fait le script

1. Configure le système APT et met à jour les paquets
2. Configure le système Snap et met à jour les paquets
3. Configure le système Flatpak et met à jour les paquets
4. Configure les dépôts APT et Flatpak additionnels
5. Remplace les Snaps forcés par Ubuntu
6. Ajoute ou supprime les paquets deb spécifiés dans `packages.list`
7. Ajoute ou supprime les paquets snap spécifiés dans `snap.list`
8. Ajoute ou supprime les paquets flatpak spécifiés dans `flatpak.list`
9. Personnalise la configuration du système

---

## 📁 Structure

```bash
.
├── assets/               # Ressources à copier sur le système
├── config-ubuntu.sh      # Script principal
├── flatpak.list          # Liste des paquets Flatpak à installer/désinstaller
├── packages.list         # Liste des paquets Deb à installer/désinstaller
└── snap.list             # Liste des paquets Snap à installer/désinstaller
```

---

## 🚀 Usage

### 1. Configuration de Flatpak (Optionnel)
Par défaut, le script installe et gère le système de paquets Flatpak. Pour désactiver Flatpak, ouvrez le fichier `config-ubuntu.sh` et modifiez la variable suivante :
```bash
FLATPAK=false
```

> [!IMPORTANT]
> A faire avant le premier lancement du script !

### 2. Exécution du script
Ouvrez votre terminal dans le dossier du dépôt, autorisez l'exécution du script et lancez-le avec les privilèges de super-utilisateur :
```bash
chmod +x config-ubuntu.sh
sudo ./config-ubuntu.sh
```

### 3. Mode vérification de mises à jour
Il est possible de faire uniquement une vérification des mises à jour (listing des paquets deb, snap et flatpak à mettre à jour sans appliquer de modifications) via l'option `check` :
```bash
sudo ./config-ubuntu.sh check
```

### 4. Utilisation pour la maintenance
Ce script est idempotent. Vous pouvez l'exécuter plusieurs fois de suite; les étapes déjà configurées seront simplement ignorées. De fait, le script peut être utilisé pour :
* **Configuration initiale** du système après une installation fraîche
* **Mise à jour** de la configuration et des listes de paquets
* **Mise à jour globale** de tous les paquets du système

---

## 🙏 Crédits

Ce script est inspiré du [travail initial](https://github.com/aaaaadrien/fedora-config) d'Adrien de [linuxtricks.fr](https://www.linuxtricks.fr)
