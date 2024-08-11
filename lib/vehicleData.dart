import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'globals.dart';

class VehicleEntry {
  final int id;
  final String name;
  final String plateNumber;
  final String type;
  final int km;
  final String startDate;
  final String endDate;
  final String remarks;
  final String photo;
  final String status;

  VehicleEntry({
    required this.id,
    required this.name,
    required this.plateNumber,
    required this.type,
    required this.km,
    required this.startDate,
    required this.endDate,
    required this.remarks,
    required this.photo,
    required this.status,
  });

  factory VehicleEntry.fromJson(Map<String, dynamic> json) {
    return VehicleEntry(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      plateNumber: json['numberplate'] ?? '',
      type: json['type'] ?? '',
      km: json['km'] ?? 0,
      startDate: json['date_start'] ?? '',
      endDate: json['date_end'] ?? '',
      remarks: json['remarks'] ?? '',
      photo: json['photo'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VehicleDataPage(),
    ),
  );
}

class VehicleDataPage extends StatefulWidget {
  const VehicleDataPage({super.key});

  @override
  _VehicleDataPageState createState() => _VehicleDataPageState();
}

class _VehicleDataPageState extends State<VehicleDataPage> {
  List<VehicleEntry> _vehicleData = [];
  List<VehicleEntry> _filteredVehicleData = [];
  String _selectedStatus = 'All';
  String _selectedType = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  final String baseUrl = 'https://vinczefi.com'; // Define your base URL here

  @override
  void initState() {
    super.initState();
    _fetchVehicleData(); // Fetch data initially
  }

  Future<void> _fetchVehicleData() async {
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/greenfleet/flutter_functions_1.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'vehicle-data-filter',
          'from': _startDate != null
              ? DateFormat('yyyy-MM-dd').format(_startDate!)
              : '',
          'to': _endDate != null
              ? DateFormat('yyyy-MM-dd').format(_endDate!)
              : '',
          'status': _selectedStatus.toLowerCase() == 'expired' ? 'expired' : 'active',
          'type': _selectedType.toLowerCase(),
          'vehicle': Globals.vehicleID?.toString(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<VehicleEntry> fetchedData =
        responseData.map((data) => VehicleEntry.fromJson(data)).toList();

        _vehicleData = fetchedData;

        _filterData();

        setState(() {
          _filteredVehicleData = _vehicleData;
        });

        print('Response Body: ${response.body}');
      } else {
        _showErrorDialog('Failed to load vehicle data',
            'Status code: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error', 'Failed to load vehicle data: $e');
    }
  }

  void _filterData() {
    setState(() {
      _filteredVehicleData = _vehicleData.where((vehicle) {
        DateTime startDate =
            DateTime.tryParse(vehicle.startDate) ?? DateTime(2000);
        DateTime endDate = DateTime.tryParse(vehicle.endDate) ?? DateTime(2100);
        if (_startDate != null && startDate.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && endDate.isAfter(_endDate!)) {
          return false;
        }
        if (_selectedStatus != 'All' &&
            vehicle.status.toLowerCase() != _selectedStatus.toLowerCase()) {
          return false;
        }
        if (_selectedType != 'All' && vehicle.type != _selectedType) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[Text(message)],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _applyFilters() {
    _fetchVehicleData().then((_) {
      setState(() {
        _filteredVehicleData.sort((a, b) {
          DateTime dateA = DateTime.tryParse(a.endDate) ?? DateTime(2000);
          DateTime dateB = DateTime.tryParse(b.endDate) ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
      });
    });
  }

  void _filterByStatus(String status) {
    setState(() {
      _selectedStatus = status;
    });
  }

  void _filterByType(String type) {
    setState(() {
      _selectedType = type;
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 101, 204, 82),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 101, 204, 82),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }


  void _showImage(String photo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isBase64 = photo.startsWith('data:image');
        String imageUrl = isBase64
            ? photo
            : '$baseUrl/$photo'; // Append base URL if it's not a base64 string

        print('Image URL: $imageUrl');
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InteractiveViewer(
                    child: isBase64
                        ? Image.memory(
                      base64Decode(photo.split(',').last),
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error);
                      },
                    )
                        : Image.network(
                      imageUrl,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error);
                      },
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Data'),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 101, 204, 82),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16.0),
            // Filter Container
            Container(
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
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _selectStartDate(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        child: Text(
                          _startDate != null
                              ? DateFormat('yyyy-MM-dd').format(_startDate!)
                              : 'From',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      ElevatedButton(
                        onPressed: () => _selectEndDate(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        child: Text(
                          _endDate != null
                              ? DateFormat('yyyy-MM-dd').format(_endDate!)
                              : 'To',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                          ),
                          const SizedBox(height: 8.0),
                          DropdownButton<String>(
                            value: _selectedStatus,
                            onChanged: (value) {
                              _filterByStatus(value!);
                            },
                            items: ['All', 'Active', 'Expired']
                                .map((status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            ))
                                .toList(),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16.0),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Type',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                          ),
                          const SizedBox(height: 8.0),
                          DropdownButton<String>(
                            value: _selectedType,
                            onChanged: (value) {
                              _filterByType(value!);
                            },
                            items: ['All', 'Oil', 'TUV', 'Insurance']
                                .map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ))
                                .toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 101, 204, 82),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            // Data Table Container
            Container(
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
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'ID',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Name',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Plate Number',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Type',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'KM',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Start Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'End Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Remarks',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Photo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: _filteredVehicleData.map((data) {
                    return DataRow(
                      cells: [
                        DataCell(Text(data.id.toString())),
                        DataCell(Text(data.name)),
                        DataCell(Text(data.plateNumber)),
                        DataCell(Text(data.type)),
                        DataCell(Text(data.km.toString())),
                        DataCell(Text(data.startDate)),
                        DataCell(Text(data.endDate)),
                        DataCell(Text(data.remarks)),
                        DataCell(
                          data.photo.isNotEmpty
                              ? GestureDetector(
                            onTap: () => _showImage(data.photo),
                            child: const Icon(
                              Icons.image,
                              color: Colors.green,
                            ),
                          )
                              : const Text('No photos'),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
