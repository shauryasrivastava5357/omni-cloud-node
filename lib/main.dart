import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart'; // The new Data Analytics Engine

const String API_URL = 'https://graviton-api-h20t.onrender.com';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Graviton Omnichannel',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const MainDashboard(),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const RadarScreen(),
    const AIAssistantScreen(),
    const ClusterTopologyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
          BottomNavigationBarItem(icon: Icon(Icons.memory), label: 'Copilot'),
          BottomNavigationBarItem(icon: Icon(Icons.account_tree), label: 'Cluster'),
        ],
      ),
    );
  }
}

// --- SCREEN 1: THE UNIVERSAL TRENDS FEED ---
class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  List<dynamic> _radarItems = [];
  bool _isLoading = false;
  String _selectedFilter = 'ALL';

  final List<Map<String, dynamic>> _platforms = [
    {'name': 'ALL', 'icon': Icons.apps},
    {'name': 'AMAZON', 'icon': Icons.shopping_cart},
    {'name': 'MYNTRA', 'icon': Icons.checkroom},
    {'name': 'FLIPKART', 'icon': Icons.local_mall},
    {'name': 'NYKAA', 'icon': Icons.face_retouching_natural},
    {'name': 'YOUTUBE', 'icon': Icons.play_circle_filled},
    {'name': 'NEWS', 'icon': Icons.article},
  ];

  @override
  void initState() {
    super.initState();
    _fetchRadarData();
  }

  Future<void> _fetchRadarData() async {
    setState(() { _isLoading = true; });
    try {
      final response = await http.get(Uri.parse('$API_URL/history'));
      if (response.statusCode == 200) {
        setState(() {
          _radarItems = json.decode(response.body);
        });
      }
    } catch (e) {
      // Silently fail for UX
    }
    setState(() { _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> filteredItems = _selectedFilter == 'ALL'
        ? _radarItems
        : _radarItems.where((item) => (item['source'] ?? '').toString().toUpperCase() == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Live Platform Trends', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: _fetchRadarData,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _platforms.length,
              itemBuilder: (context, index) {
                final platform = _platforms[index];
                final isSelected = _selectedFilter == platform['name'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter = platform['name'];
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 12, right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.cyanAccent : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? Colors.transparent : Colors.cyanAccent),
                    ),
                    child: Row(
                      children: [
                        Icon(platform['icon'], size: 18, color: isSelected ? const Color(0xFF0F172A) : Colors.cyanAccent),
                        const SizedBox(width: 8),
                        Text(
                          platform['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : filteredItems.isEmpty
                    ? const Center(child: Text("No trends found for this platform.", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final String title = item['title'] ?? 'Unknown Trend';
                          final String source = (item['source'] ?? 'TRENDING').toString().toUpperCase();

                          return Card(
                            color: const Color(0xFF1E293B),
                            margin: const EdgeInsets.only(bottom: 20),
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              onTap: () async {
                                final urlString = item['url'] ?? '';
                                if (urlString.isNotEmpty) {
                                  final Uri url = Uri.parse(urlString);
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url, mode: LaunchMode.externalApplication);
                                  }
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item['image_url'] != null && item['image_url'].toString().isNotEmpty)
                                    Image.network(
                                      item['image_url'],
                                      width: double.infinity,
                                      height: 220,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(height: 220, color: Colors.black26, child: const Icon(Icons.broken_image, size: 50, color: Colors.white24)),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.cyanAccent.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            source,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item['raw_summary'] ?? '',
                                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        
                                        // Automatically inject the Analytics Engine for E-commerce platforms
                                        if (source == 'AMAZON' || source == 'MYNTRA' || source == 'FLIPKART')
                                          PriceAnalyticsChart(
                                            historyData: _radarItems,
                                            targetProductTitle: title,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// --- SCREEN 2: AI COPILOT ---
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'sender': 'ai', 'text': 'Hello. I am connected to the Graviton Cloud. How can I help you analyze the market today?'}
  ];
  bool _isThinking = false;

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;
    String userText = _controller.text;

    setState(() {
      _messages.add({'sender': 'user', 'text': userText});
      _controller.clear();
      _isThinking = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$API_URL/ask'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'question': userText}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages.add({'sender': 'ai', 'text': data['graviton_response']});
        });
      } else {
        setState(() { _messages.add({'sender': 'ai', 'text': 'Error: Cloud cognitive engine failed to respond.'}); });
      }
    } catch (e) {
      setState(() { _messages.add({'sender': 'ai', 'text': 'Network Error: Cannot reach the backend API.'}); });
    }

    setState(() { _isThinking = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Gemini Intelligence', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isAi = _messages[index]['sender'] == 'ai';
                return Align(
                  alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isAi ? const Color(0xFF1E293B) : Colors.cyanAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isAi ? Colors.transparent : Colors.cyanAccent.withOpacity(0.5)),
                    ),
                    child: Text(
                      _messages[index]['text']!,
                      style: TextStyle(color: isAi ? Colors.white : Colors.cyanAccent, fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isThinking)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Query the market...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.cyanAccent),
                  onPressed: _sendMessage,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- SCREEN 3: CLUSTER CONFIGURATION ---
class ClusterTopologyScreen extends StatefulWidget {
  const ClusterTopologyScreen({super.key});

  @override
  State<ClusterTopologyScreen> createState() => _ClusterTopologyScreenState();
}

class _ClusterTopologyScreenState extends State<ClusterTopologyScreen> {
  bool _strictEncryption = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('System Config', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('SECURITY PREFERENCES', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.white54)),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E293B),
            child: SwitchListTile(
              title: const Text('Strict HTTP Sync', style: TextStyle(color: Colors.white)),
              value: _strictEncryption,
              activeColor: Colors.cyanAccent,
              onChanged: (val) => setState(() => _strictEncryption = val),
            ),
          ),
          const SizedBox(height: 24),
          const Text('BACKEND CONNECTION', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.white54)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Cloud Target: \n$API_URL', style: TextStyle(color: Colors.cyanAccent)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.cyanAccent,
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Colors.cyanAccent),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cloud override initiated! Scrapers are running...')),
              );
              http.get(Uri.parse('$API_URL/trending'));
            },
            icon: const Icon(Icons.sync_problem),
            label: const Text('Force Cloud Override Sync'),
          )
        ],
      ),
    );
  }
}

// --- SCREEN 4: DATA ANALYTICS DASHBOARD WIDGET ---
class PriceAnalyticsChart extends StatelessWidget {
  final List<dynamic> historyData;
  final String targetProductTitle;

  const PriceAnalyticsChart({
    super.key, 
    required this.historyData,
    required this.targetProductTitle,
  });

  // The Data Cleaning Pipeline
  List<FlSpot> _generateChartData() {
    List<FlSpot> spots = [];
    double xIndex = 0;

    var productHistory = historyData.where(
      (item) => (item['title'] ?? '').toString().contains(targetProductTitle)
    ).toList();

    for (var item in productHistory.reversed) {
      String summary = item['raw_summary'] ?? '';
      
      final regExp = RegExp(r'\d+');
      final match = regExp.firstMatch(summary);
      
      if (match != null) {
        double price = double.parse(match.group(0)!);
        spots.add(FlSpot(xIndex, price));
        xIndex++;
      }
    }
    
    if (spots.isEmpty) {
      spots.add(const FlSpot(0, 0));
    }
    
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "HISTORICAL PRICE TREND",
            style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: Colors.white54, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _generateChartData(),
                    isCurved: true,
                    color: Colors.cyanAccent,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.cyanAccent.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}