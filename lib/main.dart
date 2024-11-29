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
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
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

  try {
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
    request.fields['current-date-time'] = timestamp;

    print("Action: ${request.fields['action']}");
    print("Driver: ${request.fields['driver']}");
    print("Vehicle: ${request.fields['vehicle']}");
    print("KM: ${request.fields['km']}");
    print("Date: ${request.fields['current-date-time']}");

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
      return true;
    }

    print("Sending request with photos...");
    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    print("Operation response: $responseData");

    try {
      // Handle the case where we get multiple JSON responses
      List<String> responses = responseData.split('}{');
      if (responses.length > 1) {
        responses[0] = responses[0] + '}';
        responses[1] = '{' + responses[1];
      }

      // Process first response (operation result)
      var operationResult = json.decode(responses[0]);
      bool operationSuccess = operationResult['success'] == true;

      // Process second response (photo upload result) if it exists
      bool photoSuccess = true;
      if (responses.length > 1) {
        var photoResult = json.decode(responses[1]);
        photoSuccess = photoResult['success'] == true;
      }

      return operationSuccess && photoSuccess;
    } catch (e) {
      print('Error parsing operation response: $e');
      // If we can't parse the response but we know the server returned success messages
      // (based on the log output), we can still return true
      return responseData.contains('"success":true');
    }
  } catch (e) {
    print('Error in vehicle operation: $e');
    return false;
  }
}

Future<void> _cleanupOperation(SharedPreferences prefs, String timestamp, bool isLogin) async {
  if (!isLogin) {
    await prefs.remove('vehicleId');
    await prefs.remove('lastKmValue');
    Globals.vehicleID = null;
    Globals.kmValue = null;
  }
}

Future<void> showUploadDialog(BuildContext context) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? pendingOperations = prefs.getString('pendingOperations');
  String? pendingExpenses = prefs.getString('pendingExpenses');

  // Return if nothing to upload
  if (pendingOperations == null && pendingExpenses == null) return;

  // Parse the pending data
  List<Map<String, dynamic>> operations = [];
  List<Map<String, dynamic>> expenses = [];

  if (pendingOperations != null) {
    operations = List<Map<String, dynamic>>.from(jsonDecode(pendingOperations));
  }
  if (pendingExpenses != null) {
    expenses = List<Map<String, dynamic>>.from(jsonDecode(pendingExpenses));
  }

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            elevation: 5,

            title: const Text(
              'Internet Connection Found',
              style: TextStyle(
                color: Color.fromARGB(255, 101, 204, 82),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'There are pending items to upload:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vehicle Operations
                        if (operations.isNotEmpty) ...[
                          const Text(
                            'Vehicle Operations',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 101, 204, 82),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...operations.map((operation) {
                            bool isLogin = operation.containsKey('parcursIn');
                            String timestamp = operation['timestamp'] ?? '';
                            DateTime? dateTime = DateTime.tryParse(timestamp);
                            String formattedTime = dateTime != null
                                ? '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}'
                                : timestamp;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    isLogin ? Icons.login : Icons.logout,
                                    color: const Color.fromARGB(255, 101, 204, 82),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${isLogin ? "Login" : "Logout"}: $formattedTime',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        // Expenses Section
                        if (expenses.isNotEmpty) ...[
                          if (operations.isNotEmpty) const SizedBox(height: 16),
                          const Text(
                            'Expenses',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 101, 204, 82),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...expenses.map((expense) {
                            String timestamp = expense['timestamp'] ?? '';
                            DateTime? dateTime = DateTime.tryParse(timestamp);
                            String formattedTime = dateTime != null
                                ? '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}'
                                : timestamp;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.receipt_long,
                                    color: Color.fromARGB(255, 101, 204, 82),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${expense['type']} - ${expense['cost']} EUR',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          formattedTime,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Would you like to upload these items now?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),

            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Later',
                  style: TextStyle(fontSize: 16),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Upload Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color.fromARGB(255, 101, 204, 82),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Uploading items...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );

                  try {
                    // Create backups
                    final String operationsBackup = jsonEncode(operations);
                    final String expensesBackup = jsonEncode(expenses);

                    // Track successful uploads
                    List<Map<String, dynamic>> successfulOperations = [];
                    List<Map<String, dynamic>> successfulExpenses = [];
                    String errorMessage = '';

                    // Upload vehicle operations
                    if (operations.isNotEmpty) {
                      for (var operation in operations) {
                        try {
                          bool isLogin = operation.containsKey('parcursIn');
                          bool success = await handleVehicleOperation(operation, isLogin: isLogin);
                          if (success) {
                            successfulOperations.add(operation);
                            // Clear vehicle data if this was a logout operation
                            if (!isLogin) {
                              await prefs.remove('vehicleId');
                              await prefs.remove('lastKmValue');
                              Globals.vehicleID = null;
                              Globals.kmValue = null;
                            }
                          }
                        } catch (e) {
                          errorMessage += 'Vehicle operations error: $e\n';
                          break;
                        }
                      }

                      // Double check if we need to clear vehicle data
                      if (operations.isNotEmpty) {
                        var lastOperation = operations.last;
                        bool wasLogout = !lastOperation.containsKey('parcursIn');
                        if (wasLogout) {
                          await prefs.remove('vehicleId');
                          await prefs.remove('lastKmValue');
                          Globals.vehicleID = null;
                          Globals.kmValue = null;

                          // Clear image globals
                          Globals.image6 = null;
                          Globals.image7 = null;
                          Globals.image8 = null;
                          Globals.image9 = null;
                          Globals.image10 = null;
                          Globals.parcursOut = null;
                        }
                      }
                    }

                    // Upload expenses
                    if (expenses.isNotEmpty) {
                      for (var expense in expenses) {
                        try {
                          bool success = await handleExpenseUpload(expense);
                          if (success) {
                            successfulExpenses.add(expense);
                          }
                        } catch (e) {
                          errorMessage += 'Expenses error: $e\n';
                          break;
                        }
                      }
                    }

                    // Handle remaining items if any uploads failed
                    bool hasRemainingItems = false;
                    if (successfulOperations.length < operations.length) {
                      List<Map<String, dynamic>> remainingOperations =
                      List<Map<String, dynamic>>.from(jsonDecode(operationsBackup));
                      remainingOperations.removeWhere(
                              (op) => successfulOperations.any((success) =>
                          success['timestamp'] == op['timestamp']));
                      if (remainingOperations.isNotEmpty) {
                        await prefs.setString('pendingOperations', jsonEncode(remainingOperations));
                        hasRemainingItems = true;
                      }
                    }

                    if (successfulExpenses.length < expenses.length) {
                      List<Map<String, dynamic>> remainingExpenses =
                      List<Map<String, dynamic>>.from(jsonDecode(expensesBackup));
                      remainingExpenses.removeWhere(
                              (exp) => successfulExpenses.any((success) =>
                          success['timestamp'] == exp['timestamp']));
                      if (remainingExpenses.isNotEmpty) {
                        await prefs.setString('pendingExpenses', jsonEncode(remainingExpenses));
                        hasRemainingItems = true;
                      }
                    }

                    // Clean up fully uploaded items
                    if (successfulOperations.length == operations.length) {
                      await prefs.remove('pendingOperations');
                    }
                    if (successfulExpenses.length == expenses.length) {
                      await prefs.remove('pendingExpenses');
                    }

                    Navigator.of(context).pop(); // Close loading dialog
                    Navigator.of(context).pop(); // Close main dialog

                    if (hasRemainingItems) {
                      Fluttertoast.showToast(
                        msg: "Upload partially completed.\n" +
                            "Operations: ${successfulOperations.length}/${operations.length}\n" +
                            "Expenses: ${successfulExpenses.length}/${expenses.length}\n" +
                            (errorMessage.isNotEmpty ? "Errors: $errorMessage" : ""),
                        backgroundColor: Colors.orange,
                        textColor: Colors.white,
                        toastLength: Toast.LENGTH_LONG,
                      );
                    } else {
                      Fluttertoast.showToast(
                        msg: "All items uploaded successfully",
                        backgroundColor: Colors.green,
                        textColor: Colors.white,
                      );
                    }
                  } catch (e) {
                    Navigator.of(context).pop(); // Close loading dialog
                    Navigator.of(context).pop(); // Close main dialog

                    Fluttertoast.showToast(
                      msg: "Error during upload: $e",
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                    );
                  }
                },
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          );
        },
      );
    },
  );
}

Future<void> checkConnectivityAndShowDialog(BuildContext context) async {
  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult != ConnectivityResult.none) {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? pendingOperations = prefs.getString('pendingOperations');
    String? pendingExpenses = prefs.getString('pendingExpenses');

    // Show dialog if either type of pending data exists
    if (pendingOperations != null || pendingExpenses != null) {
      if (context.mounted) {
        await showUploadDialog(context);
      }
    }
  }
}

Future<bool> loginVehicle(String loginDate) async {
  var connectivityResult = await Connectivity().checkConnectivity();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  print("LoginDate in loginvehicle $loginDate");

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
      return true;
    }
  }

  // Store for later upload
  List<Map<String, dynamic>> pendingOperations = [];
  String? existingOperations = prefs.getString('pendingOperations');
  if (existingOperations != null) {
    pendingOperations = List<Map<String, dynamic>>.from(jsonDecode(existingOperations));
  }
  pendingOperations.add(operationData);
  await prefs.setString('pendingOperations', jsonEncode(pendingOperations));

  Fluttertoast.showToast(
    msg: "Login saved for later upload",
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

  // Add photos to operation data
  if (Globals.image6?.path != null) operationData['image6'] = Globals.image6!.path;
  if (Globals.image7?.path != null) operationData['image7'] = Globals.image7!.path;
  if (Globals.image8?.path != null) operationData['image8'] = Globals.image8!.path;
  if (Globals.image9?.path != null) operationData['image9'] = Globals.image9!.path;
  if (Globals.image10?.path != null) operationData['image10'] = Globals.image10!.path;
  if (Globals.parcursOut?.path != null) operationData['parcursOut'] = Globals.parcursOut!.path;

  if (connectivityResult != ConnectivityResult.none) {
    // Attempt immediate upload of both logout and any pending expenses
    try {
      // First handle logout
      bool logoutSuccess = await handleVehicleOperation(operationData, isLogin: false);

      // Then check and handle any pending expenses
      String? pendingExpenses = prefs.getString('pendingExpenses');
      if (pendingExpenses != null) {
        List<Map<String, dynamic>> expenses = List<Map<String, dynamic>>.from(jsonDecode(pendingExpenses));
        for (var expense in expenses) {
          await handleExpenseUpload(expense);
        }
        await prefs.remove('pendingExpenses');
      }

      if (logoutSuccess) {
        // Clear storage
        await prefs.remove('vehicleId');
        await prefs.remove('lastKmValue');

        Fluttertoast.showToast(
          msg: "Logout successful",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        return true;
      }
    } catch (e) {
      print('Error during online logout: $e');
      // If online upload fails, fall through to offline storage
    }
  }

  // Store for later upload if online upload failed or offline
  List<Map<String, dynamic>> pendingOperations = [];
  String? existingOperations = prefs.getString('pendingOperations');
  if (existingOperations != null) {
    pendingOperations = List<Map<String, dynamic>>.from(jsonDecode(existingOperations));
  }
  pendingOperations.add(operationData);
  await prefs.setString('pendingOperations', jsonEncode(pendingOperations));

  Fluttertoast.showToast(
    msg: "Logout saved for later upload",
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
      return data['success'] == true;
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

  // If immediate upload failed or no connection, save for later upload
  List<Map<String, dynamic>> pendingExpenses = [];
  String? existingExpenses = prefs.getString('pendingExpenses');
  if (existingExpenses != null) {
    pendingExpenses = List<Map<String, dynamic>>.from(jsonDecode(existingExpenses));
  }
  pendingExpenses.add(expenseData);
  await prefs.setString('pendingExpenses', jsonEncode(pendingExpenses));

  Fluttertoast.showToast(
    msg: "Expense saved for later upload",
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
      if (carServices.cars.isEmpty) {
        await carServices.getCars();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Check connectivity and show dialog before navigation
        await checkConnectivityAndShowDialog(context);

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

// First, modify your MyApp class to include WidgetsBindingObserver
class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MyApp({super.key, required this.isLoggedIn});

  @override
  State<MyApp> createState() => MyAppState();  // Remove underscore to make it public
}

// Make this class public by removing underscore
class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Camera tracking properties
  bool isCameraInUse = false;
  DateTime? lastDialogShown;
  static const Duration dialogCooldown = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool canShowDialog() {
    if (isCameraInUse) return false;

    if (lastDialogShown != null) {
      final timeSinceLastDialog = DateTime.now().difference(lastDialogShown!);
      if (timeSinceLastDialog < dialogCooldown) return false;
    }

    return true;
  }

  void setCameraState(bool inUse) {
    setState(() {
      isCameraInUse = inUse;
    });
  }

  @override
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (!canShowDialog()) return;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? pendingOperations = prefs.getString('pendingOperations');
      String? pendingExpenses = prefs.getString('pendingExpenses');

      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none &&
          (pendingOperations != null || pendingExpenses != null)) {

        if (MyApp.navigatorKey.currentContext != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          lastDialogShown = DateTime.now();
          await showUploadDialog(MyApp.navigatorKey.currentContext!);
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: MyApp.navigatorKey,  // Access through the static property
      title: 'GreenFleet Driver',
      theme: ThemeData(
        primaryColor: const Color.fromARGB(255, 101, 204, 82),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color.fromARGB(255, 101, 204, 82), width: 2.0),
          ),
          labelStyle: TextStyle(color: Colors.black),
        ),
      ),
      home: InitialLoadingScreen(isLoggedIn: widget.isLoggedIn),
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
