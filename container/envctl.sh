#!/usr/bin/env bash

set -e

NAME="{{environment-name}}"
TOKEN="{{connection-token}}"
OS="$(uname)"
WAIT=12

# Core engagement files/data.
#
SCRIPT="$HOME/.local/bin/${NAME}"
ENGAGEMENT_DIR="$HOME/Engagements/$NAME"

# Flow control.
#
case "$1" in
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
	"update")
		CONTROL_FUNCTION="updateEngagement"
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
	*)
		CONTROL_FUNCTION="scriptHelp"
		;;
esac

# Print help and exit.
#
if [[ "$CONTROL_FUNCTION" == "scriptHelp" ]]; then
	echo "Usage: $(basename "$0") COMMAND"
	echo ""
	echo "Interact with the $NAME engagement environment."
	echo ""
	echo "Available commands:"
	echo "  help     Display this help message"
	echo "  start    Start engagement"
	echo "  stop     Stop engagement"
	echo "  shell    Connect to a shell in the engagement"
	echo "  desktop  Connect to a desktop in the engagement"
	echo "  update   Update the packages installed in the engagement"
	echo "  backup   Commit changes to the underlying image and back it up"
	echo "  restore  Restore an image/container pair from the most recent backup"
	echo "  archive  Archive the engagement to $ENGAGEMENT_DIR"

	exit
fi

# Figure out which podman we're using.
#
if [[ "$OS" == "Darwin" ]]; then
	PODMAN="$(which podman 2> /dev/null)"
else
	if [[ -x "$HOME/.cache/disposable-kali/podman-launcher" ]]; then
		if [[ -f "$HOME/.cache/disposable-kali/podman-launcher.podman.version" ]]; then
			PODMAN_LAUNCHER_PODMAN_VERSION="$(cat "$HOME/.cache/disposable-kali/podman-launcher.podman.version")"
		else
			PODMAN_LAUNCHER_PODMAN_VERSION="$("$HOME/.cache/disposable-kali/podman-launcher" version | grep '^Version: .*' | sed 's/.* //')"
			echo "$PODMAN_LAUNCHER_PODMAN_VERSION" > "$HOME/.cache/disposable-kali/podman-launcher.podman.version"
		fi

		if [[ -n "$(which podman 2> /dev/null)" ]]; then
			SYSTEM_PODMAN_VERSION="$(podman version | grep '^Version: .*' | sed 's/.* //')"
		else
			SYSTEM_PODMAN_VERSION="0.0.0"
		fi

		MOST_RECENT_VERSION="$(echo -e "${SYSTEM_PODMAN_VERSION}\n${PODMAN_LAUNCHER_PODMAN_VERSION}" | sort --version-sort --reverse | head -1)"

		if [[ "$MOST_RECENT_VERSION" == "$SYSTEM_PODMAN_VERSION" ]]; then
			PODMAN="$(which podman)"
		else
			PODMAN="$HOME/.cache/disposable-kali/podman-launcher"
		fi
	else
		PODMAN="$(which podman 2> /dev/null)"
	fi
fi

if [[ -z "$PODMAN" ]]; then
	echo "No usable install of Podman found!"
	exit 1
fi

# Attempt to recover from a bad shutdown, which seems to be a
# frequent issue with podman < 5.0.0 on Linux.
#
if [[ "$OS" == "Linux" ]]; then
	if [[ $("$PODMAN" info 2>&1 | grep -c '.*invalid internal status, try resetting the pause process with .*podman system migrate.*') -eq 1 ]]; then
		echo ">>>> Attempting to recover from podman internal state error..."
		echo ">>>> (NOTE: You may be prompted for your password.)"
		USER_ID=$(id --user)
		[[ -d "/var/tmp/podman-static/$USER_ID"   ]] && sudo rm -rf "/var/tmp/podman-static/$USER_ID"
		[[ -d "/var/tmp/containers-user-$USER_ID" ]] && sudo rm -rf "/var/tmp/containers-user-$USER_ID"
		[[ -d "/var/tmp/podman-run-$USER_ID"      ]] && sudo rm -rf "/var/tmp/podman-run-$USER_ID"
		[[ -d "/tmp/podman-static/$USER_ID"       ]] && sudo rm -rf "/tmp/podman-static/$USER_ID"
		[[ -d "/tmp/containers-user-$USER_ID"     ]] && sudo rm -rf "/tmp/containers-user-$USER_ID"
		[[ -d "/tmp/podman-run-$USER_ID"          ]] && sudo rm -rf "/tmp/podman-run-$USER_ID"
	fi
fi

# Start the Podman VM, if necessary.
#
if [[ "$OS" == "Darwin" ]]; then
	if [[ $("$PODMAN" machine list --format "{{.Running}}" | grep -c "true") -eq 0 ]]; then
		echo ">>>> Starting Podman virtual machine..."
		"$PODMAN" machine start --no-info 2> /dev/null
	fi
fi

# State checks.
#
if [[ "$("$PODMAN" container inspect "$NAME" 2> /dev/null)" != "[]" ]]; then
	CONTAINER_ID="$("$PODMAN" container inspect --format "{{.ID}}" "$NAME" 2> /dev/null)"
	CONTAINER_STATE="$("$PODMAN" container inspect --format "{{.State.Status}}" "$NAME" 2> /dev/null)"
else
	CONTAINER_ID=""
	CONTAINER_STATE=""
fi

if [[ "$OS" == "Darwin" ]]; then
	echo ">>>> Checking RDP connection state..."
	RDP_CONNECTION_STATE="$(osascript <<- EOF
	tell application "System Events"
	    if application process "Windows App" exists then
	        if menu item "kali - 127.0.0.1" of menu 1 of menu bar item "Window" of menu bar 1 of application process "Windows App" exists then
	            return "connected"
	        else
	            return "disconnected"
	        end if
	    else
	        return "disconnected"
	    end if
	end tell
	EOF
	)"
else
	echo ">>>> Checking X11 connection state..."
	if [[ $(ps auxww | grep freerdp | grep -c '/v:127.0.0.1:3389') -gt 0 ]]; then
		RDP_CONNECTION_STATE="connected"
	else
		RDP_CONNECTION_STATE="disconnected"
	fi
fi

# Sanity check environment.
#
if [[ "$1" == "restore" ]] && [[ -d "$ENGAGEMENT_DIR" ]]; then
	SANITY="100%"
elif [[ -n "$CONTAINER_ID" ]] && [[ -d "$ENGAGEMENT_DIR" ]] && [[ -f "$SCRIPT" ]]; then
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
	if [[ -n "$CONTAINER_ID" ]]; then
		echo "  Podman Container:     $NAME ($CONTAINER_ID)"
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

# Update the Podman VM or `podman-launcher`, if necessary.
#
if [[ "$CONTAINER_STATE" != "running" ]]; then
	if [[ "$OS" == "Darwin" ]]; then
		if [[ -f $HOME/.cache/disposable-kali/machine-update ]]; then
			LAST_UPDATE="$(cat $HOME/.cache/disposable-kali/machine-update)"
		else
			LAST_UPDATE=0
		fi
		if [[ $(( $(date "+%s") - $LAST_UPDATE )) -ge $(( 7 * 24 * 60 * 60 )) ]]; then
			echo ">>>> Upgrading Podman virtual machine..."
			"$PODMAN" machine ssh 'sudo rpm-ostree upgrade'
			"$PODMAN" machine stop
			"$PODMAN" machine start --no-info

			mkdir -p $HOME/.cache/disposable-kali
			date "+%s" > $HOME/.cache/disposable-kali/machine-update
		fi
	else
		if [[ "$PODMAN" == "$HOME/.cache/disposable-kali/podman-launcher" ]]; then
			LATEST_PODMAN_LAUNCHER="$(curl --silent --location https://api.github.com/repos/89luca89/podman-launcher/releases/latest | grep --perl-regexp --only-matching '"tag_name": ?"v\K.*?(?=")')"

			if [[ -f "$HOME/.cache/disposable-kali/podman-launcher.version" ]]; then
				CURRENT_PODMAN_LAUNCHER="$(cat "$HOME/.cache/disposable-kali/podman-launcher.version")"
			else
				CURRENT_PODMAN_LAUNCHER="0.0.0"
			fi

			if [[ "$LATEST_PODMAN_LAUNCHER" != "$CURRENT_PODMAN_LAUNCHER" ]]; then
				if [[ "$(uname -m)" == "aarch64" ]]; then
					PODMAN_LAUNCHER_ARCH="arm64"
				else
					PODMAN_LAUNCHER_ARCH="amd64"
				fi

				curl --location --output "$HOME/.cache/disposable-kali/podman-launcher" "https://github.com/89luca89/podman-launcher/releases/download/v${LATEST_PODMAN_LAUNCHER}/podman-launcher-${PODMAN_LAUNCHER_ARCH}"

				chmod +x "$HOME/.cache/disposable-kali/podman-launcher"
				echo "$LATEST_PODMAN_LAUNCHER" > "$HOME/.cache/disposable-kali/podman-launcher.version"

				"$PODMAN" version | grep '^Version: .*' | sed 's/.* //' > "$HOME/.cache/disposable-kali/podman-launcher.podman.version"
			fi
		fi
	fi
fi

#### Control functions ################################################

# Start/Stop container.
#
startEngagement () {
	mkdir -p $HOME/.cache/disposable-kali
	readlink /etc/localtime | sed 's#.*/zoneinfo/##' > $HOME/.cache/disposable-kali/localtime

	if [[ "$CONTAINER_STATE" != "running" ]]; then
		"$PODMAN" start "$NAME"
		waitForIt
		echo "ready"
	fi
}

stopEngagement () {
	if [[ "$CONTAINER_STATE" == "running" ]]; then
		stopContainer
	fi
	if [[ "$OS" == "Darwin" ]]; then
		stopMachine
	fi
}

# Connect to the engagement container.
#
startCLI () {
	startEngagement

	"$PODMAN" exec --tty --interactive --user $USER --workdir /home/$USER "$NAME" /usr/bin/bash
}

startGUI () {
	if [[ "$RDP_CONNECTION_STATE" == "disconnected" ]]; then
		startEngagement

		if [[ "$OS" == "Darwin" ]]; then
			mkdir -p $HOME/.cache/disposable-kali

			cat > $HOME/.cache/disposable-kali/kali.rdp <<- EOF
			smart sizing:i:1
			screen mode id:i:1
			prompt for credentials on client:i:1
			redirectsmartcards:i:0
			redirectclipboard:i:1
			full address:s:127.0.0.1
			drivestoredirect:s:*
			networkautodetect:i:0
			redirectprinters:i:0
			autoreconnection enabled:i:1
			session bpp:i:24
			audiomode:i:0
			bandwidthautodetect:i:1
			dynamic resolution:i:1
			username:s:$USER
			EOF

			open $HOME/.cache/disposable-kali/kali.rdp

			{
				osascript - <<- EOF
				tell application "Windows App"
				    activate
				    tell application "System Events"
				        repeat until ((exists window "Favorites" of application process "Windows App") or (exists window "Devices" of application process "Windows App") or (exists window "Apps" of application process "Windows App"))
				            delay 1
				        end repeat
				    end tell
				    delay 1
				    activate
				end tell

				tell application "System Events" to click text field 2 of sheet 1 of window "kali - 127.0.0.1" of application process "Windows App"

				tell application "System Events" to keystroke "$TOKEN"

				tell application "System Events" to click UI element "Continue" of sheet 1 of window "kali - 127.0.0.1" of application process "Windows App"
				EOF
			} &> /dev/null
		else
			if [[ -n "$WAYLAND_DISPLAY" ]] && [[ -n "$(which wlfreerdp)" ]]; then
				FREERDP=wlfreerdp
			else
				FREERDP=xfreerdp
			fi
			{ $FREERDP /bpp:24 /dynamic-resolution /p:"$TOKEN" /rfx /u:"$USER" /v:127.0.0.1:3389 & } &> /dev/null
		fi
	else
		echo "RDP connection already in use"
		echo "Not starting desktop"
	fi
}

# Update the engagement container.
#
updateEngagement () {
	startEngagement

	"$PODMAN" exec --tty --interactive --user $USER --workdir /home/$USER "$NAME" /usr/local/bin/update
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
	if [[ $(ls -1 "$ENGAGEMENT_DIR/Backups"/*.podman.tar | wc -l) -gt 0 ]]; then
		if [[ "$CONTAINER_STATE" == "running" ]]; then
			stopContainer
		fi
		if [[ -n "$CONTAINER_ID" ]]; then
			removeContainerImagePair
		fi

		echo ">>>> Restoring image..."
		RESTORE_TARGET="$(ls -1 "$ENGAGEMENT_DIR/Backups"/*.podman.tar | sort | tail -1)"
		"$PODMAN" load --input "$RESTORE_TARGET"

		echo ">>>> Fixing image tag..."
		CURRENT_TAG="$("$PODMAN" images --format "{{.Tag}}" "$NAME")"
		"$PODMAN" image tag "$NAME:$CURRENT_TAG" "$NAME:latest"
		"$PODMAN" rmi "$NAME:$CURRENT_TAG"

		echo ">>>> Recreating container..."
		HOST_SPECIFIC_FLAGS=()
		if [[ "$OS" == "Linux" ]]; then
			HOST_SPECIFIC_FLAGS+=(--userns keep-id:uid=1000,gid=1000)
		fi

		mkdir -p $HOME/.cache/disposable-kali
		readlink /etc/localtime | sed 's#.*/zoneinfo/##' > $HOME/.cache/disposable-kali/localtime

		"$PODMAN" create --name "$NAME" \
		                 --publish 127.0.0.1:3389:3389 \
		                 --tty \
		                 --mount type=bind,source="$ENGAGEMENT_DIR",destination=/home/$USER/Documents \
		                 --mount type=bind,source=$HOME/.cache/disposable-kali/localtime,destination=/etc/localtime.host,readonly \
		                   "${HOST_SPECIFIC_FLAGS[@]}" "$NAME"

		if [[ $(ls -1 "$ENGAGEMENT_DIR/Backups"/*.podman.sh | wc -l) -gt 0 ]]; then
			RESTORE_TARGET="$(ls -1 "$ENGAGEMENT_DIR/Backups"/*.podman.sh | sort | tail -1)"
			mkdir -p "$(dirname "$SCRIPT")"
			cp "$RESTORE_TARGET" "$SCRIPT"
			chmod 755 "$SCRIPT"
		fi

		stopMachine

		echo ""
		echo "Engagement $NAME has been restored from the backup at $(ls -1 "$ENGAGEMENT_DIR/Backups"/*.podman.tar | sort | tail -1)."
	else
		echo "No backups found in $ENGAGEMENT_DIR/Backups!"
	fi
}

#### Internal helper functions ########################################

# Stop the Podman machine if there are no other running containers.
#
stopMachine () {
	if [[ "$OS" == "Darwin" ]]; then
		if [[ $("$PODMAN" container list --format "{{.State}}" | grep -c "running") -eq 0 ]]; then
			echo ">>>> Stopping Podman virtual machine..."
			"$PODMAN" machine stop
		fi
	fi
}

# Stop the current container. 
#
stopContainer () {
	echo ">>>> Stopping container..."
	"$PODMAN" stop --time $WAIT "$NAME"
}

# Commit changes in a container to the underlying image and exports the
# results.
#
commitToImage () {
	echo ">>>> Committing changes to temporary image..."
	TIMESTAMP=$(date "+%Y-%m-%d-%H-%M-%S")
	"$PODMAN" commit --author "Backup for $(date) by $USER" "$NAME" "$NAME:$TIMESTAMP"

	echo ">>>> Exporting temporary image..."
	BACKUP_DIR="$ENGAGEMENT_DIR/Backups"
	BACKUP_FILE="$BACKUP_DIR/$NAME.$TIMESTAMP.podman.tar"
	mkdir -p "$BACKUP_DIR"
	"$PODMAN" save --output "$BACKUP_FILE" "${NAME}:${TIMESTAMP}"

	echo ">>>> Exporting control files..."
	cp "$SCRIPT" "$BACKUP_DIR/${NAME}.${TIMESTAMP}.podman.sh"

	echo ">>>> Removing temporary image..."
	"$PODMAN" rmi --force "${NAME}:${TIMESTAMP}"
}

# Cleaning up the container/image pair.
#
removeContainerImagePair () {
	echo ">>>> Removing container..."
	"$PODMAN" rm --force --volumes "$NAME"

	echo ">>>> Removing underlying image..."
	"$PODMAN" rmi --force "$NAME"

	echo ">>>> Pruning images to remove dangling references..."
	"$PODMAN" image prune --force > /dev/null

	echo ">>>> Removing control files..."
	rm -f "$SCRIPT"
}

# Sleep briefly to give the container a chance to finish booting.
#
waitForIt () {
	echo -n ">>>> Waiting for the container to finish booting"
	for STEP in $(seq 1 $WAIT); do
		sleep 1
		echo -n "."
	done
	echo ""
}

#### Exec control function ############################################

$CONTROL_FUNCTION
