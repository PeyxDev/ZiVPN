#!/bin/bash

RED="\033[1;31m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
RESET="\033[0m"
BOLD="\033[1m"

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${RED}              UNINSTALL ZIVPN${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

read -p "Are you sure you want to uninstall ZiVPN? (y/n): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "${CYAN}Uninstall cancelled${RESET}"
    exit 0
fi

echo -e "${CYAN}Stopping services...${RESET}"
systemctl stop zivpn zivpn-api zivpn-bot 2>/dev/null
systemctl disable zivpn zivpn-api zivpn-bot 2>/dev/null

echo -e "${CYAN}Removing binaries...${RESET}"
rm -f /usr/local/bin/zivpn
rm -f /usr/local/bin/m-zivpn

echo -e "${CYAN}Removing configuration...${RESET}"
rm -rf /etc/zivpn

echo -e "${CYAN}Removing systemd services...${RESET}"
rm -f /etc/systemd/system/zivpn.service
rm -f /etc/systemd/system/zivpn-api.service
rm -f /etc/systemd/system/zivpn-bot.service
systemctl daemon-reload

echo -e "${CYAN}Removing firewall rules...${RESET}"
ufw delete allow 5667/udp 2>/dev/null
ufw delete allow 5667/tcp 2>/dev/null
ufw delete allow 8585/tcp 2>/dev/null

echo -e "${CYAN}Removing alias...${RESET}"
sed -i '/alias m-zivpn/d' /root/.bashrc

echo ""
echo -e "${GREEN}✅ ZiVPN has been uninstalled completely!${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"