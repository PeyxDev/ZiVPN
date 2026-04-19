#!/bin/bash

# Colors (mempertahankan warna asli untuk fungsi)
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

# Warna gaya setup.sh
neutral="${NC}"
orange="\e[38;5;130m"
purple="\e[38;5;141m"
bold_white="\e[1;37m"
pink="\e[38;5;205m"
reset="\e[0m"

# ==================== VARIABLES ====================
ZIVPN_UDP_PORT="5667"
ZIVPN_NODE_API_PORT="8585"
GITHUB_REPO="https://raw.githubusercontent.com/PeyxDev/ZiVPN/main"
ZIP_PASSWORD="PeyxDev@23"

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

# ==================== CEKIP FUNCTION ====================
CEKIP () {
MYIP=$(curl -sS ipv4.icanhazip.com)
IPVPS=$(curl -sS https://raw.githubusercontent.com/PeyxDev/esce/main/ipx | grep "$MYIP" | awk '{print $4}')
USERNAME=$(curl -sS https://raw.githubusercontent.com/PeyxDev/esce/main/ipx | grep "$MYIP" | awk '{print $2}')
EXPIRED=$(curl -sS https://raw.githubusercontent.com/PeyxDev/esce/main/ipx | grep "$MYIP" | awk '{print $3}')

if [[ "$MYIP" == "$IPVPS" ]]; then
  today=$(date -d "0 days" +%Y-%m-%d)
  d1=$(date -d "$EXPIRED" +%s 2>/dev/null)
  d2=$(date -d "$today" +%s)
  
  if [[ -z "$EXPIRED" ]]; then
    return 0
  elif [[ $d1 -lt $d2 ]]; then
    clear
    echo -e "${purple}┌───────────────────────────────────────────────┐${neutral}"
    echo -e "${purple}│${RED}              ACCOUNT EXPIRED !${FONT}"
    echo -e "${purple}└───────────────────────────────────────────────┘${neutral}"
    echo -e "${purple}│${NC}"
    echo -e "${purple}│${NC}  ${RED}Masa berlaku script Anda telah habis!${NC}"
    echo -e "${purple}│${NC}  ${YELLOW}Silakan perpanjang ke admin${NC}"
    echo -e "${purple}│${NC}"
    echo -e "${purple}│${NC}  ${CYAN}Telegram : https://t.me/PeyxDev${NC}"
    echo -e "${purple}└───────────────────────────────────────────────┘${neutral}"
    exit 1
  else
    return 0
  fi
else
  clear
  echo -e "${purple}┌───────────────────────────────────────────────┐${neutral}"
  echo -e "${purple}│${RED}              PERMISSION DENIED !${FONT}"
  echo -e "${purple}└───────────────────────────────────────────────┘${neutral}"
  echo -e "${purple}│${NC}"
  echo -e "${purple}│${NC}  ${RED}IP Anda tidak terdaftar!${NC}"
  echo -e "${purple}│${NC}  ${YELLOW}Silakan hubungi admin untuk izin akses${NC}"
  echo -e "${purple}│${NC}"
  echo -e "${purple}│${NC}  ${CYAN}Telegram : https://t.me/PeyxDev${NC}"
  echo -e "${purple}└───────────────────────────────────────────────┘${neutral}"
  exit 1
fi
}

function Xwan_Banner() {
clear
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │                     ${bold_white}ZIVPN${neutral}                     ${purple}│${neutral}"
echo -e "${purple} │         ${green}┌─┐┬ ┬┌┬┐┌─┐┌─┐┌─┐┬─┐┬┌─┐┌┬┐          ${purple}│${neutral}"
echo -e "${purple} │         ${green}├─┤│ │ │ │ │└─┐│  ├┬┘│├─┘ │           ${purple}│${neutral}"
echo -e "${purple} │         ${green}┴ ┴└─┘ ┴ └─┘└─┘└─┘┴└─┴┴   ┴           ${neutral}${purple}│${neutral}"
echo -e "${purple} │        ${YELLOW}Copyright${reset} (C)${GRAY} https://t.me/PeyxDev     ${purple}│${neutral}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
}

function Service_System_Operating() {
echo -e "${purple} ────────────────────────────────────────────────${neutral}"
echo -e "${purple}│${WHITE} SYSTEM OS       : $(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g') ${NC}"
echo -e "${purple}│${WHITE} IP VPS          : $(curl -s ipv4.icanhazip.com) ${NC}"
echo -e "${purple} ────────────────────────────────────────────────${neutral}"
}

Xwan_Banner
Service_System_Operating
CEKIP

if [[ "$(uname -s)" != "Linux" ]] || [[ "$(uname -m)" != "x86_64" ]]; then
  print_fail "System not supported (Linux AMD64 only)"
fi

if [ -f /usr/local/bin/zivpn ]; then
  echo -e "${YELLOW}┌─────────────────────────────────────────────────┐${NC}"
  echo -e "${YELLOW}│  ! ZiVPN detected. Reinstalling...${NC}"
  echo -e "${YELLOW}└─────────────────────────────────────────────────┘${NC}"
  systemctl stop zivpn.service &>/dev/null
  systemctl stop zivpn-api-js.service &>/dev/null
  systemctl stop zivpn-bot.service &>/dev/null
fi

run_silent "Updating system" "sudo apt-get update -y"

# Install dependencies (tanpa golang)
run_silent "Installing dependencies" "sudo apt-get install -y wget curl openssl jq ufw zip unzip p7zip-full"

# Install Node.js 20.x (LTS)
if ! command -v node &> /dev/null; then
  print_task "Installing Node.js 20.x"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - &>/tmp/zivpn_install.log
  apt-get install -y nodejs &>/tmp/zivpn_install.log
  print_done "Installing Node.js 20.x"
fi

echo ""
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │${CYAN}         Domain Configuration${FONT}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
echo ""

while true; do
  read -p "   Enter Domain (e.g., pxstore.web.id): " domain
  if [[ -n "$domain" ]]; then
    break
  fi
done

echo ""
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │${CYAN}   UDP Port: ${ZIVPN_UDP_PORT}${FONT}"
echo -e "${purple} │${CYAN}   Node.js API Port: ${ZIVPN_NODE_API_PORT}${FONT}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
echo ""

systemctl stop zivpn.service &>/dev/null
run_silent "Downloading Core" "wget -q https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn && chmod +x /usr/local/bin/zivpn"

mkdir -p /etc/zivpn
echo "$domain" > /etc/zivpn/domain
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

# ==================== GENERATE API KEY ====================
echo ""
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │${CYAN}         Generate API Key${FONT}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
echo ""

# Generate API Key format PX- + random 32 karakter
generate_api_key() {
    echo "PX-$(openssl rand -hex 16)"
}

API_KEY=$(generate_api_key)
echo "$API_KEY" > /etc/zivpn/apikey
chmod 600 /etc/zivpn/apikey

echo -e "${Green}  ✅ API Key generated: ${API_KEY}${NC}"
echo -e "  📁 API Key saved to: /etc/zivpn/apikey"
echo ""

# ==================== INSTALL NODE.JS API ====================
echo ""
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │${CYAN}         Installing Node.js API${FONT}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
echo ""

mkdir -p /etc/zivpn/api

# Download api.js dari repo
run_silent "Downloading Node.js API" "wget -q ${GITHUB_REPO}/api/api.js -O /etc/zivpn/api/api.js"

# Update api.js dengan API Key yang benar
sed -i "s/const API_KEY = .*/const API_KEY = '$API_KEY';/" /etc/zivpn/api/api.js
sed -i "s/const PORT = .*/const PORT = $ZIVPN_NODE_API_PORT;/" /etc/zivpn/api/api.js

# Install express
cd /etc/zivpn/api
run_silent "Installing express" "npm install express"

# Create Node.js API service
cat <<EOF > /etc/systemd/system/zivpn-api-js.service
[Unit]
Description=ZiVPN Node.js API Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn/api
ExecStart=/usr/bin/node /etc/zivpn/api/api.js
Restart=always
RestartSec=3
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# Start services
run_silent "Starting Node.js API Service" "systemctl daemon-reload && systemctl enable zivpn-api-js.service && systemctl start zivpn-api-js.service"
run_silent "Starting ZiVPN Core" "systemctl enable zivpn.service && systemctl start zivpn.service"

# Firewall rules
iface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
iptables -t nat -A PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :${ZIVPN_UDP_PORT} &>/dev/null
ufw allow 6000:19999/udp &>/dev/null
ufw allow ${ZIVPN_UDP_PORT}/udp &>/dev/null
ufw allow ${ZIVPN_NODE_API_PORT}/tcp &>/dev/null

# ==================== DOWNLOAD MENU MANAGER ====================
echo ""
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │${CYAN}         Installing Menu Manager${FONT}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
echo ""

# Download ZIP file
run_silent "Downloading Menu Package" "wget -q ${GITHUB_REPO}/menu.zip -O /tmp/menu.zip"

# Extract dengan 7zip
print_task "Extracting Menu Package with 7zip"
rm -rf /tmp/menu
7z x -p"$ZIP_PASSWORD" /tmp/menu.zip -o/tmp/menu/ -y &>/tmp/zivpn_install.log
if [ $? -eq 0 ]; then
  print_done "Extracting Menu Package with 7zip"
else
  print_fail "Extracting Menu Package (Wrong password or corrupt file)"
fi

# Copy semua file menu ke /usr/local/bin
print_task "Installing Menu Files"
find /tmp/menu -type f -exec cp -f {} /usr/local/bin/ \; 2>/dev/null
print_done "Installing Menu Files"

# Install dos2unix jika belum
if ! command -v dos2unix &> /dev/null; then
  print_task "Installing dos2unix"
  apt install dos2unix -y &>/dev/null
  print_done "Installing dos2unix"
fi

# Convert ke format Unix
print_task "Converting to Unix format"
dos2unix /usr/local/bin/* &>/dev/null
print_done "Converting to Unix format"

# Beri izin eksekusi
print_task "Setting execute permissions"
chmod +x /usr/local/bin/menu 2>/dev/null
chmod +x /usr/local/bin/add-* 2>/dev/null
chmod +x /usr/local/bin/delete-* 2>/dev/null
chmod +x /usr/local/bin/renew-* 2>/dev/null
chmod +x /usr/local/bin/list-* 2>/dev/null
chmod +x /usr/local/bin/trial-* 2>/dev/null
chmod +x /usr/local/bin/install-* 2>/dev/null
chmod +x /usr/local/bin/restart 2>/dev/null
chmod +x /usr/local/bin/status-* 2>/dev/null
chmod +x /usr/local/bin/backup 2>/dev/null
chmod +x /usr/local/bin/github-* 2>/dev/null
chmod +x /usr/local/bin/restore 2>/dev/null
chmod +x /usr/local/bin/del-* 2>/dev/null
print_done "Setting execute permissions"

# Bersihkan file temporary
rm -rf /tmp/menu /tmp/menu.zip

# ==================== AUTO MENU ON LOGIN ====================
echo ""
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │${CYAN}         Setting Auto Menu on Login${FONT}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
echo ""

# Hapus semua konfigurasi lama
sed -i '/# ========== AUTO MENU ZIVPN ==========/,/# ======================================/d' /root/.bashrc 2>/dev/null
sed -i '/# ========== AUTO MENU ZIVPN ==========/,/# ======================================/d' /root/.profile 2>/dev/null
sed -i '/alias menu=/d' /root/.bashrc 2>/dev/null
rm -f /etc/profile.d/menu.sh 2>/dev/null

# Gunakan profile.d method
cat > /etc/profile.d/menu.sh << 'EOF'
#!/bin/bash
# ZiVPN Auto Menu - Hanya tampil sekali saat login
if [ -t 0 ] && [ -f /usr/local/bin/menu ] && [ -z "$ZIVPN_MENU_SHOWN" ]; then
    export ZIVPN_MENU_SHOWN=1
    clear
    /usr/local/bin/menu
fi
EOF
chmod +x /etc/profile.d/menu.sh

# Tambahkan alias untuk manual menu
echo "alias menu='bash /usr/local/bin/menu'" >> /root/.bashrc

echo -e "${Green}  ✓ Auto menu on login has been configured${NC}"
echo ""

rm -f "$0" install.tmp install.log &>/dev/null

clear
echo ""
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │${Green}              INSTALLATION COMPLETE!${FONT}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
echo ""
echo -e "${purple} │${CYAN}  Domain           : ${domain}${FONT}"
echo -e "${purple} │${CYAN}  UDP Port         : ${ZIVPN_UDP_PORT}${FONT}"
echo -e "${purple} │${CYAN}  Node.js API Port : ${ZIVPN_NODE_API_PORT}${FONT}"
echo -e "${purple} │${CYAN}  API Key          : ${API_KEY}${FONT}"
echo -e "${purple} │${CYAN}  API Key File     : /etc/zivpn/apikey${FONT}"
echo -e "${purple} │${CYAN}  Config Dir       : /etc/zivpn${FONT}"
echo -e "${purple} ────────────────────────────────────────────────${neutral}"
echo ""
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │${YELLOW}  Menu Manager:${FONT}"
echo -e "${purple} │${Green}    menu${FONT}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
echo ""
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │${GRAY}  Telegram : https://t.me/PeyxDev${FONT}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
echo ""
echo -e "${YELLOW}  Tekan Enter untuk melanjutkan ke menu...${NC}"
read -r

# Run menu
bash /usr/local/bin/menu