#!bin/bash
# ----------------------------------------------------------------------------------
# setup_ubuntu_20.04.3_gnome.sh
#
#
#
# author. gnsa1e21
# date created. 19.04.2020, date updated, 29.01.2022
# ----------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------
# set configured=true when you have looked over the run options and configuration
#  settings for this script and are happy with them. The script will not run
#  until this is done.
configure=false
# ----------------------------------------------------------------------------------


# configure run steps
# set these to either true or false depending on which steps you want to run
run_step[0]=$configured # See above
run_step[1]=false        # create and remove directories
run_step[2]=false        # install basics and utilities
run_step[3]=false        # remove bloat
run_step[4]=false        # install clamav
run_step[5]=false        # configure firewalld
run_setp[6]=false        # install and configure git
run_step[7]=false        # install flatpak
run_step[8]=false        # install visual studio code
run_step[9]=false        # install syncthing
run_step[10]=false       # install and configure ssh
run_step[11]=false       # install and configure nvidia drivers

# Utilities


# run configure step
if ["configure" = false]; then
    printf "\nconfigure this script first before running \n\n\n"
    exit
fi

# configure settings
home_zone_name="orion"                      #
git_user_name="dekeract01"                  #
git_user_email="dekeract01@gmail.com"       #
ssh_port="35"                               #
vnc_ports="5900=59065"                      #

# reboot requirements
reboot_required=false

# make temporary directory for downloading and extracting files
tempdir="/tmp/setup-ubuntu-2004"
if [ -d "$tempdir" ]; ten
    rm -rf "$tempdir"
fi

mkdir "$tempdir"
pushd "$tempdir"

# update and upgrade repository
sudo apt update
sudo apt upgrade

# create and remove directories ----------------------------------------------------
step=1
if [ "${run_step[$step]}" = true]; then
    printf "\n ------------------------ step $step. create/remove directories ------------------------\n\n"
    
    if [ -d "$HOME/bin" ]; then
        rm -rf "$HOME/bin"
    fi
    
    if [ ! -d "$HOME/.local/bin" ]; then
        mkdir -p "$HOME/.local/bin"
    fi
    
    if [ ! -d "$HOME/.local/scripts" ]; then
        mkdir -p "$HOME/.local/scripts"
    fi
    
    if [ ! -d "$HOME/.config/systemd/user" ]; then
        mkdir -p "$HOME/.config/systemd/user"
    fi
fi


# install basic software and utilities ---------------------------------------------
step=2
if [ "${run_step[$step]}" = true ]; then
    printf "\n ------------------------ step $step. install general software and utilities ------------------------\n\n"
    
    sudo apt install neofetch htop zip exfat-utils fuse-exfat
    sudo apt install filezilla MozillaThunderbird octave
    sudo apt install build-essential gfortran gcc
    sudo apt install locate hwinfo
    
    # install hdf5 tools
    sudo apt install hdf5-tools
    
    # install network tools
    sudo apt install net-tools openvpn vpnc
fi

# remove bloat -------------------------------------------------------------------
step=3
if [ "${run_step[$step]}" = true ]; then
    printf "\n ------------------------ step $step. removing bloat ------------------------\n\n"
    
    sudo apt remove -y cheese cheese-lang
    sudo apt remove -y brasero brasero-lang brasero-nautilus libbrasero-burn3-1 libbrasero-media3-1 libbrasero-utils3-1
    sudo apt remove -y pidgin
    sudo apt remove -y gnome-documents gnome-documents-lang gnome-shell-search-provider-documents
    sudo apt remove -y folks-lang libfolks25 libfolks-eds25 gnome-contacts gnome-contacts-lang gnome-maps gnome-maps-lang gnome-shell-calendar
    sudo apt remove -y mutt mutt-doc mutt-lang
    sudo apt remove -y polari polari-lang typelib-1_0-Polari-1_0
    sudo apt remove -y gnome-shell-search-provider-gnome-weather gnome-weather gnome-weather-lang
    
    # uninstall all games
    sudo apt purge aisleriot gnome-sudoku mahjongg ace-of-penguins gnomine gbrainy
fi

# install clamAV -------------------------------------------------------------------
step=4
if [ "${run_step[$step]}" = true ]; then
    printf "\n ------------------------ step $step. installing clamav ------------------------\n\n"
    
    sudo apt install clamav clamav-daemon
    
    # update clamav signature database
    sudo systemctl stop clamav-freshclam
    sudo freshclam
    
    sudo systemctl enable clamd
    sudo systemctl start clamd
    
    sudo mkdir /var/lib/clamav
    cp daily.cvd /var/lib/clamav/daily.cvd
    sudo systemctl start clamav-freshclam
    
    # test case: clamscan downloads
    clamscan --infected --remove --recursive $HOME/Downloads
fi

# configure firewall ---------------------------------------------------------------
step=5
if [ "${run_step[$step]}" = true ]; then
    printf "\n ------------------------ step $step. installing firewalld ------------------------\n\n"
    
    # install firewall (if doens't exist), the default firewall for ubuntu is ufw
    sudo apt install firewalld
    
    # configure firewall
    sudo firewall-cmd --permanent --new-zone="$home_zone_name"
    sudo firewall-cmd --reload
    sudo firewall-cmd --set-default-zone "$home_zone_name"
    
    # enable firewall on ubuntu
    sudo ufw enable
fi


# install and configure git --------------------------------------------------------
step=6
if [ "${run_step[$step]}" = true ]; then
    printf "\n ------------------------ step $step. installing and configuring git ------------------------\n\n"
    
    # installing git
    sudo apt install git
    
    # configure git
    git config --global user.name "$git_user_name"
    git config --global user.email "$git_user_email"
    git config --global core.editor nano
fi


# install flatpack -------------------------------------------------------------------
step=7
if [ "${run_step[$step]}" = true ]; then
    printf "\n ------------------------ step $step. (reboot required) installing flatpack ------------------------\n\n"
    
    # installing flatpack
    sudo apt install flatpak gnome-software-plugin-flatpak gnome-software
    
    # add to remote repository
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    reboot_required=true
    
fi

# install and configure visual studio code -------------------------------------------------------------------
step=8
if [ "${run_step[$step]}" = true ]; then
    printf "\n ------------------------ step $step. installing and configuring visual studio code ------------------------\n\n"
    
    # install visual studio code, instructions: https://code.visualstudio.com/docs/setup/linux
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm -f packages.microsoft.gpg
    
    sudo apt install apt-transport-https
    sudo apt update
    
    # install visual studio code
    sudo apt install code # or code-insiders
    
    # configure visual studio
    
    if [ -f "$HOME/.config/Code/User/settings.json" ]; then
        rm -f "$HOME/.config/Code/User/settings.json"
    fi
    
    wget -P "$HOME/.config/Code/User" "https://gitlab.com/mjrhudson/matss-setup-and-config-files/-/raw/master/vscode/settings.json"
    
fi

# install and configure ssh -------------------------------------------------------------------
step=9
if [ "${run_step[$step]}" = true ]; then
    printf "\n ------------------------ step $step. installing and configuring syncthing ------------------------\n\n"
    
    # add syncthing to apt repos
    echo "deb https://apt.syncthing.net/ syncthing stable" | sudo tee /etc/apt/sources.list.d/syncthing.list
    
    # add syncthing pgp keys
    curl -s https://syncthing.net/release-key.txt | sudo apt-key add -
    
    # update apt database
    sudo apt update
    
    # install syncthing
    sudo apt install syncthing
    
    # enable syncthing service
    sudo systemctl enable syncthing@$USER.service
    
    # start syncthing
    sudo systemctl start syncthing@$USER.service
    
    # check syncthing adn add further automation
fi


# install and configure ssh -------------------------------------------------------------------
step=10
if [ "${run_step[$step]}" = true ]; then
    printf "\n ------------------------ step $step. installing and configuring ssh + sshd ------------------------\n\n"
    
    #  install ssh
    sudo apt install openssh-server
    
    sudo systemctl enable ssh
    sudo systemctl start ssh
    
    # generate ssh keys
    ssh-keygen -t ed25519 -a 100 -f "$HOME/.ssh/id_ed25519" -C "$USER@$HOSTNAME"
    ssh-keygen -t ed25519 -a 100 -f "$HOME/.ssh/git_ed25519" -C "$USER@$HOSTNAME"
    
    if [ -f "$HOME/.ssh/config" ]; then
        rm -f "$HOME/.ssh/config"
    fi
    
    wget -P "$HOME/.ssh" "https://gitlab.com/mjrhudson/matt-setup-and-config-files/-/raw/master/linux/ssh/config"
    
    chmod 600 "$HOME/.ssh/config"
    
    
    # configure sshd
    # set custom ssh port to use
    sudo sed -i "s/^\<Port .*\>/Port $ssh_port/g" "/etc/ssh/ssh_config"
    sudo sed -i "s/^#\<Port .*\>/Port $ssh_port/g" "/etc/ssh/ssh_config"
    
    # enable public key authentication
    sudo sed -i "s/^\<PubkeyAuthentication .*\>/PubkeyAuthentication yes/g" "/etc/ssh/ssh_config"
    sudo sed -i "s/^#\<PubkeyAuthentication .*\>/PubkeyAuthentication yes/g" "/etc/ssh/sshd_config"
    
    # disable password authentication
    sudo sed -i "s/^\<PasswordAuthentication .*\>/PasswordAuthentication no/g" "/etc/ssh/sshd_config"
    sudo sed -i "s/^#\<PasswordAuthentication .*\>/PasswordAuthentication no/g" "/etc/ssh/sshd_config"
    
    # allow custom ssh port through firewall
    sudo firewall-cmd --permanent --new-service="ssh-$ssh_port"
    sudo firewall-cmd --permanent --service="ssh-$ssh_port" --set-description="SSH service on port $ssh_port"
    sudo firewall-cmd --permanent --service="ssh-$ssh_port" --add-port="$ssh_port/tcp"
    sudo firewall-cmd --permanent --zone="$home_zone_name" --add-service="ssh-$ssh_port"
    sudo firewall-cmd --reload
    
    # start sshd service
    sudo systemctl enable sshd
    sudo systemctl start sshd

fi


# install and configure nvidia -------------------------------------------------------------------
step=11
if [ "${run_step[$step]}" = true ]; then
    
    
    if sudo hwinfo --gfxcard | grep -iF "model" | grep -iqF "nvidia"; then
        nvidia_detected=true
        echo "nvidia detected, installing nvidia drivers"
    else
        nvidia_detected=false
        echo "the computer is not equiped with an nvidia driver, process terminated."
    fi
    
    if [ "$nvidia_detected" = true ]; then
            printf "\n ------------------------ step $step. installing and configuring nvidia drivers ------------------------\n\n"

            # sudo apt-get update
            
            # install cuda
            sudo apt clean
            sudo apt update
            sudo apt remove nvidia-*
            
            
            
            
            # verify the system has cuda compatible hardware
            lspci | grep -i nvidia
            
            # verify linux version
            uname -m && cat /etc/*release
            
            # install kernal headers
            sudo apt-get install linux-headers-$(uname -r)
            
            
            
            # install cuda drivers
            wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
            
            sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
            
            wget https://developer.download.nvidia.com/compute/cuda/11.6.0/local_installers/cuda-repo-ubuntu2004-11-6-local_11.6.0-510.39.01-1_amd64.deb
            
            sudo dpkg -i cuda-repo-ubuntu2004-11-6-local_11.6.0-510.39.01-1_amd64.deb
            
            sudo apt-key add /var/cuda-repo-ubuntu2004-11-6-local/7fa2af80.pub
            
            sudo apt-get update
            
            sudo apt-get -y install cuda
            
            sudo apt install cuda nvidia-cuda-toolkit
            
    fi
fi




