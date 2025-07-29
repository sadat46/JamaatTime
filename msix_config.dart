import 'package:msix/msix.dart';

void main() async {
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
  );

  await msix.createMsixFile();
} 