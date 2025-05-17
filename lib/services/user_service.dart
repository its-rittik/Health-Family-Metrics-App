import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static Future<void> deleteUserData(String userId) async {
    final batch = FirebaseFirestore.instance.batch();
    
    // Delete user document
    final userRef = FirebaseFirestore.instance.collection('userData').doc(userId);
    batch.delete(userRef);
    
    // Delete all metric collections
    final metrics = ['steps', 'sleep', 'water', 'weight'];
    for (final metric in metrics) {
      final metricRef = userRef.collection(metric);
      final metricDocs = await metricRef.get();
      for (final doc in metricDocs.docs) {
        batch.delete(doc.reference);
      }
    }
    
    // Delete invitations
    final invitationsQuery = await FirebaseFirestore.instance
        .collection('invitations')
        .where('fromUserId', isEqualTo: userId)
        .get();
    for (final doc in invitationsQuery.docs) {
      batch.delete(doc.reference);
    }
    
    final receivedInvitationsQuery = await FirebaseFirestore.instance
        .collection('invitations')
        .where('toUserId', isEqualTo: userId)
        .get();
    for (final doc in receivedInvitationsQuery.docs) {
      batch.delete(doc.reference);
    }
    
    // Delete family connections
    final connectionsQuery = await FirebaseFirestore.instance
        .collection('familyConnections')
        .where('fromUserId', isEqualTo: userId)
        .get();
    for (final doc in connectionsQuery.docs) {
      batch.delete(doc.reference);
    }
    
    final receivedConnectionsQuery = await FirebaseFirestore.instance
        .collection('familyConnections')
        .where('toUserId', isEqualTo: userId)
        .get();
    for (final doc in receivedConnectionsQuery.docs) {
      batch.delete(doc.reference);
    }
    
    // Commit all deletions
    await batch.commit();
  }

  static Future<bool> validateFamilyInvitation({
    required String fromUserId,
    required String toUserId,
  }) async {
    // Check if user exists
    final userDoc = await FirebaseFirestore.instance
        .collection('userData')
        .doc(toUserId)
        .get();
    if (!userDoc.exists) {
      return false;
    }
    
    // Check if trying to invite self
    if (fromUserId == toUserId) {
      return false;
    }
    
    // Check if invitation already exists
    final existingInvitation = await FirebaseFirestore.instance
        .collection('invitations')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .get();
    if (existingInvitation.docs.isNotEmpty) {
      return false;
    }
    
    // Check if family connection already exists
    final existingConnection = await FirebaseFirestore.instance
        .collection('familyConnections')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .get();
    if (existingConnection.docs.isNotEmpty) {
      return false;
    }
    
    return true;
  }

  static String maskUserName(String name) {
    if (name.length <= 4) return name;
    final parts = name.split(' ');
    if (parts.length < 2) return name;
    
    final firstName = parts.first;
    final lastName = parts.last;
    
    final maskedFirstName = firstName.length > 2 
        ? '${firstName.substring(0, 2)}${'*' * (firstName.length - 2)}'
        : firstName;
    
    final maskedLastName = lastName.length > 1
        ? '${'*' * (lastName.length - 1)}${lastName.substring(lastName.length - 1)}'
        : lastName;
    
    return '$maskedFirstName $maskedLastName';
  }
} 