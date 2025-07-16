import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';


class HistoryPage extends StatefulWidget {
  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, dynamic>>> _futureHistory;

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
