cat > install.sh << 'EOF'
#!/bin/bash

# ==================== COLOR ====================
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
BLUE="\033[1;34m"
RESET="\033[0m"
BOLD="\033[1m"
GRAY="\033[1;30m"

# ==================== VARIABLES ====================
ZIVPN_PORT="5667"
ZIVPN_API_PORT="8585"
ZIVPN_DIR="/etc/zivpn"
GITHUB_REPO="https://raw.githubusercontent.com/PeyxDev/ZiVPN/main"

# ==================== FUNCTIONS ====================
print_banner() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${RESET}"
    echo -e "${BLUE}│${WHITE}  \033[38;5;196m⁙\033[38;5;202m⁙\033[38;5;208m⁙\033[38;5;214m⁙\033[38;5;220m⁙\033[38;5;226m⁙\033[38;5;190m⁙\033[38;5;154m⁙\033[38;5;118m⁙\033[38;5;82m⁙\033[38;5;46m⁙\033[38;5;47m⁙\033[38;5;48m⁙\033[38;5;49m⁙${WHITE} ZIVPN UDP TUNNEL \033[38;5;87m⁙\033[38;5;86m⁙\033[38;5;85m⁙\033[38;5;84m⁙\033[38;5;83m⁙\033[38;5;44m⁙\033[38;5;43m⁙\033[38;5;42m⁙\033[38;5;41m⁙\033[38;5;40m⁙\033[38;5;39m⁙\033[38;5;38m⁙\033[38;5;37m⁙\033[38;5;36m⁙${WHITE}   ${BLUE}│${RESET}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${RESET}"
    echo -e "${GRAY}                   PeyxDev Edition${RESET}"
    echo ""
}

print_task() {
    echo -ne "${GRAY}•${RESET} $1..."
}

print_done() {
    echo -e "\r${GREEN}✓${RESET} $1      "
}

print_fail() {
    echo -e "\r${RED}✗${RESET} $1      "
    exit 1
}

run_silent() {
    local msg="$1"
    local cmd="$2"
    print_task "$msg"
    bash -c "$cmd" &>/tmp/zivpn_install.log
    if [ $? -eq 0 ]; then
        print_done "$msg"
    else
        print_fail "$msg (Check /tmp/zivpn_install.log)"
    fi
}

# ==================== CHECK SYSTEM ====================
print_banner

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root!${RESET}"
    exit 1
fi

if [[ "$(uname -s)" != "Linux" ]] || [[ "$(uname -m)" != "x86_64" ]]; then
    print_fail "System not supported (Linux AMD64 only)"
fi

# Stop existing services
systemctl stop zivpn zivpn-api zivpn-bot 2>/dev/null
pkill -x zivpn 2>/dev/null

# ==================== UPDATE SYSTEM ====================
run_silent "Updating system" "apt-get update -y"

# ==================== INSTALL DEPENDENCIES ====================
run_silent "Installing dependencies" "apt-get install -y wget curl openssl python3 jq ufw"

# ==================== DOMAIN INPUT ====================
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         Domain Configuration${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

while true; do
    read -p "Enter Domain (e.g., vpn.pxstore.web.id): " domain
    if [[ -n "$domain" ]]; then
        break
    fi
done

echo ""
echo -e "${CYAN}UDP Port: ${ZIVPN_PORT}${RESET}"
echo -e "${CYAN}API Port: ${ZIVPN_API_PORT} (optional)${RESET}"
echo ""

# ==================== INSTALL ZIVPN CORE ====================
run_silent "Downloading ZiVPN Core" "wget -q https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn && chmod +x /usr/local/bin/zivpn"

# ==================== CREATE CONFIGURATION ====================
mkdir -p $ZIVPN_DIR

# Save domain
echo "$domain" > $ZIVPN_DIR/domain

# Create config.json
cat > $ZIVPN_DIR/config.json << EOF
{
    "listen": ":${ZIVPN_PORT}",
    "cert": "$ZIVPN_DIR/zivpn.crt",
    "key": "$ZIVPN_DIR/zivpn.key",
    "obfs": "http",
    "auth": {
        "mode": "password",
        "config": []
    }
}
EOF

# Generate SSL certificate
run_silent "Generating SSL Certificate" "openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj '/C=ID/ST=Jawa Barat/L=Bandung/O=AutoFTbot/CN=$domain' -keyout $ZIVPN_DIR/zivpn.key -out $ZIVPN_DIR/zivpn.crt 2>/dev/null"

# Create users database
echo "[]" > $ZIVPN_DIR/users.json

# ==================== CREATE SYSTEMD SERVICE ====================
cat > /etc/systemd/system/zivpn.service << EOF
[Unit]
Description=ZiVPN UDP VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$ZIVPN_DIR
ExecStart=/usr/local/bin/zivpn server -c $ZIVPN_DIR/config.json
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# ==================== API OPTION ====================
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         API Configuration (Optional)${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  ${YELLOW}1)${RESET} Install API (REST API for user management)"
echo -e "  ${YELLOW}2)${RESET} Skip API (No API - only CLI menu)"
echo ""
read -p "Choose option [1-2]: " install_api

if [[ "$install_api" == "1" ]]; then
    # Generate API Key
    API_KEY=$(openssl rand -hex 16)
    echo "$API_KEY" > $ZIVPN_DIR/apikey
    
    # Download API source
    run_silent "Downloading API Source" "wget -q ${GITHUB_REPO}/zivpn-api.go -O $ZIVPN_DIR/api.go"
    
    # Install Go if not exists
    if ! command -v go &> /dev/null; then
        run_silent "Installing Golang" "apt-get install -y golang"
    fi
    
    # Build API
    cd $ZIVPN_DIR
    run_silent "Compiling API" "go build -o zivpn-api api.go 2>/dev/null"
    
    # Create API service
    cat > /etc/systemd/system/zivpn-api.service << EOF
[Unit]
Description=ZiVPN API Service
After=network.target zivpn.service

[Service]
Type=simple
User=root
WorkingDirectory=$ZIVPN_DIR
ExecStart=$ZIVPN_DIR/zivpn-api
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable zivpn-api
    systemctl start zivpn-api
    
    # Firewall API port
    ufw allow ${ZIVPN_API_PORT}/tcp 2>/dev/null
fi

# ==================== DOWNLOAD MENU MANAGER ====================
run_silent "Downloading Menu Manager" "wget -q ${GITHUB_REPO}/menu.sh -O /usr/local/bin/m-zivpn && chmod +x /usr/local/bin/m-zivpn"

# ==================== FIREWALL ====================
ufw allow ${ZIVPN_PORT}/udp 2>/dev/null
ufw allow ${ZIVPN_PORT}/tcp 2>/dev/null

# ==================== START SERVICES ====================
systemctl daemon-reload
systemctl enable zivpn
systemctl start zivpn

# ==================== ALIAS ====================
echo "alias m-zivpn='bash /usr/local/bin/m-zivpn'" >> /root/.bashrc
source ~/.bashrc 2>/dev/null

# ==================== CLEANUP ====================
rm -f /tmp/zivpn_install.log

# ==================== DONE ====================
clear
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}              INSTALLATION COMPLETE!${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "${CYAN}  Domain      : ${domain}${RESET}"
echo -e "${CYAN}  UDP Port    : ${ZIVPN_PORT}${RESET}"
if [[ "$install_api" == "1" ]]; then
    echo -e "${CYAN}  API Port    : ${ZIVPN_API_PORT}${RESET}"
    echo -e "${CYAN}  API Key     : ${API_KEY}${RESET}"
fi
echo ""
echo -e "${BOLD}  Menu Manager:${RESET}"
echo -e "    ${GREEN}m-zivpn${RESET}"
echo ""
echo -e "${BOLD}  Commands:${RESET}"
echo -e "    ${YELLOW}systemctl start/stop/restart zivpn${RESET}"
if [[ "$install_api" == "1" ]]; then
    echo -e "    ${YELLOW}systemctl start/stop/restart zivpn-api${RESET}"
fi
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GRAY}  Telegram : https://t.me/PeyxDev${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# Run menu
m-zivpn
EOF

chmod +x install.sh