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

# Variables
MYIP=$(curl -sS ipv4.icanhazip.com)
IPVPS=$(curl -s ipv4.icanhazip.com)
domain=$(cat /etc/zivpn/domain 2>/dev/null || echo "Not Set")
UDP_PORT=$(grep -oP '"listen":":\K[0-9]+' /etc/zivpn/config.json 2>/dev/null || echo "5667")
API_PORT=$(grep -oP 'Port = ":\K[0-9]+' /etc/zivpn/api/zivpn-api.go 2>/dev/null || echo "8585")
api_key=$(cat /etc/zivpn/apikey 2>/dev/null || echo "Not Set")
RAM=$(free -m | awk 'NR==2 {print $2}')
USAGERAM=$(free -m | awk 'NR==2 {print $3}')
MEMOFREE=$(printf '%-1s' "$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')")
LOADCPU=$(printf '%-0.00001s' "$(top -bn1 | awk '/Cpu/ { cpu = "" 100 - $8 "%" }; END { print cpu }')")
CPU=$(awk -F: '/model name/ {name=$2; exit} END {print name}' /proc/cpuinfo | sed 's/^ //')
CORES=$(awk -F: '/model name/ {c++} END {print c}' /proc/cpuinfo)
VENDOR=$(awk -F: '/vendor_id/ {vendor=$2; exit} END {print vendor}' /proc/cpuinfo | sed 's/^ //')
DATEVPS=$(date +'%d/%m/%Y')
TIMEZONE=$(printf '%(%H:%M:%S)T')
MODEL=$(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')
SERONLINE=$(uptime -p | cut -d " " -f 2-10000)

# Service Status
zivpn_service=$(systemctl status zivpn | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1 2>/dev/null)
zivpn_api_service=$(systemctl status zivpn-api | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1 2>/dev/null)

if [[ $zivpn_service == "running" ]]; then
    status_zivpn="\033[92;1m● RUNNING${NC}"
else
    status_zivpn="\033[91;1m○ DEAD${NC}"
fi

if [[ $zivpn_api_service == "running" ]]; then
    status_api="\033[92;1m● RUNNING${NC}"
else
    status_api="\033[91;1m○ DEAD${NC}"
fi

# User Count
user_count=$(cat /etc/zivpn/users.json 2>/dev/null | grep -o '"username"' | wc -l || echo "0")

function Xwan_Banner() {
clear
echo -e "\033[36;1m┌─────────────────────────────────────────────────┐\033[0m"
echo -e "\033[36;1m│\e[97m  \033[38;5;196m⁙\033[38;5;202m⁙\033[38;5;208m⁙\033[38;5;214m⁙\033[38;5;220m⁙\033[38;5;226m⁙\033[38;5;190m⁙\033[38;5;154m⁙\033[38;5;118m⁙\033[38;5;82m⁙\033[38;5;46m⁙\033[38;5;47m⁙\033[38;5;48m⁙\033[38;5;49m⁙\033[97m ZiVPN MANAGER \033[38;5;87m⁙\033[38;5;86m⁙\033[38;5;85m⁙\033[38;5;84m⁙\033[38;5;83m⁙\033[38;5;44m⁙\033[38;5;43m⁙\033[38;5;42m⁙\033[38;5;41m⁙\033[38;5;40m⁙\033[38;5;39m⁙\033[38;5;38m⁙\033[38;5;37m⁙\033[38;5;36m⁙\033[97m   \033[36;1m│\033[0m"
echo -e "\033[36;1m└─────────────────────────────────────────────────┘\033[0m"
}

function Service_System_Operating() {
echo -e "\033[36;1m┌─────────────────────────────────────────────────┐\033[0m "
echo -e "\033[36;1m│\e[97m SYSTEM OS       : $MODEL \033[0m "
echo -e "\033[36;1m│\e[97m CPU             : $VENDOR $CORES CORE \033[0m "
echo -e "\033[36;1m│\e[97m SERVER RAM      : $(free -m | awk 'NR==2 {print $3}')/$RAM MB  \033[0m "
echo -e "\033[36;1m│\e[97m UPTIME SERVER   : $SERONLINE \033[0m "
echo -e "\033[36;1m│\e[97m IP VPS          : $IPVPS \033[0m "
echo -e "\033[36;1m│\e[97m DOMAIN          : $domain \033[0m "
echo -e "\033[36;1m│\e[97m UDP PORT        : $UDP_PORT \033[0m "
echo -e "\033[36;1m│\e[97m API PORT        : $API_PORT \033[0m "
echo -e "\033[36;1m└─────────────────────────────────────────────────┘\033[0m"
}

function Service_Status() {
echo -e "\033[36;1m┌─────────────────────────────────────────────────┐\033[0m "
echo -e "\033[36;1m│\e[0m\033[33;1m ZIVPN CORE  :\e[0m $status_zivpn     \033[36;1m│\e[0m\033[33;1m API SERVER :\e[0m $status_api     \033[36;1m│\e[0m\033[33;1m TOTAL USER :\e[0m $user_count      \033[36;1m│\e[0m "
echo -e "\033[36;1m└─────────────────────────────────────────────────┘\033[96;1m "
}

function Details_Clients_Name() {
echo -e "\033[36;1m   ┌───────────────────────────────────────────┐\033[0m "
echo -e "\033[36;1m   │\e[97m VERSION    : ZiVPN 1.4.9              \033[0m "
echo -e "\033[36;1m   │\e[97m STATUS     :\033[92;1m (active)           \033[0m "
echo -e "\033[36;1m   │\e[97m API KEY    : ${api_key:0:16}... \033[0m "
echo -e "\033[36;1m   │\e[97m DATE       : $DATEVPS \033[0m "
echo -e "\033[36;1m   └───────────────────────────────────────────┘\033[0m "
}

function Acces_Use_Command() {
echo -e "${BLUE}┌─────────────────────────────────────────────────┐\033[0m "
echo -e "${BLUE}│  1.)\e[93m☞ \e[97m ADD USER           ${BLUE}6.${BLUE})\e[93m☞ \e[97m USER LIST       ${BLUE}│\e[0m"
echo -e "${BLUE}│  2.)\e[93m☞ \e[97m DELETE USER        ${BLUE}7.${BLUE})\e[93m☞ \e[97m RESTART SERVICE  ${BLUE}│\e[0m"
echo -e "${BLUE}│  3.)\e[93m☞ \e[97m EXTEND USER        ${BLUE}8.${BLUE})\e[93m☞ \e[97m CHECK LOGS       ${BLUE}│\e[0m"
echo -e "${BLUE}│  4.)\e[93m☞ \e[97m LOCK/UNLOCK USER   ${BLUE}9.${BLUE})\e[93m☞ \e[97m REBOOT SYSTEM    ${BLUE}│\e[0m"
echo -e "${BLUE}│  5.)\e[93m☞ \e[97m VIEW CONFIG        ${BLUE}10.${BLUE})\e[93m☞ \e[97m CHANGE DOMAIN    ${BLUE}│\e[0m"
echo -e "${BLUE}│      \e[97m                     ${RED}x.${BLUE})\e[93m☞ \e[91m EXIT MENU        ${BLUE}│\e[0m"
echo -e "${BLUE}└─────────────────────────────────────────────────┘\033[0m"
}

function Select_Display() {
echo
read -p "Select From option [1/10 or x] :  " hallo
case $hallo in
1) clear ; add_user ;;
2) clear ; delete_user ;;
3) clear ; extend_user ;;
4) clear ; lock_unlock_user ;;
5) clear ; view_config ;;
6) clear ; user_list ;;
7) clear ; restart_service ;;
8) clear ; check_logs ;;
9) clear ; reboot ;;
10) clear ; change_domain ;;
x|X) clear ; exit 0 ;;
*) menu ;;
esac
}

# ==================== FUNCTIONS ====================

add_user() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${Green}              ADD NEW USER${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    read -p "   Username: " username
    read -p "   Password: " password
    read -p "   Duration (days): " days
    echo ""
    
    response=$(curl -s -X POST "http://localhost:$API_PORT/api/users" \
        -H "Content-Type: application/json" \
        -H "X-API-Key: $api_key" \
        -d "{\"username\":\"$username\",\"password\":\"$password\",\"days\":$days}")
    
    if [[ $response == *"success"* ]]; then
        echo -e "${Green}   ✓ User added successfully!${NC}"
    else
        echo -e "${RED}   ✗ Failed to add user${NC}"
    fi
    sleep 2
    menu
}

delete_user() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${RED}              DELETE USER${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    read -p "   Username: " username
    echo ""
    
    response=$(curl -s -X DELETE "http://localhost:$API_PORT/api/users/$username" \
        -H "X-API-Key: $api_key")
    
    if [[ $response == *"success"* ]]; then
        echo -e "${Green}   ✓ User deleted successfully!${NC}"
    else
        echo -e "${RED}   ✗ Failed to delete user${NC}"
    fi
    sleep 2
    menu
}

extend_user() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${YELLOW}              EXTEND USER${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    read -p "   Username: " username
    read -p "   Add days: " days
    echo ""
    
    response=$(curl -s -X PUT "http://localhost:$API_PORT/api/users/$username/extend" \
        -H "Content-Type: application/json" \
        -H "X-API-Key: $api_key" \
        -d "{\"days\":$days}")
    
    if [[ $response == *"success"* ]]; then
        echo -e "${Green}   ✓ User extended successfully!${NC}"
    else
        echo -e "${RED}   ✗ Failed to extend user${NC}"
    fi
    sleep 2
    menu
}

lock_unlock_user() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${YELLOW}              LOCK/UNLOCK USER${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    read -p "   Username: " username
    read -p "   Action (lock/unlock): " action
    echo ""
    
    response=$(curl -s -X PUT "http://localhost:$API_PORT/api/users/$username/$action" \
        -H "X-API-Key: $api_key")
    
    if [[ $response == *"success"* ]]; then
        echo -e "${Green}   ✓ User $action successfully!${NC}"
    else
        echo -e "${RED}   ✗ Failed to $action user${NC}"
    fi
    sleep 2
    menu
}

view_config() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${CYAN}              VIEW CONFIG${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    read -p "   Username: " username
    echo ""
    
    response=$(curl -s "http://localhost:$API_PORT/api/users/$username/config" \
        -H "X-API-Key: $api_key")
    
    echo -e "${Green}   Configuration for $username:${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "$response" | jq -r '.config // .' 2>/dev/null || echo "$response"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -p "   Press Enter to continue..."
    menu
}

user_list() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${CYAN}              USER LIST${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    
    response=$(curl -s "http://localhost:$API_PORT/api/users" \
        -H "X-API-Key: $api_key")
    
    echo -e "${Green}   Active Users:${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "$response" | jq -r '.[] | "   • \(.username) - Exp: \(.expired) - Status: \(.status)"' 2>/dev/null || echo "$response"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -p "   Press Enter to continue..."
    menu
}

restart_service() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${YELLOW}              RESTART SERVICE${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    
    systemctl restart zivpn
    systemctl restart zivpn-api
    
    echo -e "${Green}   ✓ Services restarted successfully!${NC}"
    sleep 2
    menu
}

check_logs() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${CYAN}              CHECK LOGS${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${Green}   Last 20 lines of ZiVPN log:${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    journalctl -u zivpn -n 20 --no-pager
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -p "   Press Enter to continue..."
    menu
}

change_domain() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${YELLOW}              CHANGE DOMAIN${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    read -p "   New Domain: " new_domain
    
    if [[ -n "$new_domain" ]]; then
        echo "$new_domain" > /etc/zivpn/domain
        openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/CN=$new_domain" -keyout /etc/zivpn/zivpn.key -out /etc/zivpn/zivpn.crt 2>/dev/null
        systemctl restart zivpn
        echo -e "${Green}   ✓ Domain changed and SSL regenerated!${NC}"
    else
        echo -e "${RED}   ✗ Invalid domain${NC}"
    fi
    sleep 2
    menu
}

menu() {
    Xwan_Banner
    Service_System_Operating
    Service_Status
    Details_Clients_Name
    Acces_Use_Command
    Select_Display
}

# Start menu
menu