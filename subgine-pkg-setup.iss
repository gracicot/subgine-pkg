[Setup]
AppName=Subgine Package Manager
ArchitecturesInstallIn64BitMode=x64
DefaultDirName={pf}\Subgine Package Manager
AppVersion=0.0.1
ChangesEnvironment=yes
UninstallFilesDir={app}\uninstall
OutputBaseFilename=subgine-pkg-setup
AppPublisher=Quack Games

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation";  Flags: iscustom

[Components]
Name: subgine_pkg; Description: Subgine Package Manager; Types: full custom; Flags: fixed
Name: subgine_pkg\path; Description: Add subgine-pkg To PATH; Types: full custom;

[Code]
const
  EnvironmentKey = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';

function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    EnvironmentKey,
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  { look for the path with leading and trailing semicolon }
  { Pos() returns 0 if not found }
  Result := Pos(';' + Param + ';', ';' + OrigPath + ';') = 0;
end;

procedure RemovePath(Path: string);
var
  Paths: string;
  P: Integer;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths) then
  begin
    Log('PATH not found');
  end
    else
  begin
    Log(Format('PATH is [%s]', [Paths]));

    P := Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';');
    if P = 0 then
    begin
      Log(Format('Path [%s] not found in PATH', [Path]));
    end
      else
    begin
      if P > 1 then P := P - 1;
      Delete(Paths, P, Length(Path) + 1);
      Log(Format('Path [%s] removed from PATH => [%s]', [Path, Paths]));

      if RegWriteStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths) then
      begin
        Log('PATH written');
      end
        else
      begin
        Log('Error writing PATH');
      end;
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    RemovePath(ExpandConstant('{app}') + '\bin');
  end;
end;

[Files]
Source: "subgine-pkg"; DestDir: "{app}\bin"; Components: subgine_pkg
Source: "subgine-pkg.cmake"; DestDir: "{app}\bin"; Components: subgine_pkg

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}\bin"; \
    Check: NeedsAddPath('{app}\bin'); Components: subgine_pkg\path 

[UninstallDelete]
Type: files; Name: "{app}\bin\subgine-pkg"
