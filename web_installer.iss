; Inno Setup Script for Google Gemini Desktop (Ultra-Lightweight Web Installer)
#define MyAppName "Google Gemini"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Gemini Desktop Project"
#define MyAppURL "https://github.com/phwyverysad/Gemini-Floating-Toolbar"
#define MyAppExeName "Gemini.exe"
#define DownloadURL "https://github.com/phwyverysad/Gemini-Floating-Toolbar/releases/latest/download/Gemini-Portable.zip"

[Setup]
; App Identity
AppId={{C7B42D15-18FA-4A73-A3FE-E1389D3CF4A1}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Installation Paths
DefaultDirName={commonpf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog commandline

; Output Configuration
OutputDir=dist
OutputBaseFilename=Gemini_WebSetup
SetupIconFile=resources\app.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Compression
Compression=lzma2/ultra64
SolidCompression=yes
InternalCompressLevel=ultra

; Modern UI Style
WizardStyle=modern
DisableProgramGroupPage=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "thai"; MessagesFile: "compiler:Languages\Thai.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Only embed the uninstaller helper and icon in the web setup stub to keep file size minimal (< 1.5MB)
Source: "resources\app.ico"; DestDir: "{app}\resources"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  DownloadPage: TDownloadWizardPage;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if ProgressMax > 0 then
    WizardForm.StatusLabel.Caption := Format('กำลังดาวน์โหลด Google Gemini... (%.1f MB / %.1f MB)', [Progress / 1048576.0, ProgressMax / 1048576.0])
  else
    WizardForm.StatusLabel.Caption := 'กำลังดาวน์โหลด Google Gemini...';
  Result := True;
end;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(
    'กำลังดาวน์โหลดแพ็กเกจโปรแกรม (Downloading Package)',
    'โปรแกรมติดตั้งกำลังดาวน์โหลดไฟล์ Gemini Desktop เวอร์ชันล่าสุดจากเซิร์ฟเวอร์...',
    @OnDownloadProgress
  );
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  ZipPath: String;
  AppDir: String;
  ResultCode: Integer;
  Cmd: String;
begin
  Result := True;
  if CurPageID = wpReady then
  begin
    ZipPath := ExpandConstant('{tmp}\Gemini-Portable.zip');
    AppDir := ExpandConstant('{app}');
    
    DownloadPage.Clear;
    DownloadPage.Add('{#DownloadURL}', 'Gemini-Portable.zip', '');
    DownloadPage.Show;
    try
      try
        DownloadPage.Download;
        
        // Extract downloaded zip package directly into installation folder
        WizardForm.StatusLabel.Caption := 'กำลังติดตั้งไฟล์ลงใน ' + AppDir + '...';
        Cmd := Format('-NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path ''%s'' -DestinationPath ''%s'' -Force"', [ZipPath, AppDir]);
        
        if not Exec('powershell.exe', Cmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) or (ResultCode <> 0) then
        begin
          MsgBox('ไม่สามารถแตกไฟล์ติดตั้งได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต', mbError, MB_OK);
          Result := False;
        end;
      except
        if DownloadPage.AbortedByUser then
          Log('Download aborted by user.')
        else
          MsgBox('เกิดข้อผิดพลาดในการดาวน์โหลด: ' + GetExceptionMessage, mbError, MB_OK);
        Result := False;
      end;
    finally
      DownloadPage.Hide;
    end;
  end;
end;
