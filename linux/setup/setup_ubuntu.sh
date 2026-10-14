#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# setup_ubuntu.sh
#  sets up a fresh ubuntu (gnome) install. first written for my supervisor's
#  server running the original opensbli, now updated for 26.04 lts,
#  should be fine on 24.04 too.
#
#  ./setup_ubuntu.sh              run every step set to true below
#  ./setup_ubuntu.sh git conda    run just those steps
#  ./setup_ubuntu.sh --list       list the steps
#
# author. dekeract01
# date created. 29.01.2022
# inspired by matt's setup files: https://gitlab.com/mjrhudson/matts-setup-and-config-files
# ------------------------------------------------------------------------------
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

# ---- configuration ------------------------------------------------------------
# look over everything in this section, then set configured=true.
# the script won't run until you do.
configured=false

git_user_name="dekeract01"
git_user_email="dekeract01@gmail.com"
home_zone_name="orion"          # firewalld zone for this machine
ssh_port="35"                   # port for the ssh server (sshd step)

# set any of these to false to skip that step
run_update=true
run_dirs=true
run_basics=true
run_bloat=true
run_clamav=true
run_firewall=true
run_vpn=true
run_git=true
run_flatpak=true
run_vscode=true
run_syncthing=true
run_ssh=true
run_sshd=false                  # turns off password logins, make sure you've got keys set up
run_nvidia=true                 # skipped automatically if there's no nvidia card
run_conda=true

steps="
update     update the system
dirs       create the usual directories in ~
basics     install general software and utilities
bloat      remove apps i don't use
clamav     install clamav and update its virus database
firewall   swap ufw for firewalld and set up a zone for this machine
vpn        install the openvpn and vpnc plugins for network manager
git        install and configure git
flatpak    install flatpak and add the flathub repository
vscode     install visual studio code and copy over my settings
syncthing  install syncthing and start it for this user
ssh        generate ssh keys and set up ~/.ssh/config
sshd       run an ssh server on a custom port, keys only
nvidia     install the nvidia drivers and the cuda toolkit
conda      install anaconda and create the venv3 environment
"
# ------------------------------------------------------------------------------

if [ ! -f /etc/os-release ] || ! grep -qE '^ID(_LIKE)?=.*ubuntu' /etc/os-release; then
    case "${1:-}" in -h|--help|-l|--list) ;; *) die "this script is for ubuntu" ;; esac
fi

apt_get() { sudo env DEBIAN_FRONTEND=noninteractive apt-get "$@"; }
pkg_install() { apt_get install -y "$@"; }

# remove only the packages that are actually installed
pkg_remove() {
    local p installed=""
    for p in "$@"; do
        if dpkg -s "$p" >/dev/null 2>&1; then installed="$installed $p"; fi
    done
    if [ -z "$installed" ]; then
        info "nothing to remove"
    else
        # shellcheck disable=SC2086
        apt_get purge -y $installed
        apt_get autoremove -y
    fi
}

# the zone set up by the firewall step, or whatever the default is if it hasn't run
firewall_zone() {
    if sudo firewall-cmd --get-zones | tr ' ' '\n' | grep -qx "$home_zone_name"; then
        echo "$home_zone_name"
    else
        sudo firewall-cmd --get-default-zone
    fi
}

step_update() {
    apt_get update
    apt_get full-upgrade -y
    pkg_install curl wget
    if [ -f /var/run/reboot-required ]; then reboot_required=true; fi
}

step_dirs() {
    make_dirs
    mkdir -p "$HOME/.config/systemd/user"
}

step_basics() {
    pkg_install fastfetch htop zip unzip 7zip exfatprogs wget curl
    pkg_install thunderbird filezilla octave
    pkg_install build-essential gfortran cmake gdb
    pkg_install plocate hwinfo pciutils
    pkg_install hdf5-tools libhdf5-dev
    pkg_install net-tools
}

step_bloat() {
    pkg_remove aisleriot gnome-mahjongg gnome-mines gnome-sudoku
    pkg_remove rhythmbox cheese gnome-contacts gnome-maps gnome-weather
}

step_clamav() {
    pkg_install clamav clamav-freshclam

    # stop the updater so freshclam can run now, then leave it running in the background
    sudo systemctl stop clamav-freshclam 2>/dev/null || true
    sudo freshclam || warn "freshclam couldn't update right now, the service will retry"
    sudo systemctl enable --now clamav-freshclam

    clamscan --infected --recursive "$HOME/Downloads" || true
    note "scan anything with: clamscan --infected --recursive <folder>"
}

step_firewall() {
    # ubuntu comes with ufw, running both at once makes a mess
    if have ufw; then sudo ufw disable || true; fi

    pkg_install firewalld
    sudo systemctl enable --now firewalld

    if sudo firewall-cmd --get-zones | tr ' ' '\n' | grep -qx "$home_zone_name"; then
        info "zone $home_zone_name already exists"
    else
        sudo firewall-cmd --permanent --new-zone="$home_zone_name"
        # keep the network and local discovery working, everything else incoming is blocked
        sudo firewall-cmd --permanent --zone="$home_zone_name" --add-service=dhcpv6-client
        sudo firewall-cmd --permanent --zone="$home_zone_name" --add-service=mdns
        sudo firewall-cmd --reload
    fi
    sudo firewall-cmd --set-default-zone="$home_zone_name"
    info "default zone is now $(sudo firewall-cmd --get-default-zone)"
}

step_vpn() {
    # vpns then show up under settings > network
    pkg_install openvpn vpnc network-manager-openvpn-gnome network-manager-vpnc-gnome
}

step_git() {
    pkg_install git
    setup_git
}

step_flatpak() {
    pkg_install flatpak gnome-software gnome-software-plugin-flatpak
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    reboot_required=true
}

step_vscode() {
    # https://code.visualstudio.com/docs/setup/linux
    pkg_install wget gpg apt-transport-https
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "$tmp_dir/microsoft.gpg"
    sudo install -D -o root -g root -m 644 "$tmp_dir/microsoft.gpg" /usr/share/keyrings/microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    apt_get update
    pkg_install code
    setup_vscode_settings "$HOME/.config/Code/User"
}

step_syncthing() {
    # https://apt.syncthing.net
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL -o /etc/apt/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg
    echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable-v2" \
        | sudo tee /etc/apt/sources.list.d/syncthing.list >/dev/null
    apt_get update
    pkg_install syncthing
    systemctl --user enable --now syncthing.service

    if have firewall-cmd; then
        sudo firewall-cmd --permanent --zone="$(firewall_zone)" --add-service=syncthing
        sudo firewall-cmd --reload
    fi
    note "syncthing's web ui is at http://127.0.0.1:8384"
}

step_ssh() {
    pkg_install openssh-client
    setup_ssh_keys
}

step_sshd() {
    pkg_install openssh-server

    # a drop-in wins over the defaults, ubuntu reads sshd_config.d/ first
    sudo tee /etc/ssh/sshd_config.d/10-setup.conf >/dev/null <<EOF
Port $ssh_port
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF

    if have firewall-cmd; then
        sudo firewall-cmd --permanent --zone="$(firewall_zone)" --add-port="$ssh_port/tcp"
        sudo firewall-cmd --reload
    else
        warn "firewalld isn't installed, open port $ssh_port yourself"
    fi

    sudo mkdir -p /run/sshd
    sudo sshd -t
    # newer ubuntu starts ssh from a socket, which picks up the port from sshd_config
    sudo systemctl daemon-reload
    if systemctl is-enabled ssh.socket >/dev/null 2>&1; then
        sudo systemctl restart ssh.socket
    else
        sudo systemctl enable ssh
        sudo systemctl restart ssh
    fi
    info "sshd listening on port $ssh_port"
    note "sshd only takes keys, add yours to ~/.ssh/authorized_keys on this machine"
}

step_nvidia() {
    local release
    if ! lspci | grep -i nvidia >/dev/null; then
        info "no nvidia card found, skipping"
        return 0
    fi
    info "nvidia card found: $(lspci | grep -i nvidia | head -n 1 | cut -d: -f3-)"

    # drivers, ubuntu picks the right one for the card
    pkg_install ubuntu-drivers-common "linux-headers-$(uname -r)"
    sudo ubuntu-drivers install

    # cuda toolkit from nvidia's repo, https://developer.nvidia.com/cuda-downloads
    release="$(. /etc/os-release && echo "${VERSION_ID//./}")"
    wget -qO "$tmp_dir/cuda-keyring.deb" \
        "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu$release/x86_64/cuda-keyring_1.1-1_all.deb"
    sudo dpkg -i "$tmp_dir/cuda-keyring.deb"
    apt_get update
    pkg_install cuda-toolkit

    reboot_required=true
    note "cuda is in /usr/local/cuda, add /usr/local/cuda/bin to your PATH"
}

step_conda() {
    install_anaconda
    create_venv3
}

run_steps "$@"
