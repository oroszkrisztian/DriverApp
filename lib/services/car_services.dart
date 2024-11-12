import 'package:app/globals.dart';
import 'package:app/loginPage.dart';
import 'package:app/models/cars_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CarServices {
  List<Car> _cars = [];
  int _lastKm = 0;
  VehicleData? _vehicleData;
  Map<int, VehicleData> _vehiclesData = {};

  // Getters
  List<Car> get cars => _cars;
  int get lastKm => _lastKm;
  VehicleData? get vehicleData => _vehicleData;
  Map<int, VehicleData> get vehiclesData => _vehiclesData;

  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> initializeData() async {
    print('Starting initializeData');
    try {
      // First try to load cached data
      await _loadCachedData();
      print(
          'Loaded cached data: ${_cars.length} cars, ${_vehiclesData.length} vehicle data');

      // Check connectivity
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        print('No internet connection. Using cached data.');
        return;
      }

      // Then try to get fresh data
      if (Globals.userId == null) {
        print('No user ID available, fetching all cars...');
        await getCars();
        print('All cars loaded: ${_cars.length}');
      } else {
        print('User logged in, fetching assigned vehicles...');
        await fetchVehicleData();
        print(
            'Vehicle data loaded. Current vehicles in data: ${_vehiclesData.keys}');
      }

      // Cache the fresh data
      await _cacheData();
      print('Data cached successfully');
    } catch (e) {
      print('Error in initializeData: $e');
      // If there's an error fetching fresh data, we'll still have cached data
      print('Using cached data due to error');
      rethrow;
    }
  }

  Future<void> getCars() async {
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        print('No internet connection, using cached cars');
        return;
      }

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
        print('Fetched ${_cars.length} cars');

        // Cache the new data
        await _cacheData();
        print('Cars cached successfully');
      } else {
        throw Exception('Failed to load cars: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getCars: $e');
      rethrow;
    }
  }

  Future<void> fetchVehicleData() async {
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        print('No internet connection, using cached vehicle data');
        return;
      }

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

        if (jsonData.containsKey('vehicle')) {
          final vehicleId = jsonData['vehicle']['vehicle_id'];
          final vehicleData = VehicleData.fromJson(jsonData);
          _vehiclesData[vehicleId] = vehicleData;

          // Update cars list with assigned vehicle
          _cars = [
            Car(
              id: vehicleId,
              name: vehicleData.name,
              numberPlate: vehicleData.numberPlate,
            )
          ];
          print(
              'Stored data for vehicle ID $vehicleId with KM: ${vehicleData.km}');

          // Cache the new data
          await _cacheData();
          print('Vehicle data cached successfully');
        }
      }
    } catch (e) {
      print('Error in fetchVehicleData: $e');
      rethrow;
    }
  }

  int? getLastKmForVehicle(int vehicleId) {
    if (_vehiclesData.containsKey(vehicleId)) {
      return _vehiclesData[vehicleId]?.km;
    }
    return null;
  }

  VehicleData? getVehicleData(int vehicleId) {
    print('Getting vehicle data for ID: $vehicleId');
    print('Available vehicle IDs: ${_vehiclesData.keys.toList()}');
    return _vehiclesData[vehicleId];
  }

  Future<bool> getLastKm(int driverId, int vehicleId) async {
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        throw Exception('No internet connection');
      }

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
      print('Error fetching last KM: $e');
      rethrow;
    }
  }

  Future<void> _cacheData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Cache cars
      if (_cars.isNotEmpty) {
        await prefs.setString(
            'cached_cars',
            jsonEncode(_cars
                .map((car) => {
                      'id': car.id,
                      'name': car.name,
                      'numberplate': car.numberPlate,
                    })
                .toList()));
      }

      // Cache vehicle data
      if (_vehiclesData.isNotEmpty) {
        final vehicleDataMap = _vehiclesData
            .map((key, value) => MapEntry(key.toString(), value.toJson()));
        await prefs.setString(
            'cached_vehicle_data', jsonEncode(vehicleDataMap));
      }
    } catch (e) {
      print('Error caching data: $e');
    }
  }

  Future<void> _loadCachedData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Load cached cars
      final cachedCarsString = prefs.getString('cached_cars');
      if (cachedCarsString != null) {
        final List<dynamic> cachedCars = jsonDecode(cachedCarsString);
        _cars = cachedCars.map((carJson) => Car.fromJson(carJson)).toList();
        print('Loaded ${_cars.length} cars from cache');
      }

      // Load cached vehicle data
      final cachedVehicleDataString = prefs.getString('cached_vehicle_data');
      if (cachedVehicleDataString != null) {
        final Map<String, dynamic> cachedVehicleData =
            jsonDecode(cachedVehicleDataString);
        _vehiclesData = Map.fromEntries(cachedVehicleData.entries.map((entry) =>
            MapEntry(int.parse(entry.key), VehicleData.fromJson(entry.value))));
        print('Loaded ${_vehiclesData.length} vehicle data from cache');
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  Future<bool> hasCachedData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('cached_cars') ||
          prefs.containsKey('cached_vehicle_data');
    } catch (e) {
      print('Error checking cached data: $e');
      return false;
    }
  }

  Future<void> clearCache() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_cars');
      await prefs.remove('cached_vehicle_data');
      print('Cache cleared successfully');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}
