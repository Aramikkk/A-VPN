; A-VPN installer for Windows. Build: ISCC.exe avpn.iss (after flutter build windows)
#define AppName "A-VPN"
#define AppVersion "5.0.0"
#define AppExe "A-VPN.exe"
#define BuildDir "..\..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{8C2F7A41-5E3B-4D9A-9F61-AA0C3E7B2D15}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppName}
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
; installs for the current user without asking for admin rights; the admin choice is still offered
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\..\..\build\windows\installer
OutputBaseFilename=A-VPN-Setup-{#AppVersion}
SetupIconFile=..\..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=force
RestartApplications=no

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
russian.AutoStart=Запускать A-VPN при входе в Windows
english.AutoStart=Start A-VPN when I sign in to Windows
russian.StartupGroup=Автозапуск:
english.StartupGroup=Startup:

[Tasks]
Name: "autostart"; Description: "{cm:AutoStart}"; GroupDescription: "{cm:StartupGroup}"
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; the same entry the app's own "start at login" switch writes (launch_at_startup: value name = app name,
; data = exe path), so that switch shows the right state
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#AppName}"; ValueData: "{app}\{#AppExe}"; Tasks: autostart; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"; ValueType: binary; ValueName: "{#AppName}"; ValueData: "02 00 00 00 00 00 00 00 00 00 00 00"; Tasks: autostart; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; stops the VPN service the app may have started, so its files can be removed
Filename: "{app}\HiddifyCli.exe"; Parameters: "tunnel exit"; Flags: runhidden skipifdoesntexist; RunOnceId: "StopTunnel"
