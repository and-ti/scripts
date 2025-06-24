unit frm_Main;

interface

uses
  FMX.Forms, FMX.Controls, FMX.Layouts, FMX.StdCtrls,
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Dialogs, FMX.Controls.Presentation,
  System.Generics.Collections, FMX.Ani,
  frm_1, frm_2, frm_3, FMX.Objects, frm_filho_header, frm_home;

type
  TTaskBarButton = record
    Form: TCommonCustomForm;
    Button: TSpeedButton;
  end;

var
  TaskBarList: TList<TTaskBarButton>;

type
  TFormClass = class of TForm;
  TMainForm = class(TForm)
    bar_NavBar: TToolBar;
    fly_FormsAbertos: TFlowLayout;
    bt_Form1: TButton;
    bt_Form2: TButton;
    bt_Form3: TButton;
    lyPaiFundo: TLayout;
    lyHeader: TLayout;
    imgFechar: TImage;
    imgMinimizar: TImage;
    lbSubTitulo: TLabel;
    lbTitulo: TLabel;
    lyPai: TLayout;
    lyHeaderAcoes: TLayout;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure bt_Form1Click(Sender: TObject);
    procedure bt_Form2Click(Sender: TObject);
    procedure bt_Form3Click(Sender: TObject);
    procedure ChildFormClose(Sender: TObject);
    procedure ChildFormMinimize(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    procedure UpdateHeaderInfo(const AActiveLayout: TLayout);
    procedure ChildFormOnClose(Sender: TObject; var Action: TCloseAction);
    procedure TaskBarButtonClick(Sender: TObject);
    procedure ShowChildForm(FormClass: TFormClass);
    function FindChildForm(FormClass: TFormClass): TForm;
    function FindChildLayout(Parent: TComponent): TLayout;
    procedure CriaBotao(Form: TForm);
    procedure CloseAnimationFinish(Sender: TObject);
    procedure MinimizeAnimationFinish(Sender: TObject);
    procedure RestoreAnimationFinish(Sender: TObject);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  TaskBarList := TList<TTaskBarButton>.Create;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  TaskBarList.Free;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  lyHeader.Width := lyPai.Width;
  ShowChildForm(TfrmHome);
end;

procedure TMainForm.bt_Form1Click(Sender: TObject);
begin
  ShowChildForm(TForm1);
end;

procedure TMainForm.bt_Form2Click(Sender: TObject);
begin
  ShowChildForm(TForm2);
end;

procedure TMainForm.bt_Form3Click(Sender: TObject);
begin
  ShowChildForm(TForm3);
end;

function TMainForm.FindChildForm(FormClass: TFormClass): TForm;
var
  TaskButton: TTaskBarButton;
begin
  for TaskButton in TaskBarList do
    if TaskButton.Form.ClassType = FormClass then
      Exit(TForm(TaskButton.Form));
  Result := nil;
end;

procedure TMainForm.ShowChildForm(FormClass: TFormClass);
var
  FormFilho: TForm;
  lyFilho: TLayout;
begin
  FormFilho := FindChildForm(FormClass);
  if not Assigned(FormFilho) then
  begin
    FormFilho := FormClass.Create(Application);
    CriaBotao(FormFilho);
    FormFilho.OnClose := ChildFormOnClose;
  end;

  if (FormFilho.ClassName = lyPai.TagString) then
    Exit;

  lyFilho := FindChildLayout(FormFilho);
  if Assigned(lyFilho) then
  begin
    if lyFilho.Parent <> lyPai then
      lyFilho.Parent := lyPai;

    lyFilho.TagObject := FormFilho;
    lyFilho.TagString := FormFilho.Caption;
    lyFilho.Visible   := True;
    lyFilho.Opacity   := 0;
    lyFilho.BringToFront;

    if (lyFilho.TagFloat = 0) then
    begin
      lyFilho.Scale.Y := 0;
      TAnimator.AnimateFloat(lyFilho, 'Scale.Y', 1, 0.3);
      TAnimator.AnimateFloat(lyFilho, 'Opacity', 1, 0.3);
    end
    else if (lyFilho.TagFloat = 1) then
    begin
      TAnimator.AnimateFloat(lyFilho, 'Opacity', 1, 0.3);
    end
    else if (lyFilho.TagFloat > 1) then
    begin
      lyFilho.Position.Y := lyFilho.TagFloat;
      TAnimator.AnimateFloat(lyFilho, 'Position.Y', 0, 0.3);
      TAnimator.AnimateFloat(lyFilho, 'Opacity', 1, 0.3);
    end;

    lyFilho.TagFloat := 1;
    UpdateHeaderInfo(lyFilho);
    lyPai.Repaint;
  end;
end;

procedure TMainForm.CriaBotao(Form: TForm);
var
  BTN: TTaskBarButton;
begin
  BTN.Form := Form;
  BTN.Button := TSpeedButton.Create(fly_FormsAbertos);
  with BTN.Button do
  begin
    Parent := fly_FormsAbertos;
    Text := Form.Caption;
    TagObject := Form;
    OnClick := TaskBarButtonClick;
  end;
  TaskBarList.Add(BTN);
end;

procedure TMainForm.ChildFormOnClose(Sender: TObject; var Action: TCloseAction);
var
  I: Integer;
  Frm: TCommonCustomForm;
begin
  Frm := TCommonCustomForm(Sender);
  for I := TaskBarList.Count - 1 downto 0 do
    if TaskBarList[I].Form = Frm then
    begin
      TaskBarList[I].Button.Free;
      TaskBarList.Delete(I);
      Frm := nil;
      Break;
    end;
  Action := TCloseAction.caFree;
end;

procedure TMainForm.ChildFormClose(Sender: TObject);
var
  I: Integer;
  ly: TLayout;
  frm: TCommonCustomForm;
  AnimOpacity, AnimScale: TFloatAnimation;
  LWidth, LHeight: Single;
begin
  for I := lyPai.ChildrenCount - 1 downto 0 do
  begin
    if (lyPai.Children[I] is TLayout) and (TLayout(lyPai.Children[I]).Visible) then
    begin
      ly  := TLayout(lyPai.Children[I]);
      frm := TCommonCustomForm(ly.TagObject);

      // --- INÍCIO DA CORREÇÃO ---
      // Pausa o gerenciamento de layout do pai
      lyPai.BeginUpdate;
      try
        // Desativa o Align para permitir a animação
        LWidth := ly.Width;
        LHeight := ly.Height;
        ly.Align := TAlignLayout.None;
        ly.Width := LWidth;
        ly.Height := LHeight;

        AnimOpacity := TFloatAnimation.Create(ly);
        AnimOpacity.Parent := ly;
        AnimOpacity.AnimationType := TAnimationType.Out;
        AnimOpacity.Interpolation := TInterpolationType.Quadratic;
        AnimOpacity.Duration := 0.3;
        AnimOpacity.PropertyName := 'Opacity';
        AnimOpacity.StopValue := 0;
        AnimOpacity.Start;

        AnimScale := TFloatAnimation.Create(ly);
        AnimScale.Parent := ly;
        AnimScale.AnimationType := TAnimationType.Out;
        AnimScale.Interpolation := TInterpolationType.Quadratic;
        AnimScale.Duration := 0.3;
        AnimScale.PropertyName := 'Scale.Y';
        AnimScale.StopValue := 0;

        AnimScale.Tag := NativeInt(frm);
        AnimScale.OnFinish := CloseAnimationFinish;
        AnimScale.Start;
      finally
        // Retoma o gerenciamento de layout
        lyPai.EndUpdate;
      end;
      // --- FIM DA CORREÇÃO ---

      lyPai.Repaint;
      Exit;
    end;
  end;
end;

procedure TMainForm.ChildFormMinimize(Sender: TObject);
var
  I: Integer;
  ly: TLayout;
  AnimPos, AnimOpacity: TFloatAnimation;
  LWidth, LHeight: Single;
begin
  for I := lyPai.ChildrenCount - 1 downto 0 do
  begin
    if (lyPai.Children[I] is TLayout) and (TLayout(lyPai.Children[I]).Visible) then
    begin
      ly := TLayout(lyPai.Children[I]);

      // --- INÍCIO DA CORREÇÃO ---
      // Pausa o gerenciamento de layout do pai
      lyPai.BeginUpdate;
      try
        // Desativa o Align para permitir a animação
        LWidth := ly.Width;
        LHeight := ly.Height;
        ly.Align := TAlignLayout.None;
        ly.Width := LWidth;
        ly.Height := LHeight;

        ly.TagFloat := MainForm.Height;

        AnimOpacity := TFloatAnimation.Create(ly);
        AnimOpacity.Parent := ly;
        AnimOpacity.AnimationType := TAnimationType.Out;
        AnimOpacity.Interpolation := TInterpolationType.Quadratic;
        AnimOpacity.Duration := 0.3;
        AnimOpacity.PropertyName := 'Opacity';
        AnimOpacity.StopValue := 0;
        AnimOpacity.Start;

        AnimPos := TFloatAnimation.Create(ly);
        AnimPos.Parent := ly;
        AnimPos.Duration := 0.3;
        AnimPos.PropertyName := 'Position.Y';
        AnimPos.StopValue := MainForm.Height;

        AnimPos.Tag := NativeInt(ly);
        AnimPos.OnFinish := MinimizeAnimationFinish;
        AnimPos.Start;
      finally
        // Retoma o gerenciamento de layout
        lyPai.EndUpdate;
      end;
      // --- FIM DA CORREÇÃO ---

      Exit;
    end;
  end;
end;

procedure TMainForm.TaskBarButtonClick(Sender: TObject);
var
  Btn: TSpeedButton;
  Frm: TCommonCustomForm;
  lyFilho: TLayout;
  Anim: TFloatAnimation;
begin
  Btn := Sender as TSpeedButton;
  Frm := TCommonCustomForm(Btn.TagObject);

  if (Frm.ClassName = lyPai.TagString) then
    Exit;

  lyFilho := FindChildLayout(Frm);
  if Assigned(lyFilho) then
  begin
    if lyFilho.Parent <> lyPai then
      lyFilho.Parent := lyPai;

    lyFilho.Visible := True;
    lyFilho.Opacity := 0;
    lyFilho.BringToFront;

    TAnimator.AnimateFloat(lyFilho, 'Opacity', 1, 0.3);

    if not (lyFilho.TagFloat = 0) then
    begin
      lyFilho.Position.Y := lyFilho.TagFloat;

      Anim := TFloatAnimation.Create(lyFilho);
      Anim.Parent := lyFilho;
      Anim.Duration := 0.3;
      Anim.PropertyName := 'Position.Y';
      Anim.StopValue := 0;

      Anim.Tag := NativeInt(lyFilho);
      Anim.OnFinish := RestoreAnimationFinish;
      Anim.Start;
    end
    else
    begin
      if lyFilho.Align = TAlignLayout.None then
        lyFilho.Align := TAlignLayout.Client;
      lyFilho.TagFloat := 1;
    end;

    UpdateHeaderInfo(lyFilho);
    lyPai.Repaint;
  end;
end;

procedure TMainForm.CloseAnimationFinish(Sender: TObject);
var
  Anim: TAnimation;
  frm: TCommonCustomForm;
  ClosingLayout, NewTopLayout: TLayout;
  I: Integer;
begin
  Anim := Sender as TAnimation;
  frm := TCommonCustomForm(TObject(Anim.Tag));

  if (Anim.Parent is TLayout) then
    ClosingLayout := TLayout(Anim.Parent)
  else
    ClosingLayout := nil;

  if Assigned(frm) then
    frm.Close;

  NewTopLayout := nil;
  for I := lyPai.ChildrenCount - 1 downto 0 do
  begin
    if (lyPai.Children[I] is TLayout) then
    begin
      if TObject(lyPai.Children[I]) = TObject(ClosingLayout) then
        Continue;

      if (TLayout(lyPai.Children[I]).Visible) then
      begin
        NewTopLayout := TLayout(lyPai.Children[I]);
        break;
      end;
    end;
  end;

  if Assigned(NewTopLayout) then
    UpdateHeaderInfo(NewTopLayout);

  lyPai.Repaint;
end;

procedure TMainForm.MinimizeAnimationFinish(Sender: TObject);
var
  Anim: TAnimation;
  ly, NewTopLayout: TLayout;
  I: Integer;
begin
  Anim := Sender as TAnimation;
  ly := TLayout(TObject(Anim.Tag));
  if Assigned(ly) then
  begin
    ly.SendToBack;
    ly.Visible := False;

    NewTopLayout := nil;
    for I := lyPai.ChildrenCount - 1 downto 0 do
    begin
      if (lyPai.Children[I] is TLayout) and (TLayout(lyPai.Children[I]).Visible) then
      begin
        NewTopLayout := TLayout(lyPai.Children[I]);
        break;
      end;
    end;

    if Assigned(NewTopLayout) then
      UpdateHeaderInfo(NewTopLayout);

    lyPai.Repaint;
  end;
end;

procedure TMainForm.RestoreAnimationFinish(Sender: TObject);
var
  Anim: TAnimation;
  ly: TLayout;
begin
  Anim := Sender as TAnimation;
  ly := TLayout(TObject(Anim.Tag));
  if Assigned(ly) then
  begin
    if ly.Align = TAlignLayout.None then
      ly.Align := TAlignLayout.Client;
    ly.TagFloat := 1;
  end;
end;

function TMainForm.FindChildLayout(Parent: TComponent): TLayout;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(Parent) then
    Exit;
  for I := 0 to Parent.ComponentCount - 1 do
  begin
    if (Parent.Components[I] is TLayout) then
      if (SameText(Parent.Components[I].Name, 'lyConteudo')) then
      begin
        Result := TLayout(Parent.Components[I]);
        Exit;
      end;
  end;
end;

procedure TMainForm.UpdateHeaderInfo(const AActiveLayout: TLayout);
var
  ChildForm: TForm;
begin
  if not Assigned(AActiveLayout) then
    Exit;

  lbTitulo.Text := AActiveLayout.TagString;

  if AActiveLayout.TagObject is TForm then
  begin
    ChildForm := TForm(AActiveLayout.TagObject);
    lbSubTitulo.Text := ChildForm.ClassName;
    lyPai.TagString := ChildForm.ClassName;

    if (lyPai.ChildrenCount > 1) and (not (ChildForm is TfrmHome)) and (lyHeaderAcoes.Scale.Y = 0) then
      TAnimator.AnimateFloat(lyHeaderAcoes, 'Scale.Y', 1, 0.3)
    else if (lyHeaderAcoes.Scale.Y = 1) and (ChildForm is TfrmHome) then
      TAnimator.AnimateFloat(lyHeaderAcoes, 'Scale.Y', 0, 0.3);
  end;
end;

end.
