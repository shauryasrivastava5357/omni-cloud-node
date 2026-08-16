import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Node',
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
    const ConsoleScreen(),
    const AnalyticsQueryScreen(),
    const ClusterTopologyScreen(),
    const AIAssistantScreen(),
    const SettingsScreen(),
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
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Console'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Query'),
          BottomNavigationBarItem(icon: Icon(Icons.dns), label: 'Nodes'),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'AI'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
        ],
      ),
    );
  }
}

// --- SCREEN 1: CONSOLE MONITOR ---
class ConsoleScreen extends StatefulWidget {
  const ConsoleScreen({super.key});

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  int _streams = 0;
  int _cpuUsage = 14;
  int _latency = 24;
  bool _isAutoStreaming = false;
  Timer? _streamTimer;
  final List<String> _logs = ['System Initialized. Node 01 ready.'];

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '[${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}] $message');
      if (_logs.length > 5) _logs.removeLast();
    });
  }

  Future<void> _fetchLiveTelemetry() async {
    try {
      final response = await http.get(Uri.parse('http://10.0.2.2:5000/api/telemetry'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _cpuUsage = data['cpu_load'];
          _latency = data['latency'];
        });
        _addLog('API SYNC: CPU at $_cpuUsage%, Latency $_latency ms');
      }
    } catch (e) {
      _addLog('API ERROR: Backend unreachable.');
    }
  }

  void _incrementManual() {
    setState(() { _streams++; });
    _fetchLiveTelemetry();
  }

  void _runBatch() {
    setState(() { _streams += 25; });
    _fetchLiveTelemetry();
  }

  void _toggleAutoStream() {
    setState(() {
      _isAutoStreaming = !_isAutoStreaming;
    });

    if (_isAutoStreaming) {
      _addLog('Live API Sync stream started.');
      _streamTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        setState(() { _streams += 5; });
        _fetchLiveTelemetry(); 
      });
    } else {
      _streamTimer?.cancel();
      _addLog('Live API Sync stream halted.');
    }
  }

  void _resetMetrics() {
    _streamTimer?.cancel();
    setState(() {
      _streams = 0;
      _cpuUsage = 14;
      _latency = 24;
      _isAutoStreaming = false;
      _logs.clear();
      _logs.add('System reset. Metrics cleared.');
    });
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progressValue = (_streams % 100) / 100.0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Cloud Node Console', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            Card(
              color: const Color(0xFF1E293B),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricColumn(Icons.memory, 'Node 01', 'ONLINE', Colors.greenAccent),
                    _metricColumn(Icons.speed, 'Latency', '$_latency ms', Colors.cyanAccent),
                    _metricColumn(Icons.bolt, 'CPU Load', '$_cpuUsage%', _cpuUsage > 75 ? Colors.orangeAccent : Colors.lightGreenAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.cyanAccent.withOpacity(0.3))),
              child: Column(
                children: [
                  const Text('PROCESSED INGESTION STREAMS', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('$_streams', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progressValue, backgroundColor: Colors.black26, color: Colors.cyanAccent, minHeight: 6),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: const Color(0xFF0F172A), minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _runBatch,
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Execute +25 Stream Batch', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: BorderSide(color: _isAutoStreaming ? Colors.redAccent : Colors.cyanAccent), minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _toggleAutoStream,
              icon: Icon(_isAutoStreaming ? Icons.stop : Icons.sync, color: _isAutoStreaming ? Colors.redAccent : Colors.cyanAccent),
              label: Text(_isAutoStreaming ? 'Halt Live API Sync' : 'Start Live API Sync', style: TextStyle(color: _isAutoStreaming ? Colors.redAccent : Colors.cyanAccent, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SYSTEM EVENT LOG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent, letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  ..._logs.map((log) => Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: Text(log, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white70)))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(IconData icon, String label, String value, Color statusColor) {
    return Column(
      children: [
        Icon(icon, color: Colors.cyanAccent, size: 24),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

// --- SCREEN 2: DATA QUERY ANALYTICS ---
class AnalyticsQueryScreen extends StatefulWidget {
  const AnalyticsQueryScreen({super.key});

  @override
  State<AnalyticsQueryScreen> createState() => _AnalyticsQueryScreenState();
}

class _AnalyticsQueryScreenState extends State<AnalyticsQueryScreen> {
  String _queryResult = 'Select a query or dataset to execute.';
  bool _isLoading = false;
  List<double> _barHeights = List.filled(8, 20.0);
  Timer? _telemetryTimer;

  @override
  void initState() {
    super.initState();
    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _barHeights = List.generate(8, (index) => Random().nextDouble() * 100 + 10);
      });
    });
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _runQuery(String queryType) async {
    setState(() {
      _isLoading = true;
      _queryResult = 'Connecting to Vault...';
    });

    if (queryType == 'sql') {
      try {
        final response = await http.get(Uri.parse('http://10.0.2.2:5000/api/history'));
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          if (data.isEmpty) {
             setState(() { _queryResult = 'VAULT EMPTY.\nGo to the Console and generate data first!'; _isLoading = false; });
            return;
          }
          String formattedData = '--- IMMUTABLE LEDGER DATA ---\n\n';
          for (var row in data) {
            formattedData += '[${row['timestamp']}]\nCPU Load: ${row['cpu_load']}%\nLatency: ${row['latency']}ms\n\n';
          }
          setState(() { _queryResult = formattedData; _isLoading = false; });
        }
      } catch (e) {
        setState(() { _queryResult = 'API ERROR: Database unreachable.'; _isLoading = false; });
      }
    } else if (queryType == 'ml') {
      // NEW: AI / ML BRAIN INTEGRATION
      try {
        final response = await http.get(Uri.parse('http://10.0.2.2:5000/api/analyze'));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          String mlResult = '--- ML ANOMALY DETECTION ---\n\n';
          mlResult += 'Records Analyzed: ${data['total_records_analyzed']}\n';
          mlResult += 'Historical Mean: ${data['historical_mean']}%\n';
          mlResult += 'Volatility (Std Dev): ${data['standard_deviation']}\n';
          mlResult += 'Latest CPU Load: ${data['latest_cpu']}%\n\n';
          
          if (data['anomaly_detected']) {
            mlResult += '⚠️ ALERT: STATISTICAL ANOMALY DETECTED!\nLoad exceeds expected variance threshold.';
          } else {
            mlResult += '✅ STATUS NORMAL: Latest load is within expected historical variance.';
          }

          setState(() { _queryResult = mlResult; _isLoading = false; });
        } else if (response.statusCode == 400) {
          setState(() { _queryResult = 'ML ERROR: Not enough data points.\nSync more telemetry data first!'; _isLoading = false; });
        }
      } catch (e) {
        setState(() { _queryResult = 'API ERROR: Could not reach the AI Brain.\nIs Python running?'; _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Analytics & Query Terminal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LIVE DATA THROUGHPUT', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              height: 120,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _barHeights.map((height) => AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 24,
                  height: height,
                  decoration: BoxDecoration(
                    color: height > 80 ? Colors.cyanAccent : Colors.cyan.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 32),
            const Text('DATABASE & ML PIPELINES', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.cyanAccent, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => _runQuery('sql'),
              icon: const Icon(Icons.storage),
              label: const Text('Fetch Real Database Logs'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.cyanAccent, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => _runQuery('ml'),
              icon: const Icon(Icons.psychology),
              label: const Text('Evaluate AI/ML Model Metrics'),
            ),
            const SizedBox(height: 32),
            const Text('OUTPUT TERMINAL', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.cyanAccent.withOpacity(0.3))),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                    : SingleChildScrollView(child: Text(_queryResult, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.cyanAccent))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- SCREEN 3: CLUSTER TOPOLOGY ---
class ClusterTopologyScreen extends StatefulWidget {
  const ClusterTopologyScreen({super.key});
  @override
  State<ClusterTopologyScreen> createState() => _ClusterTopologyScreenState();
}
class _ClusterTopologyScreenState extends State<ClusterTopologyScreen> {
  final List<Map<String, dynamic>> _nodes = [
    {'name': 'Node 01 (Mumbai-A)', 'status': 'ONLINE', 'load': 34, 'active': true},
    {'name': 'Node 02 (Virginia-B)', 'status': 'ONLINE', 'load': 62, 'active': true},
    {'name': 'Node 03 (Frankfurt-C)', 'status': 'STANDBY', 'load': 5, 'active': false},
  ];
  void _toggleNode(int index) {
    setState(() {
      _nodes[index]['active'] = !_nodes[index]['active'];
      _nodes[index]['status'] = _nodes[index]['active'] ? 'ONLINE' : 'STANDBY';
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF1E293B), title: const Text('Cluster Nodes Manager', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent))),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _nodes.length,
        itemBuilder: (context, index) {
          final node = _nodes[index];
          return Card(
            color: const Color(0xFF1E293B),
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.dns, color: node['active'] ? Colors.cyanAccent : Colors.grey, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(node['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('Status: ${node['status']} | Load: ${node['load']}%', style: TextStyle(color: node['active'] ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(value: node['active'], activeColor: Colors.cyanAccent, onChanged: (val) => _toggleNode(index)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- SCREEN 4: AI COPILOT ---
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});
  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}
class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [{'sender': 'ai', 'text': 'Hello Chief! I am your Node Copilot. Ask me anything about your cluster architecture.'}];
  void _sendMessage() {
    if (_controller.text.isEmpty) return;
    String userText = _controller.text;
    setState(() {
      _messages.add({'sender': 'user', 'text': userText});
      _controller.clear();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      setState(() { _messages.add({'sender': 'ai', 'text': 'Analysis complete: All node sockets are performing optimally.'}); });
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF1E293B), title: const Text('AI Copilot & Diagnostics', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent))),
      body: Column(
        children: [
          Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _messages.length, itemBuilder: (context, index) {
            bool isAi = _messages[index]['sender'] == 'ai';
            return Align(alignment: isAi ? Alignment.centerLeft : Alignment.centerRight, child: Container(margin: const EdgeInsets.symmetric(vertical: 6), padding: const EdgeInsets.all(12), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), decoration: BoxDecoration(color: isAi ? const Color(0xFF1E293B) : Colors.cyanAccent, borderRadius: BorderRadius.circular(12)), child: Text(_messages[index]['text']!, style: TextStyle(color: isAi ? Colors.white : const Color(0xFF0F172A), fontSize: 13))));
          })),
          Container(padding: const EdgeInsets.all(12), color: const Color(0xFF1E293B), child: Row(children: [Expanded(child: TextField(controller: _controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Ask AI Copilot...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none))), IconButton(icon: const Icon(Icons.send, color: Colors.cyanAccent), onPressed: _sendMessage)])),
        ],
      ),
    );
  }
}

// --- SCREEN 5: SETTINGS ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushAlerts = true;
  bool _strictEncryption = true;
  String _selectedRegion = 'ap-south-1 (Mumbai)';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF1E293B), title: const Text('Node Settings & Config', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('CLUSTER PREFERENCES', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
          const SizedBox(height: 12),
          Card(color: const Color(0xFF1E293B), child: SwitchListTile(title: const Text('High CPU Alerts'), activeColor: Colors.cyanAccent, value: _pushAlerts, onChanged: (val) { setState(() { _pushAlerts = val; }); })),
          Card(color: const Color(0xFF1E293B), child: SwitchListTile(title: const Text('Strict TLS'), activeColor: Colors.cyanAccent, value: _strictEncryption, onChanged: (val) { setState(() { _strictEncryption = val; }); })),
          const SizedBox(height: 24),
          const Text('DEPLOYMENT REGION', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _selectedRegion, dropdownColor: const Color(0xFF1E293B), icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent), items: ['ap-south-1 (Mumbai)', 'us-east-1 (N. Virginia)', 'eu-central-1 (Frankfurt)'].map((String value) { return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(color: Colors.white))); }).toList(), onChanged: (String? newValue) { setState(() { _selectedRegion = newValue!; }); }))),
        ],
      ),
    );
  }
}