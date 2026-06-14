'use strict';

const mysql = require('mysql2/promise');
const env = require('./env');

// A single shared connection pool for the whole app.
const pool = mysql.createPool({
  host: env.db.host,
  port: env.db.port,
  user: env.db.user,
  password: env.db.password,
  database: env.db.database,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  namedPlaceholders: true,
});

module.exports = { pool };
