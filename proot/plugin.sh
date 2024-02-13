#!/usr/bin/env bash

DISTRO_NAME="{{distro-name}}"
DISTRO_COMMENT="Kali Linux NetHunter (build date {{build-date}})"
TARBALL_URL['aarch64']="https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-minimal.tar.xz"
TARBALL_SHA256['aarch64']="{{tarball-sha256}}"

# Useful varibles that should already be set within proot-distro:
#
#    $INSTALLED_ROOTFS_DIR
#    $distro_name
#
# The root filesystem itself is $INSTALLED_ROOTFS_DIR/$distro_name.
#
distro_setup() {
	DISTRO_PREFIX="$INSTALLED_ROOTFS_DIR/$distro_name"

	if [[ -f "$DISTRO_PREFIX/etc/apt/sources.list" ]]; then
		# Install applications.
		#
		echo 'APT::Install-Recommends "false";' >  $DISTRO_PREFIX/etc/apt/apt.conf.d/minimal-installs
        	echo 'APT::Install-Suggests "false";'   >> $DISTRO_PREFIX/etc/apt/apt.conf.d/minimal-installs

		run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt update       --quiet --assume-yes --fix-missing
		run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt full-upgrade --quiet --assume-yes --fix-broken

		run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt install --quiet --assume-yes \
			burpsuite \
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
			openssh-client \
			tmux \
			xclip \
			xorg

		run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt autoremove --quiet --assume-yes --purge --autoremove
		run_proot_cmd env DEBIAN_FRONTEND=noninteractive apt clean      --quiet --assume-yes

		# System configuration.
		#
		sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' $DISTRO_PREFIX/etc/locale.gen
		run_proot_cmd locale-gen

		run_proot_cmd ln -sf /usr/share/zoneinfo/$(getprop persist.sys.timezone) /etc/localtime

		mv $DISTRO_PREFIX/usr/bin/systemctl $DISTRO_PREFIX/usr/bin/systemctl.bin

		cat > $DISTRO_PREFIX/usr/bin/systemctl.sh <<- EOF
		#!/usr/bin/env bash
		service \$2 \$1
		EOF

		chmod 755 $DISTRO_PREFIX/usr/bin/systemctl.sh

		cp $DISTRO_PREFIX/usr/bin/systemctl.sh $DISTRO_PREFIX/usr/bin/systemctl

		run_proot_cmd env DEBIAN_FRONTEND=noninteractive make-ssl-cert generate-default-snakeoil

		touch $DISTRO_PREFIX/root/.hushlogin

		run_proot_cmd bash -c "msfdb init && /etc/init.d/postgresql stop"

		# Make sure that problematic services are disabled (power
		# management, screen saver, etc.).
		#
		rm --force $DISTRO_PREFIX/etc/xdg/autostart/nm-applet.desktop           &> /dev/null
		rm --force $DISTRO_PREFIX/etc/xdg/autostart/xfce4-power-manager.desktop &> /dev/null
		rm --force $DISTRO_PREFIX/etc/xdg/autostart/xscreensaver.desktop        &> /dev/null

		sed -i 's/"cpugraph"/"cpugraph-disabled"/'                         $DISTRO_PREFIX/etc/xdg/xfce4/panel/default.xml
		sed -i 's/"power-manager-plugin"/"power-manager-plugin-disabled"/' $DISTRO_PREFIX/etc/xdg/xfce4/panel/default.xml
		sed -i 's/"pulseaudio"/"pulseaudio-disabled"/'                     $DISTRO_PREFIX/etc/xdg/xfce4/panel/default.xml
		sed -i 's/"+lock-screen"/"-lock-screen"/'                          $DISTRO_PREFIX/etc/xdg/xfce4/panel/default.xml

		# Create update script (useful for long-running containiners).
		#
		cat > $DISTRO_PREFIX/usr/local/bin/update.sh <<- EOF
		#!/usr/bin/env bash

		sudo cp /usr/bin/systemctl.bin /usr/bin/systemctl

		sudo apt update
		sudo apt full-upgrade
		sudo apt autoremove --purge --autoremove
		sudo apt clean

		sudo cp /usr/bin/systemctl.sh /usr/bin/systemctl

		sudo rm --force /etc/xdg/autostart/nm-applet.desktop           &> /dev/null
		sudo rm --force /etc/xdg/autostart/xfce4-power-manager.desktop &> /dev/null
		sudo rm --force /etc/xdg/autostart/xscreensaver.desktop        &> /dev/null

		sudo sed -i 's/"cpugraph"/"cpugraph-disabled"/'                         /etc/xdg/xfce4/panel/default.xml
		sudo sed -i 's/"power-manager-plugin"/"power-manager-plugin-disabled"/' /etc/xdg/xfce4/panel/default.xml
		sudo sed -i 's/"pulseaudio"/"pulseaudio-disabled"/'                     /etc/xdg/xfce4/panel/default.xml
		sudo sed -i 's/"+lock-screen"/"-lock-screen"/'                          /etc/xdg/xfce4/panel/default.xml

		while IFS= read -d '' -r SKEL_DIR; do
		    HOME_DIR="\$(echo "\$SKEL_DIR" | sed -e "s#^/etc/skel#\$HOME#")"
		    mkdir -p "\$HOME_DIR"
		done < <(find /etc/skel -mindepth 1 -type d -print0)

		while IFS= read -d '' -r SKEL_FILE; do
		    HOME_FILE="\$(echo "\$SKEL_FILE" | sed -e "s#^/etc/skel#\$HOME#")"
		    cp -apf "\$SKEL_FILE" "\$HOME_FILE"
		done < <(find /etc/skel -type f -print0)

		ln -sf \$HOME/.face \$HOME/.face.icon

		head --lines -1 /etc/skel/.java/.userPrefs/burp/prefs.xml > \$HOME/.java/.userPrefs/burp/prefs.xml
		cat >> \$HOME/.java/.userPrefs/burp/prefs.xml << CONF
		  <entry key="free.suite.alertsdisabledforjre-4166355790" value="true"/>
		  <entry key="free.suite.alertsdisabledforjre-576990537" value="true"/>
		  <entry key="free.suite.feedbackReportingEnabled" value="false"/>
		  <entry key="eulacommunity" value="4"/>
		</map>
		CONF
		EOF

		chmod 755 $DISTRO_PREFIX/usr/local/bin/update.sh

		# Create startup scripts.
		#
		cat > $DISTRO_PREFIX/usr/local/sbin/env-start.sh <<- EOF
		#!/usr/bin/env bash

		/etc/init.d/dbus start
		/etc/init.d/postgresql start
		EOF

		cat > $DISTRO_PREFIX/usr/local/sbin/env-stop.sh <<- EOF
		#!/usr/bin/env bash

		/etc/init.d/postgresql stop
		/etc/init.d/dbus stop
		EOF

		chmod 755 $DISTRO_PREFIX/usr/local/sbin/env-start.sh
		chmod 755 $DISTRO_PREFIX/usr/local/sbin/env-stop.sh

		cat > $DISTRO_PREFIX/usr/local/bin/tui.sh <<- EOF
		#!/usr/bin/env bash

		sudo /usr/local/sbin/env-start.sh

		/usr/bin/env bash

		sudo /usr/local/sbin/env-stop.sh
		EOF

		chmod 755 $DISTRO_PREFIX/usr/local/bin/tui.sh

		cat > $DISTRO_PREFIX/usr/local/bin/gui.sh <<- EOF
		#!/usr/bin/env bash

		sudo /usr/local/sbin/env-start.sh

		export DISPLAY=:0
		export GALLIUM_DRIVER=virpipe
		export MESA_GL_VERSION_OVERRIDE=4.0

		dbus-launch --exit-with-session startxfce4

		sudo /usr/local/sbin/env-stop.sh
		EOF

		chmod 755 $DISTRO_PREFIX/usr/local/bin/gui.sh
	else
		echo "Bad DISTRO_PREFIX! Post-install setup failed..."
	fi
}

#####################
## Dockerfile bits ##
#####################

# Create our normal user
#
RUN --mount=type=secret,id=USER_NAME --mount=type=secret,id=USER_PASS <<EOF
export USER_NAME="$(cat /run/secrets/USER_NAME)"

useradd --create-home \
        --shell /usr/bin/bash \
        --groups adm,audio,cdrom,dialout,dip,floppy,netdev,plugdev,sudo,staff,users,video \
          $USER_NAME

echo "${USER_NAME}:$(cat /run/secrets/USER_PASS)" | chpasswd

unset USER_NAME
EOF

# Home directory setup
#
RUN --mount=type=secret,id=USER_NAME <<EOF
export USER_NAME="$(cat /run/secrets/USER_NAME)"
export USER_HOME="/home/$USER_NAME"

touch $USER_HOME/.hushlogin

mkdir --parents $USER_HOME/.config/autostart

cat > $USER_HOME/.config/autostart/set-flameshot-selection-shortcut.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Set Flameshot selected area screenshot shortcut
Exec=xfconf-query --channel xfce4-keyboard-shortcuts --property "/commands/custom/<Primary><Alt>p" --create --type string --set "flameshot gui --clipboard --path $USER_HOME/Desktop"
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > $USER_HOME/.config/autostart/set-flameshot-desktop-shortcut.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Set Flameshot full desktop screenshot shortcut
Exec=xfconf-query --channel xfce4-keyboard-shortcuts --property "/commands/custom/<Primary><Shift><Alt>p" --create --type string --set "flameshot full --clipboard --path $USER_HOME/Desktop"
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > $USER_HOME/.config/autostart/set-session-name.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable session autosave
Exec=xfconf-query --channel xfce4-session --property /general/SessionName --create --type string --set Default
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > $USER_HOME/.config/autostart/disable-session-autosave.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable session autosave
Exec=xfconf-query --channel xfce4-session --property /general/AutoSave --create --type bool --set false
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > $USER_HOME/.config/autostart/disable-session-save-on-exit.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable session autosave
Exec=xfconf-query --channel xfce4-session --property /general/SaveOnExit --create --type bool --set false
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

mkdir --parents $USER_HOME/.BurpSuite
cat > $USER_HOME/.BurpSuite/UserConfigCommunity.json << CONF
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
CONF

mkdir --parents $USER_HOME/.java/.userPrefs/burp
head --lines -1 /etc/skel/.java/.userPrefs/burp/prefs.xml > $USER_HOME/.java/.userPrefs/burp/prefs.xml
cat >> $USER_HOME/.java/.userPrefs/burp/prefs.xml << CONF
  <entry key="free.suite.alertsdisabledforjre-4166355790" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-576990537" value="true"/>
  <entry key="free.suite.feedbackReportingEnabled" value="false"/>
  <entry key="eulacommunity" value="4"/>
</map>
CONF


mkdir -p $USER_HOME/.ssh
cat > $USER_HOME/.ssh/config << CONF
Host *
    ForwardAgent no
CONF
chmod 700 $USER_HOME/.ssh
chmod 600 $USER_HOME/.ssh/*

cat > $USER_HOME/.inputrc << CONF
"\\e[A": history-search-backward
"\\eOA": history-search-backward

"\\e[B": history-search-forward
"\\eOB": history-search-forward
CONF

cat > $USER_HOME/.bash_aliases << CONF
#!/usr/bin/env bash

export LANG=en_US.UTF-8

if [[ -z "\$TMUX" ]] && [[ ! -e \$HOME/no-tmux.txt ]] && [[ \$- == *i* ]] && [[ -n "\$DISPLAY" ]] && [[ -z "\$VSCODE_PID" ]]; then
    tmux list-sessions | grep \$(hostname) \\
                       | grep "(attached)" > /dev/null \\
                      || exec tmux -2 new-session -A -s \$(hostname)
fi
CONF

cat > $USER_HOME/.xsessionrc << CONF
#!/usr/bin/env bash

export LANG=en_US.UTF-8
CONF

cat > $USER_HOME/.tmux.conf << CONF
set -g default-terminal "tmux-256color"
set -g allow-passthrough off
set -g history-limit 16383

set -g mouse on
set-option -s set-clipboard off
bind-key -T copy-mode    MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
CONF

echo "set tabsize 4" > $USER_HOME/.nanorc

mkdir --parents $USER_HOME/Documents

chown --recursive $USER_NAME:$USER_NAME $USER_HOME

unset USER_NAME USER_HOME
EOF

# Docker exec/start
#
EXPOSE 3389
ENTRYPOINT ["/usr/bin/bash"]
CMD ["/usr/local/sbin/docker-init.sh"]
