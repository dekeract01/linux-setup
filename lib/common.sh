#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# common.sh
#  shared helpers for the setup scripts. sourced by linux/setup/*.sh and
#  macos/setup/*.sh, not meant to be run on its own.
#
#  keep this file working on bash 3.2, since that's what macos ships with.
# ------------------------------------------------------------------------------

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
conda_prefix="$HOME/anaconda3"

reboot_required=false
notes=""
current_step=""
tmp_dir=""
sudo_pid=""
log_file=""

# ---- output -------------------------------------------------------------------

if [ -t 1 ]; then
    bold=$'\033[1m' green=$'\033[32m' yellow=$'\033[33m' red=$'\033[31m' reset=$'\033[0m'
else
    bold="" green="" yellow="" red="" reset=""
fi

header() { printf '\n%s------------------------ %s ------------------------%s\n\n' "$bold" "$*" "$reset"; }
info()   { printf '%s==>%s %s\n' "$green" "$reset" "$*"; }
warn()   { printf '%swarning:%s %s\n' "$yellow" "$reset" "$*" >&2; }
die()    { printf '%serror:%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }
have()   { command -v "$1" >/dev/null 2>&1; }

# things to tell the user at the very end
note() { notes="${notes}  - $*"$'\n'; }

# move a file out of the way instead of deleting it
backup() {
    if [ -e "$1" ]; then
        mv "$1" "$1.bak.$(date +%Y%m%d-%H%M%S)"
        info "backed up existing $1"
    fi
}

# ---- running steps --------------------------------------------------------------

# the calling script sets $steps to one "name  description" per line, in run order,
# and a run_<name>=true/false toggle for each

step_names() {
    printf '%s\n' "$steps" | awk 'NF { print $1 }'
}

step_desc() {
    printf '%s\n' "$steps" | awk -v s="$1" '$1 == s { $1 = ""; sub(/^ +/, ""); print }'
}

list_steps() {
    local s var
    printf 'steps (in run order):\n\n'
    for s in $(step_names); do
        var="run_$s"
        printf '  %-10s %-5s %s\n' "$s" "${!var:-false}" "$(step_desc "$s")"
    done
    printf '\n'
}

usage() {
    local me
    me="$(basename "$0")"
    cat <<EOF
usage: $me [step ...]

  $me              run every step set to true at the top of the script
  $me git conda    run just these steps (in the usual order)
  $me --list       show all the steps and whether they're on
  $me --help       show this

EOF
    list_steps
}

cleanup() {
    if [ -n "$sudo_pid" ]; then kill "$sudo_pid" 2>/dev/null || true; fi
    if [ -n "$tmp_dir" ]; then rm -rf "$tmp_dir"; fi
}

on_error() {
    printf '\n%serror:%s step "%s" failed (line %s). fix it and rerun with: %s %s\n' \
        "$red" "$reset" "$current_step" "$1" "$0" "$current_step" >&2
}

# ask for sudo once and keep it alive, long installs outlast the sudo timeout
keep_sudo() {
    info "some steps need sudo, enter your password if asked"
    sudo -v || die "couldn't get sudo"
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) >/dev/null 2>&1 &
    sudo_pid=$!
    disown "$sudo_pid" 2>/dev/null || true
}

start_log() {
    local log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/setup"
    mkdir -p "$log_dir"
    log_file="$log_dir/$1-$(date +%Y%m%d-%H%M%S).log"
    exec > >(tee -a "$log_file") 2>&1
}

# usage: run_steps "$@"
run_steps() {
    local s var names todo=""

    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
        -l|--list) list_steps; exit 0 ;;
        -*) die "unknown option '$1' (try --help)" ;;
    esac

    if [ "$(id -u)" -eq 0 ]; then
        die "run this as your normal user, it'll ask for sudo when it needs it"
    fi

    if [ "${configured:-false}" != true ]; then
        die "open $(basename "$0"), look over the settings at the top and set configured=true first"
    fi

    # pick the steps, either from the command line or from the toggles
    names=" $(step_names | tr '\n' ' ') "
    for s in "$@"; do
        case "$names" in *" $s "*) ;; *) die "unknown step '$s' (try --list)" ;; esac
    done
    for s in $(step_names); do
        var="run_$s"
        if [ $# -gt 0 ]; then
            case " $* " in *" $s "*) todo="$todo $s" ;; esac
        elif [ "${!var:-false}" = true ]; then
            todo="$todo $s"
        fi
    done
    if [ -z "$todo" ]; then die "no steps to run, turn some on at the top of the script"; fi

    start_log "$(basename "$0" .sh)"
    info "running:$todo"
    info "log: $log_file"

    tmp_dir="$(mktemp -d)"
    trap cleanup EXIT
    trap 'on_error $LINENO' ERR
    keep_sudo

    for s in $todo; do
        current_step="$s"
        header "$s. $(step_desc "$s")"
        "step_$s"
    done

    finish
}

finish() {
    header "all done"
    if [ -n "$notes" ]; then
        printf 'a few things to sort out:\n\n%s\n' "$notes"
    fi
    if [ "$reboot_required" = true ]; then
        warn "some changes need a reboot to kick in"
    fi
    info "log saved to $log_file"
}

# ---- shared steps -----------------------------------------------------------------

make_dirs() {
    # only drop ~/bin if it's empty, ~/.local/bin is used instead
    if [ -d "$HOME/bin" ]; then
        rmdir "$HOME/bin" 2>/dev/null || warn "left ~/bin alone, it isn't empty"
    fi
    mkdir -p "$HOME/.local/bin" "$HOME/.local/scripts"
    info "created ~/.local/bin and ~/.local/scripts"
}

setup_git() {
    git config --global user.name "$git_user_name"
    git config --global user.email "$git_user_email"
    git config --global core.editor nano
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    info "git set up for $git_user_name <$git_user_email>"
}

# usage: setup_ssh_keys [extra lines for the github host block]
setup_ssh_keys() {
    local key
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # id_ed25519 for general use, git_ed25519 just for github/gitlab
    for key in id_ed25519 git_ed25519; do
        if [ -f "$HOME/.ssh/$key" ]; then
            info "$key already exists, leaving it"
        else
            info "generating $key (pick a passphrase)"
            ssh-keygen -t ed25519 -a 100 -f "$HOME/.ssh/$key" -C "$USER@$(hostname -s)"
        fi
    done

    touch "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
    if grep -qi '^host github.com' "$HOME/.ssh/config"; then
        info "~/.ssh/config already has a github entry"
    else
        {
            printf '\nHost github.com gitlab.com\n'
            printf '    User git\n'
            printf '    IdentityFile ~/.ssh/git_ed25519\n'
            printf '    IdentitiesOnly yes\n'
            if [ -n "${1:-}" ]; then printf '%s\n' "$1"; fi
        } >> "$HOME/.ssh/config"
        info "added github/gitlab to ~/.ssh/config"
    fi

    note "add ~/.ssh/git_ed25519.pub to github: https://github.com/settings/keys"
}

# usage: setup_vscode_settings <vscode user dir>
setup_vscode_settings() {
    local user_dir="$1" ext
    mkdir -p "$user_dir"
    backup "$user_dir/settings.json"
    cp "$repo_dir/vscode/settings.json" "$user_dir/settings.json"
    info "copied vscode/settings.json to $user_dir"

    if ! have code; then
        warn "'code' isn't on the PATH, skipping extensions"
        return 0
    fi
    while read -r ext; do
        case "$ext" in ''|'#'*) continue ;; esac
        code --install-extension "$ext" --force
    done < "$repo_dir/vscode/extensions.txt"
}

# installs the latest anaconda into ~/anaconda3, checking the download's sha256
install_anaconda() {
    local os arch index installer sha actual sh

    if [ -x "$conda_prefix/bin/conda" ]; then
        info "anaconda is already installed in $conda_prefix"
    else
        case "$(uname -s)" in
            Linux)  os=Linux ;;
            Darwin) os=MacOSX ;;
            *)      die "no anaconda installer for $(uname -s)" ;;
        esac
        # x86_64, aarch64 or arm64. intel macs stopped getting new installers
        # after 2025.06, so they get that one
        arch="$(uname -m)"

        index="$(curl -fsSL https://repo.anaconda.com/archive/)"
        installer="$(printf '%s\n' "$index" | grep -oE "Anaconda3-[0-9]{4}\.[0-9]{2}-[0-9]+-$os-$arch\.sh" | sort -u | tail -n 1)"
        if [ -z "$installer" ]; then die "couldn't find an anaconda installer for $os-$arch"; fi
        sha="$(printf '%s\n' "$index" | grep -A4 ">$installer<" | grep -oE '[0-9a-f]{64}' | head -n 1)"

        info "downloading $installer"
        curl -fL --progress-bar -o "$tmp_dir/$installer" "https://repo.anaconda.com/archive/$installer"

        if have sha256sum; then
            actual="$(sha256sum "$tmp_dir/$installer" | cut -d' ' -f1)"
        else
            actual="$(shasum -a 256 "$tmp_dir/$installer" | cut -d' ' -f1)"
        fi
        if [ -z "$sha" ] || [ "$actual" != "$sha" ]; then
            die "checksum didn't match for $installer, not installing it"
        fi
        info "checksum ok"

        # -b is batch mode, which accepts the anaconda licence for you
        bash "$tmp_dir/$installer" -b -p "$conda_prefix"
        rm -f "$tmp_dir/$installer"
    fi

    for sh in bash zsh; do
        if have "$sh"; then "$conda_prefix/bin/conda" init "$sh" >/dev/null; fi
    done
    info "$("$conda_prefix/bin/conda" --version) ready, conda init done for your shell"
}

# venv3: a conda environment with the latest python from conda-forge
create_venv3() {
    local conda="$conda_prefix/bin/conda"
    if [ ! -x "$conda" ]; then die "anaconda isn't installed, run the conda step"; fi

    if [ -d "$conda_prefix/envs/venv3" ]; then
        info "venv3 already exists, leaving it as it is"
    else
        "$conda" create -y -n venv3 --override-channels -c conda-forge python pip
    fi

    info "venv3 has $("$conda" run -n venv3 python --version)"
    note "open a new terminal, then: conda activate venv3"
}
