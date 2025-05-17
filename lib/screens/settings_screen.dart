import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as my_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _retypePasswordController;

  @override
  void initState() {
    super.initState();
    final user = context.read<my_auth.AuthProvider>().user;
    _nameController = TextEditingController(text: user?['name']?.toString() ?? '');
    _emailController = TextEditingController(text: user?['email']?.toString() ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _retypePasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _retypePasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<my_auth.AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(user?['name']?.toString() ?? 'No Name'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Edit Name',
                          onPressed: () => _showEditNameDialog(context, user),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(user?['email']?.toString() ?? 'No Email'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Edit Email',
                          onPressed: () => _showEditEmailDialog(context, user),
                        ),
                      ],
                    ),
                  ),
                  if (user?['userId'] != null)
                    ListTile(
                      leading: const Icon(Icons.fingerprint),
                      title: const Text('User ID'),
                      subtitle: Text(user!['userId'].toString()),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Account Settings Section
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Account Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Reset Password'),
                  onTap: () {
                    _showChangePasswordDialog(context);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ovalButton(
                      context,
                      icon: Icons.logout,
                      label: 'Logout',
                      color: Colors.orange,
                      onTap: () {
                        authProvider.signOut();
                      },
                    ),
                    _ovalButton(
                      context,
                      icon: Icons.delete_forever,
                      label: 'Delete',
                      color: Colors.red,
                      onTap: () {
                        // TODO: Implement delete account
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Account'),
                            content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () {
                                  // TODO: Call delete account logic
                                  Navigator.pop(context);
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // App Info Section
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'App Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Version'),
                  subtitle: const Text('1.0.0'),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  onTap: () {
                    // TODO: Implement privacy policy
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Terms of Service'),
                  onTap: () {
                    // TODO: Implement terms of service
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ovalButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, Map<String, dynamic>? user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty && user != null) {
                // Update Firestore
                await _updateUserName(user['userId'].toString(), newName);
                if (mounted) setState(() {});
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserName(String userId, String newName) async {
    // Update in Firestore
    await FirebaseFirestore.instance
        .collection('userData')
        .doc(userId)
        .update({'name': newName});
    // Optionally, update local provider/state if needed
    final authProvider = context.read<my_auth.AuthProvider>();
    if (authProvider.user != null) {
      authProvider.user!['name'] = newName;
    }
  }

  void _showEditEmailDialog(BuildContext context, Map<String, dynamic>? user) {
    _emailController.text = user?['email']?.toString() ?? '';
    _currentPasswordController.clear();
    bool isLoading = false;
    String? errorMessage;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'New Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(labelText: 'Current Password'),
                obscureText: true,
              ),
              if (isLoading) const Padding(
                padding: EdgeInsets.only(top: 12),
                child: CircularProgressIndicator(),
              ),
              if (errorMessage != null) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                final newEmail = _emailController.text.trim();
                final password = _currentPasswordController.text.trim();
                if (newEmail.isEmpty || password.isEmpty) {
                  setState(() { 
                    errorMessage = 'Please fill in both fields.';
                  });
                  return;
                }
                setState(() { isLoading = true; errorMessage = null; });
                try {
                  // Verify current password
                  final hashedPassword = context.read<my_auth.AuthProvider>().hashPassword(password);
                  final query = await FirebaseFirestore.instance
                      .collection('userData')
                      .where('email', isEqualTo: user?['email'])
                      .where('password', isEqualTo: hashedPassword)
                      .get();

                  if (query.docs.isEmpty) {
                    setState(() { 
                      errorMessage = 'Current password is incorrect';
                    });
                    return;
                  }

                  // Check if new email already exists
                  final existingEmail = await FirebaseFirestore.instance
                      .collection('userData')
                      .where('email', isEqualTo: newEmail)
                      .get();

                  if (existingEmail.docs.isNotEmpty) {
                    setState(() { 
                      errorMessage = 'This email is already in use';
                    });
                    return;
                  }

                  // Update email
                  await FirebaseFirestore.instance
                      .collection('userData')
                      .doc(user?['userId'].toString())
                      .update({
                    'email': newEmail,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  final authProvider = context.read<my_auth.AuthProvider>();
                  if (authProvider.user != null) {
                    authProvider.user!['email'] = newEmail;
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Email updated successfully!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  setState(() { 
                    errorMessage = 'Failed to update email. Please try again.';
                  });
                } finally {
                  setState(() { isLoading = false; });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _retypePasswordController.clear();
    bool isLoading = false;
    String? errorMessage;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(labelText: 'Current Password'),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _retypePasswordController,
                decoration: const InputDecoration(labelText: 'Re-type New Password'),
                obscureText: true,
              ),
              if (isLoading) const Padding(
                padding: EdgeInsets.only(top: 12),
                child: CircularProgressIndicator(),
              ),
              if (errorMessage != null) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                final currentPass = _currentPasswordController.text.trim();
                final newPass = _newPasswordController.text.trim();
                final retypePass = _retypePasswordController.text.trim();
                final user = context.read<my_auth.AuthProvider>().user;

                if (currentPass.isEmpty || newPass.isEmpty || retypePass.isEmpty) {
                  setState(() { 
                    errorMessage = 'Please fill in all fields';
                  });
                  return;
                }

                if (newPass != retypePass) {
                  setState(() { 
                    errorMessage = 'New passwords do not match';
                  });
                  return;
                }

                if (newPass.length < 6) {
                  setState(() { 
                    errorMessage = 'Password must be at least 6 characters';
                  });
                  return;
                }

                setState(() { isLoading = true; errorMessage = null; });

                try {
                  // Verify current password
                  final hashedCurrentPass = context.read<my_auth.AuthProvider>().hashPassword(currentPass);
                  final query = await FirebaseFirestore.instance
                      .collection('userData')
                      .where('email', isEqualTo: user?['email'])
                      .where('password', isEqualTo: hashedCurrentPass)
                      .get();

                  if (query.docs.isEmpty) {
                    setState(() { 
                      errorMessage = 'Current password is incorrect';
                    });
                    return;
                  }

                  // Update password
                  final hashedNewPass = context.read<my_auth.AuthProvider>().hashPassword(newPass);
                  await FirebaseFirestore.instance
                      .collection('userData')
                      .doc(user?['userId'].toString())
                      .update({
                    'password': hashedNewPass,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Password updated successfully!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  setState(() { 
                    errorMessage = 'Failed to update password. Please try again.';
                  });
                } finally {
                  setState(() { isLoading = false; });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectFamilyMemberDialog(BuildContext context) async {
    final user = context.read<my_auth.AuthProvider>().user;
    if (user == null) return;
    final userId = user['userId'].toString();
    final snapshot = await FirebaseFirestore.instance
        .collection('familyConnections')
        .where('userId', isEqualTo: userId)
        .get();
    final members = snapshot.docs.map((doc) => doc.data()).toList();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Family Member'),
        content: members.isEmpty
            ? const Text('No family members found.')
            : SizedBox(
                width: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(member['relation'] ?? 'Family Member'),
                      subtitle: Text('User ID: ${member['familyUserId']}'),
                      onTap: () {
                        Navigator.pop(context, member);
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 