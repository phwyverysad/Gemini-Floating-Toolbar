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
  LocalZipPath: String;
  AppDir: String;
  ResultCode: Integer;
  Cmd: String;
  Downloaded: Boolean;
begin
  Result := True;
  if CurPageID = wpReady then
  begin
    AppDir := ExpandConstant('{app}');
    ZipPath := ExpandConstant('{tmp}\Gemini-Portable.zip');
    LocalZipPath := ExtractFileDir(ExpandConstant('{srcexe}')) + '\Gemini-Portable.zip';
    Downloaded := False;

    // 1. Check if Gemini-Portable.zip exists in the same folder as the installer
    if FileExists(LocalZipPath) then
    begin
      WizardForm.StatusLabel.Caption := 'พบไฟล์แพ็กเกจในเครื่อง กำลังติดตั้ง...';
      FileCopy(LocalZipPath, ZipPath, False);
      Downloaded := True;
    end
    else
    begin
      // 2. Download from GitHub Releases
      DownloadPage.Clear;
      DownloadPage.Add('{#DownloadURL}', 'Gemini-Portable.zip', '');
      DownloadPage.Show;
      try
        try
          DownloadPage.Download;
          Downloaded := True;
        except
          if DownloadPage.AbortedByUser then
            Log('Download aborted by user.')
          else
          begin
            MsgBox('เกิดข้อผิดพลาดในการดาวน์โหลด: ' + GetExceptionMessage + #13#10 + #13#10 +
                   'คำแนะนำ:' + #13#10 +
                   '1. ตรวจสอบว่าได้เผยแพร่ GitHub Release ที่ https://github.com/phwyverysad/Gemini-Floating-Toolbar/releases แล้วหรือไม่' + #13#10 +
                   '2. หรือใช้งานไฟล์เดี่ยว dist\Gemini_Portable.exe หรือตัวติดตั้งออฟไลน์ dist\Gemini_Setup.exe ได้ทันทีโดยไม่ต้องดาวน์โหลด', mbError, MB_OK);
            Result := False;
          end;
        end;
      finally
        DownloadPage.Hide;
      end;
    end;

    if Downloaded and FileExists(ZipPath) then
    begin
      // Extract downloaded or local zip package directly into installation folder
      WizardForm.StatusLabel.Caption := 'กำลังติดตั้งไฟล์ลงใน ' + AppDir + '...';
      Cmd := Format('-NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path ''%s'' -DestinationPath ''%s'' -Force"', [ZipPath, AppDir]);
      
      if not Exec('powershell.exe', Cmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) or (ResultCode <> 0) then
      begin
        MsgBox('ไม่สามารถแตกไฟล์ติดตั้งได้ กรุณาตรวจสอบพื้นที่ดิสก์หรือสิทธิ์การเขียนไฟล์', mbError, MB_OK);
        Result := False;
      end;
    end;
  end;
end;
