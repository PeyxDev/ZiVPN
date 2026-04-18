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
echo -e "${CYAN}API Port: ${ZIVPN_API_PORT}${RESET}"
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
echo -e "${BOLD}         API Configuration${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  ${YELLOW}1)${RESET} Install API (REST API untuk manajemen user)"
echo -e "  ${YELLOW}2)${RESET} Skip API (Tanpa API - hanya CLI manager)"
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
    
    # Update config.json with API port
    sed -i "s/\"listen\": \":${ZIVPN_PORT}\"/\"listen\": \":${ZIVPN_PORT}\",\n    \"api_port\": ${ZIVPN_API_PORT}/" $ZIVPN_DIR/config.json
    
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
    
    echo ""
    echo -e "${GREEN}✅ API installed!${RESET}"
    echo -e "  ${CYAN}Port : ${ZIVPN_API_PORT}${RESET}"
    echo -e "  ${CYAN}Key  : ${API_KEY}${RESET}"
fi

# ==================== CREATE MENU MANAGER ====================
cat > /usr/local/bin/m-zivpn << 'MENUEOF'
#!/bin/bash

REDBLD="\033[0m\033[91;1m"
Green="\e[92;1m"
RED="\033[1;31m"
YELLOW="\033[33;1m"
BLUE="\033[36;1m"
FONT="\033[0m"
NC='\e[0m'
CYAN="\033[96;1m"
WHITE="\033[97;1m"

ZIVPN_CONFIG="/etc/zivpn/config.json"
ZIVPN_USERS="/etc/zivpn/users.json"
ZIVPN_DOMAIN="/etc/zivpn/domain"
ZIVPN_PORT="5667"

MYIP=$(curl -sS ipv4.icanhazip.com)
domain=$(cat /etc/xray/domain 2>/dev/null || cat $ZIVPN_DOMAIN 2>/dev/null || echo "Tidak ada")

function check_status() {
    if systemctl is-active --quiet zivpn 2>/dev/null; then
        echo -e "${Green}ON${NC}"
    elif pgrep -x "zivpn" > /dev/null; then
        echo -e "${Green}ON${NC}"
    else
        echo -e "${RED}OFF${NC}"
    fi
}

function get_total() {
    cat "$ZIVPN_USERS" 2>/dev/null | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0"
}

function get_active() {
    cat "$ZIVPN_USERS" 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); today='$(date +%Y-%m-%d)'; print(len([x for x in data if x.get('status') == 'active' and x.get('expired', '') >= today]))" 2>/dev/null || echo "0"
}

banner() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE}              ZIVPN MANAGER MENU                ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

info() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE} DOMAIN    : ${domain}${NC}"
    echo -e "${BLUE}│${WHITE} IP VPS    : ${MYIP}${NC}"
    echo -e "${BLUE}│${WHITE} PORT      : ${ZIVPN_PORT}${NC}"
    echo -e "${BLUE}│${WHITE} STATUS    : $(check_status)${NC}"
    echo -e "${BLUE}│${WHITE} USERS     : $(get_total) total, $(get_active) active${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

menu() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│  ${WHITE}1.${NC})${Green} Create User         ${BLUE}  5.${NC})${Green} View Config${RESET}        ${BLUE}│${NC}"
    echo -e "${BLUE}│  ${WHITE}2.${NC})${Green} Delete User         ${BLUE}  6.${NC})${Green} Change Domain${RESET}      ${BLUE}│${NC}"
    echo -e "${BLUE}│  ${WHITE}3.${NC})${Green} Renew User          ${BLUE}  7.${NC})${Green} Restart Service${RESET}    ${BLUE}│${NC}"
    echo -e "${BLUE}│  ${WHITE}4.${NC})${Green} List Users          ${BLUE}  8.${NC})${Green} Service Status${RESET}    ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo -e "${BLUE}  ┌───────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │  ${RED}x.${NC})${RED} Exit / Back to Main Menu${NC}                               ${BLUE}│${NC}"
    echo -e "${BLUE}  └───────────────────────────────────────────────┘${NC}"
}

create() {
    echo ""
    read -p "   Password : " password
    read -p "   Days     : " days
    read -p "   IP Limit : " iplimit
    [[ -z "$password" || -z "$days" ]] && echo -e "${RED}   Required!${RESET}" && sleep 2 && return
    exp_date=$(date -d "+$days days" +%Y-%m-%d)
    python3 << PYTHON
import json
with open("$ZIVPN_CONFIG", "r") as f: c=json.load(f)
if "$password" not in c["auth"]["config"]: c["auth"]["config"].append("$password")
with open("$ZIVPN_CONFIG", "w") as f: json.dump(c, f, indent=4)
u=[]; exec(open("$ZIVPN_USERS").read() if __import__("os").path.exists("$ZIVPN_USERS") else "")
with open("$ZIVPN_USERS", "r") as f: u=json.load(f)
u.append({"password":"$password","expired":"$exp_date","ip_limit":${iplimit:-0},"status":"active"})
with open("$ZIVPN_USERS", "w") as f: json.dump(u, f, indent=4)
PYTHON
    echo -e "${Green}   ✅ Created: $password (exp: $exp_date)${RESET}"
    systemctl restart zivpn 2>/dev/null; sleep 2
}

delete() {
    echo ""; read -p "   Password : " password
    python3 << PYTHON
import json
with open("$ZIVPN_CONFIG", "r") as f: c=json.load(f)
if "$password" in c["auth"]["config"]: c["auth"]["config"].remove("$password")
with open("$ZIVPN_CONFIG", "w") as f: json.dump(c, f, indent=4)
with open("$ZIVPN_USERS", "r") as f: u=json.load(f)
u=[x for x in u if x.get("password")!="$password"]
with open("$ZIVPN_USERS", "w") as f: json.dump(u, f, indent=4)
PYTHON
    echo -e "${Green}   ✅ Deleted: $password${RESET}"
    systemctl restart zivpn 2>/dev/null; sleep 2
}

renew() {
    echo ""; read -p "   Password : " password; read -p "   Add days : " days
    python3 << PYTHON
import json, datetime
with open("$ZIVPN_USERS", "r") as f: u=json.load(f)
for x in u:
    if x.get("password")=="$password":
        exp=x.get("expired",datetime.datetime.now().strftime("%Y-%m-%d"))
        ne=(datetime.datetime.strptime(exp,"%Y-%m-%d")+datetime.timedelta(days=$days)).strftime("%Y-%m-%d")
        x["expired"]=ne; x["status"]="active"
with open("$ZIVPN_USERS", "w") as f: json.dump(u, f, indent=4)
with open("$ZIVPN_CONFIG", "r") as f: c=json.load(f)
if "$password" not in c["auth"]["config"]: c["auth"]["config"].append("$password")
with open("$ZIVPN_CONFIG", "w") as f: json.dump(c, f, indent=4)
PYTHON
    echo -e "${Green}   ✅ Renewed: $password${RESET}"
    systemctl restart zivpn 2>/dev/null; sleep 2
}

list() {
    echo ""; echo -e "${CYAN}   User List:${RESET}"
    python3 << PYTHON
import json, datetime
t=datetime.datetime.now().strftime("%Y-%m-%d")
with open("$ZIVPN_USERS", "r") as f: u=json.load(f)
if not u: print("   No users")
else:
    print(f"   {'Username':<15} {'Expired':<12} {'Status':<10}")
    print("   " + "-"*40)
    for x in u:
        s="active"
        if x.get("expired","")<t: s="expired"
        print(f"   {x.get('password','-')[:15]:<15} {x.get('expired','-'):<12} {s:<10}")
PYTHON
    echo ""; read -p "   Press Enter..."
}

view() { echo ""; cat $ZIVPN_CONFIG | python3 -m json.tool 2>/dev/null || cat $ZIVPN_CONFIG; echo ""; read -p "   Press Enter..."; }
changedomain() {
    current=$(cat $ZIVPN_DOMAIN 2>/dev/null)
    echo ""; echo -e "   Current: ${CYAN}$current${RESET}"; read -p "   New domain: " nd
    [[ -n "$nd" ]] && echo "$nd" > $ZIVPN_DOMAIN && openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/CN=$nd" -keyout /etc/zivpn/zivpn.key -out /etc/zivpn/zivpn.crt 2>/dev/null && systemctl restart zivpn && echo -e "${Green}   ✅ Domain updated${RESET}"
    sleep 2
}
restart() { echo ""; systemctl restart zivpn 2>/dev/null; pkill -x zivpn 2>/dev/null; sleep 1; systemctl start zivpn 2>/dev/null || nohup /usr/local/bin/zivpn server -c $ZIVPN_CONFIG >/dev/null 2>&1 &; echo -e "${Green}   ✅ Restarted${RESET}"; sleep 2; }
status() { echo ""; systemctl status zivpn --no-pager -l 2>/dev/null | head -15; echo ""; read -p "   Press Enter..."; }

main() {
    while true; do banner; info; menu; echo ""; read -p "   Select [1-8/x] : " c
        case $c in 1) create;; 2) delete;; 3) renew;; 4) list;; 5) view;; 6) changedomain;; 7) restart;; 8) status;; x|X) menu;; *) echo -e "${RED}   Invalid${RESET}"; sleep 1;; esac
    done
}
main
MENUEOF

chmod +x /usr/local/bin/m-zivpn

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