#!/bin/bash

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    elif command -v lsb_release &>/dev/null; then
        DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
    elif [ -f /etc/fedora-release ]; then
        DISTRO="fedora"
    elif [ -f /etc/arch-release ]; then
        DISTRO="arch"
    else
        DISTRO="unknown"
    fi

    # Fallback to detect Arch-based systems (like EndeavourOS, Manjaro, etc.)
    if [ "$DISTRO" == "endeavouros" ] || [ "$DISTRO" == "manjaro" ]; then
        DISTRO="arch"
    fi
}

# Function to confirm user input for package installation
confirm() {
    read -p "$1 [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to check if a package is installed
check_installed() {
    local package_name=$1
    case "$DISTRO" in
        debian|ubuntu)
            dpkg -s "$package_name" &>/dev/null
            ;;
        arch)
            pacman -Qi "$package_name" &>/dev/null
            ;;
        fedora|rhel)
            rpm -q "$package_name" &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to install packages with a check and reinstall option
check_and_install() {
    local package_name="$1"
    local install_command="$2"

    if check_installed "$package_name"; then
        confirm "$package_name is already installed. Do you want to reinstall it?" && eval "$install_command"
    else
        eval "$install_command"
    fi
}

# Function to install common software like Chrome, VSCode, Discord, etc.
install_external_software() {
    # Install Google Chrome
    if ! check_installed "google-chrome"; then
        confirm "Google Chrome is not installed. Do you want to install it?" && {
            wget -O chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
            sudo apt install ./chrome.deb
            rm -f chrome.deb
        }
    fi

    # Install Visual Studio Code
    if ! check_installed "code"; then
        confirm "VSCode is not installed. Do you want to install it?" && {
            wget -O code.deb https://update.code.visualstudio.com/latest/linux-deb-x64/stable
            sudo apt install ./code.deb
            rm -f code.deb
        }
    fi

    # Install Discord
    if ! check_installed "discord"; then
        confirm "Discord is not installed. Do you want to install it?" && {
            wget -O discord.deb https://discord.com/api/download?platform=linux&format=deb
            sudo apt install ./discord.deb
            rm -f discord.deb
        }
    fi
}

# Function to install WhiteSur theme and icons with specific flags
install_whitesur_theme() {
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git || true
    cd WhiteSur-gtk-theme
    confirm "Do you want to install the WhiteSur theme?" && {
        ./install.sh --roundedmaxwindow -HD --color Dark
    }
    cd ..
    rm -rf WhiteSur-gtk-theme
}

# Function to install WhiteSur Icon Theme
install_whitesur_icon_theme() {
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git || true
    cd WhiteSur-icon-theme
    confirm "Do you want to install the WhiteSur Icons?" && {
        ./install.sh
    }
    cd ..
    rm -rf WhiteSur-icon-theme
}

# Function to clone a repository with retry logic
install_git_repo() {
    local repo_url="$1"
    local dir_name="$2"
    local max_retries=4
    local attempt=0

    while (( attempt < max_retries )); do
        if [ -d "$dir_name" ]; then
            confirm "The directory $dir_name already exists. Do you want to remove it and clone again?" && rm -rf "$dir_name"
        fi

        git clone --depth=1 "$repo_url" "$dir_name" && break
        echo "Failed to clone $repo_url, retrying... ($(( attempt + 1 ))/$max_retries)"
        attempt=$(( attempt + 1 ))
        sleep 2
    done

    if (( attempt == max_retries )); then
        echo "Failed to clone the repository after $max_retries attempts. Exiting."
        return 1
    fi
}
# Function to replace Manjaro with EndeavourOS in config.yaml
replace_manjaro_with_endeavouros() {
    local config_file="$1/config.yaml"

    if [ -f "$config_file" ]; then
        if grep -q "manjaro" "$config_file"; then
            sed -i 's/manjaro/endeavouros/g' "$config_file"
            echo "Replaced Manjaro with EndeavourOS in config.yaml."
        else
            echo "Manjaro not found in config.yaml, nothing to replace."
        fi
    else
        echo "config.yaml not found in $1. Skipping modification."
    fi
}
# Function to build and install Deskflow
build_and_install_deskflow() {
    local dir_name="deskflow"

    install_git_repo "https://github.com/deskflow/deskflow" "$dir_name" || return 1
    cd "$dir_name"

    # Replace Manjaro with EndeavourOS in config.yaml
    replace_manjaro_with_endeavouros "$PWD"

    ./scripts/install_deps.sh
    cmake -B build
    cmake --build build -j8
    ./build/bin/unittests
    ./build/bin/integtests
    ./scripts/package.py

    cd dist || exit 1
    local package=$(ls | head -n 1)
    
    case "${package##*.}" in
        deb)
            check_and_install "$package" "sudo apt install -y './$package'"
            ;;
        rpm)
            check_and_install "$package" "sudo dnf install -y './$package' || sudo rpm -ivh './$package'"
            ;;
        pkg.tar.zst)
            check_and_install "$package" "sudo pacman -U --noconfirm './$package'"
            ;;
        *)
            echo "Unknown package type. Package: $package"
            ;;
    esac

    cd ..
}
# Main script execution
confirm "This script will install various packages on your system. Do you want to continue?" || exit 1

# Detect the Linux distribution
detect_distro
echo "Detected distribution: $DISTRO"

# Install packages based on distribution
case "$DISTRO" in
    debian|ubuntu)
        sudo apt update
        check_and_install "vlc" "sudo apt install -y vlc"
        check_and_install "gnome-software" "sudo apt install -y gnome-software"
        check_and_install "gnome-shell-extensions" "sudo apt install -y gnome-shell-extensions"
        check_and_install "gnome-tweaks" "sudo apt install -y gnome-tweaks"
        check_and_install "git" "sudo apt install -y git"
        check_and_install "ffmpeg" "sudo apt install -y ffmpeg"
        ;;
    arch)
        sudo pacman -Syu
        check_and_install "vlc" "sudo pacman -S --noconfirm vlc"
        check_and_install "gnome-software" "sudo pacman -S --noconfirm gnome-software"
        check_and_install "gnome-shell-extensions" "sudo pacman -S --noconfirm gnome-shell-extensions"
        check_and_install "gnome-tweaks" "sudo pacman -S --noconfirm gnome-tweaks"
        check_and_install "git" "sudo pacman -S --noconfirm git"
        check_and_install "ffmpeg" "sudo pacman -S --noconfirm ffmpeg"
        ;;
    fedora|rhel)
        sudo dnf update
        check_and_install "vlc" "sudo dnf install -y vlc"
        check_and_install "gnome-software" "sudo dnf install -y gnome-software"
        check_and_install "gnome-shell-extensions" "sudo dnf install -y gnome-shell-extensions"
        check_and_install "gnome-tweaks" "sudo dnf install -y gnome-tweaks"
        check_and_install "git" "sudo dnf install -y git"
        check_and_install "ffmpeg" "sudo dnf install -y ffmpeg"
        ;;
    *)
        echo "Unsupported distribution."
        exit 1
        ;;
esac

# Install external software
install_external_software

# Install WhiteSur theme and icons
install_whitesur_theme

# Install WhiteSur Icon Theme
install_whitesur_icon_theme

# Build and install Deskflow
build_and_install_deskflow

echo "All tasks completed."
