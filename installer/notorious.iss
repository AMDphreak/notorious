; Notorious — Inno Setup installer
; Build: iscc installer/notorious.iss
; Expects notorious.exe in repo root (dub build -c windowed).
;
; Launch names (same binary, three filenames + App Paths + optional PATH):
;   note (primary), noto (if note conflicts), notorious (full product)
; Win+R uses App Paths; terminals/scripts need PATH (or full path to a shim).

#define MyAppName "Notorious"
#ifndef MyAppVersion
  #define MyAppVersion "0.1.1"
#endif
#ifndef MyArch
  #define MyArch "windows-x64"
#endif
#ifndef MyArchAllowed
  #define MyArchAllowed "x64compatible"
#endif
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
; Architecture in the filename so x64/arm64 do not collide on the release page.
OutputBaseFilename=Notorious-{#MyAppVersion}-{#MyArch}-setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed={#MyArchAllowed}
ArchitecturesInstallIn64BitMode={#MyArchAllowed}
UninstallDisplayIcon={app}\{#MyAppExeName}
; Needed so new PATH is visible after install without a reboot dance.
ChangesEnvironment=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "apopaths"; Description: "Register Win+R aliases (note, noto, notorious)"; GroupDescription: "Launch shortcuts:"; Flags: checkedonce
Name: "addpath"; Description: "Add install folder to user PATH (for terminals / CLI)"; GroupDescription: "Launch shortcuts:"; Flags: checkedonce

[Files]
; Canonical binary + CLI/Win+R shims (same bytes, different names).
Source: "..\notorious.exe"; DestDir: "{app}"; DestName: "notorious.exe"; Flags: ignoreversion
Source: "..\notorious.exe"; DestDir: "{app}"; DestName: "note.exe"; Flags: ignoreversion
Source: "..\notorious.exe"; DestDir: "{app}"; DestName: "noto.exe"; Flags: ignoreversion
; Present when the Windows build links the vello_bridge cdylib/import lib.
Source: "..\vello_bridge.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "..\assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.adoc"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; App Paths: Win+R / ShellExecute (does not help cmd/PowerShell by itself).
[Registry]
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\note.exe"; ValueType: string; ValueData: "{app}\note.exe"; Flags: uninsdeletekey; Tasks: apopaths
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\note.exe"; ValueType: string; ValueName: "Path"; ValueData: "{app}"; Tasks: apopaths
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\noto.exe"; ValueType: string; ValueData: "{app}\noto.exe"; Flags: uninsdeletekey; Tasks: apopaths
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\noto.exe"; ValueType: string; ValueName: "Path"; ValueData: "{app}"; Tasks: apopaths
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notorious.exe"; ValueType: string; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey; Tasks: apopaths
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notorious.exe"; ValueType: string; ValueName: "Path"; ValueData: "{app}"; Tasks: apopaths

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent shellexec

[Code]
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_CURRENT_USER,
    'Environment', 'Path', OrigPath) then
  begin
    Result := True;
    exit;
  end;
  { Avoid duplicating the install dir on reinstall }
  Result := Pos(';' + Param + ';', ';' + OrigPath + ';') = 0;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Path: string;
  AppDir: string;
begin
  if CurStep <> ssPostInstall then
    exit;
  if not WizardIsTaskSelected('addpath') then
    exit;
  AppDir := ExpandConstant('{app}');
  if not NeedsAddPath(AppDir) then
    exit;
  if not RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Path) then
    Path := '';
  if Path = '' then
    Path := AppDir
  else if Path[Length(Path)] = ';' then
    Path := Path + AppDir
  else
    Path := Path + ';' + AppDir;
  RegWriteExpandStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Path);
  { ChangesEnvironment=yes already broadcasts WM_SETTINGCHANGE }
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Path, AppDir, Left, Right: string;
  P: Integer;
begin
  if CurUninstallStep <> usPostUninstall then
    exit;
  AppDir := ExpandConstant('{app}');
  if not RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Path) then
    exit;
  P := Pos(';' + AppDir + ';', ';' + Path + ';');
  if P = 0 then
    exit;
  { Rebuild PATH without AppDir (tolerant of ends) }
  Path := ';' + Path + ';';
  StringChangeEx(Path, ';' + AppDir + ';', ';', True);
  { Trim outer semicolons }
  while (Length(Path) > 0) and (Path[1] = ';') do
    Delete(Path, 1, 1);
  while (Length(Path) > 0) and (Path[Length(Path)] = ';') do
    Delete(Path, Length(Path), 1);
  RegWriteExpandStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Path);
end;
