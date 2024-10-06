#!/usr/bin/env bash

DISTRO_NAME="{{distro-name}}"
DISTRO_COMMENT="Kali Linux NetHunter (build date {{build-date}})"
TARBALL_URL['aarch64']="https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-minimal.tar.xz"
TARBALL_SHA256['aarch64']="{{tarball-sha256}}"

distro_setup() {
	# Install applications
	#
	echo 'APT::Install-Recommends "false";' >  ./etc/apt/apt.conf.d/minimal-installs
	echo 'APT::Install-Suggests "false";'   >> ./etc/apt/apt.conf.d/minimal-installs

	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt update       --quiet --assume-yes --fix-missing
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt full-upgrade --quiet --assume-yes --fix-broken

	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt install --quiet --assume-yes \
		asciinema \
		at-spi2-core \
		bc \
		burpsuite \
		code-oss \
		dialog \
		flameshot \
		fonts-droid-fallback \
		fonts-liberation \
		fonts-liberation-sans-narrow \
		fonts-noto \
		fonts-noto-cjk-extra \
		fonts-noto-color-emoji \
		fonts-noto-extra \
		fonts-noto-ui-core \
		fonts-noto-ui-extra \
		fonts-noto-unhinted \
		kali-desktop-xfce \
		kali-undercover \
		metasploit-framework \
		nano \
		npm \
		openssh-client \
		pm-utils \
		recordmydesktop \
		tumbler \
		uuid-runtime \
		xfce4-notifyd \
		xorg \
		yarnpkg

	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt autoremove --quiet --assume-yes --purge --autoremove
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt clean      --quiet --assume-yes

	# System configuration
	#
	sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' ./etc/locale.gen
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales

	run_proot_cmd ln --symbolic --force /usr/share/zoneinfo/$(getprop persist.sys.timezone) /etc/localtime

	mkdir --parents ./usr/local/bin
	run_proot_cmd ln --symbolic --force /usr/bin/yarnpkg /usr/local/bin/yarn

	cat > ./usr/bin/systemctl.sh <<- EOF
	#!/usr/bin/env bash
	service \$2 \$1
	EOF

	chmod 755 ./usr/bin/systemctl.sh

	cp ./usr/bin/systemctl    ./usr/bin/systemctl.bin
	cp ./usr/bin/systemctl.sh ./usr/bin/systemctl

	touch ./root/.hushlogin
	touch ./var/lib/postgresql/.hushlogin

	# Create (and run) system update cleanup script.
	#
	cat > ./usr/local/sbin/system-update-cleanup.sh <<- EOF
	# Fix bad permissions on /usr/bin/sudo
	#
	chmod u+s /usr/bin/sudo

	# Make sure that problematic services are disabled (power
	# management, screen saver, etc.)
	#
	sed -i 's/"cpugraph"/"cpugraph-disabled"/'                         /etc/xdg/xfce4/panel/default.xml
	sed -i 's/"power-manager-plugin"/"power-manager-plugin-disabled"/' /etc/xdg/xfce4/panel/default.xml
	sed -i 's/"+lock-screen"/"-lock-screen"/'                          /etc/xdg/xfce4/panel/default.xml

	# Additional customizations
	#
	sed -i 's/"p=6;x=0;y=0"/"p=8;x=0;y=0"/'                                                              /etc/xdg/xfce4/panel/default.xml
	sed -i 's/name="size" type="uint" value="28"/name="size" type="uint" value="44"/'                    /etc/xdg/xfce4/panel/default.xml
	sed -i 's/name="icon-size" type="uint" value="22"/name="icon-size" type="uint" value="24"/'          /etc/xdg/xfce4/panel/default.xml
	sed -i 's/name="show-labels" type="bool" value="false"/name="show-labels" type="bool" value="true"/' /etc/xdg/xfce4/panel/default.xml
	sed -i 's/name="grouping" type="uint" value="1"/name="grouping" type="bool" value="false"/'          /etc/xdg/xfce4/panel/default.xml
	sed -i 's/"Cantarell 11"/"Noto Mono 11"/'                                                            /etc/xdg/xfce4/panel/default.xml
	sed -i 's/"%_H:%M"/"%Y-%m-%d @ %H:%M:%S %Z"/'                                                        /etc/xdg/xfce4/panel/default.xml

	sed -i 's#<property name="last-image" type="string" value="/usr/share/backgrounds/kali-16x9/default"/>#<property name="last-image" type="empty"/>#'                    /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
	sed -i 's#<property name="image-style" type="int" value="5"/>#<property name="color-style" type="int" value="0"/><property name="image-style" type="int" value="0"/>#' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
	sed -i 's#<property name="image-show" type="bool" value="true"/>#<property name="image-show" type="bool" value="false"/>#'                                             /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml

	sed -i 's/"Kali-Dark"/"Windows-10"/' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml

	sed -i 's/"Kali-Dark"/"Windows-10"/'                  /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
	sed -i 's/"Flat-Remix-Blue-Dark"/"Windows-10-Icons"/' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml

	sed -i 's/^icon_theme=.\\+/icon_theme=Windows-10-Icons/'                                   /etc/xdg/qt5ct/qt5ct.conf
	sed -i 's#^color_scheme_path=.\\+#color_scheme_path=/usr/share/qt5ct/colors/Windows.conf#' /etc/xdg/qt5ct/qt5ct.conf

	sed -i 's/^colorScheme=Kali-Dark/colorScheme=Kali-Light/'           /etc/xdg/qterminal.org/qterminal.ini
	sed -i 's/^ApplicationTransparency=.\\+/ApplicationTransparency=0/' /etc/xdg/qterminal.org/qterminal.ini

	# Fix VS Code files
	#
	sed -i 's#/usr/lib/code-oss/code-oss#/usr/bin/code-oss#' /usr/share/applications/code-oss.desktop
	sed -i 's#/usr/lib/code-oss/code-oss#/usr/bin/code-oss#' /usr/share/applications/code-oss-url-handler.desktop

	sed -i 's#"serviceUrl": "https://open-vsx.org/vscode/gallery",#"serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery","cacheUrl": "https://vscode.blob.core.windows.net/gallery/index",#' /usr/lib/code-oss/resources/app/product.json
	sed -i 's#"itemUrl": "https://open-vsx.org/vscode/item"#"itemUrl": "https://marketplace.visualstudio.com/items"#'                                                                                            /usr/lib/code-oss/resources/app/product.json

	# PostgreSQL upgrade hack
	#
	sed -i 's/^stop_version/#stop_version/' /var/lib/dpkg/info/postgresql-16.prerm
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

	sudo -u postgres /etc/init.d/postgresql stop

	sudo /usr/local/sbin/system-update-cleanup.sh

	cp --archive --force --no-target-directory /etc/skel \$HOME

	ln --symbolic --force \$HOME/.face \$HOME/.face.icon

	head --lines -1 /etc/skel/.java/.userPrefs/burp/prefs.xml > \$HOME/.java/.userPrefs/burp/prefs.xml
	cat >> \$HOME/.java/.userPrefs/burp/prefs.xml << CONF
	  <entry key="free.suite.alertsdisabledforjre-4166355790" value="true"/>
	  <entry key="free.suite.alertsdisabledforjre-576990537" value="true"/>
	  <entry key="free.suite.feedbackReportingEnabled" value="false"/>
	  <entry key="eulacommunity" value="4"/>
	</map>
	CONF
	EOF

	chmod 755 ./usr/local/bin/update.sh

	# We need a custom script to make sure that XFCE's background is
	# set consistently to a solid color (and *stays* set between
	# sessions).
	#
	cat > ./usr/local/bin/set-background-to-solid-color.sh <<- EOF
	#!/usr/bin/env bash

	XRDP_BG_COLOR=19315A

	RED="\$(echo "ibase=16 ; scale=24; \${XRDP_BG_COLOR:0:2} / FF" | bc)"
	GREEN="\$(echo "ibase=16 ; scale=24; \${XRDP_BG_COLOR:2:2} / FF" | bc)"
	BLUE="\$(echo "ibase=16 ; scale=24; \${XRDP_BG_COLOR:4:2} / FF" | bc)"

	xfconf-query --channel xfce4-desktop --list | grep -E '^/backdrop/' | sed 's#/[^/]\\+\$##' | sort -u | while read BACKDROP; do
		xfconf-query --channel xfce4-desktop --property \$BACKDROP/image-style --create --type int --set 0
		xfconf-query --channel xfce4-desktop --property \$BACKDROP/color-style --create --type int --set 0
		xfconf-query --channel xfce4-desktop --property \$BACKDROP/rgba1       --create \\
		             --type double --set \$RED \\
		             --type double --set \$GREEN \\
		             --type double --set \$BLUE \\
		             --type double --set 1
	done
	EOF

	chmod 755 ./usr/local/bin/set-background-to-solid-color.sh

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

	# Create startup scripts.
	#
	cat > ./usr/local/sbin/tui.sh <<- EOF
	#!/usr/bin/env bash

	sudo -u postgres /etc/init.d/postgresql start

	export LANG=en_US.UTF-8
	export SHELL=\$(which zsh)

	/usr/bin/env zsh

	sudo -u postgres /etc/init.d/postgresql stop
	EOF

	chmod 755 ./usr/local/sbin/tui.sh

	cat > ./usr/local/sbin/gui.sh <<- EOF
	#!/usr/bin/env bash

	sudo -u postgres /etc/init.d/postgresql start

	export DISPLAY=:0
	export GALLIUM_DRIVER=virpipe
	export LANG=en_US.UTF-8
	export MESA_GL_VERSION_OVERRIDE=4.5
	export PULSE_SERVER=tcp:127.0.0.1
	export QT_QPA_PLATFORMTHEME=qt5ct
	export SHELL=\$(which zsh)

	dbus-launch --exit-with-session startxfce4

	sudo -u postgres /etc/init.d/postgresql stop
	EOF

	chmod 755 ./usr/local/sbin/gui.sh

	# Generate local self-signed certificate (for PostgreSQL).
	#
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive make-ssl-cert generate-default-snakeoil
	chmod 600 ./etc/ssl/private/ssl-cert-snakeoil.key

	# User setup.
	#
	run_proot_cmd usermod --append --groups adm,audio,cdrom,dialout,dip,floppy,kali-trusted,netdev,plugdev,sudo,staff,users,video kali

	echo "kali ALL=(ALL:ALL) NOPASSWD: ALL" > ./etc/sudoers.d/kali

	# Home directory setup.
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

	cat > ./home/kali/.config/autostart/disable-session-autosave.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Disable session autosave
	Exec=xfconf-query --channel xfce4-session --property /general/AutoSave --create --type bool --set false
	StartupNotify=false
	Terminal=false
	Hidden=false
	EOF

	cat > ./home/kali/.config/autostart/disable-session-save-on-exit.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Disable session save-on-exit
	Exec=xfconf-query --channel xfce4-session --property /general/SaveOnExit --create --type bool --set false
	StartupNotify=false
	Terminal=false
	Hidden=false
	EOF

	cat > ./home/kali/.config/autostart/nm-applet.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Disable NetworkManager applet
	Exec=/usr/bin/true
	StartupNotify=false
	Terminal=false
	Hidden=true
	EOF

	cat > ./home/kali/.config/autostart/set-background-to-solid-color.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Set background to solid color
	Exec=/usr/local/bin/set-background-to-solid-color.sh
	StartupNotify=false
	Terminal=false
	Hidden=false
	EOF

	cat > ./home/kali/.config/autostart/set-flameshot-desktop-shortcut.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Set Flameshot full desktop screenshot shortcut
	Exec=xfconf-query --channel xfce4-keyboard-shortcuts --property "/commands/custom/<Primary><Shift><Alt>p" --create --type string --set "flameshot full --clipboard --path ./home/kali/Desktop"
	StartupNotify=false
	Terminal=false
	Hidden=false
	EOF

	cat > ./home/kali/.config/autostart/set-flameshot-selection-shortcut.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Set Flameshot selected area screenshot shortcut
	Exec=xfconf-query --channel xfce4-keyboard-shortcuts --property "/commands/custom/<Primary><Alt>p" --create --type string --set "flameshot gui --clipboard --path ./home/kali/Desktop"
	StartupNotify=false
	Terminal=false
	Hidden=false
	EOF

	cat > ./home/kali/.config/autostart/set-mousepad-color-scheme.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Set Mousepad color scheme
	Exec=gsettings set org.xfce.mousepad.preferences.view color-scheme Kali-Light
	StartupNotify=false
	Terminal=false
	Hidden=false
	EOF

	cat > ./home/kali/.config/autostart/set-session-name.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Set session name
	Exec=xfconf-query --channel xfce4-session --property /general/SessionName --create --type string --set Default
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
	Name=Disable screen saver
	Exec=/usr/bin/true
	StartupNotify=false
	Terminal=false
	Hidden=true
	EOF

	mkdir --parents ./home/kali/.config/"Code - OSS"/User
	cat > ./home/kali/.config/"Code - OSS"/User/settings.json <<- JSON
	{
	    "window.titleBarStyle": "custom",
	    "workbench.colorTheme": "Default Light Modern"
	}
	JSON

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
	  <entry key="free.suite.alertsdisabledforjre-4166355790" value="true"/>
	  <entry key="free.suite.alertsdisabledforjre-576990537" value="true"/>
	  <entry key="free.suite.feedbackReportingEnabled" value="false"/>
	  <entry key="eulacommunity" value="4"/>
	</map>
	EOF

	echo "set tabsize 4" > ./home/kali/.nanorc

	mkdir -p ./home/kali/.ssh
	cat > ./home/kali/.ssh/config <<- EOF
	Host *
	    ForwardAgent no
	EOF
	chmod 700 ./home/kali/.ssh
	chmod 600 ./home/kali/.ssh/*

	cat > ./home/kali/.zshenv <<- EOF
	#!/usr/bin/env zsh

	export LANG=en_US.UTF-8

	[[ -f /tmp/okc-ssh-agent.env ]] && source /tmp/okc-ssh-agent.env
	EOF

	ln --symbolic --force .zshenv ./home/kali/.bash_aliases

	mkdir --parents ./home/kali/Documents

	run_proot_cmd chown --recursive kali:kali /home/kali
}
