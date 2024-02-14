#!/usr/bin/env bash

NAME="{{environment-name}}"

# Core engagement files/data.
#
SCRIPT="$HOME/.local/bin/${NAME}.sh"
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
elif [[ $(pgrep -c proot) -gt 0 ]]; then
	echo "You can only run one engagement environment at a time."
	echo ""
	echo "    $(pgrep -a proot)"
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
	if [[ -n "$TMUX" ]]; then
		proot-distro login "$NAME" --user kali --bind ${ENGAGEMENT_DIR}:/home/kali/Documents -- env TMUX="TMUX" /usr/local/bin/tui.sh
	else
		proot-distro login "$NAME" --user kali --bind ${ENGAGEMENT_DIR}:/home/kali/Documents -- /usr/local/bin/tui.sh
	fi
}

startGUI () {
	export DISPLAY=:0
	export GALLIUM_DRIVER=virpipe
	export MESA_GL_VERSION_OVERRIDE=4.0

	virgl_test_server_android &
	termux-x11 :0 &

	proot-distro login "$NAME" --user kali --shared-tmp --bind ${ENGAGEMENT_DIR}:/home/kali/Documents -- /usr/local/bin/gui.sh

	pkill termux-x11
	pkill virgl_test_server_android
}

# Archive engagement environment, PRoot Distro plugin, and control script in ENGAGEMENT_DIR.
#
archiveEngagement () {
	prootBackup

	echo ">>>> Archiving PRoot Distro plugin..."
	mv --force "$PREFIX/etc/proot-distro/${NAME}.sh" "$ENGAGEMENT_DIR/${NAME}.plugin.sh"

	echo ">>>> Archiving this control script..."
	mv --force "$SCRIPT" "$ENGAGEMENT_DIR"/

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
	echo "  PRoot Plugin:         $PREFIX/etc/proot-distro/{$NAME}.sh"
	echo "  Engagement Directory: $ENGAGEMENT_DIR"
	echo "  Control Script:       $SCRIPT"
	echo ""
	read -p "Please confirm by typing YES (all capitals): " CONFIRMATION

	if [[ "$CONFIRMATION" == "YES" ]]; then
		echo ">>>> Deleting PRoot data..."
		proot-distro remove "$NAME"
		rm --force $PREFIX/etc/proot-distro/{$NAME}.sh
		echo ">>>> Deleting engagement directory..."
		rm --recursive --force "$ENGAGEMENT_DIR"
		echo ">>>> Deleting this control script..."
		rm --force "$SCRIPT"

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
	prootBackup

	echo ""
	echo "Engagement $NAME has been backed up in $BACKUP_DIR."
}

# Restore from the most recent backup.
#
restoreEngagement () {
	if [[ -f "$ENGAGEMENT_DIR/Backups/$NAME.tar" ]]; then
		echo ">>>> Restoring environment..."
		proot-distro restore "$ENGAGEMENT_DIR/Backups/$NAME.tar"

		echo ""
		echo "Engagement $NAME has been restored from the backup at $ENGAGEMENT_DIR/Backups/$NAME.tar."
	else
		echo "No backup found at $ENGAGEMENT_DIR/Backups/$NAME.tar!"
	fi
}

# Helper function that actually performs the environment backup.
#
prootBackup () {
	TIMESTAMP=$(date "+%Y-%m-%d-%H-%M-%S")
	BACKUP_DIR="$ENGAGEMENT_DIR/Backups"
	BACKUP_FILE="$BACKUP_DIR/$NAME.$TIMESTAMP.tar"

	echo ">>>> Backing up PRoot environment..."
	mkdir --parents "$BACKUP_DIR"
	proot-distro backup --output "$BACKUP_FILE" "$NAME"
	ln -sf "$BACKUP_FILE" "$BACKUP_DIR/$NAME.tar"
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
