import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'globals.dart'; // Import your globals.dart file
import 'driverPage.dart'; // Import DriverPage
import 'loginPage.dart'; // Import LoginPage
import 'package:workmanager/workmanager.dart';

// Constants for task names
const String uploadImageTask = "uploadImageTask";
const String uploadExpenseTask = "uploadExpenseTask";

// Callback dispatcher for handling background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case uploadImageTask:
        return await handleImageUpload(inputData);
      case uploadExpenseTask:
        return await handleExpenseUpload(inputData);
      default:
        return Future.value(false);
    }
  });
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
  try {
    await uploadExpense(inputData);
    return Future.value(true);
  } catch (e) {
    print('Error in expense upload task: $e');
    return Future.value(false);
  }
}

// Function to upload images in the background
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

  for (int i = 1; i <= 5; i++) {
    String? imagePath = inputData['image$i'];
    if (imagePath != null && imagePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('photo$i', imagePath));
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

// Function to upload expenses in the background
Future<void> uploadExpense(Map<String, dynamic>? inputData) async {
  if (inputData == null) {
    print("No input data for expense upload");
    return;
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
    } else {
      print('Failed to upload expense in the background: ${response.statusCode}');
    }
  } catch (e) {
    print('Error uploading expense in background: $e');
  }
}

// Function to handle vehicle login
Future<void> loginVehicle() async {
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://vinczefi.com/greenfleet/flutter_functions.php'),
    );

    request.fields['action'] = 'vehicle-login';
    request.fields['driver'] = Globals.userId.toString();
    request.fields['vehicle'] = Globals.vehicleID.toString();
    request.fields['km'] = Globals.kmValue.toString();
    var response = await request.send();

    if (response.statusCode == 200) {
      print("Login Complete");
    } else {
      print("Login Failed");
    }
  } catch (e) {
    print('Error during vehicle login: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  if (isLoggedIn) {
    Globals.userId = int.tryParse(prefs.getString('userId') ?? '');
    Globals.vehicleID = prefs.getInt('vehicleId'); // Correctly retrieve as int
    await _loadImagesFromPrefs();
  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

// Function to load images from SharedPreferences
Future<void> _loadImagesFromPrefs() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? imagePath1 = prefs.getString('image1');
  String? imagePath2 = prefs.getString('image2');
  String? imagePath3 = prefs.getString('image3');
  String? imagePath4 = prefs.getString('image4');
  String? imagePath5 = prefs.getString('image5');

  if (imagePath1 != null) Globals.image1 = File(imagePath1);
  if (imagePath2 != null) Globals.image2 = File(imagePath2);
  if (imagePath3 != null) Globals.image3 = File(imagePath3);
  if (imagePath4 != null) Globals.image4 = File(imagePath4);
  if (imagePath5 != null) Globals.image5 = File(imagePath5);
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(255, 101, 204, 82), // Green color
                  ),
                ),
                const SizedBox(width: 16),
                const Text("Logging user in"),
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
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 101, 204, 82),
        title: const Text('GreenFleet Driver'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _usernameController,
                cursorColor: const Color.fromARGB(255, 101, 204, 82),
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Color.fromARGB(255, 101, 204, 82), width: 2.0),
                  ),
                ),
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _passwordController,
                obscureText: _isObscure,
                cursorColor: const Color.fromARGB(255, 101, 204, 82),
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Color.fromARGB(255, 101, 204, 82), width: 2.0),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: _togglePasswordVisibility,
                  ),
                ),
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 16.0),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 80.0, vertical: 30.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                ),
                onPressed: login,
                child: const Text(
                  'Login',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
