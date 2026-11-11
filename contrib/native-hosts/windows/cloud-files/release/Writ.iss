#ifndef Payload
  #error Payload must name the staged package
#endif
#ifndef Version
  #error Version must name the release
#endif
#ifndef NumericVersion
  #error NumericVersion must name the Windows file version
#endif
[Setup]
AppId={{A15C3556-9AC4-47B2-A606-31BFBEC3E8CB}
AppName=Writ Public Preview
AppVersion={#Version}
AppPublisher=Writ contributors
AppPublisherURL=https://github.com/Spaceghost/writ
AppSupportURL=https://github.com/Spaceghost/writ/issues
AppUpdatesURL=https://github.com/Spaceghost/writ/releases
DefaultDirName={localappdata}\Programs\Writ
DefaultGroupName=Writ Public Preview
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
DisableProgramGroupPage=yes
DisableDirPage=yes
OutputBaseFilename=Writ-{#Version}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
TimeStampsInUTC=yes
VersionInfoVersion={#NumericVersion}
VersionInfoProductTextVersion={#Version}
UninstallDisplayIcon={app}\writ-cloud.exe
CloseApplications=no
RestartApplications=no
WizardStyle=modern

[Files]
Source: "{#Payload}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs notimestamp

[Icons]
Name: "{group}\Start Writ"; Filename: "{app}\writ-cloud.exe"; Parameters: "start"; WorkingDir: "{app}"
Name: "{group}\Stop Writ"; Filename: "{app}\writ-cloud.exe"; Parameters: "stop"
Name: "{group}\Open Writ folder"; Filename: "{win}\explorer.exe"; Parameters: """{%USERPROFILE}\Writ"""
Name: "{group}\Read me"; Filename: "{app}\README.txt"

[Run]
Filename: "{app}\writ-cloud.exe"; Parameters: "start"; Description: "Start Writ public preview"; Flags: postinstall nowait skipifsilent unchecked

[Code]
function InitializeUninstall(): Boolean;
var
  Code: Integer;
begin
  Result := Exec(ExpandConstant('{app}\writ-cloud.exe'), 'cleanup', '', SW_HIDE, ewWaitUntilTerminated, Code);
  if Result then Result := Code = 0;
  if not Result then
    SuppressibleMsgBox('Writ could not safely remove its sync registration. Close editors and run writ-cloud.exe cleanup, then retry uninstall. Your files and recovery copies have been retained.', mbError, MB_OK, IDOK);
end;
