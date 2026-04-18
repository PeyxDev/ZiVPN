#!/bin/bash

# Colors
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
BLUE="\033[1;34m"
RESET="\033[0m"
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

clear
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         ZiVPN UDP Installer - PeyxDev Edition${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [[ "$(uname -s)" != "Linux" ]] || [[ "$(uname -m)" != "x86_64" ]]; then
  print_fail "System not supported (Linux AMD64 only)"
fi

if [ -f /usr/local/bin/zivpn ]; then
  echo -e "${YELLOW}! ZiVPN detected. Reinstalling...${RESET}"
  systemctl stop zivpn.service &>/dev/null
  systemctl stop zivpn-api.service &>/dev/null
  systemctl stop zivpn-bot.service &>/dev/null
fi

run_silent "Updating system" "apt-get update -y"

if ! command -v go &> /dev/null; then
  run_silent "Installing dependencies" "apt-get install -y golang git wget curl openssl jq ufw"
else
  run_silent "Installing dependencies" "apt-get install -y wget curl openssl jq ufw"
fi

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
echo -e "${CYAN}   UDP Port: ${ZIVPN_UDP_PORT}${RESET}"
echo -e "${CYAN}   API Port: ${ZIVPN_API_PORT}${RESET}"
echo ""

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         API Key Configuration${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
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
sed -i "s/Port = \":8585\"/Port = \":${ZIVPN_API_PORT}\"/" zivpn-api.go

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

# Telegram Bot Configuration
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         Telegram Bot Configuration${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "${GRAY}   (Leave empty to skip)${RESET}"
read -p "   Bot Token: " bot_token
read -p "   Admin ID : " admin_id

if [[ -n "$bot_token" ]] && [[ -n "$admin_id" ]]; then
  echo ""
  echo "   Select Bot Type:"
  echo "   1) Free (Admin Only / Public Mode)"
  echo "   2) Paid (Pakasir Payment Gateway)"
  read -p "   Choice [1]: " bot_type
  bot_type=${bot_type:-1}

  if [[ "$bot_type" == "2" ]]; then
    read -p "   Pakasir Project Slug: " pakasir_slug
    read -p "   Pakasir API Key     : " pakasir_key
    read -p "   Daily Price (IDR)   : " daily_price
    read -p "   Default IP Limit    : " ip_limit
    ip_limit=${ip_limit:-1}
    
    echo "{\"bot_token\": \"$bot_token\", \"admin_id\": $admin_id, \"mode\": \"public\", \"domain\": \"$domain\", \"pakasir_slug\": \"$pakasir_slug\", \"pakasir_api_key\": \"$pakasir_key\", \"daily_price\": $daily_price, \"default_ip_limit\": $ip_limit}" > /etc/zivpn/bot-config.json
    bot_file="zivpn-paid-bot.go"
  else
    read -p "   Bot Mode (public/private) [default: private]: " bot_mode
    bot_mode=${bot_mode:-private}
    
    echo "{\"bot_token\": \"$bot_token\", \"admin_id\": $admin_id, \"mode\": \"$bot_mode\", \"domain\": \"$domain\"}" > /etc/zivpn/bot-config.json
    bot_file="zivpn-bot.go"
  fi
  
  run_silent "Downloading Bot" "wget -q ${GITHUB_REPO}/$bot_file -O /etc/zivpn/api/$bot_file"
  
  cd /etc/zivpn/api
  run_silent "Downloading Bot Deps" "go get github.com/go-telegram-bot-api/telegram-bot-api/v5"
  
  if go build -o zivpn-bot "$bot_file" &>/dev/null; then
    print_done "Compiling Bot"
    
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
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}         Installing Menu Manager${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

run_silent "Downloading Menu Manager" "wget -q ${GITHUB_REPO}/menu.sh -O /usr/local/sbin/m-zivpn && chmod +x /usr/local/sbin/m-zivpn"
sed -i 's/\r$//' /usr/local/sbin/m-zivpn
echo "alias m-zivpn='bash /usr/local/sbin/m-zivpn'" >> /root/.bashrc
source ~/.bashrc 2>/dev/null

rm -f "$0" install.tmp install.log &>/dev/null

clear
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}              INSTALLATION COMPLETE!${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "${CYAN}  Domain      : ${domain}${RESET}"
echo -e "${CYAN}  UDP Port    : ${ZIVPN_UDP_PORT}${RESET}"
echo -e "${CYAN}  API Port    : ${ZIVPN_API_PORT}${RESET}"
echo -e "${CYAN}  API Key     : ${api_key}${RESET}"
echo -e "${CYAN}  Config      : /etc/zivpn/config.json${RESET}"
echo -e "${CYAN}  Users DB    : /etc/zivpn/users.json${RESET}"
echo ""
echo -e "${BOLD}  Menu Manager:${RESET}"
echo -e "    ${GREEN}m-zivpn${RESET}"
echo ""
echo -e "${BOLD}  Commands:${RESET}"
echo -e "    ${YELLOW}systemctl start/stop/restart zivpn${RESET}"
echo -e "    ${YELLOW}systemctl start/stop/restart zivpn-api${RESET}"
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GRAY}  Telegram : https://t.me/PeyxDev${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Run menu
bash /usr/local/sbin/m-zivpn