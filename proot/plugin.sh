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
		at-spi2-core \
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
		metasploit-framework \
		nano \
		npm \
		openssh-client \
		pm-utils \
		tmux \
		xclip \
		xorg

	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt autoremove --quiet --assume-yes --purge --autoremove
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt clean      --quiet --assume-yes

	# System configuration
	#
	sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' ./etc/locale.gen
	run_proot_cmd env DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales

	run_proot_cmd ln --symbolic --force /usr/share/zoneinfo/$(getprop persist.sys.timezone) /etc/localtime

	mv ./usr/bin/systemctl ./usr/bin/systemctl.bin

	cat > ./usr/bin/systemctl.sh <<- EOF
	#!/usr/bin/env bash

	service \$2 \$1
	EOF

	chmod 755 ./usr/bin/systemctl.sh

	cp ./usr/bin/systemctl.sh ./usr/bin/systemctl

	run_proot_cmd env DEBIAN_FRONTEND=noninteractive make-ssl-cert generate-default-snakeoil
	chmod 600 ./etc/ssl/private/ssl-cert-snakeoil.key

	touch ./root/.hushlogin
	touch ./var/lib/postgresql/.hushlogin
	mkdir --parents ./root/.tmux

	chmod u+s ./usr/bin/sudo

	# Make sure that problematic services are disabled (power
	# management, screen saver, etc.)
	#
	rm --force ./etc/xdg/autostart/nm-applet.desktop           &> /dev/null
	rm --force ./etc/xdg/autostart/xfce4-power-manager.desktop &> /dev/null
	rm --force ./etc/xdg/autostart/xscreensaver.desktop        &> /dev/null

	sed -i 's/"cpugraph"/"cpugraph-disabled"/'                         ./etc/xdg/xfce4/panel/default.xml
	sed -i 's/"power-manager-plugin"/"power-manager-plugin-disabled"/' ./etc/xdg/xfce4/panel/default.xml
	sed -i 's/"+lock-screen"/"-lock-screen"/'                          ./etc/xdg/xfce4/panel/default.xml

	# Fix VS Code .desktop files
	#
	sed -i 's#/usr/lib/code-oss/code-oss#/usr/bin/code-oss#' /usr/share/applications/code-oss.desktop
	sed -i 's#/usr/lib/code-oss/code-oss#/usr/bin/code-oss#' /usr/share/applications/code-oss-url-handler.desktop

	# Create update script (useful for long-running environments)
	#
	cat > ./usr/local/bin/update.sh <<- EOF
	#!/usr/bin/env bash

	sudo cp /usr/bin/systemctl.bin /usr/bin/systemctl

	sudo apt update
	sudo apt full-upgrade
	sudo apt autoremove --purge --autoremove
	sudo apt clean

	sudo cp /usr/bin/systemctl.sh /usr/bin/systemctl
	sudo chmod u+s /usr/bin/sudo

	sudo rm --force /etc/xdg/autostart/nm-applet.desktop           &> /dev/null
	sudo rm --force /etc/xdg/autostart/xfce4-power-manager.desktop &> /dev/null
	sudo rm --force /etc/xdg/autostart/xscreensaver.desktop        &> /dev/null

	sudo sed -i 's#/usr/lib/code-oss/code-oss#/usr/bin/code-oss#' /usr/share/applications/code-oss.desktop
	sudo sed -i 's#/usr/lib/code-oss/code-oss#/usr/bin/code-oss#' /usr/share/applications/code-oss-url-handler.desktop

	sudo sed -i 's/"cpugraph"/"cpugraph-disabled"/'                         /etc/xdg/xfce4/panel/default.xml
	sudo sed -i 's/"power-manager-plugin"/"power-manager-plugin-disabled"/' /etc/xdg/xfce4/panel/default.xml
	sudo sed -i 's/"+lock-screen"/"-lock-screen"/'                          /etc/xdg/xfce4/panel/default.xml

	cp --archive --force --no-target-directory /etc/skel \$HOME

	ln --symbolic --force .face \$HOME/.face.icon

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

	# Create startup scripts.
	#
	cat > ./usr/local/bin/tui.sh <<- EOF
	#!/usr/bin/env bash

	sudo -u postgres /etc/init.d/postgresql start

	export LANG=en_US.UTF-8
	export SHELL=\$(which zsh)
	export TMUX_TMPDIR=\$HOME/.tmux

	/usr/bin/env zsh

	sudo -u postgres /etc/init.d/postgresql stop
	EOF

	chmod 755 ./usr/local/bin/tui.sh

	cat > ./usr/local/bin/gui.sh <<- EOF
	#!/usr/bin/env bash

	sudo -u postgres /etc/init.d/postgresql start

	export DISPLAY=:0
	export GALLIUM_DRIVER=virpipe
	export LANG=en_US.UTF-8
	export MESA_GL_VERSION_OVERRIDE=4.0
	export PULSE_SERVER=tcp:127.0.0.1
	export QT_QPA_PLATFORMTHEME=qt5ct
	export SHELL=\$(which zsh)
	export TMUX_TMPDIR=\$HOME/.tmux

	dbus-launch --exit-with-session startxfce4

	sudo -u postgres /etc/init.d/postgresql stop
	EOF

	chmod 755 ./usr/local/bin/gui.sh

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
	                "look_and_feel":"Dark"
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
	Name=Disable session autosave
	Exec=xfconf-query --channel xfce4-session --property /general/SaveOnExit --create --type bool --set false
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

	cat > ./home/kali/.config/autostart/set-session-name.desktop <<- EOF
	[Desktop Entry]
	Type=Application
	Name=Disable session autosave
	Exec=xfconf-query --channel xfce4-session --property /general/SessionName --create --type string --set Default
	StartupNotify=false
	Terminal=false
	Hidden=false
	EOF

	mkdir --parents ./home/kali/.config/"Code - OSS"/User
	echo '{"window.titleBarStyle":"custom"}' > ./home/kali/.config/"Code - OSS"/User/settings.json

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

	mkdir --parents ./home/kali/.tmux

	cat > ./home/kali/.tmux.conf <<- EOF
	set -g default-terminal "tmux-256color"
	set -g allow-passthrough off
	set -g history-limit 16383

	set -g mouse on
	set-option -s set-clipboard off
	bind-key -T copy-mode    MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
	bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
	EOF

	cat > ./home/kali/.zshenv <<- EOF
	#!/usr/bin/env zsh

	export LANG=en_US.UTF-8

	if [[ -z "\$TMUX" ]] && [[ ! -e \$HOME/no-tmux.txt ]] && [[ \$- == *i* ]] && [[ -n "\$DISPLAY" ]] && [[ -z "\$VSCODE_PID" ]]; then
	    if [[ \$(tmux list-sessions 2> /dev/null | grep -vc "(attached)") -eq 0 ]]; then
	        exec tmux -2 new-session
	    else
	        exec tmux -2 attach-session
	    fi
	fi
	alias ntterm="qterminal &> /dev/null & disown"
	EOF

	ln --symbolic --force .zshenv ./home/kali/.bash_aliases

	mkdir --parents ./home/kali/Documents

	run_proot_cmd chown --recursive kali:kali /home/kali
}
