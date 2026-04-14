import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const Color _brandGreen = Color(0xFF388E3C);
  static const double _cardRadius = 18;
  static const double _desktopBreakpoint = 860;

  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _userStats;
  final Map<String, String> _pendingRoles = {};
  final Set<String> _savingUsers = {};

  bool _isLoading = true;
  bool _isSuperAdmin = false;
  bool _isMigrating = false;
  bool _advancedExpanded = false;
  String _roleFilter = 'all';
  String _searchQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkSuperAdminAndLoadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkSuperAdminAndLoadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final isSuperAdmin = await _authService.isSuperAdmin();
      if (!mounted) return;

      if (!isSuperAdmin) {
        setState(() {
          _isSuperAdmin = false;
          _isLoading = false;
          _error = 'Only superadmins can access user management.';
        });
        return;
      }

      setState(() {
        _isSuperAdmin = true;
      });

      await _fetchUsersAndStats(showLoader: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSuperAdmin = false;
        _isLoading = false;
        _error = 'Error checking permissions: $e';
      });
    }
  }

  Future<void> _fetchUsersAndStats({bool showLoader = false}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final users = await _authService.getAllUsers();
      final stats = await _authService.getUserStats();
      if (!mounted) return;

      setState(() {
        _users = users;
        _userStats = stats;
        _isLoading = false;
        _error = null;

        final validIds = users
            .map((user) => user['uid']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        _pendingRoles.removeWhere((uid, _) => !validIds.contains(uid));
        _savingUsers.removeWhere((uid) => !validIds.contains(uid));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Error loading users: $e';
      });
    }
  }

  Future<void> _migrateExistingUsers() async {
    if (_isMigrating) return;

    setState(() {
      _isMigrating = true;
    });

    try {
      await _authService.migrateExistingUsers();
      await _fetchUsersAndStats(showLoader: false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Users synced successfully.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMigrating = false;
        });
      }
    }
  }

  Future<void> _showManualMigrationDialog() async {
    final userIdController = TextEditingController();
    final emailController = TextEditingController();
    var selectedRole = 'user';
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final userId = userIdController.text.trim();
              final email = emailController.text.trim();

              if (userId.isEmpty || email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in UID and email.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setDialogState(() {
                isSubmitting = true;
              });

              try {
                await _authService.addUserToFirestore(
                  userId,
                  email,
                  selectedRole,
                );
                if (!mounted) return;

                // ignore: use_build_context_synchronously
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('User $email added successfully.'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );

                await _fetchUsersAndStats(showLoader: false);
              } catch (e) {
                setDialogState(() {
                  isSubmitting = false;
                });
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Error adding user: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Add Missing User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use this when an authenticated account is not present in Firestore.\n\n'
                      'Firebase Console: Authentication > Users > Copy UID',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey[700],
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: userIdController,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'User ID (UID)',
                        hintText: 'e.g. abc123def456',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'e.g. user@example.com',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('User'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                            DropdownMenuItem(
                              value: 'superadmin',
                              child: Text('Superadmin'),
                            ),
                          ],
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() {
                                    selectedRole = value;
                                  });
                                },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add User'),
                ),
              ],
            );
          },
        );
      },
    );

    userIdController.dispose();
    emailController.dispose();
  }

  Future<void> _saveRoleChange(Map<String, dynamic> user) async {
    final userId = user['uid']?.toString();
    if (userId == null || userId.isEmpty) return;
    if (_savingUsers.contains(userId)) return;

    final currentRole = _normalizeRole(user['role']);
    final targetRoleString = _pendingRoles[userId];

    if (targetRoleString == null || targetRoleString == currentRole) return;

    final targetRole = targetRoleString == 'admin'
        ? UserRole.admin
        : UserRole.user;

    setState(() {
      _savingUsers.add(userId);
    });

    try {
      await _authService.updateUserRole(userId, targetRole);
      if (!mounted) return;

      setState(() {
        user['role'] = targetRoleString;
        _pendingRoles.remove(userId);
      });

      final email = user['email']?.toString() ?? 'user';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated $email to ${_displayRole(targetRoleString)}.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      await _fetchUsersAndStats(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating role: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingUsers.remove(userId);
        });
      }
    }
  }

  String _normalizeRole(dynamic rawRole) {
    final role = rawRole?.toString().toLowerCase().trim() ?? 'user';
    if (role == 'admin' || role == 'superadmin' || role == 'user') {
      return role;
    }
    return 'user';
  }

  String _displayRole(String role) {
    switch (role) {
      case 'superadmin':
        return 'Superadmin';
      case 'admin':
        return 'Admin';
      default:
        return 'User';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'superadmin':
        return const Color(0xFFC62828);
      case 'admin':
        return const Color(0xFFEF6C00);
      default:
        return const Color(0xFF1565C0);
    }
  }

  bool _isCurrentUser(Map<String, dynamic> user) {
    return user['uid']?.toString() == _authService.currentUser?.uid;
  }

  bool _isProtectedUser(Map<String, dynamic> user) {
    return _isCurrentUser(user) || _normalizeRole(user['role']) == 'superadmin';
  }

  bool _hasPendingRoleChange(Map<String, dynamic> user) {
    final userId = user['uid']?.toString();
    if (userId == null || userId.isEmpty) return false;

    final pending = _pendingRoles[userId];
    if (pending == null) return false;

    return pending != _normalizeRole(user['role']);
  }

  String _effectiveRoleForUser(Map<String, dynamic> user) {
    final userId = user['uid']?.toString();
    if (userId == null || userId.isEmpty) {
      return _normalizeRole(user['role']);
    }
    return _pendingRoles[userId] ?? _normalizeRole(user['role']);
  }

  void _stageRoleChange(Map<String, dynamic> user, String newRole) {
    final userId = user['uid']?.toString();
    if (userId == null || userId.isEmpty) return;

    final currentRole = _normalizeRole(user['role']);

    setState(() {
      if (newRole == currentRole) {
        _pendingRoles.remove(userId);
      } else {
        _pendingRoles[userId] = newRole;
      }
    });
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _users.where((user) {
      final role = _normalizeRole(user['role']);
      final email = (user['email'] ?? '').toString().toLowerCase();

      final matchesSearch = query.isEmpty || email.contains(query);
      final matchesRole = _roleFilter == 'all' || role == _roleFilter;

      return matchesSearch && matchesRole;
    }).toList();

    filtered.sort((a, b) {
      final left = (a['email'] ?? '').toString().toLowerCase();
      final right = (b['email'] ?? '').toString().toLowerCase();
      return left.compareTo(right);
    });

    return filtered;
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(String role, {bool compact = false}) {
    final color = _roleColor(role);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        _displayRole(role).toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 10.5 : 11.5,
        ),
      ),
    );
  }

  Widget _buildCurrentUserChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'YOU',
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_userStats == null) {
      return const SizedBox.shrink();
    }

    final totalUsers = (_userStats!['total_users'] as num?)?.toInt() ?? 0;
    final regularUsers = (_userStats!['users'] as num?)?.toInt() ?? 0;
    final admins = (_userStats!['admins'] as num?)?.toInt() ?? 0;
    final superadmins = (_userStats!['superadmins'] as num?)?.toInt() ?? 0;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF1565C0),
              title: 'User Statistics',
              subtitle: 'At-a-glance account distribution.',
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 560 ? 4 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: crossAxisCount == 4 ? 1.15 : 1.1,
                  children: [
                    _buildStatTile(
                      icon: Icons.people_alt_rounded,
                      label: 'Total Users',
                      value: totalUsers,
                      color: const Color(0xFF1565C0),
                    ),
                    _buildStatTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Regular Users',
                      value: regularUsers,
                      color: const Color(0xFF2E7D32),
                    ),
                    _buildStatTile(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Admins',
                      value: admins,
                      color: const Color(0xFFEF6C00),
                    ),
                    _buildStatTile(
                      icon: Icons.shield_outlined,
                      label: 'Superadmins',
                      value: superadmins,
                      color: const Color(0xFFC62828),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelector(Map<String, dynamic> user, {bool compact = false}) {
    final selectedRole = _effectiveRoleForUser(user);

    return Container(
      height: compact ? 38 : 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedRole == 'admin' ? 'admin' : 'user',
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: const [
            DropdownMenuItem(value: 'user', child: Text('User')),
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
          ],
          onChanged: (value) {
            if (value == null) return;
            _stageRoleChange(user, value);
          },
        ),
      ),
    );
  }

  Widget _buildSaveRoleButton(
    Map<String, dynamic> user, {
    bool compact = false,
  }) {
    final userId = user['uid']?.toString() ?? '';
    final isSaving = _savingUsers.contains(userId);
    final hasPending = _hasPendingRoleChange(user);

    return SizedBox(
      height: compact ? 36 : 40,
      child: ElevatedButton(
        onPressed: hasPending && !isSaving ? () => _saveRoleChange(user) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: compact ? 12 : 12.5,
          ),
        ),
        child: isSaving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(hasPending ? 'Save Role' : 'Saved'),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    final currentRole = _normalizeRole(user['role']);
    final isCurrentUser = _isCurrentUser(user);
    final isProtected = _isProtectedUser(user);
    final hasPending = _hasPendingRoleChange(user);
    final email = user['email']?.toString().trim().isNotEmpty == true
        ? user['email'].toString()
        : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. $email',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    height: 1.3,
                  ),
                ),
              ),
              if (isCurrentUser) ...[
                const SizedBox(width: 8),
                _buildCurrentUserChip(),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildRoleChip(currentRole),
              if (isProtected && !isCurrentUser)
                Text(
                  'Protected',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 12),
          if (isProtected)
            Text(
              isCurrentUser
                  ? 'You cannot change your own role.'
                  : 'Superadmin roles cannot be modified here.',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12.5,
                height: 1.3,
              ),
            )
          else ...[
            Text(
              'New Role',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildRoleSelector(user)),
                const SizedBox(width: 10),
                _buildSaveRoleButton(user),
              ],
            ),
            if (hasPending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.pending_actions_rounded,
                    size: 16,
                    color: Colors.orange[800],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Role changed, not saved.',
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> users) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 22,
        headingRowHeight: 52,
        dataRowMinHeight: 68,
        dataRowMaxHeight: 82,
        columns: const [
          DataColumn(
            numeric: true,
            label: Text('S/N', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          DataColumn(
            label: Text('Email', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          DataColumn(
            label: Text('Role', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          DataColumn(
            label: Text(
              'New Role',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          DataColumn(
            label: Text(
              'Action',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
        rows: users.asMap().entries.map((entry) {
          final index = entry.key;
          final user = entry.value;
          final currentRole = _normalizeRole(user['role']);
          final isCurrentUser = _isCurrentUser(user);
          final isProtected = _isProtectedUser(user);
          final hasPending = _hasPendingRoleChange(user);
          final email = user['email']?.toString().trim().isNotEmpty == true
              ? user['email'].toString()
              : 'Unknown';

          return DataRow(
            cells: [
              DataCell(
                Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DataCell(
                Row(
                  children: [
                    Text(
                      email,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isCurrentUser ? Colors.green[700] : null,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      _buildCurrentUserChip(),
                    ],
                  ],
                ),
              ),
              DataCell(_buildRoleChip(currentRole, compact: true)),
              DataCell(
                isProtected
                    ? Text(
                        isCurrentUser ? 'Current user' : 'Protected',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : SizedBox(
                        width: 130,
                        child: _buildRoleSelector(user, compact: true),
                      ),
              ),
              DataCell(
                isProtected
                    ? Text(
                        isCurrentUser ? 'Locked' : 'Protected',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSaveRoleButton(user, compact: true),
                          if (hasPending)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Unsaved',
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;

        final searchField = TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search by email',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Clear',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _brandGreen, width: 1.4),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 12,
            ),
          ),
        );

        final roleFilter = Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _roleFilter,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Roles')),
                DropdownMenuItem(value: 'user', child: Text('User')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(
                  value: 'superadmin',
                  child: Text('Superadmin'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _roleFilter = value;
                });
              },
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            children: [searchField, const SizedBox(height: 10), roleFilter],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            SizedBox(width: 180, child: roleFilter),
          ],
        );
      },
    );
  }

  Widget _buildUsersSection() {
    final visibleUsers = _filteredUsers;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.group_rounded,
              color: const Color(0xFFEF6C00),
              title: 'All Users',
              subtitle: 'Search accounts and save role changes per user.',
            ),
            const SizedBox(height: 14),
            _buildFilters(),
            const SizedBox(height: 10),
            Text(
              'Showing ${visibleUsers.length} of ${_users.length} users',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (visibleUsers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 32,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _users.isEmpty
                          ? 'No users found.'
                          : 'No users match the current filters.',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                // Mobile-first rendering: cards on small widths, table on wider layouts.
                builder: (context, constraints) {
                  if (constraints.maxWidth >= _desktopBreakpoint) {
                    return _buildDesktopTable(visibleUsers);
                  }

                  return Column(
                    children: [
                      for (var i = 0; i < visibleUsers.length; i++)
                        _buildUserCard(visibleUsers[i], i),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback? onPressed,
    bool isBusy = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _brandGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: _brandGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 36,
            child: OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: _brandGreen,
                side: BorderSide(color: _brandGreen.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isBusy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Card(
      elevation: 1.2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const PageStorageKey('user-management-advanced'),
          initiallyExpanded: _advancedExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _advancedExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF6D4C41).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.build_circle_outlined,
              color: Color(0xFF6D4C41),
              size: 20,
            ),
          ),
          title: const Text(
            'Migration & Recovery',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: Text(
            'Rare maintenance actions for account sync.',
            style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
          ),
          children: [
            _buildAdvancedActionTile(
              icon: Icons.sync_rounded,
              title: 'Sync Users',
              subtitle: 'Populate missing Firestore user records.',
              buttonText: _isMigrating ? 'Syncing...' : 'Sync Users',
              onPressed: _isMigrating ? null : _migrateExistingUsers,
              isBusy: _isMigrating,
            ),
            const SizedBox(height: 10),
            _buildAdvancedActionTile(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Add Missing User',
              subtitle: 'Manually add a user by UID, email, and role.',
              buttonText: 'Add User',
              onPressed: _showManualMigrationDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDeniedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 14),
            Text(
              'Access Denied',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.red[700],
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Only superadmins can access this page.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 62,
              color: Colors.red,
            ),
            const SizedBox(height: 14),
            Text(
              'Could not load user data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.red[700],
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _checkSuperAdminAndLoadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isSuperAdmin) {
      return _buildAccessDeniedState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: () => _fetchUsersAndStats(showLoader: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildStatsSection(),
          const SizedBox(height: 14),
          _buildUsersSection(),
          const SizedBox(height: 14),
          _buildAdvancedSection(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('User Management'),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor:
            Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
        elevation: 2,
        actions: _isSuperAdmin
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh data',
                  onPressed: _checkSuperAdminAndLoadData,
                ),
              ]
            : null,
      ),
      body: _buildBody(),
    );
  }
}
