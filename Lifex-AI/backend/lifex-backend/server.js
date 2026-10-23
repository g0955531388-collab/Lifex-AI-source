'use strict';

const http = require('http');
const crypto = require('crypto');

const host = process.env.LIFEX_BACKEND_HOST || '0.0.0.0';
const port = Number(process.env.PORT || process.env.LIFEX_BACKEND_PORT || 3000);
const profiles = new Map();
const syncByProfile = new Map();
const entities = new Map();

function send(res, status, body) {
  const raw = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(raw),
  });
  res.end(raw);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 2_000_000) {
        reject(new Error('body too large'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      const text = Buffer.concat(chunks).toString('utf8').trim();
      if (!text) {
        resolve({});
        return;
      }
      try {
        const parsed = JSON.parse(text);
        resolve(parsed && typeof parsed === 'object' ? parsed : {});
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || '/', `http://127.0.0.1:${port}`);
  const parts = url.pathname.split('/').filter(Boolean);

  try {
    if (req.method === 'GET' && url.pathname === '/health') {
      send(res, 200, { status: 'ok' });
      console.log('[lifex-backend] GET /health 200');
      return;
    }

    if (req.method === 'GET' && url.pathname === '/medical-manifest') {
      send(res, 200, {
        version: '0.1.0',
        generatedAt: new Date().toISOString(),
        sources: [],
        note: 'لا ملفات طبية على هذا الخادم. نسخة الأصول في التطبيق تبقى هي المرجع.',
      });
      console.log('[lifex-backend] GET /medical-manifest 200');
      return;
    }

    if (req.method === 'POST' && url.pathname === '/auth/profile') {
      const body = await readBody(req);
      const deviceId = typeof body.deviceId === 'string' ? body.deviceId.trim() : '';
      if (!deviceId) {
        send(res, 400, { error: 'deviceId مطلوب' });
        console.log('[lifex-backend] POST /auth/profile 400');
        return;
      }
      const profileId = crypto.randomUUID();
      const displayName =
        typeof body.displayName === 'string' ? body.displayName : '';
      profiles.set(profileId, {
        profileId,
        deviceId,
        displayName,
        createdAt: new Date().toISOString(),
      });
      send(res, 200, { profileId });
      console.log(`[lifex-backend] POST /auth/profile 200 profileId=${profileId}`);
      return;
    }

    if (req.method === 'POST' && url.pathname === '/sync/push') {
      const body = await readBody(req);
      const profileId =
        typeof body.profileId === 'string' ? body.profileId.trim() : '';
      if (!profileId || body.payload == null) {
        send(res, 400, { error: 'profileId و payload مطلوبان' });
        console.log('[lifex-backend] POST /sync/push 400');
        return;
      }
      syncByProfile.set(profileId, {
        updatedAt: new Date().toISOString(),
        payload: body.payload,
      });
      send(res, 200, { ok: true });
      console.log(`[lifex-backend] POST /sync/push 200 profileId=${profileId}`);
      return;
    }

    if (req.method === 'GET' && url.pathname === '/sync/pull') {
      const profileId = (url.searchParams.get('profileId') || '').trim();
      const data = syncByProfile.get(profileId);
      if (!data) {
        send(res, 404, { error: 'لا بيانات' });
        console.log('[lifex-backend] GET /sync/pull 404');
        return;
      }
      send(res, 200, data);
      console.log(`[lifex-backend] GET /sync/pull 200 profileId=${profileId}`);
      return;
    }

    if (parts[0] === 'sync' && parts.length === 3) {
      const entityType = parts[1];
      const entityId = decodeURIComponent(parts[2]);
      const key = `${entityType}/${entityId}`;
      if (req.method === 'POST') {
        const payload = await readBody(req);
        entities.set(key, payload);
        send(res, 200, { stored: true, entityType, entityId });
        console.log(`[lifex-backend] POST /sync/${entityType}/${entityId} 200`);
        return;
      }
      if (req.method === 'GET') {
        if (!entities.has(key)) {
          send(res, 404, { stored: false, entityType, entityId });
          console.log(`[lifex-backend] GET /sync/${entityType}/${entityId} 404`);
          return;
        }
        send(res, 200, entities.get(key));
        console.log(`[lifex-backend] GET /sync/${entityType}/${entityId} 200`);
        return;
      }
    }

    send(res, 404, { error: 'not_found' });
    console.log(`[lifex-backend] ${req.method} ${url.pathname} 404`);
  } catch (error) {
    send(res, 400, { error: 'bad_request' });
    console.log(`[lifex-backend] ${req.method} ${url.pathname} 400`);
  }
});

server.listen(port, host, () => {
  console.log(`[lifex-backend] listening http://${host}:${port}`);
  console.log('[lifex-backend] ذاكرة فقط. deviceId ليس مصادقة. لا HTTPS ولا JWT.');
});
