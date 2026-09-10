# ShopFlow

ShopFlow is a Flutter (Android) marketplace app backed by Firebase. Buyers browse a
shared catalogue, upload prerequisite files for restricted products, and check out;
sellers publish inventory, review submissions, and track sales.

## Architecture

The app is built around two independent subsystems that never write into each
other's data:

| Subsystem | Owns | Firestore collections |
| --- | --- | --- |
| **System A** (`lib/services/system_a.dart`) | Buyer profiles, carts, orders, interest tags | `system_a_users`, `system_a_orders` |
| **System B** (`lib/services/system_b.dart`) | Sellers, products/stock, sales, prerequisite submissions | `system_b_sellers`, `system_b_products`, `system_b_sales`, `system_b_prerequisite_submissions` |

System A never mutates inventory directly. It reads catalogue data only through
System B's `api*` interface, and stock reductions are executed by System B inside a
Firestore transaction. `ApiService` (`lib/services/api_service.dart`) is the single
orchestration layer the UI talks to; it holds auth state, cart state, and coordinates
the A ↔ B hand-off.

```
UI (screens)  ->  ApiService  ->  System A  ->  [interface]  ->  System B  ->  Firestore
```

## Features

- Email/password auth with Firebase Auth; a user can be a buyer, a seller, or both
  (sellers get a buyer profile automatically and can switch roles in the app).
- Catalogue with search, tag filtering, and interest-weighted recommendations.
- Server-persisted cart, stock-aware add-to-cart, transactional checkout, order history.
- Ratings limited to products the buyer actually purchased.
- Prerequisite workflow: buyers upload a file to Firebase Storage for restricted
  products, sellers accept or reject with a message.
- Seller dashboard: products, stock top-ups, revenue, units sold, per-product order
  lines (buyer identity intentionally hidden) and pending submissions.

## Project layout

```
flutter_app/lib
├── main.dart                 app entry, theme, routes
├── models/                   Product, CartItem, AppOrder, AppTag, submissions, seller summary
├── screens/                  splash, login, register, home, products, detail, cart, seller dashboard
├── services/
│   ├── api_service.dart      orchestration layer used by the UI
│   ├── system_a.dart         buyer subsystem
│   ├── system_b.dart         seller/inventory subsystem + interface for System A
│   └── submission_upload_service.dart
├── theme/app_theme.dart      shared Material 3 theme
├── utils/constants.dart      colors and currency
└── widgets/                  shared UI building blocks

backend/                      Firebase project configuration (deployed with the Firebase CLI)
├── firebase.json             points at the rules/index files below
├── firestore.rules           access control for the six collections the app uses
├── firestore.indexes.json    the two composite indexes the app's queries need
└── storage.rules             prerequisite-document upload/read permissions
```

There is no separate API server: the Flutter client is a direct Firebase client.
The `backend/` folder is the whole server side — security rules and indexes that
Firebase enforces on every read and write.

## Running it

1. Install Flutter 3.x (Dart SDK >= 3.1).
2. Create a Firebase project with Auth (Email/Password), Firestore, and Storage enabled.
3. Drop your `google-services.json` into `flutter_app/android/app/`.
4. `cd flutter_app && flutter pub get && flutter run`
5. Deploy the backend rules once: `cd backend && firebase deploy --only firestore,storage`

## Notes

- Collections in use: `system_a_users`, `system_a_orders`, `system_b_products`,
  `system_b_sellers`, `system_b_sales`, `system_b_prerequisite_submissions`.
  Sales records carry `buyerId` so rules can scope them to the owner.
- `ApiService.deleteAllData()` wipes every collection and the current account. It is a
  development-only utility exposed from the login screen.
