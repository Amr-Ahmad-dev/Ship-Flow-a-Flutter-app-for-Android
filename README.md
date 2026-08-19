# ShopFlow

ShopFlow is a Firebase-backed commerce demo built around two cooperating subsystems:

- System A manages buyer profiles, cart persistence, order history, and recommendation signals.
- System B manages sellers, inventory, seller sales records, and prerequisite file reviews.

The Flutter application sits on top of those two systems through a single orchestration layer (`ApiService`). This refactor keeps the original Firebase-centered architecture intact while making the codebase easier to follow, safer to extend, and more useful for both buyers and sellers.

## What Changed

- Refactored the Flutter service layer into clearer responsibilities with typed models and safer helper methods.
- Preserved Firebase Auth, Cloud Firestore, and the existing subsystem separation.
- Fixed the old approval flow so accepted items are added to the correct buyer cart instead of the seller's local cart.
- Added prerequisite file upload support for restricted products using Firebase Storage.
- Added seller-side submission review with accept/reject actions and buyer-safe privacy rules.
- Expanded seller analytics so each seller can see:
  - all of their products
  - total sold quantity per product
  - seller-safe order lines per product
  - pending prerequisite submissions
- Upgraded the buyer experience:
  - clearer product detail screens
  - file review status tracking
  - cart items that show attached approved files
  - order history that keeps approved file context
- Improved the visual system with a shared theme, better sectioning, and clearer hover/pressed feedback.

## Project Structure

### Flutter App

`flutter_app/lib/main.dart`

- App entry point
- Initializes Firebase
- Registers routes
- Applies the shared theme

`flutter_app/lib/services/service.dart`

- Main orchestration layer
- Handles auth state, cart state, recommendations, checkout, seller analytics, and submission workflows
- This is the only service the UI should talk to directly

`flutter_app/lib/services/a.dart`

- System A business logic
- Buyer registry profile creation
- Cart persistence
- Order record creation
- Buyer activity tracking

`flutter_app/lib/services/b.dart`

- System B business logic
- Seller accounts
- Products and inventory
- Seller-safe sales logs
- Prerequisite submission review records

`flutter_app/lib/services/submission_upload_service.dart`

- Buyer file picker and Firebase Storage upload logic

`flutter_app/lib/models/`

- Stronger typed models for products, cart items, orders, prerequisite submissions, and seller dashboard summaries

`flutter_app/lib/widgets/shopflow_components.dart`

- Shared UI building blocks used across screens

`flutter_app/lib/theme/app_theme.dart`

- Shared theme configuration for buttons, cards, inputs, chips, and feedback states

### Backends

The repository also contains two backend folders:

- `backend/inventory_system`
- `backend/sales_api`

The Flutter app in this project currently relies on Firebase directly for the core flows that were refactored here, so those backend folders were preserved rather than reworked.

## Core Features

### Buyer Features

- Register and sign in with Firebase Auth
- Browse products with tag filters and search
- View product details, ratings, and stock visibility
- Add normal products directly to cart
- Upload prerequisite files for restricted products
- Track submission status: pending, accepted, or rejected
- Receive clear rejection messages from sellers
- Checkout and store order history in System A
- See approved file attachments carried into cart and order history

### Seller Features

- Create products
- Add stock to existing products
- Review pending prerequisite submissions
- Accept or reject uploaded files
- View all owned products
- See total sold quantity per product
- See seller-safe order lines with:
  - order ID
  - purchased quantity
  - total price
- Track revenue, order volume, and pending review count

## Privacy Rules in the Seller Dashboard

The seller dashboard intentionally does not display buyer identity.

Visible to sellers:

- product name
- order ID
- quantity purchased
- total price
- uploaded file metadata and file link for review

Hidden from sellers:

- buyer name
- buyer account ID in the UI

The underlying workflow still stores the buyer ID internally so the system can attach approved items to the correct buyer cart.

## Setup

### Requirements

- Flutter SDK
- Firebase project configured for:
  - Authentication
  - Cloud Firestore
  - Firebase Storage
- Android or emulator setup if running on mobile

### Flutter Dependencies

The refactored mobile app now uses these core packages:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`
- `provider`
- `file_picker`
- `url_launcher`
- `intl`

### Install

From `flutter_app/`:

```bash
flutter pub get
```

### Run

From `flutter_app/`:

```bash
flutter run
```

## Firestore and Storage Expectations

### Firestore Collections

System A:

- `system_a_users`
- `system_a_orders`

System B:

- `system_b_sellers`
- `system_b_products`
- `system_b_sales`
- `system_b_prerequisite_submissions`

### Storage Paths

Prerequisite uploads are stored under:

`prerequisite_uploads/<buyerId>/<productId>/...`

## Buyer Workflow

### Standard Product

1. Buyer browses catalog.
2. Buyer opens product detail.
3. Buyer adds product to cart.
4. Buyer checks out.
5. Order is stored in System A and seller-safe sales are logged in System B.

### Product Requiring Approval

1. Buyer opens a restricted product.
2. Buyer uploads a prerequisite file.
3. Seller reviews the file in the seller dashboard.
4. If accepted:
   - the approved file is attached to the buyer cart item
   - the product can proceed through checkout
5. If rejected:
   - the buyer sees the rejection message
   - the buyer can upload a replacement file

## Seller Workflow

1. Seller signs in and opens the seller dashboard.
2. Seller adds products or increases stock.
3. Seller reviews uploaded prerequisite files.
4. Seller accepts or rejects each submission.
5. Seller monitors:
   - per-product sold quantity
   - seller-safe order lines
   - revenue summary
   - pending review queue

## Internal API Guide

### `ApiService`

Role:

- Single application-facing API for the UI
- Coordinates Firebase Auth, System A, System B, and file upload workflows

Key functions:

- `register()` creates user and subsystem profiles
- `login()` authenticates and restores the correct role state
- `getProducts()` returns catalog items with cart-aware stock visibility
- `submitProductPrerequisite()` uploads a file and creates a submission record
- `reviewPrerequisiteSubmission()` lets sellers approve or reject a file
- `createOrder()` reserves stock, creates the buyer order, and logs seller-safe sales
- `getSellerDashboardSummary()` returns seller metrics, product performance, and pending submissions

### `SystemA`

Role:

- Buyer-owned persistence

Key functions:

- `createBuyerAccount()`
- `persistCartState()`
- `appendApprovedItemToBuyerCart()`
- `finalizeOrderRecord()`
- `trackTagInterest()`

### `SystemB`

Role:

- Seller-owned inventory and review workflows

Key functions:

- `addProduct()`
- `reserveInventoryForOrder()`
- `createPrerequisiteSubmission()`
- `resolvePrerequisiteSubmission()`
- `logExternalSale()`
- `getProductsForSeller()`
- `getSalesForSeller()`

## Notes for Future Developers

- Keep UI code talking to `ApiService`, not directly to System A or System B.
- Preserve the dual-system separation unless there is a very strong reason to merge behavior.
- Keep seller analytics buyer-safe.
- If you expand file uploads further, prefer continuing with Firebase Storage rather than storing file payloads in Firestore.
- The destructive "delete all data" action is still present for development/testing and should be removed or protected before production use.
