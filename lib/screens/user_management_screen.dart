import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _userStats;
  bool _isLoading = true;
  String? _error;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkSuperAdminAndLoadData();
  }

  Future<void> _checkSuperAdminAndLoadData() async {
    try {
      final isSuperAdmin = await _authService.isSuperAdmin();
      setState(() {
        _isSuperAdmin = isSuperAdmin;
      });

      if (isSuperAdmin) {
        await _loadUsers();
        await _loadUserStats();
      } else {
        setState(() {
          _error = 'Access denied. Only superadmins can access this page.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error checking permissions: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final users = await _authService.getAllUsers();

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading users: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final stats = await _authService.getUserStats();
      setState(() {
        _userStats = stats;
      });
    } catch (e) {
      // Don't show error for stats, just log it
    }
  }

  Future<void> _migrateExistingUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _authService.migrateExistingUsers();
      
      // Refresh data after migration
      await _loadUsers();
      await _loadUserStats();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User migration completed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error migrating users: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showManualMigrationDialog() async {
    final TextEditingController userIdController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    String selectedRole = 'user';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add User to Firestore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add a user from Firebase Auth to Firestore.\n\n'
              'You can find the User ID in Firebase Console:\n'
              'Authentication → Users → Copy UID',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID (UID)',
                border: OutlineInputBorder(),
                hintText: 'e.g., abc123def456...',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                hintText: 'e.g., user@example.com',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'user', child: Text('User')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'superadmin', child: Text('Superadmin')),
              ],
              onChanged: (value) {
                selectedRole = value ?? 'user';
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = userIdController.text.trim();
              final email = emailController.text.trim();
              
              if (userId.isEmpty || email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              try {
                await _authService.addUserToFirestore(userId, email, selectedRole);

                if (mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop();
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('User $email added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                  
                  // Refresh the user list
                if (mounted) {
                  await _loadUsers();
                  await _loadUserStats();
                }
              } catch (e) {
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Add User'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserRole(String userId, String currentRole, UserRole newRole) async {
    try {
      await _authService.updateUserRole(userId, newRole);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User role updated from $currentRole to ${newRole.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Refresh data
      if (mounted) {
        await _loadUsers();
        await _loadUserStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user role: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Note: This function is currently unused
  /*
  Future<void> _deleteUser(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete user: $email?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.deleteUser(userId);
        
        // Refresh data
        await _loadUsers();
        await _loadUserStats();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User $email deleted successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting user: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
  */

  /// Note: This function is currently unused
  /*
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      if (timestamp is Timestamp) {
        return DateFormat('MMM dd, yyyy HH:mm').format(timestamp.toDate());
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }
  */

  Color _getRoleColor(String role) {
    switch (role) {
      case 'superadmin':
        return Colors.red;
      case 'admin':
        return Colors.orange;
      case 'user':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRoleDropdown(Map<String, dynamic> user) {
    final currentRole = user['role'] ?? 'user';
    final isCurrentUser = user['uid'] == _authService.currentUser?.uid;
    
    if (isCurrentUser) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: Text(
          currentRole.toUpperCase(),
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return DropdownButton<String>(
      value: user['newRole'] ?? currentRole, // Use newRole if set, otherwise currentRole
      underline: Container(),
      style: const TextStyle(fontSize: 14),
      items: const [
        DropdownMenuItem(value: 'user', child: Text('User')),
        DropdownMenuItem(value: 'admin', child: Text('Admin')),
      ],
      onChanged: (newRole) {
        if (newRole != null) {
          setState(() {
            // Store the new role separately from the current role
            user['newRole'] = newRole;
            user['pendingUpdate'] = newRole != currentRole; // Only mark for update if different
          });
        }
      },
    );
  }

  Widget _buildUpdateButton(Map<String, dynamic> user) {
    final isCurrentUser = user['uid'] == _authService.currentUser?.uid;
    final hasPendingUpdate = user['pendingUpdate'] == true;
    
    if (isCurrentUser) {
      return const Text(
        'Current User',
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }

    return ElevatedButton(
      onPressed: hasPendingUpdate ? () => _updateUserRoleFromTable(user) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: hasPendingUpdate ? Colors.blue : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(
        hasPendingUpdate ? 'Save' : 'No Changes',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _updateUserRoleFromTable(Map<String, dynamic> user) async {
    final userId = user['uid'];
    final currentRole = user['role'] ?? 'user';
    final newRoleString = user['newRole'] ?? currentRole;
    // final email = user['email'] ?? 'Unknown'; // Unused variable
    
    try {
      // Convert string role to UserRole enum
      UserRole newRole;
      switch (newRoleString) {
        case 'admin':
          newRole = UserRole.admin;
          break;
        case 'user':
        default:
          newRole = UserRole.user;
          break;
      }
      
      await _updateUserRole(userId, currentRole, newRole);
      
      // Clear the pending update flag and newRole
      setState(() {
        user['pendingUpdate'] = false;
        user['newRole'] = null;
      });
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSuperAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFFE8F5E9),
        appBar: AppBar(
          title: const Text('User Management'),
          centerTitle: true,
          backgroundColor: const Color(0xFF388E3C),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.security,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Only superadmins can access this page.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        title: const Text('User Management'),
        centerTitle: true,
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkSuperAdminAndLoadData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _migrateExistingUsers,
            tooltip: 'Migrate Users',
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showManualMigrationDialog,
            tooltip: 'Add Missing User',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _checkSuperAdminAndLoadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Statistics Card
                      if (_userStats != null) ...[
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.analytics, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(
                                      'User Statistics',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  alignment: WrapAlignment.spaceEvenly,
                                  children: [
                                    _buildStatCard('Total Users', _userStats!['total_users'].toString(), Colors.blue),
                                    _buildStatCard('Regular Users', _userStats!['users'].toString(), Colors.green),
                                    _buildStatCard('Admins', _userStats!['admins'].toString(), Colors.orange),
                                    _buildStatCard('Superadmins', _userStats!['superadmins'].toString(), Colors.red),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Users List
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.people, color: Colors.orange),
                                      const SizedBox(width: 8),
                                      Text(
                                        'All Users (${_users.length})',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: _loadUsers,
                                    tooltip: 'Refresh Users',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_users.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No users found',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columnSpacing: 20,
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'S.No',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Email Address',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Role',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'New Role',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Action',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                    rows: _users.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final user = entry.value;
                                      final isCurrentUser = user['uid'] == _authService.currentUser?.uid;
                                      
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              '${index + 1}',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                Text(
                                                  user['email'] ?? 'Unknown',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isCurrentUser ? Colors.green : null,
                                                  ),
                                                ),
                                                if (isCurrentUser) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Text(
                                                      'YOU',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getRoleColor(user['role'] ?? 'user').withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: _getRoleColor(user['role'] ?? 'user')),
                                              ),
                                              child: Text(
                                                (user['role'] ?? 'user').toUpperCase(),
                                                style: TextStyle(
                                                  color: _getRoleColor(user['role'] ?? 'user'),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            isCurrentUser
                                                ? Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.green),
                                                    ),
                                                    child: const Text(
                                                      'CURRENT USER',
                                                      style: TextStyle(
                                                        color: Colors.green,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  )
                                                : _buildRoleDropdown(user),
                                          ),
                                          DataCell(
                                            isCurrentUser
                                                ? const Text(
                                                    'Current User',
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  )
                                                : _buildUpdateButton(user),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.people,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
} 