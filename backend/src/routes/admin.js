'use strict';

const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const env = require('../config/env');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { asyncHandler } = require('../utils/http');
const { listAll, uploadMedia, updateMedia, deleteMedia } = require('../controllers/adminController');

const mediaRoot = path.resolve(env.mediaDir);
const thumbDir = path.join(mediaRoot, 'thumbnails');
fs.mkdirSync(thumbDir, { recursive: true });

// Media files land in MEDIA_DIR root (served only via auth-checked endpoints);
// thumbnails land in MEDIA_DIR/thumbnails (served statically as public images).
const storage = multer.diskStorage({
  destination: (req, file, cb) =>
    cb(null, file.fieldname === 'thumbnail' ? thumbDir : mediaRoot),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '';
    cb(null, `${uuidv4()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 2 * 1024 * 1024 * 1024 }, // 2 GB
});

const router = express.Router();

router.use(requireAuth, requireAdmin);

router.get('/media', asyncHandler(listAll));
router.post(
  '/media',
  upload.fields([
    { name: 'file', maxCount: 1 },
    { name: 'thumbnail', maxCount: 1 },
  ]),
  asyncHandler(uploadMedia)
);
router.patch('/media/:id', asyncHandler(updateMedia));
router.delete('/media/:id', asyncHandler(deleteMedia));

module.exports = router;
