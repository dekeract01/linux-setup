# linux-setup

scripts that set up a new machine the way i like it, so a fresh install goes from
nothing to ready in one go. fedora is what i use day to day. the ubuntu one started
out for my supervisor's server, which ran the original opensbli, and there's one
for macos too.

inspired by my friend matt's setup files for opensuse:
https://gitlab.com/mjrhudson/matts-setup-and-config-files

## layout

```
linux/setup/setup_fedora.sh    fedora workstation (gnome), tested against 44
linux/setup/setup_ubuntu.sh    ubuntu desktop (gnome), 26.04 lts
macos/setup/setup_macos.sh     macos on apple silicon
lib/common.sh                  shared bits: logging, the step runner, git, ssh, vscode, anaconda
vscode/settings.json           my vscode settings, copied in by the vscode step
vscode/extensions.txt          vscode extensions to install, one per line
```

## using it

no git needed, a fresh install already has curl (or wget) and tar:

```sh
curl -fsSL https://github.com/dekeract01/linux-setup/archive/refs/heads/main.tar.gz | tar -xz
# or: wget -qO- https://github.com/dekeract01/linux-setup/archive/refs/heads/main.tar.gz | tar -xz
cd linux-setup-main
```

open the script for your system, look over the configuration at the top (git
name and email, firewall zone, ssh port, which steps to run) and set
`configured=true`. it won't run until you do. then:

```sh
./linux/setup/setup_fedora.sh               # run every step that's switched on
./linux/setup/setup_fedora.sh git conda     # run just these steps
./linux/setup/setup_fedora.sh --list        # see all the steps
```

run it as your normal user, it asks for sudo once at the start. every run is
logged to `~/.local/state/setup/`. if a step fails it tells you which one, so you
can fix it and rerun just that step. the steps are safe to rerun.

## steps

| step      | fedora | ubuntu | macos | what it does |
|-----------|:------:|:------:|:-----:|--------------|
| xcode     |        |        |   ✓   | xcode command line tools |
| homebrew  |        |        |   ✓   | homebrew |
| update    |   ✓    |   ✓    |       | full system update (plus rpm fusion on fedora) |
| dirs      |   ✓    |   ✓    |   ✓   | `~/.local/bin`, `~/.local/scripts` |
| basics    |   ✓    |   ✓    |   ✓   | compilers, gfortran, cmake, hdf5, octave, htop, fastfetch, thunderbird... |
| bloat     |   ✓    |   ✓    |       | removes gnome apps and games i don't use |
| clamav    |   ✓    |   ✓    |       | clamav with automatic database updates |
| firewall  |   ✓    |   ✓    |   ✓   | firewalld zone for the machine (macos firewall + stealth mode on mac) |
| vpn       |   ✓    |   ✓    |       | openvpn and vpnc plugins for network manager |
| git       |   ✓    |   ✓    |   ✓   | git with my name, email and defaults |
| flatpak   |   ✓    |   ✓    |       | flathub |
| vscode    |   ✓    |   ✓    |   ✓   | vs code, my settings and extensions |
| syncthing |   ✓    |   ✓    |   ✓   | syncthing running as your user |
| ssh       |   ✓    |   ✓    |   ✓   | `id_ed25519` and `git_ed25519` keys, github/gitlab in `~/.ssh/config` |
| sshd      |   ✓    |   ✓    |       | ssh server on a custom port, keys only (off by default) |
| nvidia    |   ✓    |   ✓    |       | nvidia drivers (and cuda on ubuntu), skipped if there's no nvidia card |
| defaults  |        |        |   ✓   | finder shows extensions and the path bar, screenshots in `~/Pictures/Screenshots` |
| conda     |   ✓    |   ✓    |   ✓   | anaconda in `~/anaconda3` plus a `venv3` env with the latest python |

## anaconda and venv3

the conda step grabs the newest anaconda installer from repo.anaconda.com, checks
its sha256 against the one anaconda publishes, and installs it to `~/anaconda3`
(batch mode, which accepts the anaconda licence). then it makes `venv3`, a conda
environment with the latest python from conda-forge:

```sh
conda activate venv3
```

## notes

- `sshd` turns off password logins, so put your public key in
  `~/.ssh/authorized_keys` before relying on it remotely
- on fedora with secure boot, the nvidia driver needs signing, see
  https://rpmfusion.org/Howto/Secure%20Boot
- reboot after the first run, the update, flatpak and nvidia steps need it
