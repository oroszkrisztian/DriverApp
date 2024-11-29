import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'globals.dart';
import 'models/no_internet_widget.dart';

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
  bool _isLoading = false;
  bool _hasInternet = true;
  final String baseUrl = 'https://vinczefi.com';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

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
      await _fetchVehicleData();
    }
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
          'status':
              _selectedStatus.toLowerCase() == 'expired' ? 'expired' : 'active',
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

        if (_startDate != null && startDate.isBefore(_startDate!)) return false;
        if (_endDate != null && endDate.isAfter(_endDate!)) return false;
        if (_selectedStatus != 'All' &&
            vehicle.status.toLowerCase() != _selectedStatus.toLowerCase())
          return false;
        if (_selectedType != 'All' && vehicle.type != _selectedType)
          return false;

        return true;
      }).toList();
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
      setState(() => _startDate = picked);
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
      setState(() => _endDate = picked);
    }
  }

  void _filterByStatus(String status) =>
      setState(() => _selectedStatus = status);
  void _filterByType(String type) => setState(() => _selectedType = type);

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

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[Text(message)],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showImage(String photo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isBase64 = photo.startsWith('data:image');
        String imageUrl = isBase64 ? photo : '$baseUrl/$photo';

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
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.error),
                          )
                        : Image.network(
                            imageUrl,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.error),
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
            Icon(Icons.directions_car, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Vehicle Data',
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
      body:
      !_hasInternet
          ? NoInternetWidget(
        onRetry: () => _initializeData(),
      ):

      Container(
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
                        minHeight: constraints.maxHeight - 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16.0),
                          StyledFilterContainer(
                            startDate: _startDate,
                            endDate: _endDate,
                            selectedStatus: _selectedStatus,
                            selectedType: _selectedType,
                            onSelectStartDate: () => _selectStartDate(context),
                            onSelectEndDate: () => _selectEndDate(context),
                            onStatusChanged: _filterByStatus,
                            onTypeChanged: _filterByType,
                            onApplyFilters: _applyFilters,
                          ),
                          const SizedBox(height: 16.0),
                          StyledDataTable(
                            vehicleData: _filteredVehicleData,
                            onImageTap: _showImage,
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

class StyledFilterContainer extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String selectedStatus;
  final String selectedType;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final Function(String) onStatusChanged;
  final Function(String) onTypeChanged;
  final VoidCallback onApplyFilters;

  const StyledFilterContainer({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.selectedStatus,
    required this.selectedType,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onStatusChanged,
    required this.onTypeChanged,
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

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required Function(String) onChanged,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: const Color.fromARGB(255, 101, 204, 82),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color.fromARGB(255, 101, 204, 82),
              width: 1,
            ),
            color: Colors.white,
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: Container(),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: Color.fromARGB(255, 101, 204, 82),
            ),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: (String? newValue) {
              // Modified to handle nullable
              if (newValue != null) {
                onChanged(newValue);
              }
            },
          ),
        ),
      ],
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

            // Filters Section
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    value: selectedStatus,
                    items: const ['All', 'Active', 'Expired'],
                    onChanged: onStatusChanged,
                    label: 'Status',
                    icon: Icons.info_outline,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown(
                    value: selectedType,
                    items: const ['All', 'Oil', 'TUV', 'Insurance'],
                    onChanged: onTypeChanged,
                    label: 'Type',
                    icon: Icons.category,
                  ),
                ),
              ],
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

class StyledDataTable extends StatelessWidget {
  final List<VehicleEntry> vehicleData;
  final Function(String) onImageTap;

  const StyledDataTable({
    super.key,
    required this.vehicleData,
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.table_chart,
                  color: Color.fromARGB(255, 101, 204, 82),
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Vehicle Records',
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
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Plate Number')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('KM')),
                  DataColumn(label: Text('Start Date')),
                  DataColumn(label: Text('End Date')),
                  DataColumn(label: Text('Remarks')),
                  DataColumn(label: Text('Photo')),
                ],
                rows: vehicleData.map((data) {
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
                                onTap: () => onImageTap(data.photo),
                                child: const Icon(
                                  Icons.image,
                                  color: Color.fromARGB(255, 101, 204, 82),
                                ),
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
