import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:app/expense_log_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'globals.dart';
import 'logoutPage.dart';
import 'myLogs.dart';
import 'main.dart';
import 'vehicleData.dart';
import 'loginPage.dart'; // Ensure this is imported
import 'vehicleExpensePage.dart'; // Import the new expense page

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
}

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  _DriverPageState createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  Future<VehicleData>? _vehicleDataFuture;
  VehicleData? _selectedCar;
  Timer? _timer;
  bool _dataLoaded = false;
  bool _isLoggedIn = false;
  bool _vehicleLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    setState(() {
      _isLoggedIn = isLoggedIn;
      _vehicleLoggedIn = Globals.vehicleID != null;
    });

    if (isLoggedIn && Globals.vehicleID != null) {
      _vehicleDataFuture = fetchVehicleData();
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!_dataLoaded) {
          setState(() {
            _vehicleDataFuture = fetchVehicleData();
          });
        } else {
          _timer?.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<VehicleData> fetchVehicleData() async {
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/greenfleet/flutter_functions_1.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'driver-vehicle-data1',
          'driver': Globals.userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        // Print the response body to the console
        print('Response body: ${response.body}');

        var jsonData = jsonDecode(response.body);
        _dataLoaded = true;
        return VehicleData.fromJson(jsonData);
      } else {
        throw Exception(
            'Failed to load vehicle data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to load vehicle data: $e');
    }
  }

  Future<void> _logoutUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('userId');
    await prefs.remove('vehicleId');

    setState(() {
      _isLoggedIn = false;
      _vehicleLoggedIn = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MyHomePage(),
      ),
    );
  }

  void _showImage(File? image) {
    if (image == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('No Picture'),
            content: const Text('There is no picture available.'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.8, // Adjust the value as needed
                      ),
                      child: Image.file(
                        image,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 101, 204, 82), // Green background
                        foregroundColor: Colors.black, // Black text
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showExpenseDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'submit_expense',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VehicleExpensePage()),
                  );
                },
                backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add),
                    Text(
                      'Submit',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              FloatingActionButton(
                heroTag: 'expense_log',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ExpenseLogPage()),
                  );// Just close the dialog for now
                },
                backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list),
                    Text(
                      'Logs',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePreviewButton(String label, File? image) {
    return ElevatedButton(
      onPressed: () => _showImage(image),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        side: const BorderSide(color: Color.fromARGB(255, 101, 204, 82), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Car Data'),
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 101, 204, 82),
        actions: _vehicleLoggedIn
            ? [] // Empty actions when logged into a vehicle
            : [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logoutUser,
          ),
        ],
      ),
      body: _isLoggedIn
          ? (_vehicleLoggedIn
          ? FutureBuilder<VehicleData>(
        future: _vehicleDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          } else {
            VehicleData vehicleData = snapshot.data!;
            _selectedCar = vehicleData;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_selectedCar != null) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(
                            width: 1,
                            color: Colors.black,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.6),
                              spreadRadius: 5,
                              blurRadius: 7,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${_selectedCar!.name} - ${_selectedCar!.numberPlate}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      padding: const EdgeInsets.all(2.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          width: 1,
                          color: Colors.black,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.6),
                            spreadRadius: 5,
                            blurRadius: 7,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Start Date')),
                            DataColumn(label: Text('Untill')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: [
                            DataRow(cells: [
                              const DataCell(Text('Insurance')),
                              DataCell(Text(vehicleData.insuranceStartDate)),
                              DataCell(Text(vehicleData.insuranceEndDate)),
                              DataCell(Text(
                                vehicleData.insuranceValidity != null && vehicleData.insuranceValidity!
                                    ? 'VALID'
                                    : 'EXPIRED',
                                style: TextStyle(
                                  color: vehicleData.insuranceValidity != null && vehicleData.insuranceValidity!
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              )),
                            ]),
                            DataRow(cells: [
                              const DataCell(Text('TUV')),
                              DataCell(Text(vehicleData.tuvStartDate)),
                              DataCell(Text(vehicleData.tuvEndDate)),
                              DataCell(Text(
                                vehicleData.tuvValidity != null && vehicleData.tuvValidity!
                                    ? 'VALID'
                                    : 'EXPIRED',
                                style: TextStyle(
                                  color: vehicleData.tuvValidity != null && vehicleData.tuvValidity!
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              )),
                            ]),
                            DataRow(cells: [
                              const DataCell(Text('Oil')),
                              DataCell(Text(vehicleData.oilStartDate)),
                              DataCell(Text('${vehicleData.oilUntilKm ?? 'N/A'} km')),
                              DataCell(Text(
                                vehicleData.isOilValid() ? 'VALID' : 'EXPIRED',
                                style: TextStyle(
                                  color: vehicleData.isOilValid() ? Colors.green : Colors.red,
                                ),
                              )),
                            ]),
                            DataRow(cells: [
                              const DataCell(Text('KM')),
                              DataCell(Text(vehicleData.km.toString())),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (Globals.image1 != null ||
                        Globals.image2 != null ||
                        Globals.image3 != null ||
                        Globals.image4 != null ||
                        Globals.image5 != null)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(
                            width: 1,
                            color: Colors.black,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.6),
                              spreadRadius: 5,
                              blurRadius: 7,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Pictures',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildImagePreviewButton(
                                'Dashboard', Globals.image1),
                            const SizedBox(height: 8.0),
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildImagePreviewButton(
                                    'Front Left', Globals.image2),
                                _buildImagePreviewButton(
                                    'Front Right', Globals.image3),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildImagePreviewButton(
                                    'Rear Left', Globals.image4),
                                _buildImagePreviewButton(
                                    'Rear Right', Globals.image5),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 80), // Empty space for buttons
                  ],
                ),
              ),
            );
          }
        },
      )
          : Center(
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                width: 1,
                color: Colors.black,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.6),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text('Please log into a vehicle to see its data'),
          ),
        ),
      ))
          : Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              width: 1,
              color: Colors.black,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.6),
                spreadRadius: 5,
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Text('Please log in to see your car data'),
        ),
      ),
      floatingActionButton: Container(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Aligns buttons across the screen
          children: [
            const SizedBox(width: 16), // Space at the start

            // "MyLogs" button
            FloatingActionButton(
              heroTag: 'logs',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyLogPage()),
                );
              },
              backgroundColor: const Color.fromARGB(255, 101, 204, 82),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list),
                  Text(
                    'MyLogs',
                    style: TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),

            // If logged in, "MyCar" button
            if (_vehicleLoggedIn)
              FloatingActionButton(
                heroTag: 'car',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VehicleDataPage()),
                  );
                },
                backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car),
                    Text(
                      'MyCar',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),

            // If logged in, "Expense" button
            if (_vehicleLoggedIn)
              FloatingActionButton(
                heroTag: 'expense',
                onPressed: _showExpenseDialog,
                backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.attach_money),
                    Text(
                      'Expense',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),

            // "Login Vehicle/Logout Vehicle" button with consistent size and alignment
            SizedBox(
              width: 90, // Adjusted width for consistent button size
              height: 56, // Ensure height matches standard FAB size (56 is default)
              child: FloatingActionButton(
                heroTag: 'vehicle_action',
                onPressed: () async {
                  int? vehicleId = Globals.vehicleID;

                  if (vehicleId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LogoutPage(),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  }
                },
                backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                child: FutureBuilder<SharedPreferences>(
                  future: SharedPreferences.getInstance(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login),
                          Text(
                            '',
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      );
                    } else {
                      int? vehicleId = Globals.vehicleID;
                      print("Button change log in/out: " + vehicleId.toString());
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(vehicleId != null ? Icons.logout : Icons.login),
                          Text(
                            vehicleId != null ? 'Logout Vehicle' : 'Login Vehicle',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),

            const SizedBox(width: 16), // Space at the end
          ],
        ),
      ),


      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
