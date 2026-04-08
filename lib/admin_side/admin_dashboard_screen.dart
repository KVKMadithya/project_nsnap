import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _activeTimeframe = 'Weekly';
  bool _isLoading = true;

  // --- LIVE DATA VARIABLES ---
  int _totalUsers = 0;
  int _totalPosts = 0;
  int _totalVideos = 0;
  int _activeVibes = 0;

  List<FlSpot> _engagementSpots = [];
  double _maxY = 10; // Default max height for the graph
  List<String> _last7DaysLabels = [];

  @override
  void initState() {
    super.initState();
    _fetchDatabaseMetrics();
  }

  // ===========================================================================
  // THE DATA ENGINE: Pulls real counts from Firestore
  // ===========================================================================
  Future<void> _fetchDatabaseMetrics() async {
    try {
      // 1. Fetch Total Users
      QuerySnapshot userSnap = await FirebaseFirestore.instance.collection('users').get();

      // 2. Fetch Images vs Videos
      QuerySnapshot postSnap = await FirebaseFirestore.instance.collection('posts').get();
      int pCount = 0;
      int vCount = 0;
      for (var doc in postSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['type'] == 'video') {
          vCount++;
        } else {
          pCount++;
        }
      }

      // 3. Fetch Active Vibes (Only from the last 24 hours)
      DateTime yesterday = DateTime.now().subtract(const Duration(hours: 24));
      QuerySnapshot vibeSnap = await FirebaseFirestore.instance
          .collection('vibes')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterday))
          .get();

      // 4. Build the 7-Day Engagement Graph (Posts created per day)
      List<int> dailyCounts = List.filled(7, 0);
      List<String> dayLabels = [];
      DateTime now = DateTime.now();

      // Generate the labels for the X-Axis (e.g., M, T, W, T, F, S, S) ending on TODAY
      for (int i = 6; i >= 0; i--) {
        DateTime d = now.subtract(Duration(days: i));
        // Gets the first letter of the weekday (e.g., "Monday" -> "M")
        String weekday = ["M", "T", "W", "T", "F", "S", "S"][d.weekday - 1];
        dayLabels.add(weekday);
      }

      // Count the posts for the graph
      double highestCount = 5; // Minimum graph height
      for (var doc in postSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['createdAt'] != null) {
          DateTime postDate = (data['createdAt'] as Timestamp).toDate();
          int daysAgo = now.difference(postDate).inDays;

          if (daysAgo >= 0 && daysAgo < 7) {
            // Map it to the correct spot on the graph (0 is 6 days ago, 6 is today)
            int index = 6 - daysAgo;
            dailyCounts[index]++;
            if (dailyCounts[index] > highestCount) {
              highestCount = dailyCounts[index].toDouble();
            }
          }
        }
      }

      // Convert to FlSpots for the chart package
      List<FlSpot> spots = [];
      for (int i = 0; i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), dailyCounts[i].toDouble()));
      }

      // Update the UI!
      if (mounted) {
        setState(() {
          _totalUsers = userSnap.size;
          _totalPosts = pCount;
          _totalVideos = vCount;
          _activeVibes = vibeSnap.size;

          _engagementSpots = spots;
          _last7DaysLabels = dayLabels;
          _maxY = highestCount + (highestCount * 0.2); // Add 20% padding to the top of the graph

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching metrics: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: c1DeepForest,
        body: Center(child: CircularProgressIndicator(color: c3MediumSage)),
      );
    }

    return Scaffold(
      backgroundColor: c1DeepForest,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Dashboard",
                    style: TextStyle(color: c5CreamGreen, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  // --- NEW: Sleek Nsnap Branding Badge ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: c2DeepOlive.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c3MediumSage.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      "Nsnap",
                      style: TextStyle(
                        color: c5CreamGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 30),

              // --- 2. METRICS GRID (2x2) ---
              Row(
                children: [
                  Expanded(child: _buildMetricCard(_totalUsers.toString(), "Total Users", _calculatePct(_totalUsers, 50), _calculateDouble(_totalUsers, 50), Colors.black, c5CreamGreen, c3MediumSage)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricCard(_totalPosts.toString(), "Total Posts", _calculatePct(_totalPosts, 100), _calculateDouble(_totalPosts, 100), c5CreamGreen, Colors.black, Colors.blueAccent)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildMetricCard(_totalVideos.toString(), "Total Videos", _calculatePct(_totalVideos, 50), _calculateDouble(_totalVideos, 50), c5CreamGreen, Colors.black, c4LightSage)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricCard(_activeVibes.toString(), "Active Vibes", _calculatePct(_activeVibes, 20), _calculateDouble(_activeVibes, 20), c5CreamGreen, Colors.black, Colors.redAccent)),
                ],
              ),
              const SizedBox(height: 40),

              // --- 3. GRAPH HEADER & TABS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Engagement", style: TextStyle(color: c5CreamGreen, fontSize: 22, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(color: c2DeepOlive.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        _buildTimeTab("Weekly"),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 30),

              // --- 4. THE LIVE BEZIER CURVE GRAPH ---
              SizedBox(
                height: 250,
                child: _buildEngagementChart(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- MATH HELPERS FOR PROGRESS BARS ---
  String _calculatePct(int current, int target) {
    double pct = (current / target) * 100;
    if (pct > 100) return "100%";
    return "${pct.toInt()}%";
  }

  double _calculateDouble(int current, int target) {
    double pct = current / target;
    if (pct > 1.0) return 1.0;
    return pct;
  }

  // --- UI WIDGET BUILDERS ---

  Widget _buildMetricCard(String count, String label, String pctText, double pct, Color bgColor, Color textColor, Color barColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(count, style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("0%", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
              Text(pctText, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: textColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          )
        ],
      ),
    );
  }

  Widget _buildTimeTab(String title) {
    bool isActive = _activeTimeframe == title;
    return GestureDetector(
      onTap: () => setState(() => _activeTimeframe = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? c5CreamGreen : c4LightSage,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEngagementChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: (_maxY / 4) == 0 ? 1 : (_maxY / 4),
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(color: c2DeepOlive.withValues(alpha: 0.2), strokeWidth: 1),
          getDrawingVerticalLine: (value) => FlLine(color: c2DeepOlive.withValues(alpha: 0.2), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (_maxY / 4) == 0 ? 1 : (_maxY / 4),
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const Text("");
                return Text(value.toInt().toString(), style: const TextStyle(color: c4LightSage, fontSize: 12));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < _last7DaysLabels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(_last7DaysLabels[value.toInt()], style: const TextStyle(color: c4LightSage, fontWeight: FontWeight.bold)),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: _maxY,
        lineBarsData: [
          LineChartBarData(
            spots: _engagementSpots,
            isCurved: true,
            color: c3MediumSage,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) => spot.x == 6,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 6,
                color: c1DeepForest,
                strokeWidth: 3,
                strokeColor: c3MediumSage,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [c3MediumSage.withValues(alpha: 0.4), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}