#!/bin/bash

# mirror-switcher.sh — Fast Ubuntu Mirror Selector with ISP Preference
# Author: @infoshayan (edit if desired)
# Description: Uses your ISP's mirror if available; otherwise finds the fastest mirror based on your country

# Colors
GREEN='\033[0;32m'
NC='\033[0m'
BOLD=$(tput bold)
RESET=$(tput sgr0)

# Fancy header
clear
echo -e "${GREEN}${BOLD}"
echo "╔════════════════════════════════════════════╗"
echo "║        🧠 Ubuntu Fast Mirror Switcher      ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${RESET}"

# Animated progress bar
progress_bar() {
    local duration=${1:-3}
    local spin='|/-\\'
    echo -n "[*] Working: "
    for ((i=0; i<duration*10; i++)); do
        i=$((i % 4))
        printf "\b${spin:$i:1}"
        sleep 0.1
    done
    echo -e "\b✔"
}

# Get Ubuntu codename
UBUNTU_CODENAME=$(lsb_release -cs)
echo -e "[+] Detected Ubuntu version: ${BOLD}$UBUNTU_CODENAME${RESET}"
progress_bar 1

# Get country code
COUNTRY=$(curl -s https://ipinfo.io/country)
echo -e "[+] Your country: ${BOLD}$COUNTRY${RESET}"
progress_bar 1

# Set ISP info
ISP_NAME="Shatel"
ISP_DOMAIN="ubuntu.mirror.shatel.ir"
ISP_REPO="http://${ISP_DOMAIN}/ubuntu"

echo -e "[*] Checking for ISP mirror: ${BOLD}$ISP_REPO${RESET}"
progress_bar 2

if ping -c 1 -W 1 $ISP_DOMAIN &>/dev/null; then
    echo -e "[✔] Found mirror at ${BOLD}$ISP_DOMAIN${RESET}. Using it..."
    REPO_URL=$ISP_REPO
else
    echo -e "[✘] ISP mirror not found. Finding fastest global mirror..."
    if ! command -v netselect-apt &>/dev/null; then
        echo -e "[*] Installing netselect-apt..."
        sudo apt update && sudo apt install netselect-apt -y
    fi

    sudo netselect-apt -c "$COUNTRY" -n "$UBUNTU_CODENAME"
    if [ -f sources.list ]; then
        echo -e "[✔] Fastest mirror found and saved to sources.list"
        sudo cp sources.list /etc/apt/sources.list
        sudo apt update
        exit 0
    else
        echo -e "[✘] netselect-apt failed. Exiting."
        exit 1
    fi
fi

# Create sources.list using ISP or custom mirror
echo -e "[*] Replacing sources.list with: ${BOLD}$REPO_URL${RESET}"
progress_bar 2

cat <<EOF | sudo tee /etc/apt/sources.list >/dev/null
deb $REPO_URL $UBUNTU_CODENAME main restricted universe multiverse
deb $REPO_URL $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPO_URL $UBUNTU_CODENAME-backports main restricted universe multiverse
deb $REPO_URL $UBUNTU_CODENAME-security main restricted universe multiverse
EOF

# Final update
echo -e "[*] Updating package lists from new mirror..."
sudo apt update
echo -e "${GREEN}${BOLD}✅ Mirror switch complete! Your APT is now turbocharged. 🛰️${RESET}"
