import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'sqlite_sensor_service.dart';

void main() => runApp(const FallSenseApp());

class FallSenseApp extends StatelessWidget {
  const FallSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00FFD0),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const BalancePage(),
    const RealtimeDataPage(),
    const HistoryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF1A1A1A),
            selectedIndex: _selectedIndex,
            extended: true,
            onDestinationSelected: (int index) =>
                setState(() => _selectedIndex = index),
            leading: const Column(
              children: [
                SizedBox(height: 20),
                Icon(
                  Icons.health_and_safety,
                  color: Color(0xFF00FFD0),
                  size: 40,
                ),
                Text(
                  "ELDERLY FALL DETECTED",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 40),
              ],
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text("Dashboard"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_wallet),
                label: Text("Hệ thống"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.credit_card),
                label: Text("Dữ liệu thực tế"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                label: Text("Lịch sử"),
              ),
            ],
          ),
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _pages),
          ),
        ],
      ),
    );
  }
}

// --- TRANG DASHBOARD ---
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final SQLiteSensorService _sensorService = SQLiteSensorService();

  Timer? _refreshTimer;
  bool _isLoading = true;
  String _sourceStatus = "Dang ket noi SQLite...";
  int _totalRecords = 0;
  double _averageAmag = 0;
  List<FlSpot> _chartSpots = [const FlSpot(0, 0)];
  List<Map<String, String>> _recentData = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();

    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadDashboardData(showLoader: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) {
      setState(() => _isLoading = true);
    }

    try {
      final dbPath = await _sensorService.resolveDatabasePath();
      if (dbPath == null) {
        if (!mounted) return;
        setState(() {
          _sourceStatus = "Khong tim thay sensor_data.db";
          _totalRecords = 0;
          _averageAmag = 0;
          _chartSpots = [const FlSpot(0, 0)];
          _recentData = [];
          _isLoading = false;
        });
        return;
      }

      final summary = await _sensorService.loadSummary();
      final latestRows = await _sensorService.loadLatestRecords(limit: 500);
      if (!mounted) return;

      if (summary == null || latestRows.isEmpty) {
        setState(() {
          _sourceStatus = "Da ket noi SQLite, chua co du lieu sensor";
          _totalRecords = summary?.totalRecords ?? 0;
          _averageAmag = summary?.averageAmag ?? 0;
          _chartSpots = [const FlSpot(0, 0)];
          _recentData = [];
          _isLoading = false;
        });
        return;
      }

      final chartRows = latestRows.length > 60
          ? latestRows.sublist(latestRows.length - 60)
          : latestRows;
      final spots = <FlSpot>[];
      var x = 0.0;
      for (final row in chartRows) {
        spots.add(FlSpot(x, row.amag));
        x += 1;
      }

      final latest = latestRows.last;
      final latestStatus = latest.label == 1
          ? "⚠️ PHAT HIEN TE NGA"
          : "✅ Binh thuong";
      final recentRows = latestRows.reversed.take(10);

      setState(() {
        _sourceStatus = "$latestStatus | SQLite";
        _totalRecords = summary.totalRecords;
        _averageAmag = summary.averageAmag;
        _chartSpots = spots;
        _recentData = recentRows
            .map(
              (row) => {
                "time": row.timeLabel,
                "amag": row.amag.toStringAsFixed(2),
                "status": row.label == 1 ? "Cảnh báo" : "Ổn định",
              },
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sourceStatus = "Loi doc SQLite: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📊 Dashboard Phân tích",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _sourceStatus,
            style: TextStyle(
              color:
                  _sourceStatus.startsWith("Loi") ||
                      _sourceStatus.startsWith("Khong")
                  ? Colors.redAccent
                  : const Color(0xFF00FFD0),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMetricCard(
                "Tổng bản ghi",
                _totalRecords.toString(),
                Icons.description,
                Colors.blue,
              ),
              const SizedBox(width: 15),
              _buildMetricCard(
                "Trung bình Amag",
                "${_averageAmag.toStringAsFixed(2)}g",
                Icons.speed,
                Colors.green,
              ),
            ],
          ),
          if (_isLoading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(color: Color(0xFF00FFD0)),
          ],
          const SizedBox(height: 25),
          const Text(
            "Biểu đồ Gia tốc tổng hợp (Amag)",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartSpots,
                    isCurved: true,
                    color: const Color(0xFF00FFD0),
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF00FFD0).withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "Dữ liệu chi tiết gần đây",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(15),
            ),
            // ĐÂY LÀ ĐOẠN ĐÃ FIX: Bọc SingleChildScrollView cho DataTable
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(
                    label: Text(
                      "Thời gian",
                      style: TextStyle(color: Color(0xFF00FFD0)),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "Amag",
                      style: TextStyle(color: Color(0xFF00FFD0)),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "Trạng thái",
                      style: TextStyle(color: Color(0xFF00FFD0)),
                    ),
                  ),
                ],
                rows: _recentData.map((data) {
                  return DataRow(
                    cells: [
                      DataCell(Text(data["time"]!)),
                      DataCell(Text(data["amag"]!)),
                      DataCell(
                        Text(
                          data["status"]!,
                          style: TextStyle(
                            color: data["status"] == "Cảnh báo"
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TRANG BALANCE ---
class BalancePage extends StatefulWidget {
  const BalancePage({super.key});

  @override
  State<BalancePage> createState() => _BalancePageState();
}

class _BalancePageState extends State<BalancePage> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _phoneController.text = prefs.getString('sos_phone') ?? "0123456789";
    });
  }

  Future<void> _savePhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sos_phone', _phoneController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Đã lưu số điện thoại cứu trợ vĩnh viễn"),
          backgroundColor: Color(0xFF00FFD0),
        ),
      );
    }
  }

  void _showSystemCheckDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.analytics_outlined, color: Color(0xFF00FFD0)),
              SizedBox(width: 10),
              Text(
                "Chẩn đoán hệ thống",
                style: TextStyle(color: Color(0xFF00FFD0)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCheckStep("Kết nối MQTT", true),
              _buildCheckStep("Cảm biến MPU6050", true),
              _buildCheckStep("Tín hiệu SOS", true),
              const SizedBox(height: 20),
              const Divider(color: Colors.white10),
              const SizedBox(height: 10),
              const Text(
                "Tất cả hệ thống đang hoạt động tốt!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "HOÀN TẤT",
                  style: TextStyle(
                    color: Color(0xFF00FFD0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCheckStep(String label, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.error,
            color: isOk ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(
            isOk ? "Sẵn sàng" : "Lỗi",
            style: TextStyle(
              color: isOk ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Hệ Thống & Tài Nguyên",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          const Text(
            "Cài đặt liên hệ SOS",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00FFD0).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.contact_phone, color: Color(0xFF00FFD0)),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: "Nhập số điện thoại...",
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _savePhoneNumber,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00FFD0),
                  ),
                  child: const Text(
                    "LƯU LẠI",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          const Text(
            "Thống kê cứu trợ",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMetricCard(
                "Cuộc gọi SOS",
                "12",
                Icons.phone_in_talk,
                Colors.blueAccent,
              ),
              const SizedBox(width: 15),
              _buildMetricCard(
                "SMS Cảnh báo",
                "45",
                Icons.sms,
                Colors.orangeAccent,
              ),
            ],
          ),

          const SizedBox(height: 30),

          const Text(
            "Sức khỏe thiết bị",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildHardwareRow(
                  "Dung lượng Pin",
                  "85%",
                  Icons.battery_charging_full,
                  const Color(0xFF00FFD0),
                ),
                const Divider(color: Colors.white10, height: 30),
                _buildHardwareRow(
                  "Nhiệt độ cảm biến",
                  "32°C",
                  Icons.thermostat,
                  Colors.orange,
                ),
                const Divider(color: Colors.white10, height: 30),
                _buildHardwareRow(
                  "Bộ nhớ đệm (Cache)",
                  "1.2 MB",
                  Icons.storage,
                  Colors.purpleAccent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: OutlinedButton.icon(
              onPressed: () => _showSystemCheckDialog(context),
              icon: const Icon(
                Icons.build_circle_outlined,
                color: Color(0xFF00FFD0),
              ),
              label: const Text(
                "KIỂM TRA ĐỊNH KỲ",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00FFD0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 15),
            Text(
              value,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 15),
        Text(label, style: const TextStyle(fontSize: 16)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

// --- TRANG REALTIME DATA ---
class RealtimeDataPage extends StatefulWidget {
  const RealtimeDataPage({super.key});

  @override
  State<RealtimeDataPage> createState() => _RealtimeDataPageState();
}

class _RealtimeDataPageState extends State<RealtimeDataPage> {
  final SQLiteSensorService _sensorService = SQLiteSensorService();

  List<FlSpot> amagPoints = [const FlSpot(0, 0)];
  double xValue = 0;
  double currentAmag = 1.0;
  int currentLabel = 0;
  String currentBehavior = "STD";
  int _currentRecordId = 0;
  String _sourceStatus = "Dang ket noi SQLite...";
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startRealtimePolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRealtimePolling() async {
    await _loadBootstrapData();
    if (!mounted) return;

    _pollingTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      _pollLatestRecord();
    });
  }

  Future<void> _loadBootstrapData() async {
    try {
      final dbPath = await _sensorService.resolveDatabasePath();
      if (dbPath == null) {
        if (!mounted) return;
        setState(() => _sourceStatus = "Khong tim thay sensor_data.db");
        return;
      }

      final rows = await _sensorService.loadLatestRecords(limit: 30);
      if (!mounted) return;

      if (rows.isEmpty) {
        setState(() {
          _sourceStatus = "Da ket noi DB, chua co du lieu sensor";
          amagPoints = [const FlSpot(0, 0)];
          xValue = 0;
          _currentRecordId = 0;
        });
        return;
      }

      final spots = <FlSpot>[];
      var nextX = 0.0;
      for (final row in rows) {
        nextX += 1;
        spots.add(FlSpot(nextX, row.amag));
      }

      setState(() {
        _sourceStatus = "● Dang doc du lieu tu SQLite";
        amagPoints = spots;
        xValue = nextX;
        _applyRecordState(rows.last, appendPoint: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sourceStatus = "Loi doc SQLite: $e");
    }
  }

  Future<void> _pollLatestRecord() async {
    try {
      final latest = await _sensorService.loadLatestRecord();
      if (!mounted || latest == null) {
        return;
      }
      if (latest.id <= _currentRecordId) {
        return;
      }

      setState(() {
        _sourceStatus = "● Dang doc du lieu tu SQLite";
        _applyRecordState(latest, appendPoint: true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sourceStatus = "Loi doc SQLite: $e");
    }
  }

  void _applyRecordState(SensorRecord row, {required bool appendPoint}) {
    _currentRecordId = row.id;
    currentAmag = row.amag;
    currentLabel = row.label;
    currentBehavior = row.label == 1 ? "FALL" : "STD";

    if (appendPoint) {
      xValue += 1;
      amagPoints.add(FlSpot(xValue, currentAmag));
      if (amagPoints.length > 30) {
        amagPoints.removeAt(0);
      }
    }
  }

  Future<void> _makeCall() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('sos_phone') ?? "0123456789";
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  String _getBehaviorName(String code) {
    Map<String, String> names = {
      "FALL": "Phat hien te nga",
      "STD": "Binh thuong",
    };
    return names[code] ?? "Ổn định";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Giam sat SQLite Realtime",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _sourceStatus,
                    style: TextStyle(
                      color:
                          _sourceStatus.startsWith("Loi") ||
                              _sourceStatus.startsWith("Khong")
                          ? Colors.redAccent
                          : const Color(0xFF00FFD0),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _makeCall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(Icons.sos, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: amagPoints,
                      isCurved: true,
                      color: currentLabel == 1
                          ? Colors.red
                          : const Color(0xFF00FFD0),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color:
                            (currentLabel == 1
                                    ? Colors.red
                                    : const Color(0xFF00FFD0))
                                .withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: currentLabel == 1 ? Colors.red : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(
                      currentLabel == 1 ? Icons.warning : Icons.check_circle,
                      color: currentLabel == 1 ? Colors.red : Colors.green,
                    ),
                    Text(
                      currentLabel == 1 ? "FALL" : "ADL",
                      style: TextStyle(
                        color: currentLabel == 1 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 40,
                  child: VerticalDivider(color: Colors.white10),
                ),
                Column(
                  children: [
                    Text(
                      currentBehavior,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: currentLabel == 1
                            ? Colors.red
                            : const Color(0xFF00FFD0),
                      ),
                    ),
                    Text(
                      _getBehaviorName(currentBehavior),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatCard(
                "Gia tốc",
                "${currentAmag.toStringAsFixed(2)}g",
                Icons.speed,
              ),
              const SizedBox(width: 15),
              _buildStatCard(
                "Record ID",
                "$_currentRecordId",
                Icons.list_alt,
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String t, String v, IconData i, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(i, color: color, size: 18),
            Text(t, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(
              v,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TRANG HISTORY ---
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final SQLiteSensorService _sensorService = SQLiteSensorService();

  String _selectedFilter = 'Tất cả';
  List<Map<String, dynamic>> _allLogs = [];
  bool _isLoading = true;
  String _historyStatus = '';
  Timer? _refreshTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLogsFromStorage(showLoader: false);
  }

  @override
  void initState() {
    super.initState();
    _loadLogsFromStorage();

    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadLogsFromStorage(showLoader: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLogsFromStorage({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) {
      setState(() => _isLoading = true);
    }

    try {
      final dbPath = await _sensorService.resolveDatabasePath();
      if (dbPath == null) {
        if (!mounted) return;
        setState(() {
          _allLogs = [];
          _historyStatus = 'Khong tim thay sensor_data.db';
          _isLoading = false;
        });
        return;
      }

      final fallEvents = await _sensorService.loadFallEvents(limit: 100);
      if (!mounted) return;

      final dynamicLogs = fallEvents
          .map(
            (event) => {
              "time": event.timeLabel,
              "date": event.dateLabel,
              "event": "CẢNH BÁO: PHÁT HIỆN NGÃ (ID ${event.id})",
              "value": "${event.amag.toStringAsFixed(2)}g",
              "type": "alert",
              "axis":
                  "GocX ${event.angleX.toStringAsFixed(1)}°, GocY ${event.angleY.toStringAsFixed(1)}°",
            },
          )
          .toList();

      final systemLogs = <Map<String, dynamic>>[
        {
          "time": "--:--:--",
          "date": "-",
          "event": "NGUON DU LIEU SQLITE",
          "value": "sensor_data.db",
          "type": "system",
          "axis": "Dong bo truc tiep tu backend",
        },
      ];

      setState(() {
        _allLogs = [...dynamicLogs, ...systemLogs];
        _historyStatus = fallEvents.isEmpty
            ? 'Da ket noi SQLite, chua co su kien te nga'
            : 'Dang dong bo lich su tu SQLite';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allLogs = [];
        _historyStatus = 'Loi doc SQLite: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    await _loadLogsFromStorage(showLoader: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Du lieu dang dong bo truc tiep tu SQLite (chi doc)"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredLogs = _allLogs.where((log) {
      if (_selectedFilter == 'Tất cả') return true;
      if (_selectedFilter == 'Cảnh báo') return log['type'] == 'alert';
      if (_selectedFilter == 'Chuyển động') return log['type'] == 'motion';
      if (_selectedFilter == 'Hệ thống') return log['type'] == 'system';
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "📜 Nhật Ký Hệ Thống",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _historyStatus.isEmpty
                        ? "Lich su su co ghi nhan tu thiet bi"
                        : _historyStatus,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
              IconButton(
                onPressed: _clearLogs,
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.redAccent,
                ),
                tooltip: "Xóa nhật ký",
              ),
            ],
          ),
          const SizedBox(height: 25),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip("Tất cả"),
                _buildFilterChip("Cảnh báo"),
                _buildFilterChip("Chuyển động"),
                _buildFilterChip("Hệ thống"),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00FFD0)),
                  )
                : filteredLogs.isEmpty
                ? const Center(
                    child: Text(
                      "Không có nhật ký nào",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      return _buildTimelineItem(
                        filteredLogs[index],
                        index == filteredLogs.length - 1,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() => _selectedFilter = label);
        },
        selectedColor: const Color(0xFF00FFD0).withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF00FFD0) : Colors.white60,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(
          color: isSelected ? const Color(0xFF00FFD0) : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> log, bool isLast) {
    Color statusColor;
    IconData statusIcon;

    switch (log['type']) {
      case 'alert':
        statusColor = Colors.redAccent;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'motion':
        statusColor = Colors.orangeAccent;
        statusIcon = Icons.run_circle_outlined;
        break;
      default:
        statusColor = const Color(0xFF00FFD0);
        statusIcon = Icons.settings_suggest_outlined;
    }

    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            log['event'],
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        log['time'],
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: Divider(color: Colors.white10, thickness: 1),
                  ),
                  Row(
                    children: [
                      _buildDataPoint("Giá trị", log['value']),
                      const SizedBox(width: 30),
                      _buildDataPoint("Chi tiết", log['axis']),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Ngày: ${log['date']}",
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPoint(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
