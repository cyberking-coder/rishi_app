'use strict';

const path = require('path');
const env = require('../config/env');
const { ApiError } = require('./http');

// Resolve a stored file_key to an absolute path INSIDE MEDIA_DIR.
// Throws on any attempt to escape the directory (path traversal).
function resolveMediaPath(fileKey) {
  const base = path.resolve(env.mediaDir);
  const full = path.resolve(base, fileKey);
  if (full !== base && !full.startsWith(base + path.sep)) {
    throw new ApiError(400, 'Invalid media path', 'bad_path');
  }
  return full;
}

module.exports = { resolveMediaPath };
