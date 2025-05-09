#!/bin/bash
# Ubuntu Fast Mirror Switcher by @infoshayan

LOG_FILE="/var/log/mirror-switcher.log"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
BOLD=$(tput bold); RESET=$(tput sgr0)

# Install required tools if not already installed
install_requirements() {
    echo -e "${YELLOW}[*] Installing required tools...${NC}"
    sudo apt update
    sudo apt install -y curl jq
}

# Progress bar function
progress_bar() {
    local d=${1:-2}; local msg=${2:-""}; 
    echo -ne "${YELLOW}${msg}${NC} [";
    for i in $(seq 1 20); do echo -ne "#"; sleep $(bc -l <<< "$d/20"); done;
    echo "] ✔"
}

# Log function
log() {
    echo -e "$(date '+%F %T') | $1" >> "$LOG_FILE"
}

# Fatal error function
fatal() {
    echo -e "${RED}[✘] $1${NC}"
    log "[FATAL] $1"
    exit 1
}

# Banner function
banner() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔═════════════════════════════════════════════════════╗"
    echo "║      🧠 Ubuntu Fast Mirror Switcher (Pro)           ║"
    echo "╚═════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check country using ipinfo.io API
get_country_code() {
    COUNTRY_CODE=$(curl -s http://ipinfo.io/country)
    echo $COUNTRY_CODE
}

# Get the list of mirrors from Launchpad
get_launchpad_mirrors() {
    echo -e "${YELLOW}[*] Fetching the list of Ubuntu mirrors from Launchpad...${NC}"
    MIRRORS=$(curl -s https://launchpad.net/ubuntu/+archivemirrors | grep -oP 'href="\K(https://[^\"]+ubuntu\+archive[^\"]+)"' | sort | uniq)
    echo "$MIRRORS"
}

# Get mirror speed by downloading a test file
check_speed_and_find_best_mirror() {
    echo -e "${YELLOW}[*] Testing mirrors for download speed...${NC}"
    BEST_MIRROR=""
    BEST_SPEED=0
    TEST_FILE="ubuntu/dists/$(lsb_release -cs)/Release"

    for MIRROR in $MIRRORS; do
        echo -e "${YELLOW}[*] Testing mirror: $MIRROR${NC}"
        
        # Perform a speed test using curl
        START_TIME=$(date +%s)
        DOWNLOAD_SPEED=$(curl -s -w "%{speed_download}" -o /dev/null "$MIRROR/$TEST_FILE")
        END_TIME=$(date +%s)
        TIME_TAKEN=$((END_TIME - START_TIME))

        if (( $(echo "$DOWNLOAD_SPEED > $BEST_SPEED" | bc -l) )); then
            BEST_SPEED=$DOWNLOAD_SPEED
            BEST_MIRROR=$MIRROR
        fi
    done

    echo -e "${GREEN}[✔] Best mirror selected: $BEST_MIRROR${NC}"
    echo -e "${GREEN}[✔] Download speed: $BEST_SPEED B/s, Time taken: $TIME_TAKEN s${NC}"
    
    # Return the best mirror
    echo "$BEST_MIRROR"
}

# Main script execution
banner

# Ask user if they want to install required dependencies
echo -e "${YELLOW}[*] This script requires curl and jq. Press 2 to install dependencies.${NC}"
read -p "Press 2 to install required dependencies or any other key to continue without installing: " INSTALL_OPTION

if [ "$INSTALL_OPTION" == "2" ]; then
    install_requirements
else
    echo -e "${YELLOW}[*] Skipping installation of dependencies.${NC}"
fi

# Get Ubuntu codename
UBUNTU_CODENAME=$(lsb_release -cs)

# Get list of available mirrors from Launchpad
MIRRORS=$(get_launchpad_mirrors)

# Check speed and find the best mirror
REPO_URL=$(check_speed_and_find_best_mirror)

# Apply the best mirror to sources.list
echo -e "[*] Applying the best mirror to sources.list"
progress_bar 1 "Writing to sources.list"

cat <<EOF | sudo tee /etc/apt/sources.list >/dev/null
deb ${REPO_URL} ${UBUNTU_CODENAME} main restricted universe multiverse
deb ${REPO_URL} ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb ${REPO_URL} ${UBUNTU_CODENAME}-security main restricted universe multiverse
deb ${REPO_URL} ${UBUNTU_CODENAME}-backports main restricted universe multiverse
EOF

echo -e "[*] Updating APT sources..."
progress_bar 2 "apt update"
sudo apt update

echo -e "${GREEN}${BOLD}✅ Done! APT mirror has been updated successfully.${RESET}"
log "Mirror switch complete for $UBUNTU_CODENAME"
