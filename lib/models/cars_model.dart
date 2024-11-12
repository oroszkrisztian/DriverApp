class VehicleData {
  final int vehicleId;
  final String name;
  final String numberPlate;
  final int km;
  final String insuranceStartDate;
  final String insuranceEndDate;
  final bool? insuranceValidity;
  final String tuvStartDate;
  final String tuvEndDate;
  final bool? tuvValidity;
  final String oilStartDate;
  final int? oilUntilKm;
  final bool? oilValidity;

  VehicleData({
    required this.vehicleId,
    required this.name,
    required this.numberPlate,
    required this.km,
    required this.insuranceStartDate,
    required this.insuranceEndDate,
    this.insuranceValidity,
    required this.tuvStartDate,
    required this.tuvEndDate,
    this.tuvValidity,
    required this.oilStartDate,
    this.oilUntilKm,
    this.oilValidity,
  });

  factory VehicleData.fromJson(Map<String, dynamic> json) {
    // Handle both direct and nested JSON structures
    final vehicle = json['vehicle'] ?? json;
    final insurance = json['insurance'] ?? json;
    final tuv = json['tuv'] ?? json;
    final oil = json['oil'] ?? json;

    return VehicleData(
      vehicleId: vehicle['vehicle_id'] ?? 0,
      name: vehicle['name'] ?? '',
      numberPlate: vehicle['numberplate'] ?? '',
      km: vehicle['km'] ?? 0,
      insuranceStartDate: insurance['date_start'] ?? '',
      insuranceEndDate: insurance['date_end'] ?? '',
      insuranceValidity: _parseValidity(insurance['validity']),
      tuvStartDate: tuv['date_start'] ?? '',
      tuvEndDate: tuv['date_end'] ?? '',
      tuvValidity: _parseValidity(tuv['validity']),
      oilStartDate: oil['date_start'] ?? '',
      oilUntilKm: oil['until'] ?? 0,
      oilValidity: null,
    );
  }

  static bool? _parseValidity(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'valid';
    return null;
  }

  bool isOilValid() {
    if (oilUntilKm == null) return false;
    return km <= oilUntilKm!;
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle': {
        'vehicle_id': vehicleId,
        'name': name,
        'numberplate': numberPlate,
        'km': km,
      },
      'insurance': {
        'date_start': insuranceStartDate,
        'date_end': insuranceEndDate,
        'validity': insuranceValidity != null ? (insuranceValidity! ? 'valid' : 'invalid') : null,
      },
      'tuv': {
        'date_start': tuvStartDate,
        'date_end': tuvEndDate,
        'validity': tuvValidity != null ? (tuvValidity! ? 'valid' : 'invalid') : null,
      },
      'oil': {
        'date_start': oilStartDate,
        'until': oilUntilKm,
        'validity': oilValidity != null ? (oilValidity! ? 'valid' : 'invalid') : null,
      },
    };
  }
}