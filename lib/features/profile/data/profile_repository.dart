import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firebase_service.dart';
import '../model/user_profile_model.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  final FirebaseAuth _auth = FirebaseService.auth;
  // final FirebaseStorage _storage = FirebaseService.storage;

  // Collection references
  CollectionReference get _usersRef => _firestore.collection('users');

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get current user email
  String? get currentUserEmail => _auth.currentUser?.email;

  // Get current user profile
  Stream<UserProfileModel?> getCurrentUserProfile() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value(null);
    }

    return _usersRef.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return UserProfileModel.fromJson({
        'id': snapshot.id,
        ...snapshot.data() as Map<String, dynamic>,
      });
    });
  }

  // // Create or update user profile
  // Future<void> saveUserProfile(UserProfileModel profile) async {
  //   final userId = currentUserId;
  //   if (userId == null) {
  //     throw Exception('User tidak ditemukan');
  //   }

  //   // Ensure the profile ID matches the current user ID
  //   final updatedProfile = profile.copyWith(id: userId);

  //   await _usersRef.doc(userId).set(updatedProfile.toJson(), SetOptions(merge: true));
  // }

  // Update profile picture
  // Future<String> updateProfilePicture(File imageFile, dynamic uploadTask) async {
  //   final userId = currentUserId;
  //   if (userId == null) {
  //     throw Exception('User tidak ditemukan');
  //   }

  //   // Create a reference to the location you want to upload to in firebase storage
  //   // final storageRef = _storage.ref().child('profile_images/$userId.jpg');

  //   // Upload the file to firebase storage
  //   final uploadTask = await storageRef.putFile(
  //     imageFile,
  //     SettableMetadata(contentType: 'image/jpeg'),
  //   );

  //   // Get download URL
  //   final downloadUrl = await uploadTask.ref.getDownloadURL();

  //   // Update the profile document with the new image URL
  //   await _usersRef.doc(userId).update({'photoUrl': downloadUrl});

  //   return downloadUrl;
  // }

  // Update user display name in Firebase Auth
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User tidak ditemukan');
    }

    await user.updateDisplayName(name);
  }

  // Update user email in Firebase Auth
  Future<void> updateEmail(String newEmail, String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User tidak ditemukan');
    }

    // Re-authenticate the user
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    // Update the email
    await user.updateEmail(newEmail);

    // Update the email in Firestore
    await _usersRef.doc(user.uid).update({'email': newEmail});
  }

  // Update user password in Firebase Auth
  Future<void> updatePassword(
      String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User tidak ditemukan');
    }

    // Re-authenticate the user
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    // Update the password
    await user.updatePassword(newPassword);
  }

  // Delete user account
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User tidak ditemukan');
    }

    // Re-authenticate the user
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    // Delete user data from Firestore
    await _usersRef.doc(user.uid).delete();

    // Delete profile image if exists
    try {
      // await _storage.ref().child('profile_images/${user.uid}.jpg').delete();
    } catch (e) {
      // Image might not exist, ignore
    }

    // Delete the user account
    await user.delete();
  }

  // Get all users (for admin)

  Stream<List<UserProfileModel>> getAllUsers() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _usersRef.snapshots().asyncMap((snapshot) async {
      final currentUserDoc = await _usersRef.doc(currentUser.uid).get();
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;

      if (currentUserData == null) {
        return [];
      }

      // Parse role dari currentUserData
      final currentUserRole =
          _roleFromString(currentUserData['role'] ?? 'user');

      // Cek apakah user adalah admin atau pustakawan
      if (currentUserRole != UserRole.admin &&
          currentUserRole != UserRole.librarian) {
        return [];
      }

      // Jika user adalah admin atau pustakawan, kembalikan semua user
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return UserProfileModel.fromJson({
          'id': doc.id,
          ...data,
        });
      }).toList();
    });
  }

// Fungsi helper untuk mengkonversi string role ke enum UserRole
  UserRole _roleFromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'librarian':
        return UserRole.librarian;
      case 'user':
      default:
        return UserRole.user;
    }
  }

  // Get user count (for admin)
  Future<int> getUserCount() async {
    final snapshot = await _usersRef.get();
    return snapshot.docs.length;
  }

  // Get user by ID (for admin)
  Stream<UserProfileModel?> getUserById(String userId) {
    return _usersRef.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return UserProfileModel.fromJson({
        'id': snapshot.id,
        ...snapshot.data() as Map<String, dynamic>,
      });
    });
  }

  // Update user role (for admin)
  Future<void> updateUserRole(String userId, UserRole role) async {
    await _usersRef.doc(userId).update({'role': role.toString().split('.').last});
  }

  // Deactivate user account (for admin)
  Future<void> deactivateUser(String userId) async {
    await _usersRef.doc(userId).update({'isActive': false});
  }

  // Activate user account (for admin)
  Future<void> activateUser(String userId) async {
    await _usersRef.doc(userId).update({'isActive': true});
  }
}

// Provider for ProfileRepository
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});
