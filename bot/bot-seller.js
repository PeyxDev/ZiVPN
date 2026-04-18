const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');
const fs = require('fs');
const crypto = require('crypto');

// ==================== KONFIGURASI ====================
const CONFIG_FILE = '/etc/zivpn/bot-config.json';
const API_KEY_FILE = '/etc/zivpn/apikey';
const DOMAIN_FILE = '/etc/zivpn/domain';
const API_URL = 'http://localhost:8585/api';

let bot = null;
let API_KEY = '';
let config = null;

// User state management
const userStates = new Map(); // userId -> state
const tempUserData = new Map(); // userId -> { username, days, orderId, price }
const lastMessageIds = new Map(); // chatId -> messageId

// ==================== LOAD CONFIG ====================
function loadConfig() {
    try {
        const data = fs.readFileSync(CONFIG_FILE, 'utf8');
        config = JSON.parse(data);
        
        // Load domain if not in config
        if (!config.domain && fs.existsSync(DOMAIN_FILE)) {
            config.domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
        }
        
        // Load API Key
        if (fs.existsSync(API_KEY_FILE)) {
            API_KEY = fs.readFileSync(API_KEY_FILE, 'utf8').trim();
        }
        
        return config;
    } catch (err) {
        console.error('Error loading config:', err.message);
        return null;
    }
}

// ==================== HELPER FUNCTIONS ====================
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
        if (error.response) {
            return error.response.data;
        }
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
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

async function deleteLastMessage(chatId) {
    if (lastMessageIds.has(chatId)) {
        const msgId = lastMessageIds.get(chatId);
        try {
            await bot.deleteMessage(chatId, msgId);
        } catch (e) {}
        lastMessageIds.delete(chatId);
    }
}

async function sendAndTrack(chatId, text, options = {}) {
    await deleteLastMessage(chatId);
    
    const msgOptions = { parse_mode: 'Markdown', ...options };
    const sentMsg = await bot.sendMessage(chatId, text, msgOptions);
    lastMessageIds.set(chatId, sentMsg.message_id);
    return sentMsg;
}

async function sendMessage(chatId, text, keyboard = null) {
    const options = { parse_mode: 'Markdown' };
    if (keyboard) {
        options.reply_markup = keyboard;
    }
    
    if (userStates.has(chatId)) {
        const cancelKb = {
            inline_keyboard: [[{ text: "❌ Batal", callback_data: "cancel" }]]
        };
        options.reply_markup = cancelKb;
    }
    
    return await sendAndTrack(chatId, text, options);
}

function resetState(userId) {
    userStates.delete(userId);
    // Don't delete tempUserData if pending payment
}

// ==================== PAKASIR API ====================
async function createPakasirTransaction(orderId, amount) {
    try {
        const url = 'https://app.pakasir.com/api/transactioncreate/qris';
        const payload = {
            project: config.pakasir_slug,
            order_id: orderId,
            amount: amount,
            api_key: config.pakasir_api_key
        };
        
        const response = await axios.post(url, payload, {
            headers: { 'Content-Type': 'application/json' },
            timeout: 30000
        });
        
        if (response.data && response.data.payment) {
            return {
                payment_number: response.data.payment.payment_number,
                expired_at: response.data.payment.expired_at
            };
        }
        throw new Error('Invalid response from Pakasir');
    } catch (error) {
        console.error('Pakasir error:', error.message);
        throw error;
    }
}

async function checkPakasirStatus(orderId, amount) {
    try {
        const url = `https://app.pakasir.com/api/transactiondetail?project=${config.pakasir_slug}&amount=${amount}&order_id=${orderId}&api_key=${config.pakasir_api_key}`;
        const response = await axios.get(url, { timeout: 10000 });
        
        if (response.data && response.data.transaction) {
            return response.data.transaction.status;
        }
        return 'not_found';
    } catch (error) {
        console.error('Check payment error:', error.message);
        return 'error';
    }
}

// ==================== USER MANAGEMENT ====================
async function createUser(chatId, username, days, ipLimit) {
    const result = await apiCall('POST', '/user/create', {
        password: username,
        days: days,
        ip_limit: ipLimit
    });
    
    if (result.success && result.data) {
        return result.data;
    }
    throw new Error(result.message || 'Failed to create user');
}

// ==================== PAYMENT PROCESS ====================
async function processPayment(chatId, userId, days) {
    const price = days * config.daily_price;
    
    if (price < 267) {
        await sendMessage(chatId, `❌ Total harga Rp ${formatNumber(price)}. Minimal transaksi adalah Rp 267.\nSilakan tambah durasi.`);
        return false;
    }
    
    const orderId = `ZIVPN-${userId}-${Date.now()}`;
    const userData = tempUserData.get(userId) || {};
    userData.order_id = orderId;
    userData.price = price;
    userData.days = days;
    tempUserData.set(userId, userData);
    
    try {
        // Create Pakasir transaction
        const payment = await createPakasirTransaction(orderId, price);
        
        // Generate QR Code URL
        const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(payment.payment_number)}`;
        
        const msgText = `💳 *TAGIHAN PEMBAYARAN*\n━━━━━━━━━━━━━━━━━━━━\n👤 *Username*: \`${userData.username}\`\n📅 *Durasi*: ${days} Hari\n💰 *Total*: Rp ${formatNumber(price)}\n━━━━━━━━━━━━━━━━━━━━\n📱 *Scan QRIS di atas untuk membayar*\n⏰ *Expired*: ${payment.expired_at}\n━━━━━━━━━━━━━━━━━━━━\n✅ *Setelah bayar, tekan tombol Cek Pembayaran*`;
        
        const keyboard = {
            inline_keyboard: [
                [{ text: "✅ Cek Pembayaran", callback_data: `check_payment:${orderId}` }],
                [{ text: "❌ Batal", callback_data: "cancel" }]
            ]
        };
        
        await deleteLastMessage(chatId);
        
        // Send photo with QR code
        const photoMsg = await bot.sendPhoto(chatId, qrUrl, {
            caption: msgText,
            parse_mode: 'Markdown',
            reply_markup: keyboard
        });
        lastMessageIds.set(chatId, photoMsg.message_id);
        
        // Clear state but keep tempUserData
        userStates.delete(userId);
        return true;
        
    } catch (error) {
        await sendMessage(chatId, `❌ Gagal membuat pembayaran: ${error.message}`);
        resetState(userId);
        return false;
    }
}

async function checkPayment(chatId, userId, orderId, queryId) {
    const userData = tempUserData.get(userId);
    
    if (!userData || userData.order_id !== orderId) {
        await bot.answerCallbackQuery(queryId, { text: 'Data transaksi tidak ditemukan' });
        return;
    }
    
    try {
        const status = await checkPakasirStatus(orderId, userData.price);
        
        if (status === 'completed' || status === 'success') {
            // Payment success - create account
            const username = userData.username;
            const days = userData.days;
            const ipLimit = config.default_ip_limit || 1;
            
            await bot.answerCallbackQuery(queryId, { text: '✅ Pembayaran diterima! Membuat akun...' });
            
            // Create user
            const userResult = await createUser(chatId, username, days, ipLimit);
            
            if (userResult) {
                const ipInfo = await getIpInfo();
                const domain = config.domain || 'Not set';
                
                const successMsg = `✅ *PEMBAYARAN BERHASIL!*\n━━━━━━━━━━━━━━━━━━━━\n🎉 *AKUN PREMIUM AKTIF*\n━━━━━━━━━━━━━━━━━━━━\n🔐 *Password*: \`${username}\`\n📅 *Expired*: ${userResult.expired}\n🌐 *IP Limit*: ${ipLimit} Device\n🏷️ *Domain*: ${domain}\n📍 *City*: ${ipInfo.city}\n🏢 *ISP*: ${ipInfo.isp}\n━━━━━━━━━━━━━━━━━━━━\n🙏 *Terima kasih telah berlangganan!*`;
                
                await sendAndTrack(chatId, successMsg);
                tempUserData.delete(userId);
                await showMainMenu(chatId);
            } else {
                await sendMessage(chatId, '❌ Gagal membuat akun. Silakan hubungi admin.');
            }
        } else if (status === 'pending') {
            await bot.answerCallbackQuery(queryId, { text: '⏳ Pembayaran belum diterima. Silakan tunggu atau hubungi admin.' });
        } else if (status === 'expired') {
            await bot.answerCallbackQuery(queryId, { text: '⚠️ Pembayaran sudah expired. Silakan pesan ulang.' });
            tempUserData.delete(userId);
            await showMainMenu(chatId);
        } else {
            await bot.answerCallbackQuery(queryId, { text: `Status: ${status}. Silakan coba lagi nanti.` });
        }
    } catch (error) {
        console.error('Check payment error:', error);
        await bot.answerCallbackQuery(queryId, { text: 'Error cek pembayaran. Silakan coba lagi.' });
    }
}

// ==================== MENU & UI ====================
async function showMainMenu(chatId) {
    const ipInfo = await getIpInfo();
    const domain = config.domain || '(Not Configured)';
    const pricePerDay = config.daily_price || 1000;
    
    const msgText = `\`\`\`
━━━━━━━━━━━━━━━━━━━━━
    🛍️ PX STORE - ZIVPN
━━━━━━━━━━━━━━━━━━━━━
 • Domain   : ${domain}
 • City     : ${ipInfo.city}
 • ISP      : ${ipInfo.isp}
 • Harga    : Rp ${formatNumber(pricePerDay)} / Hari
━━━━━━━━━━━━━━━━━━━━━
\`\`\`
👇 *Silakan pilih menu di bawah ini:*`;
    
    const keyboard = {
        inline_keyboard: [
            [{ text: "🛒 Beli Akun Premium", callback_data: "menu_create" }],
            [{ text: "📊 System Info", callback_data: "menu_info" }],
            [{ text: "📞 Hubungi Admin", callback_data: "menu_admin", url: "https://t.me/PeyxDev" }]
        ]
    };
    
    await sendAndTrack(chatId, msgText, { reply_markup: keyboard });
}

async function showSystemInfo(chatId) {
    const result = await apiCall('GET', '/system/info');
    const ipInfo = await getIpInfo();
    const domain = config.domain || '(Not Configured)';
    
    let msg = `\`\`\`
━━━━━━━━━━━━━━━━━━━━━
    📊 INFO ZIVPN UDP
━━━━━━━━━━━━━━━━━━━━━
Domain      : ${domain}
Public IP   : ${result.data?.public_ip || 'Unknown'}
Port        : ${result.data?.port || '5667'}
Service     : ZIVPN UDP
━━━━━━━━━━━━━━━━━━━━━
📍 City      : ${ipInfo.city}
🏢 ISP       : ${ipInfo.isp}
━━━━━━━━━━━━━━━━━━━━━
⏰ Server Time: ${formatDate(new Date())}
\`\`\``;
    
    await sendAndTrack(chatId, msg);
    await showMainMenu(chatId);
}

async function startCreateUser(chatId, userId) {
    userStates.set(userId, 'create_username');
    tempUserData.set(userId, {});
    await sendMessage(chatId, '👤 *Masukkan Password/Username Baru:*\n\n📌 *Ketentuan:*\n• 3-20 karakter\n• Huruf, angka, - dan _');
}

// ==================== VALIDATION ====================
function validateUsername(chatId, text) {
    if (text.length < 3 || text.length > 20) {
        sendMessage(chatId, '❌ Password harus 3-20 karakter. Coba lagi:');
        return false;
    }
    if (!/^[a-zA-Z0-9_-]+$/.test(text)) {
        sendMessage(chatId, '❌ Password hanya boleh huruf, angka, - dan _. Coba lagi:');
        return false;
    }
    return true;
}

function validateNumber(chatId, text, min, max, fieldName) {
    const val = parseInt(text);
    if (isNaN(val) || val < min || val > max) {
        sendMessage(chatId, `❌ ${fieldName} harus angka positif (${min}-${max}). Coba lagi:`);
        return null;
    }
    return val;
}

// ==================== STATE HANDLER ====================
async function handleState(chatId, userId, state, text) {
    switch (state) {
        case 'create_username':
            if (!validateUsername(chatId, text)) return;
            
            const userData = tempUserData.get(userId) || {};
            userData.username = text;
            tempUserData.set(userId, userData);
            
            userStates.set(userId, 'create_days');
            await sendMessage(chatId, `⏳ *Masukkan Durasi (hari)*\n\n💰 Harga: Rp ${formatNumber(config.daily_price)} / hari`);
            break;
            
        case 'create_days':
            const days = validateNumber(chatId, text, 1, 365, 'Durasi');
            if (days === null) return;
            
            const data = tempUserData.get(userId) || {};
            data.days = days;
            tempUserData.set(userId, data);
            
            await processPayment(chatId, userId, days);
            break;
    }
}

// ==================== MESSAGE HANDLER ====================
async function handleMessage(msg) {
    const chatId = msg.chat.id;
    const userId = msg.from.id;
    const text = msg.text?.trim();
    
    // Check if in state
    if (userStates.has(userId)) {
        const state = userStates.get(userId);
        await handleState(chatId, userId, state, text);
        return;
    }
    
    // Handle commands
    if (msg.isCommand && msg.text) {
        const command = msg.text.split(' ')[0].substring(1);
        if (command === 'start') {
            await showMainMenu(chatId);
        }
        return;
    }
    
    // Non-command, non-state messages - show menu
    await showMainMenu(chatId);
}

// ==================== CALLBACK HANDLER ====================
async function handleCallback(query) {
    const chatId = query.message.chat.id;
    const userId = query.from.id;
    const data = query.data;
    
    switch (data) {
        case 'menu_create':
            await startCreateUser(chatId, userId);
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
            if (data.startsWith('check_payment:')) {
                const orderId = data.substring('check_payment:'.length);
                await checkPayment(chatId, userId, orderId, query.id);
            }
            break;
    }
    
    await bot.answerCallbackQuery(query.id);
}

// ==================== ADMIN COMMANDS ====================
async function handleAdminCommand(chatId, userId, text) {
    const isAdmin = config.admin_id == userId;
    if (!isAdmin) return false;
    
    if (text === '/users') {
        const result = await apiCall('GET', '/users');
        if (result.success && result.data) {
            let msg = '*📋 DAFTAR USER*\n━━━━━━━━━━━━━━━━━━━━\n';
            for (const user of result.data.slice(0, 30)) {
                msg += `• \`${user.password}\` | Exp: ${user.expired} | ${user.status}\n`;
            }
            msg += `━━━━━━━━━━━━━━━━━━━━\n📌 *Total*: ${result.data.length} users`;
            await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
        }
        return true;
    }
    
    if (text === '/stats') {
        const stats = await apiCall('GET', '/users/stats');
        if (stats.success && stats.data) {
            const msg = `*📊 STATISTIK*\n━━━━━━━━━━━━━━━━━━━━\n👥 Total: ${stats.data.total}\n✅ Active: ${stats.data.active}\n⏰ Expired: ${stats.data.expired}\n🔒 Locked: ${stats.data.locked}`;
            await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
        }
        return true;
    }
    
    if (text.startsWith('/create ')) {
        const parts = text.split(' ');
        if (parts.length >= 3) {
            const username = parts[1];
            const days = parseInt(parts[2]);
            const ipLimit = parts[3] ? parseInt(parts[3]) : config.default_ip_limit;
            
            const result = await apiCall('POST', '/user/create', {
                password: username,
                days: days,
                ip_limit: ipLimit
            });
            
            if (result.success) {
                await bot.sendMessage(chatId, `✅ User \`${username}\` created! Expired: ${result.data.expired}`, { parse_mode: 'Markdown' });
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
            await bot.sendMessage(chatId, `✅ User \`${username}\` deleted!`, { parse_mode: 'Markdown' });
        } else {
            await bot.sendMessage(chatId, `❌ Failed: ${result.message}`);
        }
        return true;
    }
    
    return false;
}

// ==================== MAIN ====================
async function main() {
    // Load config
    if (!loadConfig()) {
        console.error('Failed to load config!');
        process.exit(1);
    }
    
    // Validate Pakasir config for seller bot
    if (!config.pakasir_slug || !config.pakasir_api_key) {
        console.error('Pakasir configuration missing in bot-config.json!');
        console.error('Required: pakasir_slug, pakasir_api_key, daily_price');
        process.exit(1);
    }
    
    // Initialize bot
    bot = new TelegramBot(config.bot_token, { polling: true });
    
    console.log('🤖 PX STORE Seller Bot started!');
    console.log(`📊 Daily Price: Rp ${formatNumber(config.daily_price)}`);
    console.log(`🔑 Pakasir Slug: ${config.pakasir_slug}`);
    console.log(`👑 Admin ID: ${config.admin_id}`);
    
    // Message handler
    bot.on('message', async (msg) => {
        // Check for admin commands first
        const isAdminCommand = await handleAdminCommand(msg.chat.id, msg.from.id, msg.text);
        if (!isAdminCommand) {
            await handleMessage(msg);
        }
    });
    
    // Callback handler
    bot.on('callback_query', handleCallback);
}

main().catch(console.error);
