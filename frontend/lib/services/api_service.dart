import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tide_data.dart';

class ApiService {
  // In production (Docker), API is on the same host
  String get _baseUrl {
    if (kIsWeb) {
      return ''; // Same origin
    }
    return 'http://localhost:8080';
  }

  Future<List<Location>> getLocations() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/locations'));
    final data = jsonDecode(response.body);
    return (data['locations'] as List)
        .map((l) => Location.fromJson(l))
        .toList();
  }

  Future<List<TideEvent>> getTides(String location, DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await http.get(
      Uri.parse('$_baseUrl/api/tides/$location?date=$dateStr'),
    );
    final data = jsonDecode(response.body);
    return (data['tides'] as List)
        .map((t) => TideEvent.fromJson(t))
        .toList();
  }

  Future<Map<String, List<TideEvent>>> getTidesRange(
    String location,
    DateTime start,
    DateTime end,
  ) async {
    final startStr =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr =
        '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/api/tides/$location/range?start=$startStr&end=$endStr'),
    );
    final data = jsonDecode(response.body);
    final days = data['days'] as Map<String, dynamic>;
    return days.map((date, tides) => MapEntry(
          date,
          (tides as List).map((t) => TideEvent.fromJson(t)).toList(),
        ));
  }

  Future<List<HourlyLevel>> getHourlyLevels(
      String location, DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await http.get(
      Uri.parse('$_baseUrl/api/tides/$location/hourly?date=$dateStr'),
    );
    final data = jsonDecode(response.body);
    return (data['levels'] as List)
        .map((l) => HourlyLevel.fromJson(l))
        .toList();
  }

  Future<SunTimes> getSunTimes(String location, DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await http.get(
      Uri.parse('$_baseUrl/api/sun/$location?date=$dateStr'),
    );
    return SunTimes.fromJson(jsonDecode(response.body));
  }

  Future<DayTideData> getDayData(String location, DateTime date) async {
    final results = await Future.wait([
      getTides(location, date),
      getHourlyLevels(location, date),
      getSunTimes(location, date),
    ]);

    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return DayTideData(
      date: dateStr,
      tides: results[0] as List<TideEvent>,
      hourlyLevels: results[1] as List<HourlyLevel>,
      sunTimes: results[2] as SunTimes,
    );
  }
}
