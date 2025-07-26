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

    String normalizeAnalysis(String analysis) {
      return analysis
          .toLowerCase()
          .replaceAll('_', ' ')
          .replaceAll(RegExp(r'[^\w\s]'), '') // remove punctuation
          .trim();
    }

    for (var scan in scans) {
      final type = scan['scan_type']?.toLowerCase();
      final rawAnalysis = scan['analysis'] ?? '';
      final analysis = normalizeAnalysis(rawAnalysis);
      final createdAt = DateTime.tryParse(scan['created_at']);

      if ((type ?? '').trim() == scanType.trim().toLowerCase() && createdAt != null) {
        RegExp? regex;

        print("🔍 ScanType: $scanType | Analysis: $analysis");

        // Build general-purpose regex dynamically
        if (scanType.toLowerCase() == 'acne') {
          regex = RegExp(r'detected\s+(\d+)\s+acne');
        } else if (scanType.toLowerCase() == 'wrinkle') {
          regex = RegExp(r'detected\s+(\d+)\s+(wrinkles|lines)');
        } else if (scanType.toLowerCase().contains('dark')) {
          regex = RegExp(r'detected\s+(\d+)\s+dark\s+spots?');
        }

        final match = regex?.firstMatch(analysis);
        if (match != null) {
          final count = int.tryParse(match.group(1)!);
          if (count != null) {
            final timestamp = createdAt.millisecondsSinceEpoch.toDouble();
            print("📈 $scanType → $count at ${DateFormat('MM/dd HH:mm').format(createdAt)}");
            spots.add(FlSpot(timestamp, count.toDouble()));
          } else {
            print("❌ Failed to parse count");
          }
        } else if (analysis.contains('no') && analysis.contains(scanType.toLowerCase().replaceAll(' ', ''))) {
          final timestamp = createdAt.millisecondsSinceEpoch.toDouble();
          print("📈 $scanType → 0 at ${DateFormat('MM/dd HH:mm').format(createdAt)}");
          spots.add(FlSpot(timestamp, 0));
        } else {
          print("⚠️ No match found in $scanType analysis: $rawAnalysis");
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

                    final modelKeyMap = {
                      "Acne": "Acne",
                      "Wrinkle": "Wrinkle",
                      "Dark Spot": "Dark Spots",
                      "Oily Skin": "Skin Type", // future proofing
                    };


                    // Generate FlSpots using timestamps for x-axis
                    final acneSpots = _generateTrendSpots(scans, modelKeyMap['Acne']!);
                    final wrinkleSpots = _generateTrendSpots(scans, modelKeyMap['Wrinkle']!);
                    final darkSpotSpots = _generateTrendSpots(scans, modelKeyMap['Dark Spot']!);


                    // ⏱️ Calculate minX and maxX from timestamps (X-axis)
                    final allTimestamps = [
                      ...acneSpots.map((e) => e.x),
                      ...wrinkleSpots.map((e) => e.x),
                      ...darkSpotSpots.map((e) => e.x),
                    ];

                    final double minX = allTimestamps.isEmpty ? 0 : allTimestamps.reduce(min);
                    final double maxX = allTimestamps.isEmpty ? 1 : allTimestamps.reduce(max) + 1000000; // 1M ms padding

                    // 📈 Calculate maxY
                    final allYValues = [
                      ...acneSpots.map((e) => e.y),
                      ...wrinkleSpots.map((e) => e.y),
                      ...darkSpotSpots.map((e) => e.y),
                    ];

                    final double rawMaxY = allYValues.isEmpty ? 5.0 : allYValues.reduce(max);
                    final double maxY = min((rawMaxY * 1.2).ceilToDouble(), rawMaxY + 5);


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
                              minX: minX,
                              maxX: maxX,
                              clipData: FlClipData.all(),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: (maxX - minX) / 4, // Optional: 4 labels
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) {
                                      final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                                      return Text(
                                        DateFormat('MM/dd').format(date),
                                        style: const TextStyle(fontSize: 10),
                                      );
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
