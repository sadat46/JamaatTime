import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../services/jamaat_service.dart';
import '../services/location_config_service.dart';
import '../services/prayer_time_engine.dart';
import '../services/prayer_aux_calculator.dart';
import '../models/location_config.dart';
import '../core/constants.dart';
import '../core/locale_text.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';

List<String> adminBulkInstructionLines(Locale locale) {
  final isEnglish = locale.languageCode == 'en';
  if (isEnglish) {
    return const [
      '• Import CSV: Upload CSV file with jamaat times',
      '• CSV Format: Date, Fajr, Dhuhr, Asr, Sunset/Maghrib, Isha',
      '• Date formats: YYYY-MM-DD, DD-MM-YYYY, DD/MM/YYYY, MM/DD/YYYY',
      '• Empty cells are automatically skipped',
      '• Sunset times are converted to Maghrib (+3 minutes)',
      '• Export CSV: Download current data as CSV',
      '• Generate Year: Create default times for entire year',
      '• Generate Savar Cantt Times: Create specific times for Savar Cantt',
    ];
  }

  return const [
    '• Import CSV: জামাতের সময়সহ CSV ফাইল আপলোড করুন',
    '• CSV Format: Date, Fajr, Dhuhr, Asr, Sunset/Maghrib, Isha',
    '• Date formats: YYYY-MM-DD, DD-MM-YYYY, DD/MM/YYYY, MM/DD/YYYY',
    '• ফাঁকা সেল স্বয়ংক্রিয়ভাবে বাদ দেওয়া হয়',
    '• Sunset সময় স্বয়ংক্রিয়ভাবে Maghrib এ রূপান্তর হয় (+3 minutes)',
    '• Export CSV: বর্তমান ডেটা CSV হিসেবে ডাউনলোড করুন',
    '• Generate Year: পুরো বছরের ডিফল্ট সময় তৈরি করুন',
    '• Generate Savar Cantt Times: সাভার ক্যান্টনমেন্টের নির্দিষ্ট সময় তৈরি করুন',
  ];
}

class AdminJamaatPanel extends StatefulWidget {
  const AdminJamaatPanel({super.key});

  @override
  State<AdminJamaatPanel> createState() => _AdminJamaatPanelState();
}

class _AdminJamaatPanelState extends State<AdminJamaatPanel>
    with SingleTickerProviderStateMixin {
  final JamaatService _jamaatService = JamaatService();
  final LocationConfigService _locationConfigService = LocationConfigService();
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
        if (!times.containsKey('maghrib') ||
            times['maghrib'] == null ||
            times['maghrib'] == '-') {
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
        _adminMsg = context.tr(
          bn: 'জামাতের সময় লোড করতে সমস্যা: $e',
          en: 'Error loading jamaat times: $e',
        );
      });
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
            _message = context.tr(
              bn: 'CSV ফাইলে কমপক্ষে একটি হেডার এবং একটি ডেটা সারি থাকতে হবে',
              en: 'CSV file must have at least a header and one data row',
            );
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
          } else if (column.contains('fajr')) {
            fajrIndex = i;
          } else if (column.contains('dhuhr') || column.contains('zuhr')) {
            dhuhrIndex = i;
          } else if (column.contains('asr')) {
            asrIndex = i;
          } else if (column.contains('maghrib') || column.contains('magrib')) {
            maghribIndex = i;
          } else if (column.contains('sunset')) {
            sunsetIndex = i;
          } else if (column.contains('isha')) {
            ishaIndex = i;
          }
        }

        if (dateIndex == -1) {
          setState(() {
            _message = context.tr(
              bn: 'CSV ফাইলে Date কলাম থাকতে হবে',
              en: 'CSV must contain a Date column',
            );
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
            if (fajrIndex >= 0 &&
                fajrIndex < row.length &&
                row[fajrIndex] != null &&
                row[fajrIndex].toString().trim().isNotEmpty) {
              times['fajr'] = row[fajrIndex].toString().trim();
            }

            if (dhuhrIndex >= 0 &&
                dhuhrIndex < row.length &&
                row[dhuhrIndex] != null &&
                row[dhuhrIndex].toString().trim().isNotEmpty) {
              times['dhuhr'] = row[dhuhrIndex].toString().trim();
            }

            if (asrIndex >= 0 &&
                asrIndex < row.length &&
                row[asrIndex] != null &&
                row[asrIndex].toString().trim().isNotEmpty) {
              times['asr'] = row[asrIndex].toString().trim();
            }

            // Handle Maghrib time - check if we have sunset time and calculate Maghrib
            if (sunsetIndex >= 0 &&
                sunsetIndex < row.length &&
                row[sunsetIndex] != null &&
                row[sunsetIndex].toString().trim().isNotEmpty) {
              final sunsetTime = row[sunsetIndex].toString().trim();
              times['maghrib'] = _calculateMaghribFromSunset(sunsetTime);
            } else if (maghribIndex >= 0 &&
                maghribIndex < row.length &&
                row[maghribIndex] != null &&
                row[maghribIndex].toString().trim().isNotEmpty) {
              times['maghrib'] = row[maghribIndex].toString().trim();
            }

            if (ishaIndex >= 0 &&
                ishaIndex < row.length &&
                row[ishaIndex] != null &&
                row[ishaIndex].toString().trim().isNotEmpty) {
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
          _message =
              '${context.tr(bn: 'CSV থেকে সফলভাবে ইমপোর্ট হয়েছে', en: 'Successfully imported from CSV')} '
              '$importedCount ${context.tr(bn: 'টি রেকর্ড। পাওয়া কলাম:', en: 'records. Columns found:')} '
              '${header.join(', ')}';
          _isSuccess = true;
        });
      }
    } catch (e) {
      setState(() {
        _message = context.tr(
          bn: 'CSV ইমপোর্ট করতে সমস্যা: $e',
          en: 'Error importing CSV: $e',
        );
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

      while (currentDate.isBefore(endDate) ||
          currentDate.isAtSameMomentAs(endDate)) {
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
        _message =
            '${context.tr(bn: 'CSV ডেটা প্রস্তুত', en: 'CSV data prepared')} $_selectedCity ($_selectedYear). '
            '${context.tr(bn: 'মোট ডেটা:', en: 'Data:')} ${csvData.length - 1} ${context.tr(bn: 'দিন', en: 'days')}';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _message = context.tr(
          bn: 'CSV এক্সপোর্ট করতে সমস্যা: $e',
          en: 'Error exporting CSV: $e',
        );
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

      while (currentDate.isBefore(endDate) ||
          currentDate.isAtSameMomentAs(endDate)) {
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
        _message =
            '${context.tr(bn: 'জামাতের সময় তৈরি হয়েছে', en: 'Generated')} $generatedCount '
            '${context.tr(bn: 'দিনের জন্য', en: 'days of jamaat times for')} $_selectedCity ($_selectedYear)';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _message = context.tr(
          bn: 'বার্ষিক সময় তৈরি করতে সমস্যা: $e',
          en: 'Error generating yearly times: $e',
        );
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

      while (currentDate.isBefore(endDate) ||
          currentDate.isAtSameMomentAs(endDate)) {
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
        _message =
            '${context.tr(bn: 'সাভার ক্যান্টনমেন্টের জামাতের সময় তৈরি হয়েছে', en: 'Generated Savar Cantt jamaat times')} '
            '$generatedCount ${context.tr(bn: 'দিনের জন্য', en: 'days for')} $_selectedYear';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _message = context.tr(
          bn: 'সাভার ক্যান্টনমেন্ট সময় তৈরি করতে সমস্যা: $e',
          en: 'Error generating Savar Cantt times: $e',
        );
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
    if (month == 1) {
      fajrTime = '05:50';
    } else if (month == 2) {
      fajrTime = '05:50';
    } else if (month == 3) {
      if (day <= 15) {
        fajrTime = '05:35';
      } else {
        fajrTime = '05:20';
      }
    } else if (month == 4) {
      if (day <= 15) {
        fajrTime = '05:00';
      } else {
        fajrTime = '04:45';
      }
    } else if (month == 5) {
      fajrTime = '04:35';
    } else if (month == 6) {
      fajrTime = '04:35';
    } else if (month == 8) {
      fajrTime = '04:50';
    } else if (month == 9) {
      fajrTime = '05:05';
    } else if (month == 10) {
      fajrTime = '05:15';
    } else if (month == 11) {
      fajrTime = '05:35';
    } else if (month == 12) {
      fajrTime = '05:50';
    }

    // Dhuhr time (same all year)
    const dhuhrTime = '13:15';

    // Asr times
    String asrTime = '16:25'; // Default
    if (month == 1) {
      asrTime = '16:25';
    } else if (month == 2) {
      asrTime = '16:40';
    } else if (month == 3 || month == 4) {
      asrTime = '16:50';
    } else if (month == 5 || (month == 6 && day <= 22)) {
      asrTime = '17:00';
    } else if ((month == 6 && day >= 23) || month == 7 || month == 8) {
      asrTime = '17:15';
    } else if (month == 9) {
      asrTime = '16:45';
    } else if (month == 10) {
      if (day <= 15) {
        asrTime = '16:25';
      } else {
        asrTime = '16:15';
      }
    } else if (month == 11 || month == 12) {
      asrTime = '16:05';
    }

    // Maghrib times (approximate based on sunset + 3 minutes)
    String maghribTime = '18:15'; // Default
    if (month == 1) {
      maghribTime = '18:15';
    } else if (month == 2) {
      maghribTime = '18:30';
    } else if (month == 3) {
      if (day <= 15) {
        maghribTime = '18:45';
      } else {
        maghribTime = '19:00';
      }
    } else if (month == 4) {
      if (day <= 15) {
        maghribTime = '19:15';
      } else {
        maghribTime = '19:30';
      }
    } else if (month == 5) {
      maghribTime = '19:45';
    } else if (month == 6) {
      maghribTime = '20:00';
    } else if (month == 7) {
      maghribTime = '19:45';
    } else if (month == 8) {
      maghribTime = '19:15';
    } else if (month == 9) {
      if (day <= 15) {
        maghribTime = '18:45';
      } else {
        maghribTime = '18:30';
      }
    } else if (month == 10) {
      if (day <= 15) {
        maghribTime = '18:15';
      } else {
        maghribTime = '18:00';
      }
    } else if (month == 11) {
      maghribTime = '17:45';
    } else if (month == 12) {
      maghribTime = '17:30';
    }

    // Isha times
    String ishaTime = '19:45'; // Default
    if ((month == 1) || (month == 2) || (month == 3 && day <= 15)) {
      ishaTime = '19:45';
    } else if ((month == 3 && day >= 16) || (month == 4 && day <= 15)) {
      ishaTime = '20:00';
    } else if ((month == 4 && day >= 16) ||
        month == 5 ||
        month == 6 ||
        month == 7 ||
        (month == 8 && day <= 15)) {
      ishaTime = '20:35';
    } else if ((month == 8 && day >= 16) || (month == 9 && day <= 15)) {
      ishaTime = '20:15';
    } else if ((month == 9 && day >= 16) || (month == 10 && day <= 15)) {
      ishaTime = '19:35';
    } else if ((month == 10 && day >= 16) || month == 11 || month == 12) {
      ishaTime = '19:15';
    }

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

  /// Compute Maghrib jamaat string for the selected city/date, using the
  /// same LocationConfig-driven pipeline as the home screen.
  String _calculateMaghribJamaatTime() {
    final LocationConfig config = _locationConfigService.getConfigForCity(
      _selectedCity,
    );
    final params = PrayerTimeEngine.instance.getCalculationParametersForConfig(
      config,
    );
    final prayerTimes = PrayerTimeEngine.instance.calculatePrayerTimes(
      coordinates: Coordinates(config.latitude, config.longitude),
      date: _selectedDate,
      parameters: params,
    );
    final result = PrayerAuxCalculator.instance.calculateMaghribJamaatTime(
      maghribPrayerTime: prayerTimes.maghrib,
      selectedCity: _selectedCity,
    );
    return result == '-' ? '' : result;
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.tr(bn: 'অ্যাডমিন জামাত প্যানেল', en: 'Admin Jamaat Panel')),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor:
            Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
        elevation: 2,
        bottom: _tabController != null
            ? TabBar(
                controller: _tabController!,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.edit),
                    text: context.tr(bn: 'ম্যানুয়াল এন্ট্রি', en: 'Manual Data Entry'),
                  ),
                  Tab(
                    icon: const Icon(Icons.upload_file),
                    text: context.tr(bn: 'বাল্ক এন্ট্রি', en: 'Bulk Data Entry'),
                  ),
                ],
              )
            : null,
      ),
      body: _tabController != null
          ? TabBarView(
              controller: _tabController!,
              children: [
                // Manual Data Entry Tab
                _buildManualDataEntryTab(),
                // Bulk Data Entry Tab
                _buildBulkDataEntryTab(),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color color,
    required String title,
    required bool isCompact,
  }) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCompact ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  DropdownButtonFormField<String> _buildCityDropdown({
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: _selectedCity,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.tr(bn: 'ক্যান্টনমেন্ট', en: 'Cantt Name'),
        border: const OutlineInputBorder(),
      ),
      selectedItemBuilder: (context) {
        return AppConstants.canttNames.map((city) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(city, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }).toList();
      },
      items: AppConstants.canttNames.map((city) {
        return DropdownMenuItem(
          value: city,
          child: Text(city, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateSelectorField() {
    return InkWell(
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
        decoration: InputDecoration(
          labelText: context.tr(bn: 'তারিখ', en: 'Date'),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          _formatDate(_selectedDate),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _savePrayerTime(String prayer) async {
    final input = _jamaatControllers[prayer]?.text.trim() ?? '';
    if (input.isEmpty) {
      setState(() {
        _adminMsg = context.tr(
          bn: '$prayer এর জন্য সময় দিন',
          en: 'Please enter a time for $prayer',
        );
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
        _adminMsg = context.tr(
          bn: '$prayer এর সময় ফরম্যাট ভুল। HH:mm বা hh:mm AM/PM ব্যবহার করুন।',
          en: 'Invalid time format for $prayer. Use HH:mm or hh:mm AM/PM.',
        );
      });
      return;
    }

    final formatted = DateFormat('HH:mm').format(parsed);
    setState(() {
      _adminLoading = true;
      _adminMsg = null;
    });

    try {
      await _jamaatService.updateSingleJamaatTime(
        city: _selectedCity,
        date: _selectedDate,
        prayerName: prayer,
        time: formatted,
      );
      setState(() {
        _adminMsg = context.tr(
          bn: '$prayer এর সময় সফলভাবে সংরক্ষণ করা হয়েছে!',
          en: '$prayer time saved successfully!',
        );
        _editingPrayer = null;
      });
    } catch (e) {
      setState(() {
        _adminMsg = context.tr(
          bn: '$prayer এর সময় সংরক্ষণে সমস্যা: $e',
          en: 'Error saving $prayer time: $e',
        );
      });
    } finally {
      setState(() {
        _adminLoading = false;
      });
    }
  }

  Widget _buildPrayerRow(String prayer, {required bool isCompact}) {
    final isEditingPrayer = _editingPrayer == prayer;
    final canEdit =
        !_adminLoading && (_editingPrayer == null || isEditingPrayer);
    final canSave = !_adminLoading && isEditingPrayer;

    final labelWidth = isCompact ? 58.0 : 72.0;
    final actionSize = isCompact ? 36.0 : 40.0;
    final spacing = isCompact ? 4.0 : 8.0;

    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 8 : 10),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(prayer, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: TextField(
              controller: _jamaatControllers[prayer],
              decoration: InputDecoration(
                labelText: context.tr(bn: 'সময়', en: 'Time'),
                isDense: true,
              ),
              enabled: isEditingPrayer,
            ),
          ),
          SizedBox(width: spacing),
          Tooltip(
            message: 'Edit $prayer',
            child: SizedBox(
              width: actionSize,
              height: actionSize,
              child: ElevatedButton(
                onPressed: canEdit
                    ? () {
                        setState(() {
                          _editingPrayer = prayer;
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(actionSize, actionSize),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Icon(Icons.edit, size: 18),
              ),
            ),
          ),
          SizedBox(width: isCompact ? 4 : 6),
          Tooltip(
            message: 'Save $prayer',
            child: SizedBox(
              width: actionSize,
              height: actionSize,
              child: ElevatedButton(
                onPressed: canSave
                    ? () async {
                        await _savePrayerTime(prayer);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(actionSize, actionSize),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: _adminLoading && isEditingPrayer
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    double verticalPadding = 12,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: 12,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildManualDataEntryTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;
        final isCompact = constraints.maxWidth < 430;
        final outerPadding = constraints.maxWidth < 430 ? 12.0 : 24.0;
        final cardPadding = isCompact ? 12.0 : 16.0;
        final fieldSpacing = isCompact ? 12.0 : 16.0;

        final cityDropdown = _buildCityDropdown(
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
        );

        final dateSelector = _buildDateSelectorField();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(outerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // City and Date Selection
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              icon: Icons.location_city,
                              color: Colors.blue,
                              title: context.tr(
                                bn: 'ক্যান্টনমেন্ট ও তারিখ নির্বাচন',
                                en: 'Select Cantt Name and Date',
                              ),
                              isCompact: isCompact,
                            ),
                            const SizedBox(height: 16),
                            if (isNarrow) ...[
                              cityDropdown,
                              SizedBox(height: fieldSpacing),
                              dateSelector,
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(child: cityDropdown),
                                  SizedBox(width: fieldSpacing),
                                  Expanded(child: dateSelector),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Jamaat Times Display Section
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              icon: Icons.schedule,
                              color: Colors.green,
                              title: context.tr(bn: 'জামাতের সময়', en: 'Jamaat Times'),
                              isCompact: isCompact,
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 40),
                            Text(
                              context.tr(bn: 'জামাতের সময়:', en: 'Jamaat Times:'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            for (final p in _prayers)
                              _buildPrayerRow(p, isCompact: isCompact),
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
                          color: _isSuccess
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isSuccess ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _isSuccess
                                ? Colors.green.shade800
                                : Colors.red.shade800,
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
      },
    );
  }

  Widget _buildBulkDataEntryTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;
        final isCompact = constraints.maxWidth < 430;
        final outerPadding = constraints.maxWidth < 430 ? 12.0 : 24.0;
        final cardPadding = isCompact ? 12.0 : 16.0;
        final fieldSpacing = isCompact ? 12.0 : 16.0;

        final cityDropdown = _buildCityDropdown(
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCity = value);
            }
          },
        );

        final yearDropdown = DropdownButtonFormField<int>(
          // ignore: deprecated_member_use
          value: _selectedYear,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.tr(bn: 'বছর', en: 'Year'),
            border: const OutlineInputBorder(),
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
        );

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(outerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bulk Operations Section
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              icon: Icons.upload_file,
                              color: Colors.orange,
                              title: context.tr(bn: 'বাল্ক ডেটা এন্ট্রি', en: 'Bulk Data Entry'),
                              isCompact: isCompact,
                            ),
                            const SizedBox(height: 16),

                            // City and Year Selection
                            if (isNarrow) ...[
                              cityDropdown,
                              SizedBox(height: fieldSpacing),
                              yearDropdown,
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(child: cityDropdown),
                                  SizedBox(width: fieldSpacing),
                                  Expanded(child: yearDropdown),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),

                            // Overwrite Option
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                context.tr(bn: 'আগের ডেটা ওভাররাইট করুন', en: 'Overwrite Existing'),
                              ),
                              value: _overwriteExisting,
                              onChanged: (value) {
                                setState(
                                  () => _overwriteExisting = value ?? false,
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Bulk Operation Buttons
                            LayoutBuilder(
                              builder: (context, buttonConstraints) {
                                const spacing = 8.0;
                                final maxWidth = buttonConstraints.maxWidth;
                                final buttonWidth = maxWidth < 430
                                    ? maxWidth
                                    : maxWidth < 720
                                    ? (maxWidth - spacing) / 2
                                    : (maxWidth - (spacing * 2)) / 3;

                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: [
                                    SizedBox(
                                      width: buttonWidth,
                                      child: _buildBulkActionButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _importFromCSV,
                                        icon: Icons.upload_file,
                                        label: context.tr(bn: 'CSV ইমপোর্ট', en: 'Import CSV'),
                                        backgroundColor: Colors.blue,
                                      ),
                                    ),
                                    SizedBox(
                                      width: buttonWidth,
                                      child: _buildBulkActionButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _exportToCSV,
                                        icon: Icons.download,
                                        label: context.tr(bn: 'CSV এক্সপোর্ট', en: 'Export CSV'),
                                        backgroundColor: Colors.purple,
                                      ),
                                    ),
                                    SizedBox(
                                      width: buttonWidth,
                                      child: _buildBulkActionButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _generateYearlyTimes,
                                        icon: Icons.auto_fix_high,
                                        label: context.tr(bn: 'বছরের ডেটা তৈরি', en: 'Generate Year'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Savar Cantt Specific Button
                            SizedBox(
                              width: double.infinity,
                              child: _buildBulkActionButton(
                                onPressed: _isLoading
                                    ? null
                                    : _generateSavarCanttTimes,
                                icon: Icons.mosque,
                                label: context.tr(
                                  bn: 'সাভার ক্যান্টনমেন্ট সময় তৈরি',
                                  en: 'Generate Savar Cantt Times',
                                ),
                                backgroundColor: Colors.green,
                                verticalPadding: isCompact ? 12 : 16,
                              ),
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
                                  Text(
                                    context.tr(
                                      bn: 'বাল্ক অপারেশন নির্দেশনা:',
                                      en: 'Bulk Operations Instructions:',
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...adminBulkInstructionLines(
                                    Localizations.localeOf(context),
                                  ).map(Text.new),
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
                          color: _isSuccess
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isSuccess ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _isSuccess
                                ? Colors.green.shade800
                                : Colors.red.shade800,
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
      },
    );
  }
}
