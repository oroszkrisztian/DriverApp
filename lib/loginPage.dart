import 'package:app/models/cars_model.dart';
import 'package:app/services/car_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'driverPage.dart'; // Import DriverPage

import 'globals.dart';
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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _kmController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  final CarServices _carServices = CarServices();
  final List<Car> _cars = []; // Add this to store cars locally

  File? _image1;
  File? _image2;
  File? _image3;
  File? _image4;
  File? _image5;
  File? parcursIn;

  int? _selectedCarId;
  bool _isLoading = false;
  String? _errorMessage;
  int? _lastKm;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _carServices.initializeData();

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading vehicles: $e';
      });
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

  void _onCarSelected(int? newValue) {
    setState(() {
      _selectedCarId = newValue;
      if (newValue != null) {
        // Get the vehicle data for the selected car
        VehicleData? selectedVehicleData =
            _carServices.getVehicleData(newValue);
        if (selectedVehicleData != null) {
          _lastKm = selectedVehicleData.km; // Get KM from VehicleData
        }
      }
    });
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

  void _showLoggingDialog() {
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
                    Color.fromARGB(255, 101, 204, 82),
                  ),
                ),
                SizedBox(width: 16),
                Text("Logging into vehicle"),
              ],
            ),
          ),
        );
      },
    );
  }

  void _hideLoggingDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _submitData() async {
    if (_selectedCarId == null || _kmController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Please select a car and enter the KM.'),
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

    if (_image1 == null ||
        _image2 == null ||
        _image3 == null ||
        _image4 == null ||
        _image5 == null ||
        parcursIn == null) {
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

    Globals.image1 = _image1;
    Globals.image2 = _image2;
    Globals.image3 = _image3;
    Globals.image4 = _image4;
    Globals.image5 = _image5;
    Globals.parcursIn = parcursIn;
    Globals.vehicleID = _selectedCarId;
    Globals.kmValue = _kmController.text;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('vehicleId', Globals.vehicleID!);

    await prefs.setString('image1', _image1!.path);
    await prefs.setString('image2', _image2!.path);
    await prefs.setString('image3', _image3!.path);
    await prefs.setString('image4', _image4!.path);
    await prefs.setString('image5', _image5!.path);
    await prefs.setString('parcursIn', parcursIn!.path);

    _lastKm ??= 0;

    if (int.tryParse(_kmController.text) != null) {
      int userInputKm = int.parse(_kmController.text);

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

    _showLoggingDialog();
    await loginVehicle(); // Make sure this function exists

    Workmanager().registerOneOffTask(
      "1",
      uploadImageTask,
      inputData: {
        'userId': Globals.userId.toString(),
        'vehicleID': Globals.vehicleID.toString(),
        'km': _kmController.text,
        'image1': Globals.image1?.path,
        'image2': Globals.image2?.path,
        'image3': Globals.image3?.path,
        'image4': Globals.image4?.path,
        'image5': Globals.image5?.path,
        'image6': Globals.parcursIn?.path
      },
    );

    _hideLoggingDialog();

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
        title: const Text("Login in My Car"),
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
                  const SizedBox(height: 16),
                  const Text('Loading...')
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!),
                      ElevatedButton(
                        onPressed: _initializeData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
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
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                // Dropdown for car selection
                                DropdownButtonFormField<int>(
                                  value: _selectedCarId,
                                  items: _carServices.cars.map((Car car) {
                                    return DropdownMenuItem<int>(
                                      value: car.id,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0),
                                        child: Text(
                                            '${car.name} - ${car.numberPlate}',
                                            style: const TextStyle(
                                                color: Colors.black)),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: _onCarSelected,
                                  decoration: InputDecoration(
                                    labelText: 'Car',
                                    labelStyle:
                                        const TextStyle(color: Colors.black),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                          color: Color.fromARGB(
                                              255, 101, 204, 82)),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                          color: Color.fromARGB(
                                              255, 101, 204, 82)),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  style: const TextStyle(color: Colors.black),
                                  dropdownColor: Colors.white,
                                  icon: const Icon(Icons.arrow_drop_down,
                                      color: Colors.black),
                                  isExpanded: true,
                                  iconSize: 30.0,
                                ),
                                if (_isLoading) CircularProgressIndicator(),
                                if (_errorMessage != null) Text(_errorMessage!),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _kmController,
                                  cursorColor:
                                      const Color.fromARGB(255, 101, 204, 82),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'KM',
                                    labelStyle:
                                        const TextStyle(color: Colors.black),
                                    // Show KM if available for selected car
                                    hintText: _selectedCarId != null
                                        ? 'Last KM: ${carServices.getLastKmForVehicle(_selectedCarId!) ?? "N/A"}'
                                        : 'Enter KM',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
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
                                  style: const TextStyle(color: Colors.black),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SizedBox(
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.4,
                                      child: _buildImageInput(1, _image1),
                                    ),
                                    SizedBox(
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.4,
                                      child: _buildImageInput(6, parcursIn),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.directions_car,
                                      size: 24,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Photos',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SizedBox(
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.4,
                                      child: _buildImageInput(2, _image2),
                                    ),
                                    SizedBox(
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.4,
                                      child: _buildImageInput(3, _image3),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SizedBox(
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.4,
                                      child: _buildImageInput(4, _image4),
                                    ),
                                    SizedBox(
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.4,
                                      child: _buildImageInput(5, _image5),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 150,
                          height: 80,
                          child: ElevatedButton(
                            onPressed: _submitData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 101, 204, 82),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20.0),
                              textStyle: const TextStyle(
                                fontSize: 20,
                              ),
                            ),
                            child: const Text(
                              'Login',
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
