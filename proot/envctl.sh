#!/data/data/com.termux/files/usr/bin/bash

NAME="{{environment-name}}"

# Core engagement files/data.
#
SCRIPT="$HOME/bin/${NAME}"
ENGAGEMENT_DIR="$HOME/storage/shared/Documents/Engagements/$NAME"
DISTRO_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/$NAME"

# Sanity check environment.
#
if [[ "$1" == "--restore" ]] || [[ "$1" == "-r" ]] && [[ -d "$ENGAGEMENT_DIR" ]]; then
	SANITY="100%"
elif [[ -d "$DISTRO_ROOT" ]] && [[ -d "$ENGAGEMENT_DIR" ]] && [[ -f "$SCRIPT" ]]; then
	SANITY="100%"
elif [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ -z "$1" ]]; then
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
	echo "Usage: $(basename "$0") <OPTION OR COMMAND>"
	echo ""
	echo "Interact with the $NAME engagement environment."
	echo ""
	echo "Available options:"
	echo "  --help,    -h  Display this help message"
	echo "  --update,  -u  Update the packages installed in the engagement"
	echo "  --backup,  -b  Back up the engagement"
	echo "  --restore, -r  Restore the engagement from the most recent backup"
	echo "  --archive, -a  Archive the engagement to $ENGAGEMENT_DIR"
	echo ""
	echo "If no options are provided, the remainder of the command line is"
	echo "interpreted as a command (with its own options) to run in the engagement"
	echo "environment."
	echo ""
	echo "If no option OR command is provided, a tmux shell will be opened in the"
	echo "engagement environment."
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
		"${ADDITIONAL_ENVIRONMENT[@]}" -- "$@"
}

startCLI () {
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
		"${ADDITIONAL_ENVIRONMENT[@]}" -- /usr/local/sbin/tui
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
		-- /usr/local/bin/update
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
	if [[ $(ls -1 "$ENGAGEMENT_DIR/Backups"/$NAME.*.proot.tar | wc -l) -gt 0 ]]; then

		RESTORE_TARGET="$(ls -1 "$ENGAGEMENT_DIR/Backups"/*.proot.tar | sort | tail -1)"
		RESTORE_TIMESTAMP="$(basename "$RESTORE_TARGET" .proot.tar | sed "s/^.*\.//")"

		proot-distro restore "$RESTORE_TARGET"

		if [[ -f "$ENGAGEMENT_DIR/Backups"/$NAME.$RESTORE_TIMESTAMP.proot.sh ]]; then
			cp "$ENGAGEMENT_DIR/Backups"/$NAME.$RESTORE_TIMESTAMP.proot.sh "$SCRIPT"
			chmod 755 "$SCRIPT"
		fi

		mkdir --parents $HOME/.local/share/applications
		for DESKTOP_FILE in $(ls -1 "$ENGAGEMENT_DIR/Backups"/${NAME}-*.$RESTORE_TIMESTAMP.proot.desktop); do
			DESKTOP_FILE_NAME="$(basename "$DESKTOP_FILE" .$RESTORE_TIMESTAMP.proot.desktop)"
			cp "$DESKTOP_FILE" $HOME/.local/share/applications/$DESKTOP_FILE_NAME.desktop
		done

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

	for DESKTOP_FILE in $(ls -1 $HOME/.local/share/applications/${NAME}-*.desktop); do
		DESKTOP_FILE_NAME="$(basename "$DESKTOP_FILE" .desktop)"
		cp "$DESKTOP_FILE" "$BACKUP_DIR/$DESKTOP_FILE_NAME.$TIMESTAMP.proot.desktop"
	done
}

# Helper function that removes PRoot data.
#
prootRemove () {
	proot-distro remove "$NAME"

	rm --force "$SCRIPT"
	rm --force $HOME/.local/share/applications/${NAME}-*.desktop
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
	"--update"|"-u")
		updateEngagement
		;;
	"--backup"|"-b")
		backupEngagement
		;;
	"--restore"|"-r")
		restoreEngagement
		;;
	"--archive"|"-a")
		archiveEngagement
		;;
	"--help"|"-h")
		scriptHelp
		;;
	*)
		if [[ -z "$1" ]]; then
			startCLI
		else
			launchApp "$@"
		fi
		;;
esac
