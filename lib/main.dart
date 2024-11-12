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
const String imageUploadLockKey = 'imageUploadInProgress';
const String pendingImagesKey = 'pendingImages';

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
      int? activeVehicleId = prefs.getInt('vehicleId');

      if (!isOperationInProgress) {
        await prefs.setBool(operationLockKey, true);
        try {
          // Process pending vehicle operations first
          String? pendingOperation = prefs.getString('pendingVehicleOperation');
          if (pendingOperation != null) {
            Map<String, dynamic> operationData = jsonDecode(pendingOperation);
            print("Found pending operation: ${operationData['operationType']}");
            // Process the operation regardless of type
            bool success = await uploadVehicleOperation(operationData);
            if (success) {
              print("Successfully processed pending operation");
              await prefs.remove('pendingVehicleOperation');
              // If it was a logout operation, clear vehicle data
              if (operationData['operationType'] == 'logout') {
                print("Clearing vehicle data after successful logout");
                await prefs.remove('vehicleId');
                await prefs.remove('lastKmValue');
                Globals.vehicleID = null;
              }
            }
          }

          // Then handle pending images
          String? pendingImages = prefs.getString(pendingImagesKey);
          if (pendingImages != null) {
            await handleImageUpload(jsonDecode(pendingImages));
          }

          // Finally handle pending expenses
          String? pendingExpense = prefs.getString('expensesData');
          if (pendingExpense != null) {
            await uploadExpense(jsonDecode(pendingExpense));
          }
        } finally {
          await prefs.setBool(operationLockKey, false);
        }
      }
    }
    return true;
  } catch (e) {
    print('Error in connectivity check: $e');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(operationLockKey, false);
    return false;
  }
}

// Handling image upload task
Future<bool> handleImageUpload(Map<String, dynamic>? inputData) async {
  if (inputData == null) {
    print("No input data for image upload");
    return false;
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isUploadInProgress = prefs.getBool(imageUploadLockKey) ?? false;

  if (isUploadInProgress) {
    print("Another image upload is in progress");
    return false;
  }

  try {
    await prefs.setBool(imageUploadLockKey, true);
    await prefs.setString(pendingImagesKey, jsonEncode(inputData));

    bool success = await uploadImages(inputData);

    if (success) {
      await prefs.remove(pendingImagesKey);
    }

    return success;
  } catch (e) {
    print('Error in image upload task: $e');
    return false;
  } finally {
    await prefs.setBool(imageUploadLockKey, false);
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
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (operationType == VehicleOperationType.logout) {
        inputData?['requestedLogout'] = true; // Add flag for explicit logout
      }
      await prefs.setString('pendingVehicleOperation', json.encode(inputData));
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
    request.fields['time'] = inputData['datetime'] ?? '';

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

Future<bool> uploadImages(Map<String, dynamic>? inputData) async {
  if (inputData == null) {
    print("No input data for image upload");
    return false;
  }

  try {
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

    var response = await request.send();
    if (response.statusCode == 200) {
      print("Image upload complete");
      return true;
    } else {
      print("Image upload failed: ${response.statusCode}");
      return false;
    }
  } catch (e) {
    print('Error uploading images: $e');
    return false;
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
      print(
          'Failed to upload expense in the background: ${response.statusCode}');
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

Future<void> loginVehicle(String loginDate) async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> operationData = {
      'driver': Globals.userId.toString(),
      'vehicle': Globals.vehicleID.toString(),
      'km': Globals.kmValue.toString(),
      'operationType': 'login',
      'datetime': loginDate,
    };

    // Save operation data first
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('vehicleId', Globals.vehicleID!);
    await prefs.setString('lastKmValue', Globals.kmValue.toString());
    await _saveImagesToPrefs(); // Save images when logging in

    // Then schedule the task
    await Workmanager().registerOneOffTask(
      "vehicleLogin_$loginDate",
      vehicleLoginTask,
      inputData: operationData,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.append,
    );

    print("Vehicle login operation scheduled for: $loginDate");
  } catch (e) {
    print('Error scheduling vehicle login: $e');
  }
}

Future<void> logoutVehicle(String logoutDate) async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> operationData = {
      'driver': Globals.userId.toString(),
      'vehicle': Globals.vehicleID.toString(),
      'km': Globals.kmValue.toString(),
      'operationType': 'logout',
      'datetime': logoutDate,
    };

    // Save the operation data first
    print("Saving logout operation data");
    await prefs.setString('pendingVehicleOperation', jsonEncode(operationData));

    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      print("Has connectivity, attempting immediate logout");
      // Try immediate logout
      bool success = await uploadVehicleOperation(operationData);
      if (success) {
        print("Immediate logout successful");
        await prefs.remove('pendingVehicleOperation');
        await prefs.remove('vehicleId');
        await prefs.remove('lastKmValue');
        Globals.vehicleID = null;
        return;
      }
    }

    // If we're here, either no connectivity or immediate upload failed
    print("Scheduling background logout task");
    await Workmanager().registerOneOffTask(
      "vehicleLogout_$logoutDate",
      vehicleLogoutTask,
      inputData: operationData,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.append,
    );

    // Register periodic connectivity check if not already registered
    await Workmanager().registerPeriodicTask(
      "connectivityCheck",
      connectivityCheckTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    print("Vehicle logout operation scheduled for background processing");
  } catch (e) {
    print('Error scheduling vehicle logout: $e');
    throw e;
  }
}

void _listenForConnectivityChanges() {
  Connectivity()
      .onConnectivityChanged
      .listen((ConnectivityResult result) async {
    if (result != ConnectivityResult.none) {
      // Only handle expenses in the connectivity listener
      await _uploadSavedExpenses();
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Reset stale locks
  await prefs.setBool(operationLockKey, false);
  await prefs.setBool(imageUploadLockKey, false);

  // Remove any unintentional pending operations
  String? pendingOperation = prefs.getString('pendingVehicleOperation');
  if (pendingOperation != null) {
    Map<String, dynamic> operationData = jsonDecode(pendingOperation);
    if (operationData['requestedLogout'] != true) {
      await prefs.remove('pendingVehicleOperation');
    }
  }

  // Initialize Workmanager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  int? activeVehicleId = prefs.getInt('vehicleId');
  String? userId = prefs.getString('userId');

  if (isLoggedIn && userId != null) {
    Globals.userId = int.tryParse(userId);
    Globals.vehicleID = activeVehicleId;
    Globals.kmValue = prefs.getString('lastKmValue');

    await _loadImagesFromPrefs();

    // Only register connectivity check if logged into a vehicle
    if (activeVehicleId != null) {
      await Workmanager().registerPeriodicTask(
        "connectivityCheck",
        connectivityCheckTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        inputData: {
          'checkType': 'periodic', // Add this to identify periodic checks
        },
      );
    }

    try {
      await carServices.initializeData();
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

Future<void> _saveImagesToPrefs() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (Globals.image1?.path != null)
    await prefs.setString('image1', Globals.image1!.path);
  if (Globals.image2?.path != null)
    await prefs.setString('image2', Globals.image2!.path);
  if (Globals.image3?.path != null)
    await prefs.setString('image3', Globals.image3!.path);
  if (Globals.image4?.path != null)
    await prefs.setString('image4', Globals.image4!.path);
  if (Globals.image5?.path != null)
    await prefs.setString('image5', Globals.image5!.path);
  if (Globals.image6?.path != null)
    await prefs.setString('image6', Globals.image6!.path);
  if (Globals.image7?.path != null)
    await prefs.setString('image7', Globals.image7!.path);
  if (Globals.image8?.path != null)
    await prefs.setString('image8', Globals.image8!.path);
  if (Globals.image9?.path != null)
    await prefs.setString('image9', Globals.image9!.path);
  if (Globals.image10?.path != null)
    await prefs.setString('image10', Globals.image10!.path);
  if (Globals.parcursIn?.path != null)
    await prefs.setString('parcursIn', Globals.parcursIn!.path);
  if (Globals.parcursOut?.path != null)
    await prefs.setString('parcursOut', Globals.parcursOut!.path);
}

// Function to load images from SharedPreferences
Future<void> _loadImagesFromPrefs() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  Future<File?> getFileIfExists(String? path) async {
    if (path != null) {
      File file = File(path);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  Globals.image1 = await getFileIfExists(prefs.getString('image1'));
  Globals.image2 = await getFileIfExists(prefs.getString('image2'));
  Globals.image3 = await getFileIfExists(prefs.getString('image3'));
  Globals.image4 = await getFileIfExists(prefs.getString('image4'));
  Globals.image5 = await getFileIfExists(prefs.getString('image5'));
  Globals.image6 = await getFileIfExists(prefs.getString('image6'));
  Globals.image7 = await getFileIfExists(prefs.getString('image7'));
  Globals.image8 = await getFileIfExists(prefs.getString('image8'));
  Globals.image9 = await getFileIfExists(prefs.getString('image9'));
  Globals.image10 = await getFileIfExists(prefs.getString('image10'));
  Globals.parcursIn = await getFileIfExists(prefs.getString('parcursIn'));
  Globals.parcursOut = await getFileIfExists(prefs.getString('parcursOut'));
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
