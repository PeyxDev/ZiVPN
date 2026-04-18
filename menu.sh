#!/bin/bash

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BG_BLUE='\033[44;1m'
BG_GREEN='\033[42;1m'
BG_RED='\033[41;1m'
NC='\033[0m'
BOLD='\033[1m'

# Animation Characters
SPINNER=("⣷" "⣯" "⣟" "⡿" "⢿" "⣻" "⣽" "⣾")

# Get system information
MYIP=$(curl -sS ipv4.icanhazip.com)
domain=$(cat /etc/zivpn/domain 2>/dev/null || echo "Tidak ada")
ISP=$(curl -s ipinfo.io/org 2>/dev/null | cut -d " " -f 2-10)
if [[ -z "$ISP" ]]; then ISP="Unknown"; fi
CITY=$(curl -s ipinfo.io/city 2>/dev/null)
if [[ -z "$CITY" ]]; then CITY="Unknown"; fi
MODEL=$(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')
SERONLINE=$(uptime -p | cut -d " " -f 2-10000)
nama=$(cat /etc/xray/username 2>/dev/null || echo "PeyxDev")
ZIVPN_PORT="5667"
ZIVPN_API_PORT="8585"
ZIVPN_CONFIG="/etc/zivpn/config.json"
ZIVPN_USERS="/etc/zivpn/users.json"
API_KEY=$(cat /etc/zivpn/apikey 2>/dev/null)

# Bot configuration
KEY=$(grep -E "^#bot# " "/etc/bot/.bot.db" 2>/dev/null | head -n1 | cut -d ' ' -f 2 || echo "")
CHATIDS=$(grep -E "^#bot# " "/etc/bot/.bot.db" 2>/dev/null | cut -d ' ' -f 3 || echo "")
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"

# Transaction bot
CHATID2=$(grep -E "^#bottrx# " "/etc/bottrx/.bottrx.db" 2>/dev/null | cut -d ' ' -f 3 || echo "")
KEY2=$(grep -E "^#bottrx# " "/etc/bottrx/.bottrx.db" 2>/dev/null | cut -d ' ' -f 2 || echo "")
URL2="https://api.telegram.org/bot$KEY2/sendMessage"

# Trial configuration
TRIAL_DURATION_MINUTES=30
TRIAL_IP_LIMIT=1

# Loading animation
show_loading() {
    local text=$1
    echo -ne "${CYAN}${text} ${NC}"
    for i in {1..3}; do
        for char in "${SPINNER[@]}"; do
            echo -ne "\r${CYAN}${text} $char ${NC}"
            sleep 0.1
        done
    done
    echo -ne "\r${GREEN}${text} ✓ ${NC}"
    echo
}

# Generate random password
generate_random_password() {
    echo $(openssl rand -hex 8)
}

# Check trial limit per IP
check_trial_limit() {
    local client_ip=$1
    local trial_limit=3
    
    if [ -f "/etc/zivpn/trial_ips.log" ]; then
        trial_count=$(grep -c "$client_ip" /etc/zivpn/trial_ips.log 2>/dev/null || echo "0")
        if [ "$trial_count" -ge "$trial_limit" ]; then
            return 1
        fi
    fi
    return 0
}

# Log trial IP
log_trial_ip() {
    local client_ip=$1
    local password=$2
    echo "$client_ip|$password|$(date '+%Y-%m-%d %H:%M:%S')" >> /etc/zivpn/trial_ips.log
}

# Function to check service status
check_zivpn_status() {
    if systemctl is-active --quiet zivpn 2>/dev/null; then
        echo -e "${GREEN}ON${NC}"
    else
        echo -e "${RED}OFF${NC}"
    fi
}

check_api_status() {
    if systemctl is-active --quiet zivpn-api 2>/dev/null; then
        echo -e "${GREEN}ON${NC}"
    else
        echo -e "${RED}OFF${NC}"
    fi
}

get_total_users() {
    if [ -f "$ZIVPN_USERS" ]; then
        python3 -c "import json; print(len(json.load(open('$ZIVPN_USERS'))))" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_trial_users() {
    if [ -f "$ZIVPN_USERS" ]; then
        python3 -c "import json; from datetime import datetime; now=datetime.now().strftime('%Y-%m-%d %H:%M:%S'); data=json.load(open('$ZIVPN_USERS')); print(len([x for x in data if x.get('type') == 'trial' and x.get('expired_datetime', '') > now]))" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Banner
Zivpn_Banner() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE}  \033[38;5;196m⁙\033[38;5;202m⁙\033[38;5;208m⁙\033[38;5;214m⁙\033[38;5;220m⁙\033[38;5;226m⁙\033[38;5;190m⁙\033[38;5;154m⁙\033[38;5;118m⁙\033[38;5;82m⁙\033[38;5;46m⁙\033[38;5;47m⁙\033[38;5;48m⁙\033[38;5;49m⁙${WHITE} ZIVPN MANAGER \033[38;5;87m⁙\033[38;5;86m⁙\033[38;5;85m⁙\033[38;5;84m⁙\033[38;5;83m⁙\033[38;5;44m⁙\033[38;5;43m⁙\033[38;5;42m⁙\033[38;5;41m⁙\033[38;5;40m⁙\033[38;5;39m⁙\033[38;5;38m⁙\033[38;5;37m⁙\033[38;5;36m⁙${WHITE}    ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

# System Info
Service_System_Operating() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE} SYSTEM OS       : $MODEL ${NC}"
    echo -e "${BLUE}│${WHITE} UPTIME SERVER   : $SERONLINE ${NC}"
    echo -e "${BLUE}│${WHITE} IP VPS          : $MYIP ${NC}"
    echo -e "${BLUE}│${WHITE} ISP             : $ISP ${NC}"
    echo -e "${BLUE}│${WHITE} CITY            : $CITY ${NC}"
    echo -e "${BLUE}│${WHITE} DOMAIN          : $domain ${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

# Service Status
Service_Status() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}|${NC}${YELLOW} ZIVPN : $(check_zivpn_status) ${BLUE}|${NC}${YELLOW} API : $(check_api_status) ${BLUE}|${NC}${YELLOW} PORT : $ZIVPN_PORT ${BLUE}|${NC}${YELLOW} USERS : $(get_total_users) (Trial: $(get_trial_users)) ${BLUE}| ${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

# API Info
API_Info() {
    if [ -f "/etc/zivpn/apikey" ]; then
        echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
        echo -e "${BLUE}│${WHITE} API PORT       : $ZIVPN_API_PORT ${NC}"
        echo -e "${BLUE}│${WHITE} API KEY        : ${YELLOW}${API_KEY}${NC}"
        echo -e "${BLUE}│${WHITE} API URL        : ${CYAN}http://$MYIP:$ZIVPN_API_PORT${NC}"
        echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    fi
}

# Client Details
Details_Clients_Name() {
    echo -e "${BLUE}   ┌───────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}   │${WHITE} CLIENTS    : $(cat /usr/bin/user 2>/dev/null || echo "PX_STORE")      ${NC}"
    echo -e "${BLUE}   │${WHITE} EXPIRY     : $(cat /usr/bin/e 2>/dev/null || echo "Lifetime") Day ${NC}"
    echo -e "${BLUE}   └───────────────────────────────────────────┘${NC}"
}

# Menu Options
Acces_Use_Command() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│  ${WHITE}1.${NC})${Green} Create Premium User  ${BLUE}  5.${NC})${Green} List Users${RESET}         ${BLUE}│${NC}"
    echo -e "${BLUE}│  ${WHITE}2.${NC})${Green} Create Trial User    ${BLUE}  6.${NC})${Green} View Config${RESET}        ${BLUE}│${NC}"
    echo -e "${BLUE}│  ${WHITE}3.${NC})${Green} Delete User          ${BLUE}  7.${NC})${Green} Change Domain${RESET}      ${BLUE}│${NC}"
    echo -e "${BLUE}│  ${WHITE}4.${NC})${Green} Renew User           ${BLUE}  8.${NC})${Green} Restart Service${RESET}    ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo -e "${BLUE}  ┌───────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │  ${RED}x.${NC})${RED} Exit / Back to Main Menu${NC}                               ${BLUE}│${NC}"
    echo -e "${BLUE}  └───────────────────────────────────────────────┘${NC}"
}

# Clean expired trials
clean_expired_trials() {
    python3 << PYTHON
import json
from datetime import datetime

users_file = "$ZIVPN_USERS"
config_file = "$ZIVPN_CONFIG"
now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

try:
    with open(users_file, "r") as f:
        users = json.load(f)
except:
    users = []

modified = False
for u in users:
    if u.get("type") == "trial" and u.get("status") == "active":
        exp_datetime = u.get("expired_datetime", "")
        if exp_datetime and exp_datetime < now:
            u["status"] = "expired"
            modified = True
            try:
                with open(config_file, "r") as f:
                    config = json.load(f)
                if u["password"] in config["auth"]["config"]:
                    config["auth"]["config"].remove(u["password"])
                with open(config_file, "w") as f:
                    json.dump(config, f, indent=4)
            except:
                pass

if modified:
    with open(users_file, "w") as f:
        json.dump(users, f, indent=4)
PYTHON
}

# ==================== CREATE PREMIUM USER ====================
create_premium_user() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              CREATE PREMIUM USER${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    read -p "   Password / Username : " password
    read -p "   Days (masa aktif)   : " days
    read -p "   IP Limit (0=unlimited) : " iplimit
    
    if [[ -z "$password" || -z "$days" ]]; then
        echo -e "${RED}   Password dan Days harus diisi!${NC}"
        sleep 2
        return
    fi
    
    exp_date=$(date -d "+$days days" +%Y-%m-%d)
    tgl=$(date -d "+$days days" +"%d")
    bln=$(date -d "+$days days" +"%b")
    thn=$(date -d "+$days days" +"%Y")
    expe="$tgl $bln, $thn"
    tgl2=$(date +"%d")
    bln2=$(date +"%b")
    thn2=$(date +"%Y")
    tnggl="$tgl2 $bln2, $thn2"
    
    show_loading "Creating premium account"
    
    python3 << PYTHON
import json
from datetime import datetime

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
    "type": "premium",
    "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
})
with open("$ZIVPN_USERS", "w") as f:
    json.dump(users, f, indent=4)
PYTHON
    
    systemctl restart zivpn 2>/dev/null
    
    show_loading "Sending notifications"
    
    # Telegram notification
    TEXT="
<code>────────────────────────────────</code>
<b> 🔥 ZIVPN PREMIUM ACCOUNT </b>
<code>────────────────────────────────</code>
<code>Password         : </code> <code>$password</code>
<code>IP Limit         : </code> <code>${iplimit:-0}</code>
<code>────────────────────────────────</code>
<code>Host             : </code> <code>$domain</code>
<code>Port             : </code> <code>$ZIVPN_PORT (UDP)</code>
<code>Protocol         : </code> <code>UDP</code>
<code>Obfs             : </code> <code>zivpn</code>
<code>────────────────────────────────</code>
<code>Connection String:</code>
<code>Server : $domain:$ZIVPN_PORT</code>
<code>Password: $password</code>
<code>────────────────────────────────</code>
<b>⏰ ACCOUNT INFORMATION</b>
<code>────────────────────────────────</code>
<code>Dibuat Pada      : $tnggl</code>
<code>Berakhir Pada    : $expe</code>
<code>Durasi           : $days Days</code>
<code>────────────────────────────────</code>
"
    
    for CHATID in $CHATIDS; do
        curl -s --max-time "$TIME" \
            -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" \
            "$URL" >/dev/null
    done

    TEXT2="
<b>-----------------------------------------</b>
   <b>TRANSAKSI BERHASIL</b>
<b>-----------------------------------------</b>
<b>» Produk : ZiVPN Premium</b>
<b>» ISP :</b> ${ISP}
<b>» Domain :</b> ${domain}
<b>» Region :</b> ${CITY}
<b>» Password :</b> ${password}
<b>» Durasi :</b> ${days} Hari
<b>» IP Limit :</b> ${iplimit:-0} Devices
<b>» Dibuat   :</b> ${tnggl}
<b>» Berakhir :</b> ${expe}
<b>-----------------------------------------</b>
<i>Automatic Notification From Server...</i>"
    
    curl -s --max-time $TIME -X POST "$URL2" \
         -d "chat_id=$CHATID2" \
         -d "disable_web_page_preview=1" \
         -d "parse_mode=html" \
         --data-urlencode "text=$TEXT2" \
         --data-urlencode 'reply_markup={"inline_keyboard":[[{"text":"🔥 ORDER","url":"https://t.me/PeyxDev"},{"text":"💬 SUPPORT","url":"https://t.me/pxstoree"}]]}' >/dev/null
    
    clear
    echo -e "${GREEN}✅ Premium user created successfully!${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}Password         ${WHITE}: ${GREEN}$password${NC}"
    echo -e "${CYAN}IP Limit         ${WHITE}: ${YELLOW}${iplimit:-0} Device(s)${NC}"
    echo -e "${CYAN}Domain           ${WHITE}: ${GREEN}$domain${NC}"
    echo -e "${CYAN}Port             ${WHITE}: ${GREEN}$ZIVPN_PORT${NC}"
    echo -e "${CYAN}Expired          ${WHITE}: ${YELLOW}$expe${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
    echo -e "\n${GREEN}📢 Notifications sent to Telegram!${NC}"
    echo -e "\n${CYAN}Press Enter to continue...${NC}"
    read -n 1 -s
}

# ==================== CREATE TRIAL USER ====================
create_trial_user() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              CREATE TRIAL USER${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    
    client_ip=$(echo $SSH_CLIENT | awk '{print $1}')
    if [[ -z "$client_ip" ]]; then
        client_ip=$(curl -s ipv4.icanhazip.com 2>/dev/null)
    fi
    
    if ! check_trial_limit "$client_ip"; then
        echo -e "${RED}❌ Error: Trial limit reached! (Max 3 trials per IP)${NC}"
        echo -e "\n${CYAN}Press Enter to continue...${NC}"
        read -n 1 -s
        return
    fi
    
    trial_password=$(generate_random_password)
    exp_datetime=$(date -d "+${TRIAL_DURATION_MINUTES} minutes" +"%Y-%m-%d %H:%M:%S")
    exp_date=$(date -d "+${TRIAL_DURATION_MINUTES} minutes" +"%Y-%m-%d")
    tgl=$(date -d "+${TRIAL_DURATION_MINUTES} minutes" +"%d")
    bln=$(date -d "+${TRIAL_DURATION_MINUTES} minutes" +"%b")
    thn=$(date -d "+${TRIAL_DURATION_MINUTES} minutes" +"%Y")
    expe="$tgl $bln, $thn - $exp_datetime"
    tgl2=$(date +"%d")
    bln2=$(date +"%b")
    thn2=$(date +"%Y")
    tnggl="$tgl2 $bln2, $thn2"
    
    show_loading "Creating trial account"
    
    python3 << PYTHON
import json
from datetime import datetime

with open("$ZIVPN_CONFIG", "r") as f:
    config = json.load(f)
if "$trial_password" not in config["auth"]["config"]:
    config["auth"]["config"].append("$trial_password")
with open("$ZIVPN_CONFIG", "w") as f:
    json.dump(config, f, indent=4)

try:
    with open("$ZIVPN_USERS", "r") as f:
        users = json.load(f)
except:
    users = []

users.append({
    "password": "$trial_password",
    "expired": "$exp_date",
    "expired_datetime": "$exp_datetime",
    "ip_limit": $TRIAL_IP_LIMIT,
    "status": "active",
    "type": "trial",
    "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "client_ip": "$client_ip"
})

with open("$ZIVPN_USERS", "w") as f:
    json.dump(users, f, indent=4)
PYTHON
    
    log_trial_ip "$client_ip" "$trial_password"
    systemctl restart zivpn 2>/dev/null
    
    show_loading "Sending notifications"
    
    TEXT="
<code>────────────────────────────────</code>
<b> 🚀 ZIVPN TRIAL ACCOUNT </b>
<code>────────────────────────────────</code>
<code>Password         : </code> <code>$trial_password</code>
<code>IP Limit         : </code> <code>$TRIAL_IP_LIMIT</code>
<code>────────────────────────────────</code>
<code>Host             : </code> <code>$domain</code>
<code>Port             : </code> <code>$ZIVPN_PORT (UDP)</code>
<code>Protocol         : </code> <code>UDP</code>
<code>Obfs             : </code> <code>zivpn</code>
<code>────────────────────────────────</code>
<code>Connection String:</code>
<code>Server : $domain:$ZIVPN_PORT</code>
<code>Password: $trial_password</code>
<code>────────────────────────────────</code>
<b>⏰ TRIAL INFORMATION</b>
<code>────────────────────────────────</code>
<code>Dibuat Pada      : $tnggl - $(date +%H:%M:%S)</code>
<code>Berakhir Pada    : $expe</code>
<code>Durasi           : $TRIAL_DURATION_MINUTES Minutes</code>
<code>────────────────────────────────</code>
<i>⚠️ Trial will expire automatically after $TRIAL_DURATION_MINUTES minutes!</i>
"
    
    for CHATID in $CHATIDS; do
        curl -s --max-time "$TIME" \
            -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" \
            "$URL" >/dev/null
    done

    TEXT2="
<b>-----------------------------------------</b>
   <b>TRANSAKSI TRIAL BERHASIL</b>
<b>-----------------------------------------</b>
<b>» Produk : ZiVPN Trial</b>
<b>» ISP :</b> ${ISP}
<b>» Domain :</b> ${domain}
<b>» Region :</b> ${CITY}
<b>» Client IP :</b> ${client_ip}
<b>» Password :</b> ${trial_password}
<b>» Durasi :</b> ${TRIAL_DURATION_MINUTES} Menit
<b>» IP Limit :</b> ${TRIAL_IP_LIMIT} Devices
<b>» Dibuat   :</b> ${tnggl}
<b>» Berakhir :</b> ${expe}
<b>-----------------------------------------</b>
<i>Automatic Notification From Server...</i>"
    
    curl -s --max-time $TIME -X POST "$URL2" \
         -d "chat_id=$CHATID2" \
         -d "disable_web_page_preview=1" \
         -d "parse_mode=html" \
         --data-urlencode "text=$TEXT2" \
         --data-urlencode 'reply_markup={"inline_keyboard":[[{"text":"🔥 ORDER PREMIUM","url":"https://t.me/PeyxDev"},{"text":"💬 SUPPORT","url":"https://t.me/pxstoree"}]]}' >/dev/null
    
    clear
    echo -e "${GREEN}✅ Trial user created successfully!${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}Password         ${WHITE}: ${GREEN}$trial_password${NC}"
    echo -e "${CYAN}IP Limit         ${WHITE}: ${YELLOW}$TRIAL_IP_LIMIT Device(s)${NC}"
    echo -e "${CYAN}Domain           ${WHITE}: ${GREEN}$domain${NC}"
    echo -e "${CYAN}Port             ${WHITE}: ${GREEN}$ZIVPN_PORT${NC}"
    echo -e "${CYAN}Expired          ${WHITE}: ${YELLOW}$expe${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
    echo -e "\n${GREEN}📢 Notifications sent to Telegram!${NC}"
    echo -e "${YELLOW}⚠️ This trial will expire in $TRIAL_DURATION_MINUTES minutes${NC}"
    echo -e "${YELLOW}🔔 Remaining trials for this IP: $((3 - $(grep -c "$client_ip" /etc/zivpn/trial_ips.log 2>/dev/null || echo 0)))${NC}"
    echo -e "\n${CYAN}Press Enter to continue...${NC}"
    read -n 1 -s
}

# ==================== DELETE USER ====================
delete_user() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              DELETE USER${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    read -p "   Password / Username : " password
    
    show_loading "Deleting user"
    
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
    echo -e "${GREEN}✅ User deleted successfully!${NC}"
    echo -e "\n${CYAN}Press Enter to continue...${NC}"
    read -n 1 -s
}

# ==================== RENEW USER ====================
renew_user() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              RENEW USER${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    read -p "   Password / Username : " password
    read -p "   Add days            : " days
    
    if [[ -z "$password" || -z "$days" ]]; then
        echo -e "${RED}   Password dan Days harus diisi!${NC}"
        sleep 2
        return
    fi
    
    show_loading "Renewing user"
    
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
        if u.get("type") == "trial":
            u["type"] = "premium"
            # Remove expired_datetime for premium
            if "expired_datetime" in u:
                del u["expired_datetime"]

with open("$ZIVPN_USERS", "w") as f:
    json.dump(users, f, indent=4)

with open("$ZIVPN_CONFIG", "r") as f:
    config = json.load(f)
if "$password" not in config["auth"]["config"]:
    config["auth"]["config"].append("$password")
with open("$ZIVPN_CONFIG", "w") as f:
    json.dump(config, f, indent=4)
PYTHON
    
    systemctl restart zivpn 2>/dev/null
    echo -e "${GREEN}✅ User renewed successfully!${NC}"
    echo -e "\n${CYAN}Press Enter to continue...${NC}"
    read -n 1 -s
}

# ==================== LIST USERS ====================
list_users() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              USER LIST${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    
    python3 << PYTHON
import json
from datetime import datetime

today = datetime.now().strftime("%Y-%m-%d")
now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

try:
    with open("$ZIVPN_USERS", "r") as f:
        users = json.load(f)
except:
    users = []

if not users:
    print("   Tidak ada user terdaftar")
else:
    print(f"   {'Password':<20} {'Expired':<20} {'Status':<10} {'Type':<10} {'IP Limit':<8}")
    print("   " + "-" * 75)
    for u in users:
        pwd = u.get("password", "-")[:20]
        exp = u.get("expired", "-")
        exp_datetime = u.get("expired_datetime", exp)
        iplimit = u.get("ip_limit", 0)
        status = u.get("status", "active")
        user_type = u.get("type", "premium")
        
        if user_type == "trial":
            if exp_datetime < now and status != "locked":
                status = "expired"
        else:
            if exp < today and status != "locked":
                status = "expired"
        
        if status == "active":
            status_display = "Active"
        elif status == "locked":
            status_display = "Locked"
        else:
            status_display = "Expired"
        
        display_exp = exp_datetime if user_type == "trial" else exp
        print(f"   {pwd:<20} {display_exp:<20} {status_display:<10} {user_type:<10} {iplimit:<8}")
PYTHON
    
    echo ""
    read -p "   Press Enter to continue..."
}

# ==================== VIEW CONFIG ====================
view_config() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              CONFIGURATION${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    cat $ZIVPN_CONFIG | python3 -m json.tool 2>/dev/null || cat $ZIVPN_CONFIG
    echo ""
    read -p "   Press Enter to continue..."
}

# ==================== CHANGE DOMAIN ====================
change_domain() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              CHANGE DOMAIN${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    current=$(cat /etc/zivpn/domain 2>/dev/null || echo "Not set")
    echo -e "   Current domain: ${CYAN}$current${NC}"
    echo ""
    read -p "   New domain: " new_domain
    
    if [[ -n "$new_domain" ]]; then
        echo "$new_domain" > /etc/zivpn/domain
        openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/CN=$new_domain" -keyout /etc/zivpn/zivpn.key -out /etc/zivpn/zivpn.crt 2>/dev/null
        systemctl restart zivpn 2>/dev/null
        domain=$new_domain
        echo -e "${GREEN}✅ Domain updated to: $new_domain${NC}"
    fi
    echo ""
    read -p "   Press Enter to continue..."
}

# ==================== RESTART SERVICE ====================
restart_service() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              RESTART SERVICE${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${YELLOW}   Restarting ZiVPN service...${NC}"
    systemctl restart zivpn 2>/dev/null
    sleep 2
    echo -e "${GREEN}✅ Service restarted successfully${NC}"
    echo ""
    read -p "   Press Enter to continue..."
}

# ==================== SERVICE STATUS ====================
service_status() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              SERVICE STATUS${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    systemctl status zivpn --no-pager -l 2>/dev/null | head -20
    echo ""
    read -p "   Press Enter to continue..."
}

# ==================== MAIN MENU ====================
Select_Display() {
    echo
    read -p "   Select option [1-8 or x] : " hallo
    case $hallo in
        1) create_premium_user ;;
        2) create_trial_user ;;
        3) delete_user ;;
        4) renew_user ;;
        5) list_users ;;
        6) view_config ;;
        7) change_domain ;;
        8) restart_service ;;
        9) service_status ;;
        x|X) exit 0 ;;
        *) echo -e "${RED}   Invalid option${NC}"; sleep 1 ;;
    esac
}

# ==================== MAIN EXECUTION ====================
clean_expired_trials
Zivpn_Banner
Service_System_Operating
Service_Status
API_Info
Details_Clients_Name
Acces_Use_Command
Select_Display