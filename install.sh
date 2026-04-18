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
systemctl stop zivpn 2>/dev/null
pkill -x zivpn 2>/dev/null

# Update system
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         System Update & Dependencies${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

run_silent "Updating system" "apt-get update -y"
run_silent "Installing dependencies" "apt-get install -y wget curl openssl python3 jq ufw"

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

# Download core
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         Installing ZiVPN Core${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

run_silent "Downloading ZiVPN Core" "wget -q https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn && chmod +x /usr/local/bin/zivpn"

# Create configuration
mkdir -p $ZIVPN_DIR
echo "$domain" > $ZIVPN_DIR/domain

cat > $ZIVPN_DIR/config.json << 'EOF'
{
    "listen": ":5667",
    "cert": "/etc/zivpn/zivpn.crt",
    "key": "/etc/zivpn/zivpn.key",
    "obfs": "http",
    "auth": {
        "mode": "password",
        "config": []
    }
}
EOF

run_silent "Generating SSL Certificate" "openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj '/CN=$domain' -keyout $ZIVPN_DIR/zivpn.key -out $ZIVPN_DIR/zivpn.crt 2>/dev/null"

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

# Download menu manager
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         Installing Menu Manager${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

run_silent "Downloading Menu Manager" "wget -q ${GITHUB_REPO}/menu.sh -O /usr/local/sbin/m-zivpn && chmod +x /usr/local/sbin/m-zivpn"

# Firewall
ufw allow ${ZIVPN_PORT}/udp 2>/dev/null
ufw allow ${ZIVPN_PORT}/tcp 2>/dev/null

# Start services
systemctl daemon-reload
systemctl enable zivpn
systemctl start zivpn

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
echo -e "${CYAN}  Config      : $ZIVPN_DIR/config.json${RESET}"
echo -e "${CYAN}  Users DB    : $ZIVPN_DIR/users.json${RESET}"
echo ""
echo -e "${BOLD}  Menu Manager:${RESET}"
echo -e "    ${Green}m-zivpn${RESET}"
echo ""
echo -e "${BOLD}  Commands:${RESET}"
echo -e "    ${YELLOW}systemctl start/stop/restart zivpn${RESET}"
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GRAY}  Telegram : https://t.me/PeyxDev${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Run menu
bash /usr/local/sbin/m-zivpn