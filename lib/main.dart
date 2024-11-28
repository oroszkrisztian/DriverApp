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




// Constants
const String vehicleLoginTask = "vehicleLoginTask";
const String vehicleLogoutTask = "vehicleLogoutTask";
const String uploadExpenseTask = "uploadExpenseTask";
const String connectivityCheckTask = "connectivityCheckTask";
const String operationLockKey = 'operationInProgress';
const String pendingOperationKey = 'pendingOperation';
const String pendingExpenseKey = 'pendingExpense';

final CarServices carServices = CarServices();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case vehicleLoginTask:
        return await handleVehicleOperation(inputData, isLogin: true);
      case vehicleLogoutTask:
        return await handleVehicleOperation(inputData, isLogin: false);
      case uploadExpenseTask:
        return await handleExpenseUpload(inputData);
      case connectivityCheckTask:
        return await handleConnectivityCheck();
      default:
        return Future.value(false);
    }
  });
}

Future<bool> handleVehicleOperation(Map<String, dynamic>? inputData, {required bool isLogin}) async {
  if (inputData == null) {
    print("No input data for vehicle operation");
    return true;
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isOperationInProgress = prefs.getBool(operationLockKey) ?? false;

  if (isOperationInProgress) {
    print("Another operation in progress, will retry later");
    return false;
  }

  try {
    await prefs.setBool(operationLockKey, true);
    String timestamp = inputData['timestamp'] ?? '';
    print("Starting ${isLogin ? 'login' : 'logout'} operation...");

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://vinczefi.com/greenfleet/flutter_functions.php'),
    );

    request.fields['action'] = 'vehicle-log-photos';
    request.fields['driver'] = inputData['driver'] ?? '';
    request.fields['vehicle'] = inputData['vehicle'] ?? '';
    request.fields['km'] = inputData['km'] ?? '';

    // Add photos based on login/logout
    bool hasPhotos = false;
    if (isLogin) {
      for (int i = 1; i <= 5; i++) {
        String? imagePath = inputData['image$i'];
        if (imagePath != null && await File(imagePath).exists()) {
          request.files.add(await http.MultipartFile.fromPath('photo$i', imagePath));
          hasPhotos = true;
        }
      }
      if (inputData['parcursIn'] != null && await File(inputData['parcursIn']).exists()) {
        request.files.add(await http.MultipartFile.fromPath('photo6', inputData['parcursIn']));
        hasPhotos = true;
      }
    } else {
      for (int i = 6; i <= 10; i++) {
        String? imagePath = inputData['image$i'];
        if (imagePath != null && await File(imagePath).exists()) {
          request.files.add(await http.MultipartFile.fromPath('photo${i-5}', imagePath));
          hasPhotos = true;
        }
      }
      if (inputData['parcursOut'] != null && await File(inputData['parcursOut']).exists()) {
        request.files.add(await http.MultipartFile.fromPath('photo6', inputData['parcursOut']));
        hasPhotos = true;
      }
    }

    if (!hasPhotos) {
      print("No photos found for upload");
      await _cleanupOperation(prefs, timestamp, isLogin);
      return true;
    }

    print("Sending request with photos...");
    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    print("Operation response: $responseData");

    // Handle multiple JSON responses
    try {
      // Split response at the first closing brace followed by an opening brace
      List<String> responses = responseData.split('}{');

      // Fix the split responses to be valid JSON
      if (responses.length > 1) {
        responses[0] = responses[0] + '}';
        responses[1] = '{' + responses[1];
      }

      // Parse first response (vehicle operation)
      var operationResult = json.decode(responses[0]);
      bool operationSuccess = operationResult['success'] == true;

      // Parse second response (photo upload) if exists
      bool photoSuccess = true;
      if (responses.length > 1) {
        var photoResult = json.decode(responses[1]);
        photoSuccess = photoResult['success'] == true;
      }

      if (operationSuccess && photoSuccess) {
        await _cleanupOperation(prefs, timestamp, isLogin);

        // Cancel the background task for this operation
        String taskName = isLogin ? "vehicleLogin_$timestamp" : "vehicleLogout_$timestamp";
        await Workmanager().cancelByUniqueName(taskName);

        return true;
      }
    } catch (e) {
      print('Error parsing operation response: $e');
    }

    return false;
  } catch (e) {
    print('Error in vehicle operation: $e');
    return false;
  } finally {
    await prefs.setBool(operationLockKey, false);
  }
}


Future<void> _cleanupOperation(SharedPreferences prefs, String timestamp, bool isLogin) async {
  await prefs.remove(pendingOperationKey);

  // Cancel specific operation task
  String taskName = isLogin ? "vehicleLogin_$timestamp" : "vehicleLogout_$timestamp";
  await Workmanager().cancelByUniqueName(taskName);

  if (!isLogin) {
    // Additional cleanup for logout
    await prefs.remove('vehicleId');
    await prefs.remove('lastKmValue');
    Globals.vehicleID = null;
    Globals.kmValue = null;
  }
}

Future<bool> loginVehicle(String loginDate) async {
  var connectivityResult = await Connectivity().checkConnectivity();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  Map<String, dynamic> operationData = {
    'driver': Globals.userId.toString(),
    'vehicle': Globals.vehicleID.toString(),
    'km': Globals.kmValue.toString(),
    'timestamp': loginDate,
  };

  // Add photos
  if (Globals.image1?.path != null) operationData['image1'] = Globals.image1!.path;
  if (Globals.image2?.path != null) operationData['image2'] = Globals.image2!.path;
  if (Globals.image3?.path != null) operationData['image3'] = Globals.image3!.path;
  if (Globals.image4?.path != null) operationData['image4'] = Globals.image4!.path;
  if (Globals.image5?.path != null) operationData['image5'] = Globals.image5!.path;
  if (Globals.parcursIn?.path != null) operationData['parcursIn'] = Globals.parcursIn!.path;

  // Save state
  await prefs.setBool('isLoggedIn', true);
  await prefs.setInt('vehicleId', Globals.vehicleID!);
  await prefs.setString('lastKmValue', Globals.kmValue.toString());
  await _saveImagesToPrefs();

  if (connectivityResult != ConnectivityResult.none) {
    bool success = await handleVehicleOperation(operationData, isLogin: true);
    if (success) {
      Fluttertoast.showToast(
        msg: "Login successful",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      String taskName = "vehicleLogin_$loginDate";
      await Workmanager().cancelByUniqueName(taskName);
      return true;
    }
  }

  // Store for background processing
  await prefs.setString(pendingOperationKey, jsonEncode(operationData));

  // Add to pending operations list
  List<Map<String, dynamic>> pendingOperations = [];
  String? existingOperations = prefs.getString('pendingOperations');
  if (existingOperations != null) {
    pendingOperations = List<Map<String, dynamic>>.from(jsonDecode(existingOperations));
  }
  pendingOperations.add(operationData);
  await prefs.setString('pendingOperations', jsonEncode(pendingOperations));

  // Schedule task
  String taskName = "vehicleLogin_$loginDate";
  print("Registering task with name: $taskName");
  await Workmanager().registerOneOffTask(
    taskName,
    vehicleLoginTask,
    inputData: operationData,
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    initialDelay: const Duration(seconds: 10),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(seconds: 30),
  );

  Fluttertoast.showToast(
    msg: "Login scheduled for background upload",
    backgroundColor: Colors.orange,
    textColor: Colors.white,
  );

  return true;
}


Future<bool> logoutVehicle(String logoutDate) async {
  var connectivityResult = await Connectivity().checkConnectivity();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  Map<String, dynamic> operationData = {
    'driver': Globals.userId.toString(),
    'vehicle': Globals.vehicleID.toString(),
    'km': Globals.kmValue.toString(),
    'timestamp': logoutDate,
  };

  if (Globals.image6?.path != null) operationData['image6'] = Globals.image6!.path;
  if (Globals.image7?.path != null) operationData['image7'] = Globals.image7!.path;
  if (Globals.image8?.path != null) operationData['image8'] = Globals.image8!.path;
  if (Globals.image9?.path != null) operationData['image9'] = Globals.image9!.path;
  if (Globals.image10?.path != null) operationData['image10'] = Globals.image10!.path;
  if (Globals.parcursOut?.path != null) operationData['parcursOut'] = Globals.parcursOut!.path;

  if (connectivityResult != ConnectivityResult.none) {
    bool success = await handleVehicleOperation(operationData, isLogin: false);
    if (success) {
      await _cleanupOperation(prefs, logoutDate, false);
      String taskName = "vehicleLogout_$logoutDate";
      await Workmanager().cancelByUniqueName(taskName);

      Fluttertoast.showToast(
        msg: "Logout successful",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      return true;
    }
  }

  await prefs.setString(pendingOperationKey, jsonEncode(operationData));

  // Add to pending operations list
  List<Map<String, dynamic>> pendingOperations = [];
  String? existingOperations = prefs.getString('pendingOperations');
  if (existingOperations != null) {
    pendingOperations = List<Map<String, dynamic>>.from(jsonDecode(existingOperations));
  }
  pendingOperations.add(operationData);
  await prefs.setString('pendingOperations', jsonEncode(pendingOperations));

  String taskName = "vehicleLogout_$logoutDate";
  print("Registering task with name: $taskName");
  await Workmanager().registerOneOffTask(
    taskName,
    vehicleLogoutTask,
    inputData: operationData,
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    initialDelay: const Duration(seconds: 10),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(seconds: 30),
  );

  Fluttertoast.showToast(
    msg: "Logout scheduled for background upload",
    backgroundColor: Colors.orange,
    textColor: Colors.white,
  );

  return true;
}

Future<bool> handleExpenseUpload(Map<String, dynamic>? inputData) async {
  if (inputData == null) {
    print("No input data for expense upload");
    return true;
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String timestamp = inputData['timestamp'] ?? '';

  try {
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

    // Add expense photo if exists
    String? imagePath = inputData['image'];
    if (imagePath != null && imagePath.isNotEmpty) {
      File imageFile = File(imagePath);
      if (await imageFile.exists()) {
        request.files.add(await http.MultipartFile.fromPath('photo', imagePath));
      }
    }

    print("Sending expense request...");
    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    print("Expense response: $responseData");

    if (response.statusCode == 200) {
      var data = json.decode(responseData);
      if (data['success'] == true) {
        await prefs.remove(pendingExpenseKey);
        await Workmanager().cancelByUniqueName("expense_$timestamp");
        return true;
      }
    }

    return false;
  } catch (e) {
    print('Error uploading expense: $e');
    return false;
  }
}

Future<bool> uploadExpense(Map<String, dynamic> expenseData) async {
  var connectivityResult = await Connectivity().checkConnectivity();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  String timestamp = DateTime.now().toIso8601String();
  expenseData['timestamp'] = timestamp;

  if (connectivityResult != ConnectivityResult.none) {
    // Try immediate upload if we have connection
    bool success = await handleExpenseUpload(expenseData);
    if (success) {
      Fluttertoast.showToast(
        msg: "Expense uploaded successfully",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      return true;
    }
  }

  // If immediate upload failed or no connection, save for background upload
  await prefs.setString(pendingExpenseKey, jsonEncode(expenseData));

  await Workmanager().registerOneOffTask(
    "expense_$timestamp",
    uploadExpenseTask,
    inputData: expenseData,
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    initialDelay: const Duration(seconds: 10),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(seconds: 30),
  );

  Fluttertoast.showToast(
    msg: "Expense saved for background upload",
    backgroundColor: Colors.orange,
    textColor: Colors.white,
  );

  return true;
}

Future<bool> handleConnectivityCheck() async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String lockKey = 'operationLock';
    bool hasLock = false;

    try {
      if (prefs.getBool(lockKey) == true) return true;
      await prefs.setBool(lockKey, true);
      hasLock = true;

      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        // Get all pending operations and sort by timestamp
        List<Map<String, dynamic>> pendingOperations = [];
        String? pendingOperation = prefs.getString(pendingOperationKey);

        if (pendingOperation != null) {
          Map<String, dynamic> operationData = jsonDecode(pendingOperation);
          pendingOperations.add(operationData);
        }

        // Sort operations by timestamp
        pendingOperations.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

        // Process operations in order
        for (var operation in pendingOperations) {
          String timestamp = operation['timestamp'] ?? '';
          bool isLogin = operation.containsKey('parcursIn');

          bool wasProcessed = prefs.getBool('processed_${timestamp}') ?? false;
          if (!wasProcessed) {
            bool success = await handleVehicleOperation(operation, isLogin: isLogin);
            if (success) {
              await _cleanupOperation(prefs, timestamp, isLogin);
              await prefs.setBool('processed_${timestamp}', true);
            } else {
              // Stop processing if an operation fails
              break;
            }
          }
        }
      }
      return true;
    } finally {
      if (hasLock) await prefs.setBool(lockKey, false);
    }
  } catch (e) {
    print('Error in connectivity check: $e');
    return false;
  }
}





Future<void> _saveImagesToPrefs() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Login images (1-5 and parcursIn)
  if (Globals.image1?.path != null) await prefs.setString('image1', Globals.image1!.path);
  if (Globals.image2?.path != null) await prefs.setString('image2', Globals.image2!.path);
  if (Globals.image3?.path != null) await prefs.setString('image3', Globals.image3!.path);
  if (Globals.image4?.path != null) await prefs.setString('image4', Globals.image4!.path);
  if (Globals.image5?.path != null) await prefs.setString('image5', Globals.image5!.path);
  if (Globals.parcursIn?.path != null) await prefs.setString('parcursIn', Globals.parcursIn!.path);

  // Logout images (6-10 and parcursOut)
  if (Globals.image6?.path != null) await prefs.setString('image6', Globals.image6!.path);
  if (Globals.image7?.path != null) await prefs.setString('image7', Globals.image7!.path);
  if (Globals.image8?.path != null) await prefs.setString('image8', Globals.image8!.path);
  if (Globals.image9?.path != null) await prefs.setString('image9', Globals.image9!.path);
  if (Globals.image10?.path != null) await prefs.setString('image10', Globals.image10!.path);
  if (Globals.parcursOut?.path != null) await prefs.setString('parcursOut', Globals.parcursOut!.path);
}

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

  // Load login images (1-5 and parcursIn)
  Globals.image1 = await getFileIfExists(prefs.getString('image1'));
  Globals.image2 = await getFileIfExists(prefs.getString('image2'));
  Globals.image3 = await getFileIfExists(prefs.getString('image3'));
  Globals.image4 = await getFileIfExists(prefs.getString('image4'));
  Globals.image5 = await getFileIfExists(prefs.getString('image5'));
  Globals.parcursIn = await getFileIfExists(prefs.getString('parcursIn'));

  // Load logout images (6-10 and parcursOut)
  Globals.image6 = await getFileIfExists(prefs.getString('image6'));
  Globals.image7 = await getFileIfExists(prefs.getString('image7'));
  Globals.image8 = await getFileIfExists(prefs.getString('image8'));
  Globals.image9 = await getFileIfExists(prefs.getString('image9'));
  Globals.image10 = await getFileIfExists(prefs.getString('image10'));
  Globals.parcursOut = await getFileIfExists(prefs.getString('parcursOut'));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Reset stale locks
  await prefs.setBool(operationLockKey, false);

  // Initialize Workmanager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  int? activeVehicleId = prefs.getInt('vehicleId');
  String? userId = prefs.getString('userId');

  if (isLoggedIn && userId != null) {
    Globals.userId = int.tryParse(userId);
    Globals.vehicleID = activeVehicleId;
    Globals.kmValue = prefs.getString('lastKmValue');

    // Load saved images
    await _loadImagesFromPrefs();

    // Register periodic tasks if logged in
    if (activeVehicleId != null) {
      await Workmanager().registerPeriodicTask(
        "connectivityCheck",
        connectivityCheckTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        initialDelay: const Duration(minutes: 1),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }

    try {
      await carServices.initializeData();
    } catch (e) {
      print('Error initializing car services: $e');
    }
  }

  // Set up connectivity listener
  Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
    if (result != ConnectivityResult.none) {
      // Check for pending operations when connectivity is restored
      await handleConnectivityCheck();
    }
  });

  runApp(MyApp(isLoggedIn: isLoggedIn));
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(255, 1, 160, 226),
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
    try {
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

      print("Server Response Status Code: ${response.statusCode}");
      print("Raw Server Response: ${response.body}");

      var data = json.decode(response.body);
      print("Decoded Response Data: $data");
      print("Success Value: ${data['success']}");
      print("Driver ID: ${data['driver_id']}");
      print("Message: ${data['message']}");

      Navigator.of(context).pop(); // Hide loading dialog

      if (data['success']) {
        if (data['driver_id'] != null) {
          carServices.initializeData();
          Globals.userId = data['driver_id'];
          print("Set Global User ID to: ${Globals.userId}");

          Fluttertoast.showToast(
            msg: data['message'],
            backgroundColor: Colors.green,
            textColor: Colors.white,
            toastLength: Toast.LENGTH_SHORT,
          );

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userId', Globals.userId.toString());
          print("Saved to SharedPreferences - userId: ${Globals.userId}");

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DriverPage(),
            ),
          );
        } else {
          print("Login Failed: User ID is null");
          Fluttertoast.showToast(
            backgroundColor: Colors.red,
            textColor: Colors.white,
            msg: "User not found",
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      }
    } catch (e) {
      Navigator.of(context).pop();
      print("Login Error: $e");
      Fluttertoast.showToast(
        backgroundColor: Colors.red,
        textColor: Colors.white,
        msg: "An error occurred: $e",
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
