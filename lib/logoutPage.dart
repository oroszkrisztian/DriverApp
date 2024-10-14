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

  File? _image6;
  File? _image7;
  File? _image8;
  File? _image9;
  File? _image10;
  File? parcursOut;

  Car? _selectedCar;
  bool _isLoading = true;
  String? _errorMessage;
  int? _lastKm;

  @override
  void initState() {
    super.initState();
    getCarDetails();
  }

  Future<void> getCarDetails() async {
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/greenfleet/flutter_functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'get-vehicle-info',
          'vehicle': Globals.vehicleID.toString(),
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonData = jsonDecode(response.body);
        if (jsonData.isNotEmpty) {
          setState(() {
            _selectedCar = Car.fromJson(jsonData[0]);
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'No car found with the provided ID.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load car details: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching car details: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> getLastKm(int driverId, int vehicleId) async {
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/greenfleet/flutter_functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'get-last-km',
          'driver_id': driverId.toString(),
          'vehicle_id': vehicleId.toString(),
        },
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        print('Response data: $data'); // Debug print to check the response

        if (data is bool && data == false) {
          setState(() {
            _lastKm = 0; // Set to 0 if no data is found
            _errorMessage = null; // Clear any previous error messages
          });
          return true; // Allow the process to continue
        } else if (data != null &&
            (data is int || int.tryParse(data.toString()) != null)) {
          setState(() {
            _lastKm = int.parse(data.toString());
            _errorMessage = null;
          });
          return true;
        } else {
          setState(() {
            _errorMessage = 'Invalid response data';
          });
          return false;
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load last KM: ${response.statusCode}';
        });
        return false;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching last KM: $e';
      });
      return false;
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
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Image.file(
                    image,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8.0),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageInput(int imageNumber, File? image) {
    String label;
    switch (imageNumber) {
      case 1:
        label = 'Dash/Műszerfal';
        break;
      case 2:
        label = 'Front left';
        break;
      case 3:
        label = 'Front Right';
        break;
      case 4:
        label = 'Rear Left';
        break;
      case 5:
        label = 'Rear Right';
        break;
      case 6:
        label = 'LogBook/Menetlevél';
        break;
      default:
        label = 'Unknown';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;

        return Container(
          height: maxHeight * 0.8,
          width: maxWidth * 0.45,
          decoration: BoxDecoration(
            color: image != null
                ? const Color.fromARGB(255, 101, 204, 82)
                : Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              width: 1,
              color: Colors.black,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.4),
                spreadRadius: 5,
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(maxWidth * 0.02),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: maxWidth * 0.08,
                      ),
                    ),
                    if (image != null)
                      Icon(Icons.check,
                          color: Colors.black, size: maxWidth * 0.04),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _getImage(imageNumber),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: const BorderSide(
                        color: Color.fromARGB(255, 101, 204, 82), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: Text('Take a picture',
                      style: TextStyle(fontSize: maxWidth * 0.08)),
                ),
                ElevatedButton(
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
                  child: Text('Preview',
                      style: TextStyle(fontSize: maxWidth * 0.08)),
                ),
              ],
            ),
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
                const Text("Logging out of vehicle"),
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

    // Check if all images have been taken
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

    Globals.image6 = _image6;
    Globals.image7 = _image7;
    Globals.image8 = _image8;
    Globals.image9 = _image9;
    Globals.image10 = _image10;
    Globals.parcursOut = parcursOut;
    Globals.kmValue = _kmController.text;

    int? userID = Globals.userId;
    int? carId = Globals.vehicleID;

    bool isKmValid = await getLastKm(userID!, carId!);
    if (!isKmValid) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Invalid KM data. Please check and try again.'),
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

    // Handle user input KM validation
    if (int.tryParse(_kmController.text) != null) {
      int userInputKm = int.parse(_kmController.text);

      // Allow user input KM to be equal to or greater than last KM
      if (userInputKm < _lastKm!) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text(
                  'The entered KM must be greater than or equal to the last logged KM.\nLast km: $_lastKm'),
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
    }

    _showLoggingOutDialog(); // Show logging out dialog

    await loginVehicle(); // Make sure this completes before navigation

    Workmanager().registerOneOffTask(
      "2",
      uploadImageTask,
      inputData: {
        'userId': Globals.userId.toString(),
        'vehicleID': Globals.vehicleID.toString(),
        'km': _kmController.text,
        'image1': Globals.image6?.path,
        'image2': Globals.image7?.path,
        'image3': Globals.image8?.path,
        'image4': Globals.image9?.path,
        'image5': Globals.image10?.path,
        'image6': Globals.parcursOut?.path
      },
    );

    _hideLoggingOutDialog(); // Hide logging out dialog
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('vehicleId');
    await prefs.remove('image1');
    await prefs.remove('image2');
    await prefs.remove('image3');
    await prefs.remove('image4');
    await prefs.remove('image5');
    Globals.vehicleID = null;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverPage(),
      ),
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
        title: const Text("Logout My Car"),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 101, 204, 82),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.fromARGB(255, 101, 204, 82),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  const Text("Fetching vehicle details..."),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(screenWidth * 0.04),
                    child: Column(
                      children: [
                        if (_selectedCar != null) ...[
                          Container(
                            margin: EdgeInsets.symmetric(
                                vertical: screenHeight * 0.01),
                            padding: EdgeInsets.all(screenWidth * 0.04),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10.0),
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
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.02),
                        ],
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.6),
                                spreadRadius: 5,
                                blurRadius: 7,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(screenWidth * 0.02),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _kmController,
                                  cursorColor:
                                      const Color.fromARGB(255, 101, 204, 82),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'KM',
                                    labelStyle:
                                        const TextStyle(color: Colors.black),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                        color:
                                            Color.fromARGB(255, 101, 204, 82),
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                        color:
                                            Color.fromARGB(255, 101, 204, 82),
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: screenWidth * 0.04,
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SizedBox(
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.4,
                                      child: _buildImageInput(1, _image6),
                                    ),
                                    SizedBox(
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.4,
                                      child: _buildImageInput(6, parcursOut),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.6),
                                spreadRadius: 5,
                                blurRadius: 7,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(screenWidth * 0.02),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.directions_car,
                                      size: screenWidth * 0.06,
                                    ),
                                    SizedBox(width: screenWidth * 0.02),
                                    Text(
                                      'Photos',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.05,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SizedBox(
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.4,
                                      child: _buildImageInput(2, _image7),
                                    ),
                                    SizedBox(
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.4,
                                      child: _buildImageInput(3, _image8),
                                    ),
                                  ],
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SizedBox(
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.4,
                                      child: _buildImageInput(4, _image9),
                                    ),
                                    SizedBox(
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.4,
                                      child: _buildImageInput(5, _image10),
                                    ),
                                  ],
                                ),
                                SizedBox(height: screenHeight * 0.02),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        SizedBox(
                          width: screenWidth * 0.4,
                          height: screenHeight * 0.1,
                          child: ElevatedButton(
                            onPressed: _submitData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 101, 204, 82),
                              padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.02),
                              textStyle: TextStyle(
                                fontSize: screenWidth * 0.05,
                              ),
                            ),
                            child: const Text(
                              'Logout',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ],
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
