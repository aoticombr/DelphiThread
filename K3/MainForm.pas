(**************************************************************************
 Thread Manager - Kylix 3 version
 by Guinther de Bitencourt Pauli - ClubeDelphi  - Brazil
 guinther@clubedelphi.com.br
 Last Update in 11/03/2003
 Please send me your comment, sugestion or bug report
**************************************************************************)
unit MainForm;
(**************************************************************************)
interface
(**************************************************************************)
uses
  SysUtils, Types, Classes, Variants, QTypes, QGraphics, QControls, QForms,
  QDialogs, QStdCtrls, QActnList, QImgList, DB, DBClient, QExtCtrls,
  QButtons, QComCtrls, QGrids, QDBGrids, QDBCtrls, SyncObjs;
(**************************************************************************)
const
  ProgColor1 = $00804000;
  ProgColor2 = $00FFA74F;
  ProgColor3 = $00FFE1C4;
type
(**************************************************************************)
  TSyncObjMethod = (smNull,smNoSync,smVCLCriticalSection);
  TThreadStatus = (tsRunning,tsSuspended,tsWaiting,tsTerminated);
(**************************************************************************)
 TMyGrid = class (TDBGrid);
 TMainFrm = class(TForm)
    cds_threads: TClientDataSet;
    ds_threads: TDataSource;
    DBGridThreads: TDBGrid;
    RdGrpPriority: TRadioGroup;
    StatusBarThreads: TStatusBar;
    ImageListThreads: TImageList;
    cds_threadsTHREAD_ID: TStringField;
    cds_threadsNR_THREADS: TAggregateField;
    Label1: TLabel;
    DBText1: TDBText;
    ChckBxSuspended: TCheckBox;
    cds_threadsTHREAD_DATA: TIntegerField;
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    BitBtn3: TBitBtn;
    BtnCreateSync: TBitBtn;
    BtnCreateThread: TBitBtn;
    ActionListThreads: TActionList;
    BtnResetApp: TBitBtn;
    CreateSyncObject: TAction;
    CreateThread: TAction;
    ResetApplication: TAction;
    ResumeAll: TAction;
    SuspendAll: TAction;
    TerminateAll: TAction;
    RdGrpSync: TRadioGroup;
    Label2: TLabel;
    LblThreadsDone: TLabel;
    Label3: TLabel;
    Panel1: TPanel;
    Label7: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    SpeedButton1: TSpeedButton;
    Image1: TImage;
    Label8: TLabel;
    Label6: TLabel;
    Panel2: TPanel;
    Label9: TLabel;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure DBGridThreadsDrawColumnCell(Sender: TObject; const Rect: TRect;
      DataCol: Integer; Column: TColumn; State: TGridDrawState);
    procedure ResumeAllExecute(Sender: TObject);
    procedure TerminateAllExecute(Sender: TObject);
    procedure SuspendAllExecute(Sender: TObject);
    procedure UpdateAll(Sender: TObject);
    procedure ResetApplicationExecute(Sender: TObject);
    procedure CreateSyncObjectExecute(Sender: TObject);
    procedure CreateSyncObjectUpdate(Sender: TObject);
    procedure CreateThreadUpdate(Sender: TObject);
    procedure CreateThreadExecute(Sender: TObject);
    procedure ResetApplicationUpdate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure DBGridThreadsColEnter(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
  private
    { Private declarations }
  public
     procedure RelaseSyncObjs;
    { Public declarations }
  end;
(**************************************************************************)
  // only for display, in Linux priority is an integer
  TThreadPriority = (tpIdle, tpLowest, tpLower, tpNormal, tpHigher, tpHighest,
    tpTimeCritical);
(**************************************************************************)
  TMyThread = class (TThread)
  protected
     procedure Suspend;
     procedure terminate;
     procedure Resume;
  public
    Prioridade : TThreadPriority;
    TempoRestante : integer;
    ThreadStatus  : TThreadStatus;
    constructor Create (CreateSuspended : boolean);
    procedure AtualizarGrid;
    procedure DoTimer;
    procedure MyThreadExit(sender : TObject);
    procedure Execute; override;
  end;
(**************************************************************************)
var
  MainFrm: TMainFrm; // form
  MyMutexHandle : THandle;  // mutex
  MyCS : TCriticalSection; // VCL Critical Section
  MySemaphoreHandle : THandle; // Semaphore
  SyncObjMethod : TSyncObjMethod; // customized type
  ThreadStatusDesc : array [TThreadStatus] of string = ('Running','Suspended','Waiting','Terminated');
(**************************************************************************)
implementation
(**************************************************************************)
uses
   TypInfo, math, uAbout;
(**************************************************************************)
{$R *.xfm}
(*********************************************************************)
(* synchoronized method, refresh the VCL object DBGRID *)
procedure TMyThread.AtualizarGrid;
begin
  with MainFrm.cds_threads do
  begin
    (* this is a new thread *)
    if not Locate('THREAD_ID',inttostr(ThreadID),[]) then
    begin
      append;
      fieldbyname('THREAD_DATA').Asinteger:=integer(self); //pointer to thread
      fieldbyname('THREAD_ID').Asstring:=inttostr(ThreadID);
      post;
    end
    else
    begin
      (* update thread status in clientdataset*)
      if (TempoRestante=-1) or //thread done ok
         (terminated) then 
         Delete
      else
      begin
        edit;
        if TempoRestante=0 then
           ThreadStatus:=tsTerminated
        else
           if not suspended then
              ThreadStatus:=tsRunning;
         post;
      end;
    end;
  end;
end;
(*********************************************************************)
(* constructor *)
constructor TMyThread.create(CreateSuspended: boolean);
begin
  inherited create(CreateSuspended);
  FreeOnTerminate:=true;  
  if CreateSuspended then
     ThreadStatus:=tsSuspended
  else
    ThreadStatus:=tsWaiting;
  TempoRestante:=10;
  Prioridade:=TThreadPriority(MainFrm.RdGrpPriority.ItemIndex); 
  Synchronize(AtualizarGrid);
end;
(*********************************************************************)
(* main execute method *)
procedure TMyThread.DoTimer;
begin
  repeat
     if terminated then
        exit;
     ThreadStatus:=tsRunning;
     Synchronize(AtualizarGrid);
     TempoRestante:=TempoRestante-1;
     sleep(1000);
   until TempoRestante<-1;
end;
(*********************************************************************)
procedure TMyThread.Execute;
begin
 OnTerminate:=MyThreadExit;
 case SyncObjMethod of
   smVCLCriticalSection : begin
      MyCS.Enter;
      DoTimer;
      MyCS.Leave;
   end;
   smNoSync : DoTimer;
 end;
end;
(*********************************************************************)
procedure TMainFrm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  while not cds_threads.IsEmpty do
    TMyThread(cds_threads.fieldbyname('THREAD_DATA').AsInteger).terminate;
  RelaseSyncObjs;
end;
(*********************************************************************)
procedure TMainFrm.DBGridThreadsDrawColumnCell(Sender: TObject;
  const Rect: TRect; DataCol: Integer; Column: TColumn;
  State: TGridDrawState);
var
 BarWidth : integer;
 NewRect  : TRect;
 TD : TMyThread;
begin
   if not Column.Field.IsNull then
   begin
      NewRect:=rect;
      DBGridThreads.Canvas.Brush.Color:=clWindow;
      DBGridThreads.Canvas.FillRect(Rect);
      TD:=TMyThread(cds_threads.FieldByName('THREAD_DATA').AsInteger);
      if Column.Index in [5..7] then // action cols
      begin
         DBGridThreads.Canvas.Font.Style:=[fsunderline];
         DBGridThreads.Canvas.Font.color:=clblue;
      end;
      case Column.Index of
         0 : begin
               ImageListThreads.draw(dbgridThreads.canvas,rect.left,rect.top,11);
               DBGridThreads.Canvas.TextOut(Rect.Left+18,Rect.Top,format('$%.*X',[8,td.Threadid]));
             end;
         1 : begin
                 ImageListThreads.draw(dbgridThreads.canvas,rect.left,rect.top,integer(TD.Prioridade)+4);
                 dbgridThreads.Canvas.TextOut(rect.left+18,rect.Top,
                   GetEnumName(TypeInfo(TThreadPriority),integer(TD.Prioridade)));
             end;
         2 : begin
               case TD.ThreadStatus of
                  tsRunning : ImageListThreads.draw(dbgridThreads.canvas,rect.left,rect.top,0);
                  tsWaiting : ImageListThreads.draw(dbgridThreads.canvas,rect.left,rect.top,20{1});
                  tsTerminated : ImageListThreads.draw(dbgridThreads.canvas,rect.left,rect.top,19{2});
                  tsSuspended : ImageListThreads.draw(dbgridThreads.canvas,rect.left,rect.top,3);
               end;
               dbgridThreads.Canvas.TextOut(rect.left+18,rect.Top,ThreadStatusDesc[TD.ThreadStatus]);
             end;
         3 :  dbgridThreads.Canvas.TextOut(rect.left,rect.top,inttostr(TD.TempoRestante));
         4 :  begin
               if td.TempoRestante>7 then
                  DBGridThreads.Canvas.Brush.Color:=ProgColor1
               else
                  if td.TempoRestante>3 then
                     DBGridThreads.Canvas.Brush.Color:=ProgColor2
                  else
                     if td.TempoRestante>0 then
                        DBGridThreads.Canvas.Brush.Color:=ProgColor3;
               BarWidth:=NewRect.Right-NewRect.Left;
               BarWidth:=trunc(BarWidth*(td.TempoRestante/10));
               NewRect.Right:=NewRect.Left+BarWidth;
               DBGridThreads.Canvas.FillRect(NewRect);
            end;
         5 : if TD.ThreadStatus in [tsRunning,tsWaiting,tsSuspended] then
                DBGridThreads.Canvas.TextOut(Rect.Left+5,Rect.Top,'Kill');
         6 : if TD.ThreadStatus=tsRunning then
                DBGridThreads.Canvas.TextOut(Rect.Left,Rect.Top,'Suspend');
         7 : if TD.ThreadStatus=tsSuspended then
                DBGridThreads.Canvas.TextOut(Rect.Left,Rect.Top,'Resume');
         8..14 : if integer(td.Prioridade)=Column.Index-8 then
                    ImageListThreads.draw(dbgridThreads.canvas,rect.left+1,rect.top,integer(td.Prioridade)+12);
       end;
   end;
end;
(*********************************************************************)
procedure TMyThread.MyThreadExit;
begin
   (* Is not necessary to synchronize this method because it is called
     by MainThread*)
  MainFrm.LblThreadsDone.Caption:=
  inttostr(strtoint(MainFrm.LblThreadsDone.Caption)+1);
end;
(*********************************************************************)
procedure TMainFrm.RelaseSyncObjs;
begin
 case SyncObjMethod of
   smVCLCriticalSection : MyCS.free;
 end;
 SyncObjMethod:=smNull;
end;
(*********************************************************************)
procedure TMyThread.Resume;
begin
  inherited;
  ThreadStatus:=tsSuspended;
  Synchronize(AtualizarGrid);
end;
(*********************************************************************)
procedure TMyThread.Suspend;
begin
  inherited Suspend;
  ThreadStatus:=tsSuspended;
  Synchronize(AtualizarGrid);
end;
(*********************************************************************)
procedure TMyThread.terminate;
begin
  inherited;
  ThreadStatus:=tsTerminated;
  Synchronize(AtualizarGrid);
end;
(*********************************************************************)
procedure TMainFrm.ResumeAllExecute(Sender: TObject);
begin
  cds_threads.First;
  while not cds_threads.eof do
  begin
      TMyThread(cds_threads.fieldbyname('THREAD_DATA').AsInteger).Resume;
      cds_threads.next;
  end;
end;
(*********************************************************************)
procedure TMainFrm.TerminateAllExecute(Sender: TObject);
begin
  while not cds_threads.IsEmpty do
    TMyThread(cds_threads.fieldbyname('THREAD_DATA').AsInteger).terminate;
end;
(*********************************************************************)
procedure TMainFrm.SuspendAllExecute(Sender: TObject);
begin
  cds_threads.First;
  while not cds_threads.eof do
  begin
      TMyThread(cds_threads.fieldbyname('THREAD_DATA').AsInteger).Suspend;
      cds_threads.next;
  end;
end;
(*********************************************************************)
procedure TMainFrm.UpdateAll(Sender: TObject);
begin
 (sender as TAction).Enabled:=cds_threads.RecordCount>0;
end;
(*********************************************************************)
procedure TMainFrm.ResetApplicationExecute(Sender: TObject);
begin
   RelaseSyncObjs;
   LblThreadsDone.Caption:='0';
end;
(*********************************************************************)
procedure TMainFrm.CreateSyncObjectExecute(Sender: TObject);
begin
   StatusBarThreads.SimpleText:=
     'Synchronization Object : '+RdGrpSync.Items[RdGrpSync.Itemindex];
   SyncObjMethod:=TSyncObjMethod(RdGrpSync.ItemIndex+1);
   (* create the sync object *)
   case SyncObjMethod of
     smVCLCriticalSection : MyCS:=TCriticalSection.create;
   end;
end;
(*********************************************************************)
procedure TMainFrm.CreateSyncObjectUpdate(Sender: TObject);
begin
 (sender as TAction).Enabled:=
    (RdGrpSync.ItemIndex>=0) and
    (SyncObjMethod=smNull);
  RdGrpSync.Enabled:=SyncObjMethod=smNull;
end;
(*********************************************************************)
procedure TMainFrm.CreateThreadUpdate(Sender: TObject);
begin
 (sender as TAction).Enabled:=SyncObjMethod<>smNull;
 RdGrpPriority.Enabled:=SyncObjMethod<>smNull;
 ChckBxSuspended.Enabled:=(sender as TAction).Enabled;
end;
(*********************************************************************)
procedure TMainFrm.CreateThreadExecute(Sender: TObject);
begin
 if cds_threads.RecordCount<10 then
 begin
   StatusBarThreads.SimpleText:='Thread was created. You can create more threads.';
   TMyThread.create(ChckBxSuspended.Checked);
 end
 else
   StatusBarThreads.SimpleText:='Thread limit = 10';
end;
(*********************************************************************)
procedure TMainFrm.ResetApplicationUpdate(Sender: TObject);
begin
 (sender as TAction).Enabled:=
  (cds_threads.RecordCount=0) and (SyncObjMethod<>smNull);
end;
(*********************************************************************)
procedure TMainFrm.FormShow(Sender: TObject);
begin
  SyncObjMethod:=smNull;
end;
(*********************************************************************)
procedure TMainFrm.DBGridThreadsColEnter(Sender: TObject);
var
 MT : TMyThread;
begin
   if not cds_threads.FieldByName('THREAD_DATA').isnull then
   begin
       MT:=TMyThread(cds_threads.FieldByName('THREAD_DATA').asinteger);
       case DBGridThreads.SelectedIndex of
          5 : begin
                MT.resume;
                MT.Terminate;
              end;
          6 : MT.Suspend;
          7 : MT.Resume;
          (* change priority *)
          8..14 : begin
                     MT.Prioridade:=TThreadPriority(DBGridThreads.SelectedIndex-8);
                     if mt.Suspended then
                        mt.AtualizarGrid;
                  end;
       end;
   end;
   DBGridThreads.SelectedIndex:=0;
   if BtnCreateThread.enabled then
      BtnCreateThread.SetFocus;
end;
(*********************************************************************)

procedure TMainFrm.SpeedButton1Click(Sender: TObject);
begin
  Application.CreateForm(TAbout, About);
  try
    About.ShowModal;
  finally
    About.Free;
  end;
end;

end.
