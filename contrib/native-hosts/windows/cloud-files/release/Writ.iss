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
AppName=Writ
AppVersion={#Version}
AppPublisher=Writ contributors
AppPublisherURL=https://github.com/Spaceghost/writ
AppSupportURL=https://github.com/Spaceghost/writ/issues
AppUpdatesURL=https://github.com/Spaceghost/writ/releases
DefaultDirName={localappdata}\Programs\Writ
DefaultGroupName=Writ
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
UninstallDisplayIcon={app}\Writ.exe
CloseApplications=no
RestartApplications=no
WizardStyle=modern

[Files]
Source: "{#Payload}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs notimestamp
Source: "{#Payload}\Writ.exe"; DestName: "writ-desktop-upgrade.exe"; Flags: dontcopy notimestamp
Source: "{#Payload}\writ-cloud.exe"; DestName: "writ-provider-upgrade.exe"; Flags: dontcopy notimestamp

[Icons]
Name: "{group}\Writ"; Filename: "{app}\Writ.exe"; WorkingDir: "{app}"
Name: "{group}\Quit Writ"; Filename: "{app}\Writ.exe"; Parameters: "--quit"
Name: "{group}\Open Writ folder"; Filename: "{app}\Writ.exe"; Parameters: "--open-folder"
Name: "{group}\Writ files and rules"; Filename: "{app}\WritDrive.exe"; WorkingDir: "{app}"
Name: "{group}\Stop Writ files and rules"; Filename: "{app}\WritDrive.exe"; Parameters: "--stop"
Name: "{group}\Read me"; Filename: "{app}\README.txt"

[Run]
Filename: "{app}\Writ.exe"; Description: "Start Writ public preview"; Flags: postinstall nowait skipifsilent

[Code]
function StopDrive(): Boolean;
var
  Code: Integer;
begin
  Result := True;
  if FileExists(ExpandConstant('{app}\WritDrive.exe')) then begin
    Result := Exec(ExpandConstant('{app}\WritDrive.exe'), '--stop', '', SW_HIDE, ewWaitUntilTerminated, Code);
    if Result then Result := Code = 0;
  end;
end;

function StopDesktop(): Boolean;
var
  Code: Integer;
begin
  Result := StopDrive();
  if Result and FileExists(ExpandConstant('{app}\Writ.exe')) then begin
    Result := Exec(ExpandConstant('{app}\Writ.exe'), '--quit', '', SW_HIDE, ewWaitUntilTerminated, Code);
    if Result then Result := Code = 0;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Code: Integer;
  Stopped: Boolean;
begin
  Result := '';
  if not StopDrive() then begin
    Result := 'Writ files and rules is still finishing a storage operation. Retry when it has finished.';
    exit;
  end;
  { The helpers come from the new package, so a preview.2 console-only install
    and a portable desktop instance can both be stopped before replacement. }
  ExtractTemporaryFile('writ-desktop-upgrade.exe');
  ExtractTemporaryFile('writ-provider-upgrade.exe');
  Stopped := Exec(ExpandConstant('{tmp}\writ-desktop-upgrade.exe'), '--quit', '', SW_HIDE, ewWaitUntilTerminated, Code);
  if Stopped then Stopped := Code = 0;
  if Stopped then begin
    Stopped := Exec(ExpandConstant('{tmp}\writ-provider-upgrade.exe'), 'stop-wait', '', SW_HIDE, ewWaitUntilTerminated, Code);
    if Stopped then Stopped := Code = 0;
  end;
  if not Stopped then
    Result := 'Writ is still running. Close editors and quit Writ, then retry installation.';
end;

function InitializeUninstall(): Boolean;
var
  Code: Integer;
begin
  Result := StopDesktop();
  if not Result then begin
    SuppressibleMsgBox('Writ is still running. Close editors and quit Writ before uninstalling.', mbError, MB_OK, IDOK);
    exit;
  end;
  Result := Exec(ExpandConstant('{app}\writ-cloud.exe'), 'cleanup', '', SW_HIDE, ewWaitUntilTerminated, Code);
  if Result then Result := Code = 0;
  if Result then begin
    Result := Exec(ExpandConstant('{app}\Writ.exe'), '--unregister-startup', '', SW_HIDE, ewWaitUntilTerminated, Code);
    if Result then Result := Code = 0;
  end;
  if not Result then
    SuppressibleMsgBox('Writ could not safely remove its sync registration. Close editors and run writ-cloud.exe cleanup, then retry uninstall. Your files and recovery copies have been retained.', mbError, MB_OK, IDOK);
end;
