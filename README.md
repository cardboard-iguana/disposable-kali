# Displosable Kali Linux
Disposable [Kali Linux](https://kali.org) environments using [Docker](https://www.docker.com/) (macOS & Linux) or [PRoot Distro](https://github.com/termux/proot-distro) (Android).

This setup is probably sufficiently opinionated that it won't be useful out-of-the box for `$RANDOM_HACKER`. However, it is provided here as a resource for others to study, fork, and draw inspiration from. (Also, I'm not adverse to integrating other folks' suggestions! I'm just not going to make any changes that either make my own use cases more complicated or this repo more difficult to maintain in general. Within those bounds though, issues and pull requests are welcome!)

## Prerequisits
### macOS
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [jq](https://jqlang.github.io/jq/)
- [Microsoft Remote Desktop](https://apps.apple.com/us/app/microsoft-remote-desktop/id1295203466) (or another RDP client)
- [XZ Utils](https://tukaani.org/xz/)

Using [Homebrew](https://brew.sh/):

```bash
# Install Docker from a cask rather than formula in order to get the
# most recent version.
#
brew install \
     homebrew/cask/docker \
     jq \
     microsoft-remote-desktop \
     xz
```

### Linux
- [Docker CE](https://docs.docker.com/engine/install/debian/)
- [jq](https://jqlang.github.io/jq/)
- [XFreeRDP or wlFreeRDP](https://www.freerdp.com/)
- [XZ Utils](https://tukaani.org/xz/)

On [Debian](https://debian.org/):

```bash
# Install the most recent version of Docker.
#
curl --silent --location https://download.docker.com/linux/debian/gpg | gpg --dearmor > /usr/share/keyrings/docker.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian $(grep -E '^VERSION_CODENAME=' /etc/os-release | sed 's/.*=//') stable" > /etc/apt/sources.list.d/docker.list

apt update
apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

usermod --append --groups docker $USER

# Install additional tools. Alternately, replace `freerdp2-x11` with
# `freerdp2-wayland`.
#
apt install \
    freerdp2-x11 \
    jq \
    xz-utils
```

### Android
Coming soon!

## Usage
To create a new engagement (Docker/PRoot image/container, control script, and data directory), just clone this repo and then run `mkenv.sh` from inside of it.

### Linux and macOS
At the end of the process, the control script name will be provided and the script's `help` command will automatically run. In general:

- `$CONTROL_SCRIPT start`: Start the engagement's container.
- `$CONTROL_SCRIPT stop`: Stop the engagement's container.
- `$CONTROL_SCRIPT shell`: Connect to a shell in the engagement's container. Automatically calls `$CONTROL_SCRIPT start` if necessary.
- `$CONTROL_SCRIPT desktop`: Connect to a desktop in the engagement's container. Automatically calls `$CONTROL_SCRIPT start` if necessary. (**Linux only!** For on macOS, use `$CONTROL_SCRIPT start` and then connect to `localhost:3389` using an RDP client).
- `$CONTROL_SCRIPT archive`: Archive the engagement container and control script in the data directory. This is generally what you'll want to do at the end of the engagement.
- `$CONTROL_SCRIPT delete`: Permenantly delete all engagement data.

### Android
Coming soon!
