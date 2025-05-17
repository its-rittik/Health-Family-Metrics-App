import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _petNameController = TextEditingController();
  final _teacherNameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _retypePasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isVerified = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _petNameController.dispose();
    _teacherNameController.dispose();
    _newPasswordController.dispose();
    _retypePasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifySecurityQuestions() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final query = await FirebaseFirestore.instance
            .collection('userData')
            .where('email', isEqualTo: _emailController.text.trim())
            .get();

        if (query.docs.isEmpty) {
          setState(() {
            _errorMessage = 'No account found with this email';
          });
          return;
        }

        final userData = query.docs.first.data();
        final storedPetName = userData['petName']?.toString().toLowerCase();
        final storedTeacherName = userData['teacherName']?.toString().toLowerCase();
        final enteredPetName = _petNameController.text.trim().toLowerCase();
        final enteredTeacherName = _teacherNameController.text.trim().toLowerCase();

        if (storedPetName == enteredPetName && storedTeacherName == enteredTeacherName) {
          setState(() {
            _isVerified = true;
            _errorMessage = null;
          });
        } else {
          setState(() {
            _errorMessage = 'Security answers do not match';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final query = await FirebaseFirestore.instance
            .collection('userData')
            .where('email', isEqualTo: _emailController.text.trim())
            .get();

        if (query.docs.isEmpty) {
          setState(() {
            _errorMessage = 'No account found with this email';
          });
          return;
        }

        final userData = query.docs.first;
        final hashedPassword = context.read<AuthProvider>().hashPassword(_newPasswordController.text);

        await FirebaseFirestore.instance
            .collection('userData')
            .doc(userData.id)
            .update({
          'password': hashedPassword,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset successful!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to reset password. Please try again.';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  if (!_isVerified) ...[
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _petNameController,
                      decoration: const InputDecoration(
                        labelText: 'What is your pet name?',
                        prefixIcon: Icon(Icons.pets),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please answer this question';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _teacherNameController,
                      decoration: const InputDecoration(
                        labelText: 'What is your favourite teacher name?',
                        prefixIcon: Icon(Icons.school),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please answer this question';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifySecurityQuestions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        foregroundColor: Colors.green,
                        shape: const StadiumBorder(),
                        elevation: 2,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _newPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _retypePasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Re-type New Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please re-type your password';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        foregroundColor: Colors.green,
                        shape: const StadiumBorder(),
                        elevation: 2,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 