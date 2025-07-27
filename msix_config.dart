import 'package:msix/msix.dart';

void main() {
  final msix = Msix(
    displayName: 'Jamaat Time',
    publisherDisplayName: 'Jamaat Time Team',
    identityName: 'JamaatTime',
    msixVersion: '1.0.12.0',
    logoPath: 'assets/icon/icon.png',
    capabilities: 'internetClient,location',
    filePath: 'build/windows/runner/Release/',
    outputPath: 'build/windows/installer/',
    certificatePath: 'certificate.pfx',
    certificatePassword: 'password',
    publisher: 'CN=JamaatTime',
    description: 'Jamaat Time - Prayer Times and Admin Panel',
    backgroundColor: '#E8F5E9',
    foregroundColor: '#388E3C',
    square150x150Logo: 'assets/icon/icon.png',
    square44x44Logo: 'assets/icon/icon.png',
    square70x70Logo: 'assets/icon/icon.png',
    wide310x150Logo: 'assets/icon/icon.png',
    square310x310Logo: 'assets/icon/icon.png',
    square71x71Logo: 'assets/icon/icon.png',
    uap10: Uap10(
      displayName: 'Jamaat Time',
      description: 'Jamaat Time - Prayer Times and Admin Panel',
      backgroundColor: '#E8F5E9',
      foregroundColor: '#388E3C',
      square150x150Logo: 'assets/icon/icon.png',
      square44x44Logo: 'assets/icon/icon.png',
      square70x70Logo: 'assets/icon/icon.png',
      wide310x150Logo: 'assets/icon/icon.png',
      square310x310Logo: 'assets/icon/icon.png',
      square71x71Logo: 'assets/icon/icon.png',
    ),
  );

  msix.createMsixFile();
} 