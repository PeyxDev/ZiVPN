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

MYIP=$(curl -sS ipv4.icanhazip.com)
domain=$(cat /etc/zivpn/domain 2>/dev/null || echo "Tidak ada")
ISP=$(curl -s ipinfo.io/org 2>/dev/null | cut -d " " -f 2-10)
if [[ -z "$ISP" ]]; then ISP="Unknown"; fi
CITY=$(curl -s ipinfo.io/city 2>/dev/null)
if [[ -z "$CITY" ]]; then CITY="Unknown"; fi
MODEL=$(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')
SERONLINE=$(uptime -p | cut -d " " -f 2-10000)

ZIVPN_CONFIG="/etc/zivpn/config.json"
ZIVPN_USERS="/etc/zivpn/users.json"
ZIVPN_PORT=$(grep -oP '"listen":":\K[0-9]+' /etc/zivpn/config.json 2>/dev/null || echo "5667")
ZIVPN_API_PORT="8585"
API_KEY=$(cat /etc/zivpn/apikey 2>/dev/null)
GITHUB_REPO="https://raw.githubusercontent.com/PeyxDev/ZiVPN/main"

# ==================== CEK IP & EXPIRED ====================
CEKIP() {
    IPLIST=$(curl -sS https://raw.githubusercontent.com/PeyxDev/esce/main/ipx)
    IPVPS=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $4}')
    USERNAME=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $2}')
    EXPIRED=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $3}')
    LICENSE_KEY=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $5}')
    LICENSE_PACKAGE=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $6}')
    
    if [[ -z "$LICENSE_KEY" ]]; then
        LICENSE_KEY="XXXXXXXX-XXXX-XXXX-XXXX"
        LICENSE_PACKAGE="-"
    fi
    
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
    
    today=$(date -d "0 days" +%Y-%m-%d)
    d1=$(date -d "$EXPIRED" +%s 2>/dev/null)
    d2=$(date -d "$today" +%s)
    
    if [[ -z "$EXPIRED" ]]; then
        masaaktif="LIFETIME"
        status_exp="\033[92;1m● ACTIVE\033[0m"
    elif [[ $d1 -lt $d2 ]]; then
        clear
        echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
        echo -e "${BLUE}│${RED}              ACCOUNT EXPIRED !${NC}"
        echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
        echo -e "${BLUE}│${NC}"
        echo -e "${BLUE}│${NC}  ${RED}Masa berlaku script Anda telah habis!${NC}"
        echo -e "${BLUE}│${NC}  ${YELLOW}Silakan perpanjang ke admin${NC}"
        echo -e "${BLUE}│${NC}"
        echo -e "${BLUE}│${NC}  ${CYAN}Telegram : https://t.me/PeyxDev${NC}"
        echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
        exit 1
    else
        certifacate=$(((d1 - d2) / 86400))
        masaaktif="${certifacate} Hari"
        status_exp="\033[92;1m● ACTIVE\033[0m"
    fi
}

function check_zivpn_status() {
    if systemctl is-active --quiet zivpn 2>/dev/null; then
        echo -e "${Green}ON${NC}"
    else
        echo -e "${RED}OFF${NC}"
    fi
}

function check_api_status() {
    if systemctl is-active --quiet zivpn-api 2>/dev/null; then
        echo -e "${Green}ON${NC}"
    else
        echo -e "${RED}OFF${NC}"
    fi
}

function check_bot_status() {
    if systemctl is-active --quiet zivpn-bot 2>/dev/null; then
        echo -e "${Green}ON${NC}"
    else
        echo -e "${RED}OFF${NC}"
    fi
}

function get_total_users() {
    if [ -f "$ZIVPN_USERS" ]; then
        python3 -c "import json; print(len(json.load(open('$ZIVPN_USERS'))))" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

function generate_random_password() {
    echo $(openssl rand -hex 8)
}

function Zivpn_Banner() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE}  \033[38;5;196m⁙\033[38;5;202m⁙\033[38;5;208m⁙\033[38;5;214m⁙\033[38;5;220m⁙\033[38;5;226m⁙\033[38;5;190m⁙\033[38;5;154m⁙\033[38;5;118m⁙\033[38;5;82m⁙\033[38;5;46m⁙\033[38;5;47m⁙\033[38;5;48m⁙\033[38;5;49m⁙${WHITE} ZIVPN MANAGER \033[38;5;87m⁙\033[38;5;86m⁙\033[38;5;85m⁙\033[38;5;84m⁙\033[38;5;83m⁙\033[38;5;44m⁙\033[38;5;43m⁙\033[38;5;42m⁙\033[38;5;41m⁙\033[38;5;40m⁙\033[38;5;39m⁙\033[38;5;38m⁙\033[38;5;37m⁙\033[38;5;36m⁙${WHITE}    ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

function Service_System_Operating() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE} SYSTEM OS       : $MODEL ${NC}"
    echo -e "${BLUE}│${WHITE} UPTIME SERVER   : $SERONLINE ${NC}"
    echo -e "${BLUE}│${WHITE} IP VPS          : $MYIP ${NC}"
    echo -e "${BLUE}│${WHITE} ISP             : $ISP ${NC}"
    echo -e "${BLUE}│${WHITE} CITY            : $CITY ${NC}"
    echo -e "${BLUE}│${WHITE} DOMAIN          : $domain ${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

function Service_Status() {
    if [ -f "/etc/systemd/system/zivpn-bot.service" ]; then
        echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
        echo -e "${BLUE}|${NC}${YELLOW} ZIVPN : $(check_zivpn_status) ${BLUE}|${NC}${YELLOW} API : $(check_api_status) ${BLUE}|${NC}${YELLOW} BOT : $(check_bot_status) ${BLUE}|${NC}${YELLOW} USERS : $(get_total_users) ${BLUE}| ${NC}"
        echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    else
        echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
        echo -e "${BLUE}|${NC}${YELLOW} ZIVPN : $(check_zivpn_status) ${BLUE}|${NC}${YELLOW} API : $(check_api_status) ${BLUE}|${NC}${YELLOW} PORT : $ZIVPN_PORT ${BLUE}|${NC}${YELLOW} USERS : $(get_total_users) ${BLUE}| ${NC}"
        echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    fi
}

# ==================== LICENSE INFO (GANTI API_INFO) ====================
function License_Info() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${CYAN}              LICENSE INFORMATION${NC}"
    echo -e "${BLUE}├─────────────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│${WHITE}  User Name   : ${YELLOW}${USERNAME:-Unknown}${NC}"
    echo -e "${BLUE}│${WHITE}  License Key : ${CYAN}${LICENSE_KEY}${NC}"
    echo -e "${BLUE}│${WHITE}  Package     : ${GREEN}${LICENSE_PACKAGE}${NC}"
    echo -e "${BLUE}│${WHITE}  Expired     : ${YELLOW}${EXPIRED:-Lifetime}${NC}"
    echo -e "${BLUE}│${WHITE}  Sisa Hari   : ${YELLOW}${masaaktif}${NC}"
    echo -e "${BLUE}│${WHITE}  Status      : ${status_exp}${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

function Acces_Use_Command() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│  1.${NC})${Green} Create User          ${BLUE}  6.${NC})${Green} Trial 30 Menit${RESET}   ${BLUE}│${NC}"
    echo -e "${BLUE}│  2.${NC})${Green} Create Random PW     ${BLUE}  7.${NC})${Green} Install Bot${RESET}      ${BLUE}│${NC}"
    echo -e "${BLUE}│  3.${NC})${Green} Delete User          ${BLUE}  8.${NC})${Green} Install Pakasir${RESET}  ${BLUE}│${NC}"
    echo -e "${BLUE}│  4.${NC})${Green} Renew User           ${BLUE}  9.${NC})${Green} Restart Service${RESET}  ${BLUE}│${NC}"
    echo -e "${BLUE}│  5.${NC})${Green} List Users           ${BLUE}  10.${NC})${Green} Service Status${RESET}  ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo -e "${BLUE}  ┌───────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │  ${RED}x.${NC})${RED} Exit${NC}                                         ${BLUE}│${NC}"
    echo -e "${BLUE}  └───────────────────────────────────────────────┘${NC}"
}

function create_user() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              CREATE ZIVPN USER${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    read -p "   Password / Username : " password
    read -p "   Days (masa aktif)   : " days
    read -p "   IP Limit (0=unlimited) : " iplimit
    
    if [[ -z "$password" || -z "$days" ]]; then
        echo -e "${RED}   Password dan Days harus diisi!${NC}"
        echo ""
        read -p "   Tekan Enter untuk kembali..."
        return
    fi
    
    exp_date=$(date -d "+$days days" +%Y-%m-%d)
    
    python3 << PYTHON
import json
with open("$ZIVPN_CONFIG", "r") as f:
    config = json.load(f)
if "$password" not in config["auth"]["config"]:
    config["auth"]["config"].append("$password")
with open("$ZIVPN_CONFIG", "w") as f:
    json.dump(config, f, indent=4)

try:
    with open("$ZIVPN_USERS", "r") as f:
        users = json.load(f)
except:
    users = []

users.append({
    "password": "$password",
    "expired": "$exp_date",
    "ip_limit": ${iplimit:-0},
    "status": "active",
    "created_at": "$(date '+%Y-%m-%d %H:%M:%S')"
})
with open("$ZIVPN_USERS", "w") as f:
    json.dump(users, f, indent=4)
PYTHON
    
    echo -e "${Green}   ✅ User berhasil dibuat!${NC}"
    echo ""
    echo -e "${CYAN}   Detail User:${NC}"
    echo -e "   Password : ${YELLOW}$password${NC}"
    echo -e "   Expired  : ${YELLOW}$exp_date${NC}"
    echo -e "   IP Limit : ${YELLOW}${iplimit:-0}${NC}"
    echo -e "   Domain   : ${YELLOW}$domain${NC}"
    
    systemctl restart zivpn 2>/dev/null
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function create_random_user() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}         CREATE USER WITH RANDOM PASSWORD${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    
    password=$(generate_random_password)
    read -p "   Days (masa aktif)   : " days
    read -p "   IP Limit (0=unlimited) : " iplimit
    
    if [[ -z "$days" ]]; then
        echo -e "${RED}   Days harus diisi!${NC}"
        echo ""
        read -p "   Tekan Enter untuk kembali..."
        return
    fi
    
    exp_date=$(date -d "+$days days" +%Y-%m-%d)
    
    python3 << PYTHON
import json
with open("$ZIVPN_CONFIG", "r") as f:
    config = json.load(f)
if "$password" not in config["auth"]["config"]:
    config["auth"]["config"].append("$password")
with open("$ZIVPN_CONFIG", "w") as f:
    json.dump(config, f, indent=4)

try:
    with open("$ZIVPN_USERS", "r") as f:
        users = json.load(f)
except:
    users = []

users.append({
    "password": "$password",
    "expired": "$exp_date",
    "ip_limit": ${iplimit:-0},
    "status": "active",
    "created_at": "$(date '+%Y-%m-%d %H:%M:%S')"
})
with open("$ZIVPN_USERS", "w") as f:
    json.dump(users, f, indent=4)
PYTHON
    
    echo -e "${Green}   ✅ User berhasil dibuat!${NC}"
    echo ""
    echo -e "${CYAN}   Detail User:${NC}"
    echo -e "   Password : ${YELLOW}$password${NC}"
    echo -e "   Expired  : ${YELLOW}$exp_date${NC}"
    echo -e "   IP Limit : ${YELLOW}${iplimit:-0}${NC}"
    echo -e "   Domain   : ${YELLOW}$domain${NC}"
    
    systemctl restart zivpn 2>/dev/null
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function trial_user() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              TRIAL 30 MENIT${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    
    password=$(generate_random_password)
    echo -e "   Password Auto: ${YELLOW}$password${NC}"
    echo ""
    
    trial_end=$(date -d "+30 minutes" +"%Y-%m-%d %H:%M:%S")
    trial_date=$(date -d "+30 minutes" +"%Y-%m-%d")
    
    python3 << PYTHON
import json
with open("$ZIVPN_CONFIG", "r") as f:
    config = json.load(f)
if "$password" not in config["auth"]["config"]:
    config["auth"]["config"].append("$password")
with open("$ZIVPN_CONFIG", "w") as f:
    json.dump(config, f, indent=4)

try:
    with open("$ZIVPN_USERS", "r") as f:
        users = json.load(f)
except:
    users = []

users.append({
    "password": "$password",
    "expired": "$trial_date",
    "expired_time": "$trial_end",
    "ip_limit": 1,
    "status": "active",
    "is_trial": True,
    "created_at": "$(date '+%Y-%m-%d %H:%M:%S')"
})
with open("$ZIVPN_USERS", "w") as f:
    json.dump(users, f, indent=4)
PYTHON
    
    echo -e "${Green}   ✅ Trial 30 Menit berhasil dibuat!${NC}"
    echo ""
    echo -e "${CYAN}   Detail Trial:${NC}"
    echo -e "   Password : ${YELLOW}$password${NC}"
    echo -e "   Expired  : ${YELLOW}$trial_end${NC}"
    echo -e "   IP Limit : ${YELLOW}1${NC}"
    echo -e "   Domain   : ${YELLOW}$domain${NC}"
    
    systemctl restart zivpn 2>/dev/null
    
    (
        sleep 1800
        python3 << PYTHON
import json
with open("$ZIVPN_CONFIG", "r") as f:
    config = json.load(f)
if "$password" in config["auth"]["config"]:
    config["auth"]["config"].remove("$password")
with open("$ZIVPN_CONFIG", "w") as f:
    json.dump(config, f, indent=4)

with open("$ZIVPN_USERS", "r") as f:
    users = json.load(f)
users = [u for u in users if u.get("password") != "$password"]
with open("$ZIVPN_USERS", "w") as f:
    json.dump(users, f, indent=4)
PYTHON
        systemctl restart zivpn 2>/dev/null
    ) &
    
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function delete_user() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              DELETE ZIVPN USER${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    read -p "   Password / Username : " password
    
    python3 << PYTHON
import json
with open("$ZIVPN_CONFIG", "r") as f:
    config = json.load(f)
if "$password" in config["auth"]["config"]:
    config["auth"]["config"].remove("$password")
with open("$ZIVPN_CONFIG", "w") as f:
    json.dump(config, f, indent=4)

with open("$ZIVPN_USERS", "r") as f:
    users = json.load(f)
users = [u for u in users if u.get("password") != "$password"]
with open("$ZIVPN_USERS", "w") as f:
    json.dump(users, f, indent=4)
PYTHON
    
    echo -e "${Green}   ✅ User berhasil dihapus!${NC}"
    systemctl restart zivpn 2>/dev/null
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function renew_user() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              RENEW ZIVPN USER${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    read -p "   Password / Username : " password
    read -p "   Tambah hari         : " days
    
    if [[ -z "$password" || -z "$days" ]]; then
        echo -e "${RED}   Password dan Days harus diisi!${NC}"
        echo ""
        read -p "   Tekan Enter untuk kembali..."
        return
    fi
    
    python3 << PYTHON
import json
from datetime import datetime, timedelta

with open("$ZIVPN_USERS", "r") as f:
    users = json.load(f)

for u in users:
    if u.get("password") == "$password":
        current_exp = u.get("expired", datetime.now().strftime("%Y-%m-%d"))
        new_exp = datetime.strptime(current_exp, "%Y-%m-%d") + timedelta(days=$days)
        u["expired"] = new_exp.strftime("%Y-%m-%d")
        u["status"] = "active"
        if "is_trial" in u:
            del u["is_trial"]

with open("$ZIVPN_USERS", "w") as f:
    json.dump(users, f, indent=4)

with open("$ZIVPN_CONFIG", "r") as f:
    config = json.load(f)
if "$password" not in config["auth"]["config"]:
    config["auth"]["config"].append("$password")
with open("$ZIVPN_CONFIG", "w") as f:
    json.dump(config, f, indent=4)
PYTHON
    
    echo -e "${Green}   ✅ User berhasil diperpanjang!${NC}"
    systemctl restart zivpn 2>/dev/null
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function list_users() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              ZIVPN USER LIST${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    
    python3 << PYTHON
import json
from datetime import datetime

today = datetime.now().strftime("%Y-%m-%d")

try:
    with open("$ZIVPN_USERS", "r") as f:
        users = json.load(f)
except:
    users = []

if not users:
    print("   Tidak ada user terdaftar")
else:
    print(f"   {'Username':<15} {'Expired':<12} {'Status':<10} {'IP Limit':<8} {'Trial':<6}")
    print("   " + "-" * 60)
    for u in users:
        pwd = u.get("password", "-")[:15]
        exp = u.get("expired", "-")
        iplimit = u.get("ip_limit", 0)
        status = u.get("status", "active")
        is_trial = "Yes" if u.get("is_trial", False) else "No"
        
        if exp < today and status != "locked":
            status = "expired"
        
        if status == "active":
            status_display = "Active"
        elif status == "locked":
            status_display = "Locked"
        else:
            status_display = "Expired"
        
        print(f"   {pwd:<15} {exp:<12} {status_display:<10} {iplimit:<8} {is_trial:<6}")
PYTHON
    
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function install_bot() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              INSTALL TELEGRAM BOT${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    
    if [ -f "/etc/systemd/system/zivpn-bot.service" ]; then
        echo -e "${YELLOW}   Bot sudah terinstall!${NC}"
        read -p "   Reinstall? (y/n): " reinstall
        if [[ "$reinstall" != "y" ]]; then
            echo ""
            read -p "   Tekan Enter untuk kembali..."
            return
        fi
        systemctl stop zivpn-bot.service 2>/dev/null
    fi
    
    echo ""
    read -p "   Bot Token : " bot_token
    read -p "   Admin ID  : " admin_id
    
    if [[ -z "$bot_token" ]] || [[ -z "$admin_id" ]]; then
        echo -e "${RED}   Bot Token dan Admin ID harus diisi!${NC}"
        echo ""
        read -p "   Tekan Enter untuk kembali..."
        return
    fi
    
    echo ""
    echo -e "${CYAN}   Select Bot Type:${NC}"
    echo -e "   ${Green}1${NC}) Free (Admin Only / Public Mode)"
    echo -e "   ${Green}2${NC}) Paid (Pakasir Payment Gateway)"
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
        bot_type_name="Paid (Pakasir)"
    else
        read -p "   Bot Mode (public/private) [default: private]: " bot_mode
        bot_mode=${bot_mode:-private}
        
        echo "{\"bot_token\": \"$bot_token\", \"admin_id\": $admin_id, \"mode\": \"$bot_mode\", \"domain\": \"$domain\"}" > /etc/zivpn/bot-config.json
        bot_file="zivpn-bot.go"
        bot_type_name="Free"
    fi
    
    echo ""
    echo -e "${YELLOW}   Downloading Bot...${NC}"
    wget -q ${GITHUB_REPO}/$bot_file -O /etc/zivpn/api/$bot_file
    
    cd /etc/zivpn/api
    echo -e "${YELLOW}   Installing dependencies...${NC}"
    go get github.com/go-telegram-bot-api/telegram-bot-api/v5
    
    echo -e "${YELLOW}   Compiling Bot...${NC}"
    if go build -o zivpn-bot "$bot_file" &>/dev/null; then
        echo -e "${Green}   ✅ Bot compiled successfully!${NC}"
        
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
        
        systemctl daemon-reload
        systemctl enable zivpn-bot.service
        systemctl start zivpn-bot.service
        
        echo -e "${Green}   ✅ Bot installed and started!${NC}"
        echo ""
        echo -e "${CYAN}   Bot Type: $bot_type_name${NC}"
        echo -e "${CYAN}   Bot Token: $bot_token${NC}"
        echo -e "${CYAN}   Admin ID: $admin_id${NC}"
    else
        echo -e "${RED}   ✗ Failed to compile bot!${NC}"
    fi
    
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function install_pakasir() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              INSTALL PAKASIR BOT${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    
    if [ -f "/etc/systemd/system/zivpn-bot.service" ]; then
        echo -e "${YELLOW}   Bot sudah terinstall! Akan diupdate ke Pakasir version${NC}"
        systemctl stop zivpn-bot.service 2>/dev/null
    fi
    
    echo ""
    read -p "   Bot Token : " bot_token
    read -p "   Admin ID  : " admin_id
    read -p "   Pakasir Project Slug: " pakasir_slug
    read -p "   Pakasir API Key     : " pakasir_key
    read -p "   Daily Price (IDR)   : " daily_price
    read -p "   Default IP Limit    : " ip_limit
    ip_limit=${ip_limit:-1}
    
    if [[ -z "$bot_token" ]] || [[ -z "$admin_id" ]] || [[ -z "$pakasir_slug" ]] || [[ -z "$pakasir_key" ]] || [[ -z "$daily_price" ]]; then
        echo -e "${RED}   Semua field harus diisi!${NC}"
        echo ""
        read -p "   Tekan Enter untuk kembali..."
        return
    fi
    
    echo "{\"bot_token\": \"$bot_token\", \"admin_id\": $admin_id, \"mode\": \"public\", \"domain\": \"$domain\", \"pakasir_slug\": \"$pakasir_slug\", \"pakasir_api_key\": \"$pakasir_key\", \"daily_price\": $daily_price, \"default_ip_limit\": $ip_limit}" > /etc/zivpn/bot-config.json
    
    echo ""
    echo -e "${YELLOW}   Downloading Pakasir Bot...${NC}"
    wget -q ${GITHUB_REPO}/zivpn-paid-bot.go -O /etc/zivpn/api/zivpn-paid-bot.go
    
    cd /etc/zivpn/api
    echo -e "${YELLOW}   Installing dependencies...${NC}"
    go get github.com/go-telegram-bot-api/telegram-bot-api/v5
    
    echo -e "${YELLOW}   Compiling Bot...${NC}"
    if go build -o zivpn-bot zivpn-paid-bot.go &>/dev/null; then
        echo -e "${Green}   ✅ Pakasir Bot compiled successfully!${NC}"
        
        cat <<EOF > /etc/systemd/system/zivpn-bot.service
[Unit]
Description=ZiVPN Pakasir Telegram Bot
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
        
        systemctl daemon-reload
        systemctl enable zivpn-bot.service
        systemctl start zivpn-bot.service
        
        echo -e "${Green}   ✅ Pakasir Bot installed and started!${NC}"
        echo ""
        echo -e "${CYAN}   Bot Token: $bot_token${NC}"
        echo -e "${CYAN}   Admin ID: $admin_id${NC}"
        echo -e "${CYAN}   Pakasir Slug: $pakasir_slug${NC}"
        echo -e "${CYAN}   Daily Price: Rp $daily_price${NC}"
        echo -e "${CYAN}   IP Limit: $ip_limit${NC}"
    else
        echo -e "${RED}   ✗ Failed to compile Pakasir bot!${NC}"
    fi
    
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function restart_service() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              RESTART SERVICE${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${YELLOW}   Restarting ZiVPN service...${NC}"
    systemctl restart zivpn 2>/dev/null
    systemctl restart zivpn-api 2>/dev/null
    if systemctl is-active --quiet zivpn-bot 2>/dev/null; then
        systemctl restart zivpn-bot 2>/dev/null
    fi
    sleep 2
    echo -e "${Green}   ✅ All services restarted successfully${NC}"
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function service_status() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              SERVICE STATUS${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${WHITE}   ZiVPN Core:${NC}"
    systemctl status zivpn --no-pager -l 2>/dev/null | head -10
    echo ""
    echo -e "${WHITE}   ZiVPN API:${NC}"
    systemctl status zivpn-api --no-pager -l 2>/dev/null | head -10
    if systemctl is-active --quiet zivpn-bot 2>/dev/null; then
        echo ""
        echo -e "${WHITE}   ZiVPN Bot:${NC}"
        systemctl status zivpn-bot --no-pager -l 2>/dev/null | head -10
    fi
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function Select_Display() {
    echo
    read -p "   Select option [1-10 or x] : " hallo
    case $hallo in
        1) create_user ;;
        2) create_random_user ;;
        3) delete_user ;;
        4) renew_user ;;
        5) list_users ;;
        6) trial_user ;;
        7) install_bot ;;
        8) install_pakasir ;;
        9) restart_service ;;
        10) service_status ;;
        x|X) 
            clear
            exit 0 
            ;;
        *) 
            echo -e "${RED}   Invalid option${NC}"
            sleep 1
            ;;
    esac
}

# ==================== MAIN ====================
CEKIP
Zivpn_Banner
Service_System_Operating
Service_Status
License_Info
Acces_Use_Command
Select_Display