import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
        useMaterial3: true,
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
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.travel_explore), label: 'Trends'),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'AI Copilot'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
        ],
      ),
    );
  }
}

// --- SCREEN 1: THE UNIVERSAL TRENDS FEED (WITH HORIZONTAL FILTER) ---
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
        title: const Text('Live Platform Trends', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
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
                      border: Border.all(color: isSelected ? Colors.transparent : Colors.cyanAccent.withOpacity(0.3)),
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
                    ? const Center(child: Text("No trends found for this platform.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
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
                                  item['image_url'] != null && item['image_url'].toString().isNotEmpty
                                      ? Image.network(
                                          item['image_url'],
                                          width: double.infinity,
                                          height: 220,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => 
                                              Container(height: 220, color: Colors.black26, child: const Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                                        )
                                      : Container(height: 220, color: Colors.black26, child: const Icon(Icons.shopping_bag, size: 60, color: Colors.cyanAccent)),
                                  
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
                                            item['source'] ?? 'TRENDING',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.cyanAccent, letterSpacing: 1.2),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          item['title'] ?? 'Unknown Trend', 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white, height: 1.2),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item['raw_summary'] ?? '', 
                                          style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
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
  final List<Map<String, String>> _messages = [{'sender': 'ai', 'text': 'Hello. I am connected to the universal trend vault. Ask me to analyze the latest shopping or social trends.'}];
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
      appBar: AppBar(backgroundColor: const Color(0xFF1E293B), title: const Text('Gemini Intelligence', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent))),
      body: Column(
        children: [
          Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _messages.length, itemBuilder: (context, index) {
            bool isAi = _messages[index]['sender'] == 'ai';
            return Align(alignment: isAi ? Alignment.centerLeft : Alignment.centerRight, child: Container(margin: const EdgeInsets.symmetric(vertical: 6), padding: const EdgeInsets.all(12), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80), decoration: BoxDecoration(color: isAi ? const Color(0xFF1E293B) : Colors.cyanAccent, borderRadius: BorderRadius.circular(12)), child: Text(_messages[index]['text']!, style: TextStyle(color: isAi ? Colors.white : const Color(0xFF0F172A), fontSize: 14))));
          })),
          if (_isThinking) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.cyanAccent)),
          Container(padding: const EdgeInsets.all(12), color: const Color(0xFF1E293B), child: Row(children: [Expanded(child: TextField(controller: _controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Ask AI Copilot...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none))), IconButton(icon: const Icon(Icons.send, color: Colors.cyanAccent), onPressed: _sendMessage)])),
        ],
      ),
    );
  }
}

// --- SCREEN 3: CONFIG ---
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
      appBar: AppBar(backgroundColor: const Color(0xFF1E293B), title: const Text('System Config', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('SECURITY PREFERENCES', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
          const SizedBox(height: 12),
          Card(color: const Color(0xFF1E293B), child: SwitchListTile(title: const Text('Strict HTTPS Mode'), activeColor: Colors.cyanAccent, value: _strictEncryption, onChanged: (val) { setState(() { _strictEncryption = val; }); })),
          const SizedBox(height: 24),
          const Text('BACKEND CONNECTION', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16), 
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)), 
            child: const Text('Cloud Target: \n$API_URL', style: TextStyle(color: Colors.cyanAccent, fontFamily: 'monospace')),
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
              // 1. Show the visual feedback IMMEDIATELY when tapped
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cloud override initiated! Scrapers are running in the background...'))
              );
              // 2. Fire the network request into the void without freezing the app
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