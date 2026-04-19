const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');
const fs = require('fs');
const QRCode = require('qrcode');
const { createCanvas, loadImage } = require('canvas');

const CONFIG_FILE = '/etc/zivpn/bot-config.json';
const API_KEY_FILE = '/etc/zivpn/apikey';
const DOMAIN_FILE = '/etc/zivpn/domain';
const API_URL = 'http://localhost:8585/api';

let bot = null;
let API_KEY = '';
let config = null;

const userStates = new Map();
const tempUserData = new Map();
const lastMessageIds = new Map();
const uploadedImageHashes = new Set();

function loadConfig() {
    try {
        const data = fs.readFileSync(CONFIG_FILE, 'utf8');
        config = JSON.parse(data);
        if (!config.domain && fs.existsSync(DOMAIN_FILE)) {
            config.domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
        }
        if (fs.existsSync(API_KEY_FILE)) {
            API_KEY = fs.readFileSync(API_KEY_FILE, 'utf8').trim();
        }
        console.log('✅ Config loaded');
        return config;
    } catch (err) {
        console.error('Error loading config:', err.message);
        return null;
    }
}

async function apiCall(method, endpoint, data = null) {
    try {
        const url = `${API_URL}${endpoint}`;
        const headers = {
            'x-api-key': API_KEY,
            'Content-Type': 'application/json'
        };
        let response;
        if (method === 'GET') {
            response = await axios.get(url, { headers, timeout: 10000 });
        } else {
            response = await axios.post(url, data, { headers, timeout: 10000 });
        }
        return response.data;
    } catch (error) {
        console.error(`API Error: ${error.message}`);
        if (error.response) return error.response.data;
        return { success: false, message: error.message };
    }
}

async function getIpInfo() {
    try {
        const response = await axios.get('http://ip-api.com/json/', { timeout: 5000 });
        return { city: response.data.city || 'Unknown', isp: response.data.isp || 'Unknown' };
    } catch (error) {
        return { city: 'Unknown', isp: 'Unknown' };
    }
}

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
}

function formatDate(date) {
    return new Date(date).toLocaleString('id-ID', {
        day: '2-digit', month: '2-digit', year: 'numeric',
        hour: '2-digit', minute: '2-digit'
    });
}

// Hapus fungsi deleteLastMessage yang menyebabkan pesan hilang
async function sendMessage(chatId, text, extra = {}) {
    const msgOptions = { parse_mode: undefined, ...extra };
    return await bot.sendMessage(chatId, text, msgOptions);
}

async function sendPhoto(chatId, photo, caption = '', extra = {}) {
    const msgOptions = { caption, ...extra };
    return await bot.sendPhoto(chatId, photo, msgOptions);
}

function resetState(userId) {
    userStates.delete(userId);
}

async function createUser(chatId, username, days, limit) {
    const result = await apiCall('POST', '/user/create', {
        password: username,
        days: days,
        ip_limit: limit
    });
    if (result.success && result.data) return result.data;
    throw new Error(result.message || 'Failed to create user');
}

async function createTrialUser(chatId) {
    const result = await apiCall('POST', '/user/trial', {});
    if (result.success && result.data) return result.data;
    throw new Error(result.message || 'Failed to create trial user');
}

async function generateDynamicQRIS(amount) {
    try {
        const apiUrl = `${config.qris.api_url}?qris=${encodeURIComponent(config.qris.static_string)}&nominal=${amount}`;
        console.log('🔄 Fetching QRIS from API:', apiUrl);
        
        const response = await axios.get(apiUrl, { timeout: 10000 });
        
        if (response.data && response.data.QR) {
            return response.data.QR;
        }
        throw new Error('No QR string in response');
    } catch (error) {
        console.error('Error generating dynamic QRIS:', error.message);
        throw error;
    }
}

async function generateQRWithIcon(qrString, amount) {
    const size = config.qris.qr_size || 400;
    const iconSize = config.qris.icon_size || 80;
    
    try {
        const canvas = createCanvas(size, size);
        const ctx = canvas.getContext('2d');
        
        await QRCode.toCanvas(canvas, qrString, {
            width: size,
            margin: 2,
            color: { dark: '#000000', light: '#FFFFFF' },
            errorCorrectionLevel: 'H'
        });
        
        const centerX = size / 2;
        const centerY = size / 2;
        const radius = iconSize / 2 + 5;
        
        ctx.beginPath();
        ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
        ctx.fillStyle = '#FFFFFF';
        ctx.fill();
        
        try {
            const iconResponse = await axios.get(config.qris.icon_url, { 
                responseType: 'arraybuffer',
                timeout: 5000
            });
            const iconBuffer = Buffer.from(iconResponse.data);
            const iconImage = await loadImage(iconBuffer);
            
            const iconX = centerX - iconSize / 2;
            const iconY = centerY - iconSize / 2;
            ctx.drawImage(iconImage, iconX, iconY, iconSize, iconSize);
        } catch (iconError) {
            console.warn('Could not load icon, skipping:', iconError.message);
        }
        
        ctx.beginPath();
        ctx.arc(centerX, centerY, iconSize / 2, 0, Math.PI * 2);
        ctx.strokeStyle = '#DDDDDD';
        ctx.lineWidth = 1.5;
        ctx.stroke();
        
        return canvas;
    } catch (error) {
        console.error('Error generating QR with icon:', error);
        throw error;
    }
}

async function generateAndSendQRIS(chatId, amount, orderId) {
    try {
        const qrString = await generateDynamicQRIS(amount);
        const canvas = await generateQRWithIcon(qrString, amount);
        
        const buffer = canvas.toBuffer('image/png');
        
        const caption = `💳 PEMBAYARAN QRIS
━━━━━━━━━━━━━━━━━━━━
💰 Total: Rp ${formatNumber(amount)}
🆔 Order ID: ${orderId}
⏰ Waktu: ${formatDate(new Date())}
━━━━━━━━━━━━━━━━━━━━
📱 Scan QRIS di atas untuk membayar
📤 Setelah bayar, kirim foto bukti pembayaran

Ketik /cancel untuk membatalkan`;
        
        await sendPhoto(chatId, buffer, caption);
        return true;
    } catch (error) {
        console.error('Error generating QRIS:', error);
        await sendMessage(chatId, `❌ Gagal membuat QR Code: ${error.message}`);
        return false;
    }
}

async function processPayment(chatId, userId, days, price) {
    const orderId = `ZIVPN-${userId}-${Date.now()}`;
    const userData = tempUserData.get(userId) || {};
    userData.order_id = orderId;
    userData.price = String(price);
    userData.days = String(days);
    tempUserData.set(userId, userData);
    
    const success = await generateAndSendQRIS(chatId, price, orderId);
    if (!success) {
        return false;
    }
    
    await sendMessage(chatId, "📤 Silakan kirim FOTO BUKTI PEMBAYARAN Anda (kirim gambar/photo)");
    
    userStates.set(userId, 'waiting_proof');
    return true;
}

async function generateImageHash(fileBuffer) {
    const crypto = require('crypto');
    return crypto.createHash('md5').update(fileBuffer).digest('hex');
}

function validateImageFile(buffer, filename) {
    const allowedTypes = ['.jpg', '.jpeg', '.png'];
    const ext = filename.toLowerCase().substring(filename.lastIndexOf('.'));
    if (!allowedTypes.includes(ext)) {
        return { isValid: false, message: 'Format file harus JPG, JPEG, atau PNG' };
    }
    const maxSize = 5 * 1024 * 1024;
    if (buffer.length > maxSize) {
        return { isValid: false, message: 'Ukuran file maksimal 5MB' };
    }
    return { isValid: true, message: 'Valid' };
}

async function handleProofUpload(chatId, userId, photoFileId) {
    const userData = tempUserData.get(userId);
    if (!userData) {
        await sendMessage(chatId, '❌ Sesi kadaluarsa. Silakan mulai pesanan baru.');
        userStates.delete(userId);
        await showMainMenu(chatId);
        return;
    }
    
    await sendMessage(chatId, '⏳ Memproses bukti pembayaran...');
    
    try {
        const fileInfo = await bot.getFile(photoFileId);
        const fileUrl = `https://api.telegram.org/file/bot${config.bot_token}/${fileInfo.file_path}`;
        
        const response = await axios.get(fileUrl, { responseType: 'arraybuffer' });
        const fileBuffer = Buffer.from(response.data);
        
        const validation = validateImageFile(fileBuffer, fileInfo.file_path || 'image.jpg');
        if (!validation.isValid) {
            await sendMessage(chatId, `❌ ${validation.message}\n\nSilakan kirim ulang bukti pembayaran yang valid.`);
            return;
        }
        
        const hash = await generateImageHash(fileBuffer);
        if (uploadedImageHashes.has(hash)) {
            await sendMessage(chatId, '❌ Bukti ini sudah pernah digunakan! Harap upload bukti yang berbeda.');
            return;
        }
        
        uploadedImageHashes.add(hash);
        
        const limit = config.default_ip_limit || 1;
        const userResult = await createUser(chatId, userData.username, parseInt(userData.days), limit);
        const ipInfo = await getIpInfo();
        const domain = config.domain || 'Not set';
        
        const successMsg = `✅ PEMBAYARAN BERHASIL!
━━━━━━━━━━━━━━━━━━━━
🎉 AKUN PREMIUM AKTIF
━━━━━━━━━━━━━━━━━━━━
🔐 Password: ${userData.username}
📅 Expired: ${userResult.expired}
🌐 IP Limit: ${limit} Device
🏷️ Domain: ${domain}
📍 City: ${ipInfo.city}
🏢 ISP: ${ipInfo.isp}
━━━━━━━━━━━━━━━━━━━━
🙏 Terima kasih telah berlangganan!
✨ Powered by PX STORE ✨`;
        
        await sendMessage(chatId, successMsg);
        
        tempUserData.delete(userId);
        userStates.delete(userId);
        await showMainMenu(chatId);
        
    } catch (error) {
        console.error('Error processing proof:', error);
        await sendMessage(chatId, `❌ Gagal memproses bukti: ${error.message}\n\nSilakan coba lagi.`);
    }
}

async function handleTrial(chatId) {
    try {
        const result = await createTrialUser(chatId);
        const ipInfo = await getIpInfo();
        const domain = config.domain || 'Not set';
        
        const msg = `🎫 TRIAL 30 MENIT - PX STORE
━━━━━━━━━━━━━━━━━━━━
🔐 Password: ${result.password}
⏰ Expired: 30 menit
🌐 IP Limit: 1 Device
🏷️ Domain: ${domain}
📍 City: ${ipInfo.city}
🏢 ISP: ${ipInfo.isp}
━━━━━━━━━━━━━━━━━━━━
🎫 Akun akan kadaluarsa dalam 30 menit!
━━━━━━━━━━━━━━━━━━━━
✨ Powered by PX STORE ✨`;
        
        await sendMessage(chatId, msg);
    } catch (error) {
        await sendMessage(chatId, `❌ Gagal membuat trial: ${error.message}`);
    }
}

async function showSystemInfo(chatId) {
    const result = await apiCall('GET', '/system/info');
    const ipInfo = await getIpInfo();
    const domain = config.domain || 'Not set';
    
    let msg = `📊 SYSTEM INFORMATION - PX STORE
━━━━━━━━━━━━━━━━━━━━
🏷️ Domain: ${domain}
🌐 Public IP: ${result.data?.public_ip || 'Unknown'}
🔌 UDP Port: ${result.data?.port || '5667'}
📡 API Port: 8585
🖥️ OS: ${result.data?.os || 'Unknown'}
━━━━━━━━━━━━━━━━━━━━
📍 City: ${ipInfo.city}
🏢 ISP: ${ipInfo.isp}
━━━━━━━━━━━━━━━━━━━━
⏰ Server Time: ${formatDate(new Date())}
━━━━━━━━━━━━━━━━━━━━
✨ Powered by PX STORE ✨`;
    
    await sendMessage(chatId, msg);
}

async function showMainMenu(chatId) {
    const ipInfo = await getIpInfo();
    const domain = config.domain || '(Not Configured)';
    const pricePerDay = config.daily_price || 1000;
    
    const msgText = `🏪 PX STORE - ZIVPN PREMIUM
━━━━━━━━━━━━━━━━━━━━
📌 SERVER INFO
🏷️ Domain: ${domain}
📍 City: ${ipInfo.city}
🏢 ISP: ${ipInfo.isp}
━━━━━━━━━━━━━━━━━━━━
💰 HARGA PREMIUM
💎 Rp ${formatNumber(pricePerDay)} / Hari
━━━━━━━━━━━━━━━━━━━━
👇 Silakan pilih menu di bawah ini:`;
    
    const keyboard = {
        inline_keyboard: [
            [{ text: "🛒 BELI AKUN PREMIUM", callback_data: "menu_buy" }],
            [{ text: "🎫 TRIAL 30 MENIT", callback_data: "menu_trial" }],
            [{ text: "📊 SYSTEM INFO", callback_data: "menu_info" }],
            [{ text: "📞 HUBUNGI ADMIN", callback_data: "menu_admin", url: "https://t.me/PeyxDev" }]
        ]
    };
    
    await sendMessage(chatId, msgText, { reply_markup: keyboard });
}

async function startBuyUser(chatId, userId) {
    userStates.set(userId, 'buy_username');
    tempUserData.set(userId, {});
    await sendMessage(chatId, '👤 Masukkan Password/Username Baru:\n\n📌 Ketentuan:\n• 3-20 karakter\n• Huruf, angka, - dan _');
}

async function handleBuyState(chatId, userId, state, text) {
    switch (state) {
        case 'buy_username':
            if (text.length < 3 || text.length > 20) {
                await sendMessage(chatId, '❌ Password harus 3-20 karakter. Coba lagi:');
                return;
            }
            if (!/^[a-zA-Z0-9_-]+$/.test(text)) {
                await sendMessage(chatId, '❌ Password hanya boleh huruf, angka, - dan _. Coba lagi:');
                return;
            }
            const userData = tempUserData.get(userId) || {};
            userData.username = text;
            tempUserData.set(userId, userData);
            userStates.set(userId, 'buy_days');
            await sendMessage(chatId, `⏳ Masukkan Durasi (hari)\n\n💰 Harga: Rp ${formatNumber(config.daily_price)} / hari`);
            break;
        case 'buy_days':
            const days = parseInt(text);
            if (isNaN(days) || days < 1 || days > 365) {
                await sendMessage(chatId, '❌ Durasi harus angka (1-365). Coba lagi:');
                return;
            }
            const data = tempUserData.get(userId) || {};
            data.days = days;
            tempUserData.set(userId, data);
            
            const price = days * config.daily_price;
            await processPayment(chatId, userId, days, price);
            break;
    }
}

async function handleAdminCommand(chatId, userId, text) {
    const isAdmin = config.admin_id == userId;
    if (!isAdmin) return false;
    
    if (text === '/users') {
        const result = await apiCall('GET', '/users');
        if (result.success && result.data) {
            let msg = `📋 DAFTAR USER - PX STORE\n━━━━━━━━━━━━━━━━━━━━\n`;
            for (const user of result.data.slice(0, 30)) {
                const statusIcon = user.status === 'Active' ? '🟢' : (user.status === 'Locked' ? '🔒' : '🔴');
                msg += `${statusIcon} ${user.password} | Exp: ${user.expired}\n`;
            }
            msg += `━━━━━━━━━━━━━━━━━━━━\n📌 Total: ${result.data.length} users`;
            await bot.sendMessage(chatId, msg);
        }
        return true;
    }
    
    if (text === '/stats') {
        const stats = await apiCall('GET', '/users/stats');
        if (stats.success && stats.data) {
            const msg = `📊 STATISTIK - PX STORE
━━━━━━━━━━━━━━━━━━━━
👥 Total Users: ${stats.data.total}
✅ Active: ${stats.data.active}
⏰ Expired: ${stats.data.expired}
🔒 Locked: ${stats.data.locked}
━━━━━━━━━━━━━━━━━━━━
✨ Powered by PX STORE ✨`;
            await bot.sendMessage(chatId, msg);
        }
        return true;
    }
    
    if (text.startsWith('/create ')) {
        const parts = text.split(' ');
        if (parts.length >= 3) {
            const username = parts[1];
            const days = parseInt(parts[2]);
            const ipLimit = parts[3] ? parseInt(parts[3]) : (config.default_ip_limit || 1);
            const result = await apiCall('POST', '/user/create', {
                password: username,
                days: days,
                ip_limit: ipLimit
            });
            if (result.success) {
                await bot.sendMessage(chatId, `✅ User Created
━━━━━━━━━━━━━━━━━━━━
🔐 Username: ${username}
📅 Expired: ${result.data.expired}
🌐 IP Limit: ${ipLimit}
━━━━━━━━━━━━━━━━━━━━`);
            } else {
                await bot.sendMessage(chatId, `❌ Failed: ${result.message}`);
            }
        }
        return true;
    }
    
    if (text.startsWith('/delete ')) {
        const username = text.split(' ')[1];
        const result = await apiCall('POST', '/user/delete', { password: username });
        if (result.success) {
            await bot.sendMessage(chatId, `✅ User Deleted
━━━━━━━━━━━━━━━━━━━━
🔐 Username: ${username}
━━━━━━━━━━━━━━━━━━━━`);
        } else {
            await bot.sendMessage(chatId, `❌ Failed: ${result.message}`);
        }
        return true;
    }
    
    return false;
}

async function handleMessage(msg) {
    const chatId = msg.chat.id;
    const userId = msg.from.id;
    const text = msg.text?.trim();
    
    // Handle photo upload (bukti pembayaran)
    if (msg.photo && userStates.has(userId) && userStates.get(userId) === 'waiting_proof') {
        const photoFileId = msg.photo[msg.photo.length - 1].file_id;
        await handleProofUpload(chatId, userId, photoFileId);
        return;
    }
    
    // Handle state
    if (userStates.has(userId)) {
        const state = userStates.get(userId);
        if (state === 'buy_username' || state === 'buy_days') {
            await handleBuyState(chatId, userId, state, text);
        } else if (state === 'waiting_proof') {
            await sendMessage(chatId, '📤 Silakan kirim FOTO BUKTI PEMBAYARAN Anda (kirim gambar/photo)');
        }
        return;
    }
    
    if (msg.text === '/start') {
        await showMainMenu(chatId);
        return;
    }
    
    if (msg.text === '/cancel') {
        resetState(userId);
        tempUserData.delete(userId);
        await showMainMenu(chatId);
        return;
    }
    
    await showMainMenu(chatId);
}

async function handleCallback(query) {
    const chatId = query.message.chat.id;
    const userId = query.from.id;
    const data = query.data;
    
    switch (data) {
        case 'menu_buy':
            await startBuyUser(chatId, userId);
            break;
        case 'menu_trial':
            await handleTrial(chatId);
            break;
        case 'menu_info':
            await showSystemInfo(chatId);
            break;
        case 'cancel':
            resetState(userId);
            tempUserData.delete(userId);
            await showMainMenu(chatId);
            break;
        default:
            break;
    }
    await bot.answerCallbackQuery(query.id);
}

async function main() {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🏪 PX STORE - Seller Bot Starting...');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    if (!loadConfig()) {
        console.error('❌ Failed to load config!');
        process.exit(1);
    }
    
    bot = new TelegramBot(config.bot_token, { polling: true });
    
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ PX STORE - Seller Bot Started!');
    console.log(`📊 Daily Price: Rp ${formatNumber(config.daily_price)}`);
    console.log(`👑 Admin ID: ${config.admin_id}`);
    console.log(`🌐 Domain: ${config.domain || 'Not set'}`);
    console.log(`💳 QRIS API: ${config.qris?.api_url || 'Not set'}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🤖 Bot is running... Waiting for commands...');
    
    bot.on('message', async (msg) => {
        const isAdminCommand = await handleAdminCommand(msg.chat.id, msg.from.id, msg.text);
        if (!isAdminCommand) {
            await handleMessage(msg);
        }
    });
    
    bot.on('callback_query', handleCallback);
}

main().catch(console.error);
