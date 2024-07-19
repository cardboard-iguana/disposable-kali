#!/usr/bin/env bash

NAME="{{environment-name}}"
TOKEN="{{connection-token}}"

# Flow control.
#
case "$1" in
	"launcher")
		CONTROL_FUNCTION="desktopLauncher"
		;;
	"start")
		CONTROL_FUNCTION="startEngagement"
		;;
	"stop")
		CONTROL_FUNCTION="stopEngagement"
		;;
	"shell")
		CONTROL_FUNCTION="startCLI"
		;;
	"desktop")
		CONTROL_FUNCTION="startGUI"
		;;
	"backup")
		CONTROL_FUNCTION="backupEngagement"
		;;
	"restore")
		CONTROL_FUNCTION="restoreEngagement"
		;;
	"archive")
		CONTROL_FUNCTION="archiveEngagement"
		;;
	"delete")
		CONTROL_FUNCTION="deleteEngagement"
		;;
	*)
		CONTROL_FUNCTION="scriptHelp"
		;;
esac

# Print help and exit.
#
# Print help.
#
if [[ "$CONTROL_FUNCTION" == "scriptHelp" ]]; then
	echo "Usage: $(basename "$0") COMMAND"
	echo ""
	echo "Interact with the $NAME engagement environment."
	echo ""
	echo "Available commands:"
	echo "  start    Start the engagement's container"
	echo "  stop     Stop the engagement's container"
	echo "  shell    Connect to a shell in the engagement's container"
	echo "  desktop  Connect to a desktop in the engagement's container"
	echo "  backup   Commit changes to the underlying image and back it up"
	echo "  restore  Restore an image/container pair from the most recent backup"
	echo "  archive  Archive the engagement to $ENGAGEMENT_DIR"
	echo "  delete   Remove all engagement data"

	exit
fi

# Start the Podman VM, if necessary.
#
if [[ "$(uname)" == "Darwin" ]]; then
	if [[ $(podman machine list --format "{{.Running}}" | grep -c "true") -eq 0 ]]; then
		osascript -e "display dialog \"Starting the Podman virtual machine...\n\" buttons {\"Dismiss\"} with title \"Engagement $NAME\" with icon POSIX file \"$HOME/Applications/${NAME}.app/${NAME}.icns\"" &> /dev/null &

		echo ">>>> Starting Podman virtual machine..."
		podman machine start --no-info

		osascript -e "tell application \"System Events\" to click UI Element \"Dismiss\" of window \"Engagement $NAME\" of application process \"osascript\"" &> /dev/null
	fi
fi

# Core engagement files/data.
#
SCRIPT="$HOME/.local/bin/${NAME}.sh"
ENGAGEMENT_DIR="$HOME/Engagements/$NAME"
ID="$(podman container inspect --format "{{.ID}}" "$NAME" 2> /dev/null)"
STATE="$(podman container inspect --format "{{.State.Status}}" "$NAME" 2> /dev/null)"

# Sanity check environment.
#
if [[ "$1" == "restore" ]] && [[ -d "$ENGAGEMENT_DIR" ]]; then
	SANITY="100%"
elif [[ -n "$ID" ]] && [[ -d "$ENGAGEMENT_DIR" ]] && [[ -f "$SCRIPT" ]]; then
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
	if [[ -n "$ID" ]]; then
		echo "  Podman Container:     $NAME ($ID)"
	else
		echo "  Podman Container:     DOES NOT EXIST"
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

# Update the Podman VM, if necessary.
#
if [[ "$(uname)" == "Darwin" ]] && [[ "$CONTAINER_STATE" != "running" ]]; then
	if [[ -f $HOME/.cache/disposable-kali/machine-update ]]; then
		LAST_UPDATE="$(cat $HOME/.cache/disposable-kali/machine-update)"
	else
		LAST_UPDATE=0
	fi
	if [[ $(( $(date "+%s") - $LAST_UPDATE )) -ge $(( 7 * 24 * 60 * 60 )) ]]; then
		osascript -e "display dialog \"Updating the Podman virtual machine. Please wait...\n\" buttons {\"Dismiss\"} with title \"Engagement $NAME\" with icon POSIX file \"$HOME/Applications/${NAME}.app/${NAME}.icns\"" &> /dev/null &

		echo ">>>> Upgrading Podman virtual machine..."
		podman machine ssh 'sudo rpm-ostree upgrade'
		podman machine stop
		podman machine start --no-info

		mkdir -p $HOME/.cache/disposable-kali
		date "+%s" > $HOME/.cache/disposable-kali/machine-update

		osascript -e "tell application \"System Events\" to click UI Element \"Dismiss\" of window \"Engagement $NAME\" of application process \"osascript\"" &> /dev/null
	fi
fi

#### Control functions ################################################

# Start/Stop container.
#
startEngagement () {
	mkdir -p $HOME/.cache/disposable-kali
	readlink /etc/localtime | sed 's#.*/zoneinfo/##' > $HOME/.cache/disposable-kali/localtime

	if [[ "$STATE" != "running" ]]; then
		podman start "$NAME"
		waitForIt
		echo "ready"
	fi
}

stopEngagement () {
	if [[ "$(uname)" == "Darwin" ]]; then
			osascript -e "display dialog \"Waiting for the container to shut down...\n\" buttons {\"Dismiss\"} with title \"Stopping Engagement $NAME\" with icon POSIX file \"$HOME/Applications/${NAME}.app/${NAME}.icns\"" &> /dev/null &

			if [[ "$CONTAINER_STATE" == "running" ]]; then
				stopContainer
			fi
			stopMachine

			osascript -e "tell application \"System Events\" to click UI Element \"Dismiss\" of window \"Stopping Engagement $NAME\" of application process \"osascript\"" &> /dev/null
	else
		if [[ "$CONTAINER_STATE" == "running" ]]; then
			if [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
				# Can't call stopContainer in a subshell...
				(
					echo ">>>> Stopping container..."
					podman stop "$NAME"
				) | zenity --title="Stopping Engagement $NAME" \
				           --icon=$HOME/.local/share/icons/"${NAME}.png" \
				           --text="Waiting for the container to shut down..." \
				           --progress --pulsate --auto-close --no-cancel &> /dev/null
			else
				stopContainer
			fi
		fi
	fi
}

# Connect to the engagement container.
#
startCLI () {
	startEngagement

	podman exec --tty --interactive --user $USER --workdir /home/$USER "$NAME" /usr/bin/bash
}

startGUI () {
	startEngagement

	if [[ "$(uname)" == "Darwin" ]]; then
		mkdir -p $HOME/.cache/disposable-kali

		cat > $HOME/.cache/disposable-kali/kali.rdp <<- EOF
		smart sizing:i:1
		screen mode id:i:2
		prompt for credentials on client:i:1
		redirectsmartcards:i:0
		redirectclipboard:i:1
		forcehidpioptimizations:i:0
		full address:s:127.0.0.1
		drivestoredirect:s:*
		networkautodetect:i:0
		redirectprinters:i:0
		autoreconnection enabled:i:1
		session bpp:i:16
		audiomode:i:0
		bandwidthautodetect:i:1
		connection type:i:7
		dynamic resolution:i:1
		username:s:$USER
		allow font smoothing:i:1
		EOF

		open $HOME/.cache/disposable-kali/kali.rdp

		osascript - <<- EOF
		tell application "Microsoft Remote Desktop"
			activate
			tell application "System Events"
				repeat until (exists window "Microsoft Remote Desktop" of application process "Microsoft Remote Desktop")
					delay 1
				end repeat
			end tell
			delay 1
			activate
		end tell

		tell application "System Events" to keystroke "$TOKEN"

		tell application "System Events" to click UI element "Continue" of sheet 1 of window "kali - 127.0.0.1" of application process "Microsoft Remote Desktop"
		EOF
	else
		if [[ -n "$WAYLAND_DISPLAY" ]] && [[ -n "$(which wlfreerdp)" ]]; then
			FREERDP=wlfreerdp
		else
			FREERDP=xfreerdp
		fi
		$FREERDP /bpp:16 /dynamic-resolution /f /p:"$TOKEN" /rfx /u:"$USER" /v:127.0.0.1:3389
	fi
}

# Desktop launcher functionality.
#
desktopLauncher () {
	if [[ "$CONTAINER_STATE" == "running" ]]; then
		if [[ "$(uname)" == "Darwin" ]]; then
			osascript -e "display dialog \"Checking RDP connection state...\n\" buttons {\"Dismiss\"} with title \"Engagement $NAME\" with icon POSIX file \"$HOME/Applications/${NAME}.app/${NAME}.icns\"" &> /dev/null &

			read -r -d '' APPLESCRIPT <<- EOF
			tell application "System Events"
				if application process "Microsoft Remote Desktop" exists then
					if menu item "kali - 127.0.0.1" of menu 1 of menu bar item "Window" of menu bar 1 of application process "Microsoft Remote Desktop" exists then
						return "connected"
					else
						return "disconnected"
					end if
				else
					return "disconnected"
				end if
			end tell
			EOF
			RDP_STATE="$(echo "$APPLESCRIPT" | osascript -)"

			osascript -e "tell application \"System Events\" to click UI Element \"Dismiss\" of window \"Engagement $NAME\" of application process \"osascript\"" &> /dev/null
		else
			if [[ $(ps auxww | grep freerdp | grep -c '/v:127.0.0.1:3389') -gt 0 ]]; then
				RDP_STATE="connected"
			else
				RDP_STATE="disconnected"
			fi
		fi

		if [[ "$RDP_STATE" == "connected" ]]; then
			STATE_MESSAGE="currently running and connected"
			ENABLE_START="no"
			ENABLE_STOP="yes"
		else
			STATE_MESSAGE="currently running and disconnected"
			ENABLE_START="yes"
			ENABLE_STOP="yes"
		fi
	else
		STATE_MESSAGE="not running"
		ENABLE_START="yes"
		ENABLE_STOP="no"
	fi

	if [[ "$(uname)" == "Darwin" ]]; then
		ACTION="$(osascript -e "display dialog \"The engagement is $STATE_MESSAGE.\n\" buttons {\"Connect to Engagement\",\"Stop Engagement\",\"Cancel\"} with title \"Engagement $NAME\" with icon POSIX file \"$HOME/Applications/${NAME}.app/${NAME}.icns\" default button \"Cancel\" cancel button \"Cancel\"" 2> /dev/null | sed 's#^button returned:##')"
	elif [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
		ACTION="$(zenity --title="Engagement $NAME" --icon=$HOME/.local/share/icons/"${NAME}.png" --text="The engagement is $STATE_MESSAGE." --question --switch --extra-button="Connect to Engagement" --extra-button="Stop Engagement" --extra-button="Cancel" 2> /dev/null)"
	else
		ACTION="Cancel"
	fi

	if [[ "$ACTION" == "Connect to Engagement" ]]; then
		startGUI
	elif [[ "$ACTION" == "Stop Engagement" ]]; then
		stopEngagement
	else
		echo "Canceled"
	fi
}

# Archive container and control script in ENGAGEMENT_DIR.
#
archiveEngagement () {
	stopContainer
	commitToImage
	removeContainerImagePair
	stopMachine

	echo ""
	echo "Engagement $NAME has been archived in $ENGAGEMENT_DIR."
}

# Remove all engagement data.
#
deleteEngagement () {
	echo "You are about to PERMENANTLY DELETE the container, control script,"
	echo "and data directory for $NAME. The following objects will be deleted:"
	echo ""
	echo "  Podman Container:     $NAME ($ID)"
	echo "  Engagement Directory: $ENGAGEMENT_DIR"
	echo "  Control Script:       $SCRIPT"
	echo ""
	read -p "Please confirm by typing YES (all capitals): " CONFIRMATION

	if [[ "$CONFIRMATION" == "YES" ]]; then
		stopContainer
		removeContainerImagePair
		stopMachine

		echo ">>>> Deleting engagement directory..."
		rm -rf "$ENGAGEMENT_DIR"

		echo ""
		echo "Engagement $NAME has been deleted."
	else
		echo ""
		echo "Engagement deletion aborted."
	fi
}

# Back up the container in ENGAGEMENT_DIR.
#
backupEngagement () {
	stopContainer
	commitToImage
	stopMachine

	echo ""
	echo "Engagement $NAME has been backed up in $BACKUP_DIR."
}

# Restore from the most recent backup.
#
restoreEngagement () {
	if [[ -f "$ENGAGEMENT_DIR/Backups/$NAME.tar" ]]; then
		if [[ "$CONTAINER_STATE" == "running" ]]; then
			stopContainer
		fi
		removeContainerImagePair

		echo ">>>> Restoring image..."
		podman load --input "$ENGAGEMENT_DIR/Backups/$NAME.tar"

		echo ">>>> Fixing image tag..."
		CURRENT_TAG="$(podman images --format "{{.Tag}}" "$NAME")"
		podman image tag "$NAME:$CURRENT_TAG" "$NAME:latest"
		podman rmi "$NAME:$CURRENT_TAG"

		echo ">>>> Recreating container..."
		mkdir -p $HOME/.cache/disposable-kali
		readlink /etc/localtime | sed 's#.*/zoneinfo/##' > $HOME/.cache/disposable-kali/localtime

		podman create --name "$NAME" \
		              --publish 127.0.0.1:3389:3389 \
		              --tty \
		              --mount type=bind,source="$ENGAGEMENT_DIR",destination=/home/$USER/Documents \
		              --mount type=bind,source=$HOME/.cache/disposable-kali/localtime,destination=/etc/localtime.host,readonly \
		                "$NAME"

		if [[ -f "$ENGAGEMENT_DIR/Backups/$NAME.sh" ]]; then
			mkdir -p "$(dirname "$SCRIPT")"
			cp -L "$ENGAGEMENT_DIR/Backups/$NAME.sh" "$SCRIPT"
		fi
		if [[ "$(uname)" == "Darwin" ]]; then
			if [[ -f "$ENGAGEMENT_DIR/Backups/${NAME}.app.tar.gz" ]]; then
				mkdir -p "$HOME/Applications"
				(
					cd "$ENGAGEMENT_DIR/Backups"
					tar -xzf "Backups/${NAME}.app.tar.gz"
					mv "${NAME}.app" "$HOME/Applications/"
				)
				dockutil --add $HOME/Applications/"${NAME}.app"
			fi
		else
			if [[ -f "$ENGAGEMENT_DIR/Backups/$NAME.png" ]]; then
				mkdir -p "$HOME/.local/share/icons"
				cp -L "$ENGAGEMENT_DIR/Backups/$NAME.png" "$HOME/.local/share/icons/${NAME}.png"
			fi
			if [[ -f "$ENGAGEMENT_DIR/Backups/$NAME.desktop" ]]; then
				mkdir -p "$HOME/.local/share/applications"
				cp -L "$ENGAGEMENT_DIR/Backups/$NAME.desktop" "$HOME/.local/share/icons/${NAME}.desktop"
			fi
		fi

		stopMachine

		echo ""
		echo "Engagement $NAME has been restored from the backup at $ENGAGEMENT_DIR/Backups/$NAME.tar."
	else
		echo "No backup found at $ENGAGEMENT_DIR/Backups/$NAME.tar!"
	fi
}

#### Internal helper functions ########################################

# Stop the Podman machine if there are no other running containers.
#
stopMachine () {
	if [[ "$(uname)" == "Darwin" ]]; then
		if [[ $(podman container list --format "{{.State}}" | grep -c "running") -eq 0 ]]; then
			echo ">>>> Stopping Podman virtual machine..."
			podman machine stop
		fi
	fi
}

# Stop the current container. 
#
stopContainer () {
	echo ">>>> Stopping container..."
	podman stop "$NAME"
}

# Commit changes in a container to the underlying image and exports the
# results.
#
commitToImage () {
	echo ">>>> Committing changes to temporary image..."
	TIMESTAMP=$(date "+%Y-%m-%d-%H-%M-%S")
	podman commit --author "Backup for $(date) by $USER" "$NAME" "$NAME:$TIMESTAMP"

	echo ">>>> Exporting temporary image..."
	BACKUP_DIR="$ENGAGEMENT_DIR/Backups"
	BACKUP_FILE="$BACKUP_DIR/$NAME.$TIMESTAMP.tar"
	mkdir -p "$BACKUP_DIR"
	podman save --output "$BACKUP_FILE" "${NAME}:${TIMESTAMP}"
	ln -sf "$BACKUP_FILE" "$BACKUP_DIR/$NAME.tar"

	echo ">>>> Exporting control files..."
	cp "$SCRIPT" "$BACKUP_DIR/${NAME}.${TIMESTAMP}.sh"
	ln -sf "$BACKUP_DIR/${NAME}.${TIMESTAMP}.sh" "$BACKUP_DIR/$NAME.sh"

	if [[ "$(uname)" == "Darwin" ]]; then
		(
			cd "$HOME/Applications"
			tar -czf "$BACKUP_DIR/${NAME}.app.${TIMESTAMP}.tar.gz" "${NAME}.app"
		)
		ln -sf "$BACKUP_DIR/${NAME}.app.${TIMESTAMP}.tar.gz" "$BACKUP_DIR/${NAME}.app.tar.gz"
	else
		cp "$HOME/.local/share/applications/${NAME}.desktop" "$BACKUP_DIR/${NAME}.${TIMESTAMP}.desktop"
		ln -sf "$BACKUP_DIR/${NAME}.${TIMESTAMP}.desktop" "$BACKUP_DIR/$NAME.desktop"

		cp "$HOME/.local/share/icons/${NAME}.png" "$BACKUP_DIR/${NAME}.${TIMESTAMP}.png"
		ln -sf "$BACKUP_DIR/${NAME}.${TIMESTAMP}.png" "$BACKUP_DIR/$NAME.png"
	fi

	echo ">>>> Removing temporary image..."
	podman rmi --force "${NAME}:${TIMESTAMP}"
}

# Cleaning up the container/image pair.
#
removeContainerImagePair () {
	echo ">>>> Removing container..."
	podman rm --force --volumes "$NAME"

	echo ">>>> Removing underlying image..."
	podman rmi --force "$NAME"

	echo ">>>> Pruning images to remove dangling references..."
	podman image prune --force > /dev/null

	echo ">>>> Removing control files..."
	rm -f "$SCRIPT"
	if [[ "$(uname)" == "Darwin" ]]; then
		rm -rf "$HOME/Applications/${NAME}.app"
		dockutil --remove $HOME/Applications/"${NAME}.app" 2> /dev/null
	else
		rm -f "$HOME/.local/share/applications/${NAME}.desktop"
		rm -f "$HOME/.local/share/icons/${NAME}.png"
	fi
}

# Sleep briefly to give the container a chance to finish booting.
#
waitForIt () {
	SECONDS=12
	echo -n ">>>> Sleeping briefly"
	if [[ "$(uname)" == "Darwin" ]]; then
		osascript -e "display dialog \"Waiting $SECONDS seconds for the container to finish booting...\" buttons {\"Dismiss\"} with title \"Starting Engagement $NAME\" with icon POSIX file \"$HOME/Applications/${NAME}.app/${NAME}.icns\" giving up after $SECONDS" &> /dev/null &
	else
		if [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
			(
				for STEP in $(seq 1 $SECONDS); do
					sleep 1
					echo $(( $STEP * 100 / $SECONDS ))
				done
			) | zenity --title=$NAME \
		               --window-icon=$HOME/.local/share/icons/"${NAME}.png" \
			           --text="Waiting $SECONDS seconds for the container to finish booting..." \
			           --progress --pulsate --auto-close --no-cancel &> /dev/null &
		fi
	fi
	for STEP in $(seq 1 $SECONDS); do
		sleep 1
		echo -n "."
	done
	echo ""
}

#### Exec control function ############################################

$CONTROL_FUNCTION
