import 'package:app/globals.dart';
import 'package:app/loginPage.dart';
import 'package:app/models/cars_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CarServices {
  List<Car> _cars = [];
  int _lastKm = 0;
  VehicleData? _vehicleData; // Add this to store vehicle data
  Map<int, VehicleData> _vehiclesData = {};

  // Getters
  List<Car> get cars => _cars;
  int get lastKm => _lastKm;
  VehicleData? get vehicleData => _vehicleData;
  Map<int, VehicleData> get vehiclesData => _vehiclesData;

  // Combined initialization method
  Future<void> initializeData() async {
    print('Starting initializeData');
    try {
      // First get basic car list
      await getCars();
      print('Cars loaded: ${_cars.length}');

      // Just fetch the current vehicle data once
      print('Fetching vehicle data...');
      await fetchVehicleData();
      print(
          'Vehicle data loaded. Current vehicles in data: ${_vehiclesData.keys}');
    } catch (e) {
      print('Error in initializeData: $e');
      rethrow;
    }
  }

  Future<void> getCars() async {
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/greenfleet/flutter_functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'get-cars',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonData = jsonDecode(response.body);
        _cars = jsonData.map((json) => Car.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load cars: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching cars: $e');
    }
  }

  // Future<void> _loadVehicleData() async {
  //   if (Globals.userId == null) {
  //     print('No user ID available, skipping vehicle data load');
  //     return;
  //   }

  //   try {
  //     _vehicleData = await fetchVehicleData();
  //   } catch (e) {
  //     print('Error loading vehicle data: $e');
  //     // Don't rethrow - we want the app to continue even if detailed data fails to load
  //   }
  // }

  Future<void> fetchVehicleData() async {
    try {
        final response = await http.post(
            Uri.parse('https://vinczefi.com/greenfleet/flutter_functions_1.php'),
            headers: <String, String>{
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
                'action': 'driver-vehicle-data2',
                'driver': Globals.userId.toString(),
            },
        );

        print('Vehicle Data Response Status: ${response.statusCode}');
        print('Vehicle Data Response: ${response.body}');

        if (response.statusCode == 200 && response.body.isNotEmpty) {
            var jsonData = jsonDecode(response.body);

            if (jsonData.containsKey('error')) {
                print('Error in response: ${jsonData['error']}');
                return;
            }

            // Only fetch and store the vehicle data if it exists
            if (jsonData.containsKey('vehicle')) {
                final vehicleId = jsonData['vehicle']['vehicle_id'];
                final vehicleData = VehicleData.fromJson(jsonData);
                _vehiclesData[vehicleId] = vehicleData;

                // Now filter the cars to include only the vehicles assigned to this driver
                _cars = [Car(id: vehicleId, name: vehicleData.name, numberPlate: vehicleData.numberPlate)];
                print('Stored data for vehicle ID $vehicleId with KM: ${vehicleData.km}');
            }
        }
    } catch (e) {
        print('Error fetching vehicle data: $e');
    }
}


  int? getLastKmForVehicle(int vehicleId) {
    // If this is the vehicle we have data for, return its KM
    if (_vehiclesData.containsKey(vehicleId)) {
      return _vehiclesData[vehicleId]?.km;
    }

    // Otherwise return null
    return null;
  }

  VehicleData? getVehicleData(int vehicleId) {
    print('Getting vehicle data for ID: $vehicleId');
    print('Available vehicle IDs: ${_vehiclesData.keys.toList()}');
    return _vehiclesData[vehicleId];
  }

  Future<bool> getLastKm(int driverId, int vehicleId) async {
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/greenfleet/flutter_functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'get-last-km',
          'driver_id': driverId.toString(),
          'vehicle_id': vehicleId.toString(),
        },
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data is bool && data == false) {
          _lastKm = 0;
          return true;
        } else if (data != null &&
            (data is int || int.tryParse(data.toString()) != null)) {
          _lastKm = int.parse(data.toString());
          return true;
        } else {
          throw Exception('Invalid response data');
        }
      } else {
        throw Exception('Failed to load last KM: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching last KM: $e');
    }
  }
}
