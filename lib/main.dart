import 'dart:async';
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

import 'models/no_internet_widget.dart';



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
    return false;
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();

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

    bool hasPhotos = await _addPhotosToRequest(request, inputData, isLogin);
    if (!hasPhotos) {
      print("No photos found for upload");
      return false;
    }

    print("Sending request with photos...");

    try {
      var response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Upload request timed out after 30 seconds');
        },
      );

      var responseData = await response.stream.bytesToString();
      print("Operation response: $responseData");

      List<String> responses = responseData.split('}{');
      if (responses.length > 1) {
        responses[0] = responses[0] + '}';
        responses[1] = '{' + responses[1];
      }

      var operationResult = json.decode(responses[0]);
      bool operationSuccess = operationResult['success'] == true;

      bool photoSuccess = true;
      if (responses.length > 1) {
        var photoResult = json.decode(responses[1]);
        photoSuccess = photoResult['success'] == true;
      }

      if (operationSuccess && photoSuccess) {
        return true;
      } else {
        // If server reports failure, save operation and return false
        await _storeForLaterUpload(prefs, inputData);
        return false;
      }

    } catch (e) {
      print('Request failed: $e');
      // Important: Save the operation before propagating the error
      await _storeForLaterUpload(prefs, inputData);
      throw e;
    }
  } catch (e) {
    print('Operation failed: $e');
    // Ensure operation is saved even for unexpected errors
    await _storeForLaterUpload(prefs, inputData);
    throw e;
  }
}

// Helper function to store operations
Future<void> _storeForLaterUpload(SharedPreferences prefs, Map<String, dynamic> inputData) async {
  try {
    List<Map<String, dynamic>> pendingOperations = [];
    String? existingOperations = prefs.getString('pendingOperations');

    if (existingOperations != null) {
      pendingOperations = List<Map<String, dynamic>>.from(jsonDecode(existingOperations));
    }

    // Check for duplicates before adding
    bool isDuplicate = pendingOperations.any((op) =>
    op['timestamp'] == inputData['timestamp'] &&
        op['driver'] == inputData['driver'] &&
        op['vehicle'] == inputData['vehicle'] &&
        op['km'] == inputData['km']
    );

    if (!isDuplicate) {
      pendingOperations.add(inputData);
      await prefs.setString('pendingOperations', jsonEncode(pendingOperations));
      print('Operation saved for later upload');
    } else {
      print('Operation already exists in pending list');
    }
  } catch (e) {
    print('Error saving operation for later: $e');
    // We throw this error because failing to save a pending operation is critical
    throw Exception('Failed to save operation for later upload: $e');
  }
}


// Add a helper function for adding photos to request
Future<bool> _addPhotosToRequest(
    http.MultipartRequest request,
    Map<String, dynamic> inputData,
    bool isLogin
    ) async {
  bool hasPhotos = false;
  try {
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
  } catch (e) {
    print('Error preparing photos: $e');
    throw e;  // Propagate the error instead of handling it silently
  }
  return hasPhotos;
}


Future<void> _cleanupOperation(SharedPreferences prefs, String timestamp, bool isLogin) async {
  if (!isLogin) {
    await prefs.remove('vehicleId');
    await prefs.remove('lastKmValue');
    Globals.vehicleID = null;
    Globals.kmValue = null;
  }
}

class UploadOperation {
  final Map<String, dynamic> data;
  final String uniqueKey;
  final bool isLogin;

  UploadOperation({
    required this.data,
    required this.uniqueKey,
    required this.isLogin,
  });

  factory UploadOperation.fromData(Map<String, dynamic> data) {
    String uniqueKey = '${data['timestamp']}_${data['driver']}_${data['vehicle']}_${data['km']}';
    bool isLogin = data.containsKey('parcursIn');
    return UploadOperation(
      data: data,
      uniqueKey: uniqueKey,
      isLogin: isLogin,
    );
  }
}

class ExpenseOperation {
  final Map<String, dynamic> data;
  final String uniqueKey;

  ExpenseOperation({
    required this.data,
    required this.uniqueKey,
  });

  factory ExpenseOperation.fromData(Map<String, dynamic> data) {
    String uniqueKey = '${data['timestamp']}_${data['driver']}_${data['type']}_${data['cost']}';
    return ExpenseOperation(
      data: data,
      uniqueKey: uniqueKey,
    );
  }
}

Future<void> showUploadDialog(BuildContext context) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? pendingOperations = prefs.getString('pendingOperations');
  String? pendingExpenses = prefs.getString('pendingExpenses');

  if (pendingOperations == null && pendingExpenses == null) return;

  List<UploadOperation> operations = [];
  Set<String> operationKeys = {};

  if (pendingOperations != null) {
    List<Map<String, dynamic>> parsedOps = List<Map<String, dynamic>>.from(jsonDecode(pendingOperations));
    // Sort operations by timestamp
    parsedOps.sort((a, b) => DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));

    for (var op in parsedOps) {
      var operation = UploadOperation.fromData(op);
      if (!operationKeys.contains(operation.uniqueKey)) {
        operationKeys.add(operation.uniqueKey);
        operations.add(operation);
      }
    }
  }

  List<ExpenseOperation> expenses = [];
  Set<String> expenseKeys = {};

  if (pendingExpenses != null) {
    List<Map<String, dynamic>> parsedExp = List<Map<String, dynamic>>.from(jsonDecode(pendingExpenses));
    for (var exp in parsedExp) {
      var expense = ExpenseOperation.fromData(exp);
      if (!expenseKeys.contains(expense.uniqueKey)) {
        expenseKeys.add(expense.uniqueKey);
        expenses.add(expense);
      }
    }
  }

  if (!context.mounted) return;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
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
        content: _buildDialogContent(operations, expenses),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Later', style: TextStyle(fontSize: 16)),
            onPressed: () => Navigator.of(context).pop(),
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _handleUpload(context, operations, expenses),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      );
    },
  );
}

// Builds the content of the dialog
Widget _buildDialogContent(List<UploadOperation> operations, List<ExpenseOperation> expenses) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'There are pending items to upload:',
        style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
      ),
      const SizedBox(height: 16),
      Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (operations.isNotEmpty) ...[
                _buildOperationsSection(operations),
                if (expenses.isNotEmpty) const SizedBox(height: 16),
              ],
              if (expenses.isNotEmpty) _buildExpensesSection(expenses),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Would you like to upload these items now?',
        style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
      ),
    ],
  );
}

// Builds the operations section of the dialog
Widget _buildOperationsSection(List<UploadOperation> operations) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
        DateTime? dateTime = DateTime.tryParse(operation.data['timestamp'] ?? '');
        String formattedTime = dateTime != null
            ? '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}'
            : operation.data['timestamp'] ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                operation.isLogin ? Icons.login : Icons.logout,
                color: const Color.fromARGB(255, 101, 204, 82),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${operation.isLogin ? "Login" : "Logout"}: $formattedTime',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ],
          ),
        );
      }),
    ],
  );
}

// Builds the expenses section of the dialog
Widget _buildExpensesSection(List<ExpenseOperation> expenses) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
        DateTime? dateTime = DateTime.tryParse(expense.data['timestamp'] ?? '');
        String formattedTime = dateTime != null
            ? '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}'
            : expense.data['timestamp'] ?? '';

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
                      '${expense.data['type']} - ${expense.data['cost']} EUR',
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    Text(
                      formattedTime,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    ],
  );
}

// Handles the upload process
Future<void> _handleUpload(
    BuildContext context,
    List<UploadOperation> operations,
    List<ExpenseOperation> expenses,
    ) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _buildLoadingDialog(),
  );

  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int successfulOperations = 0;
    Map<String, bool> vehicleLoginStatus = {};

    // First, create a list of operations that we'll update as we process them
    List<Map<String, dynamic>> remainingOperations =
    operations.map((op) => Map<String, dynamic>.from(op.data)).toList();

    // Process operations sequentially
    for (int i = 0; i < operations.length; i++) {
      var operation = operations[i];
      String vehicleId = operation.data['vehicle'].toString();
      bool isLogin = operation.isLogin;

      // Validate operation sequence
      if (isLogin && vehicleLoginStatus[vehicleId] == true) {
        print('Vehicle $vehicleId already logged in, skipping duplicate login');
        continue;
      }
      if (!isLogin && vehicleLoginStatus[vehicleId] != true) {
        print('Vehicle $vehicleId not logged in, skipping invalid logout');
        continue;
      }

      try {
        print('Processing ${isLogin ? "LOGIN" : "LOGOUT"} for vehicle $vehicleId from ${operation.data['timestamp']}');

        bool success = await handleVehicleOperation(
            operation.data,
            isLogin: isLogin
        ).timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            print('Operation timed out');
            throw TimeoutException('Operation timed out');
          },
        );

        if (success) {
          print('Operation processed successfully');
          successfulOperations++;
          vehicleLoginStatus[vehicleId] = isLogin;

          // Remove this successful operation from remaining list
          remainingOperations.removeAt(0);
        } else {
          print('Operation failed, stopping sequence');
          break;
        }
      } catch (e) {
        print('Error processing operation: $e');
        break;
      }
    }

    // Update SharedPreferences with truly remaining operations
    if (remainingOperations.isNotEmpty) {
      print('Saving ${remainingOperations.length} remaining operations');
      await prefs.setString('pendingOperations', jsonEncode(remainingOperations));
    } else {
      print('No remaining operations, removing from SharedPreferences');
      await prefs.remove('pendingOperations');
    }

    // Process expenses only if all operations succeeded or there were no operations
    List<Map<String, dynamic>> remainingExpenses = [];
    int successfulExpenses = 0;

    if (successfulOperations == operations.length || operations.isEmpty) {
      for (var expense in expenses) {
        try {
          bool success = await handleExpenseUpload(expense.data).timeout(
            const Duration(seconds: 45),
            onTimeout: () => throw TimeoutException('Expense upload timed out'),
          );

          if (success) {
            successfulExpenses++;
          } else {
            remainingExpenses.add(expense.data);
          }
        } catch (e) {
          print('Error processing expense: $e');
          remainingExpenses.add(expense.data);
        }
      }

      if (remainingExpenses.isNotEmpty) {
        await prefs.setString('pendingExpenses', jsonEncode(remainingExpenses));
      } else {
        await prefs.remove('pendingExpenses');
      }
    }

    // Close dialogs
    if (context.mounted) {
      Navigator.of(context).pop();  // Close loading dialog
      Navigator.of(context).pop();  // Close upload dialog
    }

    bool hasRemainingItems = remainingOperations.isNotEmpty || remainingExpenses.isNotEmpty;

    print('Upload summary:');
    print('- Successful operations: $successfulOperations/${operations.length}');
    print('- Remaining operations: ${remainingOperations.length}');
    print('- Successful expenses: $successfulExpenses/${expenses.length}');
    print('- Remaining expenses: ${remainingExpenses.length}');

    _showUploadResult(
      hasRemainingItems: hasRemainingItems,
      totalOperations: operations.length,
      totalExpenses: expenses.length,
      successfulOperations: successfulOperations,
      successfulExpenses: successfulExpenses,
      errorMessage: hasRemainingItems ? 'Some items could not be uploaded' : '',
    );

  } catch (e) {
    print('Unexpected error during upload process: $e');
    if (context.mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    }

    Fluttertoast.showToast(
      msg: "Error during upload: $e",
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }
}


void _showUploadResult({
  required bool hasRemainingItems,
  required int totalOperations,
  required int totalExpenses,
  required int successfulOperations,
  required int successfulExpenses,
  required String errorMessage,
}) {
  if (hasRemainingItems) {
    // Build a detailed message for partial completion
    String message = "Upload partially completed.\n";

    // Add operations status if there were any operations
    if (totalOperations > 0) {
      message += "Operations: $successfulOperations/$totalOperations\n";
    }

    // Add expenses status if there were any expenses
    if (totalExpenses > 0) {
      message += "Expenses: $successfulExpenses/$totalExpenses\n";
    }

    // Add error message if there were any errors
    if (errorMessage.isNotEmpty) {
      // Truncate error message if it's too long to prevent toast overflow
      if (errorMessage.length > 100) {
        message += "Errors: ${errorMessage.substring(0, 97)}...";
      } else {
        message += "Errors: $errorMessage";
      }
    }

    Fluttertoast.showToast(
      msg: message,
      backgroundColor: Colors.orange,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 4,
    );
  } else if (successfulOperations == 0 && successfulExpenses == 0) {
    // Case where nothing was uploaded successfully
    Fluttertoast.showToast(
      msg: "No items were uploaded. Please try again when connection is stable.",
      backgroundColor: Colors.red,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 3,
    );
  } else {
    // Case where everything was uploaded successfully
    String message = "All items uploaded successfully";

    // Add count details if there were multiple items
    if ((totalOperations + totalExpenses) > 1) {
      message += "\nOperations: $successfulOperations, Expenses: $successfulExpenses";
    }

    Fluttertoast.showToast(
      msg: message,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 2,
    );
  }
}

// Builds the loading dialog
Widget _buildLoadingDialog() {
  return Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 5,
    child: const Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Color.fromARGB(255, 101, 204, 82),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Uploading items...',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ],
      ),
    ),
  );
}

// Clears vehicle-related data
Future<void> _clearVehicleData(SharedPreferences prefs) async {
  await prefs.remove('vehicleId');
  await prefs.remove('lastKmValue');
  //await prefs.remove('isLoggedIn');

  // Clear globals
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

  return false;
}

Future<bool> logoutVehicle(String logoutDate) async {
  var connectivityResult = await Connectivity().checkConnectivity();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Prepare logout operation data
  Map<String, dynamic> operationData = {
    'driver': Globals.userId.toString(),
    'vehicle': Globals.vehicleID.toString(),
    'km': Globals.kmValue.toString(),
    'timestamp': logoutDate,
  };

  // Add logout photos
  if (Globals.image6?.path != null) operationData['image6'] = Globals.image6!.path;
  if (Globals.image7?.path != null) operationData['image7'] = Globals.image7!.path;
  if (Globals.image8?.path != null) operationData['image8'] = Globals.image8!.path;
  if (Globals.image9?.path != null) operationData['image9'] = Globals.image9!.path;
  if (Globals.image10?.path != null) operationData['image10'] = Globals.image10!.path;
  if (Globals.parcursOut?.path != null) operationData['parcursOut'] = Globals.parcursOut!.path;

  // If we have internet connectivity
  if (connectivityResult != ConnectivityResult.none) {
    try {
      // Get both pending operations and expenses
      String? pendingOperationsJson = prefs.getString('pendingOperations');
      String? pendingExpensesJson = prefs.getString('pendingExpenses');

      List<Map<String, dynamic>> pendingOperations = [];
      List<Map<String, dynamic>> pendingExpenses = [];

      if (pendingOperationsJson != null) {
        pendingOperations = List<Map<String, dynamic>>.from(json.decode(pendingOperationsJson));
      }
      if (pendingExpensesJson != null) {
        pendingExpenses = List<Map<String, dynamic>>.from(json.decode(pendingExpensesJson));
      }

      // Process all pending operations first
      print('Starting to process ${pendingOperations.length} pending operations');
      for (var operation in pendingOperations) {
        try {
          bool isLogin = operation.containsKey('parcursIn');
          print('Processing ${isLogin ? "login" : "logout"} from ${operation['timestamp']}');

          bool success = await handleVehicleOperation(operation, isLogin: isLogin);
          if (!success) {
            print('Operation failed, rolling back');
            await _performFullRollback(prefs, pendingOperations, pendingExpenses, operationData);
            return true;
          }
        } catch (e) {
          print('Error processing operation: $e');
          await _performFullRollback(prefs, pendingOperations, pendingExpenses, operationData);

          Fluttertoast.showToast(
              msg: "Connection issue. Operations saved for later.",
              backgroundColor: Colors.orange,
              textColor: Colors.white
          );
          return false;
        }
      }

      // Process all pending expenses
      print('Starting to process ${pendingExpenses.length} pending expenses');
      for (var expense in pendingExpenses) {
        try {
          print('Processing expense from ${expense['timestamp']}');
          bool success = await handleExpenseUpload(expense);
          if (!success) {
            print('Expense upload failed, rolling back');
            await _performFullRollback(prefs, pendingOperations, pendingExpenses, operationData);
            return true;
          }
        } catch (e) {
          print('Error processing expense: $e');
          await _performFullRollback(prefs, pendingOperations, pendingExpenses, operationData);

          Fluttertoast.showToast(
              msg: "Connection issue. Operations saved for later.",
              backgroundColor: Colors.orange,
              textColor: Colors.white
          );
          return true;
        }
      }

      // If all pending items processed successfully, perform current logout
      try {
        print('Processing current logout');
        bool logoutSuccess = await handleVehicleOperation(operationData, isLogin: false);

        if (logoutSuccess) {
          // Clear all stored data after successful operations
          await prefs.remove('pendingOperations');
          await prefs.remove('pendingExpenses');
          await prefs.remove('vehicleId');
          await prefs.remove('lastKmValue');
          //await prefs.remove('isLoggedIn');

          // Clear globals
          Globals.vehicleID = null;
          Globals.kmValue = null;

          Fluttertoast.showToast(
              msg: "All operations completed successfully",
              backgroundColor: Colors.green,
              textColor: Colors.white
          );

          return true;
        } else {
          await _performFullRollback(prefs, pendingOperations, pendingExpenses, operationData);
          Globals.vehicleID = null;
          Globals.kmValue = null;
          return true;
        }
      } catch (e) {
        print('Error during final logout: $e');
        Globals.vehicleID = null;
        Globals.kmValue = null;
        await _performFullRollback(prefs, pendingOperations, pendingExpenses, operationData);
        return true;
      }
    } catch (e) {
      print('General error during processing: $e');
      Globals.vehicleID = null;
      Globals.kmValue = null;
      await _storeOperationForLater(prefs, operationData);
      return true;
    }
  } else {
    // Offline case - save logout operation
    print('Device offline, saving logout operation');
    await _storeOperationForLater(prefs, operationData);
    Globals.vehicleID = null;
    Globals.kmValue = null;

    Fluttertoast.showToast(
        msg: "Device offline, logout saved for later upload",
        backgroundColor: Colors.orange,
        textColor: Colors.white
    );

    return true;
  }
}

// Helper function for full rollback of both operations and expenses
Future<void> _performFullRollback(
    SharedPreferences prefs,
    List<Map<String, dynamic>> pendingOperations,
    List<Map<String, dynamic>> pendingExpenses,
    Map<String, dynamic> currentLogout
    ) async {
  // Handle operations rollback
  List<Map<String, dynamic>> allOperations = List.from(pendingOperations);

  // Check for duplicate before adding current logout
  bool logoutExists = allOperations.any((operation) =>
  operation['timestamp'] == currentLogout['timestamp'] &&
      operation['driver'] == currentLogout['driver'] &&
      operation['vehicle'] == currentLogout['vehicle']
  );

  if (!logoutExists) {
    allOperations.add(currentLogout);
  }

  // Important: Clear vehicle login state even during rollback
  // This ensures the user is properly logged out even if operations are pending
  await prefs.remove('vehicleId');
  await prefs.remove('lastKmValue');
  //await prefs.setBool('isLoggedIn', false);

  // Clear global state
  Globals.vehicleID = null;
  Globals.kmValue = null;

  // Save pending operations and expenses
  await prefs.setString('pendingOperations', json.encode(allOperations));
  if (pendingExpenses.isNotEmpty) {
    await prefs.setString('pendingExpenses', json.encode(pendingExpenses));
  }

  print('Full rollback completed with vehicle state cleared:');
  print('- Operations: ${allOperations.length}');
  print('- Expenses: ${pendingExpenses.length}');
}

// Helper function to store a single operation
Future<void> _storeOperationForLater(
    SharedPreferences prefs,
    Map<String, dynamic> operationData
    ) async {
  List<Map<String, dynamic>> pendingOperations = [];
  String? existingOperations = prefs.getString('pendingOperations');

  if (existingOperations != null) {
    pendingOperations = List<Map<String, dynamic>>.from(json.decode(existingOperations));
  }

  // Check for duplicate before adding
  bool exists = pendingOperations.any((operation) =>
  operation['timestamp'] == operationData['timestamp'] &&
      operation['driver'] == operationData['driver'] &&
      operation['vehicle'] == operationData['vehicle']
  );

  if (!exists) {
    pendingOperations.add(operationData);
    await prefs.setString('pendingOperations', json.encode(pendingOperations));
  }
}

Future<bool> handleExpenseUpload(Map<String, dynamic>? inputData) async {
  if (inputData == null) {
    print("No input data for expense upload");
    return false;  // Changed to false since this is a failure case
  }

  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://vinczefi.com/greenfleet/flutter_functions_1.php'),
    );

    // Set up request fields...
    request.fields['action'] = 'vehicle-expense';
    request.fields['driver'] = inputData['driver'] ?? '';
    request.fields['vehicle'] = inputData['vehicle'] ?? '';
    request.fields['km'] = inputData['km'] ?? '';
    request.fields['type'] = inputData['type'] ?? '';
    request.fields['remarks'] = inputData['remarks'] ?? '';
    request.fields['cost'] = inputData['cost'] ?? '';
    request.fields['current-date-time'] = inputData['timestamp'] ?? '';

    // Add expense photo if exists
    String? imagePath = inputData['image'];
    if (imagePath != null && imagePath.isNotEmpty) {
      File imageFile = File(imagePath);
      if (await imageFile.exists()) {
        request.files.add(await http.MultipartFile.fromPath('photo', imagePath));
      }
    }

    print("Sending expense request...");
    // Add timeout to the request
    var response = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Connection timed out after 30 seconds');
      },
    );

    var responseData = await response.stream.bytesToString();
    print("Expense response: $responseData");

    if (response.statusCode == 200) {
      var data = json.decode(responseData);
      return data['success'] == true;
    }

    return false;
  } catch (e) {
    print('Error uploading expense: $e');
    // We want to propagate the timeout/connection error up
    throw e;  // Important: throw the error instead of returning false
  }
}

// Helper function to store expenses for later upload
Future<void> _storeExpenseForLater(SharedPreferences prefs, Map<String, dynamic> inputData) async {
  List<Map<String, dynamic>> pendingExpenses = [];
  String? existingExpenses = prefs.getString('pendingExpenses');

  if (existingExpenses != null) {
    pendingExpenses = List<Map<String, dynamic>>.from(jsonDecode(existingExpenses));
  }

  pendingExpenses.add(inputData);
  await prefs.setString('pendingExpenses', jsonEncode(pendingExpenses));
}

// First, create a simple class to hold our result
class ExpenseResult {
  final bool success;
  final bool wasUploaded;

  ExpenseResult({
    required this.success,
    required this.wasUploaded,
  });
}

Future<ExpenseResult> uploadExpense(Map<String, dynamic> expenseData) async {
  var connectivityResult = await Connectivity().checkConnectivity();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  String timestamp = DateTime.now().toIso8601String();
  expenseData['timestamp'] = timestamp;

  if (connectivityResult != ConnectivityResult.none) {
    try {
      bool success = await handleExpenseUpload(expenseData);
      if (success) {
        Fluttertoast.showToast(
          msg: "Expense uploaded successfully",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        return ExpenseResult(success: true, wasUploaded: true);
      }
    } catch (e) {
      // Connection timeout or other error - fall through to offline storage
      print('Upload failed, saving for later: $e');
    }
  }

  // Store for later (either no connection or upload failed)
  try {
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

    // Important: indicate success but NOT uploaded
    return ExpenseResult(success: true, wasUploaded: false);
  } catch (e) {
    print('Error saving expense for later: $e');
    Fluttertoast.showToast(
      msg: "Error saving expense. Please try again.",
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
    return ExpenseResult(success: false, wasUploaded: false);
  }
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

  await prefs.setBool(operationLockKey, false);
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String? userId = prefs.getString('userId');

  // Check if there are pending operations and if last one was logout
  String? pendingOperations = prefs.getString('pendingOperations');
  if (pendingOperations != null) {
    List<Map<String, dynamic>> operations = List<Map<String, dynamic>>.from(jsonDecode(pendingOperations));
    if (operations.isNotEmpty) {
      // If last operation was logout, clear vehicle data but keep user logged in
      bool lastWasLogout = !operations.last.containsKey('parcursIn');
      if (lastWasLogout) {
        await prefs.remove('vehicleId');
        await prefs.remove('lastKmValue');
        Globals.vehicleID = null;
        Globals.kmValue = null;
      }
    }
  }

  if (isLoggedIn && userId != null) {
    Globals.userId = int.tryParse(userId);
    // Only set vehicle ID if not logged out
    if (prefs.containsKey('vehicleId')) {
      Globals.vehicleID = prefs.getInt('vehicleId');
      Globals.kmValue = prefs.getString('lastKmValue');
      await _loadImagesFromPrefs();
    }

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

  Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
    if (result != ConnectivityResult.none) {
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
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    bool hasInternet = await _checkInternet();
    setState(() {
      _hasInternet = hasInternet;
    });
    if (hasInternet) {
      await _initializeData();
    }
  }

  Future<bool> _checkInternet() async {
    // If user is logged into a vehicle (vehicleId exists), return true regardless of internet
    if (Globals.vehicleID != null) {
      return true;
    }

    // If not logged in, check internet to see if we can log in
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
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
      body:!_hasInternet
          ? NoInternetWidget(
        onRetry: () => _initializeData(),
      )
          :  Center(
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
  // Track both camera usage and dialog visibility
  bool isCameraInUse = false;
  bool isDialogVisible = false;
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
    if (isCameraInUse || isDialogVisible) return false;

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
          // Set dialog as visible before showing
          setState(() {
            isDialogVisible = true;
          });

          await Future.delayed(const Duration(milliseconds: 500));
          lastDialogShown = DateTime.now();

          if (mounted) {
            await showUploadDialog(MyApp.navigatorKey.currentContext!).then((_) {
              // Reset dialog visibility when dialog is closed
              if (mounted) {
                setState(() {
                  isDialogVisible = false;
                });
              }
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: MyApp.navigatorKey,
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
        if (data['driver_id'] != null && data['driver_id'] != -1) {
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
          print("Login Failed: User ID is -1");
          Fluttertoast.showToast(
            backgroundColor: Colors.red,
            textColor: Colors.white,
            msg: "Invalid credentials",  // Updated error message for invalid credentials
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      } else {
        // Handle case where success is false
        print("Login Failed: Success is false");
        Fluttertoast.showToast(
          backgroundColor: Colors.red,
          textColor: Colors.white,
          msg: "Invalid credentials",  // Show message for invalid credentials
          toastLength: Toast.LENGTH_SHORT,
        );
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
