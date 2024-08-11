import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'globals.dart'; // Assuming you have a globals.dart file for global variables

class LogEntry {
  final String date;
  final String vehicle;
  final String driver;
  final String from;
  final String to;
  final int startKm;
  final int endKm;
  final List<String> photos;

  LogEntry({
    required this.date,
    required this.vehicle,
    required this.driver,
    required this.from,
    required this.to,
    required this.startKm,
    required this.endKm,
    required this.photos,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      date: json['shift_date'] ?? '',
      vehicle: json['vehicle'] ?? '',
      driver: json['driver'] ?? '',
      from: json['shift_start'] ?? '',
      to: json['shift_end'] ?? '',
      startKm: json['km_start'] ?? 0,
      endKm: json['km_end'] ?? 0,
      photos: (json['photos'] ?? '')
          .toString()
          .split(',')
          .map((s) => s.trim())
          .toList(),
    );
  }

  String calculateTotalTime() {
    if (from.isEmpty || to.isEmpty) {
      return '';
    }
    try {
      final DateFormat format = DateFormat('HH:mm');
      final DateTime startTime = format.parse(from);
      final DateTime endTime = format.parse(to);
      final Duration difference = endTime.difference(startTime);
      final int hours = difference.inHours;
      final int minutes = difference.inMinutes % 60;
      return '${hours}h ${minutes}m';
    } catch (e) {
      print('Error parsing time: $e');
      return '';
    }
  }

  String calculateKmDifference() {
    return '${endKm - startKm} km';
  }
}

class Vehicle {
  final int id;
  final String name;
  final String numberPlate;

  Vehicle({required this.id, required this.name, required this.numberPlate});

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as int,
      name: json['name'] as String,
      numberPlate: json['numberplate'] as String,
    );
  }
}

class MyLogPage extends StatefulWidget {
  const MyLogPage({super.key});

  @override
  State<MyLogPage> createState() => _MyLogPageState();
}

class _MyLogPageState extends State<MyLogPage> {
  List<LogEntry> _logData = [];
  List<LogEntry> _filteredLogData = [];
  List<Vehicle> _vehicles = [];
  DateTime? _startDate;
  DateTime? _endDate;
  Vehicle? _selectedVehicle;
  final String baseUrl = 'https://vinczefi.com'; // Define your base URL here
  int? _selectedCarId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  Future<void> _fetchVehicles() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/greenfleet/flutter_functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'get-cars',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonData = jsonDecode(response.body);
        List<Vehicle> vehicles =
        jsonData.map((json) => Vehicle.fromJson(json)).toList();

        setState(() {
          _vehicles = vehicles;
          if (_vehicles.isNotEmpty) {
            _vehicles.insert(
              0,
              Vehicle(id: -1, name: 'All', numberPlate: ''),
            );
            _selectedVehicle = _vehicles.first;
            _selectedCarId = _selectedVehicle!.id;
          }
          _isLoading = false;
        });

        _fetchLogData();
      } else {
        print('Failed to load vehicles: ${response.statusCode}');
        _isLoading = false;
      }
    } catch (e) {
      print('Error fetching vehicles: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLogData() async {
    if (_startDate == null || _endDate == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/greenfleet/flutter_functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'vehicle-logs-filter',
          'from': DateFormat('yyyy-MM-dd').format(_startDate!),
          'to': DateFormat('yyyy-MM-dd').format(_endDate!),
          'vehicle': _selectedCarId == -1 ? 'all' : _selectedCarId.toString(),
          'driver': Globals.userId == null ? 'all' : Globals.userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        setState(() {
          _logData =
              responseData.map((data) => LogEntry.fromJson(data)).toList();
          _sortLogData();
          _filteredLogData = _logData;
          _filterByDate();
          _isLoading = false;
        });
      } else {
        _showErrorDialog(
            'Failed to load logs', 'Status code: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorDialog('Error', 'An error occurred: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sortLogData() {
    _logData.sort((a, b) {
      DateTime dateTimeA = DateFormat('yyyy-MM-dd HH:mm')
          .parse('${a.date} ${a.from}');
      DateTime dateTimeB = DateFormat('yyyy-MM-dd HH:mm')
          .parse('${b.date} ${b.from}');
      return dateTimeB.compareTo(dateTimeA);
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

  void _filterByDate() {
    setState(() {
      if (_startDate == null && _endDate == null) {
        _filteredLogData = _logData;
      } else {
        _filteredLogData = _logData.where((log) {
          DateTime logDate = DateFormat('yyyy-MM-dd').parse(log.date);
          if (_startDate != null && logDate.isBefore(_startDate!)) {
            return false;
          }
          if (_endDate != null && logDate.isAfter(_endDate!)) {
            return false;
          }
          return true;
        }).toList();
      }
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

  void _applyFilters() {
    _fetchLogData().then((_) {
      setState(() {
        _filteredLogData.sort((a, b) {
          DateTime dateTimeA = DateFormat('yyyy-MM-dd HH:mm')
              .parse('${a.date} ${a.from}');
          DateTime dateTimeB = DateFormat('yyyy-MM-dd HH:mm')
              .parse('${b.date} ${b.from}');
          return dateTimeB.compareTo(dateTimeA);
        });
      });
    });
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedCarId = -1;
      _filteredLogData = _logData;
    });
  }

  void _showImageDialog(List<String> photoUrls) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 400,
                  child: PageView.builder(
                    itemCount: photoUrls.length,
                    itemBuilder: (context, index) {
                      String photo = photoUrls[index];
                      bool isBase64 = photo.startsWith('data:image');
                      String imageUrl = isBase64
                          ? photo
                          : '$baseUrl/$photo'; // Append base URL if it's not a base64 string

                      return InteractiveViewer(
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
                      );
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Logs'),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 101, 204, 82),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16.0),
            DateSelectionContainer(
              startDate: _startDate,
              endDate: _endDate,
              vehicles: _vehicles,
              selectedCarId: _selectedCarId,
              onSelectStartDate: () => _selectStartDate(context),
              onSelectEndDate: () => _selectEndDate(context),
              onVehicleChanged: (newValue) {
                setState(() {
                  _selectedCarId = newValue;
                });
              },
              onApplyFilters: _applyFilters,
            ),
            const SizedBox(height: 16.0),
            LogDataTable(
              logData: _filteredLogData,
              onImageTap: _showImageDialog,
            ),
          ],
        ),
      ),
    );
  }
}

class DateSelectionContainer extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<Vehicle> vehicles;
  final int? selectedCarId;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final ValueChanged<int?> onVehicleChanged;
  final VoidCallback onApplyFilters;

  const DateSelectionContainer({
    super.key,
    this.startDate,
    this.endDate,
    required this.vehicles,
    this.selectedCarId,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onVehicleChanged,
    required this.onApplyFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                onPressed: onSelectStartDate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                child: Text(
                  startDate == null
                      ? 'From'
                      : DateFormat('yyyy-MM-dd').format(startDate!),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16.0),
              ElevatedButton(
                onPressed: onSelectEndDate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                child: Text(
                  endDate == null
                      ? 'To'
                      : DateFormat('yyyy-MM-dd').format(endDate!),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          const Text(
            'Vehicles',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
          const SizedBox(height: 8.0),
          Center(
            child: DropdownButton<int>(
              value: selectedCarId,
              onChanged: onVehicleChanged,
              items: vehicles.map((Vehicle car) {
                return DropdownMenuItem<int>(
                  value: car.id,
                  child: Text(
                    car.id == -1 ? 'All Vehicles' : '${car.name} - ${car.numberPlate}',
                    style: const TextStyle(color: Colors.black),
                  ),
                );
              }).toList(),
              hint: Text(
                selectedCarId == null
                    ? 'Select Car'
                    : vehicles.firstWhere((car) => car.id == selectedCarId).name,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
              dropdownColor: Colors.white,
              underline: Container(
                height: 2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          Center(
            child: ElevatedButton(
              onPressed: onApplyFilters,
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
          ),
        ],
      ),
    );
  }
}

class LogDataTable extends StatelessWidget {
  final List<LogEntry> logData;
  final ValueChanged<List<String>> onImageTap;

  const LogDataTable({
    super.key,
    required this.logData,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Driver', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('From', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('To', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Start KM', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('End KM', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Difference', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Photos', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: logData.map((log) {
            final totalTime = log.calculateTotalTime();
            final kmDifference = log.calculateKmDifference();
            return DataRow(
              cells: [
                DataCell(Text(log.date)),
                DataCell(Text(log.vehicle)),
                DataCell(Text(log.driver)),
                DataCell(Text(log.from)),
                DataCell(Text(log.to)),
                DataCell(Text(totalTime)),
                DataCell(Text(log.startKm.toString())),
                DataCell(Text(log.endKm.toString())),
                DataCell(Text(kmDifference)),
                DataCell(
                  log.photos.isNotEmpty
                      ? GestureDetector(
                    onTap: () => onImageTap(log.photos),
                    child: const Icon(Icons.image, color: Colors.green),
                  )
                      : const Text('No photos'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
