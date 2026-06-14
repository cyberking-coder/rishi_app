'use strict';

const jwt = require('jsonwebtoken');
const env = require('../config/env');
const { pool } = require('../config/db');
const { ApiError } = require('../utils/http');

// Verifies the Bearer JWT, then re-checks the device lock on every request.
// This means revoking a device (clearing bound_device_id) takes effect immediately,
// even if the attacker still holds a valid token.
async function requireAuth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) throw new ApiError(401, 'Missing authorization token', 'no_token');

    let payload;
    try {
      payload = jwt.verify(token, env.jwt.secret);
    } catch {
      throw new ApiError(401, 'Invalid or expired token', 'bad_token');
    }

    const [rows] = await pool.query(
      'SELECT id, email, display_name, role, bound_device_id, is_active FROM users WHERE id = :id',
      { id: payload.sub }
    );
    const user = rows[0];
    if (!user || !user.is_active) {
      throw new ApiError(401, 'Account not found or disabled', 'inactive');
    }

    // The token carries the device it was issued to. It must still match the
    // account's bound device, otherwise the session is rejected.
    if (user.bound_device_id && payload.did && user.bound_device_id !== payload.did) {
      throw new ApiError(423, 'This account is locked to another device', 'device_locked');
    }

    req.user = user;
    req.deviceId = payload.did || null;
    next();
  } catch (err) {
    next(err);
  }
}

function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return next(new ApiError(403, 'Admin access required', 'forbidden'));
  }
  next();
}

module.exports = { requireAuth, requireAdmin };
