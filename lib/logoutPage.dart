import 'package:app/models/cars_model.dart';
import 'package:app/services/car_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'globals.dart';
import 'driverPage.dart'; // Import DriverPage
import 'package:workmanager/workmanager.dart';

import 'main.dart';

class Car {
  final int id;
  final String name;
  final String numberPlate;

  Car({required this.id, required this.name, required this.numberPlate});

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: json['id'] as int,
      name: json['name'] as String,
      numberPlate: json['numberplate'] as String,
    );
  }
}

class LogoutPage extends StatefulWidget {
  const LogoutPage({super.key});

  @override
  State<LogoutPage> createState() => _LogoutPageState();
}

class _LogoutPageState extends State<LogoutPage> {
  final _kmController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final CarServices _carServices = CarServices();

  File? _image6;
  File? _image7;
  File? _image8;
  File? _image9;
  File? _image10;
  File? parcursOut;

  VehicleData? _selectedCar;
  bool _isLoading = false;
  String? _errorMessage;
  int? _lastKm;
  int? carId;

  @override
  void initState() {
    super.initState();
    // Just get the stored vehicle data
    if (Globals.vehicleID != null) {
      _selectedCar = carServices.getVehicleData(Globals.vehicleID!);
      //_lastKm = _selectedCar?.km; // Set last KM from stored data
      carId = Globals.vehicleID;
      print("LogoutPage car id: ${carId}");
    }
  }

  Future<void> _getImage(int imageNumber) async {
    try {
      final pickedFile =
          await _imagePicker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        setState(() {
          switch (imageNumber) {
            case 1:
              _image6 = File(pickedFile.path);
              break;
            case 2:
              _image7 = File(pickedFile.path);
              break;
            case 3:
              _image8 = File(pickedFile.path);
              break;
            case 4:
              _image9 = File(pickedFile.path);
              break;
            case 5:
              _image10 = File(pickedFile.path);
              break;
            case 6:
              parcursOut = File(pickedFile.path);
          }
        });
      } else {
        print('No image selected.');
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _showImage(File? image, int imageNumber) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.file(
                    image,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Take New Photo Button
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close preview
                      _getImage(imageNumber); // Take new photo
                    },
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Color.fromARGB(255, 101, 204, 82),
                    ),
                    label: const Text(
                      'Take New Photo',
                      style: TextStyle(
                        color: Color.fromARGB(255, 101, 204, 82),
                      ),
                    ),
                  ),
                  // Close Button
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.grey,
                    ),
                    label: const Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showLoggingOutDialog() {
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
                    Color.fromARGB(255, 101, 204, 82), // Green color
                  ),
                ),
                SizedBox(width: 16),
                Text("Logging out of vehicle"),
              ],
            ),
          ),
        );
      },
    );
  }

  void _hideLoggingOutDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _submitData() async {
    // Initial validation
    if (_kmController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Please enter the KM.'),
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

    int lastKM = 0; // default value in case of error

    if (Globals.kmValue != null) {
      try {
        lastKM = int.parse(Globals
            .kmValue!); // The '!' operator asserts that kmValue is not null
      } catch (e) {
        print("Invalid number format: ${Globals.kmValue}");
      }
    } else {
      print("kmValue is null");
    }

    // Check for required images
    if (_image6 == null ||
        _image7 == null ||
        _image8 == null ||
        _image9 == null ||
        _image10 == null ||
        parcursOut == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Please take all required pictures.'),
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

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Store images in Globals
      Globals.image6 = _image6;
      Globals.image7 = _image7;
      Globals.image8 = _image8;
      Globals.image9 = _image9;
      Globals.image10 = _image10;
      Globals.parcursOut = parcursOut;
      Globals.kmValue = _kmController.text;

      final String logoutDate = DateTime.now().toIso8601String();

      // Prepare logout images data
      Map<String, dynamic> logoutImages = {
        'userId': Globals.userId.toString(),
        'vehicleID': Globals.vehicleID.toString(),
        'km': _kmController.text,
        'image1': _image6!.path,
        'image2': _image7!.path,
        'image3': _image8!.path,
        'image4': _image9!.path,
        'image5': _image10!.path,
        'image6': parcursOut!.path,
        'type': 'logout',
        'timestamp': logoutDate
      };

      // Save pending images
      //await prefs.setString(jsonEncode(logoutImages));

      _showLoggingOutDialog();

      try {
        // Perform vehicle logout
        await logoutVehicle(logoutDate);

        // Schedule image upload task
        // await Workmanager().registerOneOffTask(
        //     "imageUpload_logout_${DateTime.now().millisecondsSinceEpoch}",
        //     uploadImageTask,
        //     inputData: logoutImages,
        //     constraints: Constraints(
        //       networkType: NetworkType.connected,
        //       requiresBatteryNotLow: true,
        //     ),
        //     existingWorkPolicy: ExistingWorkPolicy.append,
        //     backoffPolicy: BackoffPolicy.linear,
        //     backoffPolicyDelay: const Duration(seconds: 30));

        _hideLoggingOutDialog();

        // Clear stored data
        await prefs.remove('vehicleId');
        Globals.vehicleID = null;

        // Only navigate if logout was successful
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DriverPage()),
        );
      } catch (e) {
        print('Error during logout process: $e');
        _hideLoggingOutDialog();

        // Show error to user
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content:
                  const Text('Failed to complete logout. Please try again.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Error in logout submit data: $e');
      _hideLoggingOutDialog();

      // Show error to user
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text(
                'An error occurred while logging out. Please try again.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    int lastKM = 0; // default value in case of error

    if (Globals.kmValue != null) {
      try {
        lastKM = int.parse(Globals
            .kmValue!); // The '!' operator asserts that kmValue is not null
      } catch (e) {
        print("Invalid number format: ${Globals.kmValue}");
      }
    } else {
      print("kmValue is null");
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_filled_outlined,
                color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              "Vehicle Logout",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 101, 204, 82),
        elevation: 0,
      ),
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Vehicle Info Card
                if (_selectedCar != null)
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.directions_car,
                                color: Color.fromARGB(255, 101, 204, 82),
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _selectedCar!.name, // Using stored vehicle data
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedCar!
                                .numberPlate, // Using stored vehicle data
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black54,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // KM Input Card
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.speed,
                              color: Color.fromARGB(255, 101, 204, 82),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Odometer Reading',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _kmController,
                          cursorColor: const Color.fromARGB(255, 101, 204, 82),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Current KM',
                            labelStyle: const TextStyle(color: Colors.black87),
                            // Use the stored vehicle data from carServices
                            hintText: Globals.vehicleID != null
                                ? 'Last KM: $lastKM'
                                : 'Enter KM',
                            hintStyle: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.speed,
                              color: Color.fromARGB(255, 101, 204, 82),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 101, 204, 82),
                                width: 2,
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
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Photos Card
                // Photos Card
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width * 0.04),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Important
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_camera,
                              color: Color.fromARGB(255, 101, 204, 82),
                              size: MediaQuery.of(context).size.width * 0.06,
                            ),
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.02),
                            Text(
                              'Required Photos',
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.045,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.02),
                        _buildPhotoGrid(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Logout Button
                SizedBox(
                  width: screenWidth * 0.5,
                  child: ElevatedButton(
                    onPressed: _submitData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 101, 204, 82),
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
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text(
                          'Complete Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Helper method for photo grid
  Widget _buildPhotoGrid() {
    final screenSize = MediaQuery.of(context).size;
    final spacing = screenSize.width * 0.03; // Dynamic spacing

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _buildImageInputNew('Dashboard', 1, _image6)),
                SizedBox(width: spacing),
                Expanded(child: _buildImageInputNew('LogBook', 6, parcursOut)),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(child: _buildImageInputNew('Front Left', 2, _image7)),
                SizedBox(width: spacing),
                Expanded(child: _buildImageInputNew('Front Right', 3, _image8)),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(child: _buildImageInputNew('Rear Left', 4, _image9)),
                SizedBox(width: spacing),
                Expanded(child: _buildImageInputNew('Rear Right', 5, _image10)),
              ],
            ),
          ],
        );
      },
    );
  }

// Updated image input widget with modern design
  Widget _buildImageInputNew(String label, int imageNumber, File? image) {
    final screenSize = MediaQuery.of(context).size;
    final buttonHeight = screenSize.height * 0.15;

    return Container(
      height: buttonHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: image != null
              ? const Color.fromARGB(255, 101, 204, 82)
              : Colors.grey.shade300,
          width: image != null ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: image != null
              ? () =>
                  _showImage(image, imageNumber) // Show preview if image exists
              : () => _getImage(imageNumber), // Take photo if no image
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: screenSize.height * 0.01,
              horizontal: screenSize.width * 0.02,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(
                  image != null ? Icons.check_circle : Icons.add_a_photo,
                  color: image != null
                      ? const Color.fromARGB(255, 101, 204, 82)
                      : Colors.grey.shade400,
                  size: screenSize.width * 0.06,
                ),
                SizedBox(height: screenSize.height * 0.005),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: screenSize.width * 0.025,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (image != null)
                  Text(
                    'Tap to view',
                    style: TextStyle(
                      color: Color.fromARGB(255, 101, 204, 82),
                      fontSize: screenSize.width * 0.02,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }
}
