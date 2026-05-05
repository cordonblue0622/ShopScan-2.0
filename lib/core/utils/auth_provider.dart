import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isOwner => _currentUser?.role == UserRole.owner;
  bool get isCashier => _currentUser?.role == UserRole.cashier;

  AuthProvider() {
    _initializeAuthState();
  }

  // Initialize auth state listener
  void _initializeAuthState() {
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        // Skip if signIn already set the current user for this uid
        if (_currentUser?.id == firebaseUser.uid) {
          return;
        }

        // Only load from Firestore if signIn hasn't already set the user
        // (e.g. on app restart with persisted auth session)
        if (!_isLoading) {
          await loadCurrentUser(firebaseUser.uid);
        }
      } else {
        // User is logged out
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  // Sign up with shop
  Future<bool> signUpWithShop({
    required String email,
    required String password,
    required String ownerName,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    required UserRole role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signUpWithShop(
        email: email,
        password: password,
        ownerName: ownerName,
        shopName: shopName,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
        role: role,
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

  // Sign in
  Future<bool> signIn({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signIn(
        email: email,
        password: password,
        expectedRole: expectedRole,
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

  // Sign in with Google
  Future<bool> signInWithGoogle({
    required UserRole role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle(role: role);

      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Google sign-in was cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign in with Facebook
  Future<bool> signInWithFacebook({
    required UserRole role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithFacebook(role: role);

      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Facebook sign-in was cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email);
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

  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _currentUser = null;
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load current user
  Future<void> loadCurrentUser(String userId) async {
    try {
      final user = await _authService.getUserById(userId);
      if (user != null && !user.isActive) {
        await _authService.signOut();
        _currentUser = null;
        _error =
            'This staff account has been deactivated. Please contact the shop owner.';
        notifyListeners();
        return;
      }

      _currentUser = user;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    required String userId,
    String? name,
    String? photoUrl,
    Uint8List? photoBytes,
    bool? notificationsEnabled,
    String? appearanceMode,
    String? languagePreference,
  }) async {
    try {
      await _authService.updateUserProfile(
        userId: userId,
        name: name,
        photoUrl: photoUrl,
        photoBytes: photoBytes,
        notificationsEnabled: notificationsEnabled,
        appearanceMode: appearanceMode,
        languagePreference: languagePreference,
      );

      _currentUser = _currentUser?.copyWith(
        name: name,
        photoUrl: photoUrl,
        notificationsEnabled: notificationsEnabled,
        appearanceMode: appearanceMode,
        languagePreference: languagePreference,
      );

      if (photoBytes != null) {
        await loadCurrentUser(userId);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createCashierForOwner({
    required String ownerId,
    required String name,
    required String email,
    required String password,
    required String shiftLabel,
    required String shiftStart,
    required String shiftEnd,
  }) async {
    _error = null;

    try {
      await _authService.createCashierForOwner(
        ownerId: ownerId,
        name: name,
        email: email,
        password: password,
        shiftLabel: shiftLabel,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> terminateCashier({
    required String ownerId,
    required String cashierId,
  }) async {
    _error = null;

    try {
      await _authService.terminateCashier(
        ownerId: ownerId,
        cashierId: cashierId,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeCashierFromShop({
    required String ownerId,
    required String cashierId,
  }) async {
    _error = null;

    try {
      await _authService.removeCashierFromShop(
        ownerId: ownerId,
        cashierId: cashierId,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
