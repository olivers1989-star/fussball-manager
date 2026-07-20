; Inno-Setup-Skript für den Fussball-Manager-Installer.
; Bauen: ISCC.exe /DMyAppVersion=X.Y.Z installer\setup.iss
; Ergebnis: builds\FussballManager_Setup_vX.Y.Z.exe
; Updates werden einfach über die bestehende Installation installiert (gleiche AppId).

#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif

[Setup]
AppId={{7C1F45A9-3D82-4E1B-9C55-0F2A8B3D71E4}}
AppName=Fussball Manager
AppVersion={#MyAppVersion}
AppPublisher=Oliver Smolinski
DefaultDirName={localappdata}\Programs\Fussball Manager
DefaultGroupName=Fussball Manager
PrivilegesRequired=lowest
OutputDir=..\builds
OutputBaseFilename=FussballManager_Setup_v{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
CloseApplications=yes
UninstallDisplayIcon={app}\FussballManager.exe

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\builds\FussballManager.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Fussball Manager"; Filename: "{app}\FussballManager.exe"
Name: "{autodesktop}\Fussball Manager"; Filename: "{app}\FussballManager.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\FussballManager.exe"; Description: "{cm:LaunchProgram,Fussball Manager}"; Flags: nowait postinstall skipifsilent
