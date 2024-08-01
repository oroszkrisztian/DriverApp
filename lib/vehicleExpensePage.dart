import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'globals.dart';
import 'main.dart';

// Define the constant for the expense upload task
const String uploadExpenseTask = "uploadExpenseTask";

class VehicleExpensePage extends StatefulWidget {
  const VehicleExpensePage({Key? key}) : super(key: key);

  @override
  _VehicleExpensePageState createState() => _VehicleExpensePageState();
}

class _VehicleExpensePageState extends State<VehicleExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  String? _selectedType;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _isFuelOrOthersSelected = false;

  final List<String> _expenseTypes = ['Fuel', 'Wash', 'Others'];

  /// Pick an image using the camera
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  /// Show an image preview dialog
  void _showImagePreview(File image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Image Preview'),
          content: Image.file(image),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                foregroundColor: Colors.black,
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Submit the expense data
  Future<void> _submitExpense() async {
    if (_formKey.currentState!.validate() && _image != null) {
      setState(() {
        _isSubmitting = true;
      });

      // Gather form data
      Map<String, String> inputData = {
        'driver': Globals.userId.toString(),
        'vehicle': Globals.vehicleID.toString(),
        'km': _kmController.text,
        'type': _selectedType!,
        'remarks': _remarksController.text,
        'cost': _costController.text,
        'image': _image?.path ?? '',
      };

      // Register a background task for the expense upload
      Workmanager().registerOneOffTask(
        'expenseUpload',
        uploadExpenseTask,
        inputData: inputData,
        tag: uploadExpenseTask,
        backoffPolicy: BackoffPolicy.linear,
      );

      // Show success message
      _showSuccessDialog();
      _resetForm();
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  /// Reset the form to its initial state
  void _resetForm() {
    setState(() {
      _kmController.clear();
      _remarksController.clear();
      _costController.clear();
      _selectedType = null;
      _image = null;
      _isFuelOrOthersSelected = false;
    });
  }

  /// Show a success dialog when the expense is scheduled
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Expense Scheduled'),
          content: const Text('Your expense has been scheduled for submission.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                foregroundColor: Colors.black,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Build a widget to display an image container
  Widget _buildImageContainer(String label, File? image) {
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.black),
                  ),
                  if (image != null) const Icon(Icons.check, color: Colors.black),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _pickImage,
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
                onPressed: image != null ? () => _showImagePreview(image) : null,
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
      ),
    );
  }

  @override
  void dispose() {
    _kmController.dispose();
    _remarksController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Vehicle Expense'),
        backgroundColor: const Color.fromARGB(255, 101, 204, 82),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          width: 1,
                          color: Colors.black,
                        ),
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
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Expense Type'),
                            items: _expenseTypes.map((String type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            validator: (value) {
                              if (value == null) {
                                return 'Please select an expense type';
                              }
                              return null;
                            },
                            onChanged: (newValue) {
                              setState(() {
                                _selectedType = newValue;
                                _isFuelOrOthersSelected = newValue == 'Fuel' || newValue == 'Others';
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _kmController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'KM'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter KM';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _remarksController,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              labelText: _isFuelOrOthersSelected ? 'Remarks' : 'Remarks (Optional)',
                            ),
                            validator: (value) {
                              if (_isFuelOrOthersSelected && (value == null || value.isEmpty)) {
                                return 'Please enter remarks';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _costController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Cost'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter cost';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16.0),
                          _buildImageContainer('Expense Image', _image),
                          if (_image == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),

                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isSubmitting)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: ElevatedButton(
          onPressed: _submitExpense,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 101, 204, 82),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Submit Expense',
            style: TextStyle(color: Colors.black), // Set text color to black
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
