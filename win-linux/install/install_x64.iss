#include "common.iss"


[Setup]
AppName                 ={#sAppName}
AppVersion              ={#sAppVersion}
#ifdef _IVO_
OutputBaseFileName      =Ivolgapro_x64
#else
OutputBaseFileName      =DesktopEditors_x64
#endif
;MinVersion              =0,5.0.2195
MinVersion              =6.0
ArchitecturesAllowed    =x64
ArchitecturesInstallIn64BitMode=x64
;ShowUndisplayableLanguages = true
;UsePreviousLanguage=no

[Code]

[Files]
Source: data\vcredist\vcredist_x64.exe;       DestDir: {app}\; Flags: deleteafterinstall; \
    AfterInstall: installVCRedist(ExpandConstant('{app}\vcredist_x64.exe'), ExpandConstant('{cm:InstallAdditionalComponents}')); Check: not checkVCRedist;

Source: ..\build\Release\release\DesktopEditors.exe; DestDir: {app}; 

Source: ..\..\common\converter\windows\win64\*;           DestDir: {app}\converter; Flags: recursesubdirs ignoreversion;

Source: ..\..\common\libs\ChromiumBasedEditors2\app\corebuilds\win64\ascdocumentscore.dll;  DestDir: {app}\; Flags: ignoreversion;
Source: ..\..\common\libs\ChromiumBasedEditors2\app\cefbuilds\win64\*;                      DestDir: {app}\; Excludes: *.lib; Flags: ignoreversion recursesubdirs;
Source: data\libs\qt\win64\*;                               DestDir: {app}\; Flags: ignoreversion recursesubdirs;
Source: data\libs\chromium\win64\dbghelp.dll;               DestDir: {app}\; Flags: onlyifdoesntexist; Check: libExists('dbghelp.dll');

;
; some files placed in common.iss
;