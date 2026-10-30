# GhostWork mobile (Flutter)

Status: **built, with feature parity with the web app** (`mobile/`). Flutter 3.47 / Dart 3.13.
`flutter analyze` is clean and 28 tests pass. Verified against the live API in Chrome through the
web build, including a canvas connection, save and run. **Android and iOS builds have not been run**:
they need the Android SDK and Xcode, which are not installed on the development machine.

## Parity

Every web route exists at the same path with the same query parameters, and redirects follow the
same rules (`lib/router.dart`). Design tokens, type scale and components are ported from
`frontend/src/app/globals.css` and `frontend/src/components/ui`; Geist is bundled in `assets/fonts`.

Intentional platform differences:

- Web tables appear as the card lists the web already uses at phone width. Phones use the same
  side-drawer navigation; tablets and desktops use the icon rail and sidebar.
- On web, "Export" downloads a file. Where no save dialog is available, the app copies the JSON
  to the clipboard.
- On web, sessions use an HttpOnly cookie. The app stores its refresh token in secure storage
  (in memory only in the Flutter web build, so it signs in again after a page reload).
- Dragging from the steps library is available when the canvas is beside it (wide layouts). On
  phones the library opens as a sheet over the canvas, so steps are added by tapping.
- Password reset emails link to the web app, because native deep links aren't configured.

## Authentication

- Send `"client": "mobile"` on login/register: the response includes `refresh_token` in the body
  and no cookie is set.
- Refresh with `POST /api/v1/auth/refresh` and `{"refresh_token": "..."}`. Every refresh returns a
  new token, which is stored immediately. HTTP 409 means a concurrent refresh; retry once.
- Sign out with `POST /api/v1/auth/logout` and `{"refresh_token": "..."}`.

## Structure

- `lib/data/` — `api_client.dart` (bearer auth, single-flight refresh, rotation, friendly errors),
  `models.dart`, `token_store.dart`.
- `lib/state/providers.dart` — Riverpod auth controller and data providers.
- `lib/router.dart` — go_router routes and auth redirects.
- `lib/ui/components/` — design-system components. `lib/ui/canvas/` — Living Workflow canvas and
  timeline. `lib/ui/shell/` — app shell. `lib/ui/screens/` — public, auth and app screens.

## Running

```bash
cd mobile
flutter test && flutter analyze
flutter run -d chrome --web-port 8090 --dart-define=API_BASE_URL=http://localhost:8000
# Android emulator (needs Android Studio): the host machine is 10.0.2.2
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=WEB_APP_URL=http://10.0.2.2:3000
```

## Not built

Push notifications need FCM/APNs setup and a device-token endpoint. The app shows in-app
notifications.
