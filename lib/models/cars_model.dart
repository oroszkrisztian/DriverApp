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
    return VehicleData(
      vehicleId: json['vehicle']['vehicle_id'] ?? 0,
      name: json['vehicle']['name'] ?? '',
      numberPlate: json['vehicle']['numberplate'] ?? '',
      km: json['vehicle']['km'] ?? 0,
      insuranceStartDate: json['insurance']['date_start'] ?? '',
      insuranceEndDate: json['insurance']['date_end'] ?? '',
      insuranceValidity: _parseValidity(json['insurance']['validity']),
      tuvStartDate: json['tuv']['date_start'] ?? '',
      tuvEndDate: json['tuv']['date_end'] ?? '',
      tuvValidity: _parseValidity(json['tuv']['validity']),
      oilStartDate: json['oil']['date_start'] ?? '',
      oilUntilKm: json['oil']['until'] ?? 0,
      oilValidity: null, // This will be calculated later
    );
  }

  static bool? _parseValidity(String? value) {
    if (value == null) return null;
    return value.toLowerCase() == 'valid';
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
        'validity': insuranceValidity,
      },
      'tuv': {
        'date_start': tuvStartDate,
        'date_end': tuvEndDate,
        'validity': tuvValidity,
      },
      'oil': {
        'date_start': oilStartDate,
        'until': oilUntilKm,
        'validity': oilValidity,
      },
    };
  }
}