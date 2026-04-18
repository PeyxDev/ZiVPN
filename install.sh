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
CYAN="\033[1;36m"
BOLD="\033[1m"
GRAY="\033[1;30m"

# ==================== VARIABLES ====================
ZIVPN_UDP_PORT="5667"
ZIVPN_API_PORT="8585"
GITHUB_REPO="https://raw.githubusercontent.com/PeyxDev/ZiVPN/main"

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

# ==================== CEKIP FUNCTION ====================
CEKIP () {
MYIP=$(curl -sS ipv4.icanhazip.com)
IPVPS=$(curl -sS https://raw.githubusercontent.com/PeyxDev/esce/main/ipx | grep $MYIP | awk '{print $4}')
if [[ $MYIP == $IPVPS ]]; then
  return 0
else
  clear
  echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
  echo -e "${BLUE}│${RED}              PERMISSION DENIED !${FONT}"
  echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
  echo -e "${BLUE}│${NC}"
  echo -e "${BLUE}│${NC}  ${RED}IP Anda tidak terdaftar!${NC}"
  echo -e "${BLUE}│${NC}  ${YELLOW}Silakan hubungi admin untuk izin akses${NC}"
  echo -e "${BLUE}│${NC}"
  echo -e "${BLUE}│${NC}  ${CYAN}Telegram : https://t.me/PeyxDev${NC}"
  echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
  exit 1
fi
}

clear
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${CYAN}         ZiVPN UDP Installer - PeyxDev Edition${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""

CEKIP

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
  run_silent "Installing dependencies" "sudo apt-get install -y golang git wget curl openssl jq ufw"
else
  run_silent "Installing dependencies" "sudo apt-get install -y wget curl openssl jq ufw"
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
echo -e "   Generated Key: ${CYAN}$generated_key${RESET}"
read -p "   Enter API Key (Press Enter to use generated): " input_key
if [[ -z "$input_key" ]]; then
  api_key="$generated_key"
else
  api_key="$input_key"
fi
echo -e "   Using Key: ${GREEN}$api_key${RESET}"
echo ""

systemctl stop zivpn.service &>/dev/null
run_silent "Downloading Core" "wget -q https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn && chmod +x /usr/local/bin/zivpn"

mkdir -p /etc/zivpn
echo "$domain" > /etc/zivpn/domain
echo "$api_key" > /etc/zivpn/apikey
echo "[]" > /etc/zivpn/users.json

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
# Update API port
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

# ==================== TELEGRAM BOT CONFIGURATION ====================
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${CYAN}         Telegram Bot Configuration${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo -e "${GRAY}   (Leave empty to skip)${NC}"
echo ""
read -p "   Bot Token: " bot_token
read -p "   Admin ID : " admin_id

if [[ -n "$bot_token" ]] && [[ -n "$admin_id" ]]; then
  echo ""
  echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
  echo -e "${BLUE}│${CYAN}         Select Bot Type${FONT}"
  echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
  echo -e "   ${GREEN}1${NC}) Free (Admin Only / Public Mode)"
  echo -e "   ${GREEN}2${NC}) Paid (Pakasir Payment Gateway)"
  read -p "   Choice [1]: " bot_type
  bot_type=${bot_type:-1}

  if [[ "$bot_type" == "2" ]]; then
    echo ""
    read -p "   Pakasir Project Slug: " pakasir_slug
    read -p "   Pakasir API Key     : " pakasir_key
    read -p "   Daily Price (IDR)   : " daily_price
    read -p "   Default IP Limit    : " ip_limit
    ip_limit=${ip_limit:-1}
    
    echo "{\"bot_token\": \"$bot_token\", \"admin_id\": $admin_id, \"mode\": \"public\", \"domain\": \"$domain\", \"pakasir_slug\": \"$pakasir_slug\", \"pakasir_api_key\": \"$pakasir_key\", \"daily_price\": $daily_price, \"default_ip_limit\": $ip_limit}" > /etc/zivpn/bot-config.json
    bot_file="zivpn-paid-bot.go"
    bot_type_name="Paid (Pakasir)"
  else
    echo ""
    read -p "   Bot Mode (public/private) [default: private]: " bot_mode
    bot_mode=${bot_mode:-private}
    
    echo "{\"bot_token\": \"$bot_token\", \"admin_id\": $admin_id, \"mode\": \"$bot_mode\", \"domain\": \"$domain\"}" > /etc/zivpn/bot-config.json
    bot_file="zivpn-bot.go"
    bot_type_name="Free"
  fi
  
  echo ""
  run_silent "Downloading Bot" "wget -q ${GITHUB_REPO}/$bot_file -O /etc/zivpn/api/$bot_file"
  
  cd /etc/zivpn/api
  run_silent "Downloading Bot Deps" "go get github.com/go-telegram-bot-api/telegram-bot-api/v5"
  
  if go build -o zivpn-bot "$bot_file" &>/dev/null; then
    print_done "Compiling Bot ($bot_type_name)"
    
    cat <<EOF > /etc/systemd/system/zivpn-bot.service
[Unit]
Description=ZiVPN Telegram Bot
After=network.target zivpn-api.service

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn/api
ExecStart=/etc/zivpn/api/zivpn-bot
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable zivpn-bot.service &>/dev/null
    systemctl start zivpn-bot.service &>/dev/null
    print_done "Bot Service Created"
  else
    print_fail "Compiling Bot"
  fi
else
  print_task "Skipping Bot Setup"
  echo ""
fi

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

run_silent "Downloading Menu Manager" "wget -q ${GITHUB_REPO}/menu.sh -O /usr/local/sbin/m-zivpn && chmod +x /usr/local/sbin/m-zivpn"
sed -i 's/\r$//' /usr/local/sbin/m-zivpn
echo "alias m-zivpn='bash /usr/local/sbin/m-zivpn'" >> /root/.bashrc
source ~/.bashrc 2>/dev/null

rm -f "$0" install.tmp install.log &>/dev/null

clear
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${GREEN}              INSTALLATION COMPLETE!${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""
echo -e "${BLUE}│${CYAN}  Domain      : ${domain}${FONT}"
echo -e "${BLUE}│${CYAN}  UDP Port    : ${ZIVPN_UDP_PORT}${FONT}"
echo -e "${BLUE}│${CYAN}  API Port    : ${ZIVPN_API_PORT}${FONT}"
echo -e "${BLUE}│${CYAN}  API Key     : ${api_key}${FONT}"
echo -e "${BLUE}│${CYAN}  Config      : /etc/zivpn/config.json${FONT}"
echo -e "${BLUE}│${CYAN}  Users DB    : /etc/zivpn/users.json${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"

if [[ -n "$bot_token" ]] && [[ -n "$admin_id" ]]; then
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${GREEN}              BOT CONFIGURATION${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo -e "${BLUE}│${CYAN}  Bot Type    : ${bot_type_name}${FONT}"
echo -e "${BLUE}│${CYAN}  Bot Token   : ${bot_token}${FONT}"
echo -e "${BLUE}│${CYAN}  Admin ID    : ${admin_id}${FONT}"
if [[ "$bot_type" == "2" ]]; then
echo -e "${BLUE}│${CYAN}  Pakasir Slug: ${pakasir_slug}${FONT}"
echo -e "${BLUE}│${CYAN}  Daily Price : Rp ${daily_price}${FONT}"
echo -e "${BLUE}│${CYAN}  IP Limit    : ${ip_limit}${FONT}"
fi
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
fi

echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${YELLOW}  Menu Manager:${FONT}"
echo -e "${BLUE}│${GREEN}    m-zivpn${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${YELLOW}  Commands:${FONT}"
echo -e "${BLUE}│${NC}    systemctl start/stop/restart zivpn${FONT}"
echo -e "${BLUE}│${NC}    systemctl start/stop/restart zivpn-api${FONT}"
if [[ -n "$bot_token" ]] && [[ -n "$admin_id" ]]; then
echo -e "${BLUE}│${NC}    systemctl start/stop/restart zivpn-bot${FONT}"
fi
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${FONT}"
echo -e "${BLUE}│${GRAY}  Telegram : https://t.me/PeyxDev${FONT}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${FONT}"
echo ""

# Run menu
bash /usr/local/sbin/m-zivpn