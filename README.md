# ShopScan - Mobile POS System

A production-quality mobile Point of Sale (POS) application built with Flutter and Firebase. ShopScan enables small to medium businesses to manage inventory, process transactions, and track sales with barcode scanning capabilities.

## Features

### For Owners
- 📊 Business dashboard with real-time analytics
- 📦 Product and inventory management
- 📈 Sales reports and performance insights
- 👥 Cashier activity monitoring
- ⏱️ Shift tracking and management
- 📤 Report export functionality

### For Cashiers
- 🔍 Barcode scanning with device camera
- 🛒 Quick scan-to-cart transaction system
- 💳 Seamless checkout process
- 🧾 Real-time receipt generation
- 📋 Personal sales history tracking
- ⏰ Shift management (start/end shifts)
- 📊 Daily performance metrics

## Tech Stack

### Frontend
- **Flutter** - Cross-platform mobile development
- **Provider** - State management
- **mobile_scanner** - Barcode scanning
- **flutter_screenutil** - Responsive UI

### Backend
- **Firebase Authentication** - Secure user authentication
- **Cloud Firestore** - Real-time database
- **Firebase Storage** - File storage

### Additional Libraries
- **esc_pos_printer** - Receipt printing
- **go_router** - Navigation
- **intl** - Internationalization
- **shared_preferences** - Local storage

## Project Structure

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart      # App theme, colors, strings
│   ├── theme/
│   │   └── app_theme.dart          # Material theme configuration
│   └── utils/
│       ├── auth_provider.dart      # Authentication state
│       └── cart_provider.dart      # Shopping cart state
├── models/
│   ├── user_model.dart             # User data model
│   ├── product_model.dart          # Product data model
│   ├── transaction_model.dart      # Transaction data model
│   └── shift_model.dart            # Shift data model
├── services/
│   ├── auth_service.dart           # Firebase authentication
│   ├── firestore_service.dart      # Firestore database operations
│   ├── barcode_service.dart        # Barcode scanning
│   └── printer_service.dart        # Receipt printing
├── features/
│   ├── auth/                       # Authentication feature
│   ├── owner/                      # Owner-specific features
│   ├── cashier/                    # Cashier-specific features
│   ├── transactions/               # Transaction management
│   ├── inventory/                  # Inventory management
│   └── reports/                    # Reporting features
├── widgets/                        # Reusable UI components
└── main.dart                       # App entry point
```

## Database Structure

### Users Collection
```
{
  id: string
  name: string
  email: string
  role: "owner" | "cashier"
  photoUrl: string (optional)
  createdAt: timestamp
  isActive: boolean
}
```

### Products Collection
```
{
  id: string
  name: string
  barcode: string
  price: number
  stock: number
  category: string
  imageUrl: string (optional)
  description: string (optional)
  isActive: boolean
  createdAt: timestamp
  updatedAt: timestamp
}
```

### Transactions Collection
```
{
  id: string
  cashierId: string
  items: [{
    productId: string
    productName: string
    price: number
    quantity: number
    sku: string
  }]
  subtotal: number
  tax: number
  discount: number
  total: number
  status: "pending" | "completed" | "cancelled" | "refunded"
  timestamp: timestamp
  notes: string (optional)
}
```

### Shifts Collection
```
{
  id: string
  cashierId: string
  startTime: timestamp
  endTime: timestamp (optional)
  status: "active" | "completed" | "cancelled"
  salesAmount: number
  transactionCount: number
}
```

## Setup Instructions

### Prerequisites
- Flutter SDK (>= 3.0.0)
- Firebase Project
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/shopscan.git
   cd shopscan
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   
   a. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   
   b. Add Android, iOS, and Web apps to your Firebase project
   
   c. Update `lib/firebase_options.dart` with your Firebase credentials:
   ```dart
   static const FirebaseOptions android = FirebaseOptions(
     apiKey: 'YOUR_ANDROID_API_KEY',
     appId: 'YOUR_ANDROID_APP_ID',
     messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
     projectId: 'YOUR_PROJECT_ID',
     storageBucket: 'YOUR_STORAGE_BUCKET',
   );
   ```

4. **Enable Firebase Services**
   - Enable Authentication with Email/Password sign-in
   - Create Firestore Database
   - Set up Firebase Storage

5. **Deploy the repo Firestore rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

### Firebase Hosting

This repo is configured to deploy the Flutter web build to Firebase Hosting.

1. Install the Firebase CLI
  ```bash
  npm install -g firebase-tools
  ```

2. Log in to Firebase
  ```bash
  firebase login
  ```

3. Deploy the web app
  ```bash
  firebase deploy --only hosting
  ```

The Hosting config uses `build/web` as the public directory and automatically runs `flutter build web --release` before deployment.

After the first deploy, Firebase will give you a URL similar to:

```text
https://shopscan-7811e.web.app
```

Before using social login on the deployed site, add the Hosting domain to the Firebase Authentication authorized domains list.

6. **Run the app**
   ```bash
   flutter run
   ```

## Firestore Security Rules

The source of truth for Firestore access control now lives in [firestore.rules](firestore.rules).

Use the repo file when you deploy rules:

```bash
firebase deploy --only firestore:rules
```

The checked-in rules currently match the app's active behavior:

- Owners can read all users and manage cashier records tied to their shop.
- Owners can create and edit their own shop document.
- Owners can read all transactions and shifts.
- Cashiers can read products, create their own transactions, and create or update their own shifts.
- Cashiers can update product stock during checkout, while broader product edits stay available to owners.
- Owners and cashiers can edit only their own profile fields; security-sensitive user fields stay immutable for self-edits.

If you change Firestore access patterns in code, update [firestore.rules](firestore.rules) in the same change and redeploy it.

## Code Architecture Principles

### Separation of Concerns
- **Models**: Pure data classes with serialization
- **Services**: Business logic and external integrations
- **Providers**: State management
- **Screens**: UI and user interaction
- **Widgets**: Reusable components

### Best Practices
- ✅ Type-safe code
- ✅ Error handling with meaningful messages
- ✅ Async/await for async operations
- ✅ Stream-based real-time updates
- ✅ Proper resource disposal
- ✅ Documentation with comments
- ✅ Responsive design with flutter_screenutil

## Navigation

### Owner Flow
```
Login → Owner Dashboard → Products/Reports/Cashiers → Profile
```

### Cashier Flow
```
Login → Cashier Dashboard → Scan/Sales/Stocks → Checkout → Receipt
```

## Development Guidelines

### Adding New Features
1. Create models if needed
2. Add service methods for data operations
3. Create provider for state management
4. Build UI screens
5. Connect with navigation

### Naming Conventions
- Files: `snake_case`
- Classes: `PascalCase`
- Variables/Methods: `camelCase`
- Constants: `CONSTANT_CASE` or `camelCase` in constants file

### Code Style
- Use `final` for variables that don't change
- Add trailing commas for better formatting
- Use meaningful variable names
- Add comments for complex logic

## Testing

```bash
flutter test
```

## Build & Deployment

### Android
```bash
flutter build apk
# or for release
flutter build appbundle
```

### iOS
```bash
flutter build ios
# or for release
flutter build ipa
```

## Troubleshooting

### Firebase Connection Issues
- Verify Firebase credentials in `firebase_options.dart`
- Check Firestore security rules
- Ensure Firebase services are enabled

### Barcode Scanner Not Working
- Verify camera permissions are granted
- Check device camera functionality
- Ensure proper barcode format

### State Management Issues
- Verify all providers are in `MultiProvider`
- Check provider initialization
- Use `Consumer` or `Selector` for efficiency

## Future Enhancements

- 📱 Offline support with local caching
- 🔔 Real-time notifications
- 💬 Customer feedback system
- 📞 SMS/Email receipts
- 🌐 Multi-language support
- 🎯 Advanced analytics and insights
- 🔐 Biometric authentication
- 🌙 Dark mode support
- 💰 Multiple payment methods
- 📦 Supplier management

## License

This project is proprietary software. Unauthorized copying or distribution is prohibited.

## Support

For issues or questions, please contact the development team.

---

Built with ❤️ for modern retail businesses.
