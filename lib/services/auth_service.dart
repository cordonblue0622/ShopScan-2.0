import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:js' as js;
import 'dart:convert';
import 'dart:async';
import '../models/user_model.dart';
import '../models/shop_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  String get _projectId => Firebase.app().options.projectId;
  static const Duration _writeTimeout = Duration(seconds: 12);
  static const Duration _readTimeout = Duration(seconds: 8);

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up user with shop
  Future<UserModel?> signUpWithShop({
    required String email,
    required String password,
    required String ownerName,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    required UserRole role,
  }) async {
    User? createdUser;

    try {
      print('🔐 Signing up with email: $email');

      // Create user in Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      createdUser = userCredential.user;

      print('✅ User created in Firebase Auth: ${userCredential.user?.uid}');

      await userCredential.user?.updateDisplayName(ownerName);

      final userId = userCredential.user!.uid;

      // Create user document in Firestore
      final user = UserModel(
        id: userId,
        name: ownerName,
        email: email,
        role: role,
        shopId: userId,
        createdAt: DateTime.now(),
      );

      final shop = ShopModel(
        id: userId, // Use userId as shop ID for convenience
        name: shopName,
        address: shopAddress,
        phone: shopPhone,
        ownerId: userId,
        createdAt: DateTime.now(),
      );

      await _persistOwnerBootstrap(
        user: user,
        shop: shop,
        actingUser: userCredential.user,
      );
      print('✅ User and shop documents created in Firestore');

      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Unexpected Error: $e');
      await _rollbackCreatedAuthUser(createdUser);
      throw Exception('Registration failed: $e');
    }
  }

  // Sign in user
  Future<UserModel?> signIn({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    try {
      print('🔐 Signing in with email: $email');

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ User signed in: ${userCredential.user?.uid}');

      final firebaseUser = userCredential.user!;
      DocumentSnapshot<Map<String, dynamic>>? userDoc;

      try {
        userDoc =
            await _getUserDocument(firebaseUser.uid).timeout(_readTimeout);
      } on TimeoutException {
        print(
          '⚠️ Firestore profile lookup timed out for ${firebaseUser.uid}, trying direct profile fetch',
        );
        return await _loadUserProfileForSignIn(firebaseUser, expectedRole: expectedRole);
      }

      if (userDoc.exists) {
        print('✅ User document found in Firestore');
        final user = _normalizeLoadedUser(
          UserModel.fromJson(userDoc.data()!, userDoc.id),
          firebaseUser: firebaseUser,
        );
        if (user.role != expectedRole) {
          await _auth.signOut();
          final selectedLabel = expectedRole == UserRole.owner ? 'Owner' : 'Cashier';
          final actualLabel = user.role == UserRole.owner ? 'Owner' : 'Cashier';
          throw Exception(
            'Role mismatch: You selected "$selectedLabel" but this account is registered as "$actualLabel". Please select the correct role and try again.',
          );
        }
        await _ensureUserCanAccess(user);
        return user;
      }

      print('⚠️ User document not found in Firestore after sign-in');
      return await _loadUserProfileForSignIn(firebaseUser, expectedRole: expectedRole);
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await _auth.signOut();
        throw Exception(
          'Firestore denied access to your profile data in project $_projectId. Deploy the firestore.rules file to that same Firebase project and try again.',
        );
      }

      if (e.code == 'unavailable') {
        return await _loadUserProfileForSignIn(
          firebaseUserCredentialUserFallback(),
          expectedRole: expectedRole,
        );
      }

      print('❌ Firebase Error: ${e.code} - ${e.message}');
      throw Exception('Sign in failed: ${e.message ?? e.code}');
    } catch (e) {
      print('❌ Unexpected Error: $e');
      throw Exception('Sign in failed: $e');
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserDocument(
    String userId,
  ) async {
    final userRef = _firestore.collection('users').doc(userId);

    try {
      return await userRef.get();
    } on FirebaseException {
      rethrow;
    }
  }

  User firebaseUserCredentialUserFallback() {
    final current = _auth.currentUser;
    if (current == null) {
      throw Exception('Authenticated Firebase user is no longer available.');
    }
    return current;
  }

  UserModel _normalizeLoadedUser(UserModel user, {User? firebaseUser}) {
    final authUser = firebaseUser ??
        (_auth.currentUser?.uid == user.id ? _auth.currentUser : null);
    final authDisplayName = authUser?.displayName?.trim() ?? '';
    final storedName = user.name.trim();
    final emailPrefix = user.email.contains('@')
        ? user.email.split('@').first.trim()
        : '';
    final looksLikeEmailHandle = storedName.isEmpty ||
        (emailPrefix.isNotEmpty &&
            storedName.toLowerCase() == emailPrefix.toLowerCase());

    if (authDisplayName.isEmpty || !looksLikeEmailHandle) {
      return user;
    }

    return user.copyWith(name: authDisplayName);
  }

  // Sign in with Google
  Future<UserModel?> signInWithGoogle({
    required UserRole role,
  }) async {
    try {
      print('🔐 Starting Google Sign-In...');

      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        print('⚠️ Google Sign-In cancelled by user');
        return null;
      }

      print('✅ Google Sign-In successful: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Failed to get Firebase user from Google sign-in');
      }

      // Check if user exists in Firestore
      final userDoc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (userDoc.exists) {
        print('✅ User already exists in Firestore');
        final user = UserModel.fromJson(userDoc.data()!, firebaseUser.uid);
        await _ensureUserCanAccess(user);
        return user;
      }

      // Create new user in Firestore
      print('📝 Creating new user in Firestore after Google Sign-In');
      final newUser = UserModel(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'Google User',
        email: firebaseUser.email ?? '',
        role: role,
        shopId: role == UserRole.owner ? firebaseUser.uid : null,
        photoUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
      );

      await _persistUserProfile(newUser, actingUser: firebaseUser);
      if (newUser.role == UserRole.owner) {
        await _ensureOwnerShopExists(newUser, actingUser: firebaseUser);
      }
      print('✅ New user created in Firestore');

      await _ensureUserCanAccess(newUser);
      return newUser;
    } catch (e) {
      print('❌ Google Sign-In Error: $e');
      throw Exception('Google sign-in failed: $e');
    }
  }

  // Sign in with Facebook
  Future<UserModel?> signInWithFacebook({
    required UserRole role,
  }) async {
    try {
      print('🔐 Starting Facebook Sign-In...');

      if (kIsWeb) {
        // Use JavaScript interop for web
        print('🌐 Using JavaScript interop for Facebook login on web');

        final result = await _facebookLoginWeb();

        if (result == null) {
          print('⚠️ Facebook Sign-In cancelled by user');
          return null;
        }

        print(
            '✅ Facebook login successful, exchanging for Firebase credential...');

        // Get access token from result
        final accessToken = result['accessToken'];
        if (accessToken == null) {
          throw Exception('No access token returned from Facebook');
        }

        // Sign in to Firebase with the token
        final credential = FacebookAuthProvider.credential(accessToken);
        final userCredential = await _auth.signInWithCredential(credential);
        final firebaseUser = userCredential.user;

        if (firebaseUser == null) {
          throw Exception('Failed to get Firebase user from Facebook sign-in');
        }

        // Check if user exists in Firestore
        final userDoc =
            await _firestore.collection('users').doc(firebaseUser.uid).get();

        if (userDoc.exists) {
          print('✅ User already exists in Firestore');
          final user = UserModel.fromJson(userDoc.data()!, firebaseUser.uid);
          await _ensureUserCanAccess(user);
          return user;
        }

        // Create new user in Firestore
        print('📝 Creating new user in Firestore after Facebook Sign-In');
        final newUser = UserModel(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Facebook User',
          email: firebaseUser.email ?? '',
          role: role,
          shopId: role == UserRole.owner ? firebaseUser.uid : null,
          photoUrl: firebaseUser.photoURL,
          createdAt: DateTime.now(),
        );

        await _persistUserProfile(newUser, actingUser: firebaseUser);
        if (newUser.role == UserRole.owner) {
          await _ensureOwnerShopExists(newUser, actingUser: firebaseUser);
        }
        print('✅ New user created in Firestore');

        await _ensureUserCanAccess(newUser);
        return newUser;
      } else {
        // Use flutter_facebook_auth for mobile
        final facebookAuth = FacebookAuth.instance;
        final LoginResult result = await facebookAuth.login(
          permissions: ['public_profile', 'email'],
        );

        if (result.status == LoginStatus.cancelled) {
          print('⚠️ Facebook Sign-In cancelled by user');
          return null;
        }

        if (result.status == LoginStatus.failed) {
          throw Exception('Facebook login failed: ${result.message}');
        }

        print('✅ Facebook Sign-In successful');

        final AccessToken? accessToken = result.accessToken;

        if (accessToken == null) {
          throw Exception('Failed to get Facebook access token');
        }

        final credential =
            FacebookAuthProvider.credential(accessToken.tokenString);
        final userCredential = await _auth.signInWithCredential(credential);
        final firebaseUser = userCredential.user;

        if (firebaseUser == null) {
          throw Exception('Failed to get Firebase user from Facebook sign-in');
        }

        // Check if user exists in Firestore
        final userDoc =
            await _firestore.collection('users').doc(firebaseUser.uid).get();

        if (userDoc.exists) {
          print('✅ User already exists in Firestore');
          final user = UserModel.fromJson(userDoc.data()!, firebaseUser.uid);
          await _ensureUserCanAccess(user);
          return user;
        }

        // Create new user in Firestore
        print('📝 Creating new user in Firestore after Facebook Sign-In');
        final newUser = UserModel(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Facebook User',
          email: firebaseUser.email ?? '',
          role: role,
          shopId: role == UserRole.owner ? firebaseUser.uid : null,
          photoUrl: firebaseUser.photoURL,
          createdAt: DateTime.now(),
        );

        await _persistUserProfile(newUser, actingUser: firebaseUser);
        if (newUser.role == UserRole.owner) {
          await _ensureOwnerShopExists(newUser, actingUser: firebaseUser);
        }
        print('✅ New user created in Firestore');

        await _ensureUserCanAccess(newUser);
        return newUser;
      }
    } catch (e) {
      print('❌ Facebook Sign-In Error: $e');
      throw Exception('Facebook sign-in failed: $e');
    }
  }

  // Helper method for web Facebook login using JavaScript interop
  Future<Map<String, dynamic>?> _facebookLoginWeb() async {
    try {
      final completer = Completer<Map<String, dynamic>?>();

      // Call the JavaScript function
      js.context.callMethod('facebookLoginDirect', [
        (String jsonResponse) {
          try {
            final response = jsonDecode(jsonResponse);
            print('Facebook response received: $response');

            if (response['authResponse'] != null) {
              completer.complete({
                'accessToken': response['authResponse']['accessToken'],
                'userID': response['authResponse']['userID'],
              });
            } else if (response['status'] == 'error') {
              completer.complete(null);
            } else {
              completer.complete(null);
            }
          } catch (e) {
            print('Error parsing Facebook response: $e');
            completer.completeError(e);
          }
        }
      ]);

      return completer.future;
    } catch (e) {
      print('❌ JavaScript interop error: $e');
      throw Exception('Failed to call Facebook login: $e');
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(_readTimeout);

      if (userDoc.exists) {
        return _normalizeLoadedUser(
          UserModel.fromJson(userDoc.data()!, userDoc.id),
        );
      }

      // Try REST fallback on web before giving up
      if (kIsWeb) {
        final firebaseUser = _auth.currentUser;
        if (firebaseUser != null && firebaseUser.uid == userId) {
          final restUser = await _getUserDocumentViaRest(firebaseUser);
          if (restUser != null) {
            return restUser;
          }
        }
      }

      return null;
    } on TimeoutException {
      // SDK timed out — try REST on web
      if (kIsWeb) {
        final firebaseUser = _auth.currentUser;
        if (firebaseUser != null && firebaseUser.uid == userId) {
          return await _getUserDocumentViaRest(firebaseUser);
        }
      }
      return null;
    } catch (e) {
      // On web, try REST before failing
      if (kIsWeb) {
        try {
          final firebaseUser = _auth.currentUser;
          if (firebaseUser != null && firebaseUser.uid == userId) {
            return await _getUserDocumentViaRest(firebaseUser);
          }
        } catch (_) {}
      }
      return null;
    }
  }

  Future<UserModel> createCashierForOwner({
    required String ownerId,
    required String name,
    required String email,
    required String password,
    required String shiftLabel,
    required String shiftStart,
    required String shiftEnd,
  }) async {
    FirebaseApp? secondaryApp;
    FirebaseAuth? secondaryAuth;
    User? createdCashierAuthUser;

    try {
      final ownerFirebaseUser = _auth.currentUser;
      if (ownerFirebaseUser == null || ownerFirebaseUser.uid != ownerId) {
        throw Exception(
            'The signed-in owner session expired. Please sign in again.');
      }

      print('👤 Creating cashier: $email for owner $ownerId');
      await _ensureOwnerProfileReady(ownerFirebaseUser);

      final shopId = await _resolveOwnerShopId(ownerId);
      print('🏪 Resolved shopId: $shopId');
      final appName = 'staff-${DateTime.now().microsecondsSinceEpoch}';

      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );
      secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      print('🔑 Creating Firebase Auth account for $email...');
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      createdCashierAuthUser = firebaseUser;
      if (firebaseUser == null) {
        throw Exception('Failed to create staff credentials.');
      }
      print('✅ Auth account created: ${firebaseUser.uid}');

      await firebaseUser.updateDisplayName(name);

      final cashier = UserModel(
        id: firebaseUser.uid,
        name: name,
        email: email,
        role: UserRole.cashier,
        shopId: shopId,
        assignedShiftLabel: shiftLabel,
        assignedShiftStart: shiftStart,
        assignedShiftEnd: shiftEnd,
        createdAt: DateTime.now(),
        isActive: true,
      );

      print('📝 Writing cashier profile to Firestore...');
      await _persistUserProfile(cashier, actingUser: ownerFirebaseUser);
      print('✅ Cashier document created in Firestore');
      return cashier;
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException creating cashier: ${e.code} ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Error creating cashier: $e');
      await _rollbackCreatedAuthUser(createdCashierAuthUser);
      throw Exception('Failed to add staff: $e');
    } finally {
      try {
        await secondaryAuth?.signOut().timeout(const Duration(seconds: 2));
      } catch (_) {}

      try {
        await secondaryApp?.delete().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  Future<String> _resolveOwnerShopId(String ownerId) async {
    // On web, prefer REST to avoid SDK timeouts
    if (kIsWeb) {
      final ownerUser = _auth.currentUser;
      if (ownerUser != null) {
        final restProfile = await _getUserDocumentViaRest(ownerUser);
        if (restProfile != null &&
            restProfile.shopId != null &&
            restProfile.shopId!.isNotEmpty) {
          return restProfile.shopId!;
        }
      }
      return ownerId;
    }

    try {
      final ownerDoc = await _firestore
          .collection('users')
          .doc(ownerId)
          .get()
          .timeout(_readTimeout);
      final ownerData = ownerDoc.data();
      final ownerShopId = ownerData?['shopId'] as String?;
      if (ownerShopId != null && ownerShopId.isNotEmpty) {
        return ownerShopId;
      }
    } catch (e) {
      print('⚠️ Falling back to ownerId for shop lookup: $e');
    }

    return ownerId;
  }

  Future<void> terminateCashier({
    required String ownerId,
    required String cashierId,
  }) async {
    await _updateCashierAccess(
      ownerId: ownerId,
      cashierId: cashierId,
      isActive: false,
    );
  }

  Future<void> removeCashierFromShop({
    required String ownerId,
    required String cashierId,
  }) async {
    await _updateCashierAccess(
      ownerId: ownerId,
      cashierId: cashierId,
      isActive: false,
      removeFromShop: true,
    );
  }

  Future<void> _updateCashierAccess({
    required String ownerId,
    required String cashierId,
    required bool isActive,
    bool removeFromShop = false,
  }) async {
    final ownerShopId = await _resolveOwnerShopId(ownerId);
    final cashierRef = _firestore.collection('users').doc(cashierId);
    final cashierSnapshot = await cashierRef.get();

    if (!cashierSnapshot.exists) {
      throw Exception('Cashier account not found.');
    }

    final cashier =
        UserModel.fromJson(cashierSnapshot.data()!, cashierSnapshot.id);
    if (cashier.role != UserRole.cashier) {
      throw Exception('Only cashier accounts can be managed here.');
    }

    if (cashier.shopId != ownerShopId) {
      throw Exception('You can only manage cashiers assigned to your shop.');
    }

    await cashierRef.update({
      'isActive': isActive,
      if (removeFromShop) 'shopId': null,
      if (removeFromShop) 'assignedShiftLabel': null,
      if (removeFromShop) 'assignedShiftStart': null,
      if (removeFromShop) 'assignedShiftEnd': null,
    });
  }

  Future<void> _ensureUserCanAccess(UserModel user) async {
    if (user.isActive) {
      return;
    }

    await _auth.signOut();
    throw Exception(
        'This staff account has been deactivated. Please contact the shop owner.');
  }

  String _missingUserProfileMessage(String? email) {
    final accountLabel =
        email == null || email.isEmpty ? 'This account' : email;
    return '$accountLabel authenticated successfully, but no Firestore profile was found. This usually means the database write failed during account creation.';
  }

  Future<void> _rollbackCreatedAuthUser(User? user) async {
    if (user == null) {
      return;
    }

    try {
      await user.delete().timeout(const Duration(seconds: 5));
      print('↩️ Rolled back Firebase Auth user after Firestore write failure');
    } catch (rollbackError) {
      print('⚠️ Failed to roll back Firebase Auth user: $rollbackError');
    }
  }

  Future<UserModel> _loadUserProfileForSignIn(User firebaseUser, {UserRole? expectedRole}) async {
    final restProfile = await _getUserDocumentViaRest(firebaseUser);
    if (restProfile != null) {
      final normalizedProfile = _normalizeLoadedUser(
        restProfile,
        firebaseUser: firebaseUser,
      );
      if (expectedRole != null && normalizedProfile.role != expectedRole) {
        await _auth.signOut();
        final selectedLabel = expectedRole == UserRole.owner ? 'Owner' : 'Cashier';
        final actualLabel = normalizedProfile.role == UserRole.owner ? 'Owner' : 'Cashier';
        throw Exception(
          'Role mismatch: You selected "$selectedLabel" but this account is registered as "$actualLabel". Please select the correct role and try again.',
        );
      }
      await _ensureUserCanAccess(normalizedProfile);
      return normalizedProfile;
    }

    // No Firestore profile — user never completed registration.
    await _auth.signOut();
    throw Exception(
      'No account found for ${firebaseUser.email ?? firebaseUser.uid}. '
      'Please sign up first.',
    );
  }

  Future<void> _persistOwnerBootstrap({
    required UserModel user,
    required ShopModel shop,
    User? actingUser,
  }) async {
    await _persistUserProfile(user, actingUser: actingUser);
    await _persistShopRecord(shop, actingUser: actingUser);
  }

  Future<void> _persistUserProfile(
    UserModel user, {
    User? actingUser,
  }) async {
    await _writeDocument(
      collection: 'users',
      documentId: user.id,
      data: user.toJson(),
      actingUser: actingUser,
    );
  }

  Future<void> _persistShopRecord(
    ShopModel shop, {
    User? actingUser,
  }) async {
    await _writeDocument(
      collection: 'shops',
      documentId: shop.id,
      data: shop.toJson(),
      actingUser: actingUser,
    );
  }

  Future<void> _writeDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    User? actingUser,
  }) async {
    if (kIsWeb) {
      await _writeDocumentViaRest(
        collection: collection,
        documentId: documentId,
        data: data,
        actingUser: actingUser,
      );
      return;
    }

    await _firestore
        .collection(collection)
        .doc(documentId)
        .set(data)
        .timeout(_writeTimeout);
  }

  Future<void> _writeDocumentViaRest({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    User? actingUser,
  }) async {
    final authUser = actingUser ?? _auth.currentUser;
    if (authUser == null) {
      throw Exception(
          'No authenticated Firebase user is available for Firestore write.');
    }

    final idToken = await authUser.getIdToken(true);
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$collection/$documentId',
    );
    final response = await http
        .patch(
          uri,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'fields': _mapToFirestoreFields(data),
          }),
        )
        .timeout(_writeTimeout);

    print(
      '📝 Firestore REST write $collection/$documentId → ${response.statusCode}',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(
      'Firestore write failed for $collection/$documentId: ${response.statusCode} ${response.body}',
    );
  }

  Map<String, dynamic> _mapToFirestoreFields(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      fields[key] = _toFirestoreValue(value);
    });
    return fields;
  }

  Map<String, dynamic> _toFirestoreValue(dynamic value) {
    if (value == null) {
      return {'nullValue': null};
    }
    if (value is String) {
      return {'stringValue': value};
    }
    if (value is bool) {
      return {'booleanValue': value};
    }
    if (value is int) {
      return {'integerValue': value.toString()};
    }
    if (value is double) {
      return {'doubleValue': value};
    }
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map(_toFirestoreValue).toList(),
        },
      };
    }
    if (value is Map<String, dynamic>) {
      return {
        'mapValue': {
          'fields': _mapToFirestoreFields(value),
        },
      };
    }

    return {'stringValue': value.toString()};
  }

  Future<UserModel?> _getUserDocumentViaRest(User firebaseUser) async {
    if (!kIsWeb) {
      return null;
    }

    final idToken = await firebaseUser.getIdToken(true);
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/${firebaseUser.uid}',
    );
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    ).timeout(_readTimeout);

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to load Firestore profile for ${firebaseUser.uid}: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = decoded['fields'] as Map<String, dynamic>?;
    if (fields == null) {
      return null;
    }

    final documentName = decoded['name'] as String?;
    final documentId = documentName?.split('/').last ?? firebaseUser.uid;
    final json = _fromFirestoreFields(fields);
    return UserModel.fromJson(json, documentId);
  }

  Map<String, dynamic> _fromFirestoreFields(Map<String, dynamic> fields) {
    final data = <String, dynamic>{};
    fields.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        data[key] = _fromFirestoreValue(value);
      }
    });
    return data;
  }

  dynamic _fromFirestoreValue(Map<String, dynamic> value) {
    if (value.containsKey('nullValue')) {
      return null;
    }
    if (value.containsKey('stringValue')) {
      return value['stringValue'];
    }
    if (value.containsKey('booleanValue')) {
      return value['booleanValue'];
    }
    if (value.containsKey('integerValue')) {
      return int.tryParse(value['integerValue'].toString()) ?? 0;
    }
    if (value.containsKey('doubleValue')) {
      return (value['doubleValue'] as num).toDouble();
    }
    if (value.containsKey('timestampValue')) {
      return value['timestampValue'];
    }
    if (value.containsKey('arrayValue')) {
      final values =
          value['arrayValue']['values'] as List<dynamic>? ?? const [];
      return values
          .whereType<Map<String, dynamic>>()
          .map(_fromFirestoreValue)
          .toList();
    }
    if (value.containsKey('mapValue')) {
      final fields = value['mapValue']['fields'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      return _fromFirestoreFields(fields);
    }

    return null;
  }

  Future<void> _ensureOwnerShopExists(UserModel user,
      {User? actingUser}) async {
    if (user.role != UserRole.owner) {
      return;
    }

    final shop = ShopModel(
      id: user.shopId ?? user.id,
      name: _defaultShopName(user.name),
      address: '',
      phone: '',
      ownerId: user.id,
      createdAt: user.createdAt,
    );

    await _persistShopRecord(shop, actingUser: actingUser);
  }

  Future<UserModel> _recoverLegacyOwnerProfile(User firebaseUser) async {
    final recoveredUser = _buildOwnerProfileFromFirebaseUser(firebaseUser);

    final recoveredShop = ShopModel(
      id: firebaseUser.uid,
      name: _defaultShopName(recoveredUser.name),
      address: '',
      phone: '',
      ownerId: firebaseUser.uid,
      createdAt: recoveredUser.createdAt,
    );

    await _persistOwnerBootstrap(
      user: recoveredUser,
      shop: recoveredShop,
      actingUser: firebaseUser,
    );
    print('✅ Recovered missing owner profile and shop in Firestore');
    return recoveredUser;
  }

  Future<void> _ensureOwnerProfileReady(User firebaseUser) async {
    // Check if owner profile already exists — don't overwrite
    try {
      final existing = await _getUserDocumentViaRest(firebaseUser);
      if (existing != null) {
        print(
            '✅ Owner profile already exists in Firestore, skipping bootstrap');
        return;
      }
    } catch (_) {
      // If the check fails, proceed to create
    }

    final ownerProfile = _buildOwnerProfileFromFirebaseUser(firebaseUser);
    final ownerShop = ShopModel(
      id: ownerProfile.shopId ?? ownerProfile.id,
      name: _defaultShopName(ownerProfile.name),
      address: '',
      phone: '',
      ownerId: ownerProfile.id,
      createdAt: ownerProfile.createdAt,
    );

    await _persistOwnerBootstrap(
      user: ownerProfile,
      shop: ownerShop,
      actingUser: firebaseUser,
    );
  }

  UserModel _buildOwnerProfileFromFirebaseUser(User firebaseUser) {
    final ownerName = firebaseUser.displayName?.trim().isNotEmpty == true
        ? firebaseUser.displayName!.trim()
        : firebaseUser.email?.split('@').first ?? 'Owner';

    return UserModel(
      id: firebaseUser.uid,
      name: ownerName,
      email: firebaseUser.email ?? '',
      role: UserRole.owner,
      shopId: firebaseUser.uid,
      photoUrl: firebaseUser.photoURL,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      isActive: true,
    );
  }

  String _defaultShopName(String ownerName) {
    final trimmed = ownerName.trim();
    if (trimmed.isEmpty) {
      return 'My Shop';
    }
    return "$trimmed's Shop";
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? photoUrl,
    Uint8List? photoBytes,
    bool? notificationsEnabled,
    String? appearanceMode,
    String? languagePreference,
  }) async {
    try {
      String? uploadedPhotoUrl;
      if (photoBytes != null) {
        uploadedPhotoUrl = await _uploadProfilePhoto(
          userId: userId,
          photoBytes: photoBytes,
        );
      }

      await _firestore.collection('users').doc(userId).update({
        if (name != null) 'name': name,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (uploadedPhotoUrl != null) 'photoUrl': uploadedPhotoUrl,
        if (notificationsEnabled != null)
          'notificationsEnabled': notificationsEnabled,
        if (appearanceMode != null) 'appearanceMode': appearanceMode,
        if (languagePreference != null)
          'languagePreference': languagePreference,
      });

      if (_auth.currentUser?.uid == userId && name != null) {
        await _auth.currentUser?.updateDisplayName(name);
      }

      if (_auth.currentUser?.uid == userId && uploadedPhotoUrl != null) {
        await _auth.currentUser?.updatePhotoURL(uploadedPhotoUrl);
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<String> _uploadProfilePhoto({
    required String userId,
    required Uint8List photoBytes,
  }) async {
    final ref = _storage.ref().child('profile_photos/$userId.jpg');
    await ref.putData(
      photoBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Delete user account
  Future<void> deleteAccount(String userId) async {
    try {
      // Delete user from Firestore
      await _firestore.collection('users').doc(userId).delete();

      // Delete user from Firebase Auth
      await _auth.currentUser?.delete();
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'The user account has been disabled.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'An authentication error occurred: ${e.message}';
    }
  }
}
