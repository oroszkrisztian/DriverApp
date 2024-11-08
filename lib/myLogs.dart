import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'globals.dart';
import 'models/no_internet_widget.dart';

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
    if (from.isEmpty || to.isEmpty) return '';
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
  final String baseUrl = 'https://vinczefi.com';
  int? _selectedCarId;
  bool _isLoading = false;
  bool _hasInternet = true;

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _initializeData() async {
    bool hasInternet = await _checkInternet();
    setState(() {
      _hasInternet = hasInternet;
    });
    if (hasInternet) {
      await _fetchVehicles();
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
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
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching vehicles: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLogData() async {
    if (_startDate == null || _endDate == null) return;

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
      DateTime dateTimeA =
          DateFormat('yyyy-MM-dd HH:mm').parse('${a.date} ${a.from}');
      DateTime dateTimeB =
          DateFormat('yyyy-MM-dd HH:mm').parse('${b.date} ${b.from}');
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
          DateTime dateTimeA =
              DateFormat('yyyy-MM-dd HH:mm').parse('${a.date} ${a.from}');
          DateTime dateTimeB =
              DateFormat('yyyy-MM-dd HH:mm').parse('${b.date} ${b.from}');
          return dateTimeB.compareTo(dateTimeA);
        });
      });
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
                      String imageUrl = isBase64 ? photo : '$baseUrl/$photo';

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
                    backgroundColor: const Color.fromARGB(255, 101, 204, 82),
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
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'My Logs',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 101, 204, 82),
        elevation: 0,
      ),
      body: !_hasInternet
          ? NoInternetWidget(
              onRetry: () => _initializeData(),
            )
          : Container(
              width: double.infinity,
              height: double.infinity,
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
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromARGB(255, 101, 204, 82),
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight -
                                  32, // Account for padding
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 16.0),
                                StyledDateSelectionContainer(
                                  startDate: _startDate,
                                  endDate: _endDate,
                                  vehicles: _vehicles,
                                  selectedCarId: _selectedCarId,
                                  onSelectStartDate: () =>
                                      _selectStartDate(context),
                                  onSelectEndDate: () =>
                                      _selectEndDate(context),
                                  onVehicleChanged: (newValue) {
                                    setState(() {
                                      _selectedCarId = newValue;
                                    });
                                  },
                                  onApplyFilters: _applyFilters,
                                ),
                                const SizedBox(height: 16.0),
                                StyledLogDataTable(
                                  logData: _filteredLogData,
                                  onImageTap: _showImageDialog,
                                ),
                                const SizedBox(height: 16.0),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class StyledLogDataTable extends StatelessWidget {
  final List<LogEntry> logData;
  final ValueChanged<List<String>> onImageTap;

  const StyledLogDataTable({
    super.key,
    required this.logData,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color.fromARGB(255, 240, 250, 238),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.format_list_bulleted,
                  color: Color.fromARGB(255, 101, 204, 82),
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Log Entries',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  const Color.fromARGB(255, 101, 204, 82).withOpacity(0.1),
                ),
                dataRowColor: MaterialStateProperty.all(Colors.transparent),
                columnSpacing: 20,
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                dataTextStyle: const TextStyle(
                  color: Colors.black87,
                ),
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Vehicle')),
                  DataColumn(label: Text('Driver')),
                  DataColumn(label: Text('From')),
                  DataColumn(label: Text('To')),
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('Start KM')),
                  DataColumn(label: Text('End KM')),
                  DataColumn(label: Text('Difference')),
                  DataColumn(label: Text('Photos')),
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
                            ? IconButton(
                                icon: const Icon(
                                  Icons.photo_library,
                                  color: Color.fromARGB(255, 101, 204, 82),
                                ),
                                onPressed: () => onImageTap(log.photos),
                              )
                            : const Text('No photos'),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StyledDateSelectionContainer extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<Vehicle> vehicles;
  final int? selectedCarId;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final ValueChanged<int?> onVehicleChanged;
  final VoidCallback onApplyFilters;

  const StyledDateSelectionContainer({
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

  Widget _buildDateButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: Color.fromARGB(255, 101, 204, 82),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color.fromARGB(255, 101, 204, 82),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color.fromARGB(255, 240, 250, 238),
            ],
          ),
        ),
        child: Column(
          children: [
            // Date Section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.date_range,
                  color: Color.fromARGB(255, 101, 204, 82),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Select Date Range',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildDateButton(
                    onPressed: onSelectStartDate,
                    text: startDate == null
                        ? 'Start Date'
                        : DateFormat('yyyy-MM-dd').format(startDate!),
                    icon: Icons.calendar_today,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateButton(
                    onPressed: onSelectEndDate,
                    text: endDate == null
                        ? 'End Date'
                        : DateFormat('yyyy-MM-dd').format(endDate!),
                    icon: Icons.calendar_today,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Vehicle Section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.directions_car,
                  color: Color.fromARGB(255, 101, 204, 82),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Select Vehicle',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color.fromARGB(255, 101, 204, 82),
                  width: 1,
                ),
              ),
              child: DropdownButton<int>(
                value: selectedCarId,
                onChanged: onVehicleChanged,
                items: vehicles.map((Vehicle car) {
                  return DropdownMenuItem<int>(
                    value: car.id,
                    child: Text(
                      car.id == -1
                          ? 'All Vehicles'
                          : '${car.name} - ${car.numberPlate}',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  );
                }).toList(),
                isExpanded: true,
                underline: Container(),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Color.fromARGB(255, 101, 204, 82),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Apply Button
            ElevatedButton(
              onPressed: onApplyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list),
                  SizedBox(width: 8),
                  Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
