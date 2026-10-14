#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# setup_fedora.sh
#  sets up a fresh fedora workstation (gnome) install. tested against fedora 44.
#
#  ./setup_fedora.sh              run every step set to true below
#  ./setup_fedora.sh git conda    run just those steps
#  ./setup_fedora.sh --list       list the steps
#
# author. dekeract01
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
update     update the system and enable rpm fusion
dirs       create the usual directories in ~
basics     install general software and utilities
bloat      remove apps i don't use
clamav     install clamav and update its virus database
firewall   set up a firewalld zone for this machine
vpn        install the openvpn and vpnc plugins for network manager
git        install and configure git
flatpak    add the flathub repository
vscode     install visual studio code and copy over my settings
syncthing  install syncthing and start it for this user
ssh        generate ssh keys and set up ~/.ssh/config
sshd       run an ssh server on a custom port, keys only
nvidia     install the nvidia drivers from rpm fusion
conda      install anaconda and create the venv3 environment
"
# ------------------------------------------------------------------------------

if [ ! -f /etc/os-release ] || ! grep -q '^ID=fedora' /etc/os-release; then
    case "${1:-}" in -h|--help|-l|--list) ;; *) die "this script is for fedora" ;; esac
fi

pkg_install() { sudo dnf install -y "$@"; }

# remove only the packages that are actually installed
pkg_remove() {
    local p installed=""
    for p in "$@"; do
        if rpm -q "$p" >/dev/null 2>&1; then installed="$installed $p"; fi
    done
    if [ -z "$installed" ]; then
        info "nothing to remove"
    else
        # shellcheck disable=SC2086
        sudo dnf remove -y $installed
    fi
}

enable_rpmfusion() {
    local v
    v="$(rpm -E %fedora)"
    if rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1; then
        info "rpm fusion is already enabled"
    else
        pkg_install \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$v.noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$v.noarch.rpm"
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
    sudo dnf upgrade -y --refresh
    enable_rpmfusion
    reboot_required=true
}

step_dirs() {
    make_dirs
    mkdir -p "$HOME/.config/systemd/user"
}

step_basics() {
    pkg_install fastfetch htop zip unzip 7zip exfatprogs wget curl
    pkg_install thunderbird filezilla octave
    pkg_install gcc gcc-c++ gcc-gfortran make cmake gdb
    pkg_install plocate hwinfo pciutils
    pkg_install hdf5 hdf5-devel
    pkg_install net-tools
}

step_bloat() {
    pkg_remove gnome-contacts gnome-maps gnome-weather gnome-tour rhythmbox cheese
    pkg_remove aisleriot gnome-mahjongg gnome-mines gnome-sudoku
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
    pkg_install openvpn vpnc NetworkManager-openvpn-gnome NetworkManager-vpnc-gnome
}

step_git() {
    pkg_install git
    setup_git
}

step_flatpak() {
    pkg_install flatpak
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    # fedora can ship flathub disabled or filtered, make sure it's the full thing
    sudo flatpak remote-modify --enable --no-filter flathub
    reboot_required=true
}

step_vscode() {
    # https://code.visualstudio.com/docs/setup/linux
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    pkg_install code
    setup_vscode_settings "$HOME/.config/Code/User"
}

step_syncthing() {
    pkg_install syncthing
    systemctl --user enable --now syncthing.service

    if have firewall-cmd; then
        sudo firewall-cmd --permanent --zone="$(firewall_zone)" --add-service=syncthing
        sudo firewall-cmd --reload
    fi
    note "syncthing's web ui is at http://127.0.0.1:8384"
}

step_ssh() {
    pkg_install openssh-clients
    setup_ssh_keys
}

step_sshd() {
    local zone
    pkg_install openssh-server policycoreutils-python-utils

    # a drop-in wins over the defaults, fedora reads sshd_config.d/ first
    sudo tee /etc/ssh/sshd_config.d/10-setup.conf >/dev/null <<EOF
Port $ssh_port
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF

    # selinux only lets sshd use ports it knows about
    if ! sudo semanage port -l | grep -E '^ssh_port_t' | grep -w "$ssh_port" >/dev/null; then
        sudo semanage port -a -t ssh_port_t -p tcp "$ssh_port" 2>/dev/null \
            || sudo semanage port -m -t ssh_port_t -p tcp "$ssh_port"
    fi

    zone="$(firewall_zone)"
    sudo firewall-cmd --permanent --zone="$zone" --add-port="$ssh_port/tcp"
    sudo firewall-cmd --reload

    sudo sshd -t
    sudo systemctl enable sshd
    sudo systemctl restart sshd
    info "sshd listening on port $ssh_port (zone $zone)"
    note "sshd only takes keys, add yours to ~/.ssh/authorized_keys on this machine"
}

step_nvidia() {
    if ! lspci | grep -i nvidia >/dev/null; then
        info "no nvidia card found, skipping"
        return 0
    fi
    info "nvidia card found: $(lspci | grep -i nvidia | head -n 1 | cut -d: -f3-)"

    enable_rpmfusion
    pkg_install kernel-devel akmod-nvidia xorg-x11-drv-nvidia-cuda
    reboot_required=true
    note "the nvidia module takes a few minutes to build, wait before rebooting (check with: modinfo -F version nvidia)"
    if have mokutil && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
        note "secure boot is on, see https://rpmfusion.org/Howto/Secure%20Boot to sign the nvidia module"
    fi
}

step_conda() {
    install_anaconda
    create_venv3
}

run_steps "$@"
