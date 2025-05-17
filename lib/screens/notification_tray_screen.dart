import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class NotificationTrayScreen extends StatefulWidget {
  const NotificationTrayScreen({super.key});

  @override
  State<NotificationTrayScreen> createState() => _NotificationTrayScreenState();
}

class _NotificationTrayScreenState extends State<NotificationTrayScreen> {
  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('invitations')
            .where('toUserId', isEqualTo: user['userId'].toString())
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications.'));
          }
          final invitations = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invitations.length,
            itemBuilder: (context, index) {
              final invitation = invitations[index];
              final fromUserId = invitation['fromUserId'].toString();
              final relation = invitation['relation'] ?? '';
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('userData')
                    .doc(fromUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  String inviterName = fromUserId;
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final data = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                    inviterName = data.containsKey('name') ? data['name'].toString() : fromUserId;
                  }
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$inviterName (ID: $fromUserId) wants to add you as "$relation"',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ovalButton(
                                context,
                                icon: Icons.check,
                                label: 'Accept',
                                color: Colors.green,
                                onTap: () => _handleAccept(invitation),
                              ),
                              _ovalButton(
                                context,
                                icon: Icons.close,
                                label: 'Reject',
                                color: Colors.red,
                                onTap: () => _handleReject(invitation),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
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

  Future<void> _handleAccept(QueryDocumentSnapshot invitation) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final fromUserId = invitation['fromUserId'].toString();
    final toUserId = invitation['toUserId'].toString();
    final relation = invitation['relation'];
    // Add to familyConnections for both users
    final batch = FirebaseFirestore.instance.batch();
    final familyRef = FirebaseFirestore.instance.collection('familyConnections');
    batch.set(familyRef.doc(), {
      'userId': toUserId,
      'familyUserId': fromUserId,
      'relation': relation,
    });
    batch.set(familyRef.doc(), {
      'userId': fromUserId,
      'familyUserId': toUserId,
      'relation': relation,
    });
    // Update invitation status
    batch.update(invitation.reference, {'status': 'accepted'});
    await batch.commit();
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _handleReject(QueryDocumentSnapshot invitation) async {
    await invitation.reference.update({'status': 'rejected'});
  }
} 