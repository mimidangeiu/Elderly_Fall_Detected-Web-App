import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

class SensorRecord {
  SensorRecord({
    required this.id,
    required this.timestamp,
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.amag,
    required this.temp,
    required this.angleX,
    required this.angleY,
    required this.label,
  });

  final int id;
  final String timestamp;
  final double accX;
  final double accY;
  final double accZ;
  final double amag;
  final double temp;
  final double angleX;
  final double angleY;
  final int label;

  factory SensorRecord.fromRow(Row row) {
    return SensorRecord(
      id: _asInt(row['id']),
      timestamp: _asString(row['timestamp']),
      accX: _asDouble(row['accX']),
      accY: _asDouble(row['accY']),
      accZ: _asDouble(row['accZ']),
      amag: _asDouble(row['amag']),
      temp: _asDouble(row['temp']),
      angleX: _asDouble(row['angleX']),
      angleY: _asDouble(row['angleY']),
      label: _asInt(row['label']),
    );
  }

  DateTime? get parsedTimestamp => DateTime.tryParse(timestamp);

  String get timeLabel {
    final parsed = parsedTimestamp;
    if (parsed == null) return timestamp;
    return '${_twoDigits(parsed.hour)}:${_twoDigits(parsed.minute)}:${_twoDigits(parsed.second)}';
  }

  String get dateLabel {
    final parsed = parsedTimestamp;
    if (parsed == null) return '-';
    return '${parsed.year}-${_twoDigits(parsed.month)}-${_twoDigits(parsed.day)}';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class SQLiteSensorService {
  SQLiteSensorService({String? databasePath}) : _databasePath = databasePath;

  String? _databasePath;

  // ── Giữ 1 connection duy nhất, tái sử dụng — tránh open/dispose 25 lần/giây
  Database? _db;

  String? get databasePath => _databasePath;

  // Lấy connection, tự động mở nếu chưa có hoặc path thay đổi
  Future<Database?> _getDb() async {
    final path = await resolveDatabasePath();
    if (path == null) return null;

    // Nếu đã có connection với đúng file thì tái sử dụng
    if (_db != null) return _db;

    final db = sqlite3.open(path, mode: OpenMode.readOnly);

    // WAL mode: cho phép đọc và ghi đồng thời, không bị lock
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA synchronous=NORMAL');

    // Timeout 3 giây thay vì trả lỗi ngay khi DB bị busy
    db.execute('PRAGMA busy_timeout=3000');

    _db = db;
    return _db;
  }

  // Gọi khi app đóng để giải phóng resource
  void dispose() {
    _db?.dispose();
    _db = null;
  }

  Future<String?> resolveDatabasePath() async {
    // --- 1. KIỂM TRA NẾU ĐANG CHẠY TRÊN ANDROID (MÁY ẢO) ---
    if (Platform.isAndroid) {
      final String androidPath = '/data/local/tmp/sensor_data.db';
      if (File(androidPath).existsSync()) {
        return androidPath;
      }
      print("❌ Android: Không tìm thấy file trong /data/local/tmp/");
      return null;
    }

    // --- 2. KIỂM TRA NẾU ĐANG CHẠY TRÊN WINDOWS (LAPTOP) ---
    // Giữ nguyên logic cũ của An để chạy trên máy tính không bị lỗi
    if (_databasePath != null && File(_databasePath!).existsSync()) {
      return _databasePath;
    }

    final current = Directory.current;
    // Thêm các đường dẫn linh hoạt để máy bạn An cũng tìm được
    final candidates = <String>{
      p.normalize(
        p.join(current.path, '..', 'fall_backend_web', 'sensor_data.db'),
      ),
      p.normalize(p.join(current.path, 'fall_backend_web', 'sensor_data.db')),
      // Thêm đường dẫn tuyệt đối phòng hờ máy bạn An để khác thư mục cha
      'D:\\ELDERLY_FALL_DETECTED\\fall_backend_web\\sensor_data.db',
    };

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        _databasePath = File(candidate).absolute.path;
        return _databasePath;
      }
    }

    return null;
  }

  Future<List<SensorRecord>> loadLatestRecords({int limit = 500}) async {
    final db = await _getDb();
    if (db == null) return [];

    try {
      final rows = db.select(
        'SELECT id, timestamp, accX, accY, accZ, amag, temp, angleX, angleY, label '
        'FROM sensor ORDER BY id DESC LIMIT ?',
        [limit],
      );
      return rows
          .map(SensorRecord.fromRow)
          .toList()
          .reversed
          .toList(growable: false);
    } catch (e) {
      // Nếu DB bị lỗi → reset connection, lần sau tự mở lại
      _db?.dispose();
      _db = null;
      return [];
    }
  }

  Future<SensorRecord?> loadLatestRecord() async {
    final latest = await loadLatestRecords(limit: 1);
    if (latest.isEmpty) return null;
    return latest.last;
  }

  Future<List<SensorRecord>> loadFallEvents({int limit = 100}) async {
    final db = await _getDb();
    if (db == null) return [];

    try {
      final rows = db.select(
        'SELECT id, timestamp, accX, accY, accZ, amag, temp, angleX, angleY, label '
        'FROM sensor WHERE label = 1 ORDER BY id DESC LIMIT ?',
        [limit],
      );
      return rows.map(SensorRecord.fromRow).toList(growable: false);
    } catch (e) {
      _db?.dispose();
      _db = null;
      return [];
    }
  }

  Future<SensorSummary?> loadSummary() async {
    final db = await _getDb();
    if (db == null) return null;

    try {
      final rows = db.select(
        'SELECT COUNT(*) AS totalRecords, '
        'COALESCE(SUM(label), 0) AS totalFalls, '
        'COALESCE(AVG(amag), 0) AS averageAmag '
        'FROM sensor',
      );
      if (rows.isEmpty) {
        return const SensorSummary(
          totalRecords: 0,
          totalFalls: 0,
          averageAmag: 0,
        );
      }
      final row = rows.first;
      return SensorSummary(
        totalRecords: _asInt(row['totalRecords']),
        totalFalls: _asInt(row['totalFalls']),
        averageAmag: _asDouble(row['averageAmag']),
      );
    } catch (e) {
      _db?.dispose();
      _db = null;
      return null;
    }
  }
}

class SensorSummary {
  const SensorSummary({
    required this.totalRecords,
    required this.totalFalls,
    required this.averageAmag,
  });

  final int totalRecords;
  final int totalFalls;
  final double averageAmag;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '0') ?? 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '0') ?? 0;
}

String _asString(Object? value) => value?.toString() ?? '';
