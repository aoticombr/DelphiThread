program MultiThreadDemo;

uses
  QForms,
  MainForm in 'MainForm.pas' {MainFrm},
  uAbout in 'uAbout.pas' {About};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainFrm, MainFrm);
  Application.CreateForm(TAbout, About);
  Application.Run;
end.
