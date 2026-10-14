#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# setup_macos.sh
#  sets up a fresh mac (apple silicon). works with the bash 3.2 macos ships with.
#
#  ./setup_macos.sh              run every step set to true below
#  ./setup_macos.sh git conda    run just those steps
#  ./setup_macos.sh --list       list the steps
#
# author. dekeract01
# ------------------------------------------------------------------------------
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

# ---- configuration ------------------------------------------------------------
# look over everything in this section, then set configured=true.
# the script won't run until you do.
configured=false

git_user_name="dekeract01"
git_user_email="dekeract01@gmail.com"

# set any of these to false to skip that step
run_xcode=true
run_homebrew=true
run_dirs=true
run_basics=true
run_firewall=true
run_git=true
run_vscode=true
run_syncthing=true
run_ssh=true
run_defaults=true
run_conda=true

steps="
xcode      install the xcode command line tools
homebrew   install homebrew
dirs       create the usual directories in ~
basics     install general software and utilities
firewall   turn on the macos firewall and stealth mode
git        install and configure git
vscode     install visual studio code and copy over my settings
syncthing  install syncthing and start it at login
ssh        generate ssh keys and set up ~/.ssh/config
defaults   tweak finder and screenshot settings
conda      install anaconda and create the venv3 environment
"
# ------------------------------------------------------------------------------

if [ "$(uname -s)" != Darwin ]; then
    case "${1:-}" in -h|--help|-l|--list) ;; *) die "this script is for macos" ;; esac
fi

# put brew on the PATH for this run, wherever it got installed
load_brew() {
    local b
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$b" ]; then
            eval "$("$b" shellenv)"
            return 0
        fi
    done
    die "homebrew isn't installed, run the homebrew step"
}

step_xcode() {
    if xcode-select -p >/dev/null 2>&1; then
        info "command line tools are already installed"
        return 0
    fi
    xcode-select --install
    info "finish the install in the window that popped up, waiting for it..."
    until xcode-select -p >/dev/null 2>&1; do sleep 10; done
    info "command line tools installed"
}

step_homebrew() {
    if [ -x /opt/homebrew/bin/brew ] || [ -x /usr/local/bin/brew ]; then
        info "homebrew is already installed"
    else
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    load_brew

    # so new terminals can find brew too
    touch "$HOME/.zprofile"
    if ! grep -q 'brew shellenv' "$HOME/.zprofile"; then
        printf '\neval "$(%s/bin/brew shellenv)"\n' "$(brew --prefix)" >> "$HOME/.zprofile"
    fi
    brew update
}

step_dirs() {
    make_dirs
}

step_basics() {
    load_brew
    brew install fastfetch htop wget p7zip
    brew install gcc cmake hdf5 octave
    brew install --cask thunderbird
}

step_firewall() {
    local fw=/usr/libexec/ApplicationFirewall/socketfilterfw
    sudo "$fw" --setglobalstate on
    sudo "$fw" --setstealthmode on
    "$fw" --getglobalstate
}

step_git() {
    load_brew
    brew install git
    setup_git
}

step_vscode() {
    load_brew
    brew install --cask visual-studio-code
    setup_vscode_settings "$HOME/Library/Application Support/Code/User"
}

step_syncthing() {
    load_brew
    brew install syncthing
    brew services start syncthing
    note "syncthing's web ui is at http://127.0.0.1:8384"
}

step_ssh() {
    # keep key passphrases in the macos keychain
    setup_ssh_keys "    AddKeysToAgent yes
    UseKeychain yes"
}

step_defaults() {
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write com.apple.finder ShowStatusBar -bool true
    defaults write com.apple.finder FXPreferredViewStyle -string Nlsv
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

    mkdir -p "$HOME/Pictures/Screenshots"
    defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"

    killall Finder SystemUIServer 2>/dev/null || true
    info "finder shows extensions, the path bar and list view, screenshots go to ~/Pictures/Screenshots"
}

step_conda() {
    install_anaconda
    create_venv3
}

run_steps "$@"
