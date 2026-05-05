# ShopScan Development Guide

## Project Overview
ShopScan is a production-quality mobile POS system built with Flutter and Firebase. The project follows clean architecture principles with modular folder structure and separation of concerns.

## Architecture Principles

### 1. Separation of Concerns
- **Models** (`lib/models/`): Pure data classes with serialization/deserialization
- **Services** (`lib/services/`): Business logic, Firebase operations, external integrations
- **Providers** (`lib/core/utils/`): State management with ChangeNotifier
- **Screens** (`lib/screens/`): UI layout and navigation
- **Widgets** (`lib/widgets/`): Reusable UI components

### 2. Code Organization
```
lib/
├── core/                 # Core utilities and constants
├── models/              # Data models
├── services/            # Business logic & Firebase
├── features/            # Feature-specific modules
├── widgets/             # Reusable components
├── screens/             # Screen implementations
└── main.dart           # App entry point
```

### 3. Naming Conventions
- **Files**: `snake_case` (e.g., `auth_provider.dart`)
- **Classes**: `PascalCase` (e.g., `AuthProvider`)
- **Methods/Variables**: `camelCase` (e.g., `handleSignIn()`)
- **Constants**: `CONSTANT_CASE` in `app_constants.dart` or `camelCase` for theme values

## Development Standards

### State Management
- Use **Provider** package for state management
- Create `*Provider` classes extending `ChangeNotifier`
- Call `notifyListeners()` after state changes
- Use `Consumer<ProviderName>` or `Selector` in widgets for efficient rebuilds

### Firebase Integration
- All Firebase operations go in `Services`
- Use `FirebaseAuth` for authentication
- Use `Cloud Firestore` for database operations
- Implement proper error handling with meaningful error messages
- Use Streams for real-time updates

### Error Handling
```dart
try {
  // Operation
} on SpecificException catch (e) {
  throw Exception('User-friendly message: $e');
} catch (e) {
  throw Exception('Unexpected error: $e');
}
```

### Async Operations
- Always use `async/await` instead of `.then()`
- Handle loading and error states in providers
- Use Streams for real-time data

### Widget Design
- Keep widgets small and focused
- Extract complex widgets into separate methods or classes
- Use meaningful widget names
- Add type safety (avoid using `dynamic`)

## Code Examples

### Creating a Data Model
```dart
class ProductModel {
  final String id;
  final String name;
  // ... fields

  ProductModel({
    required this.id,
    required this.name,
    // ... parameters
  });

  // Serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };

  // Deserialization
  factory ProductModel.fromJson(Map<String, dynamic> json, String docId) {
    return ProductModel(
      id: docId,
      name: json['name'] ?? '',
    );
  }

  // Copy with
  ProductModel copyWith({
    String? id,
    String? name,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
```

### Creating a Service
```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Implementation
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }
}
```

### Creating a Provider
```dart
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signIn(
        email: email,
        password: password,
      );
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
```

### Using Provider in Widget
```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const CircularProgressIndicator();
        }

        return Text(authProvider.currentUser?.name ?? 'Guest');
      },
    );
  }
}
```

## Feature Development Workflow

### 1. Add Data Model
- Create or update model in `lib/models/`
- Implement `toJson()`, `fromJson()`, and `copyWith()`

### 2. Add Service Methods
- Create or update service in `lib/services/`
- Implement Firebase operations
- Add error handling

### 3. Add State Management
- Create or update provider in `lib/core/utils/`
- Implement loading, error, and data states
- Add methods that call service operations

### 4. Build UI
- Create screen in `lib/screens/` or `lib/features/`
- Use `Consumer` to listen to provider changes
- Create reusable widgets in `lib/widgets/`

### 5. Connect Navigation
- Update `main.dart` or navigation logic
- Ensure proper AuthWrapper for role-based navigation

## Database Best Practices

### Firestore Structure
- Use collections for entity types (users, products, transactions)
- Use document IDs as primary keys
- Structure data for efficient queries
- Avoid deeply nested collections

### Security Rules
- Implement role-based access control
- Validate data on write
- Ensure users can only access their own data
- Owners have elevated permissions

## Testing Checklist

Before committing code:
- ✅ No compile errors
- ✅ Code follows naming conventions
- ✅ Error handling implemented
- ✅ Type safety enforced
- ✅ Comments for complex logic
- ✅ No unused imports or variables
- ✅ Responsive on different screen sizes

## Performance Considerations

### Optimization Tips
- Use `const` constructors when possible
- Use `RepaintBoundary` to limit rebuilds
- Use `Selector` instead of `Consumer` when watching specific properties
- Lazy load data with pagination
- Cache frequently accessed data locally

### Real-time Updates
- Use Firestore Streams for live data
- Unsubscribe properly to avoid memory leaks
- Cancel async operations when disposing

## Common Tasks

### Adding a New Screen
1. Create screen file in `lib/screens/`
2. Create provider if needed in `lib/core/utils/`
3. Add navigation to `main.dart`
4. Implement UI based on design

### Fetching Data from Firebase
```dart
// Get single document
Future<ProductModel?> getProduct(String id) async {
  final doc = await _firestore.collection('products').doc(id).get();
  if (doc.exists) {
    return ProductModel.fromJson(doc.data()!, doc.id);
  }
  return null;
}

// Get collection with stream
Stream<List<ProductModel>> getProducts() {
  return _firestore.collection('products').snapshots().map(
    (snapshot) => snapshot.docs
        .map((doc) => ProductModel.fromJson(doc.data(), doc.id))
        .toList(),
  );
}
```

### Handling Authentication State
The `AuthWrapper` in `main.dart` automatically routes based on authentication:
- Not authenticated → LoginScreen
- Authenticated as owner → OwnerDashboardScreen
- Authenticated as cashier → CashierDashboardScreen

### Displaying Errors to Users
```dart
if (provider.error != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(provider.error!),
      backgroundColor: Color(AppColors.error),
    ),
  );
}
```

## Debugging Tips

### Firebase Issues
- Check Firestore rules in Firebase console
- Verify user permissions
- Check Authentication settings
- Review error messages in console

### UI Issues
- Use Flutter DevTools to inspect widget tree
- Check for layout problems with `debugPaintSizeEnabled = true`
- Use `flutter run -v` for verbose output

### State Issues
- Print provider state to console
- Use DevTools to track rebuilds
- Verify notifyListeners() is called

## Useful Commands

```bash
# Get dependencies
flutter pub get

# Run code analysis
flutter analyze

# Format code
dart format lib/

# Run tests
flutter test

# Build APK
flutter build apk --release

# Clean project
flutter clean

# Upgrade Flutter
flutter upgrade
```

## Git Workflow

### Commit Message Format
```
[feature/fix/refactor] Brief description

Detailed explanation of changes
```

### Branch Naming
- `feature/` - New features
- `fix/` - Bug fixes
- `refactor/` - Code refactoring
- `docs/` - Documentation updates

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Dart Language Guide](https://dart.dev/guides/language/language-tour)
- [Provider Package](https://pub.dev/packages/provider)
- [Material Design](https://material.io/design)

## FAQ

**Q: How do I add a new provider?**
A: Create a class extending `ChangeNotifier`, add getter/setter methods, call `notifyListeners()` on changes, and add to `MultiProvider` in `main.dart`.

**Q: How do I fetch real-time data?**
A: Use Firestore Streams in your service, expose via provider as `Stream<T>`, and use `StreamBuilder` or `Selector` in widgets.

**Q: How do I handle authentication?**
A: Use `AuthProvider` to manage login/logout. The `AuthWrapper` automatically handles navigation based on authentication state.

**Q: How do I debug Firebase issues?**
A: Check Firestore security rules, verify authentication status, review error messages in console, and ensure data structure matches models.

---

Last Updated: 2024
Maintained by: Development Team
