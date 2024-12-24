import 'dart:async';
import 'dart:convert';

import 'package:app/models/cars_model.dart';
import 'package:app/services/car_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'driverPage.dart'; // Import DriverPage

import 'globals.dart';


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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _kmController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String? kmInputLogin;
  MyAppState? getAppState() {
    return context.findAncestorStateOfType<MyAppState>();
  }

  final CarServices _carServices = CarServices();
  VehicleData? _selectedCar; // Add this to store cars locally

  File? _image1;
  File? _image2;
  File? _image3;
  File? _image4;
  File? _image5;
  File? parcursIn;

  int? _selectedCarId;
  bool _isLoading = false;
  String? _errorMessage;
  static int? _lastKmLogin;

  @override
  void initState() {
    super.initState();
    // Just get the stored vehicle data if already logged in
    if (Globals.vehicleID != null) {
      _selectedCar = _carServices.getVehicleData(Globals.vehicleID!);
      _lastKmLogin = _selectedCar?.km;
    }
  }
  
  Future<void> _getImage(int imageNumber) async {
    // Get reference to the app state before starting camera operation
    final appState = getAppState();

    // Set the camera flag to true before starting
    appState?.setCameraState(true);

    try {
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        setState(() {
          switch (imageNumber) {
            case 1:
              _image1 = File(pickedFile.path);
              break;
            case 2:
              _image2 = File(pickedFile.path);
              break;
            case 3:
              _image3 = File(pickedFile.path);
              break;
            case 4:
              _image4 = File(pickedFile.path);
              break;
            case 5:
              _image5 = File(pickedFile.path);
              break;
            case 6:
              parcursIn = File(pickedFile.path);
          }
        });
      } else {
        print('No image selected.');
      }
    } catch (e) {
      print('Error picking image: $e');
    } finally {
      // Always reset the camera flag when done, even if there was an error
      // Add a small delay to ensure we don't show the dialog immediately after camera closes
      await Future.delayed(const Duration(milliseconds: 500));
      appState?.setCameraState(false);
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

  void _onCarSelected(int? newValue) {
    setState(() {
      _selectedCarId = newValue;
      if (newValue != null) {
        // Get the vehicle data for the selected car from cache
        VehicleData? selectedVehicleData =
            _carServices.getVehicleData(newValue);
        if (selectedVehicleData != null) {
          _lastKmLogin = selectedVehicleData.km;
        }
      }
    });
  }


  void _hideLoggingDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _submitData() async {
    // Initial validation checks
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedKm', _kmController.text);

    if (_selectedCarId == null || _kmController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Please select a car and enter the KM.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    // Check for required images
    if (_image1 == null || _image2 == null || _image3 == null ||
        _image4 == null || _image5 == null || parcursIn == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Please take all required pictures.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    try {
      _showProgressDialog('Logging In', 'Processing your login request...');

      // Store images in Globals
      Globals.image1 = _image1;
      Globals.image2 = _image2;
      Globals.image3 = _image3;
      Globals.image4 = _image4;
      Globals.image5 = _image5;
      Globals.parcursIn = parcursIn;
      Globals.vehicleID = _selectedCarId;
      Globals.kmValue = _kmController.text;

      // KM validation
      _lastKmLogin ??= 0;
      if (int.tryParse(_kmController.text) != null) {
        int userInputKm = int.parse(_kmController.text);
        if (userInputKm < _lastKmLogin!) {
          if (mounted) Navigator.of(context).pop(); // Hide progress dialog
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Error'),
                content: Text(
                    'The entered KM must be greater than or equal to the last logged KM.\nLast km: $_lastKmLogin'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
          return;
        }
      }

      // Format current datetime
      String loginDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      print("submitDataLogin time: $loginDate");

      bool uploadSuccessful = false;

      try {
        // Add timeout to the loginVehicle call
        uploadSuccessful = await loginVehicle(loginDate).timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            print("Login attempt timed out");
            return false; // Return false on timeout
          },
        );
        print("Upload successful: $uploadSuccessful");
      } catch (e) {
        print('Error during login attempt: $e');
        uploadSuccessful = false;
      }

      if (mounted) Navigator.of(context).pop(); // Hide progress dialog

      // Show the appropriate dialog based on upload success
      await _showLoginSuccessDialog(wasUploaded: uploadSuccessful);

      // Navigate to driver page regardless of upload status
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DriverPage()),
        );
      }

    } catch (e) {
      print('Error in login submit data: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Hide progress dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content: const Text('An unexpected error occurred. Please try again.'),
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
  }

  void _showProgressDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(255, 101, 204, 82),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLoginSuccessDialog({required bool wasUploaded}) async {
    // Define the accent color based on whether the operation was uploaded or saved for later
    final Color accentColor = wasUploaded
        ? const Color.fromARGB(255, 101, 204, 82)  // Green for successful upload
        : Colors.orange;                           // Orange for saved offline

    await showDialog(
      context: context,
      barrierDismissible: false,  // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon container with themed background
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    // Use login-specific icons
                    wasUploaded ? Icons.login_rounded : Icons.cloud_upload,
                    size: 48,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Title text - corrected for login
                Text(
                  wasUploaded ? 'Vehicle Login Complete' : 'Login Saved',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                // Description text - corrected for login
                Text(
                  wasUploaded
                      ? 'Vehicle has been logged in successfully'
                      : 'Your login has been saved and will be uploaded when connection is restored',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Action button with proper navigation
                ElevatedButton(
                  onPressed: () {
                    // First close the dialog
                    Navigator.of(context).pop();

                    // Then navigate to DriverPage, replacing the current route
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const DriverPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,  // Subtle shadow for depth
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

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
              "Vehicle Login",
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
                // Vehicle Selection Card
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
                              Icons.directions_car,
                              color: Color.fromARGB(255, 101, 204, 82),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Select Vehicle',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _selectedCarId,
                          menuMaxHeight: 300,
                          items: carServices.cars.map((Car car) {
                            return DropdownMenuItem<int>(
                              value: car.id,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.directions_car,
                                    color: Color.fromARGB(255, 101, 204, 82),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${car.name} ',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    car.numberPlate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          selectedItemBuilder: (BuildContext context) {
                            return carServices.cars.map((Car car) {
                              return Row(
                                children: [
                                  const SizedBox(width: 8),
                                  Text(
                                    '${car.name} ',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    car.numberPlate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Color.fromARGB(255, 101, 204, 82),
                          ),
                          onChanged: _onCarSelected,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 15),
                            labelText: 'Select Vehicle',
                            labelStyle: const TextStyle(color: Colors.black87),
                            prefixIcon: const Icon(
                              Icons.directions_car,
                              color: Color.fromARGB(255, 101, 204, 82),
                              size: 20,
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
                            fillColor: Colors.white,
                          ),
                          dropdownColor: Colors.white,
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
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            labelText: 'Current KM',
                            labelStyle: const TextStyle(color: Colors.black87),
                            hintText: _selectedCarId != null
                                ? 'Last KM: ${carServices.getLastKmForVehicle(_selectedCarId!) ?? "N/A"}'
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
                          'Complete Login',
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
                Expanded(child: _buildImageInputNew('Dashboard', 1, _image1)),
                SizedBox(width: spacing),
                Expanded(child: _buildImageInputNew('LogBook', 6, parcursIn)),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(child: _buildImageInputNew('Front Left', 2, _image2)),
                SizedBox(width: spacing),
                Expanded(child: _buildImageInputNew('Front Right', 3, _image3)),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(child: _buildImageInputNew('Rear Left', 4, _image4)),
                SizedBox(width: spacing),
                Expanded(child: _buildImageInputNew('Rear Right', 5, _image5)),
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