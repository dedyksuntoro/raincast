import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/rainviewer_model.dart';

class WeatherService {
  Future<RainViewerData> getRainViewerData() async {
    final url = 'https://api.rainviewer.com/public/weather-maps.json';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      print(
        "Response JSON: ${response.body}",
      ); // Cek apakah JSON diterima dengan benar
      return RainViewerData.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Gagal memuat data RainViewer: ${response.statusCode}');
    }
  }
}
