#!/usr/bin/env bash

# Sanity check.
#
if [[ -z "$PREFIX" ]] && [[ -n "$(which podman)" ]]; then
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
	if [[ "$(uname)" == "Darwin" ]]; then
		PODMAN_MACHINE_NAME="$(podman machine list --format "{{.Default}}\t{{.Name}}" 2> /dev/null | grep -E '^true' | cut -f 2 | sed 's/\*$//')"
		PODMAN_MACHINE_STATE="$(podman machine inspect --format "{{.State}}" "$PODMAN_MACHINE_NAME" 2> /dev/null)"

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

			podman machine init --cpus=$VM_CPU --disk-size=$VM_DISK --memory=$VM_MEMORY --now

			# Fix https://github.com/containers/podman/issues/22678.
			#
			if [[ $(podman machine ssh 'sudo rpm-ostree status' | grep -c 'podman-machine-os:5.0') -gt 0 ]]; then
				podman machine os apply quay.io/podman/machine-os:5.1 --restart
			fi

			# Make sure that auto-updates are disabled
			#
			podman machine ssh 'sudo systemctl disable --now zincati.service'

			# Perform an update (updates roll out every 14 days, so maybe once per week?)
			#
			podman machine ssh 'sudo rpm-ostree upgrade'
			podman machine stop
			podman machine start --no-info

			mkdir -p $HOME/.cache/containerized-engagements
			date "+%s" > $HOME/.cache/containerized-engagements/machine-update
		elif [[ "$PODMAN_MACHINE_STATE" != "running" ]]; then
			podman machine start --no-info
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
	if [[ "$(uname)" == "Darwin" ]]; then
		IS_MACOS="yes"
		USER_PASS="$(uuidgen | tr "[:upper:]" "[:lower:]")"
	else
		IS_MACOS="no"
		USER_PASS="$(uuidgen --random)"
	fi

	TIMEZONE="$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')"

	BUILD_CONFIG="$(mktemp)"

	cat > "$BUILD_CONFIG" <<- EOF
	export IS_MACOS="$IS_MACOS"
	export USER_PASS="$USER_PASS"
	export USER_NAME="$USER"
	export TIMEZONE="$TIMEZONE"
	EOF

	cat container/Dockerfile | podman build \
		--no-cache \
		--secret id=config,src="$BUILD_CONFIG" \
		--tag "$NAME" -

	rm "$BUILD_CONFIG"

	mkdir -p $HOME/.cache/disposable-kali
	echo "$TIMEZONE" > $HOME/.cache/disposable-kali/localtime

	podman create --name "$NAME" \
	              --cap-add SYS_ADMIN \
	              --device /dev/fuse \
	              --publish 127.0.0.1:3389:3389 \
	              --tty \
	              --mount type=bind,source="$ENGAGEMENT_DIR",destination=/home/$USER/Documents \
	              --mount type=bind,source=$HOME/.cache/disposable-kali/localtime,destination=/etc/localtime.host,readonly \
	                "$NAME"

	# Shut down the Podman VM, unless it's still being used for something.
	#
	if [[ "$(uname)" == "Darwin" ]]; then
		if [[ $(podman container list --format "{{.State}}" | grep -c "running") -eq 0 ]]; then
			podman machine stop
		fi
	fi

	# Setup control script and launcher.
	#
	sed "s/{{environment-name}}/$NAME/;s/{{connection-token}}/$USER_PASS/" container/envctl.sh > "$SCRIPT"

	if [[ "$IS_MACOS" == "yes" ]]; then
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
