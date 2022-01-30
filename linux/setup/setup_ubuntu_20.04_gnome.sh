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
run_step[7]=false        # install software and media codecs from apt repositories
run_step[8]=false        # install Network Manager plugins


# run configure step
if ["configure" = false]; then
    printf "\nConfigure this script first before running \n\n\n"
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
    printf "\n ------------------------ Step $step. create/remove directories ------------------------\n\n"
    
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
    printf "\n ------------------------ Step $step. install general software and utilities ------------------------\n\n"
    
    sudo apt install neofetch htop zip exfat-utils fuse-exfat
    sudo apt install filezilla MozillaThunderbird octave
    sudo apt install build-essential gfortran gcc
    sudo apt install locate
    
    sudo apt install
    
    # install network tools
    sudo apt install net-tools openvpn vpnc
fi

# remove bloat -------------------------------------------------------------------
step=3
if [ "${run_step[$step]}" = true ]; then
    printf "\n ------------------------ Step $step. removing bloat ------------------------\n\n"
    
    sudo apt remove -y cheese cheese-lang
    sudo apt remove -y brasero brasero-lang brasero-nautilus libbrasero-burn3-1 libbrasero-media3-1 libbrasero-utils3-1
    sudo apt remove -y pidgin
    sudo apt remove -y gnome-documents gnome-documents-lang gnome-shell-search-provider-documents
    sudo apt remove -y folks-lang libfolks25 libfolks-eds25 gnome-contacts gnome-contacts-lang gnome-maps gnome-maps-lang gnome-shell-calendar
    sudo apt remove -y mutt mutt-doc mutt-lang
    sudo apt remove -y polari polari-lang typelib-1_0-Polari-1_0
    sudo apt remove -y gnome-shell-search-provider-gnome-weather gnome-weather gnome-weather-lang
fi

# install clamAV -------------------------------------------------------------------
step=4
if [ "${run_step[$step]}" = true ]; then
    printf "\n ------------------------ Step $step. installing clamav ------------------------\n\n"
    
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
    printf "\n ------------------------ Step $step. installing firewalld ------------------------\n\n"
    
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
    printf "\n ------------------------ Step $step. installing and configuring git ------------------------\n\n"
    
    # installing git
    sudo apt install git
    
    # configure git
    git config --global user.name "$git_user_name"
    git config --global user.email "$git_user_email"
    git config --global core.editor nano
fi


# install and configure git -------------------------------------------------------------------
step=7
if [ "${run_step[$step]}" = true ]; then
    printf "\n ------------------------ Step $step. installing and configuring git ------------------------\n\n"
    
    # installing git
    sudo apt install git
    
    # configure git
    git config --global user.name "$git_user_name"
    git config --global user.email "$git_user_email"
    git config --global core.editor nano
fi

