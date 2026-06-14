'use strict';

const fs = require('fs');
const path = require('path');
const env = require('../config/env');
const { pool } = require('../config/db');
const { ApiError } = require('../utils/http');

function publicMedia(row) {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    mediaType: row.media_type,
    thumbnailUrl: row.thumbnail_url,
    durationSecs: row.duration_secs,
    isDownloadable: !!row.is_downloadable,
  };
}

// Resolve a media row's file path safely inside MEDIA_DIR (prevents path traversal).
function resolveMediaPath(fileKey) {
  const base = path.resolve(env.mediaDir);
  const full = path.resolve(base, fileKey);
  if (full !== base && !full.startsWith(base + path.sep)) {
    throw new ApiError(400, 'Invalid media path', 'bad_path');
  }
  return full;
}

async function loadMediaOrThrow(id) {
  const [rows] = await pool.query(
    'SELECT * FROM media WHERE id = :id AND is_published = 1',
    { id }
  );
  if (!rows[0]) throw new ApiError(404, 'Media not found', 'not_found');
  return rows[0];
}

// GET /api/media?type=video|audio
async function listMedia(req, res) {
  const { type } = req.query;
  const params = {};
  let where = 'is_published = 1';
  if (type === 'video' || type === 'audio') {
    where += ' AND media_type = :type';
    params.type = type;
  }
  const [rows] = await pool.query(
    `SELECT * FROM media WHERE ${where} ORDER BY created_at DESC`,
    params
  );
  res.json({ items: rows.map(publicMedia) });
}

// GET /api/media/:id
async function getMedia(req, res) {
  const row = await loadMediaOrThrow(req.params.id);
  res.json({ item: publicMedia(row) });
}

// Shared file sender with HTTP range support (needed for video/audio seeking).
function sendFile(req, res, filePath, { asAttachment } = {}) {
  let stat;
  try {
    stat = fs.statSync(filePath);
  } catch {
    throw new ApiError(404, 'Media file is missing on the server', 'file_missing');
  }

  const total = stat.size;
  const range = req.headers.range;

  if (asAttachment) {
    res.setHeader('Content-Disposition', `attachment; filename="${path.basename(filePath)}"`);
  }
  res.setHeader('Accept-Ranges', 'bytes');
  res.setHeader('Content-Type', 'application/octet-stream');

  if (range) {
    const match = /bytes=(\d*)-(\d*)/.exec(range);
    const start = match && match[1] ? parseInt(match[1], 10) : 0;
    const end = match && match[2] ? parseInt(match[2], 10) : total - 1;
    if (start >= total || end >= total || start > end) {
      res.status(416).setHeader('Content-Range', `bytes */${total}`);
      return res.end();
    }
    res.status(206);
    res.setHeader('Content-Range', `bytes ${start}-${end}/${total}`);
    res.setHeader('Content-Length', end - start + 1);
    return fs.createReadStream(filePath, { start, end }).pipe(res);
  }

  res.setHeader('Content-Length', total);
  return fs.createReadStream(filePath).pipe(res);
}

// GET /api/media/:id/stream — for in-app playback.
async function streamMedia(req, res) {
  const row = await loadMediaOrThrow(req.params.id);
  const filePath = resolveMediaPath(row.file_key);
  sendFile(req, res, filePath, { asAttachment: false });
}

// GET /api/media/:id/download — returns the raw bytes for the app to encrypt
// and store in its private sandbox. Only allowed when is_downloadable = 1.
async function downloadMedia(req, res) {
  const row = await loadMediaOrThrow(req.params.id);
  if (!row.is_downloadable) {
    throw new ApiError(403, 'This item is not available for download', 'not_downloadable');
  }
  const filePath = resolveMediaPath(row.file_key);
  sendFile(req, res, filePath, { asAttachment: true });
}

module.exports = { listMedia, getMedia, streamMedia, downloadMedia };
