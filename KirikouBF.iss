
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

; ================================================================
; ICONE DE L'INSTALLATEUR
; ================================================================

SetupIconFile=assets\kirikoubf.ico

; ================================================================
; GENERATION DE L'INSTALLATEUR
; ================================================================

OutputDir=installer
OutputBaseFilename=KirikouBF-Setup-{#MyAppVersion}

Compression=lzma2
SolidCompression=yes
WizardStyle=modern

; ================================================================
; DESINSTALLATION
; ================================================================

Uninstallable=yes
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}

PrivilegesRequired=admin

; ================================================================
; INFORMATIONS DE VERSION
; ================================================================

VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Application desktop de gestion KirikouBF
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoCopyright=© 2026 KirikouBF

; ================================================================
; FICHIERS A INSTALLER
; ================================================================

[Files]

; Tous les fichiers compilés de Flutter
Source: "build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

; Redistribuable Microsoft Visual C++ x64
Source: "scripts\vc_redist.x64.exe"; \
    DestDir: "{tmp}"; \
    Flags: deleteafterinstall

; ================================================================
; RACCOURCIS WINDOWS
; ================================================================

[Icons]

; Menu Démarrer
Name: "{group}\KirikouBF"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"; \
    IconFilename: "{app}\{#MyAppExeName}"

; Bureau
Name: "{autodesktop}\KirikouBF"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"; \
    IconFilename: "{app}\{#MyAppExeName}"

; ================================================================
; EXECUTION APRES INSTALLATION
; ================================================================

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
