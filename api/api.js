const express = require('express');
const fs = require('fs');
const { exec } = require('child_process');
const path = require('path');
const crypto = require('crypto');

const app = express();
const PORT = 8586;  // PORT BARU

// ==================== GENERATE API KEY OTOMATIS ====================
// Format: PX- + random 32 karakter (huruf + angka)
const generateApiKey = () => {
    const randomPart = crypto.randomBytes(16).toString('hex'); // 32 karakter hex
    return `PX-${randomPart}`;
};

// Cek apakah file API Key sudah ada
const API_KEY_FILE = '/etc/zivpn/api_key.txt';
let API_KEY = '';

if (fs.existsSync(API_KEY_FILE)) {
    // Baca API Key dari file jika sudah ada
    API_KEY = fs.readFileSync(API_KEY_FILE, 'utf8').trim();
    console.log(`📖 API Key loaded from file: ${API_KEY.substring(0, 10)}...`);
} else {
    // Generate API Key baru jika belum ada
    API_KEY = generateApiKey();
    fs.writeFileSync(API_KEY_FILE, API_KEY);
    console.log(`🔑 New API Key generated: ${API_KEY}`);
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

// Verify API Key middleware
const verifyApiKey = (req, res, next) => {
    const apiKey = req.headers['x-api-key'] || req.query.api_key;
    if (apiKey === API_KEY) {
        next();
    } else {
        res.status(401).json({ 
            status: 'error', 
            message: 'Invalid API Key' 
        });
    }
};

// Helper function to run scripts
const runScript = (scriptName, args = [], input = null) => {
    return new Promise((resolve, reject) => {
        const scriptPath = `/usr/local/bin/${scriptName}`;
        
        if (!fs.existsSync(scriptPath)) {
            reject(new Error(`Script ${scriptName} not found at ${scriptPath}`));
            return;
        }

        const command = scriptPath;
        const options = { timeout: 60000 };
        
        const child = exec(command, options, (error, stdout, stderr) => {
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
};

// ==================== ROOT ENDPOINT ====================

app.get('/', (req, res) => {
    res.json({
        name: 'ZiVPN API',
        version: '2.0.0',
        status: 'running',
        port: PORT,
        api_key: API_KEY,
        api_key_preview: API_KEY.substring(0, 10) + '...' + API_KEY.substring(API_KEY.length - 10),
        endpoints: {
            system: {
                'GET /': 'API Information',
                'GET /health': 'Health check',
                'GET /status': 'Service status',
                'GET /config': 'Get configuration',
                'GET /api-key': 'Get API key info'
            },
            users: {
                'GET /users': 'List all users',
                'GET /user/:password': 'Get user details',
                'POST /user/create': 'Create user (body: password, days, iplimit)',
                'POST /user/create-random': 'Create random user (body: days, iplimit)',
                'POST /user/delete': 'Delete user (body: password)',
                'POST /user/renew': 'Renew user (body: password, days)',
                'POST /user/trial': 'Create trial user (30 minutes)',
                'POST /user/lock': 'Lock user (body: password)',
                'POST /user/unlock': 'Unlock user (body: password)'
            },
            bot: {
                'POST /bot/install': 'Install Telegram bot',
                'POST /bot/install-pakasir': 'Install Pakasir bot',
                'GET /bot/status': 'Get bot status',
                'DELETE /bot/uninstall': 'Uninstall bot'
            },
            service: {
                'POST /service/restart': 'Restart all services',
                'POST /service/restart/zivpn': 'Restart ZiVPN core',
                'POST /service/restart/api': 'Restart API',
                'POST /service/restart/bot': 'Restart bot',
                'GET /service/status': 'Get all services status'
            },
            backup: {
                'POST /backup/create': 'Create backup',
                'POST /backup/restore': 'Restore backup (body: backup_id)',
                'GET /backup/list': 'List available backups',
                'DELETE /backup/:backup_id': 'Delete backup'
            },
            github: {
                'POST /github/token': 'Set GitHub token (body: token)',
                'GET /github/token': 'Check GitHub token status',
                'DELETE /github/token': 'Delete GitHub token'
            },
            menu: {
                'POST /menu/update': 'Update menu from GitHub'
            }
        }
    });
});

// Get API Key info
app.get('/api-key', verifyApiKey, (req, res) => {
    res.json({
        status: 'success',
        api_key: API_KEY,
        format: 'PX-{random}',
        length: API_KEY.length,
        file_location: API_KEY_FILE
    });
});

// Regenerate API Key (only if requested)
app.post('/api-key/regenerate', verifyApiKey, (req, res) => {
    const newApiKey = `PX-${crypto.randomBytes(16).toString('hex')}`;
    fs.writeFileSync(API_KEY_FILE, newApiKey);
    
    res.json({
        status: 'success',
        message: 'API Key regenerated successfully',
        old_key: API_KEY,
        new_key: newApiKey,
        note: 'Please save this new API key and restart the service'
    });
});

// ==================== HEALTH CHECK ====================

app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        port: PORT
    });
});

// ==================== SYSTEM STATUS ====================

app.get('/status', verifyApiKey, (req, res) => {
    const services = ['zivpn', 'zivpn-api', 'zivpn-bot'];
    const results = {};
    let completed = 0;
    
    services.forEach(service => {
        exec(`systemctl is-active ${service}`, (error, stdout) => {
            results[service] = stdout.trim();
            completed++;
            
            if (completed === services.length) {
                res.json({
                    status: 'success',
                    services: results,
                    api_key_configured: true,
                    api_key: API_KEY.substring(0, 10) + '...',
                    port: PORT,
                    timestamp: new Date().toISOString()
                });
            }
        });
    });
});

// ==================== CONFIGURATION ====================

app.get('/config', verifyApiKey, (req, res) => {
    const config = {};
    
    // Domain
    if (fs.existsSync('/etc/zivpn/domain')) {
        config.domain = fs.readFileSync('/etc/zivpn/domain', 'utf8').trim();
    }
    
    // Server config
    if (fs.existsSync('/etc/zivpn/config.json')) {
        try {
            config.server = JSON.parse(fs.readFileSync('/etc/zivpn/config.json', 'utf8'));
        } catch(e) {}
    }
    
    // Total users
    if (fs.existsSync('/etc/zivpn/users.json')) {
        try {
            const users = JSON.parse(fs.readFileSync('/etc/zivpn/users.json', 'utf8'));
            config.total_users = users.length;
            config.active_users = users.filter(u => u.status === 'active').length;
        } catch(e) {}
    }
    
    // GitHub token status
    config.github_token_configured = fs.existsSync('/etc/zivpn/github_token');
    
    res.json({ status: 'success', config });
});

// ==================== USER MANAGEMENT ====================

// List all users
app.get('/users', verifyApiKey, (req, res) => {
    const usersFile = '/etc/zivpn/users.json';
    
    if (!fs.existsSync(usersFile)) {
        return res.json({ status: 'success', total: 0, users: [] });
    }
    
    try {
        const users = JSON.parse(fs.readFileSync(usersFile, 'utf8'));
        const today = new Date().toISOString().split('T')[0];
        
        const usersWithStatus = users.map(user => {
            const isExpired = user.expired < today;
            return {
                ...user,
                status_display: isExpired ? 'EXPIRED' : (user.status || 'ACTIVE')
            };
        });
        
        res.json({
            status: 'success',
            total: users.length,
            active: usersWithStatus.filter(u => u.status_display === 'ACTIVE').length,
            expired: usersWithStatus.filter(u => u.status_display === 'EXPIRED').length,
            users: usersWithStatus
        });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

// Get user by password
app.get('/user/:password', verifyApiKey, (req, res) => {
    const { password } = req.params;
    const usersFile = '/etc/zivpn/users.json';
    
    if (!fs.existsSync(usersFile)) {
        return res.status(404).json({ status: 'error', message: 'Users database not found' });
    }
    
    try {
        const users = JSON.parse(fs.readFileSync(usersFile, 'utf8'));
        const user = users.find(u => u.password === password);
        
        if (!user) {
            return res.status(404).json({ status: 'error', message: 'User not found' });
        }
        
        const today = new Date().toISOString().split('T')[0];
        const isExpired = user.expired < today;
        
        res.json({
            status: 'success',
            user: {
                ...user,
                status_display: isExpired ? 'EXPIRED' : 'ACTIVE'
            }
        });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

// Create user
app.post('/user/create', verifyApiKey, (req, res) => {
    const { password, days, iplimit } = req.body;
    
    if (!password || !days) {
        return res.status(400).json({
            status: 'error',
            message: 'Password and days are required'
        });
    }
    
    const input = `${password}\n${days}\n${iplimit || 0}\n`;
    
    runScript('add-zivpn', [], input)
        .then(result => {
            const expMatch = result.stdout.match(/Expired\s*:\s*([0-9-]+)/i);
            const expDate = expMatch ? expMatch[1] : 'unknown';
            
            res.json({
                status: 'success',
                message: 'User created successfully',
                user: {
                    password: password,
                    expired: expDate,
                    ip_limit: iplimit || 0
                },
                output: result.stdout
            });
        })
        .catch(err => {
            res.status(500).json({
                status: 'error',
                message: err.error || 'Failed to create user',
                details: err.stderr
            });
        });
});

// Create random user
app.post('/user/create-random', verifyApiKey, (req, res) => {
    const { days, iplimit } = req.body;
    
    if (!days) {
        return res.status(400).json({
            status: 'error',
            message: 'Days are required'
        });
    }
    
    const input = `${days}\n${iplimit || 0}\n`;
    
    runScript('add-random', [], input)
        .then(result => {
            const passMatch = result.stdout.match(/Password\s*:\s*([a-f0-9]+)/i);
            const expMatch = result.stdout.match(/Expired\s*:\s*([0-9-]+)/i);
            const password = passMatch ? passMatch[1] : 'unknown';
            const expDate = expMatch ? expMatch[1] : 'unknown';
            
            res.json({
                status: 'success',
                message: 'Random user created successfully',
                user: {
                    password: password,
                    expired: expDate,
                    ip_limit: iplimit || 0
                },
                output: result.stdout
            });
        })
        .catch(err => {
            res.status(500).json({
                status: 'error',
                message: err.error || 'Failed to create random user',
                details: err.stderr
            });
        });
});

// Delete user
app.post('/user/delete', verifyApiKey, (req, res) => {
    const { password } = req.body;
    
    if (!password) {
        return res.status(400).json({
            status: 'error',
            message: 'Password is required'
        });
    }
    
    const input = `${password}\n`;
    
    runScript('delete-zivpn', [], input)
        .then(result => {
            res.json({
                status: 'success',
                message: `User ${password} deleted successfully`,
                output: result.stdout
            });
        })
        .catch(err => {
            res.status(500).json({
                status: 'error',
                message: err.error || 'Failed to delete user',
                details: err.stderr
            });
        });
});

// Renew user
app.post('/user/renew', verifyApiKey, (req, res) => {
    const { password, days } = req.body;
    
    if (!password || !days) {
        return res.status(400).json({
            status: 'error',
            message: 'Password and days are required'
        });
    }
    
    const input = `${password}\n${days}\n`;
    
    runScript('renew-zivpn', [], input)
        .then(result => {
            res.json({
                status: 'success',
                message: `User ${password} renewed (+${days} days)`,
                output: result.stdout
            });
        })
        .catch(err => {
            res.status(500).json({
                status: 'error',
                message: err.error || 'Failed to renew user',
                details: err.stderr
            });
        });
});

// Trial user
app.post('/user/trial', verifyApiKey, (req, res) => {
    runScript('trial-zivpn')
        .then(result => {
            const passMatch = result.stdout.match(/Password\s*:\s*([a-f0-9]+)/i);
            const password = passMatch ? passMatch[1] : 'unknown';
            
            res.json({
                status: 'success',
                message: 'Trial user created (expires in 30 minutes)',
                user: {
                    password: password,
                    expired: '30 minutes',
                    ip_limit: 1
                },
                output: result.stdout
            });
        })
        .catch(err => {
            res.status(500).json({
                status: 'error',
                message: err.error || 'Failed to create trial user',
                details: err.stderr
            });
        });
});

// Lock user
app.post('/user/lock', verifyApiKey, (req, res) => {
    const { password } = req.body;
    
    if (!password) {
        return res.status(400).json({ status: 'error', message: 'Password is required' });
    }
    
    const usersFile = '/etc/zivpn/users.json';
    
    try {
        const users = JSON.parse(fs.readFileSync(usersFile, 'utf8'));
        const userIndex = users.findIndex(u => u.password === password);
        
        if (userIndex === -1) {
            return res.status(404).json({ status: 'error', message: 'User not found' });
        }
        
        users[userIndex].status = 'locked';
        fs.writeFileSync(usersFile, JSON.stringify(users, null, 4));
        
        res.json({
            status: 'success',
            message: `User ${password} locked`
        });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

// Unlock user
app.post('/user/unlock', verifyApiKey, (req, res) => {
    const { password } = req.body;
    
    if (!password) {
        return res.status(400).json({ status: 'error', message: 'Password is required' });
    }
    
    const usersFile = '/etc/zivpn/users.json';
    
    try {
        const users = JSON.parse(fs.readFileSync(usersFile, 'utf8'));
        const userIndex = users.findIndex(u => u.password === password);
        
        if (userIndex === -1) {
            return res.status(404).json({ status: 'error', message: 'User not found' });
        }
        
        users[userIndex].status = 'active';
        fs.writeFileSync(usersFile, JSON.stringify(users, null, 4));
        
        res.json({
            status: 'success',
            message: `User ${password} unlocked`
        });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

// ==================== BOT MANAGEMENT ====================

app.post('/bot/install', verifyApiKey, (req, res) => {
    const { bot_token, admin_id, bot_mode } = req.body;
    
    if (!bot_token || !admin_id) {
        return res.status(400).json({
            status: 'error',
            message: 'bot_token and admin_id are required'
        });
    }
    
    const input = `${bot_token}\n${admin_id}\n${bot_mode || 'private'}\n`;
    
    runScript('install-bot', [], input)
        .then(result => {
            res.json({
                status: 'success',
                message: 'Bot installed successfully',
                config: { bot_token, admin_id, bot_mode: bot_mode || 'private' },
                output: result.stdout
            });
        })
        .catch(err => {
            res.status(500).json({
                status: 'error',
                message: err.error || 'Failed to install bot',
                details: err.stderr
            });
        });
});

app.post('/bot/install-pakasir', verifyApiKey, (req, res) => {
    const { bot_token, admin_id, pakasir_slug, pakasir_key, daily_price, ip_limit } = req.body;
    
    if (!bot_token || !admin_id || !pakasir_slug || !pakasir_key || !daily_price) {
        return res.status(400).json({
            status: 'error',
            message: 'bot_token, admin_id, pakasir_slug, pakasir_key, daily_price are required'
        });
    }
    
    const input = `${bot_token}\n${admin_id}\n${pakasir_slug}\n${pakasir_key}\n${daily_price}\n${ip_limit || 1}\n`;
    
    runScript('install-pakasir', [], input)
        .then(result => {
            res.json({
                status: 'success',
                message: 'Pakasir bot installed successfully',
                config: { bot_token, admin_id, pakasir_slug, daily_price, ip_limit: ip_limit || 1 },
                output: result.stdout
            });
        })
        .catch(err => {
            res.status(500).json({
                status: 'error',
                message: err.error || 'Failed to install Pakasir bot',
                details: err.stderr
            });
        });
});

app.get('/bot/status', verifyApiKey, (req, res) => {
    exec('systemctl is-active zivpn-bot', (error, stdout) => {
        const isActive = stdout.trim() === 'active';
        
        let botConfig = null;
        if (fs.existsSync('/etc/zivpn/bot-config.json')) {
            try {
                botConfig = JSON.parse(fs.readFileSync('/etc/zivpn/bot-config.json', 'utf8'));
            } catch(e) {}
        }
        
        res.json({
            status: 'success',
            running: isActive,
            config: botConfig
        });
    });
});

app.delete('/bot/uninstall', verifyApiKey, (req, res) => {
    exec('systemctl stop zivpn-bot; systemctl disable zivpn-bot; rm -f /etc/systemd/system/zivpn-bot.service; rm -f /etc/zivpn/bot-config.json', (error) => {
        res.json({
            status: 'success',
            message: 'Bot uninstalled successfully'
        });
    });
});

// ==================== SERVICE MANAGEMENT ====================

app.post('/service/restart', verifyApiKey, (req, res) => {
    exec('systemctl restart zivpn zivpn-api zivpn-bot', (error, stdout, stderr) => {
        res.json({
            status: error ? 'error' : 'success',
            message: 'Services restarted',
            output: stdout,
            stderr: stderr
        });
    });
});

app.post('/service/restart/zivpn', verifyApiKey, (req, res) => {
    exec('systemctl restart zivpn', (error, stdout, stderr) => {
        res.json({
            status: error ? 'error' : 'success',
            message: 'ZiVPN core restarted',
            output: stdout
        });
    });
});

app.post('/service/restart/api', verifyApiKey, (req, res) => {
    exec('systemctl restart zivpn-api', (error, stdout, stderr) => {
        res.json({
            status: error ? 'error' : 'success',
            message: 'API service restarted',
            output: stdout
        });
    });
});

app.post('/service/restart/bot', verifyApiKey, (req, res) => {
    exec('systemctl restart zivpn-bot', (error, stdout, stderr) => {
        res.json({
            status: error ? 'error' : 'success',
            message: 'Bot service restarted',
            output: stdout
        });
    });
});

app.get('/service/status', verifyApiKey, (req, res) => {
    const services = ['zivpn', 'zivpn-api', 'zivpn-bot'];
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
                res.json({
                    status: 'success',
                    services: results,
                    timestamp: new Date().toISOString()
                });
            }
        });
    });
});

// ==================== BACKUP MANAGEMENT ====================

app.post('/backup/create', verifyApiKey, (req, res) => {
    runScript('backup')
        .then(result => {
            const idMatch = result.stdout.match(/Backup ID\s*:\s*([a-zA-Z0-9]+)/i);
            const backupId = idMatch ? idMatch[1] : 'unknown';
            
            res.json({
                status: 'success',
                message: 'Backup created successfully',
                backup_id: backupId,
                output: result.stdout
            });
        })
        .catch(err => {
            res.status(500).json({
                status: 'error',
                message: err.error || 'Failed to create backup',
                details: err.stderr
            });
        });
});

app.post('/backup/restore', verifyApiKey, (req, res) => {
    const { backup_id } = req.body;
    
    if (!backup_id) {
        return res.status(400).json({
            status: 'error',
            message: 'backup_id is required'
        });
    }
    
    const input = `${backup_id}\n`;
    
    runScript('restore', [], input)
        .then(result => {
            res.json({
                status: 'success',
                message: `Backup ${backup_id} restored successfully`,
                output: result.stdout
            });
        })
        .catch(err => {
            res.status(500).json({
                status: 'error',
                message: err.error || 'Failed to restore backup',
                details: err.stderr
            });
        });
});

app.get('/backup/list', verifyApiKey, (req, res) => {
    const backupDir = '/root/zivpn_backups';
    
    if (!fs.existsSync(backupDir)) {
        return res.json({ status: 'success', backups: [] });
    }
    
    fs.readdir(backupDir, (err, files) => {
        if (err) {
            return res.status(500).json({ status: 'error', message: err.message });
        }
        
        const backups = files
            .filter(f => f.endsWith('.zip'))
            .map(f => {
                const stats = fs.statSync(`${backupDir}/${f}`);
                return {
                    id: f.replace('.zip', ''),
                    name: f,
                    size: stats.size,
                    created: stats.mtime
                };
            });
        
        res.json({
            status: 'success',
            total: backups.length,
            backups: backups
        });
    });
});

app.delete('/backup/:backup_id', verifyApiKey, (req, res) => {
    const { backup_id } = req.params;
    const backupFile = `/root/zivpn_backups/${backup_id}.zip`;
    
    if (!fs.existsSync(backupFile)) {
        return res.status(404).json({ status: 'error', message: 'Backup not found' });
    }
    
    fs.unlinkSync(backupFile);
    res.json({
        status: 'success',
        message: `Backup ${backup_id} deleted`
    });
});

// ==================== GITHUB TOKEN MANAGEMENT ====================

app.post('/github/token', verifyApiKey, (req, res) => {
    const { token } = req.body;
    
    if (!token) {
        return res.status(400).json({
            status: 'error',
            message: 'token is required'
        });
    }
    
    const input = `${token}\n`;
    
    runScript('github-token', [], input)
        .then(result => {
            res.json({
                status: 'success',
                message: 'GitHub token saved',
                output: result.stdout
            });
        })
        .catch(err => {
            res.status(500).json({
                status: 'error',
                message: err.error || 'Failed to save token',
                details: err.stderr
            });
        });
});

app.get('/github/token', verifyApiKey, (req, res) => {
    const tokenExists = fs.existsSync('/etc/zivpn/github_token');
    let tokenPreview = null;
    
    if (tokenExists) {
        const token = fs.readFileSync('/etc/zivpn/github_token', 'utf8').trim();
        tokenPreview = token.substring(0, 10) + '...' + token.substring(token.length - 10);
    }
    
    res.json({
        status: 'success',
        configured: tokenExists,
        token: tokenPreview
    });
});

app.delete('/github/token', verifyApiKey, (req, res) => {
    runScript('del-token')
        .then(result => {
            res.json({
                status: 'success',
                message: 'GitHub token deleted',
                output: result.stdout
            });
        })
        .catch(err => {
            res.status(500).json({
                status: 'error',
                message: err.error || 'Failed to delete token',
                details: err.stderr
            });
        });
});

// ==================== MENU UPDATE ====================

app.post('/menu/update', verifyApiKey, (req, res) => {
    runScript('update-zivpn')
        .then(result => {
            res.json({
                status: 'success',
                message: 'Menu updated successfully',
                output: result.stdout
            });
        })
        .catch(err => {
            res.status(500).json({
                status: 'error',
                message: err.error || 'Failed to update menu',
                details: err.stderr
            });
        });
});

// ==================== START SERVER ====================

app.listen(PORT, '0.0.0.0', () => {
    console.log('\x1b[36m═══════════════════════════════════════════════════════════\x1b[0m');
    console.log('\x1b[32m✅ ZiVPN API Server Started Successfully!\x1b[0m');
    console.log('\x1b[36m═══════════════════════════════════════════════════════════\x1b[0m');
    console.log(`\x1b[33m📍 URL:\x1b[0m http://0.0.0.0:${PORT}`);
    console.log(`\x1b[33m🔑 API Key:\x1b[0m ${API_KEY}`);
    console.log(`\x1b[33m💾 API Key File:\x1b[0m ${API_KEY_FILE}`);
    console.log(`\x1b[33m📁 Config Dir:\x1b[0m /etc/zivpn`);
    console.log(`\x1b[33m📝 Test:\x1b[0m curl http://localhost:${PORT}/status -H "x-api-key: ${API_KEY}"`);
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