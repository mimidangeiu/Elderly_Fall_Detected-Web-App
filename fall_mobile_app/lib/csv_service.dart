import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class CSVService {
  Future<List<List<dynamic>>> loadCSVData() async {
    // 1. Đọc nội dung file từ assets
    final rawData = await rootBundle.loadString(
      "assets/mpu6050_simulated_data.csv",
    );

    // 2. Chuyển đổi thành danh sách.
    // Dùng eol: '\n' và xử lý sạch dữ liệu
    List<List<dynamic>> listData = const CsvToListConverter().convert(
      rawData,
      eol: '\n',
    );
    return listData;
  }
}
