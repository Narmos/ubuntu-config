#!/usr/bin/env bash

# Le script se termine si une variable non initialisée est utilisée
set -u

#################
### VARIABLES ###
#################

# Pour affichage texte enrichi dans le terminal
TXT_BOLD="\033[1m"
TXT_RED="\033[31m"
TXT_GREEN="\033[32m"
TXT_YELLOW="\033[33m"
TXT_CYAN="\033[36m"
TXT_RESET="\033[0m"

# Chemin et nom du script
SCRIPT_PATH=$(dirname "$0")
SCRIPT_NAME=$(basename "$0")

# Utilisateur courant et son chemin (home)
CURRENT_USER=${SUDO_USER:-$(logname)}
USER_PATH="/home/$CURRENT_USER"

# Chemin des ressources du script
ASSETS_PATH="$SCRIPT_PATH/assets"

# Fichier de log du script
LOG_FILE="/tmp/config-ubuntu.log"

# Status de la gestion des paquets Flatpak (défini)
IS_FLATPAK_ENABLED="true"

# Status de la gestion des paquets Snap (récupéré)
if dpkg-query --status "snapd" &>/dev/null; then
	IS_SNAP_ENABLED="true"
else
	IS_SNAP_ENABLED="false"
fi

# Modèle de l'ordinateur
HARDWARE_MODEL=$(hostnamectl | sed -n 's/^ *Hardware Model: //p')

# Configuration de Fastfetch à utiliser selon modèle de l'ordinateur
if [[ "$HARDWARE_MODEL" == "ThinkPad"* ]]; then
	FASTFETCH_CONFIG="thinkpad"
else
	FASTFETCH_CONFIG="default"
fi

# Informations sur la distribution
if [[ -e "/etc/os-release" ]]; then
	OS_RELEASE="/etc/os-release"
	# Lit le fichier contenant des variables et les défini dans le script préfixées de OSR_
	eval "$(sed 's/^/OSR_/' "${OS_RELEASE}")"
	echo
	echo -e "${TXT_BOLD}Distribution :${TXT_RESET} ${OSR_PRETTY_NAME:-Inconnue}"
	echo
else
	echo
	echo -e "${TXT_RED}${TXT_BOLD}ERREUR⤳${TXT_RESET} Impossible de récupérer les informations sur la distribution utilisée !"
	echo
	exit 1
fi

#####################
### FIN VARIABLES ###
#####################

#################
### FONCTIONS ###
#################

check_cmd() {
	if [[ $? -eq 0 ]]; then
		echo -e "${TXT_GREEN}✔${TXT_RESET}"
	else
		echo -e "${TXT_RED}✖${TXT_RESET}"
	fi
}

ask_update() {
	echo
	echo -e -n "${TXT_CYAN}Voulez-vous lancer les MàJ maintenant ? [o/N] : ${TXT_RESET}"

	local response
	read -r response
	response="${response:-n}"

	if [[ "${response,,}" =~ ^[oOyY]$ ]]; then
		clear -x
		exec bash "$0"
	fi
	echo
}

need_reboot() {
	[[ -f "/var/run/reboot-required" ]]
}

ask_reboot() {
	echo
	echo -e -n "${TXT_YELLOW}REDÉMARRAGE NÉCESSAIRE : Voulez-vous redémarrer le système maintenant ? [o/N] : ${TXT_RESET}"
	
	local response
	read -r response
	response="${response:-n}"
	
	if [[ "${response,,}" =~ ^[oOyY]$ ]]; then
		echo
		echo -e "${TXT_CYAN} ⟳ reboot via systemd... ${TXT_RESET}"
		echo
		sleep 2
		systemctl reboot
		exit 0
	fi
	echo
}

### Gestionnaire de paquets APT

refresh_apt_cache() {
	apt-get clean &>/dev/null
	apt-get update &>/dev/null
}

check_apt_repo() {
	[[ -f "/etc/apt/sources.list.d/${1:-}" ]]
}

check_apt_pref() {
	[[ -f "/etc/apt/preferences.d/${1:-}" ]]
}

check_apt_updates() {
	apt-get dist-upgrade --simulate
}

check_apt_pkg() {
	dpkg-query --status "${1:-}" &>/dev/null
}

add_apt_pkg() {
	apt-get install -y "${1:-}" &>> "$LOG_FILE"
}

del_apt_pkg() {
	apt-get autoremove --purge -y "${1:-}" &>> "$LOG_FILE"
}

### Gestionnaire de paquets Snap

check_snap_updates() {
	snap refresh --list
}

check_snap_pkg() {
	snap list "${1:-}" &>/dev/null
}

add_snap_pkg() {
	snap install "${1:-}" &>> "$LOG_FILE"
}

add_snap_classic_pkg() {
	snap install --classic "${1:-}" &>> "$LOG_FILE"
}

del_snap_pkg() {
	snap remove --purge "${1:-}" &>> "$LOG_FILE"
}

### Gestionnaire de paquets Flatpak

check_flatpak_updates() {
	yes n | flatpak update
}

check_flatpak_pkg() {
	flatpak info "${1:-}" &>/dev/null
}

add_flatpak_pkg() {
	flatpak install flathub --noninteractive -y "${1:-}" &>> "$LOG_FILE"
}

del_flatpak_pkg() {
	flatpak uninstall --noninteractive -y "${1:-}" &>> "$LOG_FILE"
	flatpak uninstall --unused --noninteractive -y &>> "$LOG_FILE"
}

#####################
### FIN FONCTIONS ###
#####################

####################
### DEBUT SCRIPT ###
####################

### VERIFICATION PRÉLIMINAIRES

## Paramètres du script
case "${1:-}" in
	""|"check")
		# Paramètre valide (vide ou "check"), on laisse le script continuer normalement
		;;
	*)
		# Tout autre paramètre déclenche l'erreur d'usage
		echo -e "${TXT_RED}${TXT_BOLD}ERREUR⤳${TXT_RESET} Usage incorrect du script !"
		echo "${SCRIPT_NAME}       : Lance la config et/ou les mises à jour"
		echo "${SCRIPT_NAME} check : Vérifie les mises à jour disponibles et propose de les lancer"
		echo
		exit 1
		;;
esac

## Si bien root
if [[ "$EUID" -ne 0 ]]; then
	echo -e "${TXT_RED}${TXT_BOLD}ERREUR⤳${TXT_RESET} Ce script doit être lancé avec les privilèges root (su - ou sudo) !"
	echo
	exit 1
fi

## Si bien Ubuntu Desktop
if ! check_apt_pkg ubuntu-desktop && ! check_apt_pkg ubuntu-desktop-minimal; then
	echo -e "${TXT_RED}${TXT_BOLD}ERREUR⤳${TXT_RESET} Seule Ubuntu Desktop (GNOME) est supportée !"
	echo
	exit 1
fi

## Si Flatpak installé mais gestion par ce script désactivée
if check_apt_pkg flatpak && [[ "$IS_FLATPAK_ENABLED" == "false" ]]; then
	echo -e "${TXT_YELLOW}${TXT_BOLD}ATTENTION⤳${TXT_RESET} Le système Flatpak est installé mais sa gestion via ce script est désactivée !"
	echo "Pour gérer les Flatpak, remplacez la variable IS_FLATPAK_ENABLED=\"false\" par IS_FLATPAK_ENABLED=\"true\" au début du script ${SCRIPT_NAME}."
	echo
fi

### MODE VÉRIFICATION DES MISES À JOUR
if [[ "${1:-}" == "check" ]]; then
	echo -e -n "${TXT_BOLD}Refresh du cache APT ${TXT_RESET}"
	refresh_apt_cache
	check_cmd

	echo
	echo -e "${TXT_BOLD}Mises à jour disponibles APT : ${TXT_RESET}"
	check_apt_updates

	if [[ "$IS_SNAP_ENABLED" == "true" ]]; then
		echo
		echo -e "${TXT_BOLD}Mises à jour disponibles Snap : ${TXT_RESET}"
		check_snap_updates
	fi

	if [[ "$IS_FLATPAK_ENABLED" == "true" ]] && check_apt_pkg "flatpak"; then
		echo
		echo -e "${TXT_BOLD}Mises à jour disponibles Flatpak : ${TXT_RESET}"
		check_flatpak_updates
	fi

	ask_update
	exit 0
fi

### JOURNALISATION
echo -e "${TXT_CYAN}Pour suivre la progression des mises à jour : tail -f ${LOG_FILE}${TXT_RESET}"
echo

## Séparation et date dans le fichier de log
echo -e "\n--------------------\n$(date)\n--------------------\n" &>> "$LOG_FILE"

### CONFIGURATION APT
echo -e "${TXT_BOLD}[01] Configuration du gestionnaire de paquets APT ${TXT_RESET}"

echo -n " ↳ Refresh du cache "
refresh_apt_cache
check_cmd

echo -n " ↳ Mise à jour des paquets "
apt-get dist-upgrade -y &>> "$LOG_FILE"
check_cmd

### CONFIGURATION SNAP
if [[ "$IS_SNAP_ENABLED" == "true" ]]; then
	echo -e "${TXT_BOLD}[02] Configuration du gestionnaire de paquets Snap ${TXT_RESET}"

	echo -n " ↳ Mise à jour des paquets "
	snap refresh &>> "$LOG_FILE"
	check_cmd
fi

### CONFIGURATION FLATPAK
if [[ "$IS_FLATPAK_ENABLED" == "true" ]]; then
	echo -e "${TXT_BOLD}[03] Configuration du gestionnaire de paquets Flatpak ${TXT_RESET}"

	if ! check_apt_pkg "flatpak"; then
		echo -n " ↳ Installation du paquet requis : flatpak "
		add_apt_pkg "flatpak"
		check_cmd
	fi

	echo -n " ↳ Mise à jour des paquets "
	flatpak update --noninteractive &>> "$LOG_FILE"
	check_cmd
fi

### VÉRIFICATION SI REBOOT NECESSAIRE
if need_reboot; then
	ask_reboot
fi

### CONFIGURATION DES DÉPOTS
echo -e "${TXT_BOLD}[04] Configuration des dépôts ${TXT_RESET}"

## Firefox
if ! check_apt_repo mozilla.sources \
	&& [[ -f "$ASSETS_PATH/apt/sources.list.d/mozilla.sources" ]]; then
	
	echo " ↳ Configuration du dépôt APT : Mozilla (Firefox) "

	echo -n "  ↳ Import de la clé de signature du dépôt "
	wget -qO - https://packages.mozilla.org/apt/repo-signing-key.gpg \
	| gpg --dearmor -o /etc/apt/keyrings/packages.mozilla.org.gpg
	check_cmd

	echo -n "  ↳ Ajout du dépôt "
	cp -uv "$ASSETS_PATH/apt/sources.list.d/mozilla.sources" "/etc/apt/sources.list.d/" &>> "$LOG_FILE"
	check_cmd

	if [[ -f "$ASSETS_PATH/apt/preferences.d/mozilla" ]]; then
		echo -n "  ↳ Priorisation du dépôt "
		cp -uv "$ASSETS_PATH/apt/preferences.d/mozilla" "/etc/apt/preferences.d/" &>> "$LOG_FILE"
		check_cmd
	fi

	echo -n "  ↳ Refresh du cache "
	refresh_apt_cache
	check_cmd
fi

## VS Code
if ! check_apt_repo vscode.sources \
	&& [[ -f "$ASSETS_PATH/apt/sources.list.d/vscode.sources" ]]; then
	
	echo " ↳ Configuration du dépôt APT : VS Code "

	echo -n "  ↳ Import de la clé de signature du dépôt "
	wget -qO - https://packages.microsoft.com/keys/microsoft.asc \
	| gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
	check_cmd

	echo -n "  ↳ Ajout du dépôt "
	cp -uv "$ASSETS_PATH/apt/sources.list.d/vscode.sources" "/etc/apt/sources.list.d/" &>> "$LOG_FILE"
	check_cmd

	echo -n "  ↳ Refresh du cache "
	refresh_apt_cache
	check_cmd
fi

## Flathub
if [[ "$IS_FLATPAK_ENABLED" == "true" ]] \
	&& check_apt_pkg "flatpak" \
	&& ! flatpak remotes | grep -q "flathub"; then

	echo -n " ↳ Configuration du dépôt Flatpak : Flathub "
	flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo &>/dev/null
	check_cmd
fi

### REMPLACEMENT SNAP
echo -e "${TXT_BOLD}[05] Remplacement de Snap forcé par Ubuntu ${TXT_RESET}"

## Firefox
if check_snap_pkg "firefox"; then
	echo " ↳ Remplacement du Snap Firefox par le paquet du dépôt APT Mozilla"

	echo -n "  ↳ Suppression du Snap : firefox "
	del_snap_pkg "firefox"
	check_cmd

	echo -n "  ↳ Suppression du paquet transitoire : firefox "
	del_apt_pkg "firefox"
	check_cmd

	echo -n "  ↳ Installation du paquet officiel : firefox "
	add_apt_pkg "firefox"
	check_cmd

	echo -n "  ↳ Installation du paquet de langue : firefox-l10n-fr "
	add_apt_pkg "firefox-l10n-fr"
	check_cmd
fi

### INSTALLATION/SUPPRESSION DEB
echo -e "${TXT_BOLD}[06] Gestion des paquets Deb ${TXT_RESET}"

## Selon fichier packages.list
if [[ -f "$SCRIPT_PATH/packages.list" ]]; then
	while read -r line || [[ -n "$line" ]]; do
		[[ -z "${line:-}" || "$line" =~ ^[[:space:]]*# || "$line" =~ ^[[:space:]]*$ ]] && continue

		if [[ "$line" == "add:"* ]]; then
			p="${line#add:}"
			if ! check_apt_pkg "$p"; then
				echo -n " ↳ Installation du paquet : $p "
				add_apt_pkg "$p"
				check_cmd
			fi
		elif [[ "$line" == "del:"* ]]; then
			p="${line#del:}"
			if check_apt_pkg "$p"; then
				echo -n " ↳ Suppression du paquet : $p "
				del_apt_pkg "$p"
				check_cmd
			fi
		fi
	done < "$SCRIPT_PATH/packages.list"
else
	echo -e " ↳ ${TXT_YELLOW}${TXT_BOLD}ATTENTION⤳${TXT_RESET} Le fichier packages.list n'existe pas !"
fi

### INSTALLATION/SUPPRESSION SNAP
if [[ "$IS_SNAP_ENABLED" == "true" ]]; then
	echo -e "${TXT_BOLD}[07] Gestion des paquets Snap ${TXT_RESET}"

	## Selon fichier snap.list
	if [[ -f "$SCRIPT_PATH/snap.list" ]]; then
		while read -r line || [[ -n "$line" ]]; do
			[[ -z "${line:-}" || "$line" =~ ^[[:space:]]*# || "$line" =~ ^[[:space:]]*$ ]] && continue

			if [[ "$line" == "add:"* ]]; then
				p="${line#add:}"
				if ! check_snap_pkg "$p"; then
					echo -n " ↳ Installation du Snap : $p "
					add_snap_pkg "$p"
					check_cmd
				fi
			elif [[ "$line" == "addclassic:"* ]]; then
				p="${line#addclassic:}"
				if ! check_snap_pkg "$p"; then
					echo -n " ↳ Installation du Snap : $p "
					add_snap_classic_pkg "$p"
					check_cmd
				fi
			elif [[ "$line" == "del:"* ]]; then
				p="${line#del:}"
				if check_snap_pkg "$p"; then
					echo -n " ↳ Suppression du Snap : $p "
					del_snap_pkg "$p"
					check_cmd
				fi
			fi
		done < "$SCRIPT_PATH/snap.list"
	else
		echo -e " ↳ ${TXT_YELLOW}${TXT_BOLD}ATTENTION⤳${TXT_RESET} Le fichier snap.list n'existe pas !"
	fi
fi

### INSTALLATION/SUPPRESSION FLATPAK
if [[ "$IS_FLATPAK_ENABLED" == "true" ]]; then
	echo -e "${TXT_BOLD}[08] Gestion des paquets Flatpak ${TXT_RESET}"

	## Selon fichier flatpak.list
	if [[ -f "$SCRIPT_PATH/flatpak.list" ]]; then
		while read -r line || [[ -n "$line" ]]; do
			[[ -z "${line:-}" || "$line" =~ ^[[:space:]]*# || "$line" =~ ^[[:space:]]*$ ]] && continue

			if [[ "$line" == "add:"* ]]; then
				p="${line#add:}"
				if ! check_flatpak_pkg "$p"; then
					echo -n " ↳ Installation du Flatpak : $p "
					add_flatpak_pkg "$p"
					check_cmd
				fi
			elif [[ "$line" == "del:"* ]]; then
				p="${line#del:}"
				if check_flatpak_pkg "$p"; then
					echo -n " ↳ Suppression du Flatpak : $p "
					del_flatpak_pkg "$p"
					check_cmd
				fi
			fi
		done < "$SCRIPT_PATH/flatpak.list"
	else
		echo -e " ↳ ${TXT_YELLOW}${TXT_BOLD}ATTENTION⤳${TXT_RESET} Le fichier flatpak.list n'existe pas !"
	fi
fi

### CONFIGURATION SYSTÈME
echo -e "${TXT_BOLD}[09] Configuration personnalisée du système ${TXT_RESET}"

## Fastfetch
if check_apt_pkg "fastfetch" \
	&& [[ -d "$ASSETS_PATH/fastfetch/$FASTFETCH_CONFIG" ]]; then
	echo -e " ↳ Configuration de Fastfetch"

	if [[ ! -d "$USER_PATH/.config/fastfetch" ]]; then
		echo -n "  ↳ Création du dossier de config (~/.config/fastfetch) "
		sudo -u "$CURRENT_USER" mkdir -p "$USER_PATH/.config/fastfetch"
		check_cmd
	fi

	echo -n "  ↳ Mise à jour de la config (si nécessaire) "
	sudo -u "$CURRENT_USER" cp -ruv "$ASSETS_PATH/fastfetch/$FASTFETCH_CONFIG/." "$USER_PATH/.config/fastfetch/" | sudo tee -a "$LOG_FILE" &>/dev/null
	check_cmd
fi

## Bash
if check_apt_pkg "bash" \
	&& [[ -d "$ASSETS_PATH/bash/bashrc.d" ]]; then
	echo -e " ↳ Configuration de Bash"

	if [[ ! -d "$USER_PATH/.bashrc.d" ]]; then
		echo -n "  ↳ Création du dossier de config (~/.bashrc.d) "
		sudo -u "$CURRENT_USER" mkdir -p "$USER_PATH/.bashrc.d"
		check_cmd
	fi

	echo -n "  ↳ Mise à jour de la config (si nécessaire) "
	sudo -u "$CURRENT_USER" cp -ruv "$ASSETS_PATH/bash/bashrc.d/." "$USER_PATH/.bashrc.d/" | sudo tee -a "$LOG_FILE" &>/dev/null
	check_cmd

	if [[ -f "$ASSETS_PATH/bash/bashrc" ]] \
		&& [[ -f "$USER_PATH/.bashrc" ]] \
		&& ! grep -q "bashrc.d" "$USER_PATH/.bashrc"; then

		echo -n "  ↳ Configuration de l'import automatique du dossier de config "
		cat "$ASSETS_PATH/bash/bashrc" | sudo -u "$CURRENT_USER" tee -a "$USER_PATH/.bashrc" | sudo tee -a "$LOG_FILE" &>/dev/null
		check_cmd
	fi
fi

## Bluetooth
if [[ -f "/etc/bluetooth/main.conf" ]] \
	&& ! grep -q "^[[:space:]]*AutoEnable=false" "/etc/bluetooth/main.conf"; then

	echo -n " ↳ Désactivation du Bluetooth au démarrage "
	sed -i 's/^[[:space:]]*#\?[[:space:]]*AutoEnable=.*/AutoEnable=false/' "/etc/bluetooth/main.conf"
	check_cmd
fi

### VÉRIFICATION SI REBOOT NECESSAIRE
if need_reboot; then
	ask_reboot
else
	echo
fi

##################
### FIN SCRIPT ###
##################
