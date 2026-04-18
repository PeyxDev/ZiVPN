const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');
const fs = require('fs');

// ==================== KONFIGURASI ====================
const CONFIG_FILE = '/etc/zivpn/bot-config.json';
const API_KEY_FILE = '/etc/zivpn/apikey';
let bot = null;
let API_URL = 'http://localhost:8585';
let API_KEY = '';
let BOT_TOKEN = '';

// Baca konfigurasi
function loadConfig() {
    try {
        const config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
        return config;
    } catch (err) {
        console.error('Error loading config:', err.message);
        return null;
    }
}

// Baca API Key dari file apikey
function loadApiKey() {
    try {
        if (fs.existsSync(API_KEY_FILE)) {
            const key = fs.readFileSync(API_KEY_FILE, 'utf8').trim();
            return key;
        }
    } catch (err) {
        console.error('Error loading API Key:', err.message);
    }
    return null;
}

// Inisialisasi Bot
function initBot() {
    const config = loadConfig();
    if (!config) {
        console.error('Config not found! Run install-bot first.');
        return false;
    }
    
    BOT_TOKEN = config.bot_token;
    API_KEY = loadApiKey();
    if (!API_KEY) {
        console.error('API Key not found! Check /etc/zivpn/apikey');
        return false;
    }
    
    API_URL = config.api_url || 'http://localhost:8585';
    
    bot = new TelegramBot(BOT_TOKEN, { polling: true });
    console.log(`🤖 PX STORE Bot started for admin: ${config.admin_id}`);
    console.log(`🔑 Using API Key: ${API_KEY.substring(0, 15)}...`);
    return true;
}

// API Call
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

// Format tanggal
function formatDate(date) {
    return new Date(date).toLocaleString('id-ID', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// ==================== KEYBOARD MENU ====================
const mainMenu = {
    reply_markup: {
        inline_keyboard: [
            [{ text: "👥 USER MANAGEMENT", callback_data: "menu_users" }],
            [{ text: "⚙️ SERVICE", callback_data: "menu_service" }, { text: "💾 BACKUP", callback_data: "menu_backup" }],
            [{ text: "🔑 GITHUB", callback_data: "menu_github" }, { text: "📊 STATUS", callback_data: "status" }],
            [{ text: "ℹ️ INFO", callback_data: "info" }, { text: "🔄 RESTART ALL", callback_data: "service_restart_all" }]
        ]
    }
};

const userMenu = {
    reply_markup: {
        inline_keyboard: [
            [{ text: "➕ Create User", callback_data: "user_create" }, { text: "🎲 Random User", callback_data: "user_create_random" }],
            [{ text: "🗑️ Delete User", callback_data: "user_delete" }, { text: "🔄 Renew User", callback_data: "user_renew" }],
            [{ text: "📋 List Users", callback_data: "user_list" }, { text: "⏱️ Trial (30m)", callback_data: "user_trial" }],
            [{ text: "🔒 Lock User", callback_data: "user_lock" }, { text: "🔓 Unlock User", callback_data: "user_unlock" }],
            [{ text: "🔙 Back to Main", callback_data: "back_main" }]
        ]
    }
};

const serviceMenu = {
    reply_markup: {
        inline_keyboard: [
            [{ text: "🔄 Restart All", callback_data: "service_restart_all" }, { text: "🔄 Restart Core", callback_data: "service_restart_zivpn" }],
            [{ text: "🔄 Restart API", callback_data: "service_restart_api" }, { text: "🔄 Restart Bot", callback_data: "service_restart_bot" }],
            [{ text: "📊 Service Status", callback_data: "service_status" }],
            [{ text: "🔙 Back to Main", callback_data: "back_main" }]
        ]
    }
};

const backupMenu = {
    reply_markup: {
        inline_keyboard: [
            [{ text: "💾 Create Backup", callback_data: "backup_create" }, { text: "📁 List Backups", callback_data: "backup_list" }],
            [{ text: "🔄 Restore Backup", callback_data: "backup_restore" }],
            [{ text: "🔙 Back to Main", callback_data: "back_main" }]
        ]
    }
};

const githubMenu = {
    reply_markup: {
        inline_keyboard: [
            [{ text: "🔑 Set Token", callback_data: "github_set" }, { text: "📋 Check Token", callback_data: "github_check" }],
            [{ text: "🗑️ Delete Token", callback_data: "github_delete" }],
            [{ text: "🔙 Back to Main", callback_data: "back_main" }]
        ]
    }
};

// ==================== SEND MESSAGE FUNCTIONS ====================
async function sendMainMenu(chatId) {
    const msg = `✨ *PX STORE - ZIVPN BOT MANAGER* ✨\n━━━━━━━━━━━━━━━━━━━━\n🤖 *Welcome to Premium Bot*\n📱 *Manage your VPN easily*\n━━━━━━━━━━━━━━━━━━━━\n\nSelect menu below 👇`;
    await bot.sendMessage(chatId, msg, { ...mainMenu, parse_mode: 'Markdown' });
}

// ==================== HANDLERS ====================
async function handleStart(chatId) {
    const config = loadConfig();
    if (config && config.admin_id == chatId) {
        await sendMainMenu(chatId);
    } else {
        await bot.sendMessage(chatId, '❌ *Access Denied*\nYou are not authorized to use this bot.', { parse_mode: 'Markdown' });
    }
}

async function handleInfo(chatId) {
    await bot.sendMessage(chatId, 'ℹ️ *Fetching system information...*', { parse_mode: 'Markdown' });
    
    try {
        const [sysInfo, userStats, serviceStatus] = await Promise.all([
            apiCall('GET', '/api/system/info'),
            apiCall('GET', '/api/users/stats'),
            apiCall('GET', '/api/service/status')
        ]);
        
        let msg = `🏪 *PX STORE - SYSTEM INFORMATION*\n━━━━━━━━━━━━━━━━━━━━\n`;
        
        // SERVER INFO
        msg += `*🖥️ SERVER INFO:*\n`;
        if (sysInfo && sysInfo.success && sysInfo.data) {
            msg += `🏷️ *Domain*: ${sysInfo.data.domain || 'Not set'}\n`;
            msg += `🌐 *Public IP*: ${sysInfo.data.public_ip || 'Unknown'}\n`;
            msg += `🔌 *UDP Port*: ${sysInfo.data.port || '5667'}\n`;
            msg += `📡 *API Port*: ${sysInfo.data.api_port || '8585'}\n`;
            msg += `🖥️ *OS*: ${sysInfo.data.os || 'Unknown'}\n`;
            msg += `🏢 *ISP*: ${sysInfo.data.isp || 'Unknown'}\n`;
            msg += `📍 *City*: ${sysInfo.data.city || 'Unknown'}\n`;
            msg += `⏱️ *Uptime*: ${sysInfo.data.uptime || 'Unknown'}\n`;
            msg += `💾 *Memory*: ${sysInfo.data.memory?.used || '0'} GB / ${sysInfo.data.memory?.total || '0'} GB\n`;
        } else {
            msg += `❌ Failed to get server info\n`;
        }
        
        // SERVICE STATUS
        msg += `\n*⚙️ SERVICE STATUS:*\n`;
        if (serviceStatus && serviceStatus.success && serviceStatus.data) {
            msg += `🟢 *ZiVPN Core*: ${serviceStatus.data.zivpn?.active ? '✅ Running' : '❌ Stopped'}\n`;
            msg += `🟢 *API Service*: ${serviceStatus.data['zivpn-api-js']?.active ? '✅ Running' : '❌ Stopped'}\n`;
            msg += `🟢 *Bot Service*: ${serviceStatus.data['zivpn-bot']?.active ? '✅ Running' : '❌ Stopped'}\n`;
        } else {
            msg += `❌ Failed to get service status\n`;
        }
        
        // USERS STATISTICS
        msg += `\n*👥 USERS STATISTICS:*\n`;
        if (userStats && userStats.success && userStats.data) {
            msg += `👥 *Total Users*: ${userStats.data.total}\n`;
            msg += `✅ *Active*: ${userStats.data.active}\n`;
            msg += `⏰ *Expired*: ${userStats.data.expired}\n`;
            msg += `🔒 *Locked*: ${userStats.data.locked}\n`;
        } else {
            msg += `❌ Failed to get user statistics\n`;
        }
        
        // BOT INFO
        msg += `\n*🤖 BOT INFO:*\n`;
        msg += `🤖 *Bot Name*: PX STORE\n`;
        msg += `📦 *Version*: 2.0.0\n`;
        msg += `📅 *Server Time*: ${formatDate(new Date())}\n`;
        msg += `⏱️ *Bot Uptime*: ${Math.floor(process.uptime() / 60)} minutes\n`;
        msg += `━━━━━━━━━━━━━━━━━━━━\n`;
        msg += `✨ *Powered by PX STORE* ✨`;
        
        await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
    } catch (error) {
        console.error('Info error:', error);
        await bot.sendMessage(chatId, '❌ *Failed to fetch system information*', { parse_mode: 'Markdown' });
    }
}

async function handleStatus(chatId) {
    await bot.sendMessage(chatId, '📊 *Fetching system status...*', { parse_mode: 'Markdown' });
    
    try {
        const [sysInfo, userStats, serviceStatus] = await Promise.all([
            apiCall('GET', '/api/system/info'),
            apiCall('GET', '/api/users/stats'),
            apiCall('GET', '/api/service/status')
        ]);
        
        let msg = `📊 *SYSTEM STATUS*\n━━━━━━━━━━━━━━━━━━━━\n`;
        
        // SERVICE STATUS
        msg += `*⚙️ SERVICE STATUS:*\n`;
        if (serviceStatus && serviceStatus.success && serviceStatus.data) {
            msg += `🟢 ZiVPN Core: ${serviceStatus.data.zivpn?.active ? '✅ Running' : '❌ Stopped'}\n`;
            msg += `🟢 API Service: ${serviceStatus.data['zivpn-api-js']?.active ? '✅ Running' : '❌ Stopped'}\n`;
            msg += `🟢 Bot Service: ${serviceStatus.data['zivpn-bot']?.active ? '✅ Running' : '❌ Stopped'}\n`;
        } else {
            msg += `❌ Failed to get service status\n`;
        }
        
        // SYSTEM INFO
        msg += `\n*🖥️ SYSTEM INFO:*\n`;
        if (sysInfo && sysInfo.success && sysInfo.data) {
            msg += `🏷️ Domain: ${sysInfo.data.domain || 'Not set'}\n`;
            msg += `🌐 Public IP: ${sysInfo.data.public_ip || 'Unknown'}\n`;
            msg += `🔌 UDP Port: ${sysInfo.data.port || '5667'}\n`;
            msg += `📡 API Port: ${sysInfo.data.api_port || '8585'}\n`;
            msg += `🖥️ OS: ${sysInfo.data.os || 'Unknown'}\n`;
            msg += `🏢 ISP: ${sysInfo.data.isp || 'Unknown'}\n`;
            msg += `📍 City: ${sysInfo.data.city || 'Unknown'}\n`;
            msg += `⏱️ Uptime: ${sysInfo.data.uptime || 'Unknown'}\n`;
        } else {
            msg += `❌ Failed to get system info\n`;
        }
        
        // USERS STATISTICS
        msg += `\n*👥 USERS STATISTICS:*\n`;
        if (userStats && userStats.success && userStats.data) {
            msg += `👥 Total Users: ${userStats.data.total}\n`;
            msg += `✅ Active: ${userStats.data.active}\n`;
            msg += `⏰ Expired: ${userStats.data.expired}\n`;
            msg += `🔒 Locked: ${userStats.data.locked}\n`;
        } else {
            msg += `❌ Failed to get user statistics\n`;
        }
        
        msg += `━━━━━━━━━━━━━━━━━━━━\n`;
        msg += `⏰ *Updated*: ${formatDate(new Date())}`;
        
        await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
    } catch (error) {
        console.error('Status error:', error);
        await bot.sendMessage(chatId, '❌ *Failed to fetch system status*', { parse_mode: 'Markdown' });
    }
}

// ==================== USER MANAGEMENT HANDLERS ====================
async function handleListUsers(chatId) {
    await bot.sendMessage(chatId, '📋 *Fetching user list...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('GET', '/api/users');
    
    if (!result.success || !result.data || result.data.length === 0) {
        await bot.sendMessage(chatId, '📋 *No users found*', { parse_mode: 'Markdown' });
        return;
    }
    
    let msg = `📋 *USER LIST*\n━━━━━━━━━━━━━━━━━━━━\n`;
    
    for (const user of result.data.slice(0, 20)) {
        let statusIcon = '🟢';
        if (user.status === 'Locked') statusIcon = '🔒';
        else if (user.status === 'Expired') statusIcon = '🔴';
        
        msg += `${statusIcon} *${user.password}*\n`;
        msg += `   📅 Exp: ${user.expired} | 🌐 IP: ${user.ip_limit}\n`;
    }
    
    if (result.data.length > 20) {
        msg += `\n📌 *Showing 20 of ${result.data.length} users*`;
    }
    
    msg += `\n━━━━━━━━━━━━━━━━━━━━\n📌 *Total*: ${result.data.length} users`;
    
    await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
}

async function handleCreateUser(chatId) {
    await bot.sendMessage(chatId, '📝 *Create User*\n━━━━━━━━━━━━━━━━━━━━\nSend username/password:', { parse_mode: 'Markdown' });
    
    const password = await new Promise(resolve => {
        bot.once('message', msg => {
            if (msg.chat.id === chatId) resolve(msg.text);
        });
    });
    
    await bot.sendMessage(chatId, '📅 *Enter duration (days):*', { parse_mode: 'Markdown' });
    const days = await new Promise(resolve => {
        bot.once('message', msg => {
            if (msg.chat.id === chatId) resolve(parseInt(msg.text));
        });
    });
    
    await bot.sendMessage(chatId, '🌐 *IP Limit (0 = unlimited):*', { parse_mode: 'Markdown' });
    const iplimit = await new Promise(resolve => {
        bot.once('message', msg => {
            if (msg.chat.id === chatId) resolve(parseInt(msg.text));
        });
    });
    
    await bot.sendMessage(chatId, '⏳ *Creating user...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('POST', '/api/user/create', { password, days, iplimit });
    
    if (result.success) {
        const msg = `✅ *USER CREATED*\n━━━━━━━━━━━━━━━━━━━━\n👤 *Username*: \`${password}\`\n📅 *Expired*: ${result.data.expired}\n🌐 *IP Limit*: ${result.data.ip_limit}\n🏷️ *Domain*: ${result.data.domain}\n━━━━━━━━━━━━━━━━━━━━\n✅ User created successfully!`;
        await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleCreateRandomUser(chatId) {
    await bot.sendMessage(chatId, '📅 *Enter duration (days):*', { parse_mode: 'Markdown' });
    const days = await new Promise(resolve => {
        bot.once('message', msg => {
            if (msg.chat.id === chatId) resolve(parseInt(msg.text));
        });
    });
    
    await bot.sendMessage(chatId, '🌐 *IP Limit (0 = unlimited):*', { parse_mode: 'Markdown' });
    const iplimit = await new Promise(resolve => {
        bot.once('message', msg => {
            if (msg.chat.id === chatId) resolve(parseInt(msg.text));
        });
    });
    
    await bot.sendMessage(chatId, '⏳ *Creating random user...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('POST', '/api/user/create-random', { days, iplimit });
    
    if (result.success) {
        const msg = `🎲 *RANDOM USER CREATED*\n━━━━━━━━━━━━━━━━━━━━\n👤 *Username*: \`${result.data.password}\`\n📅 *Expired*: ${result.data.expired}\n🌐 *IP Limit*: ${result.data.ip_limit}\n🏷️ *Domain*: ${result.data.domain}\n━━━━━━━━━━━━━━━━━━━━\n✅ Random user created!`;
        await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleDeleteUser(chatId) {
    await bot.sendMessage(chatId, '🗑️ *Delete User*\n━━━━━━━━━━━━━━━━━━━━\nSend username to delete:', { parse_mode: 'Markdown' });
    
    const password = await new Promise(resolve => {
        bot.once('message', msg => {
            if (msg.chat.id === chatId) resolve(msg.text);
        });
    });
    
    await bot.sendMessage(chatId, '⏳ *Deleting user...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('POST', '/api/user/delete', { password });
    
    if (result.success) {
        await bot.sendMessage(chatId, `✅ *User ${password} deleted successfully!*`, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleRenewUser(chatId) {
    await bot.sendMessage(chatId, '🔄 *Renew User*\n━━━━━━━━━━━━━━━━━━━━\nSend username:', { parse_mode: 'Markdown' });
    
    const password = await new Promise(resolve => {
        bot.once('message', msg => {
            if (msg.chat.id === chatId) resolve(msg.text);
        });
    });
    
    await bot.sendMessage(chatId, '📅 *Add days:*', { parse_mode: 'Markdown' });
    const days = await new Promise(resolve => {
        bot.once('message', msg => {
            if (msg.chat.id === chatId) resolve(parseInt(msg.text));
        });
    });
    
    await bot.sendMessage(chatId, '⏳ *Renewing user...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('POST', '/api/user/renew', { password, days });
    
    if (result.success) {
        const msg = `✅ *USER RENEWED*\n━━━━━━━━━━━━━━━━━━━━\n👤 *Username*: \`${password}\`\n📅 *New Expired*: ${result.data.expired}\n📆 *Added*: +${days} days\n━━━━━━━━━━━━━━━━━━━━\n✅ User renewed successfully!`;
        await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleTrialUser(chatId) {
    await bot.sendMessage(chatId, '⏳ *Creating trial user (30 minutes)...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('POST', '/api/user/trial', {});
    
    if (result.success) {
        const msg = `⏱️ *TRIAL USER CREATED*\n━━━━━━━━━━━━━━━━━━━━\n👤 *Username*: \`${result.data.password}\`\n⏰ *Expired*: 30 minutes\n🌐 *IP Limit*: 1\n🏷️ *Domain*: ${result.data.domain}\n━━━━━━━━━━━━━━━━━━━━\n🎫 Trial user will expire in 30 minutes!`;
        await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleLockUser(chatId) {
    await bot.sendMessage(chatId, '🔒 *Lock User*\n━━━━━━━━━━━━━━━━━━━━\nSend username to lock:', { parse_mode: 'Markdown' });
    
    const password = await new Promise(resolve => {
        bot.once('message', msg => {
            if (msg.chat.id === chatId) resolve(msg.text);
        });
    });
    
    await bot.sendMessage(chatId, '⏳ *Locking user...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('POST', '/api/user/lock', { password });
    
    if (result.success) {
        await bot.sendMessage(chatId, `✅ *User ${password} locked successfully!*`, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleUnlockUser(chatId) {
    await bot.sendMessage(chatId, '🔓 *Unlock User*\n━━━━━━━━━━━━━━━━━━━━\nSend username to unlock:', { parse_mode: 'Markdown' });
    
    const password = await new Promise(resolve => {
        bot.once('message', msg => {
            if (msg.chat.id === chatId) resolve(msg.text);
        });
    });
    
    await bot.sendMessage(chatId, '⏳ *Unlocking user...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('POST', '/api/user/unlock', { password });
    
    if (result.success) {
        await bot.sendMessage(chatId, `✅ *User ${password} unlocked successfully!*`, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

// ==================== SERVICE HANDLERS ====================
async function handleRestartAll(chatId) {
    await bot.sendMessage(chatId, '🔄 *Restarting all services...*', { parse_mode: 'Markdown' });
    const result = await apiCall('POST', '/api/service/restart', {});
    
    if (result.success) {
        await bot.sendMessage(chatId, '✅ *All services restarted successfully!*', { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleRestartZivpn(chatId) {
    await bot.sendMessage(chatId, '🔄 *Restarting ZiVPN core...*', { parse_mode: 'Markdown' });
    const result = await apiCall('POST', '/api/service/restart/zivpn', {});
    
    if (result.success) {
        await bot.sendMessage(chatId, '✅ *ZiVPN core restarted successfully!*', { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleRestartApi(chatId) {
    await bot.sendMessage(chatId, '🔄 *Restarting API service...*', { parse_mode: 'Markdown' });
    const result = await apiCall('POST', '/api/service/restart/api', {});
    
    if (result.success) {
        await bot.sendMessage(chatId, '✅ *API service restarted successfully!*', { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleRestartBot(chatId) {
    await bot.sendMessage(chatId, '🔄 *Restarting bot service...*', { parse_mode: 'Markdown' });
    const result = await apiCall('POST', '/api/service/restart/bot', {});
    
    if (result.success) {
        await bot.sendMessage(chatId, '✅ *Bot service restarted successfully!*', { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleServiceStatus(chatId) {
    await bot.sendMessage(chatId, '📊 *Fetching service status...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('GET', '/api/service/status');
    
    if (result.success && result.data) {
        let msg = `📊 *SERVICE STATUS*\n━━━━━━━━━━━━━━━━━━━━\n`;
        msg += `🟢 *ZiVPN Core*: ${result.data.zivpn?.active ? '✅ Running' : '❌ Stopped'}\n`;
        msg += `🟢 *API Service*: ${result.data['zivpn-api-js']?.active ? '✅ Running' : '❌ Stopped'}\n`;
        msg += `🟢 *Bot Service*: ${result.data['zivpn-bot']?.active ? '✅ Running' : '❌ Stopped'}\n`;
        msg += `━━━━━━━━━━━━━━━━━━━━\n⏰ *Updated*: ${formatDate(new Date())}`;
        await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, '❌ *Failed to get service status*', { parse_mode: 'Markdown' });
    }
}

// ==================== BACKUP HANDLERS ====================
async function handleCreateBackup(chatId) {
    await bot.sendMessage(chatId, '💾 *Creating backup...*', { parse_mode: 'Markdown' });
    const result = await apiCall('POST', '/api/backup/create', {});
    
    if (result.success) {
        const msg = `✅ *BACKUP CREATED*\n━━━━━━━━━━━━━━━━━━━━\n🆔 *Backup ID*: \`${result.data.backup_id}\`\n📅 *Time*: ${formatDate(new Date())}\n━━━━━━━━━━━━━━━━━━━━\n✅ Backup created successfully!`;
        await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleListBackups(chatId) {
    await bot.sendMessage(chatId, '📁 *Fetching backup list...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('GET', '/api/backup/list');
    
    if (result.success && result.data && result.data.length > 0) {
        let msg = `📁 *BACKUP LIST*\n━━━━━━━━━━━━━━━━━━━━\n`;
        for (const backup of result.data.slice(0, 10)) {
            const sizeKB = Math.round(backup.size / 1024);
            msg += `📦 *${backup.id}*\n   📅 ${new Date(backup.created).toLocaleDateString()} | 📦 ${sizeKB} KB\n`;
        }
        msg += `━━━━━━━━━━━━━━━━━━━━\n📌 *Total*: ${result.data.length} backups`;
        await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, '📁 *No backups found*', { parse_mode: 'Markdown' });
    }
}

async function handleRestoreBackup(chatId) {
    await bot.sendMessage(chatId, '🔄 *Restore Backup*\n━━━━━━━━━━━━━━━━━━━━\nSend Backup ID to restore:', { parse_mode: 'Markdown' });
    
    const backup_id = await new Promise(resolve => {
        bot.once('message', msg => {
            if (msg.chat.id === chatId) resolve(msg.text);
        });
    });
    
    await bot.sendMessage(chatId, '⏳ *Restoring backup...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('POST', '/api/backup/restore', { backup_id });
    
    if (result.success) {
        await bot.sendMessage(chatId, `✅ *Backup ${backup_id} restored successfully!*`, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

// ==================== GITHUB HANDLERS ====================
async function handleGitHubSet(chatId) {
    await bot.sendMessage(chatId, '🔑 *Set GitHub Token*\n━━━━━━━━━━━━━━━━━━━━\nSend your GitHub Personal Access Token:', { parse_mode: 'Markdown' });
    
    const token = await new Promise(resolve => {
        bot.once('message', msg => {
            if (msg.chat.id === chatId) resolve(msg.text);
        });
    });
    
    await bot.sendMessage(chatId, '⏳ *Saving token...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('POST', '/api/github/token', { token });
    
    if (result.success) {
        await bot.sendMessage(chatId, '✅ *GitHub token saved successfully!*', { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleGitHubCheck(chatId) {
    await bot.sendMessage(chatId, '🔍 *Checking GitHub token...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('GET', '/api/github/token');
    
    if (result.success && result.data) {
        const msg = `🔑 *GITHUB TOKEN STATUS*\n━━━━━━━━━━━━━━━━━━━━\n📋 *Configured*: ${result.data.configured ? '✅ Yes' : '❌ No'}\n🔐 *Token*: ${result.data.token || 'Not set'}\n━━━━━━━━━━━━━━━━━━━━\n✅ Use /start to return to main menu`;
        await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleGitHubDelete(chatId) {
    await bot.sendMessage(chatId, '🗑️ *Deleting GitHub token...*', { parse_mode: 'Markdown' });
    
    const result = await apiCall('DELETE', '/api/github/token');
    
    if (result.success) {
        await bot.sendMessage(chatId, '✅ *GitHub token deleted successfully!*', { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

// ==================== CALLBACK HANDLER ====================
async function handleCallback(query) {
    const chatId = query.message.chat.id;
    const data = query.data;
    
    switch(data) {
        case 'back_main':
            await sendMainMenu(chatId);
            break;
        case 'menu_users':
            await bot.sendMessage(chatId, '👥 *USER MANAGEMENT*\n━━━━━━━━━━━━━━━━━━━━\nSelect action below:', { ...userMenu, parse_mode: 'Markdown' });
            break;
        case 'menu_service':
            await bot.sendMessage(chatId, '⚙️ *SERVICE MANAGEMENT*\n━━━━━━━━━━━━━━━━━━━━\nSelect action below:', { ...serviceMenu, parse_mode: 'Markdown' });
            break;
        case 'menu_backup':
            await bot.sendMessage(chatId, '💾 *BACKUP MANAGEMENT*\n━━━━━━━━━━━━━━━━━━━━\nSelect action below:', { ...backupMenu, parse_mode: 'Markdown' });
            break;
        case 'menu_github':
            await bot.sendMessage(chatId, '🔑 *GITHUB TOKEN MANAGEMENT*\n━━━━━━━━━━━━━━━━━━━━\nSelect action below:', { ...githubMenu, parse_mode: 'Markdown' });
            break;
        case 'status':
            await handleStatus(chatId);
            break;
        case 'info':
            await handleInfo(chatId);
            break;
        case 'user_list':
            await handleListUsers(chatId);
            break;
        case 'user_create':
            await handleCreateUser(chatId);
            break;
        case 'user_create_random':
            await handleCreateRandomUser(chatId);
            break;
        case 'user_delete':
            await handleDeleteUser(chatId);
            break;
        case 'user_renew':
            await handleRenewUser(chatId);
            break;
        case 'user_trial':
            await handleTrialUser(chatId);
            break;
        case 'user_lock':
            await handleLockUser(chatId);
            break;
        case 'user_unlock':
            await handleUnlockUser(chatId);
            break;
        case 'service_restart_all':
            await handleRestartAll(chatId);
            break;
        case 'service_restart_zivpn':
            await handleRestartZivpn(chatId);
            break;
        case 'service_restart_api':
            await handleRestartApi(chatId);
            break;
        case 'service_restart_bot':
            await handleRestartBot(chatId);
            break;
        case 'service_status':
            await handleServiceStatus(chatId);
            break;
        case 'backup_create':
            await handleCreateBackup(chatId);
            break;
        case 'backup_list':
            await handleListBackups(chatId);
            break;
        case 'backup_restore':
            await handleRestoreBackup(chatId);
            break;
        case 'github_set':
            await handleGitHubSet(chatId);
            break;
        case 'github_check':
            await handleGitHubCheck(chatId);
            break;
        case 'github_delete':
            await handleGitHubDelete(chatId);
            break;
        default:
            await bot.answerCallbackQuery(query.id, { text: 'Coming soon!' });
    }
    
    await bot.answerCallbackQuery(query.id);
}

// ==================== MAIN ====================
async function main() {
    if (!initBot()) {
        console.error('Failed to initialize bot.');
        process.exit(1);
    }
    
    bot.onText(/\/start/, (msg) => handleStart(msg.chat.id));
    bot.on('callback_query', handleCallback);
    
    console.log('🤖 PX STORE Bot is running...');
    console.log('📡 Waiting for commands...');
}

main().catch(console.error);
