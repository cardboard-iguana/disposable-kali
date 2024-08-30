#!/usr/bin/env bash

NAME="{{environment-name}}"

# Core engagement files/data.
#
SCRIPT="$HOME/bin/${NAME}.sh"
ENGAGEMENT_DIR="$HOME/storage/shared/Documents/Engagements/$NAME"
DISTRO_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/$NAME"

# Sanity check environment.
#
if [[ "$1" == "restore" ]] && [[ -d "$ENGAGEMENT_DIR" ]] && [[ -f "$SCRIPT" ]]; then
	SANITY="100%"
elif [[ -d "$DISTRO_ROOT" ]] && [[ -d "$ENGAGEMENT_DIR" ]] && [[ -f "$SCRIPT" ]]; then
	SANITY="100%"
elif [[ "$1" == "help" ]] || [[ -z "$1" ]]; then
	SANITY="100%"
else
	SANITY="0%"
fi
if [[ "$SANITY" == "0%" ]]; then
	echo "The environment for $NAME appears to be damaged or incomplete, and is"
	echo "not usable."
	echo ""
	if [[ -d "$DISTRO_ROOT" ]]; then
		echo "  PRoot Directory:      $DISTRO_ROOT"
	else
		echo "  PRoot Directory:      DOES NOT EXIST"
	fi
	if [[ -d "$ENGAGEMENT_DIR" ]]; then
		echo "  Engagement Directory: $ENGAGEMENT_DIR"
	else
		echo "  Engagement Directory: DOES NOT EXIST"
	fi
	if [[ -f "$SCRIPT" ]]; then
		echo "  Control Script:       $SCRIPT"
	else
		echo "  Control Script:       DOES NOT EXIST"
	fi
	echo ""
	exit 1
elif [[ $(pgrep --full --count proot) -gt 0 ]]; then
	echo "You can only run one engagement environment at a time. Currently running"
	echo "proot instances:"
	echo ""
	pgrep --full proot
	echo ""
	exit 1
fi

# Print help.
#
scriptHelp () {
	echo "Usage: $(basename "$0") COMMAND"
	echo ""
	echo "Interact with the $NAME engagement environment."
	echo ""
	echo "Available commands:"
	echo "  shell    Connect to a shell in the engagement environment"
	echo "  desktop  Connect to a desktop in the engagement environment"
	echo "  backup   Back up the engagement environment"
	echo "  restore  Restore the engagement environment from the most recent backup"
	echo "  archive  Archive the engagement to $ENGAGEMENT_DIR"
	echo "  delete   Remove all engagement data"
	echo ""
	echo "Note that only a single engagement environment may be run at a time."
}

# Connect to the engagement environment.
#
startCLI () {
	unNerfProotDistro
	updateTimeZone

	proot-distro login "$NAME" --user kali --bind ${ENGAGEMENT_DIR}:/home/kali/Documents -- /usr/local/sbin/tui.sh
}

startGUI () {
	unNerfProotDistro
	updateTimeZone

	termux-x11 :0 &> /dev/null &
	virgl_test_server_android --angle-gl &> /dev/null &
	pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
	am start-activity -W com.termux.x11/com.termux.x11.MainActivity

	proot-distro login "$NAME" --user kali --shared-tmp --bind ${ENGAGEMENT_DIR}:/home/kali/Documents -- /usr/local/sbin/gui.sh

	pkill -9 dbus

	pkill --full pulseaudio
	pkill --full virgl_test_server
	pkill --full com.termux.x11

	rm --recursive --force $PREFIX/tmp/dbus-*
	rm --recursive --force $PREFIX/tmp/.ICE-unix
	rm --recursive --force $PREFIX/tmp/*-kali
	rm --recursive --force $PREFIX/tmp/*-kali.*
	rm --recursive --force $PREFIX/tmp/*_kali
	rm --recursive --force $PREFIX/tmp/polybar*
	rm --recursive --force $PREFIX/tmp/proot-*
	rm --recursive --force $PREFIX/tmp/pulse-*
	rm --recursive --force $PREFIX/tmp/.virgl_test
	rm --recursive --force $PREFIX/tmp/.X0-lock
	rm --recursive --force $PREFIX/tmp/.X11-unix
}

# Archive engagement environment, PRoot Distro plugin, and control
# script in ENGAGEMENT_DIR.
#
archiveEngagement () {
	unNerfProotDistro

	prootBackup
	prootRemove

	echo ""
	echo "Engagement $NAME has been archived in $ENGAGEMENT_DIR."
}

# Remove all engagement data.
#
deleteEngagement () {
	echo "You are about to PERMENANTLY DELETE the engagement environment,"
	echo "PRoot plugin, control script, and data directory for $NAME. The"
	echo "following objects will be deleted:"
	echo ""
	echo "  PRoot Directory:      $DISTRO_ROOT"
	echo "  PRoot Plugin:         $PREFIX/etc/proot-distro/${NAME}.override.sh"
	echo "  Engagement Directory: $ENGAGEMENT_DIR"
	echo "  Control Script:       $SCRIPT"
	echo ""
	read -p "Please confirm by typing YES (all capitals): " CONFIRMATION

	if [[ "$CONFIRMATION" == "YES" ]]; then
		unNerfProotDistro
		prootRemove

		echo ">>>> Deleting engagement directory..."
		rm --recursive --force "$ENGAGEMENT_DIR"

		echo ""
		echo "Engagement $NAME has been deleted."
	else
		echo ""
		echo "Engagement deletion aborted."
	fi
}

# Back up the engagement environment in ENGAGEMENT_DIR.
#
backupEngagement () {
	unNerfProotDistro
	prootBackup
}

# Restore from the most recent backup.
#
restoreEngagement () {
	unNerfProotDistro
	if [[ $(ls -1 "$ENGAGEMENT_DIR/Backups"/*.proot.tar | wc -l) -gt 0 ]]; then

		RESTORE_TARGET="$(ls -1 "$ENGAGEMENT_DIR/Backups"/*.proot.tar | sort | tail -1)"

		proot-distro restore "$RESTORE_TARGET"

		if [[ $(ls -1 "$ENGAGEMENT_DIR/Backups"/*.proot.sh | wc -l) -gt 0 ]]; then
			RESTORE_TARGET="$(ls -1 "$ENGAGEMENT_DIR/Backups"/*.proot.sh | sort | tail -1)"
			cp "$RESTORE_TARGET" "$SCRIPT"
			chmod 755 "$SCRIPT"
		fi

		if [[ $(ls -1 "$ENGAGEMENT_DIR/Backups"/*.proot.widget | wc -l) -gt 0 ]]; then
			RESTORE_TARGET="$(ls -1 "$ENGAGEMENT_DIR/Backups"/*.proot.widget | sort | tail -1)"
			mkdir --parents $HOME/.shortcuts/tasks
			cp "$RESTORE_TARGET" $HOME/.shortcuts/tasks/"${NAME}.sh"
			chmod 755 $HOME/.shortcuts/tasks/"${NAME}.sh"
		fi

		if [[ $(ls -1 "$ENGAGEMENT_DIR/Backups"/*.proot.png | wc -l) -gt 0 ]]; then
			RESTORE_TARGET="$(ls -1 "$ENGAGEMENT_DIR/Backups"/*.proot.png | sort | tail -1)"
			mkdir --parents $HOME/.shortcuts/icons
			cp "$RESTORE_TARGET" $HOME/.shortcuts/icons/"${NAME}.sh.png"
		fi

		echo ""
		echo "Engagement $NAME has been restored from the backup at $(ls -1 "$ENGAGEMENT_DIR/Backups"/*.proot.tar | sort | tail -1)."
	else
		echo "No backups found in $ENGAGEMENT_DIR/Backups!"
	fi
}

# Helper function that actually performs the environment backup.
#
prootBackup () {
	TIMESTAMP=$(date "+%Y-%m-%d-%H-%M-%S")
	BACKUP_DIR="$ENGAGEMENT_DIR/Backups"
	PROOT_BACKUP_FILE="$BACKUP_DIR/$NAME.$TIMESTAMP.proot.tar"
	ENVCTL_BACKUP_FILE="$BACKUP_DIR/$NAME.$TIMESTAMP.proot.sh"
	WIDGET_SH_BACKUP_FILE="$BACKUP_DIR/$NAME.$TIMESTAMP.proot.widget"
	WIDGET_PNG_BACKUP_FILE="$BACKUP_DIR/$NAME.$TIMESTAMP.proot.png"

	mkdir --parents "$BACKUP_DIR"
	proot-distro backup --output "$PROOT_BACKUP_FILE" "$NAME"
	cp "$SCRIPT" "$ENVCTL_BACKUP_FILE"
	cp $HOME/.shortcuts/tasks/"${NAME}.sh" "$WIDGET_SH_BACKUP_FILE"
	cp $HOME/.shortcuts/icons/"${NAME}.sh.png" "$WIDGET_PNG_BACKUP_FILE"
}

# Helper function that removes PRoot data.
#
prootRemove () {
	proot-distro remove "$NAME"

	rm --force $HOME/.shortcuts/icons/"${NAME}.sh.png"
	rm --force $HOME/.shortcuts/tasks/"${NAME}.sh"
	rm --force "$SCRIPT"
}

# Helper function that updates the guest's timezone.
#
updateTimeZone () {
	proot-distro login "$NAME" -- bash -c "ln --symbolic --force /usr/share/zoneinfo/$(getprop persist.sys.timezone) /etc/localtime"
}

# PRoot Distro engages in some serious nannying around pentesting
# distros. While I understand the Termux project's desire not to support
# script-kiddies, and support their refusal to include hacking tools
# (even if it makes my life harder), actively subverting user requests
# is, in my opinion, a step too far.
#
#     https://github.com/termux/proot-distro/commit/470525c55020d72b66b509066b8d71d59b62072c
#
# Helper function to proactively un-nerf pentest capabilities (even
# though we probably won't need that functionality ourselves in most
# cases).
#
unNerfProotDistro () {
	sed -i 's/if .*(kali|parrot|nethunter|blackarch).*; then/if false; then/' $(which proot-distro)
}

# Flow control.
#
case "$1" in
	"shell")
		startCLI
		;;
	"desktop")
		startGUI
		;;
	"backup")
		backupEngagement
		;;
	"restore")
		restoreEngagement
		;;
	"archive")
		archiveEngagement
		;;
	"delete")
		deleteEngagement
		;;
	*)
		scriptHelp
		;;
esac
