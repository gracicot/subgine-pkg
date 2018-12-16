[Setup]
AppName=Subgine Package Manager
ArchitecturesInstallIn64BitMode=x64
DefaultDirName={pf}\Subgine Package Manager
AppVersion=0.0.1
ChangesEnvironment=yes
UninstallFilesDir={app}\uninstall
OutputBaseFilename=subgine-pkg-setup
AppPublisher=Quack Games
DisableWelcomePage=no

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation";  Flags: iscustom

[Components]
Name: subgine_pkg; Description: Subgine Package Manager; Types: full custom; Flags: fixed
Name: subgine_pkg\path; Description: Add subgine-pkg To PATH; Types: full custom;

[Code]  
var
  CustomPage: TWizardPage;  
  CMakePathData: String;        
  CMakePathPage: TInputDirWizardPage;
  CMakeInstallationRadioButton: TNewRadioButton;   
  VisualStudioRadioButton: TNewRadioButton;
  ChoosePathRadioButton: TNewRadioButton;
  FigureOutRadioButton: TNewRadioButton;

const
  EnvironmentKey = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'; 
  VisualStudioCMakePath = 'C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin';
  CMakeDefaultPath = 'C:\Program Files\CMake\bin';

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
  Result :=  ( Pos(';' + UpperCase(Param) + ';', ';' + UpperCase(OrigPath) + ';') = 0) and
             (Pos(';' + UpperCase(Param) + '\;', ';' + UpperCase(OrigPath) + ';') = 0);
end;

function FileReplaceString(const FileName, SearchString, ReplaceString: string):boolean;
var
  MyFile : TStrings;
  MyText : string;
begin
  MyFile := TStringList.Create;

  try
    result := true;

    try
      MyFile.LoadFromFile(FileName);
      MyText := MyFile.Text;

      { Only save if text has been changed. }
      if StringChangeEx(MyText, SearchString, ReplaceString, True) > 0 then
      begin;
        MyFile.Text := MyText;
        MyFile.SaveToFile(FileName);
      end;
    except
      result := false;
    end;
  finally
    MyFile.Free;
  end;
end;


procedure RemovePath(Path: string);
var
  Paths: string;
  PathsWithSemicolon: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths) then
  begin
    Log('PATH not found');
  end
  else begin
    Log(Format('PATH is [%s]', [Paths]));
    PathsWithSemicolon := Uppercase(Paths) + ';';
    if StringChangeEx(PathsWithSemicolon, Uppercase(Path) + ';', '', True) > 0 then begin
      Log(Format('Path [%s] removed from PATH => [%s]', [Path, Paths]));
      
      if RegWriteStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', PathsWithSemicolon) then begin
        Log('PATH written');
      end
      else begin
        Log('Error writing PATH');
      end;
    end
    else begin
      Log(Format('Path [%s] not found in PATH', [Path]));
    end;
  end;
end; 

procedure ExplodeString(Text: String; Separator: String; var Dest: TArrayOfString);
var
  i, p: Integer;
begin
  i := 0;
  repeat
    SetArrayLength(Dest, i+1);
    p := Pos(Separator,Text);
    if p > 0 then begin
      Dest[i] := Copy(Text, 1, p-1);
      Text := Copy(Text, p + Length(Separator), Length(Text));
      i := i + 1;
    end else begin
      Dest[i] := Text;
      Text := '';
    end;
  until Length(Text)=0;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    RemovePath(ExpandConstant('{app}') + '\bin');
  end;
end;

procedure InitializeWizard;  
var   
  FullDescLabel: TLabel;
  PartDescLabel: TLabel;  
  ChoosePathLabel: TLabel;
  CheckNext: Boolean;
begin
  CMakePathPage := CreateInputDirPage(wpSelectComponents,
  'Select CMake bin directory', 'Where should CMake executable be found?',
  'Subgine Package Manager will run CMake scripts using the provided installation.'#13#10#13#10 +
  'To continue, click Next. If you would like to select a different CMake installation, click Browse.',
  False, 'New Folder');
  CMakePathPage.Add('');
  CMakePathPage.Values[0] := ''

  CheckNext := True;
  CMakePathData := '';

  CustomPage := CreateCustomPage(wpSelectComponents, 'Locate CMake', 'Where should Subgine Package Manager find CMake?');
  CMakeInstallationRadioButton := TNewRadioButton.Create(WizardForm);
  CMakeInstallationRadioButton.Parent := CustomPage.Surface;
  CMakeInstallationRadioButton.Checked := True;
  CMakeInstallationRadioButton.Top := 16;
  CMakeInstallationRadioButton.Width := CustomPage.SurfaceWidth;
  CMakeInstallationRadioButton.Font.Style := [fsBold];
  CMakeInstallationRadioButton.Font.Size := 9;
  CMakeInstallationRadioButton.Caption := 'CMake Installer';

  FullDescLabel := TLabel.Create(WizardForm);
  FullDescLabel.Parent := CustomPage.Surface;
  FullDescLabel.Left := 8;
  FullDescLabel.Top := CMakeInstallationRadioButton.Top + CMakeInstallationRadioButton.Height + 8;
  FullDescLabel.Width := CustomPage.SurfaceWidth; 
  FullDescLabel.Height := 24;
  FullDescLabel.AutoSize := False;
  FullDescLabel.Wordwrap := True;
  FullDescLabel.Caption := 'This option will select the CMake executable from the official CMake installation.';

  if not FileExists(CMakeDefaultPath  + '\cmake.exe') then begin
    CMakeInstallationRadioButton.Enabled := False
    FullDescLabel.Enabled := False
  end
  else begin
    if CheckNext then begin
      CMakeInstallationRadioButton.Checked := True;
      CheckNext := False;
    end;
  end;

  VisualStudioRadioButton := TNewRadioButton.Create(WizardForm);
  VisualStudioRadioButton.Parent := CustomPage.Surface;
  VisualStudioRadioButton.Top := FullDescLabel.Top + FullDescLabel.Height + 16;
  VisualStudioRadioButton.Width := CustomPage.SurfaceWidth;
  VisualStudioRadioButton.Font.Style := [fsBold];
  VisualStudioRadioButton.Font.Size := 9;
  VisualStudioRadioButton.Caption := 'Visual Studio'
  PartDescLabel := TLabel.Create(WizardForm);
  PartDescLabel.Parent := CustomPage.Surface;
  PartDescLabel.Left := 8;
  PartDescLabel.Top := VisualStudioRadioButton.Top + VisualStudioRadioButton.Height + 8;
  PartDescLabel.Width := CustomPage.SurfaceWidth;
  PartDescLabel.Height := 24;
  PartDescLabel.AutoSize := False;
  PartDescLabel.Wordwrap := True;
  PartDescLabel.Caption := 'This option will select the CMake executable from the Visual Studio distribution.';

  if not FileExists(VisualStudioCMakePath + '\cmake.exe') then begin
    VisualStudioRadioButton.Enabled := False
    PartDescLabel.Enabled := False
  end
  else begin
    if CheckNext then begin
      VisualStudioRadioButton.Checked := True;
      CheckNext := False;
    end;
  end;

  ChoosePathRadioButton := TNewRadioButton.Create(WizardForm);
  ChoosePathRadioButton.Parent := CustomPage.Surface;
  ChoosePathRadioButton.Top := PartDescLabel.Top + PartDescLabel.Height + 16;
  ChoosePathRadioButton.Width := CustomPage.SurfaceWidth;
  ChoosePathRadioButton.Font.Style := [fsBold];
  ChoosePathRadioButton.Font.Size := 9;
  ChoosePathRadioButton.Caption := 'Select Path...'
  ChoosePathLabel := TLabel.Create(WizardForm);
  ChoosePathLabel.Parent := CustomPage.Surface;
  ChoosePathLabel.Left := 8;
  ChoosePathLabel.Top := ChoosePathRadioButton.Top + ChoosePathRadioButton.Height + 8;
  ChoosePathLabel.Width := CustomPage.SurfaceWidth;
  ChoosePathLabel.Height := 24;
  ChoosePathLabel.AutoSize := False;
  ChoosePathLabel.Wordwrap := True;
  ChoosePathLabel.Caption := 'This option will prompt you to select the CMake bin directory';
  
  if CheckNext then begin
    ChoosePathRadioButton.Checked := True;
    CheckNext := False;
  end;
     
  FigureOutRadioButton := TNewRadioButton.Create(WizardForm);
  FigureOutRadioButton.Parent := CustomPage.Surface;
  FigureOutRadioButton.Top := ChoosePathLabel.Top + ChoosePathLabel.Height + 16;
  FigureOutRadioButton.Width := CustomPage.SurfaceWidth;
  FigureOutRadioButton.Caption := 'I''ll figure it out' 
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  { initialize result to not skip any page (not necessary, but safer) }
  Result := False;

  { if the page that is asked to be skipped is your custom page, then... }
  if PageID = CMakePathPage.ID then begin
    { if the component is not selected, skip the page }
    Result := not ChoosePathRadioButton.Checked;
  end;
end;

procedure AfterInstallPkgScript();
begin
  if CMakeInstallationRadioButton.Checked then begin
    CMakePathData := '`cygpath -u "' + CMakeDefaultPath + '"`'
  end
  else begin
    if VisualStudioRadioButton.Checked then begin
      CMakePathData := '`cygpath -u "' + VisualStudioCMakePath + '"`'
    end
    else begin
      if ChoosePathRadioButton.Checked then begin
        CMakePathData := '`cygpath -u "' + CMakePathPage.Values[0] + '"`'
      end;
    end;
  end;
  Log('CMakePathData: ' + CMakePathData);
  FileReplaceString(ExpandConstant('{app}') + '\bin\subgine-pkg', '{%CMAKEPATH%}', CMakePathData)
end;

[Files]
Source: "subgine-pkg"; DestDir: "{app}\bin"; Components: subgine_pkg; AfterInstall: AfterInstallPkgScript
Source: "subgine-pkg.cmake"; DestDir: "{app}\bin"; Components: subgine_pkg

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}\bin"; \
    Check: NeedsAddPath('{app}\bin'); Components: subgine_pkg\path 

[UninstallDelete]
Type: files; Name: "{app}\bin\subgine-pkg"
