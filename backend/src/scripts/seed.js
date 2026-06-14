'use strict';

// Seeds an admin user + a couple of demo catalog rows so the app has something to show.
// Run AFTER `npm run migrate`. Place matching files in MEDIA_DIR (see file_key values).
const bcrypt = require('bcryptjs');
const { pool } = require('../config/db');

async function main() {
  const adminEmail = 'admin@anuragrishi.app';
  const adminPass = 'admin12345'; // change after first login
  const hash = await bcrypt.hash(adminPass, 12);

  await pool.query(
    `INSERT INTO users (email, display_name, password_hash, role)
     VALUES (:email, 'Administrator', :hash, 'admin')
     ON DUPLICATE KEY UPDATE display_name = display_name`,
    { email: adminEmail, hash }
  );

  await pool.query(
    `INSERT INTO media (title, description, media_type, file_key, duration_secs, is_downloadable)
     VALUES
       ('Welcome Video', 'Intro to Anurag_Rishi', 'video', 'samples/welcome.mp4', 90, 1),
       ('Morning Raag', 'Sample audio track', 'audio', 'samples/morning-raag.mp3', 240, 1)
     ON DUPLICATE KEY UPDATE title = VALUES(title)`
  );

  console.log(`Seeded admin: ${adminEmail} / ${adminPass}`);
  console.log('Remember to drop sample files into MEDIA_DIR/samples/.');
  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
