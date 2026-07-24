# 🛒 Fambakare POS & Billing App 

A feature-rich, high-performance offline-first billing and Point of Sale (POS) application built with Flutter. Designed for seamless retail checkout operations featuring barcode scanning, thermal Bluetooth printing, and a **True Offline-First Cloud Sync Architecture**.

## 🚀 Key Features

- **True Offline-First Cloud Sync**
  - Instantaneous data storage using the `Hive` local NoSQL database. No waiting on loading screens.
  - Silent background syncing to Firebase Firestore every 10 minutes.
  - Real-time Firestore Listeners instantly beam changes made on one device to all other devices seamlessly.
  - Manual "Sync Now" override for instant cloud pushes.

- **Role-Based Access Control & Admin Dashboard**
  - **Admin** (Default PIN: `1969`): Access to the dedicated Admin Dashboard containing Sales Analytics, System Settings, Shop Details, and Cloud Sync configurations.
  - **Cashier** (Default PIN: `1234`): Fast barcode scanning and checkout processing.
  - **Staff** (Default PIN: `0000`): Basic inventory checking (Checkout & Settings hidden).
  - PIN codes and Shop Details are synced across the cloud automatically.

- **Fast Barcode Scanning & Checkout**
  - Uses the device camera via `mobile_scanner` with a responsive UI overlay.
  - Automatic cooldown logic prevents rapid duplicate scans.

- **Hardware Integrations**
  - Connects to ESC/POS thermal printers seamlessly via `print_bluetooth_thermal`.
  - Supports digital receipts and physical printing.

- **Sales & End of Day Reporting**
  - Live Sales Analytics dashboard tracking daily revenue and item volume.
  - Send automated EOD sales reports via SMTP Email directly from the app.
  - Discount code engine (e.g., `FAMBAKARE` for 100% discount).

## 🛠 Tech Stack

Built utilizing Clean Architecture & Feature-Driven Design:

- **Framework**: [Flutter](https://flutter.dev/)
- **State Management**: `flutter_bloc`
- **Routing**: `go_router`
- **Local Database**: `hive` & `hive_flutter`
- **Cloud Backend**: `cloud_firestore` & `firebase_core`
- **Data Modeling**: `json_serializable`, `equatable`
- **Functional Programming**: `fpdart`
- **Hardware Integrations**: `mobile_scanner`, `print_bluetooth_thermal`

## 📁 Architecture Overview

The codebase is organized using a **Feature-First Clean Architecture**:

```text
lib/
├── config/                     # Routing and global configurations
├── core/                       # Shared components
│   ├── data/                   # Hive initialization
│   ├── services/               # CloudSyncService for background Firebase syncing
│   ├── utils/                  # PrinterHelper, EmailService, CSVImporter
│   └── theme/                  # UI aesthetics
│
└── features/                   # Independent modules
    ├── auth/                   # PIN login and session state
    ├── billing/                # Home, Scanner, Cart, Checkout, Sales Analytics
    ├── product/                # Inventory management
    ├── settings/               # Sync UI, Admin Controls
    └── shop/                   # Business Information logic
```

## 🚀 Getting Started

### Installation

1. Clone the repository and fetch dependencies:
   ```bash
   git clone <repository_url>
   cd flutter_billing_app
   flutter pub get
   ```

2. Run code generation (required for Hive and JSON serialization):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

3. Run the project:
   ```bash
   flutter run
   ```

*(Note: When running on Chrome/Web in debug mode, the camera scanner may crash on hot-restart. Perform a hard browser refresh (F5) to clear the camera state.)*
