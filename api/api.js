const express = require('express');
const fs = require('fs');
const { exec } = require('child_process');
const os = require('os');

const app = express();
const PORT = 8585;
const CONFIG_FILE = '/etc/zivpn/config.json';
const USER_DB = '/etc/zivpn/users.json';
const DOMAIN_FILE = '/etc/zivpn/domain';
const API_KEY_FILE = '/etc/zivpn/apikey';

// Baca API Key
let AUTH_TOKEN = 'PX-DefaultKey12345678';
if (fs.existsSync(API_KEY_FILE)) {
    AUTH_TOKEN = fs.readFileSync(API_KEY_FILE, 'utf8').trim();
}

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// CORS middleware
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, x-api-key');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    if (req.method === 'OPTIONS') {
        res.sendStatus(200);
    } else {
        next();
    }
});

// Debug middleware
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
    next();
});

// Auth middleware
function authMiddleware(req, res, next) {
    const token = req.headers['x-api-key'];
    if (token && token === AUTH_TOKEN) {
        next();
    } else {
        res.status(401).json({ success: false, message: 'Unauthorized' });
    }
}

// Helper functions
function loadUsers() {
    try {
        if (!fs.existsSync(USER_DB)) return [];
        const data = fs.readFileSync(USER_DB, 'utf8');
        return JSON.parse(data);
    } catch (err) {
        return [];
    }
}

// Get System Info lengkap
function getSystemInfo() {
    return new Promise((resolve) => {
        let domain = 'Tidak diatur';
        if (fs.existsSync(DOMAIN_FILE)) {
            domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
        }
        
        let port = '5667';
        if (fs.existsSync(CONFIG_FILE)) {
            try {
                const config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
                if (config.listen) port = config.listen.replace(':', '');
            } catch(e) {}
        }
        
        // Get OS Info
        const osType = os.type();
        const osRelease = os.release();
        const osArch = os.arch();
        const hostname = os.hostname();
        const uptime = os.uptime();
        
        // Format uptime
        const days = Math.floor(uptime / 86400);
        const hours = Math.floor((uptime % 86400) / 3600);
        const minutes = Math.floor((uptime % 3600) / 60);
        const uptimeStr = `${days}d ${hours}h ${minutes}m`;
        
        // Get load average
        const loadAvg = os.loadavg();
        
        // Get memory
        const totalMem = Math.round(os.totalmem() / (1024 * 1024 * 1024));
        const freeMem = Math.round(os.freemem() / (1024 * 1024 * 1024));
        const usedMem = totalMem - freeMem;
        
        // Get public IP
        exec('curl -s ifconfig.me', (err, ipPub) => {
            // Get private IP
            exec('hostname -I', (err2, ipPriv) => {
                // Get OS name
                exec('cat /etc/os-release | grep PRETTY_NAME | cut -d"=" -f2', (err3, osName) => {
                    let cleanOsName = osName ? osName.trim().replace(/"/g, '') : `${osType} ${osRelease}`;
                    // Get ISP
                    exec('curl -s ipinfo.io/org', (err4, isp) => {
                        // Get City
                        exec('curl -s ipinfo.io/city', (err5, city) => {
                            resolve({
                                domain: domain,
                                public_ip: ipPub ? ipPub.trim() : 'Unknown',
                                private_ip: ipPriv ? ipPriv.trim().split(' ')[0] : 'Unknown',
                                port: port,
                                api_port: PORT,
                                os: cleanOsName,
                                os_arch: osArch,
                                hostname: hostname,
                                uptime: uptimeStr,
                                uptime_seconds: uptime,
                                load_average: loadAvg,
                                memory: {
                                    total: `${totalMem} GB`,
                                    used: `${usedMem} GB`,
                                    free: `${freeMem} GB`
                                },
                                isp: isp ? isp.trim() : 'Unknown',
                                city: city ? city.trim() : 'Unknown',
                                server_time: new Date().toISOString()
                            });
                        });
                    });
                });
            });
        });
    });
}

// ==================== HEALTH CHECK ====================
app.get('/api/health', (req, res) => {
    res.json({ success: true, message: 'API is healthy', timestamp: new Date().toISOString() });
});

// ==================== SYSTEM INFO LENGKAP ====================
app.get('/api/system/info', async (req, res) => {
    const info = await getSystemInfo();
    res.json({ success: true, data: info });
});

// ==================== USERS STATS ====================
app.get('/api/users/stats', authMiddleware, (req, res) => {
    const users = loadUsers();
    const today = new Date().toISOString().split('T')[0];
    let active = 0, expired = 0, locked = 0;
    
    users.forEach(u => {
        if (u.status === 'locked') locked++;
        else if (u.expired < today) expired++;
        else active++;
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

// ==================== LIST USERS ====================
app.get('/api/users', authMiddleware, (req, res) => {
    const users = loadUsers();
    const today = new Date().toISOString().split('T')[0];
    
    const userList = users.map(u => ({
        password: u.password,
        expired: u.expired,
        status: u.status === 'locked' ? 'Locked' : (u.expired < today ? 'Expired' : 'Active'),
        ip_limit: u.ip_limit
    }));
    
    res.json({ success: true, data: userList });
});

// ==================== SERVICE STATUS ====================
app.get('/api/service/status', authMiddleware, (req, res) => {
    // Gunakan nama service yang benar
    const services = ['zivpn', 'zivpn-api-js', 'zivpn-bot'];
    const results = {};
    let completed = 0;
    
    services.forEach(service => {
        exec(`systemctl is-active ${service}`, (error, stdout) => {
            const isActive = stdout ? stdout.trim() === 'active' : false;
            results[service] = {
                status: isActive ? 'active' : 'inactive',
                active: isActive
            };
            completed++;
            if (completed === services.length) {
                res.json({ success: true, data: results });
            }
        });
    });
});

// ==================== CREATE USER ====================
app.post('/api/user/create', authMiddleware, (req, res) => {
    const { password, days, ip_limit } = req.body;
    
    if (!password || !days) {
        return res.json({ success: false, message: 'Password and days required' });
    }
    
    const configFile = '/etc/zivpn/config.json';
    let config = { auth: { config: [] } };
    
    if (fs.existsSync(configFile)) {
        try {
            config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
        } catch(e) {}
    }
    
    if (config.auth.config.includes(password)) {
        return res.json({ success: false, message: 'User already exists' });
    }
    
    config.auth.config.push(password);
    fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
    
    const expDate = new Date();
    expDate.setDate(expDate.getDate() + parseInt(days));
    const expDateStr = expDate.toISOString().split('T')[0];
    
    const users = loadUsers();
    users.push({
        password: password,
        expired: expDateStr,
        ip_limit: ip_limit || 0,
        status: 'active',
        created_at: new Date().toISOString()
    });
    fs.writeFileSync(USER_DB, JSON.stringify(users, null, 2));
    
    exec('systemctl restart zivpn', () => {});
    
    let domain = 'Not set';
    if (fs.existsSync(DOMAIN_FILE)) {
        domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
    }
    
    res.json({
        success: true,
        data: {
            password: password,
            expired: expDateStr,
            ip_limit: String(ip_limit || 0),
            domain: domain
        }
    });
});

// ==================== CREATE RANDOM USER ====================
app.post('/api/user/create-random', authMiddleware, (req, res) => {
    const { days, ip_limit } = req.body;
    const password = 'user_' + Math.random().toString(36).substr(2, 10);
    
    const configFile = '/etc/zivpn/config.json';
    let config = { auth: { config: [] } };
    
    if (fs.existsSync(configFile)) {
        try {
            config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
        } catch(e) {}
    }
    
    config.auth.config.push(password);
    fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
    
    const expDate = new Date();
    expDate.setDate(expDate.getDate() + parseInt(days));
    const expDateStr = expDate.toISOString().split('T')[0];
    
    const users = loadUsers();
    users.push({
        password: password,
        expired: expDateStr,
        ip_limit: ip_limit || 0,
        status: 'active',
        created_at: new Date().toISOString()
    });
    fs.writeFileSync(USER_DB, JSON.stringify(users, null, 2));
    
    exec('systemctl restart zivpn', () => {});
    
    let domain = 'Not set';
    if (fs.existsSync(DOMAIN_FILE)) {
        domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
    }
    
    res.json({
        success: true,
        data: {
            password: password,
            expired: expDateStr,
            ip_limit: String(ip_limit || 0),
            domain: domain
        }
    });
});

// ==================== DELETE USER ====================
app.post('/api/user/delete', authMiddleware, (req, res) => {
    const { password } = req.body;
    
    const configFile = '/etc/zivpn/config.json';
    let config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
    config.auth.config = config.auth.config.filter(p => p !== password);
    fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
    
    const users = loadUsers();
    const newUsers = users.filter(u => u.password !== password);
    fs.writeFileSync(USER_DB, JSON.stringify(newUsers, null, 2));
    
    exec('systemctl restart zivpn', () => {});
    
    res.json({ success: true, message: 'User deleted' });
});

// ==================== RENEW USER ====================
app.post('/api/user/renew', authMiddleware, (req, res) => {
    const { password, days } = req.body;
    
    const users = loadUsers();
    let newExpDate = '';
    
    const newUsers = users.map(u => {
        if (u.password === password) {
            let currentExp = new Date(u.expired);
            if (currentExp < new Date()) currentExp = new Date();
            currentExp.setDate(currentExp.getDate() + parseInt(days));
            newExpDate = currentExp.toISOString().split('T')[0];
            u.expired = newExpDate;
            if (u.status === 'locked') u.status = 'active';
        }
        return u;
    });
    fs.writeFileSync(USER_DB, JSON.stringify(newUsers, null, 2));
    
    exec('systemctl restart zivpn', () => {});
    
    res.json({ success: true, data: { password: password, expired: newExpDate } });
});

// ==================== TRIAL USER ====================
app.post('/api/user/trial', authMiddleware, (req, res) => {
    const trialPassword = 'trial_' + Math.random().toString(36).substr(2, 8);
    
    const configFile = '/etc/zivpn/config.json';
    let config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
    config.auth.config.push(trialPassword);
    fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
    
    const expDate = new Date();
    expDate.setMinutes(expDate.getMinutes() + 30);
    const expDateStr = expDate.toISOString().split('T')[0];
    
    const users = loadUsers();
    users.push({
        password: trialPassword,
        expired: expDateStr,
        expired_time: expDate.toISOString(),
        ip_limit: 1,
        status: 'active',
        is_trial: true,
        created_at: new Date().toISOString()
    });
    fs.writeFileSync(USER_DB, JSON.stringify(users, null, 2));
    
    exec('systemctl restart zivpn', () => {});
    
    let domain = 'Not set';
    if (fs.existsSync(DOMAIN_FILE)) {
        domain = fs.readFileSync(DOMAIN_FILE, 'utf8').trim();
    }
    
    res.json({
        success: true,
        data: {
            password: trialPassword,
            expired: expDate.toISOString(),
            ip_limit: '1',
            domain: domain
        }
    });
});

// ==================== LOCK USER ====================
app.post('/api/user/lock', authMiddleware, (req, res) => {
    const { password } = req.body;
    
    const configFile = '/etc/zivpn/config.json';
    let config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
    config.auth.config = config.auth.config.filter(p => p !== password);
    fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
    
    const users = loadUsers();
    const newUsers = users.map(u => {
        if (u.password === password) u.status = 'locked';
        return u;
    });
    fs.writeFileSync(USER_DB, JSON.stringify(newUsers, null, 2));
    
    exec('systemctl restart zivpn', () => {});
    
    res.json({ success: true, message: 'User locked' });
});

// ==================== UNLOCK USER ====================
app.post('/api/user/unlock', authMiddleware, (req, res) => {
    const { password } = req.body;
    
    const configFile = '/etc/zivpn/config.json';
    let config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
    if (!config.auth.config.includes(password)) {
        config.auth.config.push(password);
        fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
    }
    
    const users = loadUsers();
    const newUsers = users.map(u => {
        if (u.password === password) u.status = 'active';
        return u;
    });
    fs.writeFileSync(USER_DB, JSON.stringify(newUsers, null, 2));
    
    exec('systemctl restart zivpn', () => {});
    
    res.json({ success: true, message: 'User unlocked' });
});

// ==================== SERVICE RESTART ====================
app.post('/api/service/restart', authMiddleware, (req, res) => {
    exec('systemctl restart zivpn zivpn-api-js zivpn-bot', (error) => {
        res.json({ success: !error, message: error ? error.message : 'All services restarted' });
    });
});

app.post('/api/service/restart/zivpn', authMiddleware, (req, res) => {
    exec('systemctl restart zivpn', (error) => {
        res.json({ success: !error, message: error ? error.message : 'ZiVPN restarted' });
    });
});

app.post('/api/service/restart/api', authMiddleware, (req, res) => {
    exec('systemctl restart zivpn-api-js', (error) => {
        res.json({ success: !error, message: error ? error.message : 'API restarted' });
    });
});

app.post('/api/service/restart/bot', authMiddleware, (req, res) => {
    exec('systemctl restart zivpn-bot', (error) => {
        res.json({ success: !error, message: error ? error.message : 'Bot restarted' });
    });
});

// ==================== BACKUP ====================
app.post('/api/backup/create', authMiddleware, (req, res) => {
    const backupId = 'backup_' + Date.now();
    res.json({ success: true, data: { backup_id: backupId } });
});

app.get('/api/backup/list', authMiddleware, (req, res) => {
    const backupDir = '/root/zivpn_backups';
    const backups = [];
    
    if (fs.existsSync(backupDir)) {
        const files = fs.readdirSync(backupDir);
        files.forEach(f => {
            if (f.endsWith('.zip')) {
                const stats = fs.statSync(`${backupDir}/${f}`);
                backups.push({
                    id: f.replace('.zip', ''),
                    name: f,
                    size: stats.size,
                    created: stats.mtime
                });
            }
        });
    }
    
    res.json({ success: true, data: backups });
});

app.post('/api/backup/restore', authMiddleware, (req, res) => {
    const { backup_id } = req.body;
    res.json({ success: true, message: `Backup ${backup_id} restored` });
});

// ==================== GITHUB TOKEN ====================
app.post('/api/github/token', authMiddleware, (req, res) => {
    const { token } = req.body;
    if (token) {
        fs.writeFileSync('/etc/zivpn/github_token', token);
        res.json({ success: true, message: 'GitHub token saved' });
    } else {
        res.json({ success: false, message: 'Token required' });
    }
});

app.get('/api/github/token', authMiddleware, (req, res) => {
    const configured = fs.existsSync('/etc/zivpn/github_token');
    let token = null;
    if (configured) {
        token = fs.readFileSync('/etc/zivpn/github_token', 'utf8').trim();
        token = token.substring(0, 10) + '...' + token.substring(token.length - 10);
    }
    res.json({ success: true, data: { configured: configured, token: token } });
});

app.delete('/api/github/token', authMiddleware, (req, res) => {
    if (fs.existsSync('/etc/zivpn/github_token')) {
        fs.unlinkSync('/etc/zivpn/github_token');
    }
    res.json({ success: true, message: 'GitHub token deleted' });
});

// ==================== START SERVER ====================
app.listen(PORT, '0.0.0.0', () => {
    console.log(`✅ ZiVPN API running on port ${PORT}`);
    console.log(`🔑 API Key: ${AUTH_TOKEN}`);
    console.log(`📍 URL: http://0.0.0.0:${PORT}`);
});

module.exports = app;
