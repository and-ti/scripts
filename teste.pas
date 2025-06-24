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
    procedure lyPaiFundoPainting(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
    procedure FormShow(Sender: TObject);
  private
    // NOVO: Procedimento centralizado para atualizar o cabeçalho.
    procedure UpdateHeaderInfo(const AActiveLayout: TLayout);
    procedure ChildFormOnClose(Sender: TObject; var Action: TCloseAction);
    procedure TaskBarButtonClick(Sender: TObject);
    procedure ShowChildForm(FormClass: TFormClass);
    function FindChildForm(FormClass: TFormClass): TForm;
    function FindChildLayout(Parent: TComponent): TLayout;
    procedure CriaBotao(Form: TForm);
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
    // ALTERADO: A atualização do header agora é chamada aqui, de forma otimizada.
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

// ALTERADO: Removido o uso de TThread + Sleep.
procedure TMainForm.ChildFormClose(Sender: TObject);
var
  I: Integer;
  ly: TLayout;
  frm: TCommonCustomForm;
  Anim: TFloatAnimation;
begin
  for I := lyPai.ChildrenCount - 1 downto 0 do
  begin
    // Pega o layout que está no topo (visível)
    ly  := TLayout(lyPai.Children[I]);
    frm := TCommonCustomForm(ly.TagObject);

    // Inicia a animação de fade-out
    Anim := TAnimator.AnimateFloat(ly, 'Opacity', 0, 0.3, TAnimationType.Out, TInterpolationType.Quadratic);

    // Usa o evento OnFinish da animação para fechar o form de forma segura.
    Anim.OnFinish := procedure(Sender: TObject)
    begin
      frm.Close;
    end;

    lyPai.Repaint;
    Exit;
  end;
end;

// ALTERADO: Removido o uso de TThread + Sleep.
procedure TMainForm.ChildFormMinimize(Sender: TObject);
var
  I: Integer;
  ly: TLayout;
  Anim: TFloatAnimation;
begin
  for I := lyPai.ChildrenCount - 1 downto 0 do
  begin
    ly := TLayout(lyPai.Children[I]);
    ly.Align := TAlignLayout.None;
    ly.TagFloat := MainForm.Height;

    TAnimator.AnimateFloat(ly, 'Opacity', 0, 0.3, TAnimationType.Out, TInterpolationType.Quadratic);
    // Anima a posição para "minimizar" para baixo
    Anim := TAnimator.AnimateFloat(ly, 'Position.Y', MainForm.Height, 0.3);

    // Usa o evento OnFinish da animação para esconder o layout.
    Anim.OnFinish := procedure(Sender: TObject)
    begin
      ly.SendToBack;
      ly.Visible := False;
      lyPai.Repaint;
    end;

    Exit;
  end;
end;

// ALTERADO: A lógica foi movida para o procedimento 'UpdateHeaderInfo'.
// Este evento agora está vazio, melhorando a performance.
procedure TMainForm.lyPaiFundoPainting(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
begin
  // A lógica foi movida para UpdateHeaderInfo para evitar chamadas excessivas.
end;

// ALTERADO: Removido o uso de TThread + Sleep.
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

    // A animação de Opacidade é sempre executada.
    TAnimator.AnimateFloat(lyFilho, 'Opacity', 1, 0.3);

    if not (lyFilho.TagFloat = 0) then
    begin
      // Se o form estava minimizado, anima sua posição de volta para o topo.
      lyFilho.Position.Y := lyFilho.TagFloat;
      Anim := TAnimator.AnimateFloat(lyFilho, 'Position.Y', 0, 0.3);

      // O código de finalização será executado após a animação de posição.
      Anim.OnFinish := procedure(Sender: TObject)
      begin
        if lyFilho.Align = TAlignLayout.None then
          lyFilho.Align := TAlignLayout.Client;
        lyFilho.TagFloat := 1;
      end;
    end
    else
    begin
      // Se não houve animação de posição, o alinhamento já pode ser ajustado
      // pois o form já estava "aberto", apenas em segundo plano.
      if lyFilho.Align = TAlignLayout.None then
        lyFilho.Align := TAlignLayout.Client;
      lyFilho.TagFloat := 1;
    end;

    // ALTERADO: A atualização do header agora é chamada aqui.
    UpdateHeaderInfo(lyFilho);
    lyPai.Repaint;
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

// NOVO: Procedimento para centralizar a lógica de atualização do cabeçalho.
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
