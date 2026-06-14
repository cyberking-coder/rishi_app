'use strict';

const express = require('express');
const cors = require('cors');
const env = require('./config/env');
const authRoutes = require('./routes/auth');
const mediaRoutes = require('./routes/media');

const app = express();

// We sit behind one reverse proxy in production; trust it for accurate client IPs.
app.set('trust proxy', 1);
app.use(cors({ origin: env.corsOrigin === '*' ? true : env.corsOrigin.split(',') }));
app.use(express.json({ limit: '1mb' }));

app.get('/api/health', (req, res) => res.json({ ok: true, service: 'anurag-rishi-api' }));

app.use('/api/auth', authRoutes);
app.use('/api/media', mediaRoutes);

// 404
app.use((req, res) => {
  res.status(404).json({ error: { message: 'Not found', code: 'not_found' } });
});

// Centralized error handler — maps ApiError + known errors to clean JSON.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  const status = err.status || 500;
  if (status >= 500) console.error(err);
  res.status(status).json({
    error: {
      message: err.message || 'Internal server error',
      code: err.code || 'internal',
    },
  });
});

if (require.main === module) {
  app.listen(env.port, () => {
    console.log(`Anurag_Rishi API listening on http://localhost:${env.port}`);
  });
}

module.exports = app;
