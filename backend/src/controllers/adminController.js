'use strict';

const fs = require('fs');
const path = require('path');
const { pool } = require('../config/db');
const env = require('../config/env');
const { ApiError } = require('../utils/http');
const { resolveMediaPath } = require('../utils/mediaPath');

function adminMedia(row) {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    mediaType: row.media_type,
    fileKey: row.file_key,
    thumbnailUrl: row.thumbnail_url,
    durationSecs: row.duration_secs,
    isDownloadable: !!row.is_downloadable,
    isPublished: !!row.is_published,
    createdAt: row.created_at,
  };
}

// GET /api/admin/media — full catalog incl. unpublished.
async function listAll(req, res) {
  const [rows] = await pool.query('SELECT * FROM media ORDER BY created_at DESC');
  res.json({ items: rows.map(adminMedia) });
}

// POST /api/admin/media — multipart upload.
// Fields: title, description?, mediaType (video|audio), isDownloadable?, durationSecs?
// Files:  file (required, the media), thumbnail (optional image)
async function uploadMedia(req, res) {
  const { title, description, mediaType, isDownloadable, durationSecs } = req.body || {};
  const mediaFile = req.files?.file?.[0];
  const thumbFile = req.files?.thumbnail?.[0];

  if (!title || !mediaType || !mediaFile) {
    if (mediaFile) await fs.promises.unlink(mediaFile.path).catch(() => {});
    if (thumbFile) await fs.promises.unlink(thumbFile.path).catch(() => {});
    throw new ApiError(400, 'title, mediaType and a media file are required', 'validation');
  }
  if (mediaType !== 'video' && mediaType !== 'audio') {
    throw new ApiError(400, 'mediaType must be "video" or "audio"', 'validation');
  }

  // multer stored files under MEDIA_DIR already; file_key is the name relative to it.
  const fileKey = path.relative(path.resolve(env.mediaDir), mediaFile.path);
  const thumbnailUrl = thumbFile
    ? `/thumbnails/${path.basename(thumbFile.path)}`
    : null;

  const [result] = await pool.query(
    `INSERT INTO media (title, description, media_type, file_key, thumbnail_url, duration_secs, is_downloadable, is_published)
     VALUES (:title, :description, :mediaType, :fileKey, :thumbnailUrl, :durationSecs, :isDownloadable, 1)`,
    {
      title: String(title).trim(),
      description: description ? String(description) : null,
      mediaType,
      fileKey,
      thumbnailUrl,
      durationSecs: durationSecs ? parseInt(durationSecs, 10) : null,
      isDownloadable: isDownloadable === 'false' || isDownloadable === false ? 0 : 1,
    }
  );
  const [rows] = await pool.query('SELECT * FROM media WHERE id = :id', { id: result.insertId });
  res.status(201).json({ item: adminMedia(rows[0]) });
}

// PATCH /api/admin/media/:id — edit metadata / publish state.
async function updateMedia(req, res) {
  const id = req.params.id;
  const fields = [];
  const params = { id };
  const allowed = {
    title: 'title',
    description: 'description',
    isDownloadable: 'is_downloadable',
    isPublished: 'is_published',
    durationSecs: 'duration_secs',
  };
  for (const [key, col] of Object.entries(allowed)) {
    if (req.body[key] !== undefined) {
      fields.push(`${col} = :${key}`);
      params[key] = typeof req.body[key] === 'boolean'
        ? (req.body[key] ? 1 : 0)
        : req.body[key];
    }
  }
  if (fields.length === 0) throw new ApiError(400, 'No updatable fields provided', 'validation');

  const [result] = await pool.query(
    `UPDATE media SET ${fields.join(', ')} WHERE id = :id`,
    params
  );
  if (result.affectedRows === 0) throw new ApiError(404, 'Media not found', 'not_found');
  const [rows] = await pool.query('SELECT * FROM media WHERE id = :id', { id });
  res.json({ item: adminMedia(rows[0]) });
}

// DELETE /api/admin/media/:id — remove row + underlying file.
async function deleteMedia(req, res) {
  const id = req.params.id;
  const [rows] = await pool.query('SELECT * FROM media WHERE id = :id', { id });
  const row = rows[0];
  if (!row) throw new ApiError(404, 'Media not found', 'not_found');

  await pool.query('DELETE FROM media WHERE id = :id', { id });

  // Best-effort file cleanup (don't fail the request if the file is already gone).
  try {
    await fs.promises.unlink(resolveMediaPath(row.file_key));
  } catch (_) {/* ignore */}

  res.json({ ok: true });
}

module.exports = { listAll, uploadMedia, updateMedia, deleteMedia };
