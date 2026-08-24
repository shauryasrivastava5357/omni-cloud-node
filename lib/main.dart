import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';

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
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          surface: Color(0xFF1E293B),
        ),
        fontFamily: 'Roboto', 
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
    const ImmersiveFeedScreen(),
    const AIAssistantScreen(),
    const ClusterTopologyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          
          // Floating Nav Bar
          Positioned(
            bottom: 30,
            left: 40,
            right: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 65,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(Icons.swipe_up_rounded, 0),
                      _buildNavItem(Icons.memory, 1),
                      _buildNavItem(Icons.dashboard_customize_rounded, 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyanAccent.withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.cyanAccent : Colors.white54,
          size: 28,
        ),
      ),
    );
  }
}

// --- SCREEN 1: IMMERSIVE FEED WITH FILTERS ---
class ImmersiveFeedScreen extends StatefulWidget {
  const ImmersiveFeedScreen({super.key});

  @override
  State<ImmersiveFeedScreen> createState() => _ImmersiveFeedScreenState();
}

class _ImmersiveFeedScreenState extends State<ImmersiveFeedScreen> {
  List<dynamic> _feedItems = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';

  final List<Map<String, dynamic>> _platforms = [
    {'name': 'ALL', 'icon': Icons.apps},
    {'name': 'AMAZON', 'icon': Icons.shopping_cart},
    {'name': 'MYNTRA', 'icon': Icons.checkroom},
    {'name': 'FLIPKART', 'icon': Icons.local_mall},
    {'name': 'INSTAGRAM', 'icon': Icons.camera_alt},
    {'name': 'X', 'icon': Icons.close},
  ];

  @override
  void initState() {
    super.initState();
    _fetchFeedData();
  }

  Future<void> _fetchFeedData() async {
    try {
      final response = await http.get(Uri.parse('$API_URL/history')).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        setState(() {
          _feedItems = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
    }

    List<dynamic> filteredItems = _selectedFilter == 'ALL'
        ? _feedItems
        : _feedItems.where((item) => (item['source'] ?? '').toString().toUpperCase() == _selectedFilter).toList();

    return Stack(
      children: [
        // 1. The Swipe Feed
        filteredItems.isEmpty
            ? const Center(child: Text("No trends found in vault for this platform.", style: TextStyle(color: Colors.white54)))
            : PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  return FullScreenMediaCard(item: filteredItems[index], fullHistory: _feedItems);
                },
              ),

        // 2. The Restored Top Category Filters
        Positioned(
          top: 50,
          left: 0,
          right: 0,
          child: SizedBox(
            height: 40,
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
                      color: isSelected ? Colors.cyanAccent : Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? Colors.transparent : Colors.white30),
                    ),
                    child: Row(
                      children: [
                        Icon(platform['icon'], size: 16, color: isSelected ? Colors.black : Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          platform['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isSelected ? Colors.black : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class FullScreenMediaCard extends StatelessWidget {
  final dynamic item;
  final List<dynamic> fullHistory;

  const FullScreenMediaCard({super.key, required this.item, required this.fullHistory});

  IconData _getPlatformIcon(String source) {
    switch (source) {
      case 'INSTAGRAM': return Icons.camera_alt;
      case 'X': return Icons.close;
      case 'YOUTUBE': return Icons.play_arrow_rounded;
      case 'AMAZON': return Icons.shopping_cart;
      case 'MYNTRA': return Icons.checkroom;
      default: return Icons.language;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = item['title'] ?? 'Unknown Trend';
    final String source = (item['source'] ?? 'TRENDING').toString().toUpperCase();
    final String imageUrl = item['image_url'] ?? '';
    final String summary = item['raw_summary'] ?? '';
    final bool isEcom = source == 'AMAZON' || source == 'MYNTRA' || source == 'FLIPKART';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image restored!
        imageUrl.isNotEmpty
            ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => _buildPlaceholder())
            : _buildPlaceholder(),

        // Dark Gradient for text readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.4),
                Colors.transparent,
                Colors.black.withOpacity(0.8),
                Colors.black,
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),

        // Platform Badge
        Positioned(
          top: 110, // Moved down slightly to clear the filters
          right: 20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.black.withOpacity(0.3),
                child: Row(
                  children: [
                    Icon(_getPlatformIcon(source), size: 16, color: Colors.cyanAccent),
                    const SizedBox(width: 6),
                    Text(source, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Title and Summary Block
        Positioned(
          bottom: 120, 
          left: 20,
          right: 20, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Text(
                summary,
                style: const TextStyle(fontSize: 15, color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              
              if (isEcom)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFF0F172A),
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => Container(
                        height: 400,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("DATA INTELLIGENCE", style: TextStyle(color: Colors.cyanAccent, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                            Expanded(child: PriceAnalyticsChart(historyData: fullHistory, targetProductTitle: title)),
                          ],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics, size: 18),
                  label: const Text('View Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF0F172A),
      child: const Center(child: Icon(Icons.public, size: 100, color: Colors.white10)),
    );
  }
}

// --- SCREENS 2 & 3: AI COPILOT & CLUSTER CONFIG ---
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});
  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'sender': 'ai', 'text': 'Graviton Intelligence online. What are we tracking today?'}
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
        setState(() { _messages.add({'sender': 'ai', 'text': data['graviton_response']}); });
      }
    } catch (e) {
      setState(() { _messages.add({'sender': 'ai', 'text': 'Network Error.'}); });
    }
    setState(() { _isThinking = false; });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Copilot", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isAi = _messages[index]['sender'] == 'ai';
                return Align(
                  alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isAi ? const Color(0xFF1E293B) : Colors.cyanAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_messages[index]['text']!, style: TextStyle(color: isAi ? Colors.white : Colors.cyanAccent, fontSize: 15)),
                  ),
                );
              },
            ),
          ),
          if (_isThinking) const CircularProgressIndicator(color: Colors.cyanAccent),
          Container(
            margin: const EdgeInsets.only(left: 20, right: 20, bottom: 120),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Query the vault...', border: InputBorder.none, hintStyle: TextStyle(color: Colors.white30)),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.cyanAccent), onPressed: _sendMessage)
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ClusterTopologyScreen extends StatelessWidget {
  const ClusterTopologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Cluster Config", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Node', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2)),
                  SizedBox(height: 8),
                  Text(API_URL, style: TextStyle(color: Colors.cyanAccent, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PriceAnalyticsChart extends StatelessWidget {
  final List<dynamic> historyData;
  final String targetProductTitle;

  const PriceAnalyticsChart({super.key, required this.historyData, required this.targetProductTitle});

  List<FlSpot> _generateChartData() {
    List<FlSpot> spots = [];
    double xIndex = 0;
    var productHistory = historyData.where((item) => (item['title'] ?? '').toString().contains(targetProductTitle)).toList();

    for (var item in productHistory.reversed) {
      String summary = item['raw_summary'] ?? '';
      final match = RegExp(r'\d+').firstMatch(summary);
      if (match != null) {
        spots.add(FlSpot(xIndex, double.parse(match.group(0)!)));
        xIndex++;
      }
    }
    if (spots.isEmpty) spots.add(const FlSpot(0, 0));
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
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
              barWidth: 4,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.cyanAccent.withOpacity(0.2)),
            ),
          ],
        ),
      ),
    );
  }
}