import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart' as my_auth;
import '../../services/notification_service.dart';

class MetricDetailScreen extends StatefulWidget {
  final String metric;
  const MetricDetailScreen({super.key, required this.metric});

  @override
  State<MetricDetailScreen> createState() => _MetricDetailScreenState();
}

class _MetricDetailScreenState extends State<MetricDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  String _selectedRange = '7 days';
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _chartData = [];
  List<Map<String, dynamic>> _familyChartData = [];
  String? _selectedFamilyUserId;
  String? _selectedFamilyRelation;
  List<Map<String, dynamic>> _familyMembers = [];

  @override
  void initState() {
    super.initState();
    _initUserAndFamilyMembers();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getMetricColor(String metric) {
    switch (metric) {
      case 'steps':
        return Colors.blue;
      case 'weight':
        return Colors.green;
      case 'sleep':
        return Colors.purple;
      case 'water':
        return Colors.lightBlue;
      default:
        return Colors.grey;
    }
  }

  IconData _getMetricIcon(String metric) {
    switch (metric) {
      case 'steps':
        return Icons.directions_walk;
      case 'weight':
        return Icons.monitor_weight;
      case 'sleep':
        return Icons.bedtime;
      case 'water':
        return Icons.water_drop;
      default:
        return Icons.health_and_safety;
    }
  }

  Map<String, dynamic> _getYAxisSettings(String metric, List<Map<String, dynamic>> data, [List<Map<String, dynamic>>? familyData]) {
    // Combine user and family data for min/max calculation if familyData is provided
    final allData = familyData != null && familyData.isNotEmpty ? [...data, ...familyData] : data;
    if (allData.isEmpty) {
      // Default values if no data
      switch (metric) {
        case 'steps':
          return {'max': 5000.0, 'interval': 1000.0, 'formatter': (num v) => v == 0 ? '0' : v.toInt().toString()};
        case 'weight':
          return {'max': 150.0, 'interval': 20.0, 'formatter': (num v) => v == 0 ? '0' : '${v.toInt()}Kg'};
        case 'sleep':
          return {'max': 12.0, 'interval': 3.0, 'formatter': (num v) => v == 0 ? '0' : '${v.toInt()}H'};
        case 'water':
          return {'max': 12.0, 'interval': 4.0, 'formatter': (num v) => v == 0 ? '0' : '${v.toInt()}G'};
        default:
          return {'max': 100.0, 'interval': 10.0, 'formatter': (num v) => v.toString()};
      }
    }

    // Calculate min and max values from allData
    double minValue = double.infinity;
    double maxValue = -double.infinity;
    for (var point in allData) {
      final value = (point['value'] as num).toDouble();
      minValue = minValue > value ? value : minValue;
      maxValue = maxValue < value ? value : maxValue;
    }

    // Add some padding to the range
    final range = maxValue - minValue;
    final padding = range * 0.1; // 10% padding
    minValue = (minValue - padding).clamp(0, double.infinity);
    maxValue = maxValue + padding;

    // Calculate appropriate interval
    double interval;
    if (range <= 10) {
      interval = 1;
    } else if (range <= 50) {
      interval = 5;
    } else if (range <= 100) {
      interval = 10;
    } else if (range <= 500) {
      interval = 50;
    } else if (range <= 1000) {
      interval = 100;
    } else if (range <= 5000) {
      interval = 500;
    } else {
      interval = 1000;
    }

    // Round maxValue up to the next interval
    maxValue = (maxValue / interval).ceil() * interval;

    // Formatter function based on metric type
    String Function(num) formatter;
    switch (metric) {
      case 'steps':
        formatter = (num v) => v == 0 ? '0' : v.toInt().toString();
        break;
      case 'weight':
        formatter = (num v) => v == 0 ? '0' : '${v.toInt()}Kg';
        break;
      case 'sleep':
        formatter = (num v) => v == 0 ? '0' : '${v.toInt()}H';
        break;
      case 'water':
        formatter = (num v) => v == 0 ? '0' : '${v.toInt()}G';
        break;
      default:
        formatter = (num v) => v.toString();
    }

    return {
      'max': maxValue,
      'min': minValue,
      'interval': interval,
      'formatter': formatter,
    };
  }

  Future<void> _saveMetric() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final userProvider = context.read<my_auth.AuthProvider>();
      final user = userProvider.user;
      if (user == null) throw Exception('User not logged in');
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      final value = int.tryParse(_controller.text.trim());
      if (value == null) throw Exception('Please enter a valid number');
      
      final docRef = FirebaseFirestore.instance
          .collection('userData')
          .doc(user['userId'].toString())
          .collection(widget.metric)
          .doc(dateKey);
          
      await docRef.set({
        'value': value,
        'timestamp': now,
      });

      setState(() {
        _controller.clear();
      });
      NotificationService.showSuccess(context, 'Saved!');
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchChartData() async {
    final userProvider = context.read<my_auth.AuthProvider>();
    final user = userProvider.user;
    if (user == null) return;
    final now = DateTime.now();
    List<Map<String, dynamic>> data = [];
    if (_selectedRange == '7 days' || _selectedRange == '15 days') {
      int days = _selectedRange == '7 days' ? 7 : 15;
      for (int i = days - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final doc = await FirebaseFirestore.instance
            .collection('userData')
            .doc(user['userId'].toString())
            .collection(widget.metric)
            .doc(dateKey)
            .get();
        data.add({
          'date': date,
          'value': doc.exists ? (doc.data()?['value'] ?? 0) : 0,
        });
      }
    } else if (_selectedRange == '1 month') {
      for (int w = 3; w >= 0; w--) {
        int sum = 0;
        int count = 0;
        DateTime weekStart = now.subtract(Duration(days: w * 7));
        for (int d = 0; d < 7; d++) {
          final date = weekStart.subtract(Duration(days: d));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final doc = await FirebaseFirestore.instance
              .collection('userData')
              .doc(user['userId'].toString())
              .collection(widget.metric)
              .doc(dateKey)
              .get();
          if (doc.exists) {
            sum += (doc.data()?['value'] ?? 0) as int;
            count++;
          }
        }
        data.add({
          'date': weekStart,
          'value': count > 0 ? (sum / count) : 0,
        });
      }
    } else if (_selectedRange == '6 months') {
      for (int p = 11; p >= 0; p--) {
        int sum = 0;
        int count = 0;
        DateTime periodStart = now.subtract(Duration(days: p * 15));
        for (int d = 0; d < 15; d++) {
          final date = periodStart.subtract(Duration(days: d));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final doc = await FirebaseFirestore.instance
              .collection('userData')
              .doc(user['userId'].toString())
              .collection(widget.metric)
              .doc(dateKey)
              .get();
          if (doc.exists) {
            sum += (doc.data()?['value'] ?? 0) as int;
            count++;
          }
        }
        data.add({
          'date': periodStart,
          'value': count > 0 ? (sum / count) : 0,
        });
      }
    }
    setState(() {
      _chartData = data;
    });
  }

  Future<void> _initUserAndFamilyMembers() async {
    final userProvider = context.read<my_auth.AuthProvider>();
    final user = userProvider.user;
    if (user == null) return;
    final userId = user['userId'].toString();
    final snapshot = await FirebaseFirestore.instance
        .collection('familyConnections')
        .where('userId', isEqualTo: userId)
        .get();
    setState(() {
      _familyMembers = snapshot.docs.map((doc) => doc.data()).toList();
    });
    await _fetchChartData();
  }

  void _showSelectFamilyMemberDialog() async {
    if (_familyMembers.isEmpty) return;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Family Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final member in _familyMembers)
              ListTile(
                title: Center(
                  child: Material(
                    color: _selectedFamilyUserId == member['familyUserId'] 
                        ? _getMetricColor(widget.metric).withOpacity(0.2) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Text(
                        member['relation'] ?? 'Family Member',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getMetricColor(widget.metric),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                onTap: () => Navigator.pop(context, member),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _selectedFamilyUserId = selected['familyUserId'];
        _selectedFamilyRelation = selected['relation'];
      });
      await _fetchFamilyChartData(selected['familyUserId']);
    }
  }

  Future<void> _fetchFamilyChartData(String familyUserId) async {
    final now = DateTime.now();
    List<Map<String, dynamic>> data = [];
    if (_selectedRange == '7 days' || _selectedRange == '15 days') {
      int days = _selectedRange == '7 days' ? 7 : 15;
      for (int i = days - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final doc = await FirebaseFirestore.instance
            .collection('userData')
            .doc(familyUserId)
            .collection(widget.metric)
            .doc(dateKey)
            .get();
        data.add({
          'date': date,
          'value': doc.exists ? (doc.data()?['value'] ?? 0) : 0,
        });
      }
    } else if (_selectedRange == '1 month') {
      for (int w = 3; w >= 0; w--) {
        int sum = 0;
        int count = 0;
        DateTime weekStart = now.subtract(Duration(days: w * 7));
        for (int d = 0; d < 7; d++) {
          final date = weekStart.subtract(Duration(days: d));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final doc = await FirebaseFirestore.instance
              .collection('userData')
              .doc(familyUserId)
              .collection(widget.metric)
              .doc(dateKey)
              .get();
          if (doc.exists) {
            sum += (doc.data()?['value'] ?? 0) as int;
            count++;
          }
        }
        data.add({
          'date': weekStart,
          'value': count > 0 ? (sum / count) : 0,
        });
      }
    } else if (_selectedRange == '6 months') {
      for (int p = 11; p >= 0; p--) {
        int sum = 0;
        int count = 0;
        DateTime periodStart = now.subtract(Duration(days: p * 15));
        for (int d = 0; d < 15; d++) {
          final date = periodStart.subtract(Duration(days: d));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final doc = await FirebaseFirestore.instance
              .collection('userData')
              .doc(familyUserId)
              .collection(widget.metric)
              .doc(dateKey)
              .get();
          if (doc.exists) {
            sum += (doc.data()?['value'] ?? 0) as int;
            count++;
          }
        }
        data.add({
          'date': periodStart,
          'value': count > 0 ? (sum / count) : 0,
        });
      }
    }
    // Pad data to match chartData length if needed
    if (mounted) {
      setState(() {
        // If chartData is already loaded, pad family data to match
        final userLen = _chartData.length;
        if (data.length < userLen) {
          for (int i = data.length; i < userLen; i++) {
            data.add({'date': null, 'value': 0});
          }
        } else if (data.length > userLen && userLen > 0) {
          data = data.sublist(0, userLen);
        }
        _familyChartData = data;
      });
    }
  }

  Future<void> _fetchBothChartData() async {
    await _fetchChartData();
    if (_selectedFamilyUserId != null) {
      await _fetchFamilyChartData(_selectedFamilyUserId!);
    } else {
      setState(() {
        _familyChartData = [];
      });
    }
  }

  @override
  void didUpdateWidget(covariant MetricDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchBothChartData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchBothChartData();
  }

  @override
  Widget build(BuildContext context) {
    final metricColor = _getMetricColor(widget.metric);
    final metricIcon = _getMetricIcon(widget.metric);
    
    // Calculate Y-axis settings based on both user and family data
    final yAxis = _getYAxisSettings(widget.metric, _chartData, _familyChartData);

    // Use the full data range for the chart
    final List<Map<String, dynamic>> chartData = _chartData;
    final List<Map<String, dynamic>> familyChartData = _familyChartData;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(metricIcon, color: metricColor),
            const SizedBox(width: 8),
            Text('${widget.metric[0].toUpperCase()}${widget.metric.substring(1)} Details'),
          ],
        ),
        backgroundColor: metricColor.withValues(red: 0, green: 0, blue: 255, alpha: 0.1),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [metricColor.withOpacity(0.05), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Enter your ${widget.metric} data:',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: metricColor)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            labelText: 'Enter ${widget.metric}',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: Icon(metricIcon, color: metricColor),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : () async {
                          await _saveMetric();
                          await _fetchBothChartData();
                        },
                        icon: const Icon(Icons.save, color: Colors.black),
                        label: _isLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save', style: TextStyle(color: Colors.black)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: metricColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 24),
                  // Show graph for: (styled like Select Member)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        const Text('Show graph for:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Material(
                          color: metricColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () async {
                              final value = await showDialog<String>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Select Range'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final option in ['7 days', '15 days', '1 month'])
                                        ListTile(
                                          title: Center(
                                            child: Material(
                                              color: _selectedRange == option ? metricColor.withOpacity(0.2) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(30),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                                child: Text(
                                                  option,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: metricColor,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          onTap: () => Navigator.pop(context, option),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                              if (value != null && value != _selectedRange) {
                                setState(() => _selectedRange = value);
                                await _fetchBothChartData();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Text(
                                    _selectedRange,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: metricColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_drop_down, color: metricColor),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Progress Graph',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: metricColor),
                    ),
                  ),
                  // Select Member Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        const Text('', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Material(
                          color: metricColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: _showSelectFamilyMemberDialog,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Text(
                                    _selectedFamilyRelation ?? 'Select Member',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: metricColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_drop_down, color: metricColor),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: chartData.isEmpty
                        ? const Center(child: Text('No data to display'))
                        : FractionallySizedBox(
                            heightFactor: 0.85,
                            child: Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                child: LineChart(
                                  LineChartData(
                                    minY: yAxis['min'],
                                    maxY: yAxis['max'],
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: true,
                                      getDrawingHorizontalLine: (value) => FlLine(
                                        color: Colors.grey.shade400,
                                        strokeWidth: 2,
                                      ),
                                      getDrawingVerticalLine: (value) => FlLine(
                                        color: Colors.grey.shade400,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border.all(color: Colors.grey.shade700, width: 2),
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: yAxis['interval'],
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              yAxis['formatter'](value),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            );
                                          },
                                          reservedSize: 40,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 1,
                                          getTitlesWidget: (double value, TitleMeta meta) {
                                            if (_selectedRange == '1 month') {
                                              const weekLabels = ['1st week', '2nd week', '3rd week', '4th week'];
                                              int index = value.toInt();
                                              if (index >= 0 && index < weekLabels.length) {
                                                return SideTitleWidget(
                                                  axisSide: meta.axisSide,
                                                  space: 8.0,
                                                  child: Text(
                                                    weekLabels[index],
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                return const SizedBox.shrink();
                                              }
                                            }
                                            if (_selectedRange == '15 days') {
                                              final idx = value.toInt();
                                              final total = chartData.length;
                                              if (total >= 3 && (idx == 0 || idx == total ~/ 2 || idx == total - 1)) {
                                                final date = chartData[idx]['date'] as DateTime;
                                                return SideTitleWidget(
                                                  axisSide: meta.axisSide,
                                                  space: 8.0,
                                                  child: Text(
                                                    DateFormat('MM/dd').format(date),
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                );
                                              } else {
                                                return const SizedBox.shrink();
                                              }
                                            }
                                            if (_selectedRange == '7 days') {
                                              final idx = value.toInt();
                                              if (idx >= 0 && idx < chartData.length) {
                                                final date = chartData[idx]['date'] as DateTime;
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 8.0),
                                                  child: Text(
                                                    DateFormat('MM/dd').format(date),
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                );
                                              }
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: List.generate(
                                          chartData.length,
                                          (i) => FlSpot(i.toDouble(), chartData[i]['value'].toDouble()),
                                        ),
                                        isCurved: true,
                                        color: metricColor,
                                        barWidth: 6,
                                        isStrokeCapRound: true,
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            colors: [
                                              metricColor.withOpacity(0.3),
                                              metricColor.withOpacity(0.0),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                            radius: 5,
                                            color: Colors.white,
                                            strokeWidth: 3,
                                            strokeColor: metricColor,
                                          ),
                                        ),
                                      ),
                                      if (_selectedFamilyUserId != null)
                                        LineChartBarData(
                                          spots: List.generate(
                                            familyChartData.length,
                                            (i) => FlSpot(i.toDouble(), familyChartData[i]['value'].toDouble()),
                                          ),
                                          isCurved: true,
                                          color: Colors.orange,
                                          barWidth: 6,
                                          isStrokeCapRound: true,
                                          belowBarData: BarAreaData(
                                            show: true,
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.orange.withOpacity(0.3),
                                                Colors.orange.withOpacity(0.0),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                          dotData: FlDotData(
                                            show: true,
                                            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                              radius: 5,
                                              color: Colors.white,
                                              strokeWidth: 3,
                                              strokeColor: Colors.orange,
                                            ),
                                          ),
                                        ),
                                    ],
                                    lineTouchData: const LineTouchData(enabled: true),
                                    showingTooltipIndicators: [],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 