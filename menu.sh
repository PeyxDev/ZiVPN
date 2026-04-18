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
GITHUB_API_REPO="https://api.github.com/repos/PeyxDev/ZiVPN/contents/backup"
GITHUB_TOKEN_FILE="/etc/zivpn/github_token"
BACKUP_DIR="/root/zivpn_backups"

# ==================== CEK IP & EXPIRED ====================
CEKIP() {
    IPLIST=$(curl -sS https://raw.githubusercontent.com/PeyxDev/esce/main/ipx)
    IPVPS=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $4}')
    USERNAME=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $2}')
    EXPIRED=$(echo "$IPLIST" | grep "$MYIP" | awk '{print $3}')
    
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
        status_exp="\033[92;1mActive\033[0m"
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
        status_exp="\033[92;1mActive\033[0m"
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

function generate_random_id() {
    echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 15 | head -n 1)
}

# ==================== TELEGRAM NOTIFICATION FUNCTION ====================
function send_telegram_notification() {
    local action="$1"
    local username="$2"
    local expired="$3"
    local iplimit="$4"
    local domain_info="$5"
    
    local bot_config="/etc/zivpn/bot-config.json"
    
    if [ -f "$bot_config" ]; then
        local bot_token=$(python3 -c "import json; f=open('$bot_config'); d=json.load(f); print(d.get('bot_token', '')); f.close()" 2>/dev/null)
        local admin_id=$(python3 -c "import json; f=open('$bot_config'); d=json.load(f); print(d.get('admin_id', '')); f.close()" 2>/dev/null)
        
        if [ -n "$bot_token" ] && [ -n "$admin_id" ] && [ "$admin_id" != "None" ] && [ "$admin_id" != "" ]; then
            local message=""
            local datetime_now=$(date '+%Y-%m-%d %H:%M:%S')
            
            case "$action" in
                "create")
                    message="🔐 *USER CREATED* 🔐
                    
━━━━━━━━━━━━━━━━━━━━
👤 *Username:* \`$username\`
📅 *Expired:* $expired
🌐 *IP Limit:* $iplimit
🏷️ *Domain:* $domain_info
⏰ *Time:* $datetime_now
━━━━━━━━━━━━━━━━━━━━
✅ User has been successfully created!"
                    ;;
                "create_random")
                    message="🎲 *RANDOM USER CREATED* 🎲
                    
━━━━━━━━━━━━━━━━━━━━
👤 *Username:* \`$username\`
📅 *Expired:* $expired
🌐 *IP Limit:* $iplimit
🏷️ *Domain:* $domain_info
⏰ *Time:* $datetime_now
━━━━━━━━━━━━━━━━━━━━
✅ Random user has been successfully created!"
                    ;;
                "trial")
                    message="⏱️ *TRIAL USER CREATED* ⏱️
                    
━━━━━━━━━━━━━━━━━━━━
👤 *Username:* \`$username\`
⏰ *Expired:* $expired (30 minutes)
🌐 *IP Limit:* $iplimit
🏷️ *Domain:* $domain_info
⏰ *Time:* $datetime_now
━━━━━━━━━━━━━━━━━━━━
🎫 Trial user will expire in 30 minutes!"
                    ;;
                "renew")
                    message="🔄 *USER RENEWED* 🔄
                    
━━━━━━━━━━━━━━━━━━━━
👤 *Username:* \`$username\`
📅 *New Expired:* $expired
🌐 *IP Limit:* $iplimit
🏷️ *Domain:* $domain_info
⏰ *Time:* $datetime_now
━━━━━━━━━━━━━━━━━━━━
✅ User has been successfully renewed!"
                    ;;
                "delete")
                    message="🗑️ *USER DELETED* 🗑️
                    
━━━━━━━━━━━━━━━━━━━━
👤 *Username:* \`$username\`
⏰ *Time:* $datetime_now
━━━━━━━━━━━━━━━━━━━━
❌ User has been removed from system!"
                    ;;
                "backup")
                    message="💾 *BACKUP CREATED* 💾
                    
━━━━━━━━━━━━━━━━━━━━
🆔 *Backup ID:* \`$username\`
📦 *File:* $username.zip
📅 *Date:* $datetime_now
━━━━━━━━━━━━━━━━━━━━
✅ Backup has been created successfully!"
                    ;;
                "restore")
                    message="🔄 *RESTORE COMPLETED* 🔄
                    
━━━━━━━━━━━━━━━━━━━━
🆔 *Backup ID:* \`$username\`
📅 *Date:* $datetime_now
━━━━━━━━━━━━━━━━━━━━
✅ System has been restored from backup!"
                    ;;
                "upload")
                    message="☁️ *BACKUP UPLOADED* ☁️
                    
━━━━━━━━━━━━━━━━━━━━
🆔 *Backup ID:* \`$username\`
📦 *File:* $username.zip
🌐 *Repository:* PeyxDev/ZiVPN/backup
📅 *Date:* $datetime_now
━━━━━━━━━━━━━━━━━━━━
✅ Backup has been uploaded to GitHub successfully!"
                    ;;
            esac
            
            curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
                -d "chat_id=${admin_id}" \
                -d "text=${message}" \
                -d "parse_mode=markdown" \
                -d "disable_web_page_preview=true" > /dev/null 2>&1
        fi
    fi
}

function Zivpn_Banner() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE}  \033[38;5;196m⁙\033[38;5;202m⁙\033[38;5;208m⁙\033[38;5;214m⁙\033[38;5;220m⁙\033[38;5;226m⁙\033[38;5;190m⁙\033[38;5;154m⁙\033[38;5;118m⁙\033[38;5;82m⁙\033[38;5;46m⁙\033[38;5;47m⁙\033[38;5;48m⁙\033[38;5;49m⁙${WHITE} PX ZIVPN MANAGER \033[38;5;87m⁙\033[38;5;86m⁙\033[38;5;85m⁙\033[38;5;84m⁙\033[38;5;83m⁙\033[38;5;44m⁙\033[38;5;43m⁙\033[38;5;42m⁙\033[38;5;41m⁙\033[38;5;40m⁙\033[38;5;39m⁙\033[38;5;38m⁙\033[38;5;37m⁙\033[38;5;36m⁙${WHITE} ${BLUE}│${NC}"
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
    echo -e "${BLUE}│${WHITE} API KEY         : ${API_KEY}${NC}"
    echo -e "${BLUE}│${WHITE} API URL         : http://$MYIP:$ZIVPN_API_PORT${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
}

function Service_Status() {
    if [ -f "/etc/systemd/system/zivpn-bot.service" ]; then
        BOT_STATUS="$(check_bot_status)"
    else
        BOT_STATUS="OFF"
    fi
    
    ZIVPN_STATUS=$(check_zivpn_status)
    API_STATUS=$(check_api_status)
    TOTAL_USERS=$(get_total_users)
    
    printf "${BLUE}┌─────────────────────────────────────────────────┐${NC}\n"
    printf "${BLUE}|  ${NC}${YELLOW}ZIVPN: %2s${NC}  ${BLUE}|  ${NC}${YELLOW}API: %2s${NC}  ${BLUE}|  ${NC}${YELLOW}BOT: %2s${NC} ${BLUE}| ${NC}${YELLOW}USERS: %1s${NC}  ${BLUE}|${NC}\n" "$ZIVPN_STATUS" "$API_STATUS" "$BOT_STATUS" "$TOTAL_USERS"
    printf "${BLUE}└─────────────────────────────────────────────────┘${NC}\n"
}

function Details_Clients_Name() {
    echo -e "${BLUE}   ┌───────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}   │${WHITE} CLIENTS    : ${USERNAME:-Unknown}${NC}"
    echo -e "${BLUE}   │${WHITE} STATUS     : ${status_exp}${NC}"
    echo -e "${BLUE}   │${WHITE} EXPIRY     : ${masaaktif}${NC}"
    echo -e "${BLUE}   └───────────────────────────────────────────┘${NC}"
}

function Acces_Use_Command() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│  01.${NC})${WHITE} Create User        ${BLUE}  06.${NC})${WHITE} Trial 30 Menit${RESET}  ${BLUE}│${NC}"
    echo -e "${BLUE}│  02.${NC})${WHITE} Create Random PW   ${BLUE}  07.${NC})${WHITE} Install Bot${RESET}     ${BLUE}│${NC}"
    echo -e "${BLUE}│  03.${NC})${WHITE} Delete User        ${BLUE}  08.${NC})${WHITE} Install Pakasir${RESET} ${BLUE}│${NC}"
    echo -e "${BLUE}│  04.${NC})${WHITE} Renew User         ${BLUE}  09.${NC})${WHITE} Restart Service${RESET} ${BLUE}│${NC}"
    echo -e "${BLUE}│  05.${NC})${WHITE} List Users         ${BLUE}  10.${NC})${WHITE} Service Status${RESET}  ${BLUE}│${NC}"
    echo -e "${BLUE}├─────────────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│  11.${NC})${WHITE} Backup             ${BLUE}  14.${NC})${WHITE} Set GitHub Token${RESET} ${BLUE}│${NC}"
    echo -e "${BLUE}│  12.${NC})${WHITE} Restore            ${BLUE}  15.${NC})${WHITE} Ganti Token${RESET}     ${BLUE}│${NC}"
    echo -e "${BLUE}│  13.${NC})${WHITE} Upload Backup      ${BLUE}  16.${NC})${WHITE} Hapus Token${RESET}     ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
    echo -e "${BLUE} ┌───────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE} │  ${RED}x.${NC})${RED} Exit${NC}                                     ${BLUE}│${NC}"
    echo -e "${BLUE} └───────────────────────────────────────────────┘${NC}"
}

# ==================== BACKUP FUNCTIONS ====================
function create_backup() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              CREATE BACKUP${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    
    mkdir -p "$BACKUP_DIR"
    
    backup_id=$(generate_random_id)
    backup_file="${BACKUP_DIR}/${backup_id}.zip"
    
    echo -e "${CYAN}   Backup ID: ${YELLOW}$backup_id${NC}"
    echo ""
    echo -e "${YELLOW}   Creating backup...${NC}"
    
    zip -j "$backup_file" /etc/zivpn/config.json /etc/zivpn/users.json /etc/zivpn/apikey /etc/zivpn/domain 2>/dev/null
    
    if [ -f "/etc/zivpn/bot-config.json" ]; then
        zip -j "$backup_file" /etc/zivpn/bot-config.json 2>/dev/null
    fi
    
    zip -j "$backup_file" /etc/systemd/system/zivpn.service /etc/systemd/system/zivpn-api.service 2>/dev/null
    
    if [ -f "$backup_file" ]; then
        backup_size=$(du -h "$backup_file" | cut -f1)
        echo -e "${Green}   ✅ Backup created successfully!${NC}"
        echo ""
        echo -e "${CYAN}   Backup Details:${NC}"
        echo -e "   ID     : ${YELLOW}$backup_id${NC}"
        echo -e "   File   : ${YELLOW}$backup_file${NC}"
        echo -e "   Size   : ${YELLOW}$backup_size${NC}"
        echo -e "   Date   : ${YELLOW}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
        
        send_telegram_notification "backup" "$backup_id" "" "" ""
    else
        echo -e "${RED}   ✗ Failed to create backup!${NC}"
    fi
    
    echo ""
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
}

function restore_backup() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              RESTORE BACKUP${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${CYAN}   Masukkan Backup ID (15 karakter random):${NC}"
    read -p "   Backup ID : " backup_id
    
    if [[ -z "$backup_id" ]]; then
        echo -e "${RED}   Backup ID harus diisi!${NC}"
        echo ""
        read -p "   Tekan Enter untuk kembali ke menu..."
        return
    fi
    
    backup_file="${BACKUP_DIR}/${backup_id}.zip"
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${YELLOW}   Backup tidak ditemukan di lokal, mencoba download dari GitHub...${NC}"
        
        local github_token=$(cat $GITHUB_TOKEN_FILE 2>/dev/null)
        if [ -z "$github_token" ]; then
            echo -e "${RED}   GitHub token belum diatur! Silakan set token terlebih dahulu (Menu 14)${NC}"
            echo ""
            read -p "   Tekan Enter untuk kembali ke menu..."
            return
        fi
        
        wget -q "https://raw.githubusercontent.com/PeyxDev/ZiVPN/main/backup/${backup_id}.zip" -O "$backup_file"
        
        if [ ! -f "$backup_file" ] || [ ! -s "$backup_file" ]; then
            echo -e "${RED}   ✗ Backup dengan ID '$backup_id' tidak ditemukan!${NC}"
            rm -f "$backup_file"
            echo ""
            read -p "   Tekan Enter untuk kembali ke menu..."
            return
        fi
    fi
    
    echo -e "${YELLOW}   Restoring backup...${NC}"
    
    mkdir -p "${BACKUP_DIR}/restore_backup_$(date +%Y%m%d_%H%M%S)"
    
    systemctl stop zivpn 2>/dev/null
    systemctl stop zivpn-api 2>/dev/null
    systemctl stop zivpn-bot 2>/dev/null
    
    unzip -o "$backup_file" -d /tmp/zivpn_restore/ 2>/dev/null
    
    if [ -f "/tmp/zivpn_restore/config.json" ]; then
        cp /tmp/zivpn_restore/config.json /etc/zivpn/config.json
    fi
    
    if [ -f "/tmp/zivpn_restore/users.json" ]; then
        cp /tmp/zivpn_restore/users.json /etc/zivpn/users.json
    fi
    
    if [ -f "/tmp/zivpn_restore/apikey" ]; then
        cp /tmp/zivpn_restore/apikey /etc/zivpn/apikey
    fi
    
    if [ -f "/tmp/zivpn_restore/domain" ]; then
        cp /tmp/zivpn_restore/domain /etc/zivpn/domain
        domain=$(cat /etc/zivpn/domain 2>/dev/null || echo "Tidak ada")
    fi
    
    if [ -f "/tmp/zivpn_restore/bot-config.json" ]; then
        cp /tmp/zivpn_restore/bot-config.json /etc/zivpn/bot-config.json
    fi
    
    if [ -f "/tmp/zivpn_restore/zivpn.service" ]; then
        cp /tmp/zivpn_restore/zivpn.service /etc/systemd/system/zivpn.service
    fi
    
    if [ -f "/tmp/zivpn_restore/zivpn-api.service" ]; then
        cp /tmp/zivpn_restore/zivpn-api.service /etc/systemd/system/zivpn-api.service
    fi
    
    rm -rf /tmp/zivpn_restore
    
    systemctl daemon-reload
    systemctl restart zivpn 2>/dev/null
    systemctl restart zivpn-api 2>/dev/null
    if systemctl is-active --quiet zivpn-bot 2>/dev/null; then
        systemctl restart zivpn-bot 2>/dev/null
    fi
    
    echo -e "${Green}   ✅ Restore completed successfully!${NC}"
    echo ""
    echo -e "${CYAN}   Restored from: ${YELLOW}$backup_id${NC}"
    
    send_telegram_notification "restore" "$backup_id" "" "" ""
    
    echo ""
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
}

function upload_backup() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              UPLOAD BACKUP TO GITHUB${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    
    local github_token=$(cat $GITHUB_TOKEN_FILE 2>/dev/null)
    if [ -z "$github_token" ]; then
        echo -e "${RED}   GitHub token belum diatur!${NC}"
        echo -e "${YELLOW}   Silakan set token terlebih dahulu (Menu 14 atau 15)${NC}"
        echo ""
        read -p "   Tekan Enter untuk kembali ke menu..."
        return
    fi
    
    echo -e "${CYAN}   Available local backups:${NC}"
    echo ""
    local backups=()
    local i=1
    
    if [ -d "$BACKUP_DIR" ]; then
        for file in "$BACKUP_DIR"/*.zip; do
            if [ -f "$file" ]; then
                filename=$(basename "$file" .zip)
                filesize=$(du -h "$file" | cut -f1)
                filedate=$(stat -c %y "$file" | cut -d' ' -f1)
                echo -e "   ${Green}$i${NC}) ${YELLOW}$filename${NC} - ${filesize} (${filedate})"
                backups+=("$filename")
                ((i++))
            fi
        done
    fi
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}   Tidak ada backup ditemukan! Buat backup terlebih dahulu (Menu 11)${NC}"
        echo ""
        read -p "   Tekan Enter untuk kembali ke menu..."
        return
    fi
    
    echo ""
    read -p "   Pilih nomor backup [1-${#backups[@]}] : " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
        echo -e "${RED}   Pilihan tidak valid!${NC}"
        echo ""
        read -p "   Tekan Enter untuk kembali ke menu..."
        return
    fi
    
    backup_id="${backups[$((choice-1))]}"
    backup_file="${BACKUP_DIR}/${backup_id}.zip"
    
    echo ""
    echo -e "${YELLOW}   Uploading ${backup_id}.zip to GitHub...${NC}"
    
    file_content_base64=$(base64 -w 0 "$backup_file")
    
    sha_response=$(curl -s -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/PeyxDev/ZiVPN/contents/backup/${backup_id}.zip")
    
    sha=$(echo "$sha_response" | grep -o '"sha": "[^"]*' | cut -d'"' -f4)
    
    if [ -n "$sha" ]; then
        json_payload=$(cat <<EOF
{
  "message": "Update backup ${backup_id}",
  "content": "${file_content_base64}",
  "sha": "${sha}"
}
EOF
)
    else
        json_payload=$(cat <<EOF
{
  "message": "Upload backup ${backup_id}",
  "content": "${file_content_base64}"
}
EOF
)
    fi
    
    response=$(curl -s -X PUT \
        -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "$json_payload" \
        "https://api.github.com/repos/PeyxDev/ZiVPN/contents/backup/${backup_id}.zip")
    
    if echo "$response" | grep -q '"content":'; then
        echo -e "${Green}   ✅ Backup successfully uploaded to GitHub!${NC}"
        echo ""
        echo -e "${CYAN}   Upload Details:${NC}"
        echo -e "   Repository : ${YELLOW}PeyxDev/ZiVPN${NC}"
        echo -e "   Path       : ${YELLOW}backup/${backup_id}.zip${NC}"
        echo -e "   Backup ID  : ${YELLOW}$backup_id${NC}"
        
        send_telegram_notification "upload" "$backup_id" "" "" ""
    else
        echo -e "${RED}   ✗ Failed to upload backup to GitHub!${NC}"
        error_msg=$(echo "$response" | grep -o '"message": "[^"]*' | cut -d'"' -f4)
        if [ -n "$error_msg" ]; then
            echo -e "${RED}   Error: $error_msg${NC}"
        fi
    fi
    
    echo ""
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
}

function set_github_token() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              SET GITHUB TOKEN${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${CYAN}   Untuk upload backup ke GitHub, Anda perlu Personal Access Token${NC}"
    echo -e "${CYAN}   Cara mendapatkan token:${NC}"
    echo -e "   ${WHITE}1. Buka https://github.com/settings/tokens${NC}"
    echo -e "   ${WHITE}2. Klik 'Generate new token (classic)'${NC}"
    echo -e "   ${WHITE}3. Beri nama token (contoh: ZiVPN-Backup)${NC}"
    echo -e "   ${WHITE}4. Centang scope 'repo'${NC}"
    echo -e "   ${WHITE}5. Generate dan copy token${NC}"
    echo ""
    
    if [ -f "$GITHUB_TOKEN_FILE" ]; then
        current_token=$(cat "$GITHUB_TOKEN_FILE")
        echo -e "${YELLOW}   Token saat ini: ${current_token:0:10}...${current_token: -10}${NC}"
        echo ""
        read -p "   Ganti token? (y/n): " change
        if [[ "$change" != "y" ]]; then
            echo ""
            read -p "   Tekan Enter untuk kembali ke menu..."
            return
        fi
    fi
    
    echo ""
    read -p "   Masukkan GitHub Token: " github_token
    
    if [[ -z "$github_token" ]]; then
        echo -e "${RED}   Token tidak boleh kosong!${NC}"
        echo ""
        read -p "   Tekan Enter untuk kembali ke menu..."
        return
    fi
    
    echo -e "${YELLOW}   Testing token...${NC}"
    test_response=$(curl -s -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user")
    
    if echo "$test_response" | grep -q '"login":'; then
        echo "$github_token" > "$GITHUB_TOKEN_FILE"
        echo -e "${Green}   ✅ Token saved successfully!${NC}"
        
        mkdir -p "$BACKUP_DIR"
        touch "$BACKUP_DIR/.gitkeep"
        
        gitkeep_base64=$(echo -n "" | base64 -w 0)
        json_payload=$(cat <<EOF
{
  "message": "Create backup directory",
  "content": "${gitkeep_base64}"
}
EOF
)
        curl -s -X PUT \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github.v3+json" \
            -d "$json_payload" \
            "https://api.github.com/repos/PeyxDev/ZiVPN/contents/backup/.gitkeep" > /dev/null 2>&1
        
        echo ""
        echo -e "${Green}   Token has been set and tested successfully!${NC}"
    else
        echo -e "${RED}   ✗ Invalid token! Please check your token.${NC}"
    fi
    
    echo ""
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
}

function change_github_token() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              GANTI GITHUB TOKEN${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    
    if [ ! -f "$GITHUB_TOKEN_FILE" ]; then
        echo -e "${YELLOW}   Belum ada token yang disimpan.${NC}"
        echo -e "${YELLOW}   Silakan set token baru.${NC}"
        echo ""
        set_github_token
        return
    fi
    
    current_token=$(cat "$GITHUB_TOKEN_FILE")
    echo -e "${CYAN}   Token saat ini: ${YELLOW}${current_token:0:15}...${current_token: -15}${NC}"
    echo ""
    echo -e "${RED}   ⚠️  PERINGATAN: Mengganti token akan menghapus token lama!${NC}"
    echo ""
    read -p "   Lanjutkan mengganti token? (y/n): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        echo ""
        read -p "   Tekan Enter untuk kembali ke menu..."
        return
    fi
    
    echo ""
    echo -e "${CYAN}   Masukkan GitHub Token BARU:${NC}"
    echo -e "${YELLOW}   (Token harus memiliki scope 'repo')${NC}"
    read -p "   Token Baru: " new_token
    
    if [[ -z "$new_token" ]]; then
        echo -e "${RED}   Token tidak boleh kosong!${NC}"
        echo ""
        read -p "   Tekan Enter untuk kembali ke menu..."
        return
    fi
    
    echo ""
    echo -e "${YELLOW}   Menguji token baru...${NC}"
    
    test_response=$(curl -s -H "Authorization: token $new_token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user")
    
    if echo "$test_response" | grep -q '"login":'; then
        # Backup token lama sebelum diganti
        if [ -f "$GITHUB_TOKEN_FILE" ]; then
            old_token=$(cat "$GITHUB_TOKEN_FILE")
            echo "# Token lama diganti pada $(date '+%Y-%m-%d %H:%M:%S')" >> "${GITHUB_TOKEN_FILE}.old"
            echo "$old_token" >> "${GITHUB_TOKEN_FILE}.old"
        fi
        
        # Simpan token baru
        echo "$new_token" > "$GITHUB_TOKEN_FILE"
        
        echo -e "${Green}   ✅ Token berhasil diganti!${NC}"
        echo ""
        echo -e "${CYAN}   Token baru: ${YELLOW}${new_token:0:15}...${new_token: -15}${NC}"
        
        # Test upload capability
        echo -e "${YELLOW}   Menguji akses upload...${NC}"
        test_file_content=$(echo -n "test" | base64 -w 0)
        test_payload=$(cat <<EOF
{
  "message": "Test upload permission",
  "content": "${test_file_content}"
}
EOF
)
        test_upload=$(curl -s -X PUT \
            -H "Authorization: token $new_token" \
            -H "Accept: application/vnd.github.v3+json" \
            -d "$test_payload" \
            "https://api.github.com/repos/PeyxDev/ZiVPN/contents/backup/test.txt" 2>/dev/null)
        
        if echo "$test_upload" | grep -q '"content":'; then
            echo -e "${Green}   ✅ Token memiliki akses upload yang valid!${NC}"
            # Hapus file test
            test_sha=$(echo "$test_upload" | grep -o '"sha": "[^"]*' | cut -d'"' -f4)
            if [ -n "$test_sha" ]; then
                delete_payload=$(cat <<EOF
{
  "message": "Remove test file",
  "sha": "${test_sha}"
}
EOF
)
                curl -s -X DELETE \
                    -H "Authorization: token $new_token" \
                    -H "Accept: application/vnd.github.v3+json" \
                    -d "$delete_payload" \
                    "https://api.github.com/repos/PeyxDev/ZiVPN/contents/backup/test.txt" > /dev/null 2>&1
            fi
        else
            echo -e "${YELLOW}   ⚠️  Peringatan: Token mungkin tidak memiliki akses upload penuh${NC}"
        fi
    else
        echo -e "${RED}   ✗ Token tidak valid! Token tidak diganti.${NC}"
        error_detail=$(echo "$test_response" | grep -o '"message": "[^"]*' | cut -d'"' -f4)
        if [ -n "$error_detail" ]; then
            echo -e "${RED}   Error: $error_detail${NC}"
        fi
    fi
    
    echo ""
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
}

function delete_github_token() {
    clear
    Zivpn_Banner
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}              HAPUS GITHUB TOKEN${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────${NC}"
    echo ""
    
    if [ ! -f "$GITHUB_TOKEN_FILE" ]; then
        echo -e "${YELLOW}   Tidak ada token yang tersimpan.${NC}"
        echo ""
        read -p "   Tekan Enter untuk kembali ke menu..."
        return
    fi
    
    current_token=$(cat "$GITHUB_TOKEN_FILE")
    echo -e "${CYAN}   Token saat ini: ${YELLOW}${current_token:0:15}...${current_token: -15}${NC}"
    echo ""
    echo -e "${RED}   ⚠️  PERINGATAN: Menghapus token akan membuat fitur upload tidak berfungsi!${NC}"
    echo ""
    read -p "   Yakin ingin menghapus token? (y/n): " confirm
    
    if [[ "$confirm" == "y" ]]; then
        # Backup token yang dihapus
        echo "# Token dihapus pada $(date '+%Y-%m-%d %H:%M:%S')" >> "${GITHUB_TOKEN_FILE}.deleted"
        echo "$current_token" >> "${GITHUB_TOKEN_FILE}.deleted"
        
        rm -f "$GITHUB_TOKEN_FILE"
        echo -e "${Green}   ✅ Token berhasil dihapus!${NC}"
        echo -e "${YELLOW}   Anda dapat mengatur token baru melalui Menu 14 atau 15${NC}"
    else
        echo -e "${YELLOW}   Penghapusan dibatalkan.${NC}"
    fi
    
    echo ""
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
}

# ==================== USER MANAGEMENT FUNCTIONS ====================
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
        read -p "   Tekan Enter untuk kembali ke menu..."
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
    
    send_telegram_notification "create" "$password" "$exp_date" "${iplimit:-0}" "$domain"
    
    echo ""
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
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
        read -p "   Tekan Enter untuk kembali ke menu..."
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
    
    send_telegram_notification "create_random" "$password" "$exp_date" "${iplimit:-0}" "$domain"
    
    echo ""
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
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
    
    send_telegram_notification "trial" "$password" "$trial_end" "1" "$domain"
    
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
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
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
    
    send_telegram_notification "delete" "$password" "" "" "$domain"
    
    echo ""
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
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
        read -p "   Tekan Enter untuk kembali ke menu..."
        return
    fi
    
    python3 << PYTHON
import json
from datetime import datetime, timedelta

with open("$ZIVPN_USERS", "r") as f:
    users = json.load(f)

new_exp_date = ""
for u in users:
    if u.get("password") == "$password":
        current_exp = u.get("expired", datetime.now().strftime("%Y-%m-%d"))
        new_exp = datetime.strptime(current_exp, "%Y-%m-%d") + timedelta(days=$days)
        new_exp_date = new_exp.strftime("%Y-%m-%d")
        u["expired"] = new_exp_date
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

with open("/tmp/zivpn_new_exp.txt", "w") as f:
    f.write(new_exp_date)
PYTHON
    
    new_exp_date=$(cat /tmp/zivpn_new_exp.txt 2>/dev/null)
    rm -f /tmp/zivpn_new_exp.txt
    
    echo -e "${Green}   ✅ User berhasil diperpanjang!${NC}"
    systemctl restart zivpn 2>/dev/null
    
    send_telegram_notification "renew" "$password" "$new_exp_date" "" "$domain"
    
    echo ""
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
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
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
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
            read -p "   Tekan Enter untuk kembali ke menu..."
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
        read -p "   Tekan Enter untuk kembali ke menu..."
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
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
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
        read -p "   Tekan Enter untuk kembali ke menu..."
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
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
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
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
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
    read -p "   Tekan Enter untuk kembali ke menu..."
    return
}

function Select_Display() {
    while true; do
        echo
        read -p "   Select option [1-16 or x] : " hallo
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
            11) create_backup ;;
            12) restore_backup ;;
            13) upload_backup ;;
            14) set_github_token ;;
            15) change_github_token ;;
            16) delete_github_token ;;
            x|X) 
                clear
                exit 0 
                ;;
            *) 
                echo -e "${RED}   Invalid option${NC}"
                sleep 1
                ;;
        esac
        
        Zivpn_Banner
        Service_System_Operating
        Service_Status
        Details_Clients_Name
        Acces_Use_Command
    done
}

# ==================== MAIN ====================
CEKIP
Zivpn_Banner
Service_System_Operating
Service_Status
Details_Clients_Name
Acces_Use_Command
Select_Display