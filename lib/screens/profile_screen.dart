import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String? _error;
  bool _loading = false;
  bool _showRegister = false;
  String? _preferredCity;
  bool _isAdmin = false;
  final List<String> _prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  final Map<String, TextEditingController> _jamaatControllers = {
    for (var p in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'])
      p: TextEditingController(),
  };
  String _adminCity = 'Savar Cantt';
  bool _adminLoading = false;
  String? _adminMsg;
  final List<String> canttNames = [
    'Kumilla Cantt',
    'Bogra Cantt',
    'Rangpur Cantt',
    'Ramu Cantt',
    'Sylhet Cantt',
    'Jashore Cantt',
    'Savar Cantt',
    'Dhaka Cantt',
    'Chittagong Cantt',
    'Padma Cantt',
  ];
  String? _editingPrayer;

  @override
  void initState() {
    super.initState();
    // Set default city if needed
    if (_preferredCity == null || !canttNames.contains(_preferredCity)) {
      _preferredCity = canttNames.first;
    }
    // Check admin status
    _checkAdmin();
    // Load Jamaat times for the default city
    _loadJamaatTimes();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _jamaatControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await _authService.isAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  Future<void> _loadJamaatTimes() async {
    setState(() {
      _adminLoading = true;
      _adminMsg = null;
    });
    final doc = await FirebaseFirestore.instance
      .collection('jamaat_times')
      .doc(_adminCity.toLowerCase())
      .collection('times')
      .doc('times')
      .get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      for (final p in _prayers) {
        _jamaatControllers[p]?.text = data[p.toLowerCase()]?.toString() ?? '';
      }
    } else {
      for (final p in _prayers) {
        _jamaatControllers[p]?.text = '';
      }
    }
    setState(() {
      _adminLoading = false;
    });
  }



  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.userChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          // Not logged in
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _showRegister ? 'Register' : 'Login',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                if (_showRegister) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                    ),
                    obscureText: true,
                  ),
                ],
                const SizedBox(height: 24),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          try {
                            if (_showRegister) {
                              if (_passwordController.text !=
                                  _confirmPasswordController.text) {
                                setState(() {
                                  _error = 'Passwords do not match';
                                  _loading = false;
                                });
                                return;
                              }
                              await _authService.register(
                                _emailController.text.trim(),
                                _passwordController.text.trim(),
                              );
                            } else {
                              await _authService.signIn(
                                _emailController.text.trim(),
                                _passwordController.text.trim(),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              _error =
                                  "${_showRegister ? 'Registration' : 'Login'} failed: ${e.toString()}";
                            });
                          } finally {
                            setState(() {
                              _loading = false;
                            });
                          }
                        },
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Text(_showRegister ? 'Register' : 'Login'),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _showRegister = !_showRegister;
                            _error = null;
                          });
                        },
                  child: Text(
                    _showRegister
                        ? 'Already have an account? Login'
                        : 'Don\'t have an account? Register',
                  ),
                ),
              ],
            ),
          );
        } else {
          // Logged in
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 16.0,
            ),
            child: Container(
              color: const Color(0xFFE8F5E9), // light green background
            child: SingleChildScrollView(
                child: Card(
                  color: const Color(0xFFC8E6C9), // lighter green card
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 16.0,
                    ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                        const Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                  ),
                  const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Logged in as: ${_isAdmin ? 'Admin' : 'User'}',
                            ),
                  ElevatedButton(
                    onPressed: () async {
                      await _authService.signOut();
                      setState(() {
                        _preferredCity = null;
                        _isAdmin = false;
                      });
                    },
                    child: const Text('Logout'),
                  ),
                          ],
                        ),
                        const SizedBox(height: 24),
                  if (_isAdmin) ...[
                    const Divider(height: 40),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Update Jamaat Time For :',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(
                                  width: 160, // Adjust width as needed
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                      value: _adminCity,
                      items: canttNames.map((cantt) {
                        return DropdownMenuItem<String>(
                          value: cantt,
                                        child: Text(
                                          cantt,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                        );
                      }).toList(),
                      onChanged: (val) {
                                      setState(() {
                                        _adminCity = val!;
                                      });
                        _loadJamaatTimes();
                      },
                    ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._prayers.map(
                            (p) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Card(
                                margin: EdgeInsets.zero,
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 12.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        p,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            SizedBox(
                                              width: 90,
                      child: TextField(
                                                controller:
                                                    _jamaatControllers[p],
                                                decoration:
                                                    const InputDecoration(
                                                      hintText: 'HH:mm',
                                                      border:
                                                          OutlineInputBorder(),
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            vertical: 8,
                                                            horizontal: 8,
                                                          ),
                                                    ),
                                                enabled: _editingPrayer == p,
                                                textAlign: TextAlign.center,
                                                inputFormatters: [
                                                  TimeTextInputFormatter(),
                                                ],
                                                keyboardType:
                                                    TextInputType.number,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                minimumSize: Size(60, 36),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _editingPrayer = p;
                                                });
                                              },
                                              child: const Text('Edit'),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed:
                                                  (_adminLoading ||
                                                      _editingPrayer != p)
                                                  ? null
                                                  : () async {
                                                      final input =
                                                          _jamaatControllers[p]
                                                              ?.text
                                                              .trim() ??
                                                          '';
                                                      DateTime? parsed;
                                                      try {
                                                        parsed = DateFormat(
                                                          'HH:mm',
                                                        ).parseStrict(input);
                                                      } catch (_) {
                                                        try {
                                                          parsed = DateFormat(
                                                            'hh:mm a',
                                                          ).parseStrict(input);
                                                        } catch (_) {}
                                                      }
                                                      if (parsed == null) {
                                                        setState(() {
                                                          _adminMsg =
                                                              'Invalid time format for $p. Use HH:mm or hh:mm AM/PM.';
                                                        });
                                                        return;
                                                      }
                                                      final formatted =
                                                          DateFormat(
                                                            'HH:mm',
                                                          ).format(parsed);
                                                      setState(() {
                                                        _adminLoading = true;
                                                        _adminMsg = null;
                                                      });
                                                      final data = {
                                                        p.toLowerCase():
                                                            formatted,
                                                      };
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection(
                                                            'jamaat_times',
                                                          )
                                                          .doc(
                                                            _adminCity
                                                                .toLowerCase(),
                                                          )
                                                          .collection('times')
                                                          .doc('times')
                                                          .set(
                                                            data,
                                                            SetOptions(
                                                              merge: true,
                                                            ),
                                                          );
                                                      await _loadJamaatTimes();
                                                      setState(() {
                                                        _adminLoading = false;
                                                        _adminMsg =
                                                            '$p time saved!';
                                                        _editingPrayer = null;
                                                      });
                                                    },
                                              child:
                                                  _adminLoading &&
                                                      _editingPrayer == p
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Text('Save'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 12),
                    if (_adminMsg != null)
                            Text(
                              _adminMsg!,
                              style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }
} 

class TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);

    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i == 2) formatted += ':';
      formatted += digits[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
