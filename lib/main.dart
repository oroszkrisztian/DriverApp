import 'dart:io';

import 'package:app/services/car_services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'globals.dart'; // Import your globals.dart file
import 'driverPage.dart'; // Import DriverPage
// Import LoginPage
import 'package:workmanager/workmanager.dart';

// Enums and Constants
enum VehicleOperationType { login, logout }

// Constants for task names
const String uploadImageTask = "uploadImageTask";
const String uploadExpenseTask = "uploadExpenseTask";
const String vehicleLoginTask = "vehicleLoginTask";
const String vehicleLogoutTask = "vehicleLogoutTask";
const String connectivityCheckTask = "connectivityCheckTask";
const String operationLockKey = 'operationInProgress';

final CarServices carServices = CarServices();

// Callback dispatcher for handling background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case uploadImageTask:
        return await handleImageUpload(inputData);
      case uploadExpenseTask:
        return await handleExpenseUpload(inputData);
      case vehicleLoginTask:
        return await handleVehicleOperation(
            inputData, VehicleOperationType.login);
      case vehicleLogoutTask:
        return await handleVehicleOperation(
            inputData, VehicleOperationType.logout);
      case connectivityCheckTask:
        return await handleConnectivityCheck();
      default:
        return Future.value(false);
    }
  });
}

Future<bool> handleConnectivityCheck() async {
  try {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isOperationInProgress = prefs.getBool(operationLockKey) ?? false;
      
      // Only proceed if no operation is in progress
      if (!isOperationInProgress) {
        // Set lock before proceeding
        await prefs.setBool(operationLockKey, true);
        
        try {
          // Check and upload pending vehicle operations
          String? pendingOperation = prefs.getString('pendingVehicleOperation');
          if (pendingOperation != null) {
            Map<String, dynamic> operationData = jsonDecode(pendingOperation);
            bool success = await uploadVehicleOperation(operationData);
            
            if (success) {
              await prefs.remove('pendingVehicleOperation');
              
              // Handle logout specific cleanup
              if (operationData['operationType'] == 'logout') {
                await prefs.remove('isLoggedIn');
                await prefs.remove('vehicleId');
                Globals.vehicleID = null;
              }
            }
          }
          
          // Check and upload pending expenses
          String? pendingExpense = prefs.getString('expensesData');
          if (pendingExpense != null) {
            Map<String, dynamic> expenseData = jsonDecode(pendingExpense);
            await uploadExpense(expenseData);
          }
        } finally {
          // Always release the lock when done
          await prefs.setBool(operationLockKey, false);
        }
      }
    }
    return true;
  } catch (e) {
    print('Error in connectivity check: $e');
    // Make sure to release lock even if there's an error
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(operationLockKey, false);
    return false;
  }
}

// Handling image upload task
Future<bool> handleImageUpload(Map<String, dynamic>? inputData) async {
  try {
    await uploadImages(inputData);
    return Future.value(true);
  } catch (e) {
    print('Error in image upload task: $e');
    return Future.value(false);
  }
}

// Handling expense upload task
Future<bool> handleExpenseUpload(Map<String, dynamic>? inputData) async {
  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    print('No internet connection. Saving expense locally.');
    return false;
  }
  return await uploadExpense(inputData);
}

Future<bool> handleVehicleOperation(
    Map<String, dynamic>? inputData, VehicleOperationType operationType) async {
  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    print('No internet connection. Saving vehicle operation data locally.');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('pendingVehicleOperation', json.encode(inputData));
      if (operationType == VehicleOperationType.logout) {
        await prefs.remove('isLoggedIn');
        await prefs.remove('vehicleId');
        Globals.vehicleID = null;
      }
      return false;
    } catch (e) {
      print('Error saving vehicle operation data: $e');
      return false;
    }
  }
  return await uploadVehicleOperation(inputData);
}

Future<bool> uploadVehicleOperation(Map<String, dynamic>? inputData) async {
  if (inputData == null) {
    print("No input data for vehicle operation");
    return false;
  }
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://vinczefi.com/greenfleet/flutter_functions.php'),
    );
    request.fields['action'] = 'vehicle-login';
    request.fields['driver'] = inputData['driver'] ?? '';
    request.fields['vehicle'] = inputData['vehicle'] ?? '';
    request.fields['km'] = inputData['km'] ?? '';
    request.fields['datetime'] = inputData['datetime'] ?? '';

    var response = await request.send();
    if (response.statusCode == 200) {
      print(
          "Vehicle ${inputData['operationType']} operation complete at ${inputData['datetime']}");
      return true;
    } else {
      print(
          "Vehicle ${inputData['operationType']} operation failed: ${response.statusCode}");
      return false;
    }
  } catch (e) {
    print('Error during vehicle ${inputData['operationType']} operation: $e');
    return false;
  }
}

Future<void> uploadImages(Map<String, dynamic>? inputData) async {
  if (inputData == null) {
    print("No input data for image upload");
    return;
  }

  var request = http.MultipartRequest(
    'POST',
    Uri.parse('https://vinczefi.com/greenfleet/flutter_functions.php'),
  );

  request.fields['action'] = 'photo-upload';
  request.fields['driver'] = inputData['userId'] ?? '';
  request.fields['vehicle'] = inputData['vehicleID'] ?? '';
  request.fields['km'] = inputData['km'] ?? '';

  print('Action: ${request.fields['action']}');
  print('Driver ID: ${request.fields['driver']}');
  print('Vehicle ID: ${request.fields['vehicle']}');
  print('KM: ${request.fields['km']}');

  for (int i = 1; i <= 6; i++) {
    String? imagePath = inputData['image$i'];
    if (imagePath != null && imagePath.isNotEmpty) {
      request.files
          .add(await http.MultipartFile.fromPath('photo$i', imagePath));
    }
  }

  try {
    var response = await request.send();
    if (response.statusCode == 200) {
      print("Image upload complete");
    } else {
      print("Image upload failed: ${response.statusCode}");
    }
  } catch (e) {
    print('Error uploading images: $e');
  }
}

Future<bool> uploadExpense(Map<String, dynamic>? inputData) async {
  if (inputData == null) {
    print("No input data for expense upload");
    return false;
  }

  var request = http.MultipartRequest(
    'POST',
    Uri.parse('https://vinczefi.com/greenfleet/flutter_functions_1.php'),
  );

  request.fields['action'] = 'vehicle-expense';
  request.fields['driver'] = inputData['driver'] ?? '';
  request.fields['vehicle'] = inputData['vehicle'] ?? '';
  request.fields['km'] = inputData['km'] ?? '';
  request.fields['type'] = inputData['type'] ?? '';
  request.fields['remarks'] = inputData['remarks'] ?? '';
  request.fields['cost'] = inputData['cost'] ?? '';

  String? imagePath = inputData['image'];

  if (imagePath != null && imagePath.isNotEmpty) {
    request.files.add(await http.MultipartFile.fromPath('photo', imagePath));
  }

  try {
    var response = await request.send();
    if (response.statusCode == 200) {
      print('Expense uploaded successfully in the background');
      return true;
    } else {
      print('Failed to upload expense in the background: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    print('Error uploading expense in background: $e');
    return false;
  }
}

Future<void> _uploadSavedExpenses() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? expenseData = prefs.getString("expensesData");
  if (expenseData != null) {
    print("Attempting to send saved expenses...");
    Map<String, dynamic> inputData = jsonDecode(expenseData);
    bool success = await uploadExpense(inputData);
    if (success) {
      await prefs.remove("expensesData");
    }
  }
}


Future<void> loginVehicle() async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentDateTime =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    Map<String, dynamic> operationData = {
      'driver': Globals.userId.toString(),
      'vehicle': Globals.vehicleID.toString(),
      'km': Globals.kmValue.toString(),
      'operationType': 'login',
      'datetime': currentDateTime,
    };

    await Workmanager().registerOneOffTask(
      "vehicleLogin_${DateTime.now().millisecondsSinceEpoch}",
      vehicleLoginTask,
      inputData: operationData,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.append,
    );

    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('vehicleId', Globals.vehicleID!);

    print("Vehicle login operation scheduled for: $currentDateTime");
  } catch (e) {
    print('Error scheduling vehicle login: $e');
  }
}

Future<void> logoutVehicle() async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentDateTime =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    Map<String, dynamic> operationData = {
      'driver': Globals.userId.toString(),
      'vehicle': Globals.vehicleID.toString(),
      'km': Globals.kmValue.toString(),
      'operationType': 'logout',
      'datetime': currentDateTime,
    };

    await Workmanager().registerOneOffTask(
      "vehicleLogout_${DateTime.now().millisecondsSinceEpoch}",
      vehicleLogoutTask,
      inputData: operationData,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.append,
    );

    await prefs.setString('pendingVehicleOperation', jsonEncode(operationData));

    print("Vehicle logout operation scheduled for: $currentDateTime");
  } catch (e) {
    print('Error scheduling vehicle logout: $e');
  }
}

void _listenForConnectivityChanges() {
  Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
    if (result != ConnectivityResult.none) {
      // Only handle expenses in the connectivity listener
      await _uploadSavedExpenses();
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SharedPreferences prefs = await SharedPreferences.getInstance();
  // Reset any stale locks on app start
  await prefs.setBool(operationLockKey, false);
  
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // Register the periodic connectivity check
  await Workmanager().registerPeriodicTask(
    "connectivityCheck",
    connectivityCheckTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );

  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  if (isLoggedIn) {
    Globals.userId = int.tryParse(prefs.getString('userId') ?? '');
    Globals.vehicleID = prefs.getInt('vehicleId');

    print('User ID loaded: ${Globals.userId}');

    _loadImagesFromPrefs();

    try {
      await carServices.initializeData();
      print('Car services initialized');
    } catch (e) {
      print('Error initializing car services: $e');
    }
  }

  _listenForConnectivityChanges();

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

Future<void> schedulePeriodicUpload() async {
  Workmanager().registerPeriodicTask(
    "uploadExpenseTaskId",
    uploadExpenseTask,
    frequency: const Duration(minutes: 15),
    inputData: {},
  );
}
// Function to load images from SharedPreferences
Future<void> _loadImagesFromPrefs() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? imagePath1 = prefs.getString('image1');
  String? imagePath2 = prefs.getString('image2');
  String? imagePath3 = prefs.getString('image3');
  String? imagePath4 = prefs.getString('image4');
  String? imagePath5 = prefs.getString('image5');
  String? imagePath6 = prefs.getString('image6');
  String? imagePath7 = prefs.getString('image7');
  String? imagePath8 = prefs.getString('image8');
  String? imagePath9 = prefs.getString('image9');
  String? imagePath10 = prefs.getString('image10');
  String? imagePathParcursIn = prefs.getString('parcursIn');
  String? imagePathParcursOut = prefs.getString('parcursout');

  if (imagePath1 != null) Globals.image1 = File(imagePath1);
  if (imagePath2 != null) Globals.image2 = File(imagePath2);
  if (imagePath3 != null) Globals.image3 = File(imagePath3);
  if (imagePath4 != null) Globals.image4 = File(imagePath4);
  if (imagePath5 != null) Globals.image5 = File(imagePath5);
  if (imagePath6 != null) Globals.image6 = File(imagePath6);
  if (imagePath7 != null) Globals.image7 = File(imagePath7);
  if (imagePath8 != null) Globals.image8 = File(imagePath8);
  if (imagePath9 != null) Globals.image9 = File(imagePath9);
  if (imagePath10 != null) Globals.image10 = File(imagePath10);
  if (imagePathParcursIn != null) Globals.parcursIn = File(imagePathParcursIn);
  if (imagePathParcursOut != null)
    Globals.parcursIn = File(imagePathParcursOut);
}

class InitialLoadingScreen extends StatefulWidget {
  final bool isLoggedIn;

  const InitialLoadingScreen({super.key, required this.isLoggedIn});

  @override
  State<InitialLoadingScreen> createState() => _InitialLoadingScreenState();
}

class _InitialLoadingScreenState extends State<InitialLoadingScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // If vehicles weren't loaded in main, try again
      if (carServices.cars.isEmpty) {
        await carServices.getCars();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Navigate to appropriate screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                widget.isLoggedIn ? const DriverPage() : const MyHomePage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading vehicles: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _errorMessage != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeData,
                    child: const Text('Retry'),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.fromARGB(255, 101, 204, 82),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Loading vehicles...'),
                ],
              ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GreenFleet Driver',
      theme: ThemeData(
        primaryColor: const Color.fromARGB(255, 101, 204, 82),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: Color.fromARGB(255, 101, 204, 82), width: 2.0),
          ),
          labelStyle: TextStyle(color: Colors.black),
        ),
      ),
      home: isLoggedIn ? const DriverPage() : const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;

  void _togglePasswordVisibility() {
    setState(() {
      _isObscure = !_isObscure;
    });
  }

  Future<void> login() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(255, 101, 204, 82), // Green color
                  ),
                ),
                SizedBox(width: 16),
                Text("Logging user in"),
              ],
            ),
          ),
        );
      },
    );

    final response = await http.post(
      Uri.parse('https://vinczefi.com/greenfleet/flutter_functions.php'),
      headers: <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'action': 'login',
        'username': _usernameController.text,
        'password': _passwordController.text,
        'type': 'driver',
      },
    );

    var data = json.decode(response.body);

    Navigator.of(context).pop(); // Hide loading dialog

    if (data['success']) {
      Globals.userId = data['driver_id'];
      Fluttertoast.showToast(
        msg: data['message'],
        backgroundColor: Colors.green,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
      );

      print(Globals.userId);
      await carServices.initializeData();

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', Globals.userId.toString());

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DriverPage(),
        ),
      );
    } else {
      Fluttertoast.showToast(
        backgroundColor: Colors.red,
        textColor: Colors.white,
        msg: data['message'],
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 101, 204, 82),
              Color.fromARGB(255, 220, 247, 214),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo or App Name
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        size: 50,
                        color: Color.fromARGB(255, 101, 204, 82),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'GreenFleet Driver',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 3.0,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Username TextField
                          TextField(
                            controller: _usernameController,
                            cursorColor:
                                const Color.fromARGB(255, 101, 204, 82),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Color.fromARGB(255, 101, 204, 82),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color.fromARGB(255, 101, 204, 82),
                                  width: 2.0,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            style: const TextStyle(color: Colors.black),
                          ),
                          const SizedBox(height: 16),
                          // Password TextField
                          TextField(
                            controller: _passwordController,
                            obscureText: _isObscure,
                            cursorColor:
                                const Color.fromARGB(255, 101, 204, 82),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color.fromARGB(255, 101, 204, 82),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isObscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color:
                                      const Color.fromARGB(255, 101, 204, 82),
                                ),
                                onPressed: _togglePasswordVisibility,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color.fromARGB(255, 101, 204, 82),
                                  width: 2.0,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            style: const TextStyle(color: Colors.black),
                          ),
                          const SizedBox(height: 24),
                          // Login Button
                          ElevatedButton(
                            onPressed: login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 101, 204, 82),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Version or copyright text
                    Text(
                      '© ${DateTime.now().year} GreenFleet',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
