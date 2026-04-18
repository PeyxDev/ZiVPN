const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');
const fs = require('fs');
const path = require('path');

// ==================== KONFIGURASI ====================
const CONFIG_FILE = '/etc/zivpn/bot-config.json';
let bot = null;
let API_URL = '';
let API_KEY = '';

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

// Inisialisasi Bot
function initBot() {
    const config = loadConfig();
    if (!config) {
        console.error('Config not found! Run config-bot first.');
        return false;
    }
    
    API_URL = `http://localhost:8585`;
    API_KEY = config.bot_token;
    
    bot = new TelegramBot(config.bot_token, { polling: true });
    console.log(`🤖 Bot started for admin: ${config.admin_id}`);
    return true;
}

// ==================== HELPER FUNCTIONS ====================
async function apiCall(method, endpoint, data = null) {
    try {
        const url = `${API_URL}${endpoint}`;
        const headers = { 'x-api-key': API_KEY };
        
        let response;
        if (method === 'GET') {
            response = await axios.get(url, { headers });
        } else {
            response = await axios.post(url, data, { headers });
        }
        
        return response.data;
    } catch (error) {
        console.error(`API Error: ${error.message}`);
        return { success: false, message: error.message };
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

// ==================== KEYBOARD MENU ====================
const mainMenu = {
    reply_markup: {
        inline_keyboard: [
            [
                { text: "👥 USER MANAGEMENT", callback_data: "menu_users" }
            ],
            [
                { text: "🤖 BOT SETTINGS", callback_data: "menu_bot" },
                { text: "⚙️ SERVICE", callback_data: "menu_service" }
            ],
            [
                { text: "💾 BACKUP", callback_data: "menu_backup" },
                { text: "🔑 GITHUB", callback_data: "menu_github" }
            ],
            [
                { text: "📊 STATUS", callback_data: "status" },
                { text: "ℹ️ INFO", callback_data: "info" }
            ]
        ],
        resize_keyboard: true
    }
};

const userMenu = {
    reply_markup: {
        inline_keyboard: [
            [
                { text: "➕ Create User", callback_data: "user_create" },
                { text: "🎲 Random User", callback_data: "user_create_random" }
            ],
            [
                { text: "🗑️ Delete User", callback_data: "user_delete" },
                { text: "🔄 Renew User", callback_data: "user_renew" }
            ],
            [
                { text: "📋 List Users", callback_data: "user_list" },
                { text: "⏱️ Trial (30m)", callback_data: "user_trial" }
            ],
            [
                { text: "🔒 Lock User", callback_data: "user_lock" },
                { text: "🔓 Unlock User", callback_data: "user_unlock" }
            ],
            [
                { text: "🔙 Back", callback_data: "back_main" }
            ]
        ]
    }
};

const serviceMenu = {
    reply_markup: {
        inline_keyboard: [
            [
                { text: "🔄 Restart All", callback_data: "service_restart_all" },
                { text: "🔄 Restart Core", callback_data: "service_restart_zivpn" }
            ],
            [
                { text: "🔄 Restart API", callback_data: "service_restart_api" },
                { text: "🔄 Restart Bot", callback_data: "service_restart_bot" }
            ],
            [
                { text: "📊 Service Status", callback_data: "service_status" }
            ],
            [
                { text: "🔙 Back", callback_data: "back_main" }
            ]
        ]
    }
};

const backupMenu = {
    reply_markup: {
        inline_keyboard: [
            [
                { text: "💾 Create Backup", callback_data: "backup_create" },
                { text: "🔄 Restore Backup", callback_data: "backup_restore" }
            ],
            [
                { text: "📁 List Backups", callback_data: "backup_list" }
            ],
            [
                { text: "🔙 Back", callback_data: "back_main" }
            ]
        ]
    }
};

const githubMenu = {
    reply_markup: {
        inline_keyboard: [
            [
                { text: "🔑 Set Token", callback_data: "github_set" },
                { text: "📋 Check Token", callback_data: "github_check" }
            ],
            [
                { text: "🗑️ Delete Token", callback_data: "github_delete" }
            ],
            [
                { text: "🔙 Back", callback_data: "back_main" }
            ]
        ]
    }
};

// ==================== BOT COMMANDS ====================
async function sendMainMenu(chatId) {
    const msg = `✨ *ZIVPN BOT MANAGER* ✨\n━━━━━━━━━━━━━━━━━━━━\n🤖 *Welcome to ZiVPN Bot*\n📱 *Manage your VPN easily*\n━━━━━━━━━━━━━━━━━━━━\n\nSelect menu below 👇`;
    await bot.sendMessage(chatId, msg, { ...mainMenu, parse_mode: 'Markdown' });
}

async function handleStart(chatId) {
    const config = loadConfig();
    if (config && config.admin_id == chatId) {
        await sendMainMenu(chatId);
    } else {
        await bot.sendMessage(chatId, '❌ *Access Denied*\nYou are not authorized to use this bot.', { parse_mode: 'Markdown' });
    }
}

async function handleStatus(chatId) {
    const status = await apiCall('GET', '/api/service/status');
    const sysInfo = await apiCall('GET', '/api/info');
    
    let msg = `📊 *SYSTEM STATUS*\n━━━━━━━━━━━━━━━━━━━━\n`;
    
    if (status.success && status.data) {
        const services = status.data;
        msg += `🟢 *ZiVPN Core*: ${services.zivpn?.active ? '✅ Running' : '❌ Stopped'}\n`;
        msg += `🟢 *API Service*: ${services['zivpn-api-js']?.active ? '✅ Running' : '❌ Stopped'}\n`;
        msg += `🟢 *Bot Service*: ${services['zivpn-bot']?.active ? '✅ Running' : '❌ Stopped'}\n`;
    }
    
    if (sysInfo.success && sysInfo.data) {
        msg += `\n🌐 *Domain*: ${sysInfo.data.domain}\n`;
        msg += `📡 *Public IP*: ${sysInfo.data.public_ip}\n`;
    }
    
    const users = await apiCall('GET', '/api/users');
    if (users.success && users.data) {
        const activeUsers = users.data.filter(u => u.status === 'Active').length;
        const expiredUsers = users.data.filter(u => u.status === 'Expired').length;
        msg += `\n👥 *Users*: ${users.data.length} total\n`;
        msg += `   ✅ Active: ${activeUsers}\n`;
        msg += `   ⏰ Expired: ${expiredUsers}\n`;
    }
    
    msg += `\n━━━━━━━━━━━━━━━━━━━━\n⏰ *Updated*: ${formatDate(new Date())}`;
    await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
}

async function handleInfo(chatId) {
    const sysInfo = await apiCall('GET', '/api/info');
    const config = await apiCall('GET', '/api/config');
    
    let msg = `ℹ️ *SYSTEM INFORMATION*\n━━━━━━━━━━━━━━━━━━━━\n`;
    msg += `🏷️ *Domain*: ${sysInfo.data?.domain || 'N/A'}\n`;
    msg += `🌐 *Public IP*: ${sysInfo.data?.public_ip || 'N/A'}\n`;
    msg += `🔌 *UDP Port*: ${sysInfo.data?.port || '5667'}\n`;
    msg += `📡 *API Port*: 8585\n`;
    msg += `━━━━━━━━━━━━━━━━━━━━\n`;
    msg += `👥 *Total Users*: ${config.data?.total_users || 0}\n`;
    msg += `✅ *Active Users*: ${config.data?.active_users || 0}\n`;
    msg += `🔑 *GitHub Token*: ${config.data?.github_token_configured ? '✅ Configured' : '❌ Not Set'}\n`;
    msg += `━━━━━━━━━━━━━━━━━━━━\n`;
    msg += `🤖 *Bot Version*: 2.0.0\n`;
    msg += `📅 *Server Time*: ${formatDate(new Date())}`;
    
    await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
}

async function handleListUsers(chatId) {
    const result = await apiCall('GET', '/api/users');
    
    if (!result.success || !result.data || result.data.length === 0) {
        await bot.sendMessage(chatId, '📋 *No users found*', { parse_mode: 'Markdown' });
        return;
    }
    
    let msg = `📋 *USER LIST*\n━━━━━━━━━━━━━━━━━━━━\n`;
    
    for (const user of result.data.slice(0, 20)) {
        const statusIcon = user.status === 'Active' ? '🟢' : (user.status === 'Locked' ? '🔒' : '🔴');
        msg += `${statusIcon} *${user.password}*\n`;
        msg += `   📅 Exp: ${user.expired} | 🌐 IP: ${user.ip_limit}\n`;
    }
    
    if (result.data.length > 20) {
        msg += `\n📌 *Showing 20 of ${result.data.length} users*`;
    }
    
    msg += `\n━━━━━━━━━━━━━━━━━━━━\n📌 *Total*: ${result.data.length} users`;
    
    await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
}

async function handleCreateUser(chatId, password = null, days = null, iplimit = null) {
    if (!password) {
        await bot.sendMessage(chatId, '📝 *Create User*\n━━━━━━━━━━━━━━━━━━━━\nSend username/password:', { parse_mode: 'Markdown' });
        const response = await new Promise(resolve => {
            bot.once('message', msg => {
                if (msg.chat.id === chatId) resolve(msg.text);
            });
        });
        password = response;
    }
    
    if (!days) {
        await bot.sendMessage(chatId, '📅 *Enter duration (days)*:', { parse_mode: 'Markdown' });
        const response = await new Promise(resolve => {
            bot.once('message', msg => {
                if (msg.chat.id === chatId) resolve(msg.text);
            });
        });
        days = parseInt(response);
    }
    
    if (!iplimit) {
        await bot.sendMessage(chatId, '🌐 *IP Limit (0 = unlimited)*:', { parse_mode: 'Markdown' });
        const response = await new Promise(resolve => {
            bot.once('message', msg => {
                if (msg.chat.id === chatId) resolve(msg.text);
            });
        });
        iplimit = parseInt(response);
    }
    
    const result = await apiCall('POST', '/api/user/create', { password, days, iplimit });
    
    if (result.success) {
        const msg = `✅ *USER CREATED*\n━━━━━━━━━━━━━━━━━━━━\n👤 *Username*: \`${password}\`\n📅 *Expired*: ${result.data.expired}\n🌐 *IP Limit*: ${result.data.ip_limit}\n🏷️ *Domain*: ${result.data.domain}\n━━━━━━━━━━━━━━━━━━━━\n✅ User created successfully!`;
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
    
    const result = await apiCall('POST', '/api/user/renew', { password, days });
    
    if (result.success) {
        const msg = `✅ *USER RENEWED*\n━━━━━━━━━━━━━━━━━━━━\n👤 *Username*: \`${password}\`\n📅 *New Expired*: ${result.data.expired}\n📆 *Added*: +${days} days\n━━━━━━━━━━━━━━━━━━━━\n✅ User renewed successfully!`;
        await bot.sendMessage(chatId, msg, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleTrialUser(chatId) {
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
    
    const result = await apiCall('POST', '/api/user/unlock', { password });
    
    if (result.success) {
        await bot.sendMessage(chatId, `✅ *User ${password} unlocked successfully!*`, { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleRestartAll(chatId) {
    await bot.sendMessage(chatId, '🔄 *Restarting all services...*', { parse_mode: 'Markdown' });
    const result = await apiCall('POST', '/api/service/restart', {});
    
    if (result.success) {
        await bot.sendMessage(chatId, '✅ *All services restarted successfully!*', { parse_mode: 'Markdown' });
    } else {
        await bot.sendMessage(chatId, `❌ *Failed*: ${result.message}`, { parse_mode: 'Markdown' });
    }
}

async function handleServiceStatus(chatId) {
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
        case 'service_status':
            await handleServiceStatus(chatId);
            break;
        case 'backup_create':
            await handleCreateBackup(chatId);
            break;
        case 'backup_list':
            await handleListBackups(chatId);
            break;
        default:
            await bot.answerCallbackQuery(query.id, { text: 'Coming soon!' });
    }
    
    await bot.answerCallbackQuery(query.id);
}

// ==================== MAIN ====================
async function main() {
    if (!initBot()) {
        console.error('Failed to initialize bot. Run config-bot first.');
        process.exit(1);
    }
    
    bot.onText(/\/start/, (msg) => handleStart(msg.chat.id));
    bot.on('callback_query', handleCallback);
    
    console.log('🤖 ZiVPN Bot is running...');
    console.log('📡 Waiting for commands...');
}

main().catch(console.error);