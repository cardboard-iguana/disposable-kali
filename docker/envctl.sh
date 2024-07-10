#!/usr/bin/env bash

NAME="{{environment-name}}"

# Core engagement files/data.
#
SCRIPT="$HOME/.local/bin/${NAME}.sh"
ENGAGEMENT_DIR="$HOME/Engagements/$NAME"
ID="$(docker container inspect --format "{{.ID}}" "$NAME" 2> /dev/null)"
STATE="$(docker container inspect --format "{{.State.Status}}" "$NAME" 2> /dev/null)"

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
		echo "  Docker Container:     $NAME ($ID)"
	else
		echo "  Docker Container:     DOES NOT EXIST"
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
	echo "  start    Start the engagement's container"
	echo "  stop     Stop the engagement's container"
	echo "  shell    Connect to a shell in the engagement's container"
	echo "  desktop  Connect to a desktop in the engagement's container"
	echo "  backup   Commit changes to the underlying image and back it up"
	echo "  restore  Restore an image/container pair from the most recent backup"
	echo "  archive  Archive the engagement to $ENGAGEMENT_DIR"
	echo "  delete   Remove all engagement data"
}

# Start/Stop container.
#
startEngagement () {
	if [[ "$STATE" != "running" ]]; then
		docker start "$NAME"
		waitForIt
		echo "ready"
	fi
}

stopEngagement () {
	if [[ "$STATE" == "running" ]]; then
		docker stop "$NAME"
	fi
}

# Connect to the engagement container.
#
startCLI () {
	startEngagement

	docker exec --tty --interactive --user $USER --workdir /home/$USER "$NAME" /usr/bin/bash
}

startGUI () {
	startEngagement

	if [[ "$(uname)" == "Darwin" ]]; then
		cat > /tmp/"${NAME}.rdp" <<- EOF
		smart sizing:i:1
		screen mode id:i:1
		prompt for credentials on client:i:1
		redirectsmartcards:i:0
		redirectclipboard:i:1
		forcehidpioptimizations:i:0
		full address:s:localhost
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
		open /tmp/"${NAME}.rdp"
	else
		if [[ -n "$WAYLAND_DISPLAY" ]] && [[ -n "$(which wlfreerdp)" ]]; then
			FREERDP=wlfreerdp
		else
			FREERDP=xfreerdp
		fi
		$FREERDP /bpp:16 /dynamic-resolution /rfx /drive:Engagement,"$ENGAGEMENT_DIR" /u:$USER /v:127.0.0.1:3389
	fi
}

# Archive Docker container and control script in ENGAGEMENT_DIR.
#
archiveEngagement () {
	echo ">>>> Stopping Docker container..."
	stopEngagement

	commitToImage
	removeContainerImagePair

	echo ""
	echo "Engagement $NAME has been archived in $ENGAGEMENT_DIR."
}

# Remove all engagement data.
#
deleteEngagement () {
	echo "You are about to PERMENANTLY DELETE the Docker container, control"
	echo "script, and data directory for $NAME. The following objects will be"
	echo "deleted:"
	echo ""
	echo "  Docker Container:     $NAME ($ID)"
	echo "  Engagement Directory: $ENGAGEMENT_DIR"
	echo "  Control Script:       $SCRIPT"
	echo ""
	read -p "Please confirm by typing YES (all capitals): " CONFIRMATION

	if [[ "$CONFIRMATION" == "YES" ]]; then
		echo ">>>> Stopping Docker container..."
		stopEngagement
		removeContainerImagePair

		echo ">>>> Deleting engagement directory..."
		rm --recursive --force "$ENGAGEMENT_DIR"

		echo ""
		echo "Engagement $NAME has been deleted."
	else
		echo ""
		echo "Engagement deletion aborted."
	fi
}

# Back up the Docker container in ENGAGEMENT_DIR.
#
backupEngagement () {
	echo ">>>> Stopping Docker container..."
	stopEngagement

	commitToImage

	echo ""
	echo "Engagement $NAME has been backed up in $BACKUP_DIR."
}

# Restore from the most recent backup.
#
restoreEngagement () {
	if [[ -f "$ENGAGEMENT_DIR/Backups/$NAME.tar" ]]; then
		echo ">>>> Stopping Docker container..."
		stopEngagement
		removeContainerImagePair

		echo ">>>> Restoring image..."
		docker load --input "$ENGAGEMENT_DIR/Backups/$NAME.tar"

		echo ">>>> Fixing image tag..."
		CURRENT_TAG="$(docker images --format "{{.Tag}}" "$NAME")"
		docker image tag "$NAME:$CURRENT_TAG" "$NAME:latest"
		docker rmi "$NAME:$CURRENT_TAG"

		echo ">>>> Recreating container..."
		docker create --name "$NAME" \
		              --publish 127.0.0.1:3389:3389 \
		              --tty \
		              --mount type=bind,source="$ENGAGEMENT_DIR",destination=/home/$USER/Documents \
		                "$NAME"

		if [[ -f "$ENGAGEMENT_DIR/Backups/$NAME.sh" ]]; then
			mkdir --parents "$(dirname "$SCRIPT")"
			cp --dereference "$ENGAGEMENT_DIR/Backups/$NAME.sh" "$SCRIPT"
		fi
		if [[ "$(uname)" == "Darwin" ]]; then
			if [[ -f "$ENGAGEMENT_DIR/${NAME}.app.tar.gz" ]]; then
				mkdir --parents "$HOME/Applications"
				tar -xzf "${NAME}.app.tar.gz"
				mv "${NAME}.app" "$HOME/Applications"
				dockutil --add $HOME/Applications/"${NAME}.app"
			fi
		else
			if [[ -f "$ENGAGEMENT_DIR/Backups/$NAME.png" ]]; then
				mkdir --parents "$HOME/.local/share/icons"
				cp --dereference "$ENGAGEMENT_DIR/Backups/$NAME.png" "$HOME/.local/share/icons/${NAME}.png"
			fi
			if [[ -f "$ENGAGEMENT_DIR/Backups/$NAME.desktop" ]]; then
				mkdir --parents "$HOME/.local/share/applications"
				cp --dereference "$ENGAGEMENT_DIR/Backups/$NAME.desktop" "$HOME/.local/share/icons/${NAME}.desktop"
			fi
		fi

		echo ""
		echo "Engagement $NAME has been restored from the backup at $ENGAGEMENT_DIR/Backups/$NAME.tar."
	else
		echo "No backup found at $ENGAGEMENT_DIR/Backups/$NAME.tar!"
	fi
}

# Helper function that commits changes in a container to the underlying
# image and exports the results.
#
commitToImage () {
	echo ">>>> Committing changes to temporary image..."
	TIMESTAMP=$(date "+%Y-%m-%d-%H-%M-%S")
	docker commit --author "$USER" --message "$NAME backup for $(date)" "$NAME" "$NAME:$TIMESTAMP"

	echo ">>>> Exporting temporary image..."
	BACKUP_DIR="$ENGAGEMENT_DIR/Backups"
	BACKUP_FILE="$BACKUP_DIR/$NAME.$TIMESTAMP.tar"
	mkdir --parents "$BACKUP_DIR"
	docker save --output "$BACKUP_FILE" "${NAME}:${TIMESTAMP}"
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
	docker rmi --force "${NAME}:${TIMESTAMP}"
}

# Helper function specifically for cleaning up Docker container/image
# pairs.
#
removeContainerImagePair () {
	echo ">>>> Removing Docker container..."
	docker rm --force --volumes "$NAME"

	echo ">>>> Removing Docker image..."
	docker rmi --force "$NAME"

	echo ">>>> Pruning Docker to remove dangling references..."
	docker image prune --force

	echo ">>>> Removing control files..."
	rm --force "$SCRIPT"
	if [[ "$(uname)" == "Darwin" ]]; then
		rm --force --recursive "$HOME/Applications/${NAME}.app"
		dockutil --remove $HOME/Applications/"${NAME}.app"
	else
		rm --force "$HOME/.local/share/applications/${NAME}.desktop"
		rm --force "$HOME/.local/share/icons/${NAME}.png"
	fi
}

# Helper function that sleeps briefly.
#
waitForIt () {
	SECONDS=12
	echo -n ">>>> Sleeping briefly"
	if [[ "$(uname)" == "Darwin" ]]; then
		osascript -e "display dialog \"Waiting $SECONDS seconds for the container...\" buttons {\"Dismiss\"} giving up after $SECONDS" &> /dev/null &
	else
		if [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
			(
				for STEP in $(seq 1 $SECONDS); do
					sleep 1
					echo $(( $STEP * 100 / $SECONDS ))
				done
			) | zenity --title=$NAME \
		               --window-icon=$HOME/.local/share/icons/"${NAME}.png" \
			           --text="Waiting $SECONDS seconds for the container..." \
			           --progress --percentage=0 --auto-close --no-cancel &> /dev/null &
		fi
	fi
	for STEP in $(seq 1 $SECONDS); do
		sleep 1
		echo -n "."
	done
	echo ""
}

# Flow control.
#
case "$1" in
	"start")
		startEngagement
		;;
	"stop")
		stopEngagement
		;;
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
