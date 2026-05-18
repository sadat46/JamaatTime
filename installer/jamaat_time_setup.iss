[Setup]
AppName=Jamaat Time
AppVersion=2.0.46
AppPublisher=Jamaat Time Team
AppPublisherURL=https://jamaattime.com
AppSupportURL=https://jamaattime.com/support
AppUpdatesURL=https://jamaattime.com/updates
DefaultDirName={autopf}\Jamaat Time
DefaultGroupName=Jamaat Time
AllowNoIcons=yes
OutputDir=..\build\windows\installer
OutputBaseFilename=JamaatTime_Setup_v2.0.46
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Jamaat Time"; Filename: "{app}\jamaat_time.exe"
Name: "{group}\Uninstall Jamaat Time"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Jamaat Time"; Filename: "{app}\jamaat_time.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\jamaat_time.exe"; Description: "Launch Jamaat Time"; Flags: nowait postinstall skipifsilent 

[Code]
const
  VCRedistUrl = 'https://aka.ms/vs/17/release/vc_redist.x64.exe';
  VCRedistFileName = 'vc_redist.x64.exe';

var
  DownloadPage: TDownloadWizardPage;
  VCRedistDownloaded: Boolean;

function IsVCRedistInstalled: Boolean;
var
  Installed: Cardinal;
begin
  Result :=
    RegQueryDWordValue(
      HKLM64,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
      'Installed',
      Installed
    ) and (Installed = 1);
end;

function OnDownloadProgress(
  const Url,
  FileName: String;
  const Progress,
  ProgressMax: Int64
): Boolean;
begin
  if Progress = ProgressMax then
    Log(Format('Successfully downloaded prerequisite to {tmp}: %s', [FileName]));
  Result := True;
end;

procedure InitializeWizard;
begin
  DownloadPage :=
    CreateDownloadPage(
      SetupMessage(msgWizardPreparing),
      SetupMessage(msgPreparingDesc),
      @OnDownloadProgress
    );
  DownloadPage.ShowBaseNameInsteadOfUrl := True;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  if (CurPageID = wpReady) and not IsVCRedistInstalled then begin
    DownloadPage.Clear;
    DownloadPage.Add(VCRedistUrl, VCRedistFileName, '');
    DownloadPage.Show;

    try
      try
        DownloadPage.Download;
        VCRedistDownloaded := True;
      except
        if DownloadPage.AbortedByUser then
          Log('VC++ Redistributable download aborted by user.')
        else
          SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbCriticalError, MB_OK, IDOK);
        Result := False;
      end;
    finally
      DownloadPage.Hide;
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Result := '';

  if IsVCRedistInstalled then
    Exit;

  if not VCRedistDownloaded then begin
    Result :=
      'Microsoft Visual C++ Redistributable is required but was not downloaded. ' +
      'Please check your internet connection and run setup again.';
    Exit;
  end;

  WizardForm.StatusLabel.Caption := 'Installing Microsoft Visual C++ Redistributable...';

  if Exec(
    ExpandConstant('{tmp}\') + VCRedistFileName,
    '/install /quiet /norestart',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  ) then begin
    if (ResultCode = 0) or (ResultCode = 3010) then begin
      if ResultCode = 3010 then
        NeedsRestart := True;
    end else begin
      Result :=
        'Microsoft Visual C++ Redistributable installer failed with exit code ' +
        IntToStr(ResultCode) +
        '.';
    end;
  end else begin
    Result := 'Microsoft Visual C++ Redistributable installer could not be started.';
  end;
end;
