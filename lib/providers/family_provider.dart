import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> handleInvite(String inviteId, bool accept) async {
    try {
      final inviteDoc = await _firestore.collection('invitations').doc(inviteId).get();
      if (!inviteDoc.exists) {
        throw Exception('Invitation not found');
      }

      final inviteData = inviteDoc.data()!;
      if (accept) {
        // Add to familyConnections collection
        await _firestore.collection('familyConnections').add({
          'userId': inviteData['fromUserId'],
          'familyUserId': inviteData['toUserId'],
          'relation': inviteData['relation'],
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Add reverse connection
        await _firestore.collection('familyConnections').add({
          'userId': inviteData['toUserId'],
          'familyUserId': inviteData['fromUserId'],
          'relation': _getReverseRelation(inviteData['relation']),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Update invitation status
      await inviteDoc.reference.update({
        'status': accept ? 'accepted' : 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  String _getReverseRelation(String relation) {
    switch (relation.toLowerCase()) {
      case 'father':
        return 'Child';
      case 'mother':
        return 'Child';
      case 'sister':
        return 'Sibling';
      case 'brother':
        return 'Sibling';
      case 'spouse':
        return 'Spouse';
      case 'child':
        return 'Parent';
      default:
        return 'Family Member';
    }
  }
} 