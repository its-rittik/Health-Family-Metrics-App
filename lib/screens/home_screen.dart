import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/date_extensions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic> todayMetrics = {
    'steps': 0,
    'weight': 0,
    'sleep': 0,
    'water': 0,
  };
  bool isLoading = true;
  final TextEditingController _familyUserIdController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  List<Map<String, String>> familyMembers = [];
  List<Map<String, dynamic>> familyMetrics = [];

  @override
  void initState() {
    super.initState();
    _fetchTodayMetrics();
    // Set up real-time listener for today's data
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _familyUserIdController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchTodayMetrics();
  }

  void _setupRealtimeListener() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final userId = user['userId'].toString();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final metrics = ['steps', 'weight', 'sleep', 'water'];

    for (final metric in metrics) {
      FirebaseFirestore.instance
          .collection('userData')
          .doc(userId)
          .collection(metric)
          .doc(today)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          setState(() {
            todayMetrics[metric] = snapshot.data()?['value'] ?? 0;
          });
        } else {
          setState(() {
            todayMetrics[metric] = 0;
          });
        }
      });
    }
  }

  Future<void> _fetchTodayMetrics() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final userId = user['userId'].toString();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final metrics = ['steps', 'weight', 'sleep', 'water'];
    
    Map<String, dynamic> newMetrics = {};
    for (final metric in metrics) {
      final doc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(userId)
          .collection(metric)
          .doc(today)
          .get();
      
      newMetrics[metric] = doc.exists ? (doc.data()?['value'] ?? 0) : 0;
    }
    
    setState(() {
      todayMetrics = newMetrics;
      isLoading = false;
    });
    _fetchFamilyMetrics();
  }

  Future<void> _fetchFamilyMetrics() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final metrics = ['steps', 'weight', 'sleep', 'water'];
    List<Map<String, dynamic>> newFamilyMetrics = [];
    
    for (final member in familyMembers) {
      Map<String, dynamic> memberMetrics = {
        'userId': member['userId'],
        'relation': member['relation'],
      };
      
      for (final metric in metrics) {
        final doc = await FirebaseFirestore.instance
            .collection('userData')
            .doc(member['userId'])
            .collection(metric)
            .doc(today)
            .get();
            
        memberMetrics[metric] = doc.exists ? (doc.data()?['value'] ?? 0) : 0;
      }
      newFamilyMetrics.add(memberMetrics);
    }
    
    setState(() {
      familyMetrics = newFamilyMetrics;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Health Summary',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Logout',
            onPressed: () {
              context.read<AuthProvider>().signOut();
            },
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _fetchTodayMetrics,
        child: Center(
          child: Padding(
              padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: 400, // Optional: limit max width for large screens
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildMetricCard(
                    context,
                    'Steps',
                    Icons.directions_walk,
                    Colors.blue,
                    '/metric/steps',
                  ),
                  _buildMetricCard(
                    context,
                    'Water',
                    Icons.water_drop,
                    Colors.lightBlue,
                    '/metric/water',
                  ),
                  _buildMetricCard(
                    context,
                    'Sleep',
                    Icons.bedtime,
                    Colors.purple,
                    '/metric/sleep',
                  ),
                  _buildMetricCard(
                    context,
                    'Weight',
                    Icons.monitor_weight,
                    Colors.green,
                    '/metric/weight',
                              ),
                            ],
                          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String route,
  ) {
    // Get the value for the metric
    String value = '';
    switch (title.toLowerCase()) {
      case 'steps':
        value = todayMetrics['steps']?.toString() ?? '0';
        break;
      case 'water':
        value = todayMetrics['water']?.toString() ?? '0';
        break;
      case 'sleep':
        value = todayMetrics['sleep']?.toString() ?? '0';
        break;
      case 'weight':
        value = todayMetrics['weight']?.toString() ?? '0';
        break;
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.pushNamed(context, route);
          if (result == true) {
            _fetchTodayMetrics();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
                      children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
              ),
            ),
    );
  }
} 