import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String petName,
    required String teacherName,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if email already exists
      final existing = await _firestore.collection('users').where('email', isEqualTo: email).get();
      if (existing.docs.isNotEmpty) {
        throw Exception('This email is already in use');
      }

      // Get and increment userId
      final counterRef = _firestore.collection('userData').doc('userIdCounter');
      int newUserId = 1000;
      await _firestore.runTransaction((transaction) async {
        final counterSnap = await transaction.get(counterRef);
        if (counterSnap.exists && counterSnap.data()!.containsKey('lastUserId')) {
          newUserId = counterSnap['lastUserId'] + 1;
        }
        transaction.set(counterRef, {'lastUserId': newUserId});
      });

      // Hash the password
      final hashedPassword = hashPassword(password);

      // Save user data in Firestore under userData/{userId}
      await _firestore.collection('userData').doc(newUserId.toString()).set({
        'name': name,
        'email': email,
        'password': hashedPassword,
        'userId': newUserId,
        'petName': petName,
        'teacherName': teacherName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _user = {
        'id': newUserId.toString(),
        'name': name,
        'email': email,
        'userId': newUserId,
        'petName': petName,
        'teacherName': teacherName,
      };
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      final hashedPassword = hashPassword(password);
      final query = await _firestore.collection('userData')
        .where('email', isEqualTo: email)
        .where('password', isEqualTo: hashedPassword)
        .get();
      if (query.docs.isEmpty) {
        throw Exception('Invalid email or password');
      }
      final doc = query.docs.first;
      _user = {
        'id': doc.id,
        ...doc.data(),
      };
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    _user = null;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('users').where('email', isEqualTo: email).get();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateUserProfile({
    String? name,
    String? email,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_user != null) {
        if (email != null && email != _user!['email']) {
          await _firestore.collection('users').doc(_user!['id']).update({
            'name': name,
            'email': email,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        if (name != null) {
          await _firestore.collection('users').doc(_user!['id']).update({
            'name': name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
} 