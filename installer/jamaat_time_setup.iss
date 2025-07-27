[Setup]
AppName=Jamaat Time
AppVersion=1.0.12
AppPublisher=Jamaat Time Team
AppPublisherURL=https://jamaattime.com
AppSupportURL=https://jamaattime.com/support
AppUpdatesURL=https://jamaattime.com/updates
DefaultDirName={autopf}\Jamaat Time
DefaultGroupName=Jamaat Time
AllowNoIcons=yes
OutputDir=..\build\windows\installer
OutputBaseFilename=JamaatTime_Setup_v1.0.12
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Jamaat Time"; Filename: "{app}\jamaat_time.exe"
Name: "{group}\Uninstall Jamaat Time"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Jamaat Time"; Filename: "{app}\jamaat_time.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\jamaat_time.exe"; Description: "Launch Jamaat Time"; Flags: nowait postinstall skipifsilent 