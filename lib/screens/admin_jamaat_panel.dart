import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../services/jamaat_service.dart';
import '../core/constants.dart';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';

class AdminJamaatPanel extends StatefulWidget {
  const AdminJamaatPanel({super.key});

  @override
  State<AdminJamaatPanel> createState() => _AdminJamaatPanelState();
}

class _AdminJamaatPanelState extends State<AdminJamaatPanel> with SingleTickerProviderStateMixin {
  final JamaatService _jamaatService = JamaatService();
  TabController? _tabController;
  
  // Manual Entry Variables
  String _selectedCity = AppConstants.canttNames.first;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  // Jamaat time display variables (from profile screen)
  final List<String> _prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  final Map<String, TextEditingController> _jamaatControllers = {
    for (var p in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'])
      p: TextEditingController(),
  };
  bool _adminLoading = false;
  String? _adminMsg;
  String? _editingPrayer;

  // Bulk import settings
  int _selectedYear = DateTime.now().year;
  bool _overwriteExisting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadJamaatTimes();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    for (final controller in _jamaatControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadJamaatTimes() async {
    setState(() {
      _adminLoading = true;
      _adminMsg = null;
    });

    try {
      final times = await _jamaatService.getJamaatTimes(
        city: _selectedCity,
        date: _selectedDate,
      );

      if (times != null) {
        // Auto-calculate Maghrib jamaat time if not present
        if (!times.containsKey('maghrib') || times['maghrib'] == null || times['maghrib'] == '-') {
          final calculatedMaghrib = _calculateMaghribJamaatTime();
          times['maghrib'] = calculatedMaghrib;
        }

        // Update controllers with loaded times
        for (final prayer in _prayers) {
          final key = prayer.toLowerCase();
          final controller = _jamaatControllers[prayer];
          if (controller != null && times.containsKey(key)) {
            final time = times[key];
            if (time != null && time.toString().isNotEmpty && time != '-') {
              controller.text = time.toString();
            } else {
              controller.clear();
            }
          }
        }

        setState(() {
          _adminLoading = false;
        });
      } else {
        setState(() {
          _adminLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _adminLoading = false;
        _adminMsg = 'Error loading jamaat times: $e';
      });
    }
  }

  Future<void> _saveManualTimes() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final times = <String, String>{};
      for (final entry in _jamaatControllers.entries) {
        if (entry.value.text.isNotEmpty) {
          times[entry.key.toLowerCase()] = entry.value.text;
        }
      }

      if (times.isEmpty) {
        setState(() {
          _message = 'Please enter at least one prayer time';
          _isSuccess = false;
        });
        return;
      }

      // Use JamaatService for consistent data structure
      try {
        await _jamaatService.saveJamaatTimes(
          city: _selectedCity,
          date: _selectedDate,
          times: times,
        );

        setState(() {
          _isSuccess = true;
          _message = 'Jamaat times saved successfully for $_selectedCity on ${DateFormat('MMM dd, yyyy').format(_selectedDate)}';
        });

        // Clear success message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isSuccess = false;
              _message = null;
            });
          }
        });
      } catch (e) {
        setState(() {
          _isSuccess = false;
          _message = 'Error saving jamaat times: $e';
        });
      }
    } catch (e) {
      debugPrint('Error saving jamaat times: $e');
      setState(() {
        _message = 'Error saving jamaat times: $e';
        _isSuccess = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editManualTimes() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      // Load existing times for editing
      await _loadJamaatTimes();
      
      setState(() {
        _message = 'Times loaded for editing. Make your changes and click Save.';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _message = 'Error loading times for editing: $e';
        _isSuccess = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromCSV() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = result.files.first;
        final csvString = String.fromCharCodes(file.bytes!);
        final csvData = const CsvToListConverter().convert(csvString);

        if (csvData.length < 2) {
          setState(() {
            _message = 'CSV file must have at least a header and one data row';
            _isSuccess = false;
          });
          return;
        }

        // Check CSV format and determine column mapping
        final header = csvData[0];
        
        // Determine column indices based on header
        int dateIndex = -1;
        int fajrIndex = -1;
        int dhuhrIndex = -1;
        int asrIndex = -1;
        int maghribIndex = -1;
        int sunsetIndex = -1;
        int ishaIndex = -1;
        
        for (int i = 0; i < header.length; i++) {
          final column = header[i].toString().toLowerCase().trim();
          if (column.contains('date')) {
            dateIndex = i;
          }
          else if (column.contains('fajr')) {
            fajrIndex = i;
          }
          else if (column.contains('dhuhr') || column.contains('zuhr')) {
            dhuhrIndex = i;
          }
          else if (column.contains('asr')) {
            asrIndex = i;
          }
          else if (column.contains('maghrib') || column.contains('magrib')) {
            maghribIndex = i;
          }
          else if (column.contains('sunset')) {
            sunsetIndex = i;
          }
          else if (column.contains('isha')) {
            ishaIndex = i;
          }
        }
        
        if (dateIndex == -1) {
          setState(() {
            _message = 'CSV must contain a Date column';
            _isSuccess = false;
          });
          return;
        }

        // Process CSV data
        int importedCount = 0;
        for (int i = 1; i < csvData.length; i++) {
          final row = csvData[i];
          if (row.length > dateIndex) {
            // Handle null values safely
            final date = row[dateIndex]?.toString() ?? '';
            if (date.isEmpty) {
              continue;
            }

            // Create times map with null safety
            final times = <String, String>{};
            
            // Add times based on column mapping
            if (fajrIndex >= 0 && fajrIndex < row.length && 
                row[fajrIndex] != null && row[fajrIndex].toString().trim().isNotEmpty) {
              times['fajr'] = row[fajrIndex].toString().trim();
            }
            
            if (dhuhrIndex >= 0 && dhuhrIndex < row.length && 
                row[dhuhrIndex] != null && row[dhuhrIndex].toString().trim().isNotEmpty) {
              times['dhuhr'] = row[dhuhrIndex].toString().trim();
            }
            
            if (asrIndex >= 0 && asrIndex < row.length && 
                row[asrIndex] != null && row[asrIndex].toString().trim().isNotEmpty) {
              times['asr'] = row[asrIndex].toString().trim();
            }
            
            // Handle Maghrib time - check if we have sunset time and calculate Maghrib
            if (sunsetIndex >= 0 && sunsetIndex < row.length && 
                row[sunsetIndex] != null && row[sunsetIndex].toString().trim().isNotEmpty) {
              final sunsetTime = row[sunsetIndex].toString().trim();
              times['maghrib'] = _calculateMaghribFromSunset(sunsetTime);
            } else if (maghribIndex >= 0 && maghribIndex < row.length && 
                       row[maghribIndex] != null && row[maghribIndex].toString().trim().isNotEmpty) {
              times['maghrib'] = row[maghribIndex].toString().trim();
            }
            
            if (ishaIndex >= 0 && ishaIndex < row.length && 
                row[ishaIndex] != null && row[ishaIndex].toString().trim().isNotEmpty) {
              times['isha'] = row[ishaIndex].toString().trim();
            }

            // Only save if we have at least one time
            if (times.isNotEmpty) {
              try {
                final parsedDate = _parseDate(date);
                if (parsedDate != null) {
                  await _jamaatService.saveJamaatTimes(
                    city: _selectedCity,
                    date: parsedDate,
                    times: times,
                  );
                  importedCount++;
                }
              } catch (e) {
                debugPrint('Error importing row $i: $e');
              }
            }
          }
        }

        setState(() {
          _message = 'Successfully imported $importedCount records from CSV. '
              'Columns found: ${header.join(', ')}';
          _isSuccess = true;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error importing CSV: $e';
        _isSuccess = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToCSV() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final csvData = [
        ['Date', 'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'],
      ];

      DateTime currentDate = DateTime(_selectedYear, 1, 1);
      final endDate = DateTime(_selectedYear, 12, 31);

      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        final times = await _jamaatService.getJamaatTimes(
          city: _selectedCity,
          date: currentDate,
        );

        if (times != null) {
          csvData.add([
            _formatDate(currentDate),
            times['fajr'] ?? '',
            times['dhuhr'] ?? '',
            times['asr'] ?? '',
            times['maghrib'] ?? '',
            times['isha'] ?? '',
          ]);
        }
        
        currentDate = currentDate.add(const Duration(days: 1));
      }

      // Save file (implementation depends on platform)
      // For now, just show success message
      setState(() {
        _message = 'CSV data prepared for $_selectedCity ($_selectedYear). Data: ${csvData.length - 1} days';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _message = 'Error exporting CSV: $e';
        _isSuccess = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateYearlyTimes() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      int generatedCount = 0;
      DateTime currentDate = DateTime(_selectedYear, 1, 1);
      final endDate = DateTime(_selectedYear, 12, 31);

      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        // Check if data already exists
        if (!_overwriteExisting) {
          final existingTimes = await _jamaatService.getJamaatTimes(
            city: _selectedCity,
            date: currentDate,
          );
          if (existingTimes != null) {
            currentDate = currentDate.add(const Duration(days: 1));
            continue;
          }
        }

        // Generate default times (you can customize these)
        final defaultTimes = {
          'fajr': '05:15',
          'dhuhr': '12:15',
          'asr': '15:45',
          'maghrib': '18:15',
          'isha': '19:45',
        };

        await _jamaatService.saveJamaatTimes(
          city: _selectedCity,
          date: currentDate,
          times: defaultTimes,
        );
        generatedCount++;
        currentDate = currentDate.add(const Duration(days: 1));
      }

      setState(() {
        _message = 'Generated $generatedCount days of jamaat times for $_selectedCity ($_selectedYear)';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _message = 'Error generating yearly times: $e';
        _isSuccess = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateSavarCanttTimes() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      int generatedCount = 0;
      DateTime currentDate = DateTime(_selectedYear, 1, 1);
      final endDate = DateTime(_selectedYear, 12, 31);

      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        // Check if data already exists
        if (!_overwriteExisting) {
          final existingTimes = await _jamaatService.getJamaatTimes(
            city: _selectedCity,
            date: currentDate,
          );
          if (existingTimes != null) {
            currentDate = currentDate.add(const Duration(days: 1));
            continue;
          }
        }

        // Get times based on date ranges for Savar Cantt
        final times = _getSavarCanttTimes(currentDate);
        
        await _jamaatService.saveJamaatTimes(
          city: _selectedCity,
          date: currentDate,
          times: times,
        );
        generatedCount++;
        currentDate = currentDate.add(const Duration(days: 1));
      }

      setState(() {
        _message = 'Generated $generatedCount days of Savar Cantt jamaat times for $_selectedYear';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _message = 'Error generating Savar Cantt times: $e';
        _isSuccess = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, String> _getSavarCanttTimes(DateTime date) {
    final month = date.month;
    final day = date.day;

    // Fajr times
    String fajrTime = '05:50'; // Default
    if (month == 1) fajrTime = '05:50';
    else if (month == 2) fajrTime = '05:50';
    else if (month == 3) {
      if (day <= 15) fajrTime = '05:35';
      else fajrTime = '05:20';
    }
    else if (month == 4) {
      if (day <= 15) fajrTime = '05:00';
      else fajrTime = '04:45';
    }
    else if (month == 5) fajrTime = '04:35';
    else if (month == 6) fajrTime = '04:35';
    else if (month == 8) fajrTime = '04:50';
    else if (month == 9) fajrTime = '05:05';
    else if (month == 10) fajrTime = '05:15';
    else if (month == 11) fajrTime = '05:35';
    else if (month == 12) fajrTime = '05:50';

    // Dhuhr time (same all year)
    const dhuhrTime = '13:15';

    // Asr times
    String asrTime = '16:25'; // Default
    if (month == 1) asrTime = '16:25';
    else if (month == 2) asrTime = '16:40';
    else if (month == 3 || month == 4) asrTime = '16:50';
    else if (month == 5 || (month == 6 && day <= 22)) asrTime = '17:00';
    else if ((month == 6 && day >= 23) || month == 7 || month == 8) asrTime = '17:15';
    else if (month == 9) asrTime = '16:45';
    else if (month == 10) {
      if (day <= 15) asrTime = '16:25';
      else asrTime = '16:15';
    }
    else if (month == 11 || month == 12) asrTime = '16:05';

    // Maghrib times (approximate based on sunset + 3 minutes)
    String maghribTime = '18:15'; // Default
    if (month == 1) maghribTime = '18:15';
    else if (month == 2) maghribTime = '18:30';
    else if (month == 3) {
      if (day <= 15) maghribTime = '18:45';
      else maghribTime = '19:00';
    }
    else if (month == 4) {
      if (day <= 15) maghribTime = '19:15';
      else maghribTime = '19:30';
    }
    else if (month == 5) maghribTime = '19:45';
    else if (month == 6) maghribTime = '20:00';
    else if (month == 7) maghribTime = '19:45';
    else if (month == 8) maghribTime = '19:15';
    else if (month == 9) {
      if (day <= 15) maghribTime = '18:45';
      else maghribTime = '18:30';
    }
    else if (month == 10) {
      if (day <= 15) maghribTime = '18:15';
      else maghribTime = '18:00';
    }
    else if (month == 11) maghribTime = '17:45';
    else if (month == 12) maghribTime = '17:30';

    // Isha times
    String ishaTime = '19:45'; // Default
    if ((month == 1) || (month == 2) || (month == 3 && day <= 15)) ishaTime = '19:45';
    else if ((month == 3 && day >= 16) || (month == 4 && day <= 15)) ishaTime = '20:00';
    else if ((month == 4 && day >= 16) || month == 5 || month == 6 || month == 7 || (month == 8 && day <= 15)) ishaTime = '20:35';
    else if ((month == 8 && day >= 16) || (month == 9 && day <= 15)) ishaTime = '20:15';
    else if ((month == 9 && day >= 16) || (month == 10 && day <= 15)) ishaTime = '19:35';
    else if ((month == 10 && day >= 16) || month == 11 || month == 12) ishaTime = '19:15';

    return {
      'fajr': fajrTime,
      'dhuhr': dhuhrTime,
      'asr': asrTime,
      'maghrib': maghribTime,
      'isha': ishaTime,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get Maghrib offset in minutes based on cantt name
  int _getMaghribOffset(String city) {
    switch (city) {
      case 'Savar Cantt':
      case 'Dhaka Cantt':
      case 'Kumilla Cantt':
        return 13;
      case 'Rangpur Cantt':
      case 'Jashore Cantt':
      case 'Bogra Cantt':
        return 10;
      default:
        return 7;
    }
  }

  /// Calculate Maghrib jamaat time from prayer time with cantt-specific offset
  String _calculateMaghribJamaatTime() {
    // Get prayer times for the selected date and city
    final coords = Coordinates(23.8376, 90.2820); // Default coordinates
    final params = CalculationMethod.muslimWorldLeague();
    params.madhab = Madhab.hanafi; // Default to Hanafi
    
    final prayerTimes = PrayerTimes(
      coordinates: coords,
      date: _selectedDate,
      calculationParameters: params,
      precision: true,
    );
    
    final maghribPrayerTime = prayerTimes.maghrib;
    if (maghribPrayerTime != null) {
      final offset = _getMaghribOffset(_selectedCity);
      
      // Convert to local time before adding offset
      final localMaghribTime = maghribPrayerTime.toLocal();
      final maghribJamaatTime = localMaghribTime.add(Duration(minutes: offset));
      
      return DateFormat('HH:mm').format(maghribJamaatTime);
    }
    return '';
  }

  /// Calculate Maghrib time from sunset time (3 minutes after sunset)
  String _calculateMaghribFromSunset(String sunsetTime) {
    try {
      final sunset = DateTime.parse('2000-01-01 $sunsetTime:00');
      final maghrib = sunset.add(const Duration(minutes: 3));
      return '${maghrib.hour.toString().padLeft(2, '0')}:${maghrib.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return sunsetTime; // Return original time if parsing fails
    }
  }

  /// Parse date from various formats
  DateTime? _parseDate(String dateString) {
    
    try {
      // Try ISO format first (YYYY-MM-DD)
      final result = DateTime.parse(dateString);
      return result;
    } catch (e) {
      // Try DD-MM-YYYY format (13-01-2025)
      if (dateString.contains('-') && dateString.split('-').length == 3) {
        final parts = dateString.split('-');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (day != null && month != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }
      
      // Try DD/MM/YYYY format (8/1/2025)
      if (dateString.contains('/') && dateString.split('/').length == 3) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (day != null && month != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }
      
      // Try MM/DD/YYYY format (1/8/2025)
      if (dateString.contains('/') && dateString.split('/').length == 3) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          final month = int.tryParse(parts[0]);
          final day = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (month != null && day != null && year != null && month <= 12) {
            return DateTime(year, month, day);
          }
        }
      }
      
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        title: const Text('Admin Jamaat Panel'),
        centerTitle: true,
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: _tabController != null ? TabBar(
          controller: _tabController!,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.edit),
              text: 'Manual Data Entry',
            ),
            Tab(
              icon: Icon(Icons.upload_file),
              text: 'Bulk Data Entry',
            ),
          ],
        ) : null,
      ),
      body: _tabController != null ? TabBarView(
        controller: _tabController!,
        children: [
          // Manual Data Entry Tab
          _buildManualDataEntryTab(),
          // Bulk Data Entry Tab
          _buildBulkDataEntryTab(),
        ],
      ) : const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildManualDataEntryTab() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // City and Date Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_city, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'Select Cantt Name and Date',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCity,
                                decoration: const InputDecoration(
                                  labelText: 'Cantt Name',
                                  border: OutlineInputBorder(),
                                ),
                                items: AppConstants.canttNames.map((city) {
                                  return DropdownMenuItem(value: city, child: Text(city));
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedCity = value);
                                    _loadJamaatTimes();
                                    // Auto-calculate Maghrib when city changes
                                    if (_jamaatControllers['Maghrib'] != null) {
                                      final calculatedMaghrib = _calculateMaghribJamaatTime();
                                      _jamaatControllers['Maghrib']!.text = calculatedMaghrib;
                                    }
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (date != null) {
                                    setState(() => _selectedDate = date);
                                    _loadJamaatTimes();
                                    // Auto-calculate Maghrib when date changes
                                    if (_jamaatControllers['Maghrib'] != null) {
                                      final calculatedMaghrib = _calculateMaghribJamaatTime();
                                      _jamaatControllers['Maghrib']!.text = calculatedMaghrib;
                                    }
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Date',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(_formatDate(_selectedDate)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Jamaat Times Display Section (from profile screen)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text(
                              'Jamaat Times',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 40),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Jamaat Times:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final p in _prayers)
                          Row(
                            children: [
                              Expanded(child: Text(p)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _jamaatControllers[p],
                                  decoration: const InputDecoration(
                                    labelText: 'Time',
                                  ),
                                  enabled: _editingPrayer == p,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: (_adminLoading || _editingPrayer != null && _editingPrayer != p)
                                    ? null
                                    : () {
                                        setState(() {
                                          _editingPrayer = p;
                                        });
                                      },
                                child: const Text('Edit'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: (_adminLoading || _editingPrayer != p)
                                    ? null
                                    : () async {
                                        final input = _jamaatControllers[p]?.text.trim() ?? '';
                                        if (input.isEmpty) {
                                          setState(() {
                                            _adminMsg = 'Please enter a time for $p';
                                          });
                                          return;
                                        }
                                        DateTime? parsed;
                                        try {
                                          parsed = DateFormat('HH:mm').parseStrict(input);
                                        } catch (_) {
                                          try {
                                            parsed = DateFormat('hh:mm a').parseStrict(input);
                                          } catch (_) {}
                                        }
                                        if (parsed == null) {
                                          setState(() {
                                            _adminMsg = 'Invalid time format for $p. Use HH:mm or hh:mm AM/PM.';
                                          });
                                          return;
                                        }
                                        final formatted = DateFormat('HH:mm').format(parsed);
                                        setState(() {
                                          _adminLoading = true;
                                          _adminMsg = null;
                                        });
                                        try {
                                          final data = {p.toLowerCase(): formatted};
                                          final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
                                          final cityKey = _selectedCity.toLowerCase().replaceAll(' ', '_');
                                          await FirebaseFirestore.instance
                                              .collection('jamaat_times')
                                              .doc(cityKey)
                                              .collection('daily_times')
                                              .doc(dateString)
                                              .set(data, SetOptions(merge: true));
                                          setState(() {
                                            _adminMsg = '$p time saved successfully!';
                                            _editingPrayer = null;
                                          });
                                        } catch (e) {
                                          setState(() {
                                            _adminMsg = 'Error saving $p time: $e';
                                          });
                                        } finally {
                                          setState(() {
                                            _adminLoading = false;
                                          });
                                        }
                                      },
                                child: _adminLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Save'),
                              ),

                            ],
                          ),
                        const SizedBox(height: 12),
                        if (_adminMsg != null)
                          Text(
                            _adminMsg!,
                            style: const TextStyle(color: Colors.green),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Status Message
                if (_message != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isSuccess ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isSuccess ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),

                // Loading Indicator
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulkDataEntryTab() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bulk Operations Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.upload_file, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Text(
                              'Bulk Data Entry',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // City and Year Selection
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCity,
                                decoration: const InputDecoration(
                                  labelText: 'Cantt Name',
                                  border: OutlineInputBorder(),
                                ),
                                items: AppConstants.canttNames.map((city) {
                                  return DropdownMenuItem(value: city, child: Text(city));
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedCity = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedYear,
                                decoration: const InputDecoration(
                                  labelText: 'Year',
                                  border: OutlineInputBorder(),
                                ),
                                items: List.generate(10, (index) {
                                  final year = DateTime.now().year + index;
                                  return DropdownMenuItem(value: year, child: Text(year.toString()));
                                }),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedYear = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Overwrite Option
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Overwrite Existing'),
                                value: _overwriteExisting,
                                onChanged: (value) {
                                  setState(() => _overwriteExisting = value ?? false);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Bulk Operation Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _importFromCSV,
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Import CSV'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _exportToCSV,
                                icon: const Icon(Icons.download),
                                label: const Text('Export CSV'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _generateYearlyTimes,
                                icon: const Icon(Icons.auto_fix_high),
                                label: const Text('Generate Year'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Savar Cantt Specific Button
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _generateSavarCanttTimes,
                                icon: const Icon(Icons.mosque),
                                label: const Text('Generate Savar Cantt Times'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Instructions
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bulk Operations Instructions:',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                              const SizedBox(height: 8),
                              const Text('• Import CSV: Upload CSV file with jamaat times'),
                              const Text('• CSV Format: Date, Fajr, Dhuhr, Asr, Sunset/Maghrib, Isha'),
                              const Text('• Date formats: YYYY-MM-DD, DD-MM-YYYY, DD/MM/YYYY, MM/DD/YYYY'),
                              const Text('• Empty cells are automatically skipped'),
                              const Text('• Sunset times are converted to Maghrib (+3 minutes)'),
                              const Text('• Export CSV: Download current data as CSV'),
                              const Text('• Generate Year: Create default times for entire year'),
                              const Text('• Generate Savar Cantt Times: Create specific times for Savar Cantt'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Status Message
                if (_message != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isSuccess ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isSuccess ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),

                // Loading Indicator
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 