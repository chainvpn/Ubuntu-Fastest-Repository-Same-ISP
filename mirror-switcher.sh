#!/bin/bash

# Ubuntu Fastest Repository Selector with ISP Preference
# Author: @infoshayan — https://github.com/chainvpn/Ubuntu-Fastest-Repository-Same-ISP

# === Config ===
ISP_NAME="Shatel"
ISP_DOMAIN="ubuntu.mirror.shatel.ir"
ISP_URL="http://${ISP_DOMAIN}/ubuntu"
LOG_FILE="/var/log/mirror-switcher.log"

# === Colors ===
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD=$(tput bold)
RESET=$(tput sgr0)

# === Functions ===

progress_bar() {
    local duration=${1:-2}
    local msg=${2:-""}
    echo -ne "${YELLOW}${msg}${NC} "
    echo -ne "["
    for i in $(seq 1 20); do
        echo -ne "#"
        sleep $(bc -l <<< "$duration/20")
    done
    echo -e "] ✔"
}

log() {
    echo -e "$(date '+%F %T') | $1" >> "$LOG_FILE"
}

fatal() {
    echo -e "${RED}[✘] $1${NC}"
    log "[FATAL] $1"
    exit 1
}

banner() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔═════════════════════════════════════════════════════╗"
    echo "║      🧠 Ubuntu Fast Mirror Switcher (Pro)           ║"
    echo "╚═════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# === Start Script ===
banner
log "Started mirror-switcher"

UBUNTU_CODENAME=$(lsb_release -cs)
COUNTRY=$(curl -s https://ipinfo.io/country || echo "US")

echo -e "[*] Detected Ubuntu Codename: ${BOLD}${UBUNTU_CODENAME}${RESET}"
progress_bar 0.5 "Checking Ubuntu version"

echo -e "[*] Your Country: ${BOLD}${COUNTRY}${RESET}"
progress_bar 0.5 "Getting Geo Info"

echo -e "[*] Trying ISP Mirror (${ISP_NAME}) at ${BOLD}${ISP_URL}${RESET}"
progress_bar 1 "Testing ISP mirror"

if curl -s --head --request GET "${ISP_URL}/dists/${UBUNTU_CODENAME}/Release" | grep "200 OK" > /dev/null; then
    echo -e "${GREEN}[✔] ISP Mirror is available!${NC}"
    log "Using ISP mirror $ISP_URL"
    REPO_URL="$ISP_URL"
else
    echo -e "${YELLOW}[!] ISP Mirror not available. Finding fastest mirror...${NC}"
    progress_bar 1 "Installing netselect-apt"

    sudo apt update > /dev/null
    sudo apt install -y netselect-apt > /dev/null || fatal "Could not install netselect-apt"

    sudo netselect-apt -c "$COUNTRY" -n "$UBUNTU_CODENAME"
    [ ! -f sources.list ] && fatal "netselect-apt failed to generate sources.list"

    sudo cp sources.list /etc/apt/sources.list
    echo -e "${GREEN}[✔] Fastest mirror set via netselect-apt${NC}"
    log "Used fastest mirror via netselect-apt"
    sudo apt update
    exit 0
fi

# === Update sources.list with selected mirror ===
echo -e "[*] Applying new mirror to sources.list"
progress_bar 1 "Writing to sources.list"

cat <<EOF | sudo tee /etc/apt/sources.list >/dev/null
deb ${REPO_URL} ${UBUNTU_CODENAME} main restricted universe multiverse
deb ${REPO_URL} ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb ${REPO_URL} ${UBUNTU_CODENAME}-security main restricted universe multiverse
deb ${REPO_URL} ${UBUNTU_CODENAME}-backports main restricted universe multiverse
EOF

# === Final update ===
echo -e "[*] Updating APT sources..."
progress_bar 2 "apt update"
sudo apt update

echo -e "${GREEN}${BOLD}✅ Done! APT mirror has been updated successfully.${RESET}"
log "Mirror switch complete for $UBUNTU_CODENAME"
