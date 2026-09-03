#!/usr/bin/env bash

#################
### VARIABLES ###
#################
CURRENTPATH=$(dirname "$0")
USER_HOME=$(eval echo ~$SUDO_USER)
FLATPAK=true
SNAP=true
LOGFILE="/tmp/config-ubuntu.log"

# RECUP les infos sur la distribution pour vérification
if [[ -e /etc/os-release ]]; then
	os_release="/etc/os-release"
	. "${os_release}"
	echo "Distribution : ${PRETTY_NAME}"
fi

#################
### FONCTIONS ###
#################
check_cmd() {
	if [[ $? -eq 0 ]]; then
		echo -e "\033[32m\xE2\x9C\x94\033[0m" # vu vert
	else
		echo -e "\033[31m\xE2\x9D\x8C\033[0m" # croix rouge
	fi
}

refresh_apt_cache() {
	apt-get clean > /dev/null 2>&1
	apt-get update > /dev/null 2>&1
}

check_apt_repo() {
	if [[ -e /etc/apt/sources.list.d/$1 ]]; then
		return 0
	else
		return 1
	fi
}

check_apt_updates() {
	yes n | apt-get dist-upgrade
}

check_apt_pkg() {
	dpkg-query --status "$1" > /dev/null 2>&1
}

add_apt_pkg() {
	apt-get install -y "$1" >> "$LOGFILE" 2>&1
}

del_apt_pkg() {
	apt-get autoremove --purge -y "$1" >> "$LOGFILE" 2>&1
}

check_snap_updates() {
	snap refresh --list
}

check_snap_pkg() {
	snap list "$1" > /dev/null 2>&1
}

add_snap_pkg() {
	snap install "$1" > /dev/null 2>&1
}

add_snap_classic_pkg() {
	snap install --classic "$1" > /dev/null 2>&1
}

del_snap_pkg() {
	snap remove --purge "$1" > /dev/null 2>&1
}

check_flatpak_updates() {
	yes n | flatpak update
}

check_flatpak_pkg() {
	flatpak info "$1" > /dev/null 2>&1
}

add_flatpak_pkg() {
	flatpak install flathub --noninteractive -y "$1" > /dev/null 2>&1
}

del_flatpak_pkg() {
	flatpak uninstall --noninteractive -y "$1" > /dev/null 2>&1
	flatpak uninstall --unused --noninteractive -y > /dev/null 2>&1
}

need_reboot() {
	if [[ -e /var/run/reboot-required ]]; then
		return 0
	else
		return 1
	fi
}

ask_reboot() {
	echo -n -e "\033[5;33mREDÉMARRAGE NÉCESSAIRE\033[0m\033[33m : Voulez-vous redémarrer le système maintenant ? [o/N] : \033[0m"
	read rebootuser
	rebootuser=${rebootuser:-n}
	if [[ ${rebootuser,,} =~ ^[oOyY]$ ]]; then
		echo -e "\n\033[0;35m Reboot via systemd ... \033[0m"
		sleep 2
		systemctl reboot
		exit
	fi
}

ask_update() {
	echo -n -e "\n\033[36mVoulez-vous lancer les MàJ maintenant ? [o/N] : \033[0m"
	read startupdate
	startupdate=${startupdate:-n}
	echo
	if [[ ${startupdate,,} =~ ^[oOyY]$ ]]; then
		clear -x
		bash "$0"
	fi
}

####################
### DEBUT SCRIPT ###
####################
### VERIF option du script
if [[ -z "$1" ]]; then
	echo "OK" > /dev/null
elif [[ "$1" == "check" ]]; then
	echo "OK" > /dev/null
else
	echo -e "\033[31mERREUR\033[0m Usage incorrect du script"
	echo "$(basename $0)         : Lance la config et/ou les mises à jour"
	echo "$(basename $0) check   : Vérifie les mises à jour disponibles et propose de les lancer"
	exit 1;
fi

### VERIF si root
if [[ $(id -u) -ne "0" ]]; then
	echo -e "\033[31mERREUR\033[0m Lancer le script avec les droits root (su - root ou sudo)"
	exit 1;
fi

### VERIF si bien Ubuntu Desktop
if ! check_apt_pkg ubuntu-desktop && ! check_apt_pkg ubuntu-desktop-minimal; then
	echo -e "\033[31mERREUR\033[0m Seule Ubuntu Desktop (GNOME) est supportée !"
	exit 2;
fi

### VERIF gestion Snap
if check_apt_pkg snapd && ! $SNAP; then
	echo -e "\033[5;33mATTENTION\033[0m\033[33m Le système Snap est installé mais sa gestion via ce script est désactivée !\033[0m"
	echo -e "Pour gérer les Snaps, remplacer la variable SNAP=false par SNAP=true au début du script $(basename $0)"
fi

### VERIF gestion Flatpak
if check_apt_pkg flatpak && ! $FLATPAK; then
	echo -e "\033[5;33mATTENTION\033[0m\033[33m : Le système Flatpak est installé mais sa gestion via ce script est désactivée !\033[0m"
	echo -e "Pour gérer les Flatpak, remplacer la variable FLATPAK=false par FLATPAK=true au début du script $(basename $0)"
fi

### VERIF MàJ si option "check"
if [[ "$1" = "check" ]]; then
	echo
	echo -e -n "\033[1mRefresh du cache APT \033[0m"
	refresh_apt_cache
	check_cmd

	echo -e "\033[1mMises à jour disponibles APT : \033[0m"
	check_apt_updates

	echo

	if $SNAP; then
		if check_apt_pkg "snapd"; then
			echo
			echo -e "\033[1mMises à jour disponibles Snap : \033[0m"
			check_snap_updates
		fi
	fi

	if $FLATPAK; then
		if check_apt_pkg "flatpak"; then
			echo
			echo -e "\033[1mMises à jour disponibles Flatpak : \033[0m"
			check_flatpak_updates
		fi
	fi

	ask_update
	exit;
fi

### INFOS fichier log
echo -e "\033[36m"
echo "Pour suivre la progression des mises à jour : tail -f $LOGFILE"
echo -e "\033[0m"
## Date dans le log
echo '-------------------' >> "$LOGFILE"
date >> "$LOGFILE"

### CONFIG système APT
echo -e "\033[1mConfiguration du système APT\033[0m"

echo -e -n " \xE2\x86\xB3 Refresh du cache "
refresh_apt_cache
check_cmd

## MAJ des paquets DEB
echo -e -n " \xE2\x86\xB3 Mise à jour des paquets "
apt-get dist-upgrade -y >> "$LOGFILE" 2>&1
check_cmd

### CONFIG système Snap
if $SNAP; then
	echo -e "\033[1mConfiguration du système Snap\033[0m"

	## INSTALL paquet requis pour système Snap
	if ! check_apt_pkg "snapd"; then
		echo -e -n " \xE2\x86\xB3 Installation du paquet requis : snapd "
		add_apt_pkg snapd
		check_cmd
	fi

	## MAJ des paquets Snap
	echo -e -n " \xE2\x86\xB3 Mise à jour des paquets "
	snap refresh >> "$LOGFILE" 2>&1
	check_cmd
fi

### CONFIG système Flatpak
if $FLATPAK; then
	echo -e "\033[1mConfiguration du système Flatpak\033[0m"

	## INSTALL paquet requis pour système Flatpak
	if ! check_apt_pkg "flatpak"; then
		echo -e -n " \xE2\x86\xB3 Installation du paquet requis : flatpak "
		add_apt_pkg "flatpak"
		check_cmd
	fi

	## MAJ des paquets Flatpak
	echo -e -n " \xE2\x86\xB3 Mise à jour des paquets "
	flatpak update --noninteractive >> "$LOGFILE" 2>&1
	check_cmd
fi

### VERIF si reboot nécessaire
if need_reboot; then
	ask_reboot
fi

### CONFIG des dépôts
echo -e "\033[1mConfiguration des dépôts\033[0m"

## Firefox
if ! check_apt_repo mozilla.sources; then
	echo -e -n " \xE2\x86\xB3 Configuration du dépôt APT : Mozilla (Firefox) "

	echo -e -n "  \xE2\x86\xB3 Import de la clé de signature du dépôt "
	wget -qO - https://packages.mozilla.org/apt/repo-signing-key.gpg \
	| gpg --dearmor -o /etc/apt/keyrings/packages.mozilla.org.asc
	check_cmd

	echo -e -n "  \xE2\x86\xB3 Ajout du dépôt "
	sudo cp "./assets/apt/sources.list.d/mozilla.sources" "/etc/apt/sources.list.d/"
	check_cmd

	echo -e -n "  \xE2\x86\xB3 Priorisation du dépôt "
	sudo cp "./assets/apt/preferences.d/mozilla" "/etc/apt/preferences.d/"
	check_cmd

	echo -e -n "  \xE2\x86\xB3 Refresh du cache "
	refresh_apt_cache
	check_cmd
fi

## VS Code
if ! check_apt_repo vscode.sources; then
	echo -e -n " \xE2\x86\xB3 Configuration du dépôt APT : VS Code "
	
	echo -e -n "  \xE2\x86\xB3 Import de la clé de signature du dépôt "
	wget -qO - https://packages.microsoft.com/keys/microsoft.asc \
	| gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
	check_cmd
	
	echo -e -n "  \xE2\x86\xB3 Ajout du dépôt "
	sudo cp "./assets/apt/sources.list.d/vscode.sources" "/etc/apt/sources.list.d/"
	check_cmd
	
	echo -e -n "  \xE2\x86\xB3 Refresh du cache "
	refresh_apt_cache
	check_cmd
fi

## Flathub
if $FLATPAK; then
	if [[ $(flatpak remotes | grep -c flathub) -ne 1 ]]; then
		echo -e -n " \xE2\x86\xB3 Configuration du dépôt Flatpak : Flathub "
		flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1
		check_cmd
	fi
fi

### REMPLACEMENT Snap
echo -e "\033[1mRemplacement de Snap forcé par Ubuntu\033[0m"

## Firefox
if check_snap_pkg "firefox"; then
	echo -e " \xE2\x86\xB3 Remplacement du Snap Firefox par le paquet du dépôt APT Mozilla "
	echo -e -n "  \xE2\x86\xB3 Suppression du Snap : firefox "
	del_snap_pkg "firefox"
	check_cmd

	echo -e -n "  \xE2\x86\xB3 Suppression du paquet résiduel : firefox "
	del_apt_pkg "firefox"
	check_cmd

	echo -e -n "  \xE2\x86\xB3 Installation du paquet : firefox "
	add_apt_pkg "firefox"
	check_cmd

	echo -e -n "  \xE2\x86\xB3 Installation du paquet : firefox-l10n-fr "
	add_apt_pkg "firefox-l10n-fr"
	check_cmd
fi

### INSTALL/SUPPRESSION DEB
echo -e "\033[1mGestion des paquets APT\033[0m"
## Selon packages.list
while read -r line; do
	if [[ "$line" == add:* ]]; then
		p=${line#add:}
		if ! check_apt_pkg "$p"; then
			echo -e -n " \xE2\x86\xB3 Installation du paquet : $p "
			add_apt_pkg "$p"
			check_cmd
		fi
	fi
	
	if [[ "$line" == del:* ]]; then
		p=${line#del:}
		if check_apt_pkg "$p"; then
			echo -e -n " \xE2\x86\xB3 Suppression du paquet : $p "
			del_apt_pkg "$p"
			check_cmd
		fi
	fi
done < "$CURRENTPATH/packages.list"

### INSTALL/SUPPRESSION Snap
if $SNAP; then
	echo -e "\033[1mGestion des paquets Snap\033[0m"
	## Selon snap.list
	while read -r line
	do
		if [[ "$line" == add:* ]]; then
			p=${line#add:}
			if ! check_snap_pkg "$p"; then
				echo -e -n " \xE2\x86\xB3 Installation du Snap : $p "
				add_snap_pkg "$p"
				check_cmd
			fi
		fi

		if [[ "$line" == addclassic:* ]]; then
			p=${line#addclassic:}
			if ! check_snap_pkg "$p"; then
				echo -e -n " \xE2\x86\xB3 Installation du Snap : $p "
				add_snap_classic_pkg "$p"
				check_cmd
			fi
		fi
		
		if [[ "$line" == del:* ]]; then
			p=${line#del:}
			if check_snap_pkg "$p"; then
				echo -e -n " \xE2\x86\xB3 Suppression du Snap : $p "
				del_snap_pkg "$p"
				check_cmd
			fi
		fi
	done < "$CURRENTPATH/snap.list"
fi

### INSTALL/SUPPRESSION Flatpak
if $FLATPAK; then
	echo -e "\033[1mGestion des paquets Flatpak\033[0m"
	## Selon flatpak.list
	while read -r line; do
		if [[ "$line" == add:* ]]; then
			p=${line#add:}
			if ! check_flatpak_pkg "$p"; then
				echo -e -n " \xE2\x86\xB3 Installation du Flatpak : $p "
				add_flatpak_pkg "$p"
				check_cmd
			fi
		fi
		
		if [[ "$line" == del:* ]]; then
			p=${line#del:}
			if check_flatpak_pkg "$p"; then
				echo -e -n " \xE2\x86\xB3 Suppression du Flatpak : $p "
				del_flatpak_pkg "$p"
				check_cmd
			fi
		fi
	done < "$CURRENTPATH/flatpak.list"
fi

### CONFIG système
echo -e "\033[1mConfiguration personnalisée du système\033[0m"

## Fastfetch
if [[ ! -d "$USER_HOME/.config/fastfetch" ]]; then
	echo -e -n " \xE2\x86\xB3 Configuration de fastfetch "
	if [[ "$(cat /sys/devices/virtual/dmi/id/product_version 2>/dev/null)" == ThinkPad* ]]; then
		fastfetch_config="thinkpad"
	else
		fastfetch_config="default"
	fi
	cp -r "./assets/fastfetch/${fastfetch_config}/" "$USER_HOME/.config/fastfetch" && \
	chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config/fastfetch"
	check_cmd
fi

## Bash
if [[ ! -d "$USER_HOME/.bashrc.d" ]]; then
	echo -e -n " \xE2\x86\xB3 Ajout des alias et fonctions Bash dans ~/.bashrc.d "
	cp -r "./assets/bash/bashrc.d/" "$USER_HOME/.bashrc.d" && \
	chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.bashrc.d"
	check_cmd
	echo -e -n " \xE2\x86\xB3 Import des fichiers de ~/.bashrc.d dans .bashrc "
	sudo -u "$SUDO_USER" cat "./assets/bash/bashrc" >> "$USER_HOME/.bashrc"
	check_cmd
fi

## Bluetooth
if [[ -e "/etc/bluetooth/main.conf" ]]; then
	if ! grep -q "^[[:space:]]*AutoEnable=false" "/etc/bluetooth/main.conf"; then
		echo -e -n " \xE2\x86\xB3 Désactivation du bluetooth au démarrage "
		# Cette regex gère les espaces et remplace '#AutoEnable=true' ou 'AutoEnable=true'
		sed -i 's/^[[:space:]]*#\?[[:space:]]*AutoEnable=.*/AutoEnable=false/' "/etc/bluetooth/main.conf"
		check_cmd
	fi
fi

echo

### VERIF si reboot nécessaire
if need_reboot; then
	ask_reboot
fi
