# Firebase Push Notifications Setup

## Step 1 — Create Firebase Project

1. Go to https://console.firebase.google.com
2. Click **Add project** → name it `HOMP`
3. Disable Google Analytics (optional) → **Create project**

## Step 2 — Register Android Apps

### Staff App
1. In Firebase console → **Add app** → Android
2. Package name: `com.homp.staff`
3. App nickname: `HOMP Staff`
4. Download `google-services.json`
5. Place it at: `apps/staff/android/app/google-services.json`

### Guest App
1. **Add app** → Android again
2. Package name: `com.homp.guest`
3. App nickname: `HOMP Guest`
4. Download `google-services.json`
5. Place it at: `apps/guest/android/app/google-services.json`

## Step 3 — Add Google Services Gradle Plugin

### Staff app — `apps/staff/android/build.gradle.kts`
Add to the `plugins` block:
```kotlin
id("com.google.gms.google-services") version "4.4.2" apply false
```

### Staff app — `apps/staff/android/app/build.gradle.kts`
Add to the `plugins` block:
```kotlin
id("com.google.gms.google-services")
```

Repeat the same for the guest app.

## Step 4 — Add Flutter Firebase Packages

In `apps/staff/pubspec.yaml` and `apps/guest/pubspec.yaml`, uncomment:
```yaml
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
```

Then run `flutter pub get` in each app folder.

## Step 5 — Initialize Firebase in Flutter

In `apps/staff/lib/main.dart`:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const StaffApp());
}
```

In `apps/staff/lib/screens/shell_screen.dart` initState:
```dart
FcmService.init().catchError((_) {});
```

The `FcmService` at `apps/staff/lib/services/fcm_service.dart` is already written.

## Step 6 — Backend Firebase Credentials

1. In Firebase console → **Project Settings** → **Service accounts**
2. Click **Generate new private key** → download JSON
3. Save it as `apps/api/firebase-service-account.json`
4. Add to `apps/api/.env`:
```
FCM_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
```

Restart the API (`npm run dev`). You'll see:
```
[NotificationService] Firebase Admin initialized ✅
```

## How Notifications Work

| Event | Who gets notified |
|-------|------------------|
| Order status → READY | All WAITERs (via FCM) |
| Staff saves FCM token | Stored in DB on login |

The backend `NotificationService` is already wired into the restaurant order flow.
