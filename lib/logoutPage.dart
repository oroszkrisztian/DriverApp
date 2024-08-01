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

  File? _image1;
  File? _image2;
  File? _image3;
  File? _image4;
  File? _image5;

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
        Uri.parse('https://greenfleet.ro/flatter/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'get-vehicle-info',
          'vehicle':Globals.vehicleID.toString(),
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
        Uri.parse('https://greenfleet.ro/flatter/functions.php'),
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
            _lastKm = null;
            _errorMessage = 'No KM data found for this vehicle.';
          });
          return false;
        } else if (data != null && (data is int || int.tryParse(data.toString()) != null)) {
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
        label = 'Dashboard';
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
      default:
        label = 'Unknown';
    }

    return Container(
      height: 150,
      width: 160,
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
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.black),
                ),
                if (image != null) const Icon(Icons.check, color: Colors.black),
                const SizedBox(height: 8),
              ],
            ),
            ElevatedButton(
              onPressed: () => _getImage(imageNumber),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Color.fromARGB(255, 101, 204, 82), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text('Take a picture'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _showImage(image),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Color.fromARGB(255, 101, 204, 82), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text('Preview'),
            ),
          ],
        ),
      ),
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
    if (_image1 == null || _image2 == null || _image3 == null || _image4 == null || _image5 == null) {
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

    // Compare user input with last KM
    if (_lastKm != null && int.tryParse(_kmController.text) != null) {
      int userInputKm = int.parse(_kmController.text);
      if (userInputKm <= _lastKm!) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text('The entered KM must be greater than the last logged KM.\nLast km: $_lastKm'),
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
        'image1': Globals.image1?.path,
        'image2': Globals.image2?.path,
        'image3': Globals.image3?.path,
        'image4': Globals.image4?.path,
        'image5': Globals.image5?.path
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
                Color.fromARGB(255, 101, 204, 82), // Green color
              ),
            ),
            const SizedBox(width: 16),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_selectedCar != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  padding: const EdgeInsets.all(16.0),
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _kmController,
                    cursorColor: const Color.fromARGB(255, 101, 204, 82),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: 'KM',
                      labelStyle: const TextStyle(color: Colors.black),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color.fromARGB(255, 101, 204, 82),
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color.fromARGB(255, 101, 204, 82),
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildImageInput(1, _image1),
              const SizedBox(height: 20),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildImageInput(2, _image2),
                      _buildImageInput(3, _image3),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildImageInput(4, _image4),
                      _buildImageInput(5, _image5),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 150,
                height: 80,
                child: ElevatedButton(
                  onPressed: _submitData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    textStyle: const TextStyle(
                      fontSize: 20,
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
