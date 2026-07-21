# Ticketing Mobile (Flutter)

Customer-facing app for the event-ticketing API. Browse events, pick seats on the **live
seat map** (the exact layout arranged in the admin editor), hold seats, and pay.

## Prerequisites

- Flutter SDK 3.3+ (`flutter --version`)
- The event-ticketing backend running (default `http://localhost:8080`)

## First-time setup

This repo contains the app source (`lib/`, `pubspec.yaml`). Generate the platform runners
and fetch packages:

```bash
cd ticketing_mobile
flutter create .          # backfills android/ ios/ etc. (keeps lib/ and pubspec)
flutter pub get
```

## Point it at your backend

Edit `lib/src/config.dart` → `Config.baseUrl`:

| Target | baseUrl |
| --- | --- |
| Android emulator | `http://10.0.2.2:8080` (default) |
| iOS simulator / desktop | `http://localhost:8080` |
| Physical device | `http://<your-machine-LAN-IP>:8080` |

## Run

```bash
flutter run
```

## What it does

- **Events** — `GET /api/events/available`; tap a *seated* event to open its seat map.
- **Seat map** — `GET /api/events/{id}/seats`, redrawn from the stored `layoutX/Y`, size and
  `rotationDegrees` (same coordinate space as the admin editor). Pinch-zoom / pan via
  `InteractiveViewer`. Tap available seats to select; polls every 8s for live status.
- **Hold** — `POST /api/bookings` with the selected `seatIds`.
- **Booking** — expiry countdown, `POST /api/bookings/{id}/payment`, `DELETE /api/bookings/{id}`.
- **My bookings** — `GET /api/bookings` (keyed by a per-install `X-Customer-Ref`).

## Structure

```
lib/
  main.dart                     app entry (initialises Config, shows EventsScreen)
  src/
    config.dart                 base URL + persisted customer ref
    api/api_client.dart         all HTTP calls + error parsing
    models/                     SeatMap/Seat, EventSummary, Booking
    theme/seat_colors.dart      type/status colours (match the admin)
    widgets/
      seat_map_view.dart        the core renderer (InteractiveViewer + rotated tiles)
      countdown.dart            hold-expiry timer
    screens/                    events, seat map, booking, bookings list
```

## Notes

- Seat colours mirror the admin: VIP purple, Premium blue, Regular slate; held = grey,
  sold = dark, selected = amber.
- The backend caches the seat map with a short TTL, so status/type/layout changes can lag a
  few seconds after an admin edit.
