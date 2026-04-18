const express = require('express');
const fs = require('fs');
const { exec } = require('child_process');
const crypto = require('crypto');
const path = require('path');

const app = express();
const PORT = 8585;
const CONFIG_FILE = '/etc/zivpn/config.json';
const USER_DB = '/etc/zivpn/users.json';
const DOMAIN_FILE = '/etc/zivpn/domain';
const API_KEY_FILE = '/etc/zivpn/apikey';
const GITHUB_TOKEN_FILE = '/etc/zivpn/github_token';
const BACKUP_DIR = '/root/zivpn_backups';

// ==================== GENERATE API KEY OTOMATIS ====================
function generateApiKey() {
    const randomPart = crypto.randomBytes(16).toString('hex');
    return `PX-${randomPart}`;
}

// Cek dan buat API Key jika belum ada
let AUTH_TOKEN = 'AutoFtBot-agskjgdvsbdreiWG1234512SDKrqw';

if (fs.existsSync(API_KEY_FILE)) {
    AUTH_TOKEN = fs.readFileSync(API_KEY_FILE, 'utf8').trim();
    console.log(`📖 API Key loaded from file: ${AUTH_TOKEN.substring(0, 15)}...`);
} else {
    AUTH_TOKEN = generateApiKey();
    fs.writeFileSync(API_KEY_FILE, AUTH_TOKEN);
    console.log(`🔑 New API Key generated: ${AUTH_TOKEN}`);
    console.log(`💾 API Key saved to: ${API_KEY_FILE}`);
}

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Logger middleware
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
    next();
});

// ==================== AUTH MIDDLEWARE ====================
function authMiddleware(req, res, next) {
    const token = req.headers['x-api-key'];
    if (token !== AUTH_TOKEN) {
        return jsonResponse(res, 401, false, 'Unauthorized', null);
    }
    next();
}

// ==================== HELPER FUNCTIONS ====================
function jsonResponse(res, status, success, message, data) {
    res.status(status).json({
        success: success,
        message: message,
        data: data || null
    });
}

function loadConfig() {
    try {
        const data = fs.readFileSync(CONFIG_FILE, 'utf8');
        return JSON.parse(data);
    } catch (err) {
        return null;
    }
}

function saveConfig(config) {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2), 'utf8');
}

function loadUsers() {
    try {
        const data = fs.readFileSync(USER_DB, 'utf8');
        return JSON.parse(data);
    } catch (err) {
        return [];
    }
}

function saveUsers(users) {
    fs.writeFileSync(USER_DB, JSON.stringify(users, null, 2), 'utf8');
}

function restartService(service = 'zivpn') {
    return new Promise((resolve, reject) => {
        exec(`systemctl restart ${service}.service`, (error, stdout, stderr) => {
            if (error) {
                reject(error);
            } else {
                resolve(stdout);
            }
        });
    });
}

function runScript(scriptName, input = null) {
    return new Promise((resolve, reject) => {
        const scriptPath = `/usr/local/bin/${scriptName}`;
        
        if (!fs.existsSync(scriptPath)) {
            reject(new Error(`Script ${scriptName} not found`));
            return;
        }
        
        const child = exec(scriptPath, { timeout: 60000 }, (error, stdout, stderr) => {
            if (error) {
                reject({ error: error.message, stderr, stdout });
            } else {
                resolve({ stdout, stderr });
            }
        });
        
        if (input) {
            child.stdin.write(input);
            child.stdin.end();
        }
    });
}

function lockUser(username) {
    const config = loadConfig();
    if (config && config.auth && config.auth.config) {
        const newConfigAuth = config.auth.config.filter(p => p !== username);
        if (newConfigAuth.length !== config.auth.config.length) {
            config.auth.config = newConfigAuth;
            saveConfig(config);
            restartService().catch(console.error);
        }
    }

    const users = loadUsers();
    const newUsers = users.map(u => {
        if (u.password === username) {
            u.status = 'locked';
        }
        return u;
    });
    saveUsers(newUsers);
}

function enableUser(username) {
    const config = loadConfig();
    if (config && config.auth && config.auth.config) {
        if (!config.auth.config.includes(username)) {
            config.auth.config.push(username);
            saveConfig(config);
            restartService().catch(console.error);
        }
    }
}

// ==================== MONITOR USER LIMITS ====================
function monitorUserLimits() {
    setInterval(() => {
        const users = loadUsers();
        const userLimits = {};
        users.forEach(u => {
            if (u.ip_limit > 0) {
                userLimits[u.password] = u.ip_limit;
            }
        });

        if (Object.keys(userLimits).length === 0) return;

        exec('journalctl -u zivpn.service --since "1 minute ago" --no-pager', (error, stdout) => {
            if (error) return;
            
            const activeIps = {};
            const lines = stdout.split('\n');
            
            for (const line of lines) {
                if (line.includes('user:') && line.includes('source:')) {
                    const userMatch = line.match(/user:\s*([^,\s]+)/);
                    const ipMatch = line.match(/source:\s*([^,\s]+)/);
                    
                    if (userMatch && ipMatch && userLimits[userMatch[1]]) {
                        const username = userMatch[1];
                        const ip = ipMatch[1];
                        if (!activeIps[username]) activeIps[username] = new Set();
                        activeIps[username].add(ip);
                    }
                }
            }
            
            for (const [username, ips] of Object.entries(activeIps)) {
                const limit = userLimits[username];
                if (ips.size > limit) {
                    console.log(`User ${username} exceeded IP limit. Locking account.`);
                    lockUser(username);
                }
            }
        });
    }, 60000);
}

// ==================== ROOT ENDPOINT ====================
app.get('/', (req, res) => {
    res.json({
        name: 'ZiVPN API',
        version: '2.0.0',
        status: 'running',
        port: PORT,
        api_key: AUTH_TOKEN.substring(0, 15) + '...',
        endpoints: {
            system: {
                'GET /': 'API Information',
                'GET /api/health': 'Health check',
                'GET /api/info': 'System info',
                'GET /api/config': 'Get configuration'
            },
            users: {
                'GET /api/users': 'List all users',
                'GET /api/user/:password': 'Get user details',
                'POST /api/user/create': 'Create user',
                'POST /api/user/create-random': 'Create random user',
                'POST /api/user/delete': 'Delete user',
                'POST /api/user/renew': 'Renew user',
                'POST /api/user/trial': 'Create trial user (30 min)',
                'POST /api/user/lock': 'Lock user',
                'POST /api/user/unlock': 'Unlock user'
            },
            bot: {
                'POST /api/bot/install': 'Install Telegram bot',
                'POST /api/bot/install-pakasir': 'Install Pakasir bot',
                'GET /api/bot/status': 'Get bot status',
                'DELETE /api/bot/uninstall': 'Uninstall bot'
            },
            service: {
                'POST /api/service/restart': 'Restart all services',
                'POST /api/service/restart/zivpn': 'Restart ZiVPN core',
                'POST /api/service/restart/api': 'Restart API',
                'POST /api/service/restart/bot': 'Restart bot',
                'GET /api/service/status': 'Get all services status'
            },
            backup: {
                'POST /api/backup/create': 'Create backup',
                'POST /api/backup/restore': 'Restore backup',
                'GET /api/backup/list': 'List backups',
                'DELETE /api/backup/:id': 'Delete backup'
            },
            github: {
                'POST /api/github/token': 'Set GitHub token',
                'GET /api/github/token': 'Check GitHub token',
                'DELETE /api/github/token': 'Delete GitHub token'
            },
            menu: {
                'POST /api/menu/update': 'Update menu from GitHub'
            },
            api: {
                'GET /api/apikey': 'Get API key info',
                'POST /api/apikey/regenerate': 'Regenerate API key'
            }
        }
    });
});

// ==================== SYSTEM ENDPOINTS ====================

// Health check (tanpa auth)
app.get('/api/health', (req, res) => {
    jsonResponse(res, 200, true, 'API is healthy', {
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage()
    });
});

// System info
app.get('/api/info', authMiddleware, (req, res) => {
    exec('curl -s ifconfig.me', (err, ipPub) => {
        exec('hostname -I', (err2, ipPriv) => {
            let domain = 'Tidak diatur';
            if (fs.existsSync(DOMAIN_FILE)) {
                domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
            }
            
            const info = {
                domain: domain,
                public_ip: ipPub ? ipPub.trim() : '',
                private_ip: ipPriv ? ipPriv.trim().split(' ')[0] : '',
                port: '5667',
                service: 'zivpn',
                api_port: PORT
            };
            
            jsonResponse(res, 200, true, 'System Info', info);
        });
    });
});

// Get configuration
app.get('/api/config', authMiddleware, (req, res) => {
    const config = {};
    
    if (fs.existsSync(DOMAIN_FILE)) {
        config.domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
    }
    
    const serverConfig = loadConfig();
    if (serverConfig) {
        config.server = {
            listen: serverConfig.listen,
            obfs: serverConfig.obfs
        };
    }
    
    const users = loadUsers();
    config.total_users = users.length;
    config.active_users = users.filter(u => u.status === 'active').length;
    config.github_token_configured = fs.existsSync(GITHUB_TOKEN_FILE);
    
    jsonResponse(res, 200, true, 'Configuration', config);
});

// ==================== USER MANAGEMENT ====================

// List all users
app.get('/api/users', authMiddleware, (req, res) => {
    const users = loadUsers();
    const today = new Date().toISOString().split('T')[0];
    
    const userList = users.map(u => {
        let status = 'Active';
        if (u.status === 'locked') {
            status = 'Locked';
        } else if (u.expired < today) {
            status = 'Expired';
        }
        
        return {
            password: u.password,
            expired: u.expired,
            status: status,
            ip_limit: u.ip_limit,
            is_trial: u.is_trial || false,
            created_at: u.created_at
        };
    });
    
    jsonResponse(res, 200, true, 'Daftar user', userList);
});

// Get user by password
app.get('/api/user/:password', authMiddleware, (req, res) => {
    const { password } = req.params;
    const users = loadUsers();
    const user = users.find(u => u.password === password);
    
    if (!user) {
        return jsonResponse(res, 404, false, 'User tidak ditemukan', null);
    }
    
    const today = new Date().toISOString().split('T')[0];
    const isExpired = user.expired < today;
    
    jsonResponse(res, 200, true, 'User details', {
        ...user,
        status_display: isExpired ? 'Expired' : (user.status === 'locked' ? 'Locked' : 'Active')
    });
});

// Create user
app.post('/api/user/create', authMiddleware, (req, res) => {
    const { password, days, ip_limit } = req.body;
    
    if (!password || !days || days <= 0) {
        return jsonResponse(res, 400, false, 'Password dan days harus valid', null);
    }
    
    const config = loadConfig();
    if (config && config.auth && config.auth.config.includes(password)) {
        return jsonResponse(res, 409, false, 'User sudah ada', null);
    }
    
    config.auth.config.push(password);
    saveConfig(config);
    
    const expDate = new Date();
    expDate.setDate(expDate.getDate() + parseInt(days));
    const expDateStr = expDate.toISOString().split('T')[0];
    const limit = ip_limit || 0;
    
    const users = loadUsers();
    users.push({
        password: password,
        expired: expDateStr,
        ip_limit: limit,
        status: 'active',
        is_trial: false,
        created_at: new Date().toISOString()
    });
    saveUsers(users);
    
    restartService().catch(console.error);
    
    let domain = 'Tidak diatur';
    if (fs.existsSync(DOMAIN_FILE)) {
        domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
    }
    
    jsonResponse(res, 200, true, 'User berhasil dibuat', {
        password: password,
        expired: expDateStr,
        ip_limit: String(limit),
        domain: domain
    });
});

// Create random user
app.post('/api/user/create-random', authMiddleware, (req, res) => {
    const { days, ip_limit } = req.body;
    
    if (!days || days <= 0) {
        return jsonResponse(res, 400, false, 'Days harus valid', null);
    }
    
    const randomPassword = crypto.randomBytes(8).toString('hex');
    const config = loadConfig();
    
    config.auth.config.push(randomPassword);
    saveConfig(config);
    
    const expDate = new Date();
    expDate.setDate(expDate.getDate() + parseInt(days));
    const expDateStr = expDate.toISOString().split('T')[0];
    const limit = ip_limit || 0;
    
    const users = loadUsers();
    users.push({
        password: randomPassword,
        expired: expDateStr,
        ip_limit: limit,
        status: 'active',
        is_trial: false,
        created_at: new Date().toISOString()
    });
    saveUsers(users);
    
    restartService().catch(console.error);
    
    let domain = 'Tidak diatur';
    if (fs.existsSync(DOMAIN_FILE)) {
        domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
    }
    
    jsonResponse(res, 200, true, 'Random user berhasil dibuat', {
        password: randomPassword,
        expired: expDateStr,
        ip_limit: String(limit),
        domain: domain
    });
});

// Delete user
app.post('/api/user/delete', authMiddleware, (req, res) => {
    const { password } = req.body;
    
    if (!password) {
        return jsonResponse(res, 400, false, 'Password diperlukan', null);
    }
    
    const config = loadConfig();
    const newConfigAuth = config.auth.config.filter(p => p !== password);
    
    if (newConfigAuth.length === config.auth.config.length) {
        return jsonResponse(res, 404, false, 'User tidak ditemukan', null);
    }
    
    config.auth.config = newConfigAuth;
    saveConfig(config);
    
    const users = loadUsers();
    const newUsers = users.filter(u => u.password !== password);
    saveUsers(newUsers);
    
    restartService().catch(console.error);
    
    jsonResponse(res, 200, true, 'User berhasil dihapus', null);
});

// Renew user
app.post('/api/user/renew', authMiddleware, (req, res) => {
    const { password, days } = req.body;
    
    if (!password || !days || days <= 0) {
        return jsonResponse(res, 400, false, 'Password dan days harus valid', null);
    }
    
    const users = loadUsers();
    let found = false;
    let newExpDate = '';
    
    const newUsers = users.map(u => {
        if (u.password === password) {
            found = true;
            let currentExp = new Date(u.expired);
            if (currentExp < new Date()) {
                currentExp = new Date();
            }
            currentExp.setDate(currentExp.getDate() + parseInt(days));
            newExpDate = currentExp.toISOString().split('T')[0];
            u.expired = newExpDate;
            if (u.status === 'locked') {
                u.status = 'active';
                enableUser(password);
            }
        }
        return u;
    });
    
    if (!found) {
        return jsonResponse(res, 404, false, 'User tidak ditemukan', null);
    }
    
    saveUsers(newUsers);
    restartService().catch(console.error);
    
    jsonResponse(res, 200, true, 'User berhasil diperpanjang', {
        password: password,
        expired: newExpDate
    });
});

// Trial user (30 minutes)
app.post('/api/user/trial', authMiddleware, (req, res) => {
    const trialPassword = crypto.randomBytes(8).toString('hex');
    const config = loadConfig();
    
    config.auth.config.push(trialPassword);
    saveConfig(config);
    
    const trialDate = new Date();
    const expDateStr = trialDate.toISOString().split('T')[0];
    const trialEnd = new Date(Date.now() + 30 * 60000).toISOString();
    
    const users = loadUsers();
    users.push({
        password: trialPassword,
        expired: expDateStr,
        expired_time: trialEnd,
        ip_limit: 1,
        status: 'active',
        is_trial: true,
        created_at: new Date().toISOString()
    });
    saveUsers(users);
    
    restartService().catch(console.error);
    
    // Auto delete after 30 minutes
    setTimeout(() => {
        const currentConfig = loadConfig();
        if (currentConfig && currentConfig.auth.config.includes(trialPassword)) {
            const newAuth = currentConfig.auth.config.filter(p => p !== trialPassword);
            currentConfig.auth.config = newAuth;
            saveConfig(currentConfig);
            
            const currentUsers = loadUsers();
            const filteredUsers = currentUsers.filter(u => u.password !== trialPassword);
            saveUsers(filteredUsers);
            restartService().catch(console.error);
        }
    }, 30 * 60000);
    
    let domain = 'Tidak diatur';
    if (fs.existsSync(DOMAIN_FILE)) {
        domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
    }
    
    jsonResponse(res, 200, true, 'Trial user berhasil dibuat (30 menit)', {
        password: trialPassword,
        expired: trialEnd,
        ip_limit: '1',
        domain: domain
    });
});

// Lock user
app.post('/api/user/lock', authMiddleware, (req, res) => {
    const { password } = req.body;
    
    if (!password) {
        return jsonResponse(res, 400, false, 'Password diperlukan', null);
    }
    
    lockUser(password);
    jsonResponse(res, 200, true, `User ${password} berhasil dikunci`, null);
});

// Unlock user
app.post('/api/user/unlock', authMiddleware, (req, res) => {
    const { password } = req.body;
    
    if (!password) {
        return jsonResponse(res, 400, false, 'Password diperlukan', null);
    }
    
    enableUser(password);
    
    const users = loadUsers();
    const newUsers = users.map(u => {
        if (u.password === password) {
            u.status = 'active';
        }
        return u;
    });
    saveUsers(newUsers);
    
    jsonResponse(res, 200, true, `User ${password} berhasil dibuka`, null);
});

// ==================== BOT MANAGEMENT ====================

// Install bot
app.post('/api/bot/install', authMiddleware, (req, res) => {
    const { bot_token, admin_id, bot_mode } = req.body;
    
    if (!bot_token || !admin_id) {
        return jsonResponse(res, 400, false, 'bot_token dan admin_id diperlukan', null);
    }
    
    const input = `${bot_token}\n${admin_id}\n${bot_mode || 'private'}\n`;
    
    runScript('install-bot', input)
        .then(result => {
            jsonResponse(res, 200, true, 'Bot berhasil diinstall', {
                bot_token: bot_token,
                admin_id: admin_id,
                bot_mode: bot_mode || 'private'
            });
        })
        .catch(err => {
            jsonResponse(res, 500, false, 'Gagal install bot: ' + (err.error || err.message), null);
        });
});

// Install Pakasir bot
app.post('/api/bot/install-pakasir', authMiddleware, (req, res) => {
    const { bot_token, admin_id, pakasir_slug, pakasir_key, daily_price, ip_limit } = req.body;
    
    if (!bot_token || !admin_id || !pakasir_slug || !pakasir_key || !daily_price) {
        return jsonResponse(res, 400, false, 'Semua field pakasir diperlukan', null);
    }
    
    const input = `${bot_token}\n${admin_id}\n${pakasir_slug}\n${pakasir_key}\n${daily_price}\n${ip_limit || 1}\n`;
    
    runScript('install-pakasir', input)
        .then(result => {
            jsonResponse(res, 200, true, 'Pakasir bot berhasil diinstall', {
                bot_token: bot_token,
                admin_id: admin_id,
                pakasir_slug: pakasir_slug,
                daily_price: daily_price,
                ip_limit: ip_limit || 1
            });
        })
        .catch(err => {
            jsonResponse(res, 500, false, 'Gagal install pakasir bot: ' + (err.error || err.message), null);
        });
});

// Get bot status
app.get('/api/bot/status', authMiddleware, (req, res) => {
    exec('systemctl is-active zivpn-bot', (error, stdout) => {
        const isActive = stdout.trim() === 'active';
        
        let botConfig = null;
        if (fs.existsSync('/etc/zivpn/bot-config.json')) {
            try {
                botConfig = JSON.parse(fs.readFileSync('/etc/zivpn/bot-config.json', 'utf8'));
                delete botConfig.bot_token;
            } catch(e) {}
        }
        
        jsonResponse(res, 200, true, 'Bot status', {
            running: isActive,
            config: botConfig
        });
    });
});

// Uninstall bot
app.delete('/api/bot/uninstall', authMiddleware, (req, res) => {
    exec('systemctl stop zivpn-bot; systemctl disable zivpn-bot; rm -f /etc/systemd/system/zivpn-bot.service; rm -f /etc/zivpn/bot-config.json', (error) => {
        jsonResponse(res, 200, true, 'Bot berhasil diuninstall', null);
    });
});

// ==================== SERVICE MANAGEMENT ====================

// Restart all services
app.post('/api/service/restart', authMiddleware, (req, res) => {
    Promise.all([
        restartService('zivpn'),
        restartService('zivpn-api-js'),
        restartService('zivpn-bot').catch(() => {})
    ]).then(() => {
        jsonResponse(res, 200, true, 'Semua service berhasil direstart', null);
    }).catch(err => {
        jsonResponse(res, 500, false, 'Gagal merestart service: ' + err.message, null);
    });
});

// Restart specific services
app.post('/api/service/restart/zivpn', authMiddleware, (req, res) => {
    restartService('zivpn')
        .then(() => jsonResponse(res, 200, true, 'ZiVPN core berhasil direstart', null))
        .catch(err => jsonResponse(res, 500, false, 'Gagal: ' + err.message, null));
});

app.post('/api/service/restart/api', authMiddleware, (req, res) => {
    restartService('zivpn-api-js')
        .then(() => jsonResponse(res, 200, true, 'API service berhasil direstart', null))
        .catch(err => jsonResponse(res, 500, false, 'Gagal: ' + err.message, null));
});

app.post('/api/service/restart/bot', authMiddleware, (req, res) => {
    restartService('zivpn-bot')
        .then(() => jsonResponse(res, 200, true, 'Bot service berhasil direstart', null))
        .catch(err => jsonResponse(res, 500, false, 'Gagal: ' + err.message, null));
});

// Get all services status
app.get('/api/service/status', authMiddleware, (req, res) => {
    const services = ['zivpn', 'zivpn-api-js', 'zivpn-bot'];
    const results = {};
    let completed = 0;
    
    services.forEach(service => {
        exec(`systemctl is-active ${service}`, (error, stdout) => {
            results[service] = {
                status: stdout.trim(),
                active: stdout.trim() === 'active'
            };
            completed++;
            
            if (completed === services.length) {
                jsonResponse(res, 200, true, 'Service status', results);
            }
        });
    });
});

// ==================== BACKUP MANAGEMENT ====================

// Create backup
app.post('/api/backup/create', authMiddleware, (req, res) => {
    runScript('backup')
        .then(result => {
            const idMatch = result.stdout.match(/Backup ID\s*:\s*([a-zA-Z0-9]+)/i);
            const backupId = idMatch ? idMatch[1] : 'unknown';
            jsonResponse(res, 200, true, 'Backup berhasil dibuat', { backup_id: backupId });
        })
        .catch(err => {
            jsonResponse(res, 500, false, 'Gagal membuat backup: ' + (err.error || err.message), null);
        });
});

// Restore backup
app.post('/api/backup/restore', authMiddleware, (req, res) => {
    const { backup_id } = req.body;
    
    if (!backup_id) {
        return jsonResponse(res, 400, false, 'backup_id diperlukan', null);
    }
    
    const input = `${backup_id}\n`;
    
    runScript('restore', input)
        .then(result => {
            jsonResponse(res, 200, true, `Backup ${backup_id} berhasil direstore`, null);
        })
        .catch(err => {
            jsonResponse(res, 500, false, 'Gagal restore backup: ' + (err.error || err.message), null);
        });
});

// List backups
app.get('/api/backup/list', authMiddleware, (req, res) => {
    if (!fs.existsSync(BACKUP_DIR)) {
        return jsonResponse(res, 200, true, 'Daftar backup', []);
    }
    
    fs.readdir(BACKUP_DIR, (err, files) => {
        if (err) {
            return jsonResponse(res, 500, false, 'Gagal membaca direktori backup', null);
        }
        
        const backups = files
            .filter(f => f.endsWith('.zip'))
            .map(f => {
                const stats = fs.statSync(`${BACKUP_DIR}/${f}`);
                return {
                    id: f.replace('.zip', ''),
                    name: f,
                    size: stats.size,
                    created: stats.mtime
                };
            });
        
        jsonResponse(res, 200, true, 'Daftar backup', backups);
    });
});

// Delete backup
app.delete('/api/backup/:id', authMiddleware, (req, res) => {
    const { id } = req.params;
    const backupFile = `${BACKUP_DIR}/${id}.zip`;
    
    if (!fs.existsSync(backupFile)) {
        return jsonResponse(res, 404, false, 'Backup tidak ditemukan', null);
    }
    
    fs.unlinkSync(backupFile);
    jsonResponse(res, 200, true, `Backup ${id} berhasil dihapus`, null);
});

// ==================== GITHUB TOKEN MANAGEMENT ====================

// Set GitHub token
app.post('/api/github/token', authMiddleware, (req, res) => {
    const { token } = req.body;
    
    if (!token) {
        return jsonResponse(res, 400, false, 'Token diperlukan', null);
    }
    
    const input = `${token}\n`;
    
    runScript('github-token', input)
        .then(result => {
            jsonResponse(res, 200, true, 'GitHub token berhasil disimpan', null);
        })
        .catch(err => {
            jsonResponse(res, 500, false, 'Gagal menyimpan token: ' + (err.error || err.message), null);
        });
});

// Get GitHub token status
app.get('/api/github/token', authMiddleware, (req, res) => {
    const tokenExists = fs.existsSync(GITHUB_TOKEN_FILE);
    let tokenPreview = null;
    
    if (tokenExists) {
        const token = fs.readFileSync(GITHUB_TOKEN_FILE, 'utf8').trim();
        tokenPreview = token.substring(0, 10) + '...' + token.substring(token.length - 10);
    }
    
    jsonResponse(res, 200, true, 'GitHub token status', {
        configured: tokenExists,
        token: tokenPreview
    });
});

// Delete GitHub token
app.delete('/api/github/token', authMiddleware, (req, res) => {
    runScript('del-token')
        .then(result => {
            jsonResponse(res, 200, true, 'GitHub token berhasil dihapus', null);
        })
        .catch(err => {
            jsonResponse(res, 500, false, 'Gagal menghapus token: ' + (err.error || err.message), null);
        });
});

// ==================== MENU UPDATE ====================

// Update menu
app.post('/api/menu/update', authMiddleware, (req, res) => {
    runScript('update-zivpn')
        .then(result => {
            jsonResponse(res, 200, true, 'Menu berhasil diupdate', null);
        })
        .catch(err => {
            jsonResponse(res, 500, false, 'Gagal update menu: ' + (err.error || err.message), null);
        });
});

// ==================== GET DOMAIN ====================
app.get('/api/domain', (req, res) => {
    let domain = 'Tidak diatur';
    if (fs.existsSync(DOMAIN_FILE)) {
        domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
    }
    res.json({ success: true, data: { domain: domain } });
});

// ==================== GET PUBLIC IP ====================
app.get('/api/ip', (req, res) => {
    exec('curl -s ifconfig.me', (err, ipPub) => {
        exec('hostname -I', (err2, ipPriv) => {
            res.json({
                success: true,
                data: {
                    public_ip: ipPub ? ipPub.trim() : 'Unknown',
                    private_ip: ipPriv ? ipPriv.trim().split(' ')[0] : 'Unknown'
                }
            });
        });
    });
});

// ==================== GET SYSTEM INFO (LENGKAP) ====================
app.get('/api/system/info', (req, res) => {
    exec('curl -s ifconfig.me', (err, ipPub) => {
        exec('hostname -I', (err2, ipPriv) => {
            let domain = 'Tidak diatur';
            if (fs.existsSync(DOMAIN_FILE)) {
                domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
            }
            
            let port = '5667';
            if (fs.existsSync(CONFIG_FILE)) {
                try {
                    const config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
                    if (config.listen) {
                        port = config.listen.replace(':', '');
                    }
                } catch(e) {}
            }
            
            res.json({
                success: true,
                data: {
                    domain: domain,
                    public_ip: ipPub ? ipPub.trim() : 'Unknown',
                    private_ip: ipPriv ? ipPriv.trim().split(' ')[0] : 'Unknown',
                    port: port,
                    api_port: 8585,
                    server_time: new Date().toISOString()
                }
            });
        });
    });
});

// ==================== GET USER STATISTICS ====================
app.get('/api/users/stats', (req, res) => {
    const users = loadUsers();
    const today = new Date().toISOString().split('T')[0];
    
    let active = 0;
    let expired = 0;
    let locked = 0;
    
    users.forEach(u => {
        if (u.status === 'locked') {
            locked++;
        } else if (u.expired < today) {
            expired++;
        } else {
            active++;
        }
    });
    
    res.json({
        success: true,
        data: {
            total: users.length,
            active: active,
            expired: expired,
            locked: locked
        }
    });
});

// ==================== API KEY MANAGEMENT ====================

// Get API key info (tanpa auth untuk cek)
app.get('/api/apikey', (req, res) => {
    jsonResponse(res, 200, true, 'API Key Info', {
        configured: fs.existsSync(API_KEY_FILE),
        key_preview: AUTH_TOKEN ? AUTH_TOKEN.substring(0, 15) + '...' : 'not set',
        format: 'PX-{random 32 hex}'
    });
});

// Regenerate API key (dengan auth)
app.post('/api/apikey/regenerate', authMiddleware, (req, res) => {
    const oldKey = AUTH_TOKEN;
    const newKey = generateApiKey();
    
    fs.writeFileSync(API_KEY_FILE, newKey);
    AUTH_TOKEN = newKey;
    
    jsonResponse(res, 200, true, 'API Key berhasil digenerate ulang', {
        old_key: oldKey.substring(0, 15) + '...',
        new_key: newKey,
        note: 'Simpan API Key baru ini'
    });
});

// ==================== START SERVER & MONITOR ====================

// Mulai monitoring user limits
monitorUserLimits();

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log('\x1b[36m═══════════════════════════════════════════════════════════\x1b[0m');
    console.log('\x1b[32m✅ ZiVPN API Server Started Successfully!\x1b[0m');
    console.log('\x1b[36m═══════════════════════════════════════════════════════════\x1b[0m');
    console.log(`\x1b[33m📍 URL:\x1b[0m http://0.0.0.0:${PORT}`);
    console.log(`\x1b[33m🔑 API Key:\x1b[0m ${AUTH_TOKEN}`);
    console.log(`\x1b[33m💾 API Key File:\x1b[0m ${API_KEY_FILE}`);
    console.log(`\x1b[33m📁 Config Dir:\x1b[0m /etc/zivpn`);
    console.log(`\x1b[33m📝 Test:\x1b[0m curl http://localhost:${PORT}/api/info -H "x-api-key: ${AUTH_TOKEN}"`);
    console.log('\x1b[36m═══════════════════════════════════════════════════════════\x1b[0m');
});

// Error handling
process.on('uncaughtException', (err) => {
    console.error('\x1b[31m❌ Uncaught Exception:\x1b[0m', err);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('\x1b[31m❌ Unhandled Rejection:\x1b[0m', reason);
});

module.exports = app;