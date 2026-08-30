; Notorious — Inno Setup installer
; Build: iscc installer/notorious.iss
; Expects notorious.exe in repo root (dub build -c windowed) or set SourcePath.
;
; Win+R aliases: each name under App Paths is a separate key pointing at the
; same binary (Microsoft-recommended; prefer this over mutating PATH).
; Aliases: noto, notor, notorious

#define MyAppName "Notorious"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "AMDphreak"
#define MyAppURL "https://github.com/AMDphreak/notorious"
#define MyAppExeName "notorious.exe"

[Setup]
AppId={{A7C3E9D1-4B2F-4E8A-9C11-NOTORIOUS0001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
OutputDir=..\dist
OutputBaseFilename=Notorious-{#MyAppVersion}-setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
; Start Menu name includes "Notorious" so searching "note" finds it.
UninstallDisplayIcon={app}\{#MyAppExeName}
ChangesEnvironment=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "apopaths"; Description: "Register Win+R aliases (noto, notor, notorious)"; GroupDescription: "Launch shortcuts:"; Flags: checkedonce

[Files]
Source: "..\notorious.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.adoc"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; App Paths: ShellExecute / Win+R resolve these without putting {app} on PATH.
; Multiple aliases = multiple keys; each (Default) points at the real binary.
[Registry]
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\noto.exe"; ValueType: string; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey; Tasks: apopaths
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\noto.exe"; ValueType: string; ValueName: "Path"; ValueData: "{app}"; Tasks: apopaths
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notor.exe"; ValueType: string; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey; Tasks: apopaths
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notor.exe"; ValueType: string; ValueName: "Path"; ValueData: "{app}"; Tasks: apopaths
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notorious.exe"; ValueType: string; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey; Tasks: apopaths
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notorious.exe"; ValueType: string; ValueName: "Path"; ValueData: "{app}"; Tasks: apopaths

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent shellexec
