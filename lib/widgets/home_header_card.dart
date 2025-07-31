import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/constants.dart';

class HomeHeaderCard extends StatelessWidget {
  final String? selectedCity;
  final List<String> canttNames;
  final DateTime selectedDate;
  final ValueNotifier<DateTime> timeNotifier;
  final ValueNotifier<Duration> countdownNotifier;
  final String? currentPlaceName;
  final bool isFetchingPlaceName;
  final bool isLoadingJamaat;
  final String? jamaatError;
  final Function(String?) onCityChanged;
  final VoidCallback onLocationPressed;
  final String Function() getCountdownText;

  const HomeHeaderCard({
    super.key,
    required this.selectedCity,
    required this.canttNames,
    required this.selectedDate,
    required this.timeNotifier,
    required this.countdownNotifier,
    required this.currentPlaceName,
    required this.isFetchingPlaceName,
    required this.isLoadingJamaat,
    required this.jamaatError,
    required this.onCityChanged,
    required this.onLocationPressed,
    required this.getCountdownText,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, d MMM, yyyy').format(selectedDate);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCardWidth = constraints.maxWidth < 500
            ? constraints.maxWidth
            : 500.0;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth),
            child: Card(
              elevation: 4,
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth < 400 ? 8.0 : 16.0,
                  vertical: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Your Mosque at: '),
                        DropdownButton<String>(
                          value: selectedCity,
                          items: canttNames.map((cantt) {
                            return DropdownMenuItem<String>(
                              value: cantt,
                              child: Text(cantt),
                            );
                          }).toList(),
                          onChanged: onCityChanged,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateStr,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: ValueListenableBuilder<DateTime>(
                                valueListenable: timeNotifier,
                                builder: (context, time, child) {
                                  final timeStr = DateFormat('HH:mm').format(time);
                                  return Text(
                                    timeStr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Jamaat times status
                    if (isLoadingJamaat)
                      const Row(
                        children: [
                          SizedBox(width: 16),
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading jamaat times...', 
                               style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    if (jamaatError != null)
                      Row(
                        children: [
                          const SizedBox(width: 16),
                          const Icon(Icons.error, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              jamaatError!,
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 24.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: ValueListenableBuilder<Duration>(
                                valueListenable: countdownNotifier,
                                builder: (context, countdown, child) {
                                  return Text(
                                    getCountdownText(),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1B5E20),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: onLocationPressed,
                        ),
                        Expanded(
                          child: currentPlaceName != null
                              ? SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    currentPlaceName!,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    overflow: TextOverflow.visible,
                                  ),
                                )
                              : isFetchingPlaceName
                                  ? const Padding(
                                      padding: EdgeInsets.only(left: 8.0),
                                      child: SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                        ),
                      ],
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