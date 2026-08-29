import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';

const String API_URL = 'https://graviton-api-h20t.onrender.com';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const GravitonApp());
}

class GravitonApp extends StatelessWidget {
  const GravitonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Graviton Analytics',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFEBEBF0), 
        primaryColor: const Color(0xFF1C1C1E),
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007AFF),
          secondary: Color(0xFF8E8E93),
          surface: Colors.white,
        ),
      ),
      home: const MainDashboard(),
    );
  }
}

// --- MASTER CONTROLLER & PLATINUM DOCK ---
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 1; 
  List<dynamic> _feedItems = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchFeedData();
  }

  Future<void> _fetchFeedData() async {
    try {
      final response = await http.get(Uri.parse('$API_URL/history')).timeout(const Duration(seconds: 15));
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

  // Triggers the Render server to scrape the web, then re-fetches the database
  Future<void> _triggerCloudSync() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Commanding cloud node to fetch fresh trends...", style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF1C1C1E),
        duration: Duration(seconds: 3),
      )
    );
    try {
      await http.get(Uri.parse('$API_URL/trending')); 
      await Future.delayed(const Duration(seconds: 2)); 
      await _fetchFeedData();
    } catch (e) {
      // ignore
    }
  }

  void _changeFilterAndNavigate(String filter) {
    setState(() {
      _selectedFilter = filter;
      _currentIndex = 0; 
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      MagazineFeedScreen(
        feedItems: _feedItems, 
        isLoading: _isLoading, 
        selectedFilter: _selectedFilter,
        onClearFilter: () => setState(() => _selectedFilter = 'ALL'),
        onRefresh: _triggerCloudSync,
      ),
      PlatformMatrixScreen(
        feedItems: _feedItems, 
        onPlatformSelected: _changeFilterAndNavigate,
      ),
      const AIAssistantScreen(),
      const ClusterTopologyScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: screens[_currentIndex],
          ),
          
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  height: 75,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.65), 
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 15))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.view_day_rounded, "Feed"),
                      _buildNavItem(1, Icons.grid_view_rounded, "Explore"),
                      _buildNavItem(2, Icons.graphic_eq_rounded, "Copilot"),
                      _buildNavItem(3, Icons.insert_chart_rounded, "Data"),
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

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1C1C1E) : Colors.transparent, 
          borderRadius: BorderRadius.circular(30),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF8E8E93), size: 24),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ]
          ],
        ),
      ),
    );
  }
}

// --- SCREEN 1: MAGAZINE FEED (NEW ARCHITECTURE) ---
class MagazineFeedScreen extends StatelessWidget {
  final List<dynamic> feedItems;
  final bool isLoading;
  final String selectedFilter;
  final VoidCallback onClearFilter;
  final Future<void> Function() onRefresh;

  const MagazineFeedScreen({
    super.key, 
    required this.feedItems, 
    required this.isLoading,
    required this.selectedFilter,
    required this.onClearFilter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    List<dynamic> filteredItems = selectedFilter == 'ALL'
        ? feedItems
        : feedItems.where((item) => (item['source'] ?? '').toString().toUpperCase() == selectedFilter).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedFilter == 'ALL' ? 'Live Stream' : selectedFilter,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF1C1C1E), letterSpacing: -1.0),
                ),
                if (selectedFilter != 'ALL')
                  GestureDetector(
                    onTap: onClearFilter,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                      child: const Icon(Icons.close, color: Color(0xFF1C1C1E), size: 20),
                    ),
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1C1C1E)))
                : filteredItems.isEmpty
                    ? const Center(child: Text("No data in vault. Pull to refresh.", style: TextStyle(color: Color(0xFF8E8E93))))
                    : RefreshIndicator(
                        color: const Color(0xFF1C1C1E),
                        backgroundColor: Colors.white,
                        onRefresh: onRefresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 140), // Clears the dock
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            return MagazineCard(item: filteredItems[index], fullHistory: feedItems);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class MagazineCard extends StatelessWidget {
  final dynamic item;
  final List<dynamic> fullHistory;

  const MagazineCard({super.key, required this.item, required this.fullHistory});

  Color _getPlatformColor(String source) {
    switch (source) {
      case 'AMAZON': return const Color(0xFFFF9900);
      case 'MYNTRA': return const Color(0xFFFF3F6C);
      case 'FLIPKART': return const Color(0xFF2874F0);
      case 'NEWS': return const Color(0xFF34A853);
      case 'INSTAGRAM': return const Color(0xFFE1306C);
      case 'X': return const Color(0xFF14171A);
      case 'YOUTUBE': return const Color(0xFFFF0000);
      default: return const Color(0xFF8E8E93);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = item['title'] ?? 'Unknown Trend';
    final String source = (item['source'] ?? 'TRENDING').toString().toUpperCase();
    final String imageUrl = item['image_url'] ?? '';
    final String summary = item['raw_summary'] ?? '';
    final bool isEcom = source == 'AMAZON' || source == 'MYNTRA' || source == 'FLIPKART';
    final Color pColor = _getPlatformColor(source);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
          const BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 1), 
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Block with Fallback
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl, 
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => _buildImageFallback(source, pColor),
                    )
                  : _buildImageFallback(source, pColor),
            ),
          ),
          
          // Text Content Block
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Platform Tag
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: pColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(source, style: TextStyle(color: pColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0)),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Title
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1E), height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                
                // Summary
                Text(summary, style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 20),
                
                // Action Buttons
                Row(
                  children: [
                    if (isEcom)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1C1C1E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _showAnalyticsModal(context, title, fullHistory),
                          icon: const Icon(Icons.analytics_outlined, size: 18),
                          label: const Text("Analytics", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    else 
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEBEBF0),
                            foregroundColor: const Color(0xFF1C1C1E),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final Uri url = Uri.parse(item['url'] ?? '');
                            if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text("View Source", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildImageFallback(String source, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      ),
      child: Center(
        child: Icon(Icons.public, size: 40, color: color.withOpacity(0.5)),
      ),
    );
  }

  void _showAnalyticsModal(BuildContext context, String title, List<dynamic> history) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text("PRICE VELOCITY", style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1E)), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 40),
            Expanded(child: PriceAnalyticsChart(historyData: history, targetProductTitle: title)),
          ],
        ),
      ),
    );
  }
}

// --- SCREEN 2: BENTO GRID EXPLORE ---
class PlatformMatrixScreen extends StatelessWidget {
  final List<dynamic> feedItems;
  final Function(String) onPlatformSelected;

  const PlatformMatrixScreen({super.key, required this.feedItems, required this.onPlatformSelected});

  final List<Map<String, dynamic>> _platforms = const [
    {'name': 'AMAZON', 'icon': Icons.shopping_bag_outlined, 'color': Color(0xFFFF9900)},
    {'name': 'MYNTRA', 'icon': Icons.checkroom_outlined, 'color': Color(0xFFFF3F6C)},
    {'name': 'FLIPKART', 'icon': Icons.local_mall_outlined, 'color': Color(0xFF2874F0)},
    {'name': 'NEWS', 'icon': Icons.article_outlined, 'color': Color(0xFF34A853)},
    {'name': 'INSTAGRAM', 'icon': Icons.camera_alt_outlined, 'color': Color(0xFFE1306C)},
    {'name': 'X', 'icon': Icons.tag, 'color': Color(0xFF14171A)},
    {'name': 'YOUTUBE', 'icon': Icons.play_circle_outline, 'color': Color(0xFFFF0000)},
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 40, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Data Vault", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF1C1C1E), letterSpacing: -1.0)),
                  SizedBox(height: 8),
                  Text("Select a stream to filter telemetry.", style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93))),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final platform = _platforms[index];
                  return InkWell(
                    onTap: () => onPlatformSelected(platform['name']),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
                          const BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 1, offset: Offset(0, 0)), 
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: platform['color'].withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(platform['icon'], size: 28, color: platform['color']),
                          ),
                          const SizedBox(height: 16),
                          Text(platform['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1C1C1E), letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _platforms.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 140)), 
        ],
      ),
    );
  }
}

// --- SCREEN 3: COPILOT ---
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});
  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [{'sender': 'ai', 'text': 'Graviton Intelligence online. Query the vault.'}];
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
      final response = await http.post(Uri.parse('$API_URL/ask'), headers: {'Content-Type': 'application/json'}, body: json.encode({'question': userText}));
      if (response.statusCode == 200) {
        setState(() { _messages.add({'sender': 'ai', 'text': json.decode(response.body)['graviton_response']}); });
      }
    } catch (e) {
      setState(() { _messages.add({'sender': 'ai', 'text': 'Node connection severed.'}); });
    }
    setState(() => _isThinking = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 40, 24, 16),
            child: Align(alignment: Alignment.centerLeft, child: Text("Copilot", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF1C1C1E), letterSpacing: -1.0))),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isAi = _messages[index]['sender'] == 'ai';
                return Align(
                  alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isAi ? Colors.white : const Color(0xFF007AFF),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isAi ? 4 : 20),
                        bottomRight: Radius.circular(isAi ? 20 : 4),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Text(
                      _messages[index]['text']!, 
                      style: TextStyle(color: isAi ? const Color(0xFF1C1C1E) : Colors.white, fontSize: 16, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isThinking) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Color(0xFF1C1C1E), strokeWidth: 2)),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 120), 
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Color(0xFF1C1C1E)),
                      decoration: const InputDecoration(
                        hintText: 'Message Copilot...',
                        hintStyle: TextStyle(color: Color(0xFF8E8E93)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF007AFF),
                      child: IconButton(icon: const Icon(Icons.arrow_upward, color: Colors.white), onPressed: _sendMessage),
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

// --- SCREEN 4: ANALYTICS DASHBOARD ---
class ClusterTopologyScreen extends StatelessWidget {
  const ClusterTopologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 140),
        children: [
          const Text("Analytics", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF1C1C1E), letterSpacing: -1.0)),
          const SizedBox(height: 8),
          const Text("Live node telemetry and performance.", style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93))),
          const SizedBox(height: 32),
          
          _buildInfoCard(title: "Data Vault", value: "842 Records", icon: Icons.storage_rounded, color: const Color(0xFF007AFF)),
          const SizedBox(height: 16),
          _buildInfoCard(title: "Uptime", value: "99.9%", icon: Icons.check_circle_outline_rounded, color: const Color(0xFF34A853)),
          const SizedBox(height: 16),
          _buildInfoCard(title: "Active Node", value: API_URL, icon: Icons.dns_outlined, color: const Color(0xFF1C1C1E)),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- E-COMMERCE PRICE CHART ---
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
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _generateChartData(),
            isCurved: true,
            color: const Color(0xFF1C1C1E), 
            barWidth: 3,
            dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: const Color(0xFF1C1C1E));
            }),
            belowBarData: BarAreaData(
              show: true, 
              gradient: LinearGradient(
                colors: [const Color(0xFF1C1C1E).withOpacity(0.2), Colors.transparent],
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