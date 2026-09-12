import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import { ZipArchive } from 'archiver';
import crypto from 'crypto';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = 3000;

// Security Middleware: Hide technology stack
app.disable('x-powered-by');

// Cybersecurity Headers Middleware (OWASP recommended baseline)
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'SAMEORIGIN');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'camera=(self), microphone=(), geolocation=()');
  next();
});

app.use(express.json({ limit: '1mb' }));
app.use(express.static(__dirname));

// Rate limiting map in-memory for brute force mitigation
const rateLimitMap = new Map();

function checkRateLimit(ip, maxRequests = 30, windowMs = 60000) {
  const now = Date.now();
  const entry = rateLimitMap.get(ip) || { count: 0, resetTime: now + windowMs };
  if (now > entry.resetTime) {
    entry.count = 1;
    entry.resetTime = now + windowMs;
  } else {
    entry.count++;
  }
  rateLimitMap.set(ip, entry);
  return entry.count <= maxRequests;
}

// Secret hash for AL credential verification
const SECRET_AL_HASH = 'b7aea05ac84d296afc2f35daec1541dda23ec7466ea0544d19270877e2a2c41a';

// Secure Admin Verification Endpoint (Server-Side Double Check)
app.post('/api/auth/verify', (req, res) => {
  const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';
  if (!checkRateLimit(clientIp, 10, 60000)) {
    return res.status(429).json({
      error: 'Security alert: Too many authentication attempts. Please try again later.'
    });
  }

  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({
      error: 'خطأ أمني: كلمة المرور تتكون من أكثر من 8 خانات وتحتوي على أرقام وحروف'
    });
  }

  const computedHash = crypto.createHash('sha256').update(String(password)).digest('hex');

  if (username === 'AL' && computedHash === SECRET_AL_HASH) {
    return res.json({
      success: true,
      role: 'super_admin',
      token: SECRET_AL_HASH
    });
  }

  // Deceptive error response
  return res.status(401).json({
    success: false,
    deception: true,
    error: 'خطأ أمني: كلمة المرور غير صحيحة! كلمة المرور تتكون من أكثر من 8 خانات (رموز وأرقام وحروف)'
  });
});

// Endpoint to download the entire project as a clean, complete ZIP package
app.get('/api/download-project', async (req, res) => {
  try {
    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', 'attachment; filename="shop-qr-platform-secure.zip"');

    const zip = new ZipArchive();
    zip.pipe(res);

    const filesToInclude = [
      'index.html',
      'server.js',
      'package.json',
      'supabase_schema.sql',
      '.env.example',
      '.gitignore',
      'README.md',
      'metadata.json',
      'admin_face.jpg'
    ];

    for (const file of filesToInclude) {
      const fullPath = path.join(__dirname, file);
      if (fs.existsSync(fullPath)) {
        zip.file(fullPath, { name: file });
      }
    }

    await zip.finalize();
  } catch (err) {
    console.error('Error generating zip:', err);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Failed to generate project archive' });
    }
  }
});

// Configuration endpoint for environment variables
app.get('/api/config', (req, res) => {
  res.json({
    supabaseUrl: process.env.SUPABASE_URL || null,
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY || null
  });
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', secured: true, time: new Date().toISOString() });
});

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Secured Server running on http://0.0.0.0:${PORT}`);
});


