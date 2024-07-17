#!/usr/bin/env bash

# Sanity check.
#
if [[ -z "$PREFIX" ]] && [[ -n "$(which docker)" ]]; then
	if [[ ! -f docker/envctl.sh ]] || [[ ! -f docker/Dockerfile ]]; then
		echo "This script must be run from the root of the disposable-kali repo!"
		exit 1
	fi
	if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
		echo "$HOME/.local/bin must bin in your PATH!"
		exit 1
	fi
	CODE_PATH="docker"
elif [[ -n "$PREFIX" ]] && [[ -n "$(which proot-distro)" ]]; then
	if [[ ! -f proot/envctl.sh ]] || [[ ! -f proot/plugin.sh ]]; then
		echo "This script must be run from the root of the disposable-kali repo!"
		exit 1
	fi
	if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
		echo "$HOME/bin must bin in your PATH!"
		exit 1
	fi
	CODE_PATH="proot"
else
	echo "No usable install of Docker or PRoot Distro found!"
	exit 1
fi

# An engagement name must be supplied.
#
if [[ -n "$1" ]]; then
	NAME="$(echo -n "$1" | tr -c -s '[:alnum:]_-' '-' | tr '[:upper:]' '[:lower:]' | sed 's/^[_-]\+//;s/[_-]\+$//')"
else
	echo "You must supply an engagement name as this script's first (and only) parameter!"
	exit 1
fi

# Determine build variables.
#
if [[ "$CODE_PATH" == "docker" ]]; then
	SCRIPT="$HOME/.local/bin/${NAME}.sh"
	ENGAGEMENT_DIR="$HOME/Engagements/$NAME"
elif [[ "$CODE_PATH" == "proot" ]]; then
	SCRIPT="$HOME/bin/${NAME}.sh"
	ENGAGEMENT_DIR="$HOME/storage/shared/Documents/Engagements/$NAME"
else
	echo "You should not be here."
	exit 2
fi

# Create necessary directories.
#
mkdir -p "$ENGAGEMENT_DIR"
mkdir -p "$(dirname "$SCRIPT")"

# Build container/proot.
#
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
		export IS_MACOS="yes"
		export USER_PASS="$(uuidgen | tr "[:upper:]" "[:lower:]")"
	else
		export IS_MACOS="no"
		export USER_PASS="$(uuidgen --random)"
	fi

	export USER_NAME="$USER"
	export TIMEZONE="$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')"

	cat docker/Dockerfile | docker build \
		--no-cache \
		--secret id=IS_MACOS \
		--secret id=USER_NAME \
		--secret id=USER_PASS \
		--secret id=TIMEZONE \
		--tag "$NAME" -

	docker create --name "$NAME" \
	              --cap-add SYS_ADMIN \
	              --device /dev/fuse \
	              --publish 127.0.0.1:3389:3389 \
	              --tty \
	              --mount type=bind,source="$ENGAGEMENT_DIR",destination=/home/$USER_NAME/Documents \
	                "$NAME"

	sed "s/{{environment-name}}/$NAME/;s/{{connection-token}}/$USER_PASS/" docker/envctl.sh > "$SCRIPT"

	if [[ "$IS_MACOS" == "yes" ]]; then
		mkdir -p $HOME/Applications
		cp docker/launcher.tar /tmp
		(
			cd /tmp
			tar -xvf launcher.tar
			rm launcher.tar
			sed "s/{{environment-name}}/$NAME/" launcher.app/launcher > launcher.app/"${NAME}"
			rm launcher.app/launcher
			chmod 755 launcher.app/"${NAME}"
			mv launcher.app/launcher.icns launcher.app/"${NAME}.icns"
			mv launcher.app $HOME/Applications/"${NAME}.app"
		)

		dockutil --add $HOME/Applications/"${NAME}.app"
	else
		mkdir -p $HOME/.local/share/icons
		cp icons/wikimedia-kali-logo.png $HOME/.local/share/icons/"${NAME}.png"

		mkdir -p $HOME/.local/share/applications
		sed "s#{{environment-name}}#$NAME#;s#{{user-home}}#$HOME#" docker/launcher.desktop > $HOME/.local/share/applications/"${NAME}.desktop"
	fi

	unset IS_MACOS USER_NAME USER_PASS TIMEZONE
elif [[ "$CODE_PATH" == "proot" ]]; then
	# PRoot Distro engages in some serious nannying around pentesting
	# distros. While I understand the Termux project's desire not to
	# support script-kiddies, and support their refusal to include
	# hacking tools (even if it makes my life harder), actively
	# subverting user requests is, in my opinion, a step too far.
	#
	#     https://github.com/termux/proot-distro/commit/470525c55020d72b66b509066b8d71d59b62072c
	#
	# Proactively un-nerf pentest capabilities (even though we probably
	# won't need that functionality ourselves in most cases).
	#
	sed -i 's/if .*(kali|parrot|nethunter|blackarch).*; then/if false; then/' $(which proot-distro)

	TARBALL_SHA256="$(curl --silent https://kali.download/nethunter-images/current/rootfs/SHA256SUMS | grep kalifs-arm64-minimal | sed 's/ .*//')"
	BUILD_DATE="$(date)"

	sed "s|{{distro-name}}|$NAME|;s|{{build-date}}|$BUILD_DATE|;s|{{tarball-sha256}}|$TARBALL_SHA256|" proot/plugin.sh > "$PREFIX/etc/proot-distro/${NAME}.override.sh"

	proot-distro install "$NAME"

	# For some reason, setting up PostgreSQL/Metasploit works when
	# called from proot-distro, but does not work when called using the
	# run_proot_cmd helper function when building a new environment.
	# For anyone interested in trying to track this down, the error
	# message generated by pg_createcluster is:
	#
	#     FATAL:   Could not create shared memory segment: Function not implemented
	#     DETAIL:  Failed system call was shmget
	#
	proot-distro login "$NAME" -- bash -c "su postgres --command=\"pg_createcluster 16 main\" && su postgres --command=\"/etc/init.d/postgresql start\" && msfdb init && su postgres --command=\"/etc/init.d/postgresql stop\""

	proot-distro login "$NAME" -- bash -c "echo \"kali:\$(uuidgen --random)\" | chpasswd"

	sed "s/{{environment-name}}/$NAME/" proot/envctl.sh > "$SCRIPT"

	mkdir -p $HOME/.shortcuts/icons
	cp icons/wikimedia-kali-logo.png $HOME/.shortcuts/icons/"${NAME}.sh.png"

	mkdir -p $HOME/.shortcuts/tasks
	sed "s/{{environment-name}}/$NAME/" proot/widget.sh > $HOME/.shortcuts/tasks/"${NAME}.sh"
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
