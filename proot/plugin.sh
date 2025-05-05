#!/data/data/com.termux/files/usr/bin/bash

DISTRO_NAME="{{distro-name}}"
DISTRO_COMMENT="Kali Linux NetHunter (build date {{build-date}})"
TARBALL_URL['aarch64']="https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-minimal-arm64.tar.xz"
TARBALL_SHA256['aarch64']="{{tarball-sha256}}"

distro_setup() {
	# Configure APT
	#
	echo 'APT::Install-Recommends "false";' >  ./etc/apt/apt.conf.d/minimal-installs
	echo 'APT::Install-Suggests "false";'   >> ./etc/apt/apt.conf.d/minimal-installs

	# Install base system
	#
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt update       --quiet --assume-yes --fix-missing
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt full-upgrade --quiet --assume-yes --fix-broken

	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt install --quiet --assume-yes \
		build-essential \
		burpsuite \
		code-oss \
		dialog \
		firefox-esr \
		fonts-recommended \
		gnupg \
		kali-menu \
		kali-themes \
		kali-undercover \
		less \
		libffi-dev \
		libyaml-dev \
		metasploit-framework \
		nano \
		netcat-openbsd \
		openssh-client \
		python3-venv \
		qt5ct \
		qt6ct \
		sqlite3 \
		tmux \
		uuid-runtime \
		xclip \
		zlib1g-dev

	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt autoremove --quiet --assume-yes --purge --autoremove
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt clean      --quiet --assume-yes

	# Install mise
	#
	mkdir --parents ./etc/apt/keyrings
	mkdir --parents ./etc/apt/sources.list.d

	run_proot_cmd bash -c "curl --silent --location https://mise.jdx.dev/gpg-key.pub | gpg --dearmor > /etc/apt/keyrings/mise-archive-keyring.gpg"
	echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg] https://mise.jdx.dev/deb stable main" > ./etc/apt/sources.list.d/mise.list

	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt update  --quiet --assume-yes
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt install --quiet --assume-yes mise

	# Make sure locale is built
	#
	sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' ./etc/locale.gen
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales

	# Set time zone
	#
	run_proot_cmd ln --symbolic --force /usr/share/zoneinfo/$(getprop persist.sys.timezone) /etc/localtime

	# Create systemctl hack script
	#
	cat > ./usr/bin/systemctl.sh <<- EOF
	#!/usr/bin/env bash
	service \$2 \$1
	EOF

	chmod 755 ./usr/bin/systemctl.sh

	cp ./usr/bin/systemctl    ./usr/bin/systemctl.bin
	cp ./usr/bin/systemctl.sh ./usr/bin/systemctl

	# Hush various logins
	#
	touch ./root/.hushlogin
	touch ./var/lib/postgresql/.hushlogin

	# Create (and run) system update cleanup script.
	#
	cat > ./usr/local/sbin/system-update-cleanup <<- EOF
	#!/usr/bin/env bash

	# Fix bad permissions on /usr/bin/sudo
	#
	chmod u+s /usr/bin/sudo

	# Fix VS Code files
	#
	#sed -i 's#/usr/lib/code-oss/code-oss#/usr/bin/code-oss#' /usr/share/applications/code-oss.desktop
	#sed -i 's#/usr/lib/code-oss/code-oss#/usr/bin/code-oss#' /usr/share/applications/code-oss-url-handler.desktop

	sed -i 's#"serviceUrl": "https://open-vsx.org/vscode/gallery",#"serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery","cacheUrl": "https://vscode.blob.core.windows.net/gallery/index",#' /usr/lib/code-oss/resources/app/product.json
	sed -i 's#"itemUrl": "https://open-vsx.org/vscode/item"#"itemUrl": "https://marketplace.visualstudio.com/items"#'                                                                                            /usr/lib/code-oss/resources/app/product.json

	# PostgreSQL upgrade hack
	#
	sed -i 's/^stop_version/#stop_version/' /var/lib/dpkg/info/postgresql-??.prerm
	EOF

	chmod 755 ./usr/local/sbin/system-update-cleanup

	run_proot_cmd /usr/local/sbin/system-update-cleanup

	# Create update script (useful for long-running environments)
	#
	cat > ./usr/local/bin/update <<- EOF
	#!/usr/bin/env bash

	sudo -u postgres /etc/init.d/postgresql stop

	sudo cp /usr/bin/systemctl.bin /usr/bin/systemctl

	sudo apt update
	sudo apt full-upgrade
	sudo apt autoremove --purge --autoremove
	sudo apt clean

	sudo cp /usr/bin/systemctl    /usr/bin/systemctl.bin
	sudo cp /usr/bin/systemctl.sh /usr/bin/systemctl

	sudo -u postgres /etc/init.d/postgresql start

	sudo /usr/local/sbin/system-update-cleanup

	mise upgrade
	EOF

	chmod 755 ./usr/local/bin/update

	# Abuse the command-not-found functionality to add a date/time
	# stamp before each prompt
	#
	cat > ./etc/zsh_command_not_found <<- EOF
	#!/usr/bin/env zsh

	precmd() {
	    print -Pnr -- "\$TERM_TITLE"

	    if [[ "\$NEWLINE_BEFORE_PROMPT" == "yes" ]]; then
	        if [[ -z "\$_NEW_LINE_BEFORE_PROMPT" ]]; then
	            _NEW_LINE_BEFORE_PROMPT=1
	        else
	            print ""
	        fi
	    fi
	    date "+%Y-%m-%d @ %H:%M:%S %Z"
	}
	EOF

	# Create shell startup script
	#
	cat > ./usr/local/sbin/tui <<- EOF
	#!/usr/bin/env bash

	sudo -u postgres /etc/init.d/postgresql start

	/usr/bin/env tmux -2 new-session

	sudo -u postgres /etc/init.d/postgresql stop
	EOF

	chmod 755 ./usr/local/sbin/tui

	# Generate local self-signed certificate (for PostgreSQL)
	#
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive make-ssl-cert generate-default-snakeoil
	chmod 600 ./etc/ssl/private/ssl-cert-snakeoil.key

	# User setup.
	#
	run_proot_cmd usermod --append --groups adm,audio,cdrom,dialout,dip,floppy,netdev,plugdev,sudo,staff,users,video kali

	echo "kali ALL=(ALL:ALL) NOPASSWD: ALL" > ./etc/sudoers.d/kali

	# Home directory setup
	#
	cp --archive --force --no-target-directory ./etc/skel ./home/kali

	mkdir --parents ./home/kali/.BurpSuite
	cat > ./home/kali/.BurpSuite/UserConfigCommunity.json <<- EOF
	{
	    "user_options":{
	        "display":{
	            "user_interface":{
	                "look_and_feel":"Light"
	            }
	        },
	        "misc":{
	            "show_learn_tab":false
	        },
	        "proxy":{
	            "http_history":{
	                "sort_column":"#",
	                "sort_order":"descending"
	            },
	            "websockets_history":{
	                "sort_column":"#",
	                "sort_order":"descending"
	            }
	        }
	    }
	}
	EOF

	mkdir --parents ./home/kali/.config/"Code - OSS"/User
	cat > ./home/kali/.config/"Code - OSS"/User/settings.json <<- EOF
	{
	    "window.titleBarStyle": "custom",
	    "workbench.colorTheme": "Default Light Modern"
	}
	EOF

	mkdir --parents ./home/kali/.config/gtk-3.0
	cat > ./home/kali/.config/gtk-3.0/settings.ini <<- EOF
	[Settings]
	gtk-icon-theme-name = Windows-10-Icons
	gtk-theme-name = Windows-10
	EOF

	mkdir --parents ./home/kali/.config/qt5ct
	sed 's#^icon_theme=.\+#icon_theme=Windows-10-Icons#;s#^color_scheme_path=.\+#color_scheme_path=/usr/share/qt5ct/colors/Windows.conf#' ./etc/xdg/qt5ct/qt5ct.conf > ./home/kali/.config/qt5ct/qt5ct.conf

	mkdir --parents ./home/kali/.config/qt6ct
	sed 's#^icon_theme=.\+#icon_theme=Windows-10-Icons#;s#^color_scheme_path=.\+#color_scheme_path=/usr/share/qt5ct/colors/Windows.conf#' ./etc/xdg/qt6ct/qt6ct.conf > ./home/kali/.config/qt6ct/qt6ct.conf

	ln --symbolic --force .face ./home/kali/.face.icon

	cat > ./home/kali/.gtkrc-2.0 <<- EOF
	gtk-icon-theme-name = "Windows-10-Icons"
	gtk-theme-name = "Windows-10"
	EOF

	touch ./home/kali/.hushlogin

	cat > ./home/kali/.inputrc <<- EOF
	"\\e[A": history-search-backward
	"\\eOA": history-search-backward

	"\\e[B": history-search-forward
	"\\eOB": history-search-forward
	EOF

	mkdir --parents ./home/kali/.java/.userPrefs/burp
	head --lines -1 ./etc/skel/.java/.userPrefs/burp/prefs.xml > ./home/kali/.java/.userPrefs/burp/prefs.xml
	cat >> ./home/kali/.java/.userPrefs/burp/prefs.xml <<- EOF
	  <entry key="free.suite.feedbackReportingEnabled" value="false"/>
	  <entry key="eulacommunity" value="4"/>
	</map>
	EOF

	echo "set tabsize 4" > ./home/kali/.nanorc

	mkdir --parents ./home/kali/.ssh
	cat > ./home/kali/.ssh/config <<- EOF
	Host *
	    ForwardAgent no
	EOF
	chmod 700 ./home/kali/.ssh
	chmod 600 ./home/kali/.ssh/*

	mkdir --parents ./home/kali/.tmux
	cat > ./home/kali/.tmux.conf <<- EOF
	set-option -g default-shell /usr/bin/zsh
	set-option -g default-terminal tmux-256color
	set-option -g allow-passthrough off
	set-option -g history-limit 65536

	set-option -g mouse on
	set-option -s set-clipboard off

	bind-key -T copy-mode    MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
	bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
	EOF

	cat > ./home/kali/.zshenv <<- EOF
	#!/usr/bin/env zsh

	export LANG=en_US.UTF-8

	alias pbcopy="\$(which xclip) -in -selection clipboard"
	alias pbpaste="\$(which xclip) -out -selection clipboard"

	[[ -f /tmp/okc-ssh-agent.env ]] && source /tmp/okc-ssh-agent.env

	if [[ "\$SHELL" =~ .*/zsh$ ]]; then
	    eval "\$(mise activate zsh)"
	elif [[ "\$SHELL" =~ .*/bash$ ]]; then
	    eval "\$(mise activate bash)"
	fi
	EOF

	ln --symbolic --force .zshenv ./home/kali/.bash_aliases

	mkdir --parents ./home/kali/Documents

	run_proot_cmd chown --recursive kali:kali /home/kali
}
