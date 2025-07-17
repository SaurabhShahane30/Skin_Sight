import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';



class HistoryPage extends StatefulWidget {
  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, dynamic>>> _futureHistory;
  String selectedType = 'All'; // Options: All, Acne, Wrinkle, Dark Spot


  @override
  void initState() {
    super.initState();
    _futureHistory = fetchScanHistory();
  }

  Future<List<Map<String, dynamic>>> fetchScanHistory() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    print("📌 Current user ID: $userId");


    final data = await Supabase.instance.client
        .from('scan_history')
        .select('*')
        .eq('user_id', userId as Object)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  List<FlSpot> _generateTrendSpots(List<Map<String, dynamic>> scans, String scanType) {
    List<FlSpot> spots = [];

    for (int i = 0; i < scans.length; i++) {
      final scan = scans[i];
      final type = scan['scan_type']?.toLowerCase();
      final analysis = scan['analysis'] ?? '';

      if (type == scanType.toLowerCase()) {
        final match = RegExp(r'\d+').firstMatch(analysis);
        if (match != null) {
          final count = int.tryParse(match.group(0)!);
          if (count != null) {
            spots.add(FlSpot(i.toDouble(), count.toDouble()));
          }
        }
      }
    }

    return spots;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF0D1),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/signup.png'), // background image
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ⏰ Custom Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD17A7A),
                      ),
                      child: const Icon(Icons.history, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "History",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF933A79),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 240,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _futureHistory,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No data to display trend."));
                    }

                    final scans = snapshot.data!;
                    final acneSpots = _generateTrendSpots(scans, 'Acne');
                    final wrinkleSpots = _generateTrendSpots(scans, 'Wrinkle');
                    final darkSpotSpots = _generateTrendSpots(scans, 'Dark Spot');

                    // Calculate max Y from all spot types
                    final allYValues = [
                      ...acneSpots.map((e) => e.y),
                      ...wrinkleSpots.map((e) => e.y),
                      ...darkSpotSpots.map((e) => e.y),
                    ];

                    final double maxY = allYValues.isEmpty ? 5.0 : allYValues.reduce(max) + 1;



                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Trend",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            DropdownButton<String>(
                              value: selectedType,
                              onChanged: (value) {
                                setState(() {
                                  selectedType = value!;
                                });
                              },
                              items: ['All', 'Acne', 'Wrinkle', 'Dark Spot']
                                  .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                                  .toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: maxY,
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index >= 0 && index < scans.length) {
                                        final date = DateTime.parse(scans[index]['created_at']);
                                        return Text(DateFormat('MM/dd').format(date), style: TextStyle(fontSize: 10));
                                      }
                                      return Text('');
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: true),
                                ),
                                topTitles: AxisTitles(),
                                rightTitles: AxisTitles(),
                              ),
                              gridData: FlGridData(show: true),
                              borderData: FlBorderData(show: true),
                              lineBarsData: [
                                if (selectedType == 'All' || selectedType == 'Acne')
                                  LineChartBarData(
                                    spots: acneSpots,
                                    isCurved: true,
                                    color: Colors.pink,
                                    barWidth: 2,
                                    dotData: FlDotData(show: true),
                                  ),
                                if (selectedType == 'All' || selectedType == 'Wrinkle')
                                  LineChartBarData(
                                    spots: wrinkleSpots,
                                    isCurved: true,
                                    color: Colors.blue,
                                    barWidth: 2,
                                    dotData: FlDotData(show: true),
                                  ),
                                if (selectedType == 'All' || selectedType == 'Dark Spot')
                                  LineChartBarData(
                                    spots: darkSpotSpots,
                                    isCurved: true,
                                    color: Colors.purple,
                                    barWidth: 2,
                                    dotData: FlDotData(show: true),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),


              // 🔄 Scan History List (FutureBuilder inside Expanded)
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _futureHistory,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No scans found."));
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {
                          _futureHistory = fetchScanHistory();
                        });
                        await _futureHistory;
                      },
                      color: Color(0xFFE1709A), // spinner color
                      backgroundColor: Color(0xFFFFE6EF),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final scan = snapshot.data![index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFBD5488).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                              border: Border.all(
                                color: const Color(0xFFBD5488),
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Date and Time", style: TextStyle(color: Colors.grey)),
                                Text(
                                  DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(scan['created_at'])),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Scanned For", style: TextStyle(color: Colors.grey)),
                                        Text(scan['scan_type'] ?? "", style: TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Analysis", style: TextStyle(color: Colors.grey)),
                                        Text(scan['analysis'] ?? "", style: TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text("Summary", style: TextStyle(color: Colors.grey)),
                                Text(scan['summary'] ?? ""),
                                if (scan['image_url'] != null) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(scan['image_url'], height: 120),
                                  ),
                                ],
                              ],
                            ),
                          );

                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
