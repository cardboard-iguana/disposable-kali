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
    netcat-openbsd \
    openssh-client \
    openvpn \
    python3-venv \
    sqlite3 \
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
cat > /usr/local/sbin/system-update-cleanup << SCRIPT
#!/usr/bin/env bash

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
	cat >> /usr/local/sbin/system-update-cleanup <<- SCRIPT

	# Fix scroll on macOS
	#
	if [[ \$(grep -Ec '^XRDP_XORG_TOUCHPAD_SCROLL_HACK=yes$' /etc/xrdp/sesman.ini) -eq 0 ]]; then
	    sed -i 's/^\\[SessionVariables\\]\$/\\[SessionVariables\\]\\nXRDP_XORG_TOUCHPAD_SCROLL_HACK=yes/' /etc/xrdp/sesman.ini
	fi
	SCRIPT
fi

chmod 755 /usr/local/sbin/system-update-cleanup

/usr/local/sbin/system-update-cleanup
EOF

# Create update script (useful for long-running containiners)
#
RUN <<EOF
cat > /usr/local/bin/update << SCRIPT
#!/usr/bin/env bash

sudo cp /usr/bin/systemctl.bin /usr/bin/systemctl

sudo apt update
sudo apt full-upgrade
sudo apt autoremove --purge --autoremove
sudo apt clean

sudo cp /usr/bin/systemctl    /usr/bin/systemctl.bin
sudo cp /usr/bin/systemctl.sh /usr/bin/systemctl

sudo /usr/local/sbin/system-update-cleanup

mise upgrade
SCRIPT

chmod 755 /usr/local/bin/update
EOF

# Enforce user-level customizations
#
RUN <<EOF
cat > /usr/local/bin/user-settings << SCRIPT
#!/usr/bin/env bash

# Make sure that XFCE's background is set consistently to match XRDP
#
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

# Set theme
#
gsettings set org.xfce.mousepad.preferences.view color-scheme Kali-Light
gsettings set org.gnome.desktop.interface        gtk-theme    Windows-10
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
xfconf-query --channel xsettings     --property /Net/ThemeName                         --create --type string --set Windows-10

# Disable session saving
#
xfconf-query --channel xfce4-session --property /general/AutoSave    --create --type bool --set false
xfconf-query --channel xfce4-session --property /general/SaveOnExit  --create --type bool --set false
xfconf-query --channel xfce4-session --property /general/SessionName --create --type string --set Default

# Disable screensaver
#
xfconf-query --channel xfce4-screensaver --property /lock/enabled  --create --type bool --set false
xfconf-query --channel xfce4-screensaver --property /saver/enabled --create --type bool --set false
SCRIPT

chmod 755 /usr/local/bin/user-settings
EOF

# Create container startup script
#
RUN <<EOF
cat > /usr/local/sbin/init << SCRIPT
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

chmod 755 /usr/local/sbin/init
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

cat > /home/"$USER_NAME"/.config/autostart/nm-applet.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Disable NetworkManager applet
Exec=/usr/bin/true
StartupNotify=false
Terminal=false
Hidden=true
AUTOSTART

cat > /home/"$USER_NAME"/.config/autostart/user-settings.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Configure user settings
Exec=/usr/local/bin/user-settings
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

mkdir --parents /home/"$USER_NAME"/.config/"Code - OSS"/User
cat > /home/"$USER_NAME"/.config/"Code - OSS"/User/settings.json << JSON
{
    "window.titleBarStyle": "custom",
    "workbench.colorTheme": "Default Light Modern"
}
JSON

mkdir --parents /home/"$USER_NAME"/.config/gtk-3.0
cat > /home/"$USER_NAME"/.config/gtk-3.0/settings.ini << INI
[Settings]
gtk-icon-theme-name = Windows-10-Icons
gtk-theme-name = Windows-10
INI

mkdir --parents /home/"$USER_NAME"/.config/qt5ct
sed 's#^icon_theme=.\+#icon_theme=Windows-10-Icons#;s#^color_scheme_path=.\+#color_scheme_path=/usr/share/qt5ct/colors/Windows.conf#' /etc/xdg/qt5ct/qt5ct.conf > /home/"$USER_NAME"/.config/qt5ct/qt5ct.conf

mkdir --parents /home/"$USER_NAME"/.config/qt6ct
sed 's#^icon_theme=.\+#icon_theme=Windows-10-Icons#;s#^color_scheme_path=.\+#color_scheme_path=/usr/share/qt5ct/colors/Windows.conf#' /etc/xdg/qt6ct/qt6ct.conf > /home/"$USER_NAME"/.config/qt6ct/qt6ct.conf

mkdir --parents /home/"$USER_NAME"/.config/qterminal.org
sed -i 's/^colorScheme=Kali-Dark/colorScheme=Kali-Light/;s/^ApplicationTransparency=.\+/ApplicationTransparency=0/' /etc/xdg/qterminal.org/qterminal.ini > /home/"$USER_NAME"/.config/qterminal.org/qterminal.ini

ln --symbolic --force /home/"$USER_NAME"/.face /home/"$USER_NAME"/.face.icon

cat > /home/"$USER_NAME"/.gtkrc-2.0 << INI
gtk-icon-theme-name = "Windows-10-Icons"
gtk-theme-name = "Windows-10"
INI

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
CMD ["/usr/local/sbin/init"]
