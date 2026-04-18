# Hapus file lama
rm -f /usr/local/sbin/m-zivpn

# Download ulang
wget -q https://raw.githubusercontent.com/PeyxDev/ZiVPN/main/menu.sh -O /usr/local/sbin/m-zivpn

# Fix carriage return
sed -i 's/\r$//' /usr/local/sbin/m-zivpn

# Set permission
chmod +x /usr/local/sbin/m-zivpn

# Jalankan
m-zivpn