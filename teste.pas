unit uFormManager;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, FMX.Forms,
  FMX.Controls, FMX.StdCtrls, FMX.Layouts, FMX.Ani, FMX.Objects,
  System.UITypes, FMX.Types;

type
  TFormClass = class of TForm;

  // Forward declaration
  TChildFormInfo = class;

  // A classe de informação do formulário.
  TChildFormInfo = class
  private
    FForm: TForm;
    FTaskButton: TSpeedButton;
    FContentLayout: TLayout;
    procedure FindContentLayout;
  public
    constructor Create(AForm: TForm; ATaskButton: TSpeedButton);
    destructor Destroy; override;

    property Form: TForm read FForm;
    property TaskButton: TSpeedButton read FTaskButton;
    property ContentLayout: TLayout read FContentLayout;
  end;

  // O Gerenciador de Formulários
  TFormManager = class(TObject)
  private
    // --- Referências da View ---
    FParentLayout: TLayout;
    FHeaderActionsLayout: TLayout;
    FTaskBarLayout: TFlowLayout;
    FTitleLabel: TLabel;
    FSubTitleLabel: TLabel;
    FMainFormHeight: Single;

    // --- Estado Interno ---
    FOpenForms: TDictionary<TFormClass, TChildFormInfo>;
    FActiveFormInfo: TChildFormInfo;
    FActivationHistory: TList<TChildFormInfo>;
    FOwner: TComponent;
    FHomeFormClass: TFormClass;
    FIsDestroying: Boolean;
    FIsMinimizing: Boolean;

    // --- Métodos Internos de Lógica e UI ---
    procedure ActivateForm(AInfo: TChildFormInfo; AIsNew: Boolean);
    procedure ChildFormOnClose(Sender: TObject; var Action: TCloseAction);
    procedure TaskBarButtonClick(Sender: TObject);
    procedure UpdateHeaderUI(AInfo: TChildFormInfo);

    // --- Callbacks de Animação ---
    procedure OnCloseAnimationFinished(Sender: TObject);
    procedure OnMinimizeAnimationFinished(Sender: TObject);
    // CORREÇÃO: Novo método para o evento OnFinish da animação de restaurar
    procedure OnRestoreFromMinimizeFinished(Sender: TObject);

  public
    constructor Create(
      AOwner: TComponent;
      AParentLayout: TLayout;
      AHeaderActionsLayout: TLayout;
      ATaskBarLayout: TFlowLayout;
      ATitleLabel: TLabel;
      ASubTitleLabel: TLabel;
      AMainFormHeight: Single;
      AHomeFormClass: TFormClass = nil
    );
    destructor Destroy; override;

    // --- Comandos ---
    procedure ShowForm(AFormClass: TFormClass);
    procedure MinimizeActiveForm;
    procedure CloseActiveForm;
  end;

implementation

//==============================================================================
// TChildFormInfo
//==============================================================================

constructor TChildFormInfo.Create(AForm: TForm; ATaskButton: TSpeedButton);
begin
  inherited Create;
  FForm := AForm;
  FTaskButton := ATaskButton;
  FindContentLayout;
end;

destructor TChildFormInfo.Destroy;
begin
  inherited Destroy;
end;

procedure TChildFormInfo.FindContentLayout;
var
  I: Integer;
begin
  FContentLayout := nil;
  if not Assigned(FForm) then Exit;
  for I := 0 to FForm.ComponentCount - 1 do
    if (FForm.Components[I] is TLayout) and (SameText(FForm.Components[I].Name, 'lyConteudo')) then
    begin
      FContentLayout := TLayout(FForm.Components[I]);
      Exit;
    end;
end;

//==============================================================================
// TFormManager
//==============================================================================

constructor TFormManager.Create(AOwner: TComponent; AParentLayout: TLayout;
  AHeaderActionsLayout: TLayout; ATaskBarLayout: TFlowLayout;
  ATitleLabel: TLabel; ASubTitleLabel: TLabel; AMainFormHeight: Single;
  AHomeFormClass: TFormClass);
begin
  inherited Create;
  // Armazena referências para os componentes da UI
  FOwner := AOwner;
  FParentLayout := AParentLayout;
  FHeaderActionsLayout := AHeaderActionsLayout;
  FTaskBarLayout := ATaskBarLayout;
  FTitleLabel := ATitleLabel;
  FSubTitleLabel := ASubTitleLabel;
  FMainFormHeight := AMainFormHeight;
  FHomeFormClass := AHomeFormClass;
  FIsDestroying := False;
  FIsMinimizing := False;

  // Inicializa o estado interno
  FOpenForms := TDictionary<TFormClass, TChildFormInfo>.Create;
  FActivationHistory := TList<TChildFormInfo>.Create;
  FActiveFormInfo := nil;
end;

destructor TFormManager.Destroy;
begin
  FIsDestroying := True;
  FActivationHistory.Free;
  FOpenForms.Free;
  inherited Destroy;
end;

procedure TFormManager.ShowForm(AFormClass: TFormClass);
var
  Info: TChildFormInfo;
  IsNew: Boolean;
begin
  // Se o form clicado já for o ativo, não faz nada
  if (FActiveFormInfo <> nil) and (FActiveFormInfo.Form.ClassType = AFormClass) then
    Exit;

  IsNew := not FOpenForms.TryGetValue(AFormClass, Info);
  if IsNew then
  begin
    var NewForm := AFormClass.Create(nil);
    NewForm.OnClose := ChildFormOnClose;
    var NewButton := TSpeedButton.Create(nil);
    Info := TChildFormInfo.Create(NewForm, NewButton);
    Info.TaskButton.TagObject := TObject(Info);
    Info.TaskButton.OnClick := TaskBarButtonClick;
    FOpenForms.Add(AFormClass, Info);

    with Info.TaskButton do
    begin
      Parent := FTaskBarLayout;
      Text := Info.Form.Caption;
    end;
  end;

  ActivateForm(Info, IsNew);
end;

procedure TFormManager.ActivateForm(AInfo: TChildFormInfo; AIsNew: Boolean);
begin
  if not Assigned(AInfo) or not Assigned(AInfo.ContentLayout) then
    Exit;

  var Layout := AInfo.ContentLayout;

  if Layout.Parent <> FParentLayout then
    Layout.Parent := FParentLayout;

  Layout.BringToFront;

  if AIsNew then
  begin
    // ANIMAÇÃO PARA FORM NOVO: Escala de 0 a 1 no eixo Y
    Layout.Align := TAlignLayout.Client;
    Layout.Visible := True;
    Layout.Opacity := 1;
    Layout.Scale.Y := 0.0;
    TAnimator.AnimateFloat(Layout, 'Scale.Y', 1, 0.3, TAnimationType.Out, TInterpolationType.Quadratic);
  end
  else
  begin
    if not Layout.Visible then
    begin
      // CORREÇÃO: ANIMAÇÃO PARA "DESMINIMIZAR"
      Layout.Visible := True;
      Layout.Opacity := 1;
      Layout.Position.Y := FMainFormHeight;

      var AnimPos := TFloatAnimation.Create(Layout);
      AnimPos.Parent := Layout;
      AnimPos.PropertyName := 'Position.Y';
      AnimPos.StopValue := 0;
      AnimPos.Duration := 0.3;
      AnimPos.AnimationType := TAnimationType.Out;
      AnimPos.Interpolation := TInterpolationType.Quadratic;
      // Armazena o layout no TagObject para que o evento OnFinish saiba qual componente alinhar
      AnimPos.TagObject := Layout;
      // Atribui o método de evento compatível
      AnimPos.OnFinish := OnRestoreFromMinimizeFinished;
      AnimPos.Start;
    end
    else
    begin
      if FIsMinimizing then
      begin
        // Apenas torna o form visível sem animação
        Layout.Opacity := 1;
      end
      else
      begin
        // ANIMAÇÃO PADRÃO (clique na taskbar)
        Layout.Align := TAlignLayout.Client;
        Layout.Visible := True;
        Layout.Opacity := 0;
        TAnimator.AnimateFloat(Layout, 'Opacity', 1, 0.25);
      end;
    end;
  end;

  FParentLayout.Repaint;

  FActivationHistory.Remove(AInfo);
  FActivationHistory.Add(AInfo);
  FActiveFormInfo := AInfo;
  UpdateHeaderUI(AInfo);
end;

procedure TFormManager.UpdateHeaderUI(AInfo: TChildFormInfo);
begin
  if not Assigned(AInfo) then
  begin
    FTitleLabel.Text := 'Nenhum formulário ativo';
    FSubTitleLabel.Text := '';
    TAnimator.AnimateFloat(FHeaderActionsLayout, 'Scale.Y', 0, 0.3);
    Exit;
  end;

  FTitleLabel.Text := AInfo.Form.Caption;
  FSubTitleLabel.Text := AInfo.Form.ClassName;

  var TargetScale: Single := 1;
  if Assigned(FHomeFormClass) and (AInfo.Form.ClassType = FHomeFormClass) then
    TargetScale := 0;

  if FHeaderActionsLayout.Scale.Y <> TargetScale then
    TAnimator.AnimateFloat(FHeaderActionsLayout, 'Scale.Y', TargetScale, 0.3);
end;

procedure TFormManager.TaskBarButtonClick(Sender: TObject);
var
  Btn: TSpeedButton;
  Info: TChildFormInfo;
begin
  Btn := Sender as TSpeedButton;
  Info := TChildFormInfo(Btn.TagObject);
  if (FActiveFormInfo <> Info) and Assigned(Info) then
    ActivateForm(Info, False);
end;

procedure TFormManager.ChildFormOnClose(Sender: TObject; var Action: TCloseAction);
var
  FormToClose: TForm;
  Info: TChildFormInfo;
begin
  FormToClose := Sender as TForm;
  if FOpenForms.TryGetValue(TFormClass(FormToClose.ClassType), Info) then
  begin
    FActivationHistory.Remove(Info);
    FOpenForms.Remove(TFormClass(FormToClose.ClassType));

    Info.TaskButton.Free;

    if not FIsDestroying then
    begin
      if FActiveFormInfo = Info then
      begin
        FActiveFormInfo := nil;
        if FActivationHistory.Count > 0 then
          ActivateForm(FActivationHistory.Last, False)
        else
          UpdateHeaderUI(nil);
      end;
    end;

    Info.Free;
  end;
  Action := TCloseAction.caFree;
end;

procedure TFormManager.CloseActiveForm;
begin
  if not Assigned(FActiveFormInfo) or (Assigned(FHomeFormClass) and (FActiveFormInfo.Form.ClassType = FHomeFormClass)) then
    Exit;

  var Layout := FActiveFormInfo.ContentLayout;
  var FormToClose := FActiveFormInfo.Form;

  var Anim := TFloatAnimation.Create(Layout);
  Anim.Parent := Layout;
  Anim.PropertyName := 'Opacity';
  Anim.StartValue := 1;
  Anim.StopValue := 0;
  Anim.Duration := 0.3;
  Anim.TagObject := FormToClose;
  Anim.OnFinish := OnCloseAnimationFinished;
  Anim.Start;
end;

procedure TFormManager.MinimizeActiveForm;
begin
  if not Assigned(FActiveFormInfo) then
    Exit;

  FIsMinimizing := True;

  var Layout := FActiveFormInfo.ContentLayout;
  Layout.Align := TAlignLayout.None; // Importante para a animação de posição

  var AnimPos := TFloatAnimation.Create(Layout);
  AnimPos.Parent := Layout;
  AnimPos.PropertyName := 'Position.Y';
  AnimPos.StartValue := 0;
  AnimPos.StopValue := FMainFormHeight;
  AnimPos.Duration := 0.3;
  AnimPos.TagObject := FActiveFormInfo;
  AnimPos.OnFinish := OnMinimizeAnimationFinished;
  AnimPos.Start;

  FActiveFormInfo := nil;
end;

procedure TFormManager.OnCloseAnimationFinished(Sender: TObject);
var
  Anim: TFloatAnimation;
  FormToClose: TForm;
begin
  if FIsDestroying then Exit;

  Anim := Sender as TFloatAnimation;
  FormToClose := TForm(Anim.TagObject);
  if Assigned(FormToClose) then
    FormToClose.Close;
  Anim.OnFinish := nil;
end;

procedure TFormManager.OnMinimizeAnimationFinished(Sender: TObject);
var
  Anim: TFloatAnimation;
  MinimizedInfo: TChildFormInfo;
begin
  if FIsDestroying then Exit;

  Anim := Sender as TFloatAnimation;
  MinimizedInfo := TChildFormInfo(Anim.TagObject);

  if Assigned(MinimizedInfo) then
  begin
    MinimizedInfo.ContentLayout.Visible := False;
    FActivationHistory.Remove(MinimizedInfo);
  end;

  if FActivationHistory.Count > 0 then
    ActivateForm(FActivationHistory.Last, False)
  else
    UpdateHeaderUI(nil);

  FParentLayout.Repaint;
  Anim.OnFinish := nil;

  FIsMinimizing := False;
end;

// CORREÇÃO: Implementação do novo método de evento
procedure TFormManager.OnRestoreFromMinimizeFinished(Sender: TObject);
var
  Anim: TFloatAnimation;
  LayoutToRestore: TLayout;
begin
  Anim := Sender as TFloatAnimation;
  // Verifica se o TagObject é o layout que esperamos
  if Assigned(Anim.TagObject) and (Anim.TagObject is TLayout) then
  begin
    LayoutToRestore := TLayout(Anim.TagObject);
    // Restaura o alinhamento para que o layout preencha a área do pai
    LayoutToRestore.Align := TAlignLayout.Client;
  end;
  // Limpa o evento para evitar chamadas futuras
  Anim.OnFinish := nil;
end;

end.
