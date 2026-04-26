import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

/// Authentication + session glue for RoomSync.
///
/// Responsibilities:
/// - **Teacher accounts**: Sign up / login using Firebase Authentication (email & password)
/// - **Profiles**: store basic user profile data in Firestore at `users/{uid}`
/// - **App session**: persist a lightweight `User` snapshot locally so the UI
///   can restore the last signed-in role on app restart
///
/// Notes:
/// - Real authorization should be enforced via Firestore Security Rules.
/// - Admin login is currently a prototype (hardcoded credential check) but can
///   optionally sign into Firebase too for authenticated Firestore writes.
class AuthService {
  static const _sessionKey = 'roomsync_current_user_v1';
  static const _usersCollection = 'users';

  static const String _adminEmail = 'chair@bsit.edu';
  static const String _adminPassword = 'admin123';
  static const String _adminName = 'BSIT Chair';
  static const String _defaultCourseId = 'C1';

  /// Restore the last signed-in app user from local storage.
  ///
  /// This does not guarantee FirebaseAuth has a current user; it only restores
  /// the app's internal `User` model used by the dashboard.
  Future<User?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      return _userFromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Clear local session and sign out of FirebaseAuth (if initialized).
  Future<void> signOut() async {
    if (Firebase.apps.isNotEmpty) {
      try {
        await fb_auth.FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  /// Prototype admin login.
  ///
  /// - Validates against hardcoded credentials.
  /// - Attempts FirebaseAuth sign-in (best-effort) so Firestore writes have
  ///   an authenticated context when security rules require it.
  Future<User?> loginAdmin({
    required String email,
    required String password,
  }) async {
    if (email.trim().toLowerCase() != _adminEmail ||
        password != _adminPassword) {
      return null;
    }

    // Optional: also sign into Firebase so Firestore writes have auth context.
    // If this fails (no admin user created in Firebase Auth), we still allow
    // local admin session so the app can run offline.
    if (Firebase.apps.isNotEmpty) {
      try {
        await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _adminEmail,
          password: _adminPassword,
        );
      } catch (_) {}
    }

    const user = User(
      id: 'U_ADMIN_1',
      name: _adminName,
      email: _adminEmail,
      role: UserRole.courseAdmin,
      courseId: _defaultCourseId,
    );
    await _persistSession(user);
    return user;
  }

  /// Teacher login via FirebaseAuth and Firestore profile lookup.
  ///
  /// Flow:
  /// - Sign in with email/password
  /// - Read `users/{uid}` to get `name`, `role`, `courseId`
  /// - Persist session locally for quick restore
  Future<User?> loginTeacher({
    required String email,
    required String password,
  }) async {
    if (Firebase.apps.isEmpty) {
      return null;
    }

    final normalized = email.trim().toLowerCase();
    try {
      final cred =
          await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalized,
        password: password,
      );

      final uid = cred.user?.uid;
      if (uid == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(uid)
          .get();

      final data = doc.data() ?? const <String, dynamic>{};
      final name = (data['name'] ?? '').toString();
      final courseId = (data['courseId'] ?? _defaultCourseId).toString();
      final roleString = (data['role'] ?? UserRole.teacher.name).toString();
      final role = UserRole.values.firstWhere(
        (r) => r.name == roleString,
        orElse: () => UserRole.teacher,
      );

      final user = User(
        id: uid,
        name: name.isEmpty ? normalized : name,
        email: normalized,
        role: role,
        courseId: courseId,
      );
      await _persistSession(user);
      return user;
    } catch (_) {
      return null;
    }
  }

  /// Teacher sign up via FirebaseAuth, then profile creation in Firestore.
  ///
  /// Returns `null` on success; otherwise returns a human-readable error string.
  Future<String?> signUpTeacher({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedName.isEmpty) return 'Name is required.';
    if (normalizedEmail.isEmpty) return 'Email is required.';
    if (!normalizedEmail.contains('@')) return 'Enter a valid email.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    if (password != confirmPassword) return 'Passwords do not match.';

    if (Firebase.apps.isEmpty) {
      return 'Firebase is not initialized.';
    }

    try {
      final cred =
          await fb_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final uid = cred.user?.uid;
      if (uid == null) return 'Failed to create account (missing user id).';

      await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(uid)
          .set({
        'name': normalizedName,
        'email': normalizedEmail,
        'role': UserRole.teacher.name,
        'courseId': _defaultCourseId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'A teacher account with this email already exists.';
      }
      if (e.code == 'invalid-email') return 'Enter a valid email.';
      if (e.code == 'weak-password') {
        return 'Password is too weak (use 6+ characters).';
      }
      return 'Sign up failed: ${e.message ?? e.code}';
    } catch (e) {
      return 'Sign up failed: $e';
    }
  }

  /// Persist the current user session locally.
  Future<void> _persistSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(_userToJson(user)));
  }

  /// Serialize the app's `User` into a JSON-friendly map for session storage.
  static Map<String, dynamic> _userToJson(User user) {
    return {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'role': user.role.name,
      'courseId': user.courseId,
    };
  }

  /// Deserialize a `User` from a locally-stored session JSON map.
  static User _userFromJson(Map<String, dynamic> map) {
    final roleString = (map['role'] ?? UserRole.teacher.name).toString();
    final role = UserRole.values.firstWhere(
      (r) => r.name == roleString,
      orElse: () => UserRole.teacher,
    );
    return User(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      role: role,
      courseId: (map['courseId'] ?? _defaultCourseId).toString(),
    );
  }
}
