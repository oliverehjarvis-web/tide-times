class TideEvent {
  final DateTime dateTimeUtc;
  final DateTime dateTimeLocal;
  final String type; // "high" or "low"
  final double heightMetres;

  TideEvent({
    required this.dateTimeUtc,
    required this.dateTimeLocal,
    required this.type,
    required this.heightMetres,
  });

  factory TideEvent.fromJson(Map<String, dynamic> json) {
    return TideEvent(
      dateTimeUtc: DateTime.parse(json['datetime_utc']),
      dateTimeLocal: DateTime.parse(json['datetime_local'] ?? json['datetime_utc']),
      type: json['type'],
      heightMetres: (json['height_metres'] as num).toDouble(),
    );
  }

  bool get isHigh => type == 'high';
  bool get isLow => type == 'low';
}

class HourlyLevel {
  final DateTime dateTimeUtc;
  final DateTime dateTimeLocal;
  final double heightMetres;

  HourlyLevel({
    required this.dateTimeUtc,
    required this.dateTimeLocal,
    required this.heightMetres,
  });

  factory HourlyLevel.fromJson(Map<String, dynamic> json) {
    return HourlyLevel(
      dateTimeUtc: DateTime.parse(json['datetime_utc']),
      dateTimeLocal: DateTime.parse(json['datetime_local'] ?? json['datetime_utc']),
      heightMetres: (json['height_metres'] as num).toDouble(),
    );
  }
}

class SunTimes {
  final String date;
  final String sunrise;
  final String sunset;
  final double dayLengthHours;

  SunTimes({
    required this.date,
    required this.sunrise,
    required this.sunset,
    required this.dayLengthHours,
  });

  factory SunTimes.fromJson(Map<String, dynamic> json) {
    return SunTimes(
      date: json['date'],
      sunrise: json['sunrise'],
      sunset: json['sunset'],
      dayLengthHours: (json['day_length_hours'] as num).toDouble(),
    );
  }
}

class Location {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  Location({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'],
      name: json['name'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class DayTideData {
  final String date;
  final List<TideEvent> tides;
  final List<HourlyLevel> hourlyLevels;
  final SunTimes? sunTimes;

  DayTideData({
    required this.date,
    required this.tides,
    required this.hourlyLevels,
    this.sunTimes,
  });
}
