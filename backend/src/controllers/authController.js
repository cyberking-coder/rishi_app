'use strict';

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const { pool } = require('../config/db');
const { ApiError, clientIp, userAgent } = require('../utils/http');

function signToken(user, deviceId) {
  // `did` = device id the token is bound to; re-checked on every request.
  return jwt.sign(
    { sub: user.id, role: user.role, did: deviceId },
    env.jwt.secret,
    { expiresIn: env.jwt.expiresIn }
  );
}

function publicUser(user) {
  return {
    id: user.id,
    email: user.email,
    displayName: user.display_name,
    role: user.role,
  };
}

async function recordAudit(conn, { userId, email, deviceId, ip, ua, outcome }) {
  await conn.query(
    `INSERT INTO login_audit (user_id, email, device_id, ip_address, user_agent, outcome)
     VALUES (:userId, :email, :deviceId, :ip, :ua, :outcome)`,
    { userId: userId || null, email: email || null, deviceId: deviceId || null, ip, ua, outcome }
  );
}

// POST /api/auth/register
async function register(req, res) {
  const { email, password, displayName } = req.body || {};
  if (!email || !password || !displayName) {
    throw new ApiError(400, 'email, password and displayName are required', 'validation');
  }
  if (String(password).length < 8) {
    throw new ApiError(400, 'Password must be at least 8 characters', 'validation');
  }

  const normalizedEmail = String(email).trim().toLowerCase();
  const passwordHash = await bcrypt.hash(String(password), 12);

  try {
    const [result] = await pool.query(
      `INSERT INTO users (email, display_name, password_hash)
       VALUES (:email, :displayName, :passwordHash)`,
      { email: normalizedEmail, displayName: String(displayName).trim(), passwordHash }
    );
    const [rows] = await pool.query('SELECT * FROM users WHERE id = :id', { id: result.insertId });
    // Registration does not log the user in or bind a device — that happens at first login,
    // so the lock is tied to the device the user actually signs in from.
    res.status(201).json({ user: publicUser(rows[0]) });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      throw new ApiError(409, 'An account with that email already exists', 'email_taken');
    }
    throw err;
  }
}

// POST /api/auth/login
// Body: { email, password, device: { id, platform, model, osVersion } }
async function login(req, res) {
  const { email, password, device } = req.body || {};
  const deviceId = device && device.id ? String(device.id) : null;
  const ip = clientIp(req);
  const ua = userAgent(req);

  if (!email || !password || !deviceId) {
    throw new ApiError(400, 'email, password and device.id are required', 'validation');
  }
  const normalizedEmail = String(email).trim().toLowerCase();

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const [rows] = await conn.query(
      'SELECT * FROM users WHERE email = :email FOR UPDATE',
      { email: normalizedEmail }
    );
    const user = rows[0];

    if (!user) {
      await recordAudit(conn, { email: normalizedEmail, deviceId, ip, ua, outcome: 'bad_credentials' });
      await conn.commit();
      throw new ApiError(401, 'Invalid email or password', 'bad_credentials');
    }
    if (!user.is_active) {
      await recordAudit(conn, { userId: user.id, email: normalizedEmail, deviceId, ip, ua, outcome: 'inactive' });
      await conn.commit();
      throw new ApiError(403, 'This account is disabled', 'inactive');
    }

    const ok = await bcrypt.compare(String(password), user.password_hash);
    if (!ok) {
      await recordAudit(conn, { userId: user.id, email: normalizedEmail, deviceId, ip, ua, outcome: 'bad_credentials' });
      await conn.commit();
      throw new ApiError(401, 'Invalid email or password', 'bad_credentials');
    }

    // ---- Device-lock enforcement ----
    // Admins are exempt: they manage the catalog from a browser/desktop and must
    // not get bound to a single device. The lock applies to content consumers only.
    if (user.role === 'admin') {
      // no binding, no enforcement
    } else if (!user.bound_device_id) {
      // First ever successful login → bind the account to this device.
      await conn.query(
        'UPDATE users SET bound_device_id = :did WHERE id = :id',
        { did: deviceId, id: user.id }
      );
      user.bound_device_id = deviceId;
    } else if (user.bound_device_id !== deviceId) {
      // Account already bound to a DIFFERENT device → reject.
      await recordAudit(conn, { userId: user.id, email: normalizedEmail, deviceId, ip, ua, outcome: 'device_locked' });
      await conn.commit();
      throw new ApiError(423, 'This account is already in use on another device', 'device_locked');
    }

    // Upsert the device record + refresh last-seen ip (audit trail).
    await conn.query(
      `INSERT INTO devices (user_id, device_id, platform, model, os_version, first_seen_ip, last_seen_ip)
       VALUES (:userId, :deviceId, :platform, :model, :osVersion, :ip, :ip)
       ON DUPLICATE KEY UPDATE last_seen_ip = :ip, last_seen_at = CURRENT_TIMESTAMP`,
      {
        userId: user.id,
        deviceId,
        platform: device.platform || null,
        model: device.model || null,
        osVersion: device.osVersion || null,
        ip,
      }
    );

    await recordAudit(conn, { userId: user.id, email: normalizedEmail, deviceId, ip, ua, outcome: 'success' });
    await conn.commit();

    const token = signToken(user, deviceId);
    res.json({ token, user: publicUser(user) });
  } catch (err) {
    await conn.rollback().catch(() => {});
    throw err;
  } finally {
    conn.release();
  }
}

// GET /api/auth/me
async function me(req, res) {
  res.json({ user: publicUser(req.user) });
}

module.exports = { register, login, me };
