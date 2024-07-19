FROM kalilinux/kali-rolling

# Configure APT
#
RUN <<EOF
echo 'APT::Install-Recommends "false";' >  /etc/apt/apt.conf.d/minimal-installs
echo 'APT::Install-Suggests "false";'   >> /etc/apt/apt.conf.d/minimal-installs
EOF

# Make sure that base system is sane
#
RUN <<EOF
export DEBIAN_FRONTEND=noninteractive

apt update       --quiet --assume-yes --fix-missing
apt full-upgrade --quiet --assume-yes --fix-broken

unset DEBIAN_FRONTEND
EOF

# Install applications
#
RUN <<EOF
export DEBIAN_FRONTEND=noninteractive

apt install --quiet --assume-yes \
    asciinema \
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
    openvpn \
    recordmydesktop \
    tumbler \
    uuid-runtime \
    xorg \
    xorgxrdp \
    xrdp \
    yarnpkg

unset DEBIAN_FRONTEND
EOF

# Clean up installation
#
RUN <<EOF
export DEBIAN_FRONTEND=noninteractive

apt autoremove --quiet --assume-yes --purge --autoremove
apt clean      --quiet --assume-yes

unset DEBIAN_FRONTEND
EOF

# Make sure locale is built
#
RUN <<EOF
sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
EOF

# Set time zone
#
RUN --mount=type=secret,id=config <<EOF
eval "$(cat /run/secrets/config)"

ln --symbolic --force /usr/share/zoneinfo/$TIMEZONE /etc/localtime

unset IS_MACOS USER_PASS USER_NAME TIMEZONE
EOF

# Some things expect a `yarn` command, rather than `yarnpkg`
#
RUN <<EOF
mkdir --parents /usr/local/bin
ln --symbolic --force /usr/bin/yarnpkg /usr/local/bin/yarn
EOF

# Create systemctl hack script
#
RUN <<EOF
cat > /usr/bin/systemctl.sh <<SCRIPT
#!/usr/bin/env bash
service \$2 \$1
SCRIPT

chmod 755 /usr/bin/systemctl.sh

cp /usr/bin/systemctl    /usr/bin/systemctl.bin
cp /usr/bin/systemctl.sh /usr/bin/systemctl
EOF

# Hush various logins
#
RUN <<EOF
touch /root/.hushlogin
touch /var/lib/postgresql/.hushlogin
EOF

# Create (and run) system update cleanup script
#
RUN --mount=type=secret,id=config <<EOF
eval "$(cat /run/secrets/config)"

cat > /usr/local/sbin/system-update-cleanup.sh << SCRIPT
#!/usr/bin/env bash

# Make sure that problematic services are disabled (power management,
# screen saver, etc.)
#
sed -i 's/"cpugraph"/"cpugraph-disabled"/'                         /etc/xdg/xfce4/panel/default.xml
sed -i 's/"power-manager-plugin"/"power-manager-plugin-disabled"/' /etc/xdg/xfce4/panel/default.xml
sed -i 's/"pulseaudio"/"pulseaudio-disabled"/'                     /etc/xdg/xfce4/panel/default.xml
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

# Xrdp with fuse doesn't work under Podman (and requires an
# uncomfortable number of permissions in Docker); since we already
# share a directory with the host and it's not necessary for normal
# cut-and-paste, we just disable it here
#
sed -i 's/^FuseMountName=thinclient_drives\$/FuseMountName=.thinclient-drives/' /etc/xrdp/sesman.ini
sed -i 's/^#EnableFuseMount=false\$/EnableFuseMount=false/'                     /etc/xrdp/sesman.ini
SCRIPT
if [ "$IS_MACOS" = "yes" ]; then
	cat >> /usr/local/sbin/system-update-cleanup.sh <<- SCRIPT

	# Fix scroll on macOS
	#
	if [[ \$(grep -Ec '^XRDP_XORG_TOUCHPAD_SCROLL_HACK=yes$' /etc/xrdp/sesman.ini) -eq 0 ]]; then
	    sed -i 's/^\\[SessionVariables\\]\$/\\[SessionVariables\\]\\nXRDP_XORG_TOUCHPAD_SCROLL_HACK=yes/' /etc/xrdp/sesman.ini
	fi
	SCRIPT
fi

chmod 755 /usr/local/sbin/system-update-cleanup.sh

/usr/local/sbin/system-update-cleanup.sh

unset IS_MACOS USER_PASS USER_NAME TIMEZONE
EOF

# Create update script (useful for long-running containiners)
#
RUN --mount=type=secret,id=config <<EOF
eval "$(cat /run/secrets/config)"

cat > /usr/local/bin/update.sh << SCRIPT
#!/usr/bin/env bash

sudo cp /usr/bin/systemctl.bin /usr/bin/systemctl

sudo apt update
sudo apt full-upgrade
sudo apt autoremove --purge --autoremove
sudo apt clean

sudo cp /usr/bin/systemctl    /usr/bin/systemctl.bin
sudo cp /usr/bin/systemctl.sh /usr/bin/systemctl

sudo /usr/local/sbin/system-update-cleanup.sh

cp --archive --force --no-target-directory /etc/skel \$HOME

ln --symbolic --force \$HOME/.face \$HOME/.face.icon

head --lines -1 /etc/skel/.java/.userPrefs/burp/prefs.xml > \$HOME/.java/.userPrefs/burp/prefs.xml
cat >> \$HOME/.java/.userPrefs/burp/prefs.xml << CONF
  <entry key="free.suite.alertsdisabledforjre-1849443513" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-2220309211" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-277690372" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-3003353162" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-3187814639" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-4147451139" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-4166355790" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-439594872" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-492727137" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-576990537" value="true"/>
  <entry key="free.suite.feedbackReportingEnabled" value="false"/>
  <entry key="eulacommunity" value="4"/>
</map>
CONF
SCRIPT

chmod 755 /usr/local/bin/update.sh

unset IS_MACOS USER_PASS USER_NAME TIMEZONE
EOF

# We need a custom script to make sure that XFCE's background is set
# consistently to a solid color (and *stays* set between sessions)
#
RUN <<EOF
cat > /usr/local/bin/set-background-to-solid-color.sh << SCRIPT
#!/usr/bin/env bash

XRDP_BG_COLOR="\$(grep -E '^blue=' /etc/xrdp/xrdp.ini | sed 's/.\\+=//' | tr '[:lower:]' '[:upper:]')"

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
SCRIPT

chmod 755 /usr/local/bin/set-background-to-solid-color.sh
EOF

# Create container startup script
#
RUN --mount=type=secret,id=config <<EOF
eval "$(cat /run/secrets/config)"

cat > /usr/local/sbin/init.sh << SCRIPT
#!/usr/bin/env bash

if [[ -f /etc/localtime.host ]]; then
	ln --symbolic --force "/usr/share/zoneinfo/$(cat /etc/localtime.host)" /etc/localtime
fi

/etc/init.d/dbus start
/etc/init.d/postgresql start

rm --recursive --force /var/run/xrdp &> /dev/null
/etc/init.d/xrdp start

chown --recursive $USER_NAME:$USER_NAME /home/$USER_NAME

/usr/bin/bash
SCRIPT

chmod 755 /usr/local/sbin/init.sh

unset IS_MACOS USER_PASS USER_NAME TIMEZONE
EOF

# Generate local self-signed certificate (for PostgreSQL)
#
RUN <<EOF
export DEBIAN_FRONTEND=noninteractive

make-ssl-cert generate-default-snakeoil

unset DEBIAN_FRONTEND
EOF

# Init Metasploit database
#
RUN <<EOF
msfdb init
/etc/init.d/postgresql stop
EOF

# Create our normal user
#
RUN --mount=type=secret,id=config <<EOF
eval "$(cat /run/secrets/config)"

useradd --create-home \
        --shell /usr/bin/bash \
        --groups adm,audio,cdrom,dialout,dip,floppy,netdev,plugdev,sudo,staff,users,video \
          $USER_NAME

echo "${USER_NAME}:${USER_PASS}" | chpasswd

echo "$USER_NAME ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER_NAME

unset IS_MACOS USER_PASS USER_NAME TIMEZONE
EOF

# Home directory setup
#
RUN --mount=type=secret,id=config <<EOF
eval "$(cat /run/secrets/config)"

export USER_HOME="/home/$USER_NAME"

cp --archive --force --no-target-directory /etc/skel $USER_HOME

cat > $USER_HOME/.bash_aliases << CONF
#!/usr/bin/env bash

export LANG=en_US.UTF-8

function bash_prompt_precmd {
	if [[ "\$NEWLINE_BEFORE_PROMPT" == "yes" ]]; then
		if [[ -z "\$_NEW_LINE_BEFORE_PROMPT" ]]; then
			_NEW_LINE_BEFORE_PROMPT=1
		else
			echo ""
		fi
	fi
	date "+%Y-%m-%d @ %H:%M:%S %Z"
}
PROMPT_COMMAND=bash_prompt_precmd
CONF

mkdir --parents $USER_HOME/.BurpSuite
cat > $USER_HOME/.BurpSuite/UserConfigCommunity.json << CONF
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
CONF

mkdir --parents $USER_HOME/.config/autostart

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
Name=Disable session save-on-exit
Exec=xfconf-query --channel xfce4-session --property /general/SaveOnExit --create --type bool --set false
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > $USER_HOME/.config/autostart/nm-applet.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable NetworkManager applet
Exec=/usr/bin/true
StartupNotify=false
Terminal=false
Hidden=true
AUTOSTART

cat > $USER_HOME/.config/autostart/set-background-to-solid-color.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Set background to solid color
Exec=/usr/local/bin/set-background-to-solid-color.sh
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

cat > $USER_HOME/.config/autostart/set-flameshot-selection-shortcut.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Set Flameshot selected area screenshot shortcut
Exec=xfconf-query --channel xfce4-keyboard-shortcuts --property "/commands/custom/<Primary><Alt>p" --create --type string --set "flameshot gui --clipboard --path $USER_HOME/Desktop"
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > $USER_HOME/.config/autostart/set-mousepad-color-scheme.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Set Mousepad color scheme
Exec=gsettings set org.xfce.mousepad.preferences.view color-scheme Kali-Light
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > $USER_HOME/.config/autostart/set-session-name.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Set session name
Exec=xfconf-query --channel xfce4-session --property /general/SessionName --create --type string --set Default
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > $USER_HOME/.config/autostart/xfce4-power-manager.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable Xfce power management applet
Exec=/usr/bin/true
StartupNotify=false
Terminal=false
Hidden=true
AUTOSTART

cat > $USER_HOME/.config/autostart/xscreensaver.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable screen saver
Exec=/usr/bin/true
StartupNotify=false
Terminal=false
Hidden=true
AUTOSTART

mkdir --parents "$USER_HOME/.config/Code - OSS/User"
cat > "$USER_HOME/.config/Code - OSS/User/settings.json" << JSON
{
    "window.titleBarStyle": "custom",
    "workbench.colorTheme": "Default Light Modern"
}
JSON

touch $USER_HOME/.hushlogin

cat > $USER_HOME/.inputrc << CONF
"\\e[A": history-search-backward
"\\eOA": history-search-backward

"\\e[B": history-search-forward
"\\eOB": history-search-forward
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

echo "set tabsize 4" > $USER_HOME/.nanorc

mkdir -p $USER_HOME/.ssh
cat > $USER_HOME/.ssh/config << CONF
Host *
    ForwardAgent no
CONF
chmod 700 $USER_HOME/.ssh
chmod 600 $USER_HOME/.ssh/*

cat > $USER_HOME/.xsessionrc << CONF
#!/usr/bin/env bash

export LANG=en_US.UTF-8
CONF

mkdir --parents $USER_HOME/Documents

chown --recursive $USER_NAME:$USER_NAME $USER_HOME

unset IS_MACOS USER_PASS USER_NAME TIMEZONE USER_HOME
EOF

# Container exec/start
#
EXPOSE 3389
ENTRYPOINT ["/usr/bin/bash"]
CMD ["/usr/local/sbin/init.sh"]
