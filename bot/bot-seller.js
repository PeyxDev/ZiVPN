const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');
const fs = require('fs');
const QRCode = require('qrcode');
const { createCanvas } = require('canvas');

const CONFIG_FILE = '/etc/zivpn/bot-config.json';
const API_KEY_FILE = '/etc/zivpn/apikey';
const DOMAIN_FILE = '/etc/zivpn/domain';
const API_URL = 'http://localhost:8585/api';

let bot = null;
let API_KEY = '';
let config = null;

const userStates = new Map();
const tempUserData = new Map();
const processedOrders = new Set();

// ============ FUNGSI ESCAPE HTML ============
function escapeHtml(text) {
    if (!text) return '';
    return String(text)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

// ============ LOAD CONFIG ============
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

// ============ API CALL ============
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

// ============ GET IP INFO ============
async function getIpInfo() {
    try {
        const response = await axios.get('http://ip-api.com/json/', { timeout: 5000 });
        return { city: response.data.city || 'Unknown', isp: response.data.isp || 'Unknown' };
    } catch (error) {
        return { city: 'Unknown', isp: 'Unknown' };
    }
}

// ============ FORMAT NUMBER ============
function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
}

// ============ FORMAT DATE ============
function formatDate(date) {
    return new Date(date).toLocaleString('id-ID', {
        day: '2-digit', month: '2-digit', year: 'numeric',
        hour: '2-digit', minute: '2-digit'
    });
}

// ============ SEND MESSAGE (FIXED) ============
async function sendMessage(chatId, text, extra = {}) {
    const msgOptions = { 
        parse_mode: 'HTML', 
        disable_web_page_preview: true,
        ...extra 
    };
    try {
        return await bot.sendMessage(chatId, text, msgOptions);
    } catch (error) {
        console.error('SendMessage Error:', error.message);
        // Fallback tanpa HTML jika terjadi error
        const plainText = text.replace(/<[^>]*>/g, '');
        return await bot.sendMessage(chatId, plainText, { ...extra, parse_mode: undefined });
    }
}

// ============ SEND PHOTO ============
async function sendPhoto(chatId, photo, caption = '', extra = {}) {
    const msgOptions = { caption, parse_mode: 'HTML', ...extra };
    try {
        return await bot.sendPhoto(chatId, photo, msgOptions);
    } catch (error) {
        console.error('SendPhoto Error:', error.message);
        const plainCaption = caption.replace(/<[^>]*>/g, '');
        return await bot.sendPhoto(chatId, photo, { ...extra, caption: plainCaption, parse_mode: undefined });
    }
}

// ============ RESET STATE ============
function resetState(userId) {
    userStates.delete(userId);
    tempUserData.delete(userId);
}

// ============ CREATE USER ============
async function createUser(chatId, username, days, limit) {
    const result = await apiCall('POST', '/user/create', {
        password: username,
        days: days,
        ip_limit: limit
    });
    if (result.success && result.data) return result.data;
    throw new Error(result.message || 'Failed to create user');
}

// ============ CREATE TRIAL USER ============
async function createTrialUser(chatId) {
    const result = await apiCall('POST', '/user/trial', {});
    if (result.success && result.data) return result.data;
    throw new Error(result.message || 'Failed to create trial user');
}

// ============ GENERATE DYNAMIC QRIS ============
async function generateDynamicQRIS(amount) {
    try {
        const apiUrl = `${config.qris.api_url}?qris=${encodeURIComponent(config.qris.static_string)}&nominal=${amount}`;
        console.log('Fetching QRIS from API:', apiUrl);
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

// ============ GENERATE QR CODE ============
async function generateQRCode(qrString) {
    const size = 400;
    try {
        const canvas = createCanvas(size, size);
        await QRCode.toCanvas(canvas, qrString, {
            width: size,
            margin: 2,
            color: { dark: '#000000', light: '#FFFFFF' },
            errorCorrectionLevel: 'H'
        });
        return canvas;
    } catch (error) {
        console.error('Error generating QR:', error);
        throw error;
    }
}

// ============ GENERATE AND SEND QRIS ============
async function generateAndSendQRIS(chatId, amount, orderId) {
    try {
        const qrString = await generateDynamicQRIS(amount);
        const canvas = await generateQRCode(qrString);
        const buffer = canvas.toBuffer('image/png');
        const caption = `💳 <b>QRIS PAYMENT</b>

💰 <b>Total</b> : <code>Rp ${formatNumber(amount)}</code>
🆔 <b>Order ID</b> : <code>${orderId}</code>
⏰ <b>Time</b> : <code>${formatDate(new Date())}</code>

📱 Scan QRIS above to pay
📤 Press CONFIRM button after payment`;
        const keyboard = {
            inline_keyboard: [
                [{ text: "✅ CONFIRM PAYMENT", callback_data: `confirm_payment:${orderId}` }],
                [{ text: "❌ CANCEL", callback_data: "cancel" }]
            ]
        };
        await sendPhoto(chatId, buffer, caption, { reply_markup: keyboard });
        return true;
    } catch (error) {
        console.error('Error generating QRIS:', error);
        await sendMessage(chatId, `❌ <b>Failed to generate QR Code</b>: ${escapeHtml(error.message)}`);
        return false;
    }
}

// ============ PROCESS PAYMENT ============
async function processPayment(chatId, userId, days, price) {
    const orderId = `PX-${userId}-${Date.now()}`;
    const userData = tempUserData.get(userId) || {};
    userData.order_id = orderId;
    userData.price = String(price);
    userData.days = String(days);
    userData.status = 'pending';
    tempUserData.set(userId, userData);
    const success = await generateAndSendQRIS(chatId, price, orderId);
    if (!success) return false;
    userStates.set(userId, 'waiting_confirmation');
    return true;
}

// ============ HANDLE PAYMENT CONFIRMATION (FIXED) ============
async function handlePaymentConfirmation(chatId, userId, orderId, queryId) {
    if (processedOrders.has(orderId)) {
        await bot.answerCallbackQuery(queryId, { text: '❌ Transaction already processed!' });
        return;
    }
    
    const userData = tempUserData.get(userId);
    if (!userData || userData.order_id !== orderId) {
        await bot.answerCallbackQuery(queryId, { text: '❌ Transaction data not found!' });
        return;
    }
    
    if (userData.status === 'confirmed') {
        await bot.answerCallbackQuery(queryId, { text: '⚠️ Payment already confirmed!' });
        return;
    }
    
    // Answer callback dulu
    await bot.answerCallbackQuery(queryId, { text: '⏳ Processing confirmation...' });
    
    const escapedUsername = escapeHtml(userData.username);
    const escapedPrice = formatNumber(parseInt(userData.price));
    
    const adminMsg = `💰 <b>PAYMENT CONFIRMATION</b>

👤 <b>User ID</b> : <code>${userId}</code>
👤 <b>Username</b> : <code>${escapedUsername}</code>
📅 <b>Duration</b> : <code>${userData.days} Days</code>
💰 <b>Amount</b> : <code>Rp ${escapedPrice}</code>
🆔 <b>Order ID</b> : <code>${orderId}</code>

⏳ <b>Status: PENDING ADMIN APPROVAL</b>`;

    await sendMessage(config.admin_id, adminMsg);
    
    const adminKeyboard = {
        inline_keyboard: [
            [
                { text: "✅ APPROVE", callback_data: `admin_approve:${userId}:${orderId}` },
                { text: "❌ REJECT", callback_data: `admin_reject:${userId}:${orderId}` }
            ]
        ]
    };
    
    await sendMessage(config.admin_id, `🔔 <b>Please select action:</b>`, { reply_markup: adminKeyboard });
    
    userData.status = 'waiting_admin';
    tempUserData.set(userId, userData);
    
    await sendMessage(chatId, `✅ <b>Confirmation received!</b>

⏳ Waiting for admin approval.
Your account will be created once admin approves your payment.`);
}

// ============ ADMIN APPROVE (FIXED) ============
async function adminApprove(userId, orderId, adminId) {
    const isAdmin = config.admin_id == adminId;
    if (!isAdmin) return;
    
    if (processedOrders.has(orderId)) {
        await sendMessage(adminId, `⚠️ <b>Transaction already processed!</b>`);
        return;
    }
    
    const userData = tempUserData.get(userId);
    if (!userData || userData.order_id !== orderId) {
        await sendMessage(adminId, `❌ <b>Transaction data not found!</b>`);
        return;
    }
    
    if (userData.status === 'confirmed') {
        await sendMessage(adminId, `⚠️ <b>Transaction already processed!</b>`);
        return;
    }
    
    processedOrders.add(orderId);
    
    try {
        const limit = config.default_ip_limit || 1;
        const userResult = await createUser(userId, userData.username, parseInt(userData.days), limit);
        const ipInfo = await getIpInfo();
        const domain = config.domain || 'Not set';
        
        // Escape semua variabel yang mungkin mengandung karakter khusus
        const escapedUsername = escapeHtml(userData.username);
        const escapedExpired = escapeHtml(userResult.expired);
        const escapedDomain = escapeHtml(domain);
        const escapedCity = escapeHtml(ipInfo.city);
        const escapedIsp = escapeHtml(ipInfo.isp);
        
        const successMsg = `✅ <b>PAYMENT APPROVED!</b>

🎉 <b>PREMIUM ACCOUNT ACTIVE</b>

🔐 <b>Password</b> : <code>${escapedUsername}</code>
📅 <b>Expired</b> : <code>${escapedExpired}</code>
🌐 <b>IP Limit</b> : <code>${limit} Device</code>
🏷️ <b>Domain</b> : <code>${escapedDomain}</code>
📍 <b>City</b> : <code>${escapedCity}</code>
🏢 <b>ISP</b> : <code>${escapedIsp}</code>

🙏 <b>Thank you for subscribing!</b>
✨ <b>Powered by PX STORE</b> ✨`;

        // Kirim pesan ke user
        await sendMessage(userId, successMsg);
        
        const adminSuccessMsg = `✅ <b>Account created for user ${userId}</b>

🔐 Password: <code>${escapedUsername}</code>
📅 Expired: ${escapedExpired}`;
        
        await sendMessage(adminId, adminSuccessMsg);
        
        userData.status = 'confirmed';
        tempUserData.set(userId, userData);
        
    } catch (error) {
        console.error('AdminApprove Error:', error);
        await sendMessage(adminId, `❌ <b>Failed to create account:</b> ${escapeHtml(error.message)}`);
        processedOrders.delete(orderId);
    }
}

// ============ ADMIN REJECT (FIXED) ============
async function adminReject(userId, orderId, adminId) {
    const isAdmin = config.admin_id == adminId;
    if (!isAdmin) return;
    
    const userData = tempUserData.get(userId);
    if (!userData || userData.order_id !== orderId) return;
    
    await sendMessage(userId, `❌ <b>PAYMENT REJECTED</b>

Please contact admin for more information.

📞 Contact: @PeyxDev`);
    
    await sendMessage(adminId, `❌ <b>Payment for user ${userId} rejected</b>`);
    
    userData.status = 'rejected';
    tempUserData.set(userId, userData);
}

// ============ HANDLE TRIAL ============
async function handleTrial(chatId) {
    try {
        const result = await createTrialUser(chatId);
        const ipInfo = await getIpInfo();
        const domain = config.domain || 'Not set';
        
        const escapedPassword = escapeHtml(result.password);
        const escapedDomain = escapeHtml(domain);
        const escapedCity = escapeHtml(ipInfo.city);
        const escapedIsp = escapeHtml(ipInfo.isp);
        
        const msg = `🎫 <b>TRIAL 30 MINUTES - PX STORE</b>

🔐 <b>Password</b> : <code>${escapedPassword}</code>
⏰ <b>Expired</b> : <code>30 minutes</code>
🌐 <b>IP Limit</b> : <code>1 Device</code>
🏷️ <b>Domain</b> : <code>${escapedDomain}</code>
📍 <b>City</b> : <code>${escapedCity}</code>
🏢 <b>ISP</b> : <code>${escapedIsp}</code>

🎫 <b>Account will expire in 30 minutes!</b>

✨ <b>Powered by PX STORE</b> ✨`;
        
        await sendMessage(chatId, msg);
    } catch (error) {
        await sendMessage(chatId, `❌ <b>Failed to create trial:</b> ${escapeHtml(error.message)}`);
    }
}

// ============ SHOW SYSTEM INFO ============
async function showSystemInfo(chatId) {
    const result = await apiCall('GET', '/system/info');
    const ipInfo = await getIpInfo();
    const domain = config.domain || 'Not set';
    
    const escapedDomain = escapeHtml(domain);
    const escapedCity = escapeHtml(ipInfo.city);
    const escapedIsp = escapeHtml(ipInfo.isp);
    const escapedPublicIp = escapeHtml(result.data?.public_ip || 'Unknown');
    
    let msg = `📊 <b>SYSTEM INFORMATION - PX STORE</b>

🏷️ <b>Domain</b> : <code>${escapedDomain}</code>
🌐 <b>Public IP</b> : <code>${escapedPublicIp}</code>
🔌 <b>UDP Port</b> : <code>${result.data?.port || '5667'}</code>
📡 <b>API Port</b> : <code>8585</code>
🖥️ <b>OS</b> : <code>${result.data?.os || 'Unknown'}</code>

📍 <b>City</b> : <code>${escapedCity}</code>
🏢 <b>ISP</b> : <code>${escapedIsp}</code>

⏰ <b>Server Time</b> : <code>${formatDate(new Date())}</code>

✨ <b>Powered by PX STORE</b> ✨`;
    
    await sendMessage(chatId, msg);
}

// ============ SHOW MAIN MENU ============
async function showMainMenu(chatId) {
    const ipInfo = await getIpInfo();
    const domain = config.domain || '(Not Configured)';
    const pricePerDay = config.daily_price || 1000;
    
    const escapedDomain = escapeHtml(domain);
    const escapedCity = escapeHtml(ipInfo.city);
    const escapedIsp = escapeHtml(ipInfo.isp);
    
    const msgText = `🏪 <b>PX STORE - ZIVPN PREMIUM</b>

📌 <b>SERVER INFO</b>
🏷️ <b>Domain</b> : <code>${escapedDomain}</code>
📍 <b>City</b> : <code>${escapedCity}</code>
🏢 <b>ISP</b> : <code>${escapedIsp}</code>

💰 <b>PRICE</b>
💎 <b>Rp ${formatNumber(pricePerDay)} / Day</b>

👇 <b>Please select menu below:</b>`;
    
    const keyboard = {
        inline_keyboard: [
            [{ text: "🛒 BUY PREMIUM ACCOUNT", callback_data: "menu_buy" }],
            [{ text: "🎫 TRIAL 30 MINUTES", callback_data: "menu_trial" }],
            [{ text: "📊 SYSTEM INFO", callback_data: "menu_info" }],
            [{ text: "📞 CONTACT ADMIN", callback_data: "menu_admin", url: "https://t.me/PeyxDev" }]
        ]
    };
    
    await sendMessage(chatId, msgText, { reply_markup: keyboard });
}

// ============ START BUY USER ============
async function startBuyUser(chatId, userId) {
    userStates.set(userId, 'buy_username');
    tempUserData.set(userId, {});
    await sendMessage(chatId, `👤 <b>Enter Password/Username:</b>

📌 Rules:
• 3-20 characters
• Letters, numbers, - and _`);
}

// ============ HANDLE BUY STATE ============
async function handleBuyState(chatId, userId, state, text) {
    switch (state) {
        case 'buy_username':
            if (text.length < 3 || text.length > 20) {
                await sendMessage(chatId, '❌ <b>Password must be 3-20 characters.</b> Try again:');
                return;
            }
            if (!/^[a-zA-Z0-9_-]+$/.test(text)) {
                await sendMessage(chatId, '❌ <b>Password only letters, numbers, - and _.</b> Try again:');
                return;
            }
            const userData = tempUserData.get(userId) || {};
            userData.username = text;
            tempUserData.set(userId, userData);
            userStates.set(userId, 'buy_days');
            await sendMessage(chatId, `⏳ <b>Enter duration (days)</b>

💰 <b>Price:</b> <code>Rp ${formatNumber(config.daily_price)} / day</code>`);
            break;
        case 'buy_days':
            const days = parseInt(text);
            if (isNaN(days) || days < 1 || days > 365) {
                await sendMessage(chatId, '❌ <b>Duration must be number (1-365).</b> Try again:');
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

// ============ HANDLE ADMIN COMMAND ============
async function handleAdminCommand(chatId, userId, text) {
    if (!text) return false;
    const isAdmin = config.admin_id == userId;
    if (!isAdmin) return false;
    
    if (text === '/users') {
        const result = await apiCall('GET', '/users');
        if (result.success && result.data) {
            let msg = `📋 <b>USER LIST - PX STORE</b>\n\n`;
            for (const user of result.data.slice(0, 30)) {
                const statusIcon = user.status === 'Active' ? '🟢' : (user.status === 'Locked' ? '🔒' : '🔴');
                const escapedPassword = escapeHtml(user.password);
                msg += `${statusIcon} <code>${escapedPassword}</code> | Exp: ${user.expired}\n`;
            }
            msg += `\n📌 <b>Total</b> : <code>${result.data.length}</code> users`;
            await sendMessage(chatId, msg);
        }
        return true;
    }
    
    if (text === '/stats') {
        const stats = await apiCall('GET', '/users/stats');
        if (stats.success && stats.data) {
            const msg = `📊 <b>STATISTICS - PX STORE</b>

👥 <b>Total Users</b> : <code>${stats.data.total}</code>
✅ <b>Active</b> : <code>${stats.data.active}</code>
⏰ <b>Expired</b> : <code>${stats.data.expired}</code>
🔒 <b>Locked</b> : <code>${stats.data.locked}</code>

✨ <b>Powered by PX STORE</b> ✨`;
            await sendMessage(chatId, msg);
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
                const escapedUsername = escapeHtml(username);
                const escapedExpired = escapeHtml(result.data.expired);
                await sendMessage(chatId, `✅ <b>User Created</b>

🔐 <b>Username</b> : <code>${escapedUsername}</code>
📅 <b>Expired</b> : <code>${escapedExpired}</code>
🌐 <b>IP Limit</b> : <code>${ipLimit}</code>`);
            } else {
                await sendMessage(chatId, `❌ <b>Failed:</b> ${escapeHtml(result.message)}`);
            }
        }
        return true;
    }
    
    if (text.startsWith('/delete ')) {
        const username = text.split(' ')[1];
        const result = await apiCall('POST', '/user/delete', { password: username });
        if (result.success) {
            await sendMessage(chatId, `✅ <b>User Deleted</b>

🔐 <b>Username</b> : <code>${escapeHtml(username)}</code>`);
        } else {
            await sendMessage(chatId, `❌ <b>Failed:</b> ${escapeHtml(result.message)}`);
        }
        return true;
    }
    
    return false;
}

// ============ HANDLE MESSAGE ============
async function handleMessage(msg) {
    const chatId = msg.chat.id;
    const userId = msg.from.id;
    const text = msg.text?.trim();
    
    if (userStates.has(userId)) {
        const state = userStates.get(userId);
        if (state === 'buy_username' || state === 'buy_days') {
            if (text) {
                await handleBuyState(chatId, userId, state, text);
            } else {
                await sendMessage(chatId, '❌ <b>Please enter valid text!</b>');
            }
        } else if (state === 'waiting_confirmation') {
            await sendMessage(chatId, '📤 <b>Please press CONFIRM PAYMENT button after you have paid.</b>');
        }
        return;
    }
    
    if (text === '/start') {
        await showMainMenu(chatId);
        return;
    }
    
    if (text === '/cancel') {
        resetState(userId);
        await showMainMenu(chatId);
        return;
    }
    
    await showMainMenu(chatId);
}

// ============ HANDLE CALLBACK ============
async function handleCallback(query) {
    const chatId = query.message.chat.id;
    const userId = query.from.id;
    const data = query.data;
    
    if (data.startsWith('confirm_payment:')) {
        const orderId = data.substring('confirm_payment:'.length);
        await handlePaymentConfirmation(chatId, userId, orderId, query.id);
    } else if (data.startsWith('admin_approve:')) {
        const parts = data.split(':');
        const targetUserId = parseInt(parts[1]);
        const orderId = parts[2];
        await adminApprove(targetUserId, orderId, userId);
        await bot.answerCallbackQuery(query.id);
    } else if (data.startsWith('admin_reject:')) {
        const parts = data.split(':');
        const targetUserId = parseInt(parts[1]);
        const orderId = parts[2];
        await adminReject(targetUserId, orderId, userId);
        await bot.answerCallbackQuery(query.id);
    } else {
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
                await showMainMenu(chatId);
                break;
            default:
                break;
        }
    }
    await bot.answerCallbackQuery(query.id);
}

// ============ MAIN ============
async function main() {
    console.log('=========================================');
    console.log('🏪 PX STORE - Seller Bot Starting...');
    console.log('=========================================');
    
    if (!loadConfig()) {
        console.error('❌ Failed to load config!');
        process.exit(1);
    }
    
    bot = new TelegramBot(config.bot_token, { polling: true });
    
    console.log('=========================================');
    console.log('✅ PX STORE - Seller Bot Started!');
    console.log(`📊 Daily Price: Rp ${formatNumber(config.daily_price)}`);
    console.log(`👑 Admin ID: ${config.admin_id}`);
    console.log(`🌐 Domain: ${config.domain || 'Not set'}`);
    console.log(`💳 QRIS API: ${config.qris?.api_url || 'Not set'}`);
    console.log('=========================================');
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