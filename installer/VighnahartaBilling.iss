; Build the Flutter Windows release, then stage it in dist\VighnahartaBilling-2.0.0\app.
; Keep this AppId unchanged for future upgrades.
#define AppName "Vighnaharta Billing"
#define AppVersion "2.0.0"
#define AppExe "vighnaharta_fataka.exe"
#define ReleaseDir "..\..\dist\VighnahartaBilling-2.0.0\app"

[Setup]
AppId={{43E17C08-E8C4-43E6-BDF2-483041238795}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Vighnaharta
DefaultDirName={autopf}\Vighnaharta Billing
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExe}
SetupIconFile=..\windows\runner\resources\app_icon.ico
OutputDir=..\..\dist
OutputBaseFilename=VighnahartaBillingSetup-2.0.0
VersionInfoVersion=2.0.0.2
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
PrivilegesRequired=admin
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\dist\VighnahartaBilling-2.0.0\prerequisites\vc_redist.x64.exe"; Flags: dontcopy

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch {#AppName}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[Code]
function NeedsVCRuntime: Boolean;
var
  Installed, Major, Minor, Build: Cardinal;
  Key: String;
begin
  Key := 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';
  Result := True;
  if not RegQueryDWordValue(HKLM64, Key, 'Installed', Installed) then Exit;
  if Installed <> 1 then Exit;
  if not RegQueryDWordValue(HKLM64, Key, 'Major', Major) then Exit;
  if not RegQueryDWordValue(HKLM64, Key, 'Minor', Minor) then Exit;
  if not RegQueryDWordValue(HKLM64, Key, 'Bld', Build) then Exit;
  Result := (Major < 14) or
    ((Major = 14) and (Minor < 51)) or
    ((Major = 14) and (Minor = 51) and (Build < 36247));
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ExitCode: Integer;
begin
  Result := '';
  if not NeedsVCRuntime then Exit;
  ExtractTemporaryFile('vc_redist.x64.exe');
  if not Exec(ExpandConstant('{tmp}\vc_redist.x64.exe'),
    '/install /quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then
  begin
    Result := 'Could not start the Microsoft Visual C++ runtime installer.';
    Exit;
  end;
  if ExitCode = 3010 then NeedsRestart := True
  else if (ExitCode <> 0) and (ExitCode <> 1638) then
    Result := 'Microsoft Visual C++ runtime installation failed (code ' +
      IntToStr(ExitCode) + '). Restart Windows and run Setup again.';
end;
