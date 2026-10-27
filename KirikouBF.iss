
; ================================================================
; INSTALLATEUR KIRIKOUBF
; ================================================================

#define MyAppName "KirikouBF"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "KirikouBF"
#define MyAppExeName "kirikoubf_desktop.exe"

[Setup]
AppId={{KIRIKOUBF-DESKTOP-2026}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

OutputDir=installer
OutputBaseFilename=KirikouBF-Setup-{#MyAppVersion}

Compression=lzma2
SolidCompression=yes
WizardStyle=modern

Uninstallable=yes
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}

PrivilegesRequired=admin

VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Application desktop de gestion KirikouBF
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoCopyright=© 2026 KirikouBF

[Files]
; Tous les fichiers compilés de Flutter
Source: "build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

; Redistribuable Microsoft Visual C++ x64
Source: "scripts\vc_redist.x64.exe"; \
    DestDir: "{tmp}"; \
    Flags: deleteafterinstall

[Icons]
Name: "{group}\KirikouBF"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"

Name: "{autodesktop}\KirikouBF"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"

[Run]
; Installer ou mettre à jour le runtime Visual C++
Filename: "{tmp}\vc_redist.x64.exe"; \
    Parameters: "/install /quiet /norestart"; \
    StatusMsg: "Installation des composants Microsoft Visual C++..."; \
    Flags: waituntilterminated; \
    Check: Is64BitInstallMode

; Lancer KirikouBF à la fin
Filename: "{app}\{#MyAppExeName}"; \
    Description: "Lancer KirikouBF"; \
    WorkingDir: "{app}"; \
    Flags: nowait postinstall skipifsilent
