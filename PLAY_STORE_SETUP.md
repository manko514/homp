# Play Store Release Setup

## Step 1 — Generate Signing Keystores

Run these commands once. Keep the .keystore files safe — you can never re-upload to Play Store with a different key.

### Staff App Keystore
```powershell
keytool -genkey -v -keystore homp-staff.keystore -alias homp-staff -keyalg RSA -keysize 2048 -validity 10000
```
Move `homp-staff.keystore` to `apps/staff/android/app/`

### Guest App Keystore
```powershell
keytool -genkey -v -keystore homp-guest.keystore -alias homp-guest -keyalg RSA -keysize 2048 -validity 10000
```
Move `homp-guest.keystore` to `apps/guest/android/app/`

## Step 2 — Create key.properties

### `apps/staff/android/key.properties`
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=homp-staff
storeFile=homp-staff.keystore
```

### `apps/guest/android/key.properties`
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=homp-guest
storeFile=homp-guest.keystore
```

⚠️ Never commit key.properties or .keystore files to Git. Add to .gitignore:
```
android/key.properties
android/app/*.keystore
```

## Step 3 — Build Signed AAB for Play Store

```powershell
# Staff app
cd apps/staff
flutter build appbundle --release --dart-define=API_URL=https://api.yourdomain.com

# Guest app
cd apps/guest
flutter build appbundle --release --dart-define=API_URL=https://api.yourdomain.com
```

AAB files will be at:
- `apps/staff/build/app/outputs/bundle/release/app-release.aab`
- `apps/guest/build/app/outputs/bundle/release/app-release.aab`

## Step 4 — Create Play Store Listings

1. Go to https://play.google.com/console
2. Create two apps:
   - **HOMP Guest** — package: `com.homp.guest`
   - **HOMP Staff** — package: `com.homp.staff`
3. Upload the AAB files to **Internal Testing** track
4. Set up store listing (description, screenshots, icon)

## Step 5 — CI/CD GitHub Actions

The workflow at `.github/workflows/build.yml` auto-builds and deploys on push to `main`.

Add these secrets in GitHub Settings → Secrets:
| Secret | Value |
|--------|-------|
| `API_URL` | `https://api.yourdomain.com` |
| `STAFF_KEYSTORE_BASE64` | `base64 homp-staff.keystore` |
| `STAFF_KEY_ALIAS` | `homp-staff` |
| `STAFF_KEY_STORE_PASSWORD` | your password |
| `STAFF_KEY_PASSWORD` | your key password |
| `GUEST_KEYSTORE_BASE64` | `base64 homp-guest.keystore` |
| `GUEST_KEY_ALIAS` | `homp-guest` |
| `GUEST_KEY_STORE_PASSWORD` | your password |
| `GUEST_KEY_PASSWORD` | your key password |
| `PLAY_STORE_JSON_KEY` | contents of Play Store service account JSON |

To encode keystore for GitHub secret:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("homp-staff.keystore")) | clip
```
