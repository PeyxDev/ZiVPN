#!/bin/bash

# ==================== COLOR ====================
REDBLD="\033[0m\033[91;1m"
Green="\e[92;1m"
RED="\033[1;31m"
YELLOW="\033[33;1m"
BLUE="\033[36;1m"
FONT="\033[0m"
GREENBG="\033[42;37m"
REDBG="\033[41;37m"
NC='\e[0m'
CYAN="\033[96;1m"
WHITE="\033[97;1m"
BOLD="\033[1m"
GRAY="\033[1;30m"

# ==================== VARIABLES ====================
ZIVPN_PORT="5667"
ZIVPN_API_PORT="8585"
ZIVPN_DIR="/etc/zivpn"
GITHUB_REPO="https://raw.githubusercontent.com/PeyxDev/ZiVPN/main"

# ==================== FUNCTIONS ====================
function print_banner() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE}  \033[38;5;196m⁙\033[38;5;202m⁙\033[38;5;208m⁙\033[38;5;214m⁙\033[38;5;220m⁙\033[38;5;226m⁙\033[38;5;190m⁙\033[38;5;154m⁙\033[38;5;118m⁙\033[38;5;82m⁙\033[38;5;46m⁙\033[38;5;47m⁙\033[38;5;48m⁙\033[38;5;49m⁙${WHITE} ZIVPN UDP TUNNEL \033[38;5;87m⁙\033[38;5;86m⁙\033[38;5;85m⁙\033[38;5;84m⁙\033[38;5;83m⁙\033[38;5;44m⁙\033[38;5;43m⁙\033[38;5;42m⁙\033[38;5;41m⁙\033[38;5;40m⁙\033[38;5;39m⁙\033[38;5;38m⁙\033[38;5;37m⁙\033[38;5;36m⁙${WHITE}   ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo -e "${GRAY}                   PeyxDev Edition${NC}"
    echo ""
}

function print_task() {
    echo -ne "${GRAY}•${RESET} $1..."
}

function print_done() {
    echo -e "\r${Green}✓${RESET} $1      "
}

function print_fail() {
    echo -e "\r${RED}✗${RESET} $1      "
    exit 1
}

function run_silent() {
    local msg="$1"
    local cmd="$2"
    print_task "$msg"
    bash -c "$cmd" &>/tmp/zivpn_install.log
    if [ $? -eq 0 ]; then
        print_done "$msg"
    else
        print_fail "$msg"
    fi
}

# ==================== START INSTALLATION ====================
print_banner

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root!${RESET}"
    exit 1
fi

# Check system
if [[ "$(uname -s)" != "Linux" ]] || [[ "$(uname -m)" != "x86_64" ]]; then
    print_fail "System not supported (Linux AMD64 only)"
fi

# Stop existing services
systemctl stop zivpn zivpn-api 2>/dev/null
pkill -x zivpn 2>/dev/null

# Update system
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         System Update & Dependencies${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

run_silent "Updating system" "apt-get update -y"
run_silent "Installing dependencies" "apt-get install -y wget curl openssl python3 jq ufw net-tools"

# Domain input
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         Domain Configuration${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

while true; do
    read -p "   Enter Domain (e.g., vpn.pxstore.web.id): " domain
    if [[ -n "$domain" ]]; then
        break
    fi
done

echo ""
echo -e "${CYAN}   UDP Port: ${ZIVPN_PORT}${NC}"
echo ""

# Pilihan Install
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         Installation Type${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "   ${YELLOW}1)${RESET} Install with API (REST API + CLI Menu)"
echo -e "   ${YELLOW}2)${RESET} Install CLI Only (Menu Manager only)"
echo ""
read -p "   Choose option [1-2]: " install_type

# Download core
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         Installing ZiVPN Core${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

run_silent "Downloading ZiVPN Core" "wget -q https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn && chmod +x /usr/local/bin/zivpn"

# Create directory
mkdir -p $ZIVPN_DIR

# Save domain
echo "$domain" > $ZIVPN_DIR/domain

# Download config.json from repo
run_silent "Downloading config.json" "wget -q ${GITHUB_REPO}/config.json -O $ZIVPN_DIR/config.json"

# Update config.json with domain
sed -i "s/\"cert\":.*/\"cert\": \"\/etc\/zivpn\/zivpn.crt\",/" $ZIVPN_DIR/config.json
sed -i "s/\"key\":.*/\"key\": \"\/etc\/zivpn\/zivpn.key\",/" $ZIVPN_DIR/config.json
sed -i "s/:5667/:${ZIVPN_PORT}/" $ZIVPN_DIR/config.json

# Generate SSL certificate
run_silent "Generating SSL Certificate" "openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj '/CN=$domain' -keyout $ZIVPN_DIR/zivpn.key -out $ZIVPN_DIR/zivpn.crt 2>/dev/null"

# Create users database
echo "[]" > $ZIVPN_DIR/users.json

# Create systemd service
cat > /etc/systemd/system/zivpn.service << 'EOF'
[Unit]
Description=ZiVPN UDP VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Install API if chosen
if [[ "$install_type" == "1" ]]; then
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}         Installing API Service${RESET}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    
    # Generate API Key
    API_KEY=$(openssl rand -hex 16)
    echo "$API_KEY" > $ZIVPN_DIR/apikey
    
    # Install Go if not exists
    if ! command -v go &> /dev/null; then
        run_silent "Installing Golang" "apt-get install -y golang"
    fi
    
    # Download and build API
    run_silent "Downloading API Source" "wget -q ${GITHUB_REPO}/zivpn-api.go -O $ZIVPN_DIR/api.go"
    
    cd $ZIVPN_DIR
    run_silent "Compiling API" "go build -o zivpn-api api.go 2>/dev/null"
    
    # Create API service
    cat > /etc/systemd/system/zivpn-api.service << 'EOF'
[Unit]
Description=ZiVPN API Service
After=network.target zivpn.service

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/etc/zivpn/zivpn-api
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    # Firewall API port
    ufw allow ${ZIVPN_API_PORT}/tcp 2>/dev/null
fi

# Download menu manager
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         Installing Menu Manager${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

run_silent "Downloading Menu Manager" "wget -q ${GITHUB_REPO}/menu.sh -O /usr/local/sbin/m-zivpn && chmod +x /usr/local/sbin/m-zivpn"
sed -i 's/\r$//' /usr/local/sbin/m-zivpn

# Firewall
ufw allow ${ZIVPN_PORT}/udp 2>/dev/null
ufw allow ${ZIVPN_PORT}/tcp 2>/dev/null

# Start services
systemctl daemon-reload
systemctl enable zivpn
systemctl start zivpn

if [[ "$install_type" == "1" ]]; then
    systemctl enable zivpn-api
    systemctl start zivpn-api
fi

# Alias
echo "alias m-zivpn='bash /usr/local/sbin/m-zivpn'" >> /root/.bashrc
source ~/.bashrc 2>/dev/null

# Cleanup
rm -f /tmp/zivpn_install.log

# Done
clear
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${Green}              INSTALLATION COMPLETE!${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "${CYAN}  Domain      : ${domain}${RESET}"
echo -e "${CYAN}  UDP Port    : ${ZIVPN_PORT}${RESET}"

if [[ "$install_type" == "1" ]]; then
    echo -e "${CYAN}  API Port    : ${ZIVPN_API_PORT}${RESET}"
    echo -e "${CYAN}  API Key     : ${API_KEY}${RESET}"
fi

echo -e "${CYAN}  Config      : $ZIVPN_DIR/config.json${RESET}"
echo -e "${CYAN}  Users DB    : $ZIVPN_DIR/users.json${RESET}"
echo ""
echo -e "${BOLD}  Menu Manager:${RESET}"
echo -e "    ${Green}m-zivpn${RESET}"
echo ""
echo -e "${BOLD}  Commands:${RESET}"
echo -e "    ${YELLOW}systemctl start/stop/restart zivpn${RESET}"

if [[ "$install_type" == "1" ]]; then
    echo -e "    ${YELLOW}systemctl start/stop/restart zivpn-api${RESET}"
fi

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GRAY}  Telegram : https://t.me/PeyxDev${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Run menu
bash /usr/local/sbin/m-zivpn