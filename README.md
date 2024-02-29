# Displosable Kali Linux
Disposable [Kali Linux](https://kali.org) environments using [Docker](https://www.docker.com/) (macOS & Linux) or [PRoot Distro](https://github.com/termux/proot-distro) (Android).

This setup is probably sufficiently opinionated that it won't be useful out-of-the box for `$RANDOM_HACKER`. However, it is provided here as a resource for others to study, fork, and draw inspiration from. (Also, I'm not adverse to integrating other folks' suggestions! I'm just not going to make any changes that either make my own use cases more complicated or this repo more difficult to maintain in general. Within those bounds though, issues and pull requests are welcome!)

## Prerequisits
On all systems, `$HOME/.local/bin` is expected to bin in your `$PATH`.

### macOS
- [Rancher Desktop](https://rancherdesktop.io/)
- [Microsoft Remote Desktop](https://apps.apple.com/us/app/microsoft-remote-desktop/id1295203466) (or another RDP client)

Using [Homebrew](https://brew.sh/):

```bash
# Install Rancher Desktop and Microsoft Remote Desktop.
#
brew install microsoft-remote-desktop rancher
```

Rancher Desktop must be run once before trying to deploy a disposable environment. Recommended prences tweaks:

- Application → Behavior → Startup → Automatically start at login → On
- Application → Behavior → Background → Start in the background → On
- Virtual Machine → Volumes → Mount Type → virtiofs
- Virtual Machine → Emulation → Virtual Machine Type → VZ

### Linux
- [Docker CE](https://docs.docker.com/engine/install/debian/)
- [XFreeRDP or wlFreeRDP](https://www.freerdp.com/)

On [Debian](https://debian.org/):

```bash
# Install the most recent version of Docker.
#
curl --silent --location https://download.docker.com/linux/debian/gpg | gpg --dearmor > /usr/share/keyrings/docker.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian $(grep -E '^VERSION_CODENAME=' /etc/os-release | sed 's/.*=//') stable" > /etc/apt/sources.list.d/docker.list

apt update
apt install containerd.io docker-buildx-plugin docker-ce docker-ce-cli docker-compose-plugin

usermod --append --groups docker $USER

# Install additional tools. Alternately, replace `freerdp2-x11` with
# `freerdp2-wayland`.
#
apt install freerdp2-x11
```

### Android
- [Termux](https://f-droid.org/en/packages/com.termux/)
- [Termux:X11](https://github.com/termux/termux-x11)

A couple of Termux packages are also required:

```bash
# Set up the X11 tools repo (required to install `termux-x11-nightly`).
#
pkg install x11-repo

# Install required packages.
#
pkg install proot-distro pulseaudio termux-x11-nightly virglrenderer-android which

# Enable access to device storage.
#
termux-setup-storage
```

You will almost certainly want to enable Developer Mode and then set the following option to prevent desktop sessions from being unexpectedly killed:

- Developer options → Apps → Disable child process restrictions → On

## Usage
To create a new engagement (Docker/PRoot image/container, control script, and data directory), just clone this repo and then run `mkenv.sh some-engagement-name` from inside of it.

At the end of the process, the control script name will be provided and the script's `help` command will automatically run. Script commands are detailed below.

### Linux and macOS
- `$CONTROL_SCRIPT start`: Start the engagement's container.
- `$CONTROL_SCRIPT stop`: Stop the engagement's container.
- `$CONTROL_SCRIPT shell`: Connect to a shell in the engagement's container. Automatically calls `$CONTROL_SCRIPT start` if necessary.
- `$CONTROL_SCRIPT desktop`: Connect to a desktop in the engagement's container. Automatically calls `$CONTROL_SCRIPT start` if necessary. (**Linux only!** For on macOS, use `$CONTROL_SCRIPT start` and then connect to `localhost:3389` using an RDP client).
- `$CONTROL_SCRIPT backup`: Backup the engagement container in the data directory. Useful for taking snapshots of the container before making a potentially destructive change during an engagement or porting a configured engagement to a different machine.
- `$CONTROL_SCRIPT restore`: Removes the current engagement container and image and regenerates it from the backup linked at `$ENGAGEMENT_DIR/Backups/${NAME}.tar`. By default this will be the most recent backup, but the symlink can be changed manually to point to any other backup.
- `$CONTROL_SCRIPT archive`: Backup the engagement container, delete it and the associated image, and archive the control script in the data directory. This is generally what you'll want to do at the end of the engagement.
- `$CONTROL_SCRIPT delete`: Permenantly delete all engagement data.

### Android
- `$CONTROL_SCRIPT shell`: Connect to a shell in the engagement environment.
- `$CONTROL_SCRIPT desktop`: Start a desktop in the engagement environment. Use the Termux:X11 app to connect.
- `$CONTROL_SCRIPT backup`: Backup the engagement environment in the data directory. Useful for taking snapshots of the container before making a potentially destructive change during an engagement or porting a configured engagement to a different machine.
- `$CONTROL_SCRIPT restore`: Replaces the current engagement environment from the most recent backup in `$ENGAGEMENT_DIR/Backups/`.
- `$CONTROL_SCRIPT archive`: Backup the engagement environment, delete it, and archive the control script in the data directory. This is generally what you'll want to do at the end of the engagement.
- `$CONTROL_SCRIPT delete`: Permenantly delete all engagement data.
