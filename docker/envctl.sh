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
if [[ "$1" == "restore" ]] && [[ -d "$ENGAGEMENT_DIR" ]] && [[ -f "$SCRIPT" ]]; then
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
	if [[ "$(uname -s)" == "Linux" ]]; then
		echo "  desktop  Connect to a desktop in the engagement's container"
	fi
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
	waitForIt
	docker exec --tty --interactive "$NAME" /usr/bin/bash
}

startGUI () {
	startEngagement
	waitForIt
	if [[ -n "$WAYLAND_DISPLAY" ]] && [[ -n "$(which wlfreerdp)" ]]; then
		FREERDP=wlfreerdp
	else
		FREERDP=xfreerdp
	fi
	$FREERDP /bpp:16 /dynamic-resolution /rfx /u:$USER /v:127.0.0.1:3389
}

# Archive Docker container and control script in ENGAGEMENT_DIR.
#
archiveEngagement () {
	echo ">>>> Stopping Docker container..."
	stopEngagement

	commitToImage
	removeContainerImagePair

	echo ">>>> Archiving this control script..."
	mv --force "$SCRIPT" "$ENGAGEMENT_DIR"/

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
		echo ">>>> Deleting this control script..."
		rm --force "$SCRIPT"

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
		              --mount type=bind,source="$ENGAGEMENT_DIR",destination=/home/$USER_NAME/Documents \
		                "$NAME"

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
}

# Helper function that sleeps briefly.
#
waitForIt () {
	SECONDS=8
	echo -n ">>>> Sleeping briefly"
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
		if [[ "$(uname -s)" == "Linux" ]]; then
			startGUI
		else
			scriptHelp
		fi
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
