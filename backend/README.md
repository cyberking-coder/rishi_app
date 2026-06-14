# Anurag_Rishi — Backend API

Node.js + Express + MySQL. Provides authentication, **single-device lock enforcement**,
the media catalog, and auth-checked streaming/download endpoints.

## Setup

```bash
cd backend
cp .env.example .env          # then edit DB creds + JWT_SECRET
npm install
npm run migrate               # creates the database + tables from db/schema.sql
npm run seed                  # optional: admin user + demo catalog rows
npm run dev                   # starts on http://localhost:4000
```

Health check: `GET http://localhost:4000/api/health`

## API

| Method | Path                       | Auth | Notes |
|--------|----------------------------|------|-------|
| POST   | `/api/auth/register`       | no   | `{ email, password, displayName }` |
| POST   | `/api/auth/login`          | no   | `{ email, password, device:{ id, platform, model, osVersion } }` |
| GET    | `/api/auth/me`             | yes  | current user |
| GET    | `/api/media?type=video`    | yes  | catalog list (`type` optional: `video`\|`audio`) |
| GET    | `/api/media/:id`           | yes  | single item |
| GET    | `/api/media/:id/stream`    | yes  | range-enabled streaming for playback |
| GET    | `/api/media/:id/download`  | yes  | raw bytes for the app to encrypt + store in-sandbox |

### Device-lock behaviour

- **First successful login** binds the account to `device.id` (`users.bound_device_id`).
- A login from any **other** device returns **`423 Locked`** (`code: device_locked`).
- Every login attempt is written to `login_audit` with its **IP address** and outcome.
- The device fingerprint + IPs are also tracked per-device in the `devices` table.

### Releasing a device lock (admin)

To move an account to a new phone, clear the binding in MySQL (a self-service
"deregister" endpoint is a natural next step):

```sql
UPDATE users SET bound_device_id = NULL WHERE email = 'someone@example.com';
```

## Media files

Source files live under `MEDIA_DIR` (default `./uploads`). The `media.file_key` column is a
path **relative** to that directory; the server blocks path traversal. Replace the seeded
sample keys with your real uploads (an upload/admin endpoint is a planned follow-up).
