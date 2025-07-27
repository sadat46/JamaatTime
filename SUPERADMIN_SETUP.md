# 🛡️ Superadmin Setup Guide

## Overview
The Jamaat Time app now supports a three-tier role system:
- **User**: Regular users who can view prayer times and set preferences
- **Admin**: Can manage jamaat times for all cantt areas
- **Superadmin**: Has all admin privileges plus user management capabilities

## 🔧 Setting Up Superadmin

### Method 1: Firestore Database (Recommended)

1. **Access Firebase Console**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your Jamaat Time project
   - Navigate to Firestore Database

2. **Create/Update User Document**
   - Go to the `users` collection
   - Find the user document you want to make superadmin
   - Update the `role` field to `superadmin`
   ```json
   {
     "email": "your-email@example.com",
     "role": "superadmin",
     "created_at": "timestamp",
     "updated_at": "timestamp"
   }
   ```

### Method 2: Hardcoded Email (Legacy Support)

1. **Edit AuthService**
   - Open `lib/services/auth_service.dart`
   - Find the `superadminEmails` array
   - Add your email address:
   ```dart
   const superadminEmails = [
     'your-email@example.com', // Add your email here
   ];
   ```

## 🎯 Superadmin Features

### 1. User Management
- **View All Users**: See complete list of registered users
- **User Statistics**: View counts of users, admins, and superadmins
- **Role Management**: Change user roles (User ↔ Admin ↔ Superadmin)
- **User Deletion**: Remove users from the system

### 2. Access Control
- **Role Hierarchy**: Superadmin > Admin > User
- **Self-Protection**: Superadmins cannot change their own role
- **Peer Protection**: Superadmins cannot modify other superadmins

### 3. Admin Features (Inherited)
- All admin capabilities for managing jamaat times
- City selection and time updates
- Real-time data synchronization

## 🔐 Security Features

### Role Protection
- **Self-Modification Prevention**: Users cannot change their own roles
- **Superadmin Protection**: Superadmins cannot modify other superadmins
- **Self-Deletion Prevention**: Users cannot delete their own accounts

### Access Control
- **Role-Based Access**: Features are only available to appropriate roles
- **Permission Validation**: Server-side validation of all operations
- **Audit Trail**: All role changes are timestamped

## 📱 Using Superadmin Features

### 1. Access User Management
1. Log in with superadmin credentials
2. Go to Profile tab
3. Click "Manage Users" button in Superadmin Controls section

### 2. Manage User Roles
1. In User Management screen, find the user
2. Click the three-dot menu (⋮)
3. Select desired role:
   - **Make User**: Regular user access
   - **Make Admin**: Admin privileges
   - **Make Superadmin**: Full superadmin access

### 3. View Statistics
- User Management screen shows real-time statistics
- Total users, regular users, admins, and superadmins
- Automatic updates when roles change

## 🚨 Important Notes

### Security Considerations
- **Superadmin Access**: Superadmins have complete system control
- **Role Assignment**: Be careful when assigning superadmin roles
- **Email Verification**: Ensure superadmin emails are verified
- **Backup**: Regular backups of user data recommended

### Best Practices
- **Limited Superadmins**: Keep superadmin count minimal
- **Regular Audits**: Periodically review user roles
- **Secure Emails**: Use secure email addresses for superadmin accounts
- **Documentation**: Keep track of role assignments

### Troubleshooting
- **Access Denied**: Ensure you're logged in with superadmin credentials
- **Role Not Updating**: Check Firestore permissions and internet connection
- **User Not Found**: Verify user exists in Firestore database

## 🔄 Migration from Old System

### Existing Admin Users
- Current admin users will continue to work
- They can be upgraded to superadmin via Firestore
- Legacy email-based admin system still supported

### New User Registration
- New users automatically get 'user' role
- Admins/superadmins must be manually assigned
- No automatic role escalation

## 📞 Support

For issues with superadmin functionality:
1. Check Firestore database permissions
2. Verify user document structure
3. Ensure proper role field values
4. Check Firebase Authentication status

---

**Note**: This superadmin system provides powerful user management capabilities. Use responsibly and ensure proper security measures are in place. 