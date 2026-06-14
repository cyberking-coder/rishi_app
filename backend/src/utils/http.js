'use strict';

// Best-effort client IP, honouring a single proxy hop (X-Forwarded-For).
// In production set `app.set('trust proxy', ...)` to match your deployment.
function clientIp(req) {
  const fwd = req.headers['x-forwarded-for'];
  if (typeof fwd === 'string' && fwd.length > 0) {
    return fwd.split(',')[0].trim();
  }
  return req.socket?.remoteAddress || null;
}

function userAgent(req) {
  const ua = req.headers['user-agent'];
  return typeof ua === 'string' ? ua.slice(0, 255) : null;
}

// Wraps an async route handler so thrown errors reach Express' error middleware.
function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

class ApiError extends Error {
  constructor(status, message, code) {
    super(message);
    this.status = status;
    this.code = code || null;
  }
}

module.exports = { clientIp, userAgent, asyncHandler, ApiError };
