import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/family_provider.dart';
import 'notification_tray_screen.dart';
import '../widgets/notification_badge.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final TextEditingController _userIdController = TextEditingController();
  String? _selectedRelation;
  bool _isLoading = false;
  List<Map<String, dynamic>> _familyMembers = [];
  int _pendingInvites = 0;

  final List<String> _relations = [
    'Father',
    'Mother',
    'Sister',
    'Brother',
    'Spouse',
    'Child',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
    _listenPendingInvites();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  void _listenPendingInvites() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final userId = user['userId'].toString();
    FirebaseFirestore.instance
      .collection('invitations')
      .where('toUserId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .listen((snapshot) {
        setState(() {
          _pendingInvites = snapshot.docs.length;
        });
      });
  }

  Future<void> _loadFamilyMembers() async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthProvider>().user;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('familyConnections')
          .where('userId', isEqualTo: user['userId'].toString())
          .get();

      setState(() {
        _familyMembers = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showInviteDialog() async {
    String? _dialogError;
    final userIdController = TextEditingController(text: _userIdController.text);
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Invite Family Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userIdController,
                decoration: const InputDecoration(
                  labelText: 'Family Member User ID',
                  hintText: 'Enter their unique ID',
                ),
                onChanged: (val) {
                  _userIdController.text = val;
                  setState(() => _dialogError = null);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRelation,
                decoration: const InputDecoration(
                  labelText: 'Relation',
                ),
                items: _relations.map((relation) {
                  return DropdownMenuItem(
                    value: relation,
                    child: Text(relation),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRelation = value;
                    _dialogError = null;
                  });
                },
              ),
              if (_dialogError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _dialogError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (_dialogError != null || userIdController.text.isEmpty || _selectedRelation == null)
                  ? null
                  : () async {
                      final error = await _validateAndSendInvitation(dialogContext: context);
                      if (error != null) {
                        setState(() => _dialogError = error);
                      } else {
                        if (mounted) Navigator.pop(context);
                      }
                    },
              child: const Text('Send Invitation'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _validateAndSendInvitation({BuildContext? dialogContext}) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return null;
    final fromUserId = user['userId'].toString();
    final toUserId = _userIdController.text.trim();
    if (fromUserId == toUserId) {
      return 'You cannot invite yourself';
    }
    // Check if user exists
    final userDoc = await FirebaseFirestore.instance.collection('userData').doc(toUserId).get();
    if (!userDoc.exists) {
      return 'Invalid user ID';
    }
    // Check if invitation already exists
    final existingInvitation = await FirebaseFirestore.instance
        .collection('invitations')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (existingInvitation.docs.isNotEmpty) {
      return 'This user is already invited';
    }
    // Check if family connection already exists (both directions)
    final existingConnection1 = await FirebaseFirestore.instance
        .collection('familyConnections')
        .where('userId', isEqualTo: fromUserId)
        .where('familyUserId', isEqualTo: toUserId)
        .get();
    final existingConnection2 = await FirebaseFirestore.instance
        .collection('familyConnections')
        .where('userId', isEqualTo: toUserId)
        .where('familyUserId', isEqualTo: fromUserId)
        .get();
    if (existingConnection1.docs.isNotEmpty || existingConnection2.docs.isNotEmpty) {
      return 'This user is already connected to you';
    }
    // Masked name
    final name = userDoc.data()?['name'] ?? '';
    final maskedName = UserService.maskUserName(name);
    if (dialogContext != null) {
      NotificationService.showSuccess(dialogContext, 'Successfully invited: $maskedName');
    }
    // Send invitation
    await FirebaseFirestore.instance.collection('invitations').add({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'relation': _selectedRelation,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    _userIdController.clear();
    setState(() => _selectedRelation = null);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Family',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          NotificationBadge(
            count: _pendingInvites,
            onTap: () async {
              setState(() { _pendingInvites = 0; });
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NotificationTrayScreen()),
              );
              if (result == true) {
                _loadFamilyMembers();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _familyMembers.isEmpty
              ? _buildEmptyState()
              : _buildFamilyList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Invite your family member to track health together!',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showInviteDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Invite Family Member'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyList() {
    // Remove duplicates by familyUserId
    final uniqueMembers = <String, Map<String, dynamic>>{};
    for (final member in _familyMembers) {
      uniqueMembers[member['familyUserId'].toString()] = member;
    }
    final membersList = uniqueMembers.values.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: membersList.length + 1, // +1 for the add button
      itemBuilder: (context, index) {
        if (index < membersList.length) {
          final member = membersList[index];
          return FutureBuilder<Map<String, dynamic>>(
            future: _fetchFamilyMemberTodayMetrics(member['familyUserId'].toString()),
            builder: (context, snapshot) {
              final metrics = snapshot.data ?? {'steps': 0, 'water': 0, 'sleep': 0, 'weight': 0};
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () async {
                    await _showComparisonDialog(context, member);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(
                                _getRelationEmoji(member['relation']),
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member['relation'] ?? 'Family Member',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  Text(
                                    'User ID: ${member['familyUserId']}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Family Member',
                              onPressed: () => _deleteFamilyMember(context, member['familyUserId'].toString()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Today\'s Progress',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMetricItem('Steps', metrics['steps'].toString(), Icons.directions_walk),
                            _buildMetricItem('Water', metrics['water'].toString() + 'L', Icons.water_drop),
                            _buildMetricItem('Sleep', metrics['sleep'].toString() + 'h', Icons.bedtime),
                            _buildMetricItem('Weight', metrics['weight'].toString() + 'kg', Icons.monitor_weight),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        } else {
          // Add member button at the end
          return Center(
            child: ElevatedButton.icon(
              onPressed: _showInviteDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Invite Family Member'),
              style: ElevatedButton.styleFrom(
                shape: StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          );
        }
      },
    );
  }

  String _getRelationEmoji(String? relation) {
    switch (relation?.toLowerCase()) {
      case 'father':
        return '👨';
      case 'mother':
        return '👩';
      case 'sister':
        return '👧';
      case 'brother':
        return '👦';
      case 'spouse':
        return '💑';
      case 'child':
        return '👶';
      default:
        return '👤';
    }
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Future<void> _showComparisonDialog(BuildContext context, Map<String, dynamic> member) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final userId = user['userId'].toString();
    final familyUserId = member['familyUserId'].toString();
    final metrics = ['steps', 'weight', 'sleep', 'water'];
    Map<String, dynamic> myMetrics = {};
    Map<String, dynamic> familyMetrics = {};
    for (final metric in metrics) {
      final myDoc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(userId)
          .collection(metric)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      myMetrics[metric] = myDoc.docs.isNotEmpty ? myDoc.docs.first['value'] : 0;
      final famDoc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(familyUserId)
          .collection(metric)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      familyMetrics[metric] = famDoc.docs.isNotEmpty ? famDoc.docs.first['value'] : 0;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Comparison'),
        content: SizedBox(
          width: 260,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.person, size: 32),
                        Text('You', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(Icons.person_outline, size: 32),
                        Text(member['relation'] ?? 'Family', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...metrics.map((metric) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _metricBox(metric, myMetrics[metric]),
                      _metricBox(metric, familyMetrics[metric]),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Material(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Text(
                    'Close',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox(String metric, dynamic value) {
    String label = metric[0].toUpperCase() + metric.substring(1);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value.toString(), style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _deleteFamilyMember(BuildContext context, String familyUserId) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final userId = user['userId'].toString();
    final docs = await FirebaseFirestore.instance
        .collection('familyConnections')
        .where('userId', isEqualTo: userId)
        .where('familyUserId', isEqualTo: familyUserId)
        .get();
    if (docs.docs.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Family Member'),
          content: const Text('Are you sure you want to remove this family member?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        for (final doc in docs.docs) {
          await doc.reference.delete();
        }
        _loadFamilyMembers();
        NotificationService.showSuccess(context, 'Family member deleted.');
      }
    }
  }

  Future<void> _handleInvite(String inviteId, bool accept) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FamilyProvider>().handleInvite(inviteId, accept);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(accept ? 'Invite accepted' : 'Invite rejected'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _fetchFamilyMemberTodayMetrics(String userId) async {
    final today = DateTime.now();
    final dateKey = "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final metrics = ['steps', 'water', 'sleep', 'weight'];
    Map<String, dynamic> data = {};
    for (final metric in metrics) {
      final doc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(userId)
          .collection(metric)
          .doc(dateKey)
          .get();
      data[metric] = doc.exists ? (doc.data()?['value'] ?? 0) : 0;
    }
    return data;
  }
} 