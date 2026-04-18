#!/bin/bash

# Colors
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
GRAY="\033[1;30m"

# ==================== VARIABLES ====================
ZIVPN_UDP_PORT="5667"
ZIVPN_API_PORT="8585"
GITHUB_REPO="https://raw.githubusercontent.com/PeyxDev/ZiVPN/main"

print_task() {
  echo -ne "${GRAY}•${RESET} $1..."
}

print_done() {
  echo -e "\r${Green}✓${RESET} $1      "
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

# ==================== CEKIP & LISENSI ====================
CEKIP() {
    MYIP=$(curl -sS ipv4.icanhazip.com)
    IPLIST=$(curl -sS https://raw.githubusercontent.com/PeyxDev/esce/main/ipx)
    IPVPS=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $1}')
    LICENSE_USERNAME=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $2}')
    LICENSE_EXPIRED=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $3}')
    LICENSE_KEY=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $4}')
    LICENSE_PACKAGE=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $5}')
    LICENSE_MAX_USERS=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $6}')
    LICENSE_STATUS=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $7}')
    
    if [[ "$MYIP" != "$IPVPS" ]]; then
        clear
        echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
        echo -e "${BLUE}│${RED}              PERMISSION DENIED !${NC}"
        echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
        echo -e "${BLUE}│${NC}"
        echo -e "${BLUE}│${NC}  ${RED}IP Anda tidak terdaftar!${NC}"
        echo -e "${BLUE}│${NC}  ${YELLOW}Silakan hubungi admin untuk izin akses${NC}"
        echo -e "${BLUE}│${NC}"
        echo -e "${BLUE}│${NC}  ${CYAN}Telegram : https://t.me/PeyxDev${NC}"
        echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
        exit 1
    fi
    
    # Cek expired lisensi
    today=$(date -d "0 days" +%Y-%m-%d)
    d1=$(date -d "$LICENSE_EXPIRED" +%s 2>/dev/null)
    d2=$(date -d "$today" +%s)
    
    if [[ -n "$LICENSE_EXPIRED" ]] && [[ $d1 -lt $d2 ]]; then
        clear
        echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
        echo -e "${BLUE}│${RED}              LICENSE EXPIRED !${NC}"
        echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
        echo -e "${BLUE}│${NC}"
        echo -e "${BLUE}│${NC}  ${RED}Lisensi Anda telah expired pada: ${LICENSE_EXPIRED}${NC}"
        echo -e "${BLUE}│${NC}  ${YELLOW}Silakan perpanjang lisensi ke admin${NC}"
        echo -e "${BLUE}│${NC}"
        echo -e "${BLUE}│${NC}  ${CYAN}Telegram : https://t.me/PeyxDev${NC}"
        echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
        exit 1
    fi
    
    # Cek status lisensi
    if [[ "$LICENSE_STATUS" != "active" ]] && [[ -n "$LICENSE_STATUS" ]]; then
        clear
        echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
        echo -e "${BLUE}│${RED}              LICENSE INACTIVE !${NC}"
        echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
        echo -e "${BLUE}│${NC}"
        echo -e "${BLUE}│${NC}  ${RED}Status lisensi: ${LICENSE_STATUS}${NC}"
        echo -e "${BLUE}│${NC}  ${YELLOW}Silakan hubungi admin untuk mengaktifkan lisensi${NC}"
        echo -e "${BLUE}│${NC}"
        echo -e "${BLUE}│${NC}  ${CYAN}Telegram : https://t.me/PeyxDev${NC}"
        echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
        exit 1
    fi
}

function Xwan_Banner() {
clear
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${WHITE}  \033[38;5;196m⁙\033[38;5;202m⁙\033[38;5;208m⁙\033[38;5;214m⁙\033[38;5;220m⁙\033[38;5;226m⁙\033[38;5;190m⁙\033[38;5;154m⁙\033[38;5;118m⁙\033[38;5;82m⁙\033[38;5;46m⁙\033[38;5;47m⁙\033[38;5;48m⁙\033[38;5;49m⁙${WHITE} ZIVPN INSTALLER \033[38;5;87m⁙\033[38;5;86m⁙\033[38;5;85m⁙\033[38;5;84m⁙\033[38;5;83m⁙\033[38;5;44m⁙\033[38;5;43m⁙\033[38;5;42m⁙\033[38;5;41m⁙\033[38;5;40m⁙\033[38;5;39m⁙\033[38;5;38m⁙\033[38;5;37m⁙\033[38;5;36m⁙${WHITE}   ${BLUE}│${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

function License_Info_Install() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${CYAN}              LICENSE INFORMATION${NC}"
    echo -e "${BLUE}├─────────────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│${WHITE}  User Name   : ${YELLOW}${LICENSE_USERNAME:-Unknown}${NC}"
    echo -e "${BLUE}│${WHITE}  License Key : ${CYAN}${LICENSE_KEY}${NC}"
    echo -e "${BLUE}│${WHITE}  Package     : ${GREEN}${LICENSE_PACKAGE}${NC}"
    echo -e "${BLUE}│${WHITE}  Max Users   : ${YELLOW}${LICENSE_MAX_USERS}${NC}"
    echo -e "${BLUE}│${WHITE}  Expired     : ${YELLOW}${LICENSE_EXPIRED:-Lifetime}${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

function Service_System_Operating() {
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${WHITE} SYSTEM OS       : $(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g') ${NC}"
echo -e "${BLUE}│${WHITE} IP VPS          : $(curl -s ipv4.icanhazip.com) ${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

# ==================== MAIN INSTALL ====================
Xwan_Banner
Service_System_Operating
CEKIP
License_Info_Install

if [[ "$(uname -s)" != "Linux" ]] || [[ "$(uname -m)" != "x86_64" ]]; then
  print_fail "System not supported (Linux AMD64 only)"
fi

if [ -f /usr/local/bin/zivpn ]; then
  echo -e "${YELLOW}┌─────────────────────────────────────────────────┐${NC}"
  echo -e "${YELLOW}│  ! ZiVPN detected. Reinstalling...${NC}"
  echo -e "${YELLOW}└─────────────────────────────────────────────────┘${NC}"
  systemctl stop zivpn.service &>/dev/null
  systemctl stop zivpn-api.service &>/dev/null
  systemctl stop zivpn-bot.service &>/dev/null
fi

run_silent "Updating system" "sudo apt-get update -y"

if ! command -v go &> /dev/null; then
  run_silent "Installing dependencies" "sudo apt-get install -y golang git wget curl openssl jq ufw python3"
else
  run_silent "Installing dependencies" "sudo apt-get install -y wget curl openssl jq ufw python3"
fi

echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${CYAN}         Domain Configuration${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""

while true; do
  read -p "   Enter Domain (e.g., vpn.pxstore.web.id): " domain
  if [[ -n "$domain" ]]; then
    break
  fi
done

echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${CYAN}   UDP Port: ${ZIVPN_UDP_PORT}${FONT}"
echo -e "${BLUE}│${CYAN}   API Port: ${ZIVPN_API_PORT}${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""

echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${CYAN}         API Key Configuration${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""

generated_key=$(openssl rand -hex 16)
echo -e "   Generated Key: ${CYAN}$generated_key${NC}"
read -p "   Enter API Key (Press Enter to use generated): " input_key
if [[ -z "$input_key" ]]; then
  api_key="$generated_key"
else
  api_key="$input_key"
fi
echo -e "   Using Key: ${Green}$api_key${NC}"
echo ""

systemctl stop zivpn.service &>/dev/null
run_silent "Downloading Core" "wget -q https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn && chmod +x /usr/local/bin/zivpn"

mkdir -p /etc/zivpn
echo "$domain" > /etc/zivpn/domain
echo "$api_key" > /etc/zivpn/apikey
echo "[]" > /etc/zivpn/users.json

# Simpan informasi lisensi ke file
echo "$LICENSE_USERNAME" > /etc/zivpn/license_user
echo "$LICENSE_KEY" > /etc/zivpn/license_key
echo "$LICENSE_EXPIRED" > /etc/zivpn/license_expired
echo "$LICENSE_PACKAGE" > /etc/zivpn/license_package
echo "$LICENSE_MAX_USERS" > /etc/zivpn/license_max_users

run_silent "Configuring" "wget -q ${GITHUB_REPO}/config.json -O /etc/zivpn/config.json"
sed -i "s/:5667/:${ZIVPN_UDP_PORT}/" /etc/zivpn/config.json

run_silent "Generating SSL" "openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj '/C=ID/ST=Jawa Barat/L=Bandung/O=AutoFTbot/OU=IT Department/CN=$domain' -keyout /etc/zivpn/zivpn.key -out /etc/zivpn/zivpn.crt 2>/dev/null"

# Sysctl optimization
cat >> /etc/sysctl.conf <<END
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.ip_forward=1
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.core.optmem_max=65536
net.core.somaxconn=65535
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_fastopen=3
fs.file-max=1000000
END
sysctl -p &>/dev/null

# Create systemd service for ZiVPN
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=ZIVPN UDP VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
LimitNOFILE=65535
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# Setup API
mkdir -p /etc/zivpn/api
run_silent "Setting up API" "wget -q ${GITHUB_REPO}/zivpn-api.go -O /etc/zivpn/api/zivpn-api.go && wget -q ${GITHUB_REPO}/go.mod -O /etc/zivpn/api/go.mod"

cd /etc/zivpn/api
sed -i "s/Port = \":8080\"/Port = \":${ZIVPN_API_PORT}\"/" zivpn-api.go

if go build -o zivpn-api zivpn-api.go &>/dev/null; then
  print_done "Compiling API"
else
  print_fail "Compiling API"
fi

# Create API service
cat <<EOF > /etc/systemd/system/zivpn-api.service
[Unit]
Description=ZiVPN Golang API Service
After=network.target zivpn.service

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn/api
ExecStart=/etc/zivpn/api/zivpn-api
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Start services
run_silent "Starting Services" "systemctl daemon-reload && systemctl enable zivpn.service && systemctl start zivpn.service && systemctl enable zivpn-api.service && systemctl start zivpn-api.service"

# Firewall rules
iface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
iptables -t nat -A PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :${ZIVPN_UDP_PORT} &>/dev/null
ufw allow 6000:19999/udp &>/dev/null
ufw allow ${ZIVPN_UDP_PORT}/udp &>/dev/null
ufw allow ${ZIVPN_API_PORT}/tcp &>/dev/null

# ==================== DOWNLOAD MENU MANAGER ====================
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${CYAN}         Installing Menu Manager${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""

# Download menu script yang sudah lengkap dengan lisensi
run_silent "Downloading Menu Manager" "wget -q ${GITHUB_REPO}/menu.sh -O /usr/local/bin/menu && chmod +x /usr/local/bin/menu"
sed -i 's/\r$//' /usr/local/bin/menu
echo "alias menu='bash /usr/local/bin/menu'" >> /root/.bashrc
source ~/.bashrc 2>/dev/null

rm -f "$0" install.tmp install.log &>/dev/null

clear
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${Green}              INSTALLATION COMPLETE!${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""
echo -e "${BLUE}│${CYAN}  Domain      : ${domain}${FONT}"
echo -e "${BLUE}│${CYAN}  UDP Port    : ${ZIVPN_UDP_PORT}${FONT}"
echo -e "${BLUE}│${CYAN}  API Port    : ${ZIVPN_API_PORT}${FONT}"
echo -e "${BLUE}│${CYAN}  API Key     : ${api_key}${FONT}"
echo -e "${BLUE}│${CYAN}  Config      : /etc/zivpn/config.json${FONT}"
echo -e "${BLUE}│${CYAN}  Users DB    : /etc/zivpn/users.json${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${CYAN}              LICENSE SAVED${FONT}"
echo -e "${BLUE}├─────────────────────────────────────────────────┤${FONT}"
echo -e "${BLUE}│${WHITE}  User Name   : ${YELLOW}${LICENSE_USERNAME}${FONT}"
echo -e "${BLUE}│${WHITE}  License Key : ${CYAN}${LICENSE_KEY}${FONT}"
echo -e "${BLUE}│${WHITE}  Package     : ${GREEN}${LICENSE_PACKAGE}${FONT}"
echo -e "${BLUE}│${WHITE}  Max Users   : ${YELLOW}${LICENSE_MAX_USERS}${FONT}"
echo -e "${BLUE}│${WHITE}  Expired     : ${YELLOW}${LICENSE_EXPIRED:-Lifetime}${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${YELLOW}  Menu Manager:${FONT}"
echo -e "${BLUE}│${Green}    menu${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${YELLOW}  Commands:${FONT}"
echo -e "${BLUE}│${NC}    systemctl start/stop/restart zivpn${FONT}"
echo -e "${BLUE}│${NC}    systemctl start/stop/restart zivpn-api${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${GRAY}  Telegram : https://t.me/PeyxDev${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""

# Run menu
bash /usr/local/bin/menu