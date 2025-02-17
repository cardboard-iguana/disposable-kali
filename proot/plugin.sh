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
		at-spi2-core \
		bc \
		build-essential \
		burpsuite \
		code-oss \
		dialog \
		fonts-noto \
		fonts-recommended \
		kali-desktop-xfce \
		kali-undercover \
		less \
		libffi-dev \
		libyaml-dev \
		metasploit-framework \
		nano \
		openssh-client \
		pm-utils \
		tmux \
		tumbler \
		uuid-runtime \
		xclip \
		xfce4-notifyd \
		xorg \
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
	cat > ./usr/local/sbin/system-update-cleanup.sh <<- EOF
	#!/usr/bin/env bash

	# Fix bad permissions on /usr/bin/sudo
	#
	chmod u+s /usr/bin/sudo

	# Fix VS Code files
	#
	sed -i 's#/usr/lib/code-oss/code-oss#/usr/bin/code-oss#' /usr/share/applications/code-oss.desktop
	sed -i 's#/usr/lib/code-oss/code-oss#/usr/bin/code-oss#' /usr/share/applications/code-oss-url-handler.desktop

	sed -i 's#"serviceUrl": "https://open-vsx.org/vscode/gallery",#"serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery","cacheUrl": "https://vscode.blob.core.windows.net/gallery/index",#' /usr/lib/code-oss/resources/app/product.json
	sed -i 's#"itemUrl": "https://open-vsx.org/vscode/item"#"itemUrl": "https://marketplace.visualstudio.com/items"#'                                                                                            /usr/lib/code-oss/resources/app/product.json

	# PostgreSQL upgrade hack
	#
	sed -i 's/^stop_version/#stop_version/' /var/lib/dpkg/info/postgresql-??.prerm

	# FIXME: Unfortunately, setting the XFCE desktop backdrop is broken as
	# of 2025-01-02 for outputs whose names contain spaces. This causes
	# xfdesktop to always load /usr/share/backgrounds/xfce/xfce-x.svg as the
	# backdrop, rather than applying the solid color set above. As a stupid
	# work-around, we overwrite the default backdrop with one that is the
	# desired solid color.
	#
	cat > /usr/share/backgrounds/xfce/xfce-x.svg << SVG
	<?xml version="1.0" encoding="UTF-8" standalone="no"?>
	<svg width="3840"
	     height="2160"
	     viewBox="0 0 3840 2160"
	     version="1.1"
	     style="background-color: #19315a;"
	     xmlns="http://www.w3.org/2000/svg">
	<rect style="fill: #19315a; fill-opacity: 1;"
	      width="3840"
	      height="2160"
	      x="0"
	      y="0" />
	</svg>
	SVG
	EOF

	chmod 755 ./usr/local/sbin/system-update-cleanup.sh

	run_proot_cmd /usr/local/sbin/system-update-cleanup.sh

	# Create update script (useful for long-running environments)
	#
	cat > ./usr/local/bin/update.sh <<- EOF
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

	sudo /usr/local/sbin/system-update-cleanup.sh

	mise upgrade
	EOF

	chmod 755 ./usr/local/bin/update.sh

	# Enforce user-level customizations
	#
	cat > ./usr/local/bin/user-settings.sh <<- EOF
	#!/usr/bin/env bash

	# Make sure that XFCE's background is set to a solid color
	#
	XRDP_BG_COLOR=19315A

	RED="\$(echo "ibase=16 ; scale=24; \${XRDP_BG_COLOR:0:2} / FF" | bc)"
	GREEN="\$(echo "ibase=16 ; scale=24; \${XRDP_BG_COLOR:2:2} / FF" | bc)"
	BLUE="\$(echo "ibase=16 ; scale=24; \${XRDP_BG_COLOR:4:2} / FF" | bc)"

	MONITOR="\$(xrandr --current | grep connected | sed 's/connected.*//;s/ //g')"

	xfconf-query --channel xfce4-desktop --property /backdrop/single-workspace-mode                            --create --type bool   --set true
	xfconf-query --channel xfce4-desktop --property /backdrop/single-workspace-number                          --create --type int    --set 0
	xfconf-query --channel xfce4-desktop --property /backdrop/screen0/monitor\${MONITOR}/workspace0/image-style --create --type int    --set 0
	xfconf-query --channel xfce4-desktop --property /backdrop/screen0/monitor\${MONITOR}/workspace0/color-style --create --type int    --set 0
	xfconf-query --channel xfce4-desktop --property /backdrop/screen0/monitor\${MONITOR}/workspace0/rgba1       --create --type double --set \$RED \\
	                                                                                                                    --type double --set \$GREEN \\
	                                                                                                                    --type double --set \$BLUE \\
	                                                                                                                    --type double --set 1

	# Set theme
	#
	gsettings set org.xfce.mousepad.preferences.view color-scheme Kali-Light
	gsettings set org.gnome.desktop.interface        gtk-theme    Kali-Light
	gsettings set org.gnome.desktop.interface        icon-theme   Windows-10-Icons

	xfconf-query --channel xfce4-notifyd --property /theme                                 --create --type string --set Retro
	xfconf-query --channel xfce4-notifyd --property /notify-location                       --create --type string --set bottom-right
	xfconf-query --channel xfce4-panel   --property /panels/dark-mode                      --create --type bool   --set true
	xfconf-query --channel xfce4-panel   --property /panels/panel-1/icon-size              --create --type uint   --set 24
	xfconf-query --channel xfce4-panel   --property /panels/panel-1/position               --create --type string --set "p=8;x=0;y=0"
	xfconf-query --channel xfce4-panel   --property /panels/panel-1/size                   --create --type uint   --set 44
	xfconf-query --channel xfce4-panel   --property /plugins/plugin-11/show-labels         --create --type bool   --set true
	xfconf-query --channel xfce4-panel   --property /plugins/plugin-11/grouping            --create --type bool   --set false
	xfconf-query --channel xfce4-panel   --property /plugins/plugin-19/digital-time-format --create --type string --set "%Y-%m-%d @ %H:%M:%S %Z"
	xfconf-query --channel xfce4-panel   --property /plugins/plugin-19/digital-time-font   --create --type string --set "Noto Mono 11"
	xfconf-query --channel xfce4-panel   --property /plugins/plugin-22/items               --create --type string --set "-lock-screen" \\
	                                                                                                --type string --set "+logout"
	xfconf-query --channel xfce4-panel   --property /plugins/plugin-2200/items             --create --type string --set "-lock-screen" \\
	                                                                                                --type string --set "+logout"
	xfconf-query --channel xfwm4         --property /general/theme                         --create --type string --set Kali-Light
	xfconf-query --channel xsettings     --property /Net/IconThemeName                     --create --type string --set Windows-10-Icons
	xfconf-query --channel xsettings     --property /Net/ThemeName                         --create --type string --set Kali-Light

	# Disable session saving
	#
	xfconf-query --channel xfce4-session --property /general/AutoSave    --create --type bool --set false
	xfconf-query --channel xfce4-session --property /general/SaveOnExit  --create --type bool --set false
	xfconf-query --channel xfce4-session --property /general/SessionName --create --type string --set Default

	# Disable screensaver
	#
	xfconf-query --channel xfce4-screensaver --property /lock/enabled  --create --type bool --set false
	xfconf-query --channel xfce4-screensaver --property /saver/enabled --create --type bool --set false
	EOF

	chmod 755 ./usr/local/bin/user-settings.sh

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

	# Create startup scripts
	#
	cat > ./usr/local/sbin/tui.sh <<- EOF
	#!/usr/bin/env bash

	sudo -u postgres /etc/init.d/postgresql start

	/usr/bin/env tmux -2 new-session

	sudo -u postgres /etc/init.d/postgresql stop
	EOF

	chmod 755 ./usr/local/sbin/tui.sh

	cat > ./usr/local/sbin/gui.sh <<- EOF
	#!/usr/bin/env bash

	sudo -u postgres /etc/init.d/postgresql start

	dbus-launch --exit-with-session startxfce4

	sudo -u postgres /etc/init.d/postgresql stop
	EOF

	chmod 755 ./usr/local/sbin/gui.sh

	# Generate local self-signed certificate (for PostgreSQL)
	#
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive make-ssl-cert generate-default-snakeoil
	chmod 600 ./etc/ssl/private/ssl-cert-snakeoil.key

	# User setup.
	#
	run_proot_cmd usermod --append --groups adm,audio,cdrom,dialout,dip,floppy,kali-trusted,netdev,plugdev,sudo,staff,users,video kali

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

	mkdir --parents ./home/kali/.config/autostart

	cat > ./home/kali/.config/autostart/nm-applet.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Disable NetworkManager applet
	Exec=/usr/bin/true
	StartupNotify=false
	Terminal=false
	Hidden=true
	EOF

	cat > ./home/kali/.config/autostart/user-settings.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Configure user settings
	Exec=/usr/local/bin/user-settings.sh
	StartupNotify=false
	Terminal=false
	Hidden=false
	EOF

	cat > ./home/kali/.config/autostart/xfce4-power-manager.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Disable Xfce power management applet
	Exec=/usr/bin/true
	StartupNotify=false
	Terminal=false
	Hidden=true
	EOF

	cat > ./home/kali/.config/autostart/xscreensaver.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Disable X screen saver
	Exec=/usr/bin/true
	StartupNotify=false
	Terminal=false
	Hidden=true
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
	gtk-theme-name = Kali-Light
	EOF

	mkdir --parents ./home/kali/.config/qt5ct
	sed 's#^icon_theme=.\+#icon_theme=Windows-10-Icons#;s#^color_scheme_path=.\+#color_scheme_path=/usr/share/qt5ct/colors/Kali-Light.conf#' ./etc/xdg/qt5ct/qt5ct.conf > ./home/kali/.config/qt5ct/qt5ct.conf

	mkdir --parents ./home/kali/.config/qt6ct
	sed 's#^icon_theme=.\+#icon_theme=Windows-10-Icons#;s#^color_scheme_path=.\+#color_scheme_path=/usr/share/qt6ct/colors/Kali-Light.conf#' ./etc/xdg/qt6ct/qt6ct.conf > ./home/kali/.config/qt6ct/qt6ct.conf

	mkdir --parents ./home/kali/.config/qterminal.org
	sed 's/^colorScheme=Kali-Dark/colorScheme=Kali-Light/;s/^ApplicationTransparency=.\+/ApplicationTransparency=0/' ./etc/xdg/qterminal.org/qterminal.ini > ./home/kali/.config/qterminal.org/qterminal.ini

	ln --symbolic --force .face ./home/kali/.face.icon

	cat > ./home/kali/.gtkrc-2.0 <<- EOF
	gtk-icon-theme-name = "Windows-10-Icons"
	gtk-theme-name = "Kali-Light"
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
