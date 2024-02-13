#!/usr/bin/env bash

# Sanity check.
#
if [[ -z "$PREFIX" ]] && [[ -n "$(which docker)" ]]; then
	if [[ ! -f docker/envctl.sh ]] || [[ ! -f docker/Dockerfile ]]; then
		echo "This script must be run from the root of the disposable-kali repo!"
		exit 1
	else
		CODE_PATH="docker"
	fi
elif [[ -n "$PREFIX" ]] && [[ -n "$(which proot-distro)" ]]; then
	if [[ ! -f proot/envctl.sh ]] || [[ ! -f proot/plugin.sh ]]; then
		echo "This script must be run from the root of the disposable-kali repo!"
		exit 1
	else
		CODE_PATH="proot"
	fi
else
	echo "No usable install of Docker or PRoot Distro found!"
	exit 1
fi

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
	echo "$HOME/.local/bin must bin in your PATH!"
	exit 1
fi

# Gather engagement information.
#
read -p "What is the engagement name? " ENGAGEMENT_NAME

if [[ "$CODE_PATH" == "docker" ]]; then
	USER_NAME="$USER"
elif [[ "$CODE_PATH" == "proot" ]]; then
	read -p "What name should be used for the non-root container user? " USER_NAME
else
	echo "You should not be here."
	exit 2
fi

GOOD_PASSWORD="no"
while [[ "$GOOD_PASSWORD" == "no" ]]; do
	read -s -p "What password should be used for the non-root container user (not echoed)? " PASSWORD_ONE
	echo ""
	read -s -p "Retype the password above to confirm (not echoed). " PASSWORD_TWO
	echo ""
	if [[ "$PASSWORD_ONE" == "$PASSWORD_TWO" ]]; then
		USER_PASS="$PASSWORD_ONE"
		GOOD_PASSWORD="yes"
	else
		echo ""
		echo "Supplied passwords do not match!"
		echo ""
	fi
done

# Determine build variables.
#
NAME="$(echo -n "$ENGAGEMENT_NAME" | tr -c -s '[:alnum:]_-' '-' | tr '[:upper:]' '[:lower:]' | sed 's/^[_-]\+//;s/[_-]\+$//')"
SCRIPT="$HOME/.local/bin/${NAME}.sh"

if [[ "$CODE_PATH" == "docker" ]]; then
	ENGAGEMENT_DIR="$HOME/Engagements/$NAME"
	TIMEZONE="$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')"
elif [[ "$CODE_PATH" == "proot" ]]; then
	ENGAGEMENT_DIR="$HOME/storage/shared/Documents/Engagements/$NAME"
	TIMEZONE="$(getprop persist.sys.timezone)"
else
	echo "You should not be here."
	exit 2
fi

# Confirm details.
#
echo ""
echo "The following settings will be used:"
echo ""
echo "  Engagement Name: $ENGAGEMENT_NAME"
echo "  User Name:       $USER_NAME"
echo "  Password:        ********"
echo "  Time Zone:       $TIMEZONE"
echo ""
echo "The following engagement objects will be created:"
echo ""
if [[ "$CODE_PATH" == "docker" ]]; then
	echo "  Docker Container:     $NAME (kalilinux/kali-rolling)"
elif [[ "$CODE_PATH" == "proot" ]]; then
	echo "  Proot Distribution:   $NAME (kali-nethunter/current)"
else
	echo "You should not be here."
	exit 2
fi
echo "  Engagement Directory: $ENGAGEMENT_DIR"
echo "  Control Script:       $SCRIPT"
echo ""
read -n 1 -p "Is this correct? (y/N) " CONFIRMATION
echo ""
echo ""

if [[ ! "$CONFIRMATION" =~ ^[yY]$ ]]; then
	echo "Engagement creation aborted."
	exit
fi

# Create necessary directories.
#
mkdir --parents "$ENGAGEMENT_DIR"
mkdir --parents "$HOME/.local/bin"

if [[ "$CODE_PATH" == "docker" ]]; then
	# Build Docker container.
	#
	# Note the use of --no-cache for `docker build`. There are two
	# reasons for this:
	#
	# Firstly, username, timezone, and password changes don't
	# necessarily invalidate the build cache, since secrets aren't
	# exposed (generally a good thing). While one could attempt to
	# cachebust using, say, a SHA256 sum of these values, such a hash
	# would still be deterministic (and recorded in Docker's build
	# logs), and thus the data could be recovered by brute-forcing.
	# Adding a salt would just result in the cache being invalidated on
	# every run anyway, so why go through the extra effort?
	#
	#     https://github.com/moby/moby/issues/1996#issuecomment-185872769
	#
	# Secondly, the fetching packages to install initially really
	# shouldn't be cached even though it's the longest, most annoying
	# step (upwards of ~15 minutes), since doing so can cause us to miss
	# out on security updates.
	#
	# Building without a cache isn't quite as bad as it sounds, because
	# in practice most of the time a new engagement is only going to be
	# built daily at worse, and more likely only once every 2 - 3 weeks.
	#
	if [[ "$(uname)" == "Darwin" ]]; then
		IS_MACOS="yes"
	else
		IS_MACOS="no"
	fi

	export IS_MACOS USER_NAME USER_PASS TIMEZONE

	cat docker/Dockerfile | docker build \
		--no-cache \
		--secret id=IS_MACOS \
		--secret id=USER_NAME \
		--secret id=USER_PASS \
		--secret id=TIMEZONE \
		--tag "$NAME" -

	docker create --name "$NAME" \
	              --publish 127.0.0.1:3389:3389 \
	              --tty \
	              --mount type=bind,source="$ENGAGEMENT_DIR",destination=/home/$USER_NAME/Documents \
	                "$NAME"

	unset IS_MACOS USER_NAME USER_PASS TIMEZONE

	sed "s/{{environment-name}}/$NAME/" docker/envctl.sh > "$SCRIPT"
elif [[ "$CODE_PATH" == "proot" ]]; then
	TARBALL_SHA256="$(curl --silent https://kali.download/nethunter-images/current/rootfs/SHA256SUMS | grep kalifs-arm64-minimal | sed 's/ .*//')"
	BUILD_DATE="$(date)"

	sed "s|{{distro-name}}|$ENGAGEMENT_NAME|;s|{{build-date}}|$DATE|;s|{{tarball-sha256}}|$TARBALL_SHA256|" proot/plugin.sh > "$PREFIX/etc/proot-distro/${NAME}.sh"

	proot-distro install "$NAME"

	sed "s/{{environment-name}}/$NAME/" proot/envctl.sh > "$SCRIPT"
else
	echo "You should not be here."
	exit 2
fi

# Finish up.
#
chmod +x "$SCRIPT"
echo ""
echo "Build finished. The engagement container can be controlled with"
echo "$SCRIPT."
echo ""
echo "------------------------------------------------------------------------"
echo ""
$SCRIPT help
echo ""
