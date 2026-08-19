ShopFlow
<p align="center"> <strong>A Firebase-backed commerce application built with Flutter, designed around two cooperating business subsystems.</strong> </p> <p align="center"> Buyer Management • Seller Management • Inventory • Orders • File Reviews • Analytics </p> <p align="center"> <img src="https://img.shields.io/badge/Flutter-Mobile%20App-02569B?logo=flutter&logoColor=white" alt="Flutter"> <img src="https://img.shields.io/badge/Dart-Programming-0175C2?logo=dart&logoColor=white" alt="Dart"> <img src="https://img.shields.io/badge/Firebase-Backend-FFCA28?logo=firebase&logoColor=black" alt="Firebase"> <img src="https://img.shields.io/badge/Firestore-Database-FFCA28?logo=firebase&logoColor=black" alt="Cloud Firestore"> <img src="https://img.shields.io/badge/Firebase%20Auth-Authentication-FFCA28?logo=firebase&logoColor=black" alt="Firebase Authentication"> <img src="https://img.shields.io/badge/Firebase%20Storage-File%20Storage-FFCA28?logo=firebase&logoColor=black" alt="Firebase Storage"> </p>
Overview

ShopFlow is a commerce application built with Flutter and Firebase, designed around two cooperating business subsystems.

The application separates buyer-oriented and seller-oriented responsibilities while allowing both sides to participate in the same commerce workflows.

                         Flutter Application
                                │
                                ▼
                         ┌─────────────┐
                         │ ApiService  │
                         │ Orchestrator│
                         └──────┬──────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
                    ▼                       ▼
             ┌──────────────┐       ┌──────────────┐
             │   System A   │       │   System B   │
             │              │       │              │
             │ Buyer Data   │       │ Seller Data  │
             │ Cart         │       │ Products     │
             │ Orders       │       │ Inventory    │
             │ Activity     │       │ Sales        │
             │ Signals      │       │ Reviews      │
             └──────────────┘       └──────────────┘
System A — Buyer Domain

System A manages buyer-oriented functionality:

Buyer profiles
Cart persistence
Order history
Buyer activity
Recommendation signals
System B — Seller Domain

System B manages seller-oriented functionality:

Seller accounts
Products
Inventory
Seller sales records
Prerequisite submissions
Seller analytics

The Flutter application communicates with both subsystems through a single orchestration layer, ApiService, keeping the UI independent from the internal implementation of each subsystem.

Core Features
Buyer Features
Register and sign in with Firebase Authentication
Browse products
Search products
Filter products by tags
View product details
View ratings and stock visibility
Add standard products directly to the cart
Upload prerequisite files for restricted products
Track prerequisite submission status
Receive rejection messages
Replace rejected prerequisite files
Checkout
View order history
Retain approved file context through cart and order history
Seller Features
Create products
Add stock to existing products
Review prerequisite submissions
Accept or reject uploaded files
View owned products
View total sold quantity per product
View seller-safe order lines
Track revenue
Track order volume
Track pending prerequisite reviews
Architecture

ShopFlow uses a two-subsystem structure coordinated through ApiService.

                         Flutter UI
                             │
                             ▼
                      ┌─────────────┐
                      │ ApiService  │
                      └──────┬──────┘
                             │
                  ┌──────────┴──────────┐
                  │                     │
                  ▼                     ▼
             ┌──────────┐          ┌──────────┐
             │ System A │          │ System B │
             │  Buyer   │          │  Seller  │
             │  Domain  │          │  Domain  │
             └────┬─────┘          └────┬─────┘
                  │                     │
                  └──────────┬──────────┘
                             ▼
                          Firebase

The separation allows each subsystem to maintain its own responsibilities while the orchestration layer coordinates workflows that involve both sides.

ApiService

ApiService is the main application-facing service layer.

The UI communicates with ApiService rather than directly accessing System A or System B.

It coordinates:

Authentication
Authentication state
Cart operations
Product access
Recommendation signals
Checkout
Seller analytics
Prerequisite submissions
File uploads
Key Functions
Function	Responsibility
register()	Creates the user and required subsystem profiles
login()	Authenticates the user and restores the correct role state
getProducts()	Retrieves catalog products with cart-aware stock visibility
submitProductPrerequisite()	Uploads a prerequisite file and creates a submission
reviewPrerequisiteSubmission()	Allows sellers to approve or reject submissions
createOrder()	Coordinates inventory, buyer orders, and seller-safe sales
getSellerDashboardSummary()	Returns seller metrics, product performance, and pending submissions
System A

flutter_app/lib/services/a.dart

System A is responsible for buyer-owned persistence and business logic.

Responsibilities
Buyer profile creation
Cart persistence
Buyer order records
Buyer activity tracking
Recommendation signals
Key Functions
createBuyerAccount()
persistCartState()
appendApprovedItemToBuyerCart()
finalizeOrderRecord()
trackTagInterest()
System B

flutter_app/lib/services/b.dart

System B is responsible for seller-owned operations.

Responsibilities
Seller accounts
Product management
Inventory management
Seller-safe sales records
Prerequisite review workflows
Seller analytics
Key Functions
addProduct()
reserveInventoryForOrder()
createPrerequisiteSubmission()
resolvePrerequisiteSubmission()
logExternalSale()
getProductsForSeller()
getSalesForSeller()
Product Prerequisite Workflow

Some products require a prerequisite file before purchase.

The workflow is explicitly represented through review states:

Buyer
  │
  │ Upload prerequisite
  ▼
┌─────────┐
│ Pending │
└────┬────┘
     │
     │ Seller review
     ▼
 ┌───┴────┐
 ▼        ▼
Accept   Reject
 │        │
 ▼        ▼
Cart    Replacement
 │
 ▼
Checkout

A rejected submission can be replaced by the buyer.

An accepted submission is associated with the correct buyer and can proceed through the purchasing workflow.

Checkout

Checkout coordinates operations across both subsystems.

For a standard product:

Buyer
  │
  ▼
Cart
  │
  ▼
Checkout
  │
  ├──────────────► System A
  │                 Create order
  │
  └──────────────► System B
                    Reserve inventory
                    Record seller-safe sale

The UI does not need to coordinate these operations itself. ApiService manages the workflow between the two subsystems.

Privacy

Seller analytics intentionally avoid exposing buyer identity through the seller-facing interface.

Visible to Sellers
Product name
Order ID
Purchased quantity
Total price
Uploaded file metadata
File link required for review
Hidden from Sellers
Buyer name
Buyer account ID in the seller-facing UI

The buyer ID can still be stored internally when necessary to associate an approved item with the correct buyer.

This creates an important distinction between data required internally for correctness and data that should be exposed to another user.

Buyer Workflow
Standard Product
Browse the catalog.
Open a product.
Add the product to the cart.
Checkout.
Create the buyer order.
Reserve inventory.
Record the seller-safe sale.
Restricted Product
Open a restricted product.
Upload the prerequisite file.
Create a pending submission.
Seller reviews the submission.
If accepted, the approved file is associated with the buyer's cart item.
Buyer proceeds to checkout.
If rejected, the buyer receives the rejection state and can submit a replacement.
Seller Workflow
Seller signs in.
Seller opens the dashboard.
Seller creates products or adds inventory.
Seller reviews pending prerequisite submissions.
Seller accepts or rejects submissions.
Seller monitors product performance and sales.

The dashboard provides:

Product inventory
Sold quantity per product
Revenue
Order information
Pending prerequisite reviews
Firebase

ShopFlow uses Firebase for its core backend infrastructure.

Firebase Authentication

Used for:

Registration
Sign-in
Authentication state
Cloud Firestore

Used for persistent application data, including:

Users
Products
Orders
Sales
Prerequisite submissions
Application state
Firebase Storage

Used for prerequisite file uploads.

The file itself is stored in Firebase Storage while its metadata and workflow state are maintained through Firestore.

Firestore Structure
System A
system_a_users
system_a_orders
System B
system_b_sellers
system_b_products
system_b_sales
system_b_prerequisite_submissions
Storage Structure

Prerequisite files are stored using the buyer and product as part of the storage path:

prerequisite_uploads/
└── <buyerId>/
    └── <productId>/
        └── ...
Project Structure
ShopFlow/
│
├── flutter_app/
│   ├── lib/
│   │   ├── main.dart
│   │   │
│   │   ├── models/
│   │   │   ├── ...
│   │   │
│   │   ├── services/
│   │   │   ├── service.dart
│   │   │   ├── a.dart
│   │   │   ├── b.dart
│   │   │   └── submission_upload_service.dart
│   │   │
│   │   ├── widgets/
│   │   │   └── shopflow_components.dart
│   │   │
│   │   └── theme/
│   │       └── app_theme.dart
│   │
│   └── ...
│
├── backend/
│   ├── inventory_system/
│   └── sales_api/
│
└── README.md
Supporting Components
main.dart

Responsible for:

Application entry point
Firebase initialization
Route registration
Shared theme configuration
SubmissionUploadService

Responsible for:

File selection
Firebase Storage uploads
Connecting uploaded files with prerequisite submissions
models/

Contains typed models for:

Products
Cart items
Orders
Prerequisite submissions
Seller dashboard summaries
shopflow_components.dart

Contains reusable UI components shared across screens.

app_theme.dart

Defines the shared visual system for:

Buttons
Cards
Inputs
Chips
Feedback states
Interaction states
Refactoring

The current version improves the original implementation while preserving its Firebase-centered architecture.

Service Layer

The Flutter service layer was reorganized into clearer responsibilities while retaining a single application-facing orchestration point.

Typed Models

Important application entities were represented using typed models to make data flow clearer and safer to extend.

Approval Flow

The previous approval flow could incorrectly add an approved item to the seller's local cart.

This was corrected so that the approved item is added to the correct buyer's cart.

Seller approves
      │
      ▼
Identify buyer
      │
      ▼
Update buyer cart
File Uploads

Restricted products now support prerequisite file uploads using Firebase Storage.

Seller Analytics

The seller dashboard was expanded to provide:

All owned products
Total sold quantity per product
Seller-safe order lines
Revenue information
Pending review count
User Interface

The visual system was improved through:

Shared theme configuration
Reusable components
Clearer sectioning
Improved visual hierarchy
Better hover and pressed states
More consistent feedback
Technology Stack
Technology	Purpose
Flutter	Cross-platform application interface
Dart	Application programming language
Firebase Authentication	Authentication and account management
Cloud Firestore	Persistent application data
Firebase Storage	File storage
Provider	State management
File Picker	Prerequisite file selection
URL Launcher	Opening stored file links
Intl	Date and formatting utilities
Engineering Concepts
Multi-system architecture
Service-layer orchestration
Typed models
Authentication
State management
Inventory management
Order processing
File upload workflows
Approval workflows
Privacy-aware data presentation
Seller analytics
Persistent application state
Reusable UI components
Shared design systems
Backend Folders

The repository also contains:

backend/inventory_system
backend/sales_api

These folders are preserved as part of the project's existing architecture.

The current refactored Flutter application relies directly on Firebase for the core flows described in this README, so the backend folders have not been reworked as part of this refactor.

Setup
Requirements
Flutter SDK
Firebase project
Firebase Authentication configured
Cloud Firestore configured
Firebase Storage configured
Android device or emulator if running on Android
Install Dependencies

From the Flutter application directory:

cd flutter_app
flutter pub get
Run
flutter run
Firestore & Storage Requirements

Before running the application, configure the required Firebase services and ensure the expected collections are available.

Firestore
system_a_users
system_a_orders


system_b_sellers
system_b_products
system_b_sales
system_b_prerequisite_submissions
Storage
prerequisite_uploads/<buyerId>/<productId>/...
Development Status

ShopFlow is currently a development/demo application rather than a production commerce platform.

The core buyer and seller workflows are implemented, but additional work would be required before production deployment.

Current Development Considerations
Automated test coverage can be expanded.
Firebase security rules should receive a complete production review.
Checkout failure and recovery scenarios can be strengthened.
Inventory concurrency handling can be improved.
File validation can be made more robust.
Error handling can be expanded.
The development-only destructive data operation should be removed or protected before production deployment.
Future Improvements

Potential future improvements include:

Expanded automated testing
Stronger Firebase security rules
More robust inventory concurrency handling
Improved checkout recovery
Richer seller analytics
Expanded recommendation signals
More advanced product discovery
Stronger prerequisite file validation
Improved error handling and user feedback
Production deployment configuration
What I Learned

ShopFlow provided practical experience with building an application where multiple business responsibilities must coexist without making the UI responsible for the entire system.

The project required working with:

Flutter application architecture
Dart
Firebase Authentication
Cloud Firestore
Firebase Storage
State management
Typed data models
Inventory management
Order processing
File-based approval workflows
Seller analytics
Privacy-aware data exposure
Cross-system coordination
UI component reuse

One of the main architectural lessons was that separating responsibilities is only useful if the boundaries can still cooperate safely.

ShopFlow therefore uses ApiService as the orchestration point between the Flutter interface and the two business subsystems.

Contact

Amr Ahmad
Computer Science Student

Email: amrahmadsalah@gmail.com

GitHub: Amr-Ahmad-dev

<p align="center"> <strong>Flutter • Dart • Firebase • Firestore • Authentication • Storage • Application Architecture</strong> </p>
