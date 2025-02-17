FROM registry.hub.docker.com/kalilinux/kali-rolling:latest

ARG DEBIAN_FRONTEND=noninteractive
ARG HOST_OS
ARG TIMEZONE
ARG USER_NAME

USER root

# Configure APT
#
RUN <<EOF
echo 'APT::Install-Recommends "false";' >  /etc/apt/apt.conf.d/minimal-installs
echo 'APT::Install-Suggests "false";'   >> /etc/apt/apt.conf.d/minimal-installs
EOF

# Install base system
#
RUN <<EOF
apt update       --quiet --assume-yes --fix-missing
apt full-upgrade --quiet --assume-yes --fix-broken

apt install --quiet --assume-yes \
    asciinema \
    bc \
    build-essential \
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
    less \
    libffi-dev \
    libyaml-dev \
    metasploit-framework \
    nano \
    openssh-client \
    openvpn \
    recordmydesktop \
    tmux \
    tumbler \
    uuid-runtime \
    xclip \
    xfce4-notifyd \
    xorg \
    xorgxrdp \
    xrdp \
    zlib1g-dev

apt autoremove --quiet --assume-yes --purge --autoremove
apt clean      --quiet --assume-yes
EOF

# Install mise
#
RUN <<EOF
mkdir --parents /etc/apt/keyrings
mkdir --parents /etc/apt/sources.list.d

curl --silent --location https://mise.jdx.dev/gpg-key.pub | gpg --dearmor > /etc/apt/keyrings/mise-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg] https://mise.jdx.dev/deb stable main" > /etc/apt/sources.list.d/mise.list

apt update  --quiet --assume-yes
apt install --quiet --assume-yes mise
EOF

# Make sure locale is built
#
RUN <<EOF
sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
EOF

# Set time zone
#
RUN ln --symbolic --force /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime

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
RUN <<EOF
cat > /usr/local/sbin/system-update-cleanup.sh << SCRIPT
#!/usr/bin/env bash

# Desktop customizations
#
sed -i 's#\\(^    <property name="panel-1" type="empty">$\\)#    <property name="dark-mode" type="bool" value="true"/>\\n\\1#' /etc/xdg/xfce4/panel/default.xml
sed -i 's/"p=6;x=0;y=0"/"p=8;x=0;y=0"/'                                                                                        /etc/xdg/xfce4/panel/default.xml
sed -i 's/name="size" type="uint" value="28"/name="size" type="uint" value="44"/'                                              /etc/xdg/xfce4/panel/default.xml
sed -i 's/name="icon-size" type="uint" value="22"/name="icon-size" type="uint" value="24"/'                                    /etc/xdg/xfce4/panel/default.xml
sed -i 's/name="show-labels" type="bool" value="false"/name="show-labels" type="bool" value="true"/'                           /etc/xdg/xfce4/panel/default.xml
sed -i 's/name="grouping" type="uint" value="1"/name="grouping" type="bool" value="false"/'                                    /etc/xdg/xfce4/panel/default.xml
sed -i 's/"Cantarell 11"/"Noto Mono 11"/'                                                                                      /etc/xdg/xfce4/panel/default.xml
sed -i 's/"%_H:%M"/"%Y-%m-%d @ %H:%M:%S %Z"/'                                                                                  /etc/xdg/xfce4/panel/default.xml
sed -i 's/"+lock-screen"/"-lock-screen"/'                                                                                      /etc/xdg/xfce4/panel/default.xml

sed -i 's/"Kali-Dark"/"Kali-Light"/' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml

sed -i 's/"Kali-Dark"/"Kali-Light"/'                                                                                                                       /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
sed -i 's/"Flat-Remix-Blue-Dark"/"Windows-10-Icons"/'                                                                                                      /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml

sed -i 's/^icon_theme=.\\+/icon_theme=Windows-10-Icons/'                                      /etc/xdg/qt5ct/qt5ct.conf
sed -i 's#^color_scheme_path=.\\+#color_scheme_path=/usr/share/qt5ct/colors/Kali-Light.conf#' /etc/xdg/qt5ct/qt5ct.conf

sed -i 's/^icon_theme=.\\+/icon_theme=Windows-10-Icons/'                                      /etc/xdg/qt6ct/qt6ct.conf
sed -i 's#^color_scheme_path=.\\+#color_scheme_path=/usr/share/qt5ct/colors/Kali-Light.conf#' /etc/xdg/qt6ct/qt6ct.conf

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
if [ "$HOST_OS" = "Darwin" ]; then
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
EOF

# Create update script (useful for long-running containiners)
#
RUN <<EOF
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
  <entry key="free.suite.alertsdisabledforjre-1743307703" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-4166355790" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-576990537" value="true"/>
  <entry key="free.suite.feedbackReportingEnabled" value="false"/>
  <entry key="eulacommunity" value="4"/>
</map>
CONF

mise upgrade
SCRIPT

chmod 755 /usr/local/bin/update.sh
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

xfconf-query --channel xfce4-desktop --property /backdrop/single-workspace-mode                      --create --type bool   --set true
xfconf-query --channel xfce4-desktop --property /backdrop/single-workspace-number                    --create --type int    --set 0
xfconf-query --channel xfce4-desktop --property /backdrop/screen0/monitorrdp0/workspace0/image-style --create --type int    --set 0
xfconf-query --channel xfce4-desktop --property /backdrop/screen0/monitorrdp0/workspace0/color-style --create --type int    --set 0
xfconf-query --channel xfce4-desktop --property /backdrop/screen0/monitorrdp0/workspace0/rgba1       --create --type double --set \$RED \\
                                                                                                              --type double --set \$GREEN \\
                                                                                                              --type double --set \$BLUE \\
                                                                                                              --type double --set 1
SCRIPT

chmod 755 /usr/local/bin/set-background-to-solid-color.sh
EOF

# Create container startup script
#
RUN <<EOF
cat > /usr/local/sbin/init.sh << SCRIPT
#!/usr/bin/env bash

if [[ -f /etc/localtime.host ]]; then
	ln --symbolic --force "/usr/share/zoneinfo/\$(cat /etc/localtime.host)" /etc/localtime
fi

/etc/init.d/dbus start
/etc/init.d/postgresql start

rm --recursive --force /var/run/xrdp &> /dev/null
/etc/init.d/xrdp start

chown --recursive "$USER_NAME":"$USER_NAME" /home/"$USER_NAME"

/usr/bin/bash
SCRIPT

chmod 755 /usr/local/sbin/init.sh
EOF

# Generate local self-signed certificate (for PostgreSQL)
#
RUN make-ssl-cert generate-default-snakeoil

# Init Metasploit database
#
RUN <<EOF
msfdb init
/etc/init.d/postgresql stop
EOF

# Create our normal user
#
RUN --mount=type=secret,id=connection-token <<EOF
useradd --create-home \
        --shell /usr/bin/bash \
        --groups adm,audio,cdrom,dialout,dip,floppy,netdev,plugdev,sudo,staff,users,video \
          "$USER_NAME"

echo "${USER_NAME}:$(cat /run/secrets/connection-token)" | chpasswd

echo "$USER_NAME ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/"$USER_NAME"
EOF

# Home directory setup
#
RUN <<EOF
cp --archive --force --no-target-directory /etc/skel /home/"$USER_NAME"

cat > /home/"$USER_NAME"/.bash_aliases << CONF
#!/usr/bin/env bash

export LANG=en_US.UTF-8

alias pbcopy="\$(which xclip) -in -selection clipboard"
alias pbpaste="\$(which xclip) -out -selection clipboard"

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

eval "\$(mise activate bash)"
CONF

mkdir --parents /home/"$USER_NAME"/.BurpSuite
cat > /home/"$USER_NAME"/.BurpSuite/UserConfigCommunity.json << CONF
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

mkdir --parents /home/"$USER_NAME"/.config/autostart

cat > /home/"$USER_NAME"/.config/autostart/disable-session-autosave.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable session autosave
Exec=/usr/bin/xfconf-query --channel xfce4-session --property /general/AutoSave --create --type bool --set false
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > /home/"$USER_NAME"/.config/autostart/disable-session-save-on-exit.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable session save-on-exit
Exec=/usr/bin/xfconf-query --channel xfce4-session --property /general/SaveOnExit --create --type bool --set false
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > /home/"$USER_NAME"/.config/autostart/nm-applet.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable NetworkManager applet
Exec=/usr/bin/true
StartupNotify=false
Terminal=false
Hidden=true
AUTOSTART

cat > /home/"$USER_NAME"/.config/autostart/set-background-to-solid-color.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Set background to solid color
Exec=/usr/local/bin/set-background-to-solid-color.sh
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > /home/"$USER_NAME"/.config/autostart/set-flameshot-desktop-shortcut.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Set Flameshot full desktop screenshot shortcut
Exec=/usr/bin/xfconf-query --channel xfce4-keyboard-shortcuts --property "/commands/custom/<Primary><Shift><Alt>p" --create --type string --set "flameshot full --clipboard --path \\"/home/$USER_NAME/Desktop\\""
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > /home/"$USER_NAME"/.config/autostart/set-flameshot-selection-shortcut.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Set Flameshot selected area screenshot shortcut
Exec=/usr/bin/xfconf-query --channel xfce4-keyboard-shortcuts --property "/commands/custom/<Primary><Alt>p" --create --type string --set "flameshot gui --clipboard --path \\"/home/$USER_NAME/Desktop\\""
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > /home/"$USER_NAME"/.config/autostart/set-mousepad-color-scheme.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Set Mousepad color scheme
Exec=/usr/bin/gsettings set org.xfce.mousepad.preferences.view color-scheme Kali-Light
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > /home/"$USER_NAME"/.config/autostart/set-session-name.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Set session name
Exec=/usr/bin/xfconf-query --channel xfce4-session --property /general/SessionName --create --type string --set Default
StartupNotify=false
Terminal=false
Hidden=false
AUTOSTART

cat > /home/"$USER_NAME"/.config/autostart/xfce4-power-manager.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable Xfce power management applet
Exec=/usr/bin/true
StartupNotify=false
Terminal=false
Hidden=true
AUTOSTART

cat > /home/"$USER_NAME"/.config/autostart/xscreensaver.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable X screen saver
Exec=/usr/bin/true
StartupNotify=false
Terminal=false
Hidden=true
AUTOSTART

cat > /home/"$USER_NAME"/.config/autostart/xfce-screensaver.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable Xfce screen saver
Exec=/usr/bin/xfconf-query --channel xfce4-screensaver --property /saver/enabled --create --type bool --set false
StartupNotify=false
Terminal=false
Hidden=true
AUTOSTART

cat > /home/"$USER_NAME"/.config/autostart/xfce-lockscreen.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable Xfce lock screen
Exec=/usr/bin/xfconf-query --channel xfce4-screensaver --property /lock/enabled --create --type bool --set false
StartupNotify=false
Terminal=false
Hidden=true
AUTOSTART

mkdir --parents /home/"$USER_NAME"/.config/"Code - OSS"/User
cat > /home/"$USER_NAME"/.config/"Code - OSS"/User/settings.json << JSON
{
    "window.titleBarStyle": "custom",
    "workbench.colorTheme": "Default Light Modern"
}
JSON

mkdir --parents /home/"$USER_NAME"/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /home/"$USER_NAME"/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-notifyd.xml << XML
<?xml version="1.1" encoding="UTF-8"?>

<channel name="xfce4-notifyd" version="1.0">
  <property name="theme" type="string" value="Retro"/>
  <property name="notify-location" type="string" value="bottom-right"/>
</channel>
XML

touch /home/"$USER_NAME"/.hushlogin

cat > /home/"$USER_NAME"/.inputrc << CONF
"\\e[A": history-search-backward
"\\eOA": history-search-backward

"\\e[B": history-search-forward
"\\eOB": history-search-forward
CONF

mkdir --parents /home/"$USER_NAME"/.java/.userPrefs/burp
head --lines -1 /etc/skel/.java/.userPrefs/burp/prefs.xml > /home/"$USER_NAME"/.java/.userPrefs/burp/prefs.xml
cat >> /home/"$USER_NAME"/.java/.userPrefs/burp/prefs.xml << CONF
  <entry key="free.suite.alertsdisabledforjre-1743307703" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-4166355790" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-576990537" value="true"/>
  <entry key="free.suite.feedbackReportingEnabled" value="false"/>
  <entry key="eulacommunity" value="4"/>
</map>
CONF

echo "set tabsize 4" > /home/"$USER_NAME"/.nanorc

mkdir --parents /home/"$USER_NAME"/.ssh
cat > /home/"$USER_NAME"/.ssh/config << CONF
Host *
    ForwardAgent no
CONF
chmod 700 /home/"$USER_NAME"/.ssh
chmod 600 /home/"$USER_NAME"/.ssh/*

cat > /home/"$USER_NAME"/.tmux.conf << CONF
set-option -g default-terminal tmux-256color
set-option -g allow-passthrough off
set-option -g history-limit 65536

set-option -g mouse on
set-option -s set-clipboard off

bind-key -T copy-mode    MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
CONF

cat > /home/"$USER_NAME"/.xsessionrc << CONF
#!/usr/bin/env bash

export LANG=en_US.UTF-8
CONF

mkdir --parents /home/"$USER_NAME"/Documents

chown --recursive "$USER_NAME":"$USER_NAME" /home/"$USER_NAME"
EOF

# Container exec/start
#
EXPOSE 3389
ENTRYPOINT ["/usr/bin/bash"]
CMD ["/usr/local/sbin/init.sh"]
