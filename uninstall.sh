#!/bin/bash

RED="\033[1;31m"
GREEN="\e[92;1m"
YELLOW="\033[33;1m"
BLUE="\033[36;1m"
NC='\e[0m'

clear
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${RED}         UNINSTALL ZIVPN COMPLETE${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
echo ""

# Stop semua service
echo -e "${YELLOW}➤ Menghentikan service...${NC}"
systemctl stop zivpn.service 2>/dev/null
systemctl stop zivpn-api.service 2>/dev/null
systemctl stop zivpn-bot.service 2>/dev/null
systemctl disable zivpn.service 2>/dev/null
systemctl disable zivpn-api.service 2>/dev/null
systemctl disable zivpn-bot.service 2>/dev/null

# Hapus file service
echo -e "${YELLOW}➤ Menghapus file service...${NC}"
rm -f /etc/systemd/system/zivpn.service
rm -f /etc/systemd/system/zivpn-api.service
rm -f /etc/systemd/system/zivpn-bot.service
systemctl daemon-reload

# Hapus binary
echo -e "${YELLOW}➤ Menghapus binary...${NC}"
rm -f /usr/local/bin/zivpn
rm -f /usr/local/bin/menu
rm -f /usr/local/sbin/m-zivpn

# Hapus semua file konfigurasi
echo -e "${YELLOW}➤ Menghapus konfigurasi...${NC}"
rm -rf /etc/zivpn

# Hapus users.json
rm -f /etc/zivpn/users.json 2>/dev/null

# Hapus alias
echo -e "${YELLOW}➤ Menghapus alias...${NC}"
sed -i '/alias m-zivpn/d' /root/.bashrc 2>/dev/null
sed -i '/alias menu/d' /root/.bashrc 2>/dev/null

# Hapus firewall rules (opsional)
echo -e "${YELLOW}➤ Menghapus aturan firewall...${NC}"
ufw delete allow 5667/udp 2>/dev/null
ufw delete allow 8585/tcp 2>/dev/null
ufw delete allow 6000:19999/udp 2>/dev/null

# Hapus iptables rules
iface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
iptables -t nat -D PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null

# Hapus sysctl tambahan (opsional)
sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf 2>/dev/null
sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf 2>/dev/null
sed -i '/net.ipv4.ip_forward=1/d' /etc/sysctl.conf 2>/dev/null
sed -i '/net.core.rmem_max=16777216/d' /etc/sysctl.conf 2>/dev/null
sed -i '/net.core.wmem_max=16777216/d' /etc/sysctl.conf 2>/dev/null
sed -i '/net.core.rmem_default=16777216/d' /etc/sysctl.conf 2>/dev/null
sed -i '/net.core.wmem_default=16777216/d' /etc/sysctl.conf 2>/dev/null
sed -i '/net.core.optmem_max=65536/d' /etc/sysctl.conf 2>/dev/null
sed -i '/net.core.somaxconn=65535/d' /etc/sysctl.conf 2>/dev/null
sed -i '/net.ipv4.tcp_rmem=4096 87380 16777216/d' /etc/sysctl.conf 2>/dev/null
sed -i '/net.ipv4.tcp_wmem=4096 65536 16777216/d' /etc/sysctl.conf 2>/dev/null
sed -i '/net.ipv4.tcp_fastopen=3/d' /etc/sysctl.conf 2>/dev/null
sed -i '/fs.file-max=1000000/d' /etc/sysctl.conf 2>/dev/null

echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${GREEN}         UNINSTALL COMPLETE!${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "${GREEN}  ✓ Semua konfigurasi ZiVPN telah dihapus${NC}"
echo ""