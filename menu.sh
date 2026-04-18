cat > menu.sh << 'EOF'
#!/bin/bash

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

# Get server info
MYIP=$(curl -sS ipv4.icanhazip.com 2>/dev/null)
domain=$(cat /etc/xray/domain 2>/dev/null || cat /etc/zivpn/domain 2>/dev/null || echo "Tidak ada")
ISP=$(cat /etc/xray/isp 2>/dev/null || echo "Unknown")
CITY=$(cat /etc/xray/city 2>/dev/null || echo "Unknown")
DATEVPS=$(date +'%d/%m/%Y')
TIMEZONE=$(date +'%H:%M:%S')
MODEL=$(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')
SERONLINE=$(uptime -p | cut -d " " -f 2-10000)

# ZiVPN Config
ZIVPN_CONFIG="/etc/zivpn/config.json"
ZIVPN_USERS="/etc/zivpn/users.json"
ZIVPN_DOMAIN="/etc/zivpn/domain"
ZIVPN_PORT="5667"

function check_zivpn_status() {
    if systemctl is-active --quiet zivpn 2>/dev/null; then
        echo -e "${Green}ON${NC}"
    elif pgrep -x "zivpn" > /dev/null; then
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

function get_total_users() {
    if [ -f "$ZIVPN_USERS" ]; then
        python3 -c "import json; print(len(json.load(open('$ZIVPN_USERS'))))" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

function get_active_users() {
    if [ -f "$ZIVPN_USERS" ]; then
        python3 -c "import json; from datetime import datetime; today=datetime.now().strftime('%Y-%m-%d'); data=json.load(open('$ZIVPN_USERS')); print(len([x for x in data if x.get('status')=='active' and x.get('expired','')>=today]))" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

function Zivpn_Banner() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE}  \033[38;5;196m⁙\033[38;5;202m⁙\033[38;5;208m⁙\033[38;5;214m⁙\033[38;5;220m⁙\033[38;5;226m⁙\033[38;5;190m⁙\033[38;5;154m⁙\033[38;5;118m⁙\033[38;5;82m⁙\033[38;5;46m⁙\033[38;5;47m⁙\033[38;5;48m⁙\033[38;5;49m⁙${WHITE} ZIVPN MANAGER \033[38;5;87m⁙\033[38;5;86m⁙\033[38;5;85m⁙\033[38;5;84m⁙\033[38;5;83m⁙\033[38;5;44m⁙\033[38;5;43m⁙\033[38;5;42m⁙\033[38;5;41m⁙\033[38;5;40m⁙\033[38;5;39m⁙\033[38;5;38m⁙\033[38;5;37m⁙\033[38;5;36m⁙${WHITE}   ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

function Service_System_Operating() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE} SYSTEM OS       : $MODEL ${NC}"
    echo -e "${BLUE}│${WHITE} UPTIME SERVER   : $SERONLINE ${NC}"
    echo -e "${BLUE}│${WHITE} IP VPS          : $MYIP ${NC}"
    echo -e "${BLUE}│${WHITE} ISP             : $ISP - $CITY ${NC}"
    echo -e "${BLUE}│${WHITE} DOMAIN          : $domain ${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

function Service_Status() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}|${NC}${YELLOW} ZIVPN : $(check_zivpn_status) ${BLUE}|${NC}${YELLOW} API : $(check_api_status) ${BLUE}|${NC}${YELLOW} PORT : $ZIVPN_PORT ${BLUE}|${NC}${YELLOW} USERS : $(get_total_users) (Active: $(get_active_users)) ${BLUE}| ${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

function Details_Clients_Name() {
    echo -e "${BLUE}   ┌───────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}   │${WHITE} VERSION    : $(cat /opt/.ver 2>/dev/null || echo "1.0")    ${NC}"
    echo -e "${BLUE}   │${WHITE} STATUS     :\033[92;1m (active)    ${NC}"
    echo -e "${BLUE}   │${WHITE} CLIENTS    :\033[91;1m $(cat /usr/bin/user 2>/dev/null || echo "PX_STORE")      ${NC}"
    echo -e "${BLUE}   │${WHITE} EXPIRY     : $(cat /usr/bin/e 2>/dev/null || echo "Lifetime") Day ${NC}"
    echo -e "${BLUE}   └───────────────────────────────────────────┘${NC}"
}

function Acces_Use_Command() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│  ${WHITE}1.${NC})${Green} Create ZiVPN User     ${BLUE}  5.${NC})${Green} View Config${RESET}          ${BLUE}│${NC}"
    echo -e "${BLUE}│  ${WHITE}2.${NC})${Green} Delete ZiVPN User     ${BLUE}  6.${NC})${Green} Change Domain${RESET}        ${BLUE}│${NC}"
    echo -e "${BLUE}│  ${WHITE}3.${NC})${Green} Renew ZiVPN User      ${BLUE}  7.${NC})${Green} Restart Service${RESET}      ${BLUE}│${NC}"
    echo -e "${BLUE}│  ${WHITE}4.${NC})${Green} List ZiVPN Users      ${BLUE}  8.${NC})${Green} Service Status${RESET}      ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo -e "${BLUE}  ┌───────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │  ${RED}x.${NC})${RED} Exit / Back to Main Menu${NC}                               ${BLUE}│${NC}"
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
        sleep 2
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
    echo -e "   Domain   : ${YELLOW}$(cat $ZIVPN_DOMAIN 2>/dev/null)${NC}"
    
    systemctl restart zivpn 2>/dev/null
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
        sleep 2
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
    print(f"   {'Username':<15} {'Expired':<12} {'Status':<10} {'IP Limit':<8}")
    print("   " + "-" * 50)
    for u in users:
        pwd = u.get("password", "-")[:15]
        exp = u.get("expired", "-")
        iplimit = u.get("ip_limit", 0)
        status = u.get("status", "active")
        
        if exp < today and status != "locked":
            status = "expired"
        
        if status == "active":
            status_display = "Active"
        elif status == "locked":
            status_display = "Locked"
        else:
            status_display = "Expired"
        
        print(f"   {pwd:<15} {exp:<12} {status_display:<10} {iplimit:<8}")
PYTHON
    
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function view_config() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              ZIVPN CONFIGURATION${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${WHITE}   Config file: $ZIVPN_CONFIG${NC}"
    echo ""
    cat $ZIVPN_CONFIG | python3 -m json.tool 2>/dev/null || cat $ZIVPN_CONFIG
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function change_domain() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              CHANGE DOMAIN${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    current=$(cat $ZIVPN_DOMAIN 2>/dev/null || echo "Not set")
    echo -e "   Current domain: ${CYAN}$current${NC}"
    echo ""
    read -p "   New domain: " new_domain
    
    if [[ -n "$new_domain" ]]; then
        echo "$new_domain" > $ZIVPN_DOMAIN
        echo -e "${Green}   ✅ Domain updated to: $new_domain${NC}"
        
        # Regenerate SSL
        openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/CN=$new_domain" -keyout /etc/zivpn/zivpn.key -out /etc/zivpn/zivpn.crt 2>/dev/null
        systemctl restart zivpn 2>/dev/null
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
    pkill -x zivpn 2>/dev/null
    sleep 1
    if systemctl start zivpn 2>/dev/null; then
        echo -e "${Green}   ✅ Service restarted successfully${NC}"
    elif [ -f /usr/local/bin/zivpn ]; then
        nohup /usr/local/bin/zivpn server -c $ZIVPN_CONFIG > /dev/null 2>&1 &
        echo -e "${Green}   ✅ ZiVPN restarted manually${NC}"
    else
        echo -e "${RED}   ❌ Failed to restart service${NC}"
    fi
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
    systemctl status zivpn --no-pager -l 2>/dev/null | head -20
    echo ""
    read -p "   Tekan Enter untuk kembali..."
}

function Select_Display() {
    echo
    read -p "   Select option [1-8 or x] : " hallo
    case $hallo in
        1) create_user ;;
        2) delete_user ;;
        3) renew_user ;;
        4) list_users ;;
        5) view_config ;;
        6) change_domain ;;
        7) restart_service ;;
        8) service_status ;;
        x|X) menu ;;
        *) echo -e "${RED}   Invalid option${NC}"; sleep 1 ;;
    esac
}

# Main execution
Zivpn_Banner
Service_System_Operating
Service_Status
Details_Clients_Name
Acces_Use_Command
Select_Display
EOF

chmod +x menu.sh