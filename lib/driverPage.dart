import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:app/expense_log_page.dart';
import 'package:app/models/cars_model.dart';
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

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  _DriverPageState createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  //bool _dataLoaded = false;
  bool _isLoggedIn = false;
  bool _vehicleLoggedIn = false;

  VehicleData? _selectedCar;

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

      // Get the selected car's data if logged in
      if (_vehicleLoggedIn && Globals.vehicleID != null) {
        _selectedCar = carServices.getVehicleData(Globals.vehicleID!);
      }
    });
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
                        maxHeight: constraints.maxHeight * 0.8,
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
                        backgroundColor:
                            const Color.fromARGB(255, 101, 204, 82),
                        foregroundColor: Colors.black,
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
                    MaterialPageRoute(
                        builder: (context) => const VehicleExpensePage()),
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
                    MaterialPageRoute(
                        builder: (context) => const ExpenseLogPage()),
                  );
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
        side: const BorderSide(
            color: Color.fromARGB(255, 101, 204, 82), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: Text(label),
    );
  }

  @override
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
          ? (_vehicleLoggedIn && _selectedCar != null
              ? SingleChildScrollView(
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
                                DataColumn(label: Text('Until')),
                                DataColumn(label: Text('Status')),
                              ],
                              rows: [
                                DataRow(cells: [
                                  const DataCell(Text('Insurance')),
                                  DataCell(
                                      Text(_selectedCar!.insuranceStartDate)),
                                  DataCell(
                                      Text(_selectedCar!.insuranceEndDate)),
                                  DataCell(Text(
                                    _selectedCar!.insuranceValidity != null &&
                                            _selectedCar!.insuranceValidity!
                                        ? 'VALID'
                                        : 'EXPIRED',
                                    style: TextStyle(
                                      color: _selectedCar!.insuranceValidity !=
                                                  null &&
                                              _selectedCar!.insuranceValidity!
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  )),
                                ]),
                                DataRow(cells: [
                                  const DataCell(Text('TUV')),
                                  DataCell(Text(_selectedCar!.tuvStartDate)),
                                  DataCell(Text(_selectedCar!.tuvEndDate)),
                                  DataCell(Text(
                                    _selectedCar!.tuvValidity != null &&
                                            _selectedCar!.tuvValidity!
                                        ? 'VALID'
                                        : 'EXPIRED',
                                    style: TextStyle(
                                      color:
                                          _selectedCar!.tuvValidity != null &&
                                                  _selectedCar!.tuvValidity!
                                              ? Colors.green
                                              : Colors.red,
                                    ),
                                  )),
                                ]),
                                DataRow(cells: [
                                  const DataCell(Text('Oil')),
                                  DataCell(Text(_selectedCar!.oilStartDate)),
                                  DataCell(Text(
                                      '${_selectedCar!.oilUntilKm ?? 'N/A'} km')),
                                  DataCell(Text(
                                    _selectedCar!.isOilValid()
                                        ? 'VALID'
                                        : 'EXPIRED',
                                    style: TextStyle(
                                      color: _selectedCar!.isOilValid()
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  )),
                                ]),
                                DataRow(cells: [
                                  const DataCell(Text('KM')),
                                  DataCell(Text(_selectedCar!.km.toString())),
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
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginPage()),
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
                      child: const Text('You are not logged in a car'),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 16),
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
            if (_vehicleLoggedIn)
              FloatingActionButton(
                heroTag: 'car',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const VehicleDataPage()),
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
            SizedBox(
              width: 90,
              height: 56,
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
                      print("Button change log in/out: $vehicleId");
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(vehicleId != null ? Icons.logout : Icons.login),
                          Text(
                            vehicleId != null
                                ? 'Logout Vehicle'
                                : 'Login Vehicle',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
