#!/usr/bin/env bash

set -e

OS="$(uname)"

# Figure out which podman we're using; we need at least v4.9.3 to get
# reliable builds. Once this is widely available (Debian 13 trixie for
# Chrome OS, but maybe worth keeping this check in here until I get a
# good look at SteamOS), we can just revert back to using the system
# podman everywhere.
#
if [[ "$OS" == "Darwin" ]]; then
	PODMAN="$(which podman)"
elif [[ -z "$PREFIX" ]]; then
	mkdir -p "$HOME/.cache/disposable-kali"

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
	fi

	PODMAN_LAUNCHER_PODMAN_VERSION="$("$HOME/.cache/disposable-kali/podman-launcher" version | grep '^Version: .*' | sed 's/.* //')"
	echo "$PODMAN_LAUNCHER_PODMAN_VERSION" > "$HOME/.cache/disposable-kali/podman-launcher.podman.version"

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
	PODMAN=""
fi

# Sanity check.
#
if [[ -z "$PREFIX" ]] && [[ -n "$PODMAN" ]]; then
	if [[ ! -f container/envctl.sh ]] || [[ ! -f container/Dockerfile ]]; then
		echo "This script must be run from the root of the disposable-kali repo!"
		exit 1
	fi
	if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
		echo "$HOME/.local/bin must bin in your PATH!"
		exit 1
	fi
	CODE_PATH="podman"
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
	echo "No usable install of Podman or PRoot Distro found!"
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
if [[ "$CODE_PATH" == "podman" ]]; then
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
if [[ "$CODE_PATH" == "podman" ]]; then
	# Init the Podman VM, if necessary.
	#
	if [[ "$OS" == "Darwin" ]]; then
		PODMAN_MACHINE_NAME="$("$PODMAN" machine list --format "{{.Default}}\t{{.Name}}" 2> /dev/null | grep -E '^true' | cut -f 2 | sed 's/\*$//')"

		if [[ -z "$PODMAN_MACHINE_NAME" ]]; then
			TOTAL_AVAIL_MEMORY=$(bc -le "mem = (($(sysctl hw.memsize | sed 's/.*: //') / 1024) / 1024) / 2; scale = 0; mem / 1")
			if [[ $TOTAL_AVAIL_MEMORY -ge 32768 ]]; then
				VM_MEMORY=32768
			elif [[ $TOTAL_AVAIL_MEMORY -ge 16384 ]]; then
				VM_MEMORY=16384
			elif [[ $TOTAL_AVAIL_MEMORY -ge 8192 ]]; then
				VM_MEMORY=8192
			elif [[ $TOTAL_AVAIL_MEMORY -ge 4096 ]]; then
				VM_MEMORY=4096
			else
				echo "At least 8 GB of memory is required!"
				exit 1
			fi

			TOTAL_AVAIL_CPU=$(bc -le "cpu = $(sysctl hw.ncpu | sed 's/.*: //') / 2; scale = 0; cpu / 1")
			if [[ $TOTAL_AVAIL_CPU -ge 16 ]]; then
				VM_CPU=16
			elif [[ $TOTAL_AVAIL_CPU -ge 8 ]]; then
				VM_CPU=8
			elif [[ $TOTAL_AVAIL_CPU -ge 4 ]]; then
				VM_CPU=4
			elif [[ $TOTAL_AVAIL_CPU -ge 2 ]]; then
				VM_CPU=2
			else
				echo "At least 4 CPU cores are required!"
				exit 1
			fi

			TOTAL_AVAIL_DISK=$(bc -le "disk = (($(df -Pk $HOME | tail -1 | sed 's/[ ]\{1,\}/\t/g' | cut -f 4) / 1024) / 1024) * 0.64; scale = 0; disk / 1")
			if [[ $TOTAL_AVAIL_DISK -ge 512 ]]; then
				VM_DISK=512
			elif [[ $TOTAL_AVAIL_DISK -ge 256 ]]; then
				VM_DISK=256
			elif [[ $TOTAL_AVAIL_DISK -ge 128 ]]; then
				VM_DISK=128
			else
				echo "At least 200 GB of free disk space is required!"
				exit 1
			fi

			"$PODMAN" machine init --cpus=$VM_CPU --disk-size=$VM_DISK --memory=$VM_MEMORY
			"$PODMAN" machine start --no-info

			# Fix https://github.com/containers/podman/issues/22678.
			#
			if [[ $("$PODMAN" machine ssh 'sudo rpm-ostree status' | grep -c 'podman-machine-os:5.0') -gt 0 ]]; then
				"$PODMAN" machine os apply quay.io/podman/machine-os:5.1 --restart
			fi

			# Make sure that auto-updates are disabled
			#
			"$PODMAN" machine ssh 'sudo systemctl disable --now zincati.service'

			# Perform an update (updates roll out every 14 days, so maybe once per week?)
			#
			"$PODMAN" machine ssh 'sudo rpm-ostree upgrade'
			"$PODMAN" machine stop
			"$PODMAN" machine start --no-info

			mkdir -p $HOME/.cache/containerized-engagements
			date "+%s" > $HOME/.cache/containerized-engagements/machine-update
		else
			if [[ "$("$PODMAN" machine inspect --format "{{.State}}" "$PODMAN_MACHINE_NAME" 2> /dev/null)" != "running" ]]; then
				"$PODMAN" machine start --no-info
			fi
		fi
	fi

	# Build container.
	#
	# Note the use of --no-cache for `podman build`. The reason here is
	# that changing the username, timezone, and password changes doesn't
	# necessarily invalidate the build cache, since secrets aren't
	# exposed (generally a good thing). While we could try to cache bust
	# out way out of the situation, we still want to grab the latest
	# packages, so most of our build will be invalid anyway.
	#
	# Building without a cache isn't quite as bad as it sounds, because
	# in practice most of the time a new engagement is only going to be
	# built daily at worse, and more likely only once every 2 - 3 weeks.
	#
	# FIXME: The test for whether to set HIDPI_GUI to "yes" or "no"
	# really should be smarter. Ideally, HIDPI_GUI would be "yes"
	# whenever the host's primary display is larger than 1600 pixels on
	# a side. However, this will require different tests for macOS,
	# X.org, and Wayland, and I'm frankly just not sufficiently
	# motivated right now.
	#
	HOST_SPECIFIC_FLAGS=()
	if [[ "$OS" == "Darwin" ]]; then
		CONNECTION_TOKEN="$(uuidgen | tr "[:upper:]" "[:lower:]")"
		HIDPI_GUI="yes"
	else
		CONNECTION_TOKEN="$(uuidgen --random)"
		HIDPI_GUI="no"
		HOST_SPECIFIC_FLAGS+=(--userns keep-id:uid=1000,gid=1000)
	fi

	TIMEZONE="$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')"

	TOKEN_FILE="$(mktemp)"

	echo "$CONNECTION_TOKEN" > "$TOKEN_FILE"

	cat container/Dockerfile | "$PODMAN" build \
		--no-cache \
		--build-arg HIDPI="$HIDPI_GUI" \
		--build-arg HOST_OS="$OS" \
		--build-arg TIMEZONE="$TIMEZONE" \
		--build-arg USER_NAME="$USER" \
		--secret id=connection-token,src="$TOKEN_FILE" \
		--tag "$NAME" -

	rm "$TOKEN_FILE"

	mkdir -p $HOME/.cache/disposable-kali
	echo "$TIMEZONE" > $HOME/.cache/disposable-kali/localtime

	"$PODMAN" create --name "$NAME" \
	                 --publish 127.0.0.1:3389:3389 \
	                 --tty \
	                 --mount type=bind,source="$ENGAGEMENT_DIR",destination=/home/$USER/Documents \
	                 --mount type=bind,source=$HOME/.cache/disposable-kali/localtime,destination=/etc/localtime.host,readonly \
	                   "${HOST_SPECIFIC_FLAGS[@]}" "$NAME"

	# Shut down the Podman VM, unless it's still being used for something.
	#
	if [[ "$OS" == "Darwin" ]]; then
		if [[ $("$PODMAN" container list --format "{{.State}}" | grep -c "running") -eq 0 ]]; then
			"$PODMAN" machine stop
		fi
	fi

	# Setup control script and launcher.
	#
	sed "s/{{environment-name}}/$NAME/;s/{{connection-token}}/$CONNECTION_TOKEN/" container/envctl.sh > "$SCRIPT"

	if [[ "$OS" == "Darwin" ]]; then
		mkdir -p $HOME/Applications
		cp container/launcher.tar /tmp
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
		sed "s#{{environment-name}}#$NAME#;s#{{user-home}}#$HOME#" container/launcher.desktop > $HOME/.local/share/applications/"${NAME}.desktop"
	fi
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

	TARBALL_SHA256="$(curl https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-minimal-arm64.tar.xz | sha256sum | sed 's/ .*//')"
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
	proot-distro login "$NAME" -- bash -c "su postgres --command=\"pg_createcluster 17 main\" && su postgres --command=\"/etc/init.d/postgresql start\" && msfdb init && su postgres --command=\"/etc/init.d/postgresql stop\""

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
