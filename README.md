# ubuntu-config

Ma configuration d'Ubuntu (base Ubuntu Desktop). Configure & met à jour Ubuntu.

Versions testées : 24.04 LTS | 24.10

**Ne fonctionne qu'avec Ubuntu Desktop disposant de l'environnement de bureau GNOME.**

# Guide

## Liste des fichiers

 **config-ubuntu.sh** : Script principal

 **packages.list** : Fichier de paquets DEB à ajouter ou retirer du système

 **snap.list** : Fichier de Snap à ajouter ou retirer du système

 **flatpak.list** : Fichier de Flatpak à ajouter ou retirer du système

## Fonctionnement

Les fichiers mentionnés ci-dessus doivent être dans le même dossier.

> **Remarque :** par défaut, le script installe Flatpak. Pour désactiver Flatpak, modifier la variable `FLATPAK=true` en `FLATPAK=false` dans le fichier `config-ubuntu.sh`

Exécuter avec les droits de super-utilisateur le script principal :

    sudo ./config-ubuntu.sh

Celui-ci peut être exécuté plusieurs fois de suite. Si des étapes sont déjà configurées, elles ne le seront pas à nouveau. De fait, le script peut être utilisé pour :

 - Réaliser la configuration initiale du système
 - Mettre à jour la configuration du système
 - Effectuer les mises à jour des paquets

Il est possible de faire uniquement une vérification des mises à jour (listing des paquets, snap et flatpak à mettre à jour sans appliquer de modifications) via l'option check :

    sudo ./config-ubuntu.sh check

## Opérations réalisées par le script

Le script lancé va effectuer les opérations suivantes :

- Configurer le système APT
    - Mettre à jour les paquets DEB
- Configurer le système Snap
    - Mettre à jour les paquets Snap
- Configurer le système Flatpak *(si activer)*
    - Installer les paquets requis pour Flatpak
    - Mettre à jour les paquets Flatpak + *Proposition de redémarrage du système si nécessaire*
- Ajouter les dépôts additionnels APT / Flatpak *(si activer)*
- Ajouter ou Supprimer les paquets DEB paramétrés dans le fichier packages.list
- Ajouter ou Supprimer les paquets Snap paramétrés dans le fichier snap.list 
- Ajouter ou Supprimer les paquets Flatpak paramétrés dans le fichier flatpak.list *(si activer)*
- Personnaliser la configuration du système + *Proposition de redémarrage du système si nécessaire*

# Crédits

Ce script est basé sur [celui](https://github.com/aaaaadrien/fedora-config) d'Adrien de [linuxtricks.fr](https://www.linuxtricks.fr)
