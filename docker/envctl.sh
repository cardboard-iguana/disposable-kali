#!/usr/bin/env bash

NAME="{{environment-name}}"

# Core engagement files/data.
#
SCRIPT="$HOME/.local/bin/${NAME}.sh"
ENGAGEMENT_DIR="$HOME/Engagements/$NAME"
CONTAINER_DATA="$(docker container ls --all --format json | jq --slurp --raw-output ".[] | select(.Names == \"$NAME\") | .ID + \"|\" + .State")"

# Sanity check environment.
#
if [[ -n "$CONTAINER_DATA" ]] && [[ -d "$ENGAGEMENT_DIR" ]] && [[ -f "$SCRIPT" ]]; then
	STATE="$(echo "$CONTAINER_DATA" | cut -d "|" -f 2)"
else
	echo "The environment for $NAME appears to be damaged or incomplete, and is"
	echo "not usable."
	echo ""
	if [[ -n "$CONTAINER_DATA" ]]; then
		echo "  Docker Container:     $(echo "$CONTAINER_DATA" | cut -d "|" -f 1)"
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
	echo "  archive  Archive the engagement container in $ENGAGEMENT_DIR"
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
	$FREERDP /bpp:16 /dynamic-resolution /u:$USER /v:localhost:3389
}

# Archive Docker container and control script in ENGAGEMENT_DIR.
#
archiveEngagement () {
	echo ">>>> Stopping Docker container..."
	stopEngagement

	echo ">>>> Committing changes to Docker container..."
	docker commit --author "$USER" --message "Archive for $(date)" "$NAME"
	echo ">>>> Exporting Docker container..."
	ARCHIVE_DIR="$ENGAGEMENT_DIR/Archives/$(date "+%Y-%m-%d %H%M")"
	mkdir --parents "$ARCHIVE_DIR"
	docker save --output "$ARCHIVE_DIR/$NAME.tar" "$NAME"
	echo ">>>> Compressing exported image (this may take some time)..."
	xz --verbose "$ARCHIVE_DIR/$NAME.tar"
	removeContainerImagePair
	echo ">>>> Archiving this control script..."
	mv --force "$SCRIPT" "$ARCHIVE_DIR"/

	echo ""
	echo "Engagement $NAME has been archived in $ARCHIVE_DIR."
}

# Remove all engagement data.
#
deleteEngagement () {
	echo "You are about to PERMENANTLY DELETE the Docker container, control"
	echo "script, and data directory for $NAME. The following objects will be"
	echo "deleted:"
	echo ""
	echo "  Docker Container:     $NAME ($(echo "$CONTAINER_DATA" | cut -d "|" -f 1))"
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
	SECONDS=4
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
