# Displosable Kali Linux
Disposable [Kali Linux](https://kali.org) environments using [Podman](https://podman.io/) (macOS & Linux) or [PRoot Distro](https://github.com/termux/proot-distro) (Android).

This setup is probably sufficiently opinionated that it won't be useful out-of-the box for `$RANDOM_HACKER`. However, it is provided here as a resource for others to study, fork, and draw inspiration from. (Also, I'm not adverse to integrating other folks' suggestions! I'm just not going to make any changes that either make my own use cases more complicated or this repo more difficult to maintain in general. Within those bounds though, issues and pull requests are welcome!)

## Prerequisits
### macOS
- [dockutil](https://github.com/kcrawford/dockutil)
- [Podman](https://podman.io/)
- [Microsoft Remote Desktop](https://apps.apple.com/us/app/microsoft-remote-desktop/id1295203466) (or another RDP client)

The use of [Homebrew](https://brew.sh) to install these tools is *highly* recommended. You can probably make things work without it, but you'll need to make sure your PATH is correct at the *GUI* level!

```bash
# Make sure that command-line developer tools are available
#
xcode-select --install

# Install Homebrew (`brew` path will be /usr/local/bin on x86_64 systems)
#
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >> $HOME/.zshrc
eval "$(/opt/homebrew/bin/brew shellenv)"
brew analytics off

# Install actual prerequisits
#
brew install dockutil microsoft-remote-desktop podman
```

**Note:** Podman is weird about how the default virtual machine gets set. If you use multiple virtual machines (*i.e.*, `podman machine list` has more entries than just `podman-machine-default`), you'll probably periodically get errors where the `$CONTROL_SCRIPT` can't find your container. If you see this, try resetting the default VM using ``podman system connection default podman-machine-default`.

Finally, make sure that `$HOME/.local/bin` exists and is in your `$PATH`.

### Linux
- [bc](https://www.gnu.org/software/bc/)
- [Podman](https://podman.io/)
- `uuidgen`
- [XFreeRDP or wlFreeRDP](https://www.freerdp.com/)
- [Zenity](https://gitlab.gnome.org/GNOME/zenity)

On [Debian](https://debian.org/):

```bash
# Install additional required tools. Alternately, replace
# `freerdp2-x11` with `freerdp2-wayland`.
#
apt install freerdp2-x11 uuid-runtime zenity
```

Finally, make sure that `$HOME/.local/bin` exists and is in your `$PATH`.

### Android
- [Termux](https://f-droid.org/en/packages/com.termux/)
- [Termux:X11](https://github.com/termux/termux-x11)
- [Termux:Widget](https://github.com/termux/termux-widget) (optional)

A couple of Termux packages are also required:

```bash
# Set up the X11 tools repo (required to install `termux-x11-nightly`).
#
pkg install x11-repo

# Install required packages.
#
pkg install proot-distro pulseaudio termux-am termux-x11-nightly virglrenderer-android which

# If using Termux:Widget, tudo will also need to be installed
#
curl --location https://github.com/agnostic-apollo/tudo/releases/latest/download/tudo --output $PREFIX/bin/tudo
chmod 755 $PREFIX/bin/tudo

# Enable access to device storage.
#
termux-setup-storage
```

You will almost certainly want to enable Developer Mode and then set the following option to prevent desktop sessions from being unexpectedly killed:

- Developer options → Apps → Disable child process restrictions → On

Finally, make sure that `$HOME/bin` exists and is in your Termux `$PATH`.

## Usage
To create a new engagement (container, control script, and data directory), just clone this repo and then run `mkenv.sh some-engagement-name` from inside of it.

At the end of the process, the control script name will be provided and the script's `help` command will automatically run. Script commands are detailed below. A desktop launcher will also be created allowing for quick access; be aware that on macOS and Linux, the container will *not* terminate when finished, and must be manually stopped using `$CONTROL_SCRIPT stop`!

### Linux and macOS
- `$CONTROL_SCRIPT start`: Start the engagement's container.
- `$CONTROL_SCRIPT stop`: Stop the engagement's container.
- `$CONTROL_SCRIPT shell`: Connect to a shell in the engagement's container. Automatically calls `$CONTROL_SCRIPT start` if necessary.
- `$CONTROL_SCRIPT desktop`: Connect to a desktop in the engagement's container. Automatically calls `$CONTROL_SCRIPT start` if necessary.
- `$CONTROL_SCRIPT backup`: Backup the engagement container in the data directory. Useful for taking snapshots of the container before making a potentially destructive change during an engagement or porting a configured engagement to a different machine.
- `$CONTROL_SCRIPT restore`: Removes the current engagement container and image and regenerates it from the backup linked at `$ENGAGEMENT_DIR/Backups/${NAME}.tar`. By default this will be the most recent backup, but the symlink can be changed manually to point to any other backup.
- `$CONTROL_SCRIPT archive`: Backup the engagement container, delete it and the associated image, and archive the control script in the data directory. This is generally what you'll want to do at the end of the engagement.
- `$CONTROL_SCRIPT delete`: Permenantly delete all engagement data.

**Note:** On macOS, the first time you start an environment's desktop, you will be asked to grant either the Terminal app (if calling `$CONTROL_SCRIPT` directly) or `env` "Accessibility Access". You will need to do this in the System Settings app and then re-connect. On the next run, you will be asked to grant access to the "System Events" app. You should not be asked for these permissions again, or for subsequent engagements.

### Android
- `$CONTROL_SCRIPT shell`: Connect to a shell in the engagement environment.
- `$CONTROL_SCRIPT desktop`: Start a desktop in the engagement environment. Use the Termux:X11 app to connect.
- `$CONTROL_SCRIPT backup`: Backup the engagement environment in the data directory. Useful for taking snapshots of the container before making a potentially destructive change during an engagement or porting a configured engagement to a different machine.
- `$CONTROL_SCRIPT restore`: Replaces the current engagement environment from the most recent backup in `$ENGAGEMENT_DIR/Backups/`.
- `$CONTROL_SCRIPT archive`: Backup the engagement environment, delete it, and archive the control script in the data directory. This is generally what you'll want to do at the end of the engagement.
- `$CONTROL_SCRIPT delete`: Permenantly delete all engagement data.
