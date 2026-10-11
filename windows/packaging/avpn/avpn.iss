; A-VPN installer for Windows. Build: ISCC.exe avpn.iss (after flutter build windows)
#define AppName "A-VPN"
; the release number: release.sh passes it from pubspec.yaml (/DAppVersion=…)
#ifndef AppVersion
  #define AppVersion "5.1.0"
#endif
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
; admin rights: the sign-in task that starts A-VPN runs with highest privileges, so TUN needs no UAC prompt
PrivilegesRequired=admin
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
Source: "autostart.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; the launch after setup runs with setup's admin rights: A-VPN.exe may be marked "run as administrator"
; (the VPN mode needs it), and Windows refuses to start such a file without them (error 740)
; start at sign-in through a scheduled task (also clears the Run-key entry older versions wrote)
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\autostart.ps1"" -Enable"; Flags: runhidden waituntilterminated; Tasks: autostart
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\autostart.ps1"" -Disable"; Flags: runhidden waituntilterminated; Tasks: not autostart
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent runascurrentuser

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\autostart.ps1"" -Disable"; Flags: runhidden waituntilterminated; RunOnceId: "RemoveAutostart"
; stops the VPN service the app may have started, so its files can be removed
Filename: "{app}\HiddifyCli.exe"; Parameters: "tunnel exit"; Flags: runhidden skipifdoesntexist; RunOnceId: "StopTunnel"
