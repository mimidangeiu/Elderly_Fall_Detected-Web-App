import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'csv_service.dart';
import 'dart:math';

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
  int _selectedIndex = 0; // Mặc định mở Dashboard

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

// --- TRANG DASHBOARD (GIAO DIỆN GIỐNG WEB) ---
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> recentData = [
      {"time": "14:20:01", "amag": "1.02", "status": "Ổn định"},
      {"time": "14:20:05", "amag": "3.85", "status": "Cảnh báo"},
      {"time": "14:20:10", "amag": "0.98", "status": "Ổn định"},
      {"time": "14:20:15", "amag": "1.15", "status": "Ổn định"},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📊 Dashboard Phân tích",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMetricCard(
                "Tổng bản ghi",
                "1,240",
                Icons.description,
                Colors.blue,
              ),
              const SizedBox(width: 15),
              _buildMetricCard(
                "Trung bình Amag",
                "1.05g",
                Icons.speed,
                Colors.green,
              ),
            ],
          ),
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
                    spots: const [
                      FlSpot(0, 1),
                      FlSpot(1, 1.2),
                      FlSpot(2, 1),
                      FlSpot(3, 3.8),
                      FlSpot(4, 1.1),
                      FlSpot(5, 0.9),
                    ],
                    isCurved: true,
                    color: const Color(0xFF00FFD0),
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF00FFD0).withOpacity(0.1),
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
              rows: recentData.map((data) {
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
  // Controller quản lý ô nhập liệu
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedPhone(); // Tự động load số khi mở trang
  }

  // Hàm đọc số từ bộ nhớ máy
  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _phoneController.text = prefs.getString('sos_phone') ?? "0123456789";
    });
  }

  // Hàm lưu số vào bộ nhớ máy
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

  // Giữ nguyên hàm chẩn đoán của bạn
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

          // --- PHẦN MỚI THÊM: QUẢN LÝ LIÊN HỆ ---
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
                color: const Color(0xFF00FFD0).withOpacity(0.2),
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

          // --- GIỮ NGUYÊN PHẦN THỐNG KÊ CỦA BẠN ---
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

          // --- GIỮ NGUYÊN PHẦN SỨC KHỎE THIẾT BỊ CỦA BẠN ---
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

          // --- GIỮ NGUYÊN NÚT KIỂM TRA ĐỊNH KỲ CỦA BẠN ---
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

  // --- GIỮ NGUYÊN CÁC HÀM HELPER WIDGETS ---
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
          border: Border.all(color: color.withOpacity(0.3), width: 1),
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
  // Biến dữ liệu
  List<FlSpot> amagPoints = [const FlSpot(0, 0)];
  double xValue = 0;
  double currentAmag = 1.0;
  int currentLabel = 0;
  String currentBehavior = "STD";

  // Biến điều khiển giả lập CSV
  bool isFalling =
      false; // Biến cờ để ngăn lưu trùng lặp nhiều dòng cho 1 lần ngã
  List<List<dynamic>> _csvData = [];
  int _currentRow = 1; // Bỏ qua tiêu đề (row 0)
  Timer? _simulationTimer;

  @override
  void initState() {
    super.initState();
    _startSimulation();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  // Hàm đọc CSV và bắt đầu chạy dữ liệu
  // --- HÀM GIẢ LẬP ĐỌC DỮ LIỆU ---
  Future<void> _startSimulation() async {
    // 1. Tải dữ liệu từ file CSV qua Service
    _csvData = await CSVService().loadCSVData();

    // 2. Thiết lập Timer để đọc dữ liệu mỗi 100ms
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (_currentRow < _csvData.length) {
        final row = _csvData[_currentRow];

        // Bỏ qua nếu dòng dữ liệu không đủ cột (yêu cầu ít nhất 7 cột)
        if (row.length < 7) {
          _currentRow++;
          return;
        }

        if (!mounted) return; // Kiểm tra nếu widget còn tồn tại

        setState(() {
          // --- A. TRÍCH XUẤT DỮ LIỆU ---
          // Format trong file của bạn: temp, accX, accY, accZ, angleX, angleY, label
          double ax = double.tryParse(row[1].toString()) ?? 0.0;
          double ay = double.tryParse(row[2].toString()) ?? 0.0;
          double az = double.tryParse(row[3].toString()) ?? 0.0;
          currentLabel = int.tryParse(row[6].toString().trim()) ?? 0;

          // --- B. TÍNH TOÁN AMAG ---
          currentAmag = sqrt(ax * ax + ay * ay + az * az);

          // --- C. LOGIC PHÂN LOẠI HÀNH VI & LƯU LỊCH SỬ ---
          if (currentLabel == 1) {
            // NHÓM PHÁT HIỆN TÉ NGÃ (Label = 1)
            if (ax.abs() > ay.abs() && ax.abs() > az.abs()) {
              currentBehavior = "FOL"; // Ngã sấp/ngửa
            } else if (ay.abs() > ax.abs() && ay.abs() > az.abs()) {
              currentBehavior = "SDL"; // Ngã sang bên
            } else {
              currentBehavior = "FKL"; // Ngã khuỵu
            }

            // CHỈ LƯU VÀO HISTORY KHI MỚI BẮT ĐẦU NGÃ (Chống lưu lặp lại)
            if (!isFalling) {
              _saveToHistory(currentBehavior, currentAmag);
              isFalling = true; // Khóa lại cho đến khi Label về 0
            }
          } else {
            // NHÓM TRẠNG THÁI AN TOÀN (Label = 0)
            isFalling = false; // Reset biến cờ khi quay lại an toàn

            if (currentAmag > 2.5) {
              currentBehavior = "JUM"; // Nhảy
            } else if (currentAmag > 1.8) {
              currentBehavior = "JOG"; // Chạy
            } else if (currentAmag > 1.15) {
              currentBehavior = "WAL"; // Đi bộ
            } else if (currentAmag < 0.85) {
              currentBehavior = "CSI"; // Ra/vào xe
            } else {
              currentBehavior = "STD"; // Đứng yên
            }
          }

          // --- D. CẬP NHẬT BIỂU ĐỒ ---
          xValue++;
          amagPoints.add(FlSpot(xValue, currentAmag));
          if (amagPoints.length > 30) {
            amagPoints.removeAt(0); // Giữ biểu đồ luôn trôi
          }
        });

        _currentRow++;
      } else {
        _currentRow = 1; // Hết file thì quay lại từ đầu
      }
    });
  }

  // --- HÀM LƯU LỊCH SỬ (Định nghĩa duy nhất một lần trong class) ---
  Future<void> _saveToHistory(String behavior, double amag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList('fall_history') ?? [];

      // Tạo chuỗi lưu trữ có cấu trúc để trang History dễ đọc
      String timestamp = DateTime.now().toString().split('.')[0];
      String record =
          "$timestamp | $behavior | Amag: ${amag.toStringAsFixed(2)}";

      history.insert(0, record); // Đưa dữ liệu mới lên đầu

      // Giới hạn 50 bản ghi cho nhẹ bộ nhớ
      if (history.length > 50) history = history.sublist(0, 50);

      await prefs.setStringList('fall_history', history);
      debugPrint("System: Đã ghi nhận sự cố vào lịch sử.");
    } catch (e) {
      debugPrint("Error saving history: $e");
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
      "FOL": "Ngã sấp",
      "FKL": "Ngã khuỵu",
      "SDL": "Ngã bên",
      "BSC": "Ngã ngồi",
      "STD": "Đứng yên",
      "WAL": "Đi bộ",
      "JOG": "Chạy",
      "JUM": "Nhảy",
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Giám sát CSV Realtime",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "● Đang đọc dữ liệu",
                    style: TextStyle(color: Color(0xFF00FFD0), fontSize: 14),
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

          // Biểu đồ Amag
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
                                .withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Bảng trạng thái Hành vi
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
                "Dòng CSV",
                "$_currentRow",
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
  String _selectedFilter = 'Tất cả';
  List<Map<String, dynamic>> _allLogs = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLogsFromStorage(); // Tự động load lại dữ liệu mỗi khi tab được hiển thị
  }

  @override
  void initState() {
    super.initState();
    _loadLogsFromStorage();
  }

  // --- HÀM ĐỌC DỮ LIỆU THỰC TẾ TỪ BỘ NHỚ ---
  Future<void> _loadLogsFromStorage() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    List<String> storedLogs = prefs.getStringList('fall_history') ?? [];

    // Chuyển đổi dữ liệu từ SharedPreferences thành List Map để hiển thị
    List<Map<String, dynamic>> dynamicLogs = storedLogs
        .map((logString) {
          try {
            final parts = logString.split(' | ');
            return {
              "time": parts[0].contains(' ')
                  ? parts[0].split(' ')[1]
                  : parts[0],
              "date": parts[0].contains(' ')
                  ? parts[0].split(' ')[0]
                  : "08/02/2026",
              "event": "CẢNH BÁO: PHÁT HIỆN NGÃ (${parts[1]})",
              "value": parts[2].replaceFirst("Amag: ", "") + "g",
              "type": "alert",
              "axis": "Phân tích từ cảm biến",
            };
          } catch (e) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    // Dữ liệu hệ thống mẫu (luôn xuất hiện cuối cùng)
    List<Map<String, dynamic>> systemLogs = [
      {
        "time": "08:00:00",
        "date": "08/02/2026",
        "event": "HỆ THỐNG KHỞI ĐỘNG",
        "value": "1.00g",
        "type": "system",
        "axis": "Thiết bị sẵn sàng",
      },
    ];

    setState(() {
      // Ưu tiên dữ liệu ngã thật (dynamicLogs) lên trên đầu
      _allLogs = [...dynamicLogs, ...systemLogs];
      _isLoading = false;
    });
  }

  // --- HÀM XÓA LỊCH SỬ ---
  Future<void> _clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fall_history');
    _loadLogsFromStorage(); // Load lại trang
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ Đã xóa sạch nhật ký")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Logic lọc dữ liệu dựa trên Chip được chọn
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
                  const Text(
                    "Lịch sử sự cố ghi nhận từ thiết bị",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
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

          // Thanh bộ lọc (Chips)
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

          // Danh sách Timeline
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
        selectedColor: const Color(0xFF00FFD0).withOpacity(0.2),
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
                      color: statusColor.withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.white.withOpacity(0.05),
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
                border: Border.all(color: Colors.white.withOpacity(0.03)),
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
