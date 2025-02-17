#!/data/data/com.termux/files/usr/bin/bash

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
fi

# Print help.
#
scriptHelp () {
	echo "Usage: $(basename "$0") COMMAND"
	echo ""
	echo "Interact with the $NAME engagement environment."
	echo ""
	echo "Available commands:"
	echo "  app      Launch an app in the engagement environment"
	echo "  shell    Connect to a shell in the engagement environment"
	echo "  backup   Back up the engagement environment"
	echo "  restore  Restore the engagement environment from the most recent backup"
	echo "  archive  Archive the engagement to $ENGAGEMENT_DIR"
}

# Connect to the engagement environment.
#
# FIXME - Add MESA_LOADER_DRIVER_OVERRIDE=zink to ADDITIONAL_ENVIRONMENT
# once the zink MESA driver is available in Kali
#
launchApp () {
	unNerfProotDistro
	updateTimeZone

	ADDITIONAL_ENVIRONMENT=()
	if [[ -n "$DISPLAY" ]]; then
		ADDITIONAL_ENVIRONMENT+=(--env DISPLAY=$DISPLAY)
		ADDITIONAL_ENVIRONMENT+=(--env QT_QPA_PLATFORMTHEME=qt6ct)
		ADDITIONAL_ENVIRONMENT+=(--env TU_DEBUG=noconform)
	fi
	if [[ -n "$PULSE_SERVER" ]]; then
		ADDITIONAL_ENVIRONMENT+=(--env PULSE_SERVER=$PULSE_SERVER)
	fi

	proot-distro login "$NAME" \
		--user kali \
		--env LANG=en_US.UTF-8 \
		--env SHELL=/usr/bin/zsh \
		--env TMUX_TMPDIR=/home/kali/.tmux \
		--no-arch-warning \
		--shared-tmp \
		--bind ${ENGAGEMENT_DIR}:/home/kali/Documents \
		"${ADDITIONAL_ENVIRONMENT[@]}" -- "${@:2}"
}

startCLI () {
	unNerfProotDistro
	updateTimeZone

	proot-distro login "$NAME" \
		--user kali \
		--env LANG=en_US.UTF-8 \
		--env SHELL=/usr/bin/zsh \
		--env TMUX_TMPDIR=/home/kali/.tmux \
		--no-arch-warning \
		--shared-tmp \
		--bind ${ENGAGEMENT_DIR}:/home/kali/Documents \
		-- /usr/local/sbin/tui.sh
}

# Update the engagement environment.
#
updateEngagement () {
	unNerfProotDistro
	updateTimeZone

	proot-distro login "$NAME" \
		--user kali \
		--env LANG=en_US.UTF-8 \
		--env SHELL=/usr/bin/zsh \
		--no-arch-warning \
		--shared-tmp \
		--bind ${ENGAGEMENT_DIR}:/home/kali/Documents \
		-- /usr/local/bin/update.sh
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

	mkdir --parents "$BACKUP_DIR"
	proot-distro backup --output "$PROOT_BACKUP_FILE" "$NAME"
	cp "$SCRIPT" "$ENVCTL_BACKUP_FILE"
}

# Helper function that removes PRoot data.
#
prootRemove () {
	proot-distro remove "$NAME"

	rm --force "$SCRIPT"
}

# Helper function that updates the guest's timezone.
#
updateTimeZone () {
	proot-distro login "$NAME" --no-arch-warning -- bash -c "ln --symbolic --force /usr/share/zoneinfo/$(getprop persist.sys.timezone) /etc/localtime"
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
	"app")
		launchApp
		;;
	"shell")
		startCLI
		;;
	"update")
		updateEngagement
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
	*)
		scriptHelp
		;;
esac
