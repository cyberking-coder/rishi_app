# Anurag_Rishi App

A YouTube-style media platform for **videos and audio**, with three defining features:

1. **Secure in-app downloads** — downloaded media is stored *encrypted inside the app's
   private sandbox*. It is never written to the phone's public storage / gallery / file
   manager, so it cannot be opened or shared by any other app.
2. **Single-device login** — each account is bound to the first device it signs in from.
   Attempting to log in from a second device is rejected until an admin (or the user, via a
   future "deregister" flow) releases the lock.
3. **Auth + audit** — email/password sign up & login, with the device fingerprint and the
   login IP address recorded server-side for every session.

## Repository layout

```
backend/   Node.js + Express + MySQL API (auth, device-lock, media catalog, secure download)
app/       Flutter mobile app (Android + iOS) — auth, device binding, player, secure downloads
```

See [`backend/README.md`](backend/README.md) and [`app/README.md`](app/README.md) for setup.

## How the device lock actually works (important)

Reading a phone's **MAC / physical address is blocked by both iOS and Android** on modern
OS versions (iOS forbids it; Android returns a fake constant). So instead of a MAC address,
the app generates a **stable device fingerprint** on first launch:

- A random UUID is created once and stored in the OS **secure keystore** (Android Keystore /
  iOS Keychain), combined with non-resettable hardware/OS info from `device_info_plus`.
- On **first successful login**, the backend stores `(user_id, device_id)` and marks the
  account as device-locked.
- Every subsequent login/app-open sends the same `device_id`. If it doesn't match the bound
  device, the server returns `423 Locked` and the app refuses to open the content.
- The login **IP address** is logged on every request for your security audit trail (IP is
  recorded but *not* used for enforcement, because phone IPs change constantly).

> True copy-protection against screen recording / rooted devices requires commercial DRM
> (Google Widevine / Apple FairPlay). The encrypted-sandbox approach here stops casual
> extraction and file sharing; DRM can be layered on later.

## Status

This is the **MVP foundation**: it is structured to run end-to-end (register → login →
device-lock → browse catalog → stream → secure download). Media transcoding, payments,
push notifications, and DRM are intentionally out of scope for this first cut.
