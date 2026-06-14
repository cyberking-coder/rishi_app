'use strict';

const express = require('express');
const { listMedia, getMedia, streamMedia, downloadMedia } = require('../controllers/mediaController');
const { requireAuth } = require('../middleware/auth');
const { asyncHandler } = require('../utils/http');

const router = express.Router();

// All media access requires a valid, device-locked session.
router.use(requireAuth);

router.get('/', asyncHandler(listMedia));
router.get('/:id', asyncHandler(getMedia));
router.get('/:id/stream', asyncHandler(streamMedia));
router.get('/:id/download', asyncHandler(downloadMedia));

module.exports = router;
