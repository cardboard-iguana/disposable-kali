FROM kalilinux/kali-rolling

# Install applications
#
RUN <<EOF
export DEBIAN_FRONTEND=noninteractive

echo 'APT::Install-Recommends "false";' >  /etc/apt/apt.conf.d/minimal-installs
echo 'APT::Install-Suggests "false";'   >> /etc/apt/apt.conf.d/minimal-installs

apt update       --quiet --assume-yes --fix-missing
apt full-upgrade --quiet --assume-yes --fix-broken

apt install --quiet --assume-yes \
    burpsuite \
    dialog \
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
    kali-desktop-i3 \
    metasploit-framework \
    nano \
    openssh-client \
    openvpn \
    tmux \
    xorg \
    xorgxrdp \
    xrdp

apt autoremove --quiet --assume-yes --purge --autoremove
apt clean      --quiet --assume-yes

unset DEBIAN_FRONTEND
EOF

# System configuration
#
RUN <<EOF
sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
EOF

RUN --mount=type=secret,id=TIMEZONE \
      ln --symbolic --force /usr/share/zoneinfo/$(cat /run/secrets/TIMEZONE) /etc/localtime

RUN <<EOF
mv /usr/bin/systemctl /usr/bin/systemctl.bin

cat > /usr/bin/systemctl.sh <<SCRIPT
#!/usr/bin/env bash
service \$2 \$1
SCRIPT

chmod 755 /usr/bin/systemctl.sh

cp /usr/bin/systemctl.sh /usr/bin/systemctl
EOF

RUN <<EOF
export DEBIAN_FRONTEND=noninteractive

make-ssl-cert generate-default-snakeoil

touch /root/.hushlogin
touch /var/lib/postgresql/.hushlogin

msfdb init
/etc/init.d/postgresql stop

unset DEBIAN_FRONTEND
EOF

# Make sure that problematic services are disabled (power management,
# screen saver, etc.)
#
RUN <<EOF
rm --force /etc/xdg/autostart/xfce4-power-manager.desktop &> /dev/null

sed -i 's/"cpugraph"/"cpugraph-disabled"/'                         /etc/xdg/xfce4/panel/default.xml
sed -i 's/"power-manager-plugin"/"power-manager-plugin-disabled"/' /etc/xdg/xfce4/panel/default.xml
sed -i 's/"pulseaudio"/"pulseaudio-disabled"/'                     /etc/xdg/xfce4/panel/default.xml
sed -i 's/"+lock-screen"/"-lock-screen"/'                          /etc/xdg/xfce4/panel/default.xml
EOF

# i3 Configuration tweaks
#
RUN <<EOF
sed -i 's|^exec --no-startup-id /usr/bin/xrandr|#exec --no-startup-id /usr/bin/xrandr|'                               /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/execs.conf
sed -i 's|^exec --no-startup-id /usr/bin/nm-applet|#exec --no-startup-id /usr/bin/nm-applet|'                         /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/execs.conf
sed -i 's|^exec --no-startup-id /usr/bin/pulseaudio|#exec --no-startup-id /usr/bin/pulseaudio|'                       /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/execs.conf
sed -i 's|^exec --no-startup-id /usr/bin/xfce4-power-manager|exec --no-startup-id /usr/bin/xfce4-power-manager|'      /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/execs.conf
sed -i 's|^exec --no-startup-id /usr/bin/nitrogen --restore|exec_always --no-startup-id /usr/bin/nitrogen --restore|' /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/execs.conf
sed -i 's|^exec_always --no-startup-id /usr/bin/picom --no-use-damage|exec_always --no-startup-id /usr/bin/picom|'    /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/execs.conf

sed -i 's/Mod4/Mod1/' /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/keybinds.conf
cat >> /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/keybinds.conf << CONF

## Chromebook fixes:
bindsym \$mod+Next focus down
bindsym \$mod+Prior focus up
bindsym \$mod+Shift+Next move down
bindsym \$mod+Shift+Prior move up
CONF

sed -i 's/^background_opacity 1.0/background_opacity 0.9/'      /usr/share/i3-dotfiles/etc/skel/.config/kitty/config.d/appearance.conf

sed -i 's/^active-opacity = 0.9;/active-opacity = 1.0;/'        /usr/share/i3-dotfiles/etc/skel/.config/picom/picom.conf
sed -i 's/^backend = "glx";/backend = "xrender";/'              /usr/share/i3-dotfiles/etc/skel/.config/picom/picom.conf
sed -i 's/^blur-method = "dual_kawase";/blur-method = "none";/' /usr/share/i3-dotfiles/etc/skel/.config/picom/picom.conf

sed -i 's/^modules-right       = .*/modules-right       = powermenu/' /usr/share/i3-dotfiles/etc/skel/.config/polybar/config.ini

sed -i "s%^reboot='\(.\+\) Reboot'%reboot='\1 Restart i3'%"                 /usr/share/i3-dotfiles/etc/skel/.config/rofi/scripts/powermenu
sed -i 's%echo -e ".\+" | rofi_cmd%echo -e "$logout\\n$reboot" | rofi_cmd%' /usr/share/i3-dotfiles/etc/skel/.config/rofi/scripts/powermenu
sed -i "s%/usr/bin/systemctl reboot%/usr/bin/i3-msg restart%"               /usr/share/i3-dotfiles/etc/skel/.config/rofi/scripts/powermenu
EOF

# Fix scroll on macOS
#
RUN --mount=type=secret,id=IS_MACOS <<EOF
export IS_MACOS="$(cat /run/secrets/IS_MACOS)"

if [ "$IS_MACOS" = "yes" ]; then
    sed -i 's/^\[SessionVariables\]$/\[SessionVariables\]\nXRDP_XORG_TOUCHPAD_SCROLL_HACK=yes/' /etc/xrdp/sesman.ini
fi

unset IS_MACOS
EOF

# Create update script (useful for long-running containiners)
#
RUN --mount=type=secret,id=IS_MACOS <<EOF
export IS_MACOS="$(cat /run/secrets/IS_MACOS)"

cat > /usr/local/bin/update.sh << SCRIPT
#!/usr/bin/env bash

sudo cp /usr/bin/systemctl.bin /usr/bin/systemctl

sudo apt update
sudo apt full-upgrade
sudo apt autoremove --purge --autoremove
sudo apt clean

sudo cp /usr/bin/systemctl.sh /usr/bin/systemctl

sudo rm --force /etc/xdg/autostart/xfce4-power-manager.desktop &> /dev/null

sudo sed -i 's/"cpugraph"/"cpugraph-disabled"/'                         /etc/xdg/xfce4/panel/default.xml
sudo sed -i 's/"power-manager-plugin"/"power-manager-plugin-disabled"/' /etc/xdg/xfce4/panel/default.xml
sudo sed -i 's/"pulseaudio"/"pulseaudio-disabled"/'                     /etc/xdg/xfce4/panel/default.xml
sudo sed -i 's/"+lock-screen"/"-lock-screen"/'                          /etc/xdg/xfce4/panel/default.xml

sudo sed -i 's|^exec --no-startup-id /usr/bin/xrandr|#exec --no-startup-id /usr/bin/xrandr|'                               /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/execs.conf
sudo sed -i 's|^exec --no-startup-id /usr/bin/nm-applet|#exec --no-startup-id /usr/bin/nm-applet|'                         /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/execs.conf
sudo sed -i 's|^exec --no-startup-id /usr/bin/pulseaudio|#exec --no-startup-id /usr/bin/pulseaudio|'                       /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/execs.conf
sudo sed -i 's|^exec --no-startup-id /usr/bin/xfce4-power-manager|exec --no-startup-id /usr/bin/xfce4-power-manager|'      /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/execs.conf
sudo sed -i 's|^exec --no-startup-id /usr/bin/nitrogen --restore|exec_always --no-startup-id /usr/bin/nitrogen --restore|' /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/execs.conf
sudo sed -i 's|^exec_always --no-startup-id /usr/bin/picom --no-use-damage|exec_always --no-startup-id /usr/bin/picom|'    /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/execs.conf

sudo sed -i 's/Mod4/Mod1/' /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/keybinds.conf
if [[ \$(grep -c "## Chromebook fixes:" /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/keybinds.conf) -eq 0 ]]; then
    sudo echo ""                                   >> /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/keybinds.conf
    sudo echo "## Chromebook fixes:"               >> /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/keybinds.conf
    sudo echo "bindsym \$mod+Next focus down"      >> /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/keybinds.conf
    sudo echo "bindsym \$mod+Prior focus up"       >> /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/keybinds.conf
    sudo echo "bindsym \$mod+Shift+Next move down" >> /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/keybinds.conf
    sudo echo "bindsym \$mod+Shift+Prior move up"  >> /usr/share/i3-dotfiles/etc/skel/.config/i3/config.d/keybinds.conf
fi

sudo sed -i 's/^background_opacity 1.0/background_opacity 0.9/'      /usr/share/i3-dotfiles/etc/skel/.config/kitty/config.d/appearance.conf

sudo sed -i 's/^active-opacity = 0.9;/active-opacity = 1.0;/'        /usr/share/i3-dotfiles/etc/skel/.config/picom/picom.conf
sudo sed -i 's/^backend = "glx";/backend = "xrender";/'              /usr/share/i3-dotfiles/etc/skel/.config/picom/picom.conf
sudo sed -i 's/^blur-method = "dual_kawase";/blur-method = "none";/' /usr/share/i3-dotfiles/etc/skel/.config/picom/picom.conf

sudo sed -i 's/^modules-right       = .*/modules-right       = powermenu/' /usr/share/i3-dotfiles/etc/skel/.config/polybar/config.ini

sudo sed -i "s%^reboot='\(.\+\) Reboot'%reboot='\1 Restart i3'%"                   /usr/share/i3-dotfiles/etc/skel/.config/rofi/scripts/powermenu
sudo sed -i 's%echo -e ".\+" | rofi_cmd%echo -e "\$logout\\n\$reboot" | rofi_cmd%' /usr/share/i3-dotfiles/etc/skel/.config/rofi/scripts/powermenu
sudo sed -i "s%/usr/bin/systemctl reboot%/usr/bin/i3-msg restart%"                 /usr/share/i3-dotfiles/etc/skel/.config/rofi/scripts/powermenu

SCRIPT

if [ "$IS_MACOS" = "yes" ]; then
cat >> /usr/local/bin/update.sh << SCRIPT
if [[ \$(grep -Ec '^XRDP_XORG_TOUCHPAD_SCROLL_HACK=yes$' /etc/xrdp/sesman.ini) -eq 0 ]]; then
    sudo sed -i 's/^\[SessionVariables\]$/\[SessionVariables\]\nXRDP_XORG_TOUCHPAD_SCROLL_HACK=yes/' /etc/xrdp/sesman.ini
fi

SCRIPT
fi

cat >> /usr/local/bin/update.sh << SCRIPT
cp --archive --force --no-target-directory /etc/skel                       \$HOME
cp --archive --force --no-target-directory /usr/share/i3-dotfiles/etc/skel \$HOME

ln --symbolic --force \$HOME/.face \$HOME/.face.icon

head --lines -1 /etc/skel/.java/.userPrefs/burp/prefs.xml > \$HOME/.java/.userPrefs/burp/prefs.xml
cat >> \$HOME/.java/.userPrefs/burp/prefs.xml << CONF
  <entry key="free.suite.alertsdisabledforjre-4166355790" value="true"/>
  <entry key="free.suite.alertsdisabledforjre-576990537" value="true"/>
  <entry key="free.suite.feedbackReportingEnabled" value="false"/>
  <entry key="eulacommunity" value="4"/>
</map>
CONF
SCRIPT

chmod 755 /usr/local/bin/update.sh

unset IS_MACOS
EOF

# Create Docker startup script
#
RUN --mount=type=secret,id=USER_NAME <<EOF
export USER_NAME="$(cat /run/secrets/USER_NAME)"

cat > /usr/local/sbin/docker-init.sh << SCRIPT
#!/usr/bin/env bash

/etc/init.d/dbus start
/etc/init.d/postgresql start

rm --recursive --force /var/run/xrdp &> /dev/null
/etc/init.d/xrdp start

chown --recursive $USER_NAME:$USER_NAME /home/$USER_NAME

/usr/bin/bash
SCRIPT

chmod 755 /usr/local/sbin/docker-init.sh
EOF

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

cp --archive --force --no-target-directory /etc/skel                       $USER_HOME
cp --archive --force --no-target-directory /usr/share/i3-dotfiles/etc/skel $USER_HOME

touch $USER_HOME/.hushlogin

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
    if [[ \$(tmux list-sessions 2> /dev/null | grep -vc "(attached)") -eq 0 ]]; then
        exec tmux -2 new-session
    else
        exec tmux -2 attach-session
    fi
fi
alias ntterm="kitty &> /dev/null & disown"
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
