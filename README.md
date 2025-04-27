# Displosable Kali Linux
Disposable [Kali Linux](https://kali.org) environments for Android using [PRoot Distro](https://github.com/termux/proot-distro).

This setup is probably sufficiently opinionated that it won't be useful out-of-the box for `$RANDOM_HACKER`. However, it is provided here as a resource for others to study, fork, and draw inspiration from. (Also, I'm not adverse to integrating other folks' suggestions! I'm just not going to make any changes that either make my own use cases more complicated or this repo more difficult to maintain in general. Within those bounds though, issues and pull requests are welcome!)

## Prerequisits
- [Termux](https://f-droid.org/en/packages/com.termux/)
- [Termux:X11](https://github.com/termux/termux-x11)

Note that there is no dedicated desktop environment on Android; instead, you should install and configure a desktop environment through Termux. For example:

```bash
# Install required packages for this script.
#
pkg install proot-distro which

# Set up the X11 tools repo (required to install `termux-x11-nightly`).
#
pkg install x11-repo

# Install a desktop environment.
#
pkg install pulseaudio termux-am termux-x11-nightly virglrenderer-android xfce4 xfce4-pulseaudio-plugin

mkdir $HOME/bin

cat > $HOME/bin/start-desktop << EOF
#!$(which bash)

export USERNAME=\$(whoami)
export USER=\$USERNAME

rm --recursive --force \$PREFIX/../home/.config/pulse
rm --recursive --force \$PREFIX/tmp/dbus-*
rm --recursive --force \$PREFIX/tmp/.ICE-unix
rm --recursive --force \$PREFIX/tmp/*-\${USERNAME}
rm --recursive --force \$PREFIX/tmp/*-\${USERNAME}.*
rm --recursive --force \$PREFIX/tmp/*_\${USERNAME}
rm --recursive --force \$PREFIX/tmp/proot-*
rm --recursive --force \$PREFIX/tmp/pulse-*
rm --recursive --force \$PREFIX/tmp/.virgl_test
rm --recursive --force \$PREFIX/tmp/.X0-lock
rm --recursive --force \$PREFIX/tmp/.X11-unix

dbus-daemon --session --address=unix:path=$PREFIX/var/run/dbus-session &

termux-x11 :0 &

export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.3COMPAT
export MESA_GLES_VERSION_OVERRIDE=3.2
export LIBGL_DRI_DISABLE=1
if [[ \$(getprop ro.hardware.egl | grep -c "mali") -gt 0 ]] || [[ \$(getprop ro.hardware.vulkan | grep -c "mali") -gt 0 ]]; then
	virgl_test_server_android --angle-gl &
else
	virgl_test_server_android &
fi
unset MESA_NO_ERROR MESA_GL_VERSION_OVERRIDE MESA_GLES_VERSION_OVERRIDE LIBGL_DRI_DISABLE

if [[ "\$(getprop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')" == "samsung" ]]; then
	export LD_PRELOAD=/system/lib64/libskcodec.so
fi
pulseaudio --start \\
           --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \\
           --exit-idle-time=-1
unset LD_PRELOAD

sleep 1

am start-activity -W com.termux.x11/com.termux.x11.MainActivity

export DISPLAY=:0
export GALLIUM_DRIVER=virpipe
export PULSE_SERVER=tcp:127.0.0.1
dbus-launch --exit-with-session xfce4-session
unset DISPLAY GALLIUM_DRIVER PULSE_SERVER

pkill --full pulseaudio
pkill --full virgl_test_server
pkill --full com.termux.x11

pkill -9 dbus

rm --recursive --force \$PREFIX/../home/.config/pulse
rm --recursive --force \$PREFIX/tmp/dbus-*
rm --recursive --force \$PREFIX/tmp/.ICE-unix
rm --recursive --force \$PREFIX/tmp/*-\${USERNAME}
rm --recursive --force \$PREFIX/tmp/*-\${USERNAME}.*
rm --recursive --force \$PREFIX/tmp/*_\${USERNAME}
rm --recursive --force \$PREFIX/tmp/proot-*
rm --recursive --force \$PREFIX/tmp/pulse-*
rm --recursive --force \$PREFIX/tmp/.virgl_test
rm --recursive --force \$PREFIX/tmp/.X0-lock
rm --recursive --force \$PREFIX/tmp/.X11-unix

unset USER USERNAME
EOF

chmod +x $HOME/bin/start-desktop
echo '$PATH:$HOME/bin' >> $HOME/.bashrc

# Enable access to device storage.
#
termux-setup-storage
```

You will almost certainly want to enable Developer Mode and then set **Developer options → Apps → Disable child process restrictions → On** to prevent desktop sessions from being unexpectedly killed.

## Usage
To create a new engagement (container, control script, and data directory), just clone this repo and then run `bash mkenv.sh some-engagement-name` from inside of it.

At the end of the process, the control script name will be provided and the script's "help" command will automatically run.

- `$CONTROL_SCRIPT --help`: Display help message.
- `$CONTROL_SCRIPT --update`: Update the engagement environment's packages. Useful during long-running engagements.
- `$CONTROL_SCRIPT --backup`: Backup the engagement environment in the data directory. Useful for taking snapshots of the container before making a potentially destructive change during an engagement or porting a configured engagement to a different machine.
- `$CONTROL_SCRIPT --restore`: Replaces the current engagement environment from the most recent backup in `$ENGAGEMENT_DIR/Backups/`.
- `$CONTROL_SCRIPT --archive`: Backup the engagement environment, delete it, and archive the control script in the data directory. This is generally what you'll want to do at the end of the engagement.

If the `$CONTROL_SCRIPT` is called without any options, then the remainder of the command line is treated as a command (perhaps with its own options) to run in the engagement environment (*i.e.*, `$CONTROL_SCRIPT ls -la`).

If `$CONTROL_SCRIPT` is called without any options *or* commands, then a tmux shell is opened in the engagement environment.
