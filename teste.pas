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



procedure TMainForm.bt_Form2Click(Sender: TObject);

begin

  ShowChildForm(TForm2);

end;



procedure TMainForm.bt_Form3Click(Sender: TObject);

begin

  ShowChildForm(TForm3);

end;



procedure TMainForm.bt_Form1Click(Sender: TObject);

begin

  ShowChildForm(TForm1);

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

begin

  for I := lyPai.ChildrenCount - 1 downto 0 do

    begin

      ly  := TLayout(lyPai.Children[I]);

      frm := TCommonCustomForm(lyPai.Children[I].TagObject);



      TAnimator.AnimateFloat(ly, 'Opacity', 0, 0.3, TAnimationType.Out, TInterpolationType.Quadratic);



      TThread.CreateAnonymousThread(

        procedure

          begin

            Sleep(300);

            TThread.Synchronize(nil,

              procedure

                begin

                  frm.Close;

                end

            );

          end

      ).Start;



      lyPai.Repaint;

      Exit;

    end;

end;



procedure TMainForm.ChildFormMinimize(Sender: TObject);

var

  I: Integer;

  ly: TLayout;

begin

  for I := lyPai.ChildrenCount - 1 downto 0 do

    begin

      ly := TLayout(lyPai.Children[I]);

      ly.Align := TAlignLayout.None;

      ly.TagFloat := MainForm.Height;

      TAnimator.AnimateFloat(ly, 'Opacity', 0, 0.3, TAnimationType.Out, TInterpolationType.Quadratic);

      TAnimator.AnimateFloat(ly, 'Position.Y', MainForm.Height, 0.3);



      TThread.CreateAnonymousThread(

        procedure

          begin

            Sleep(300);

            TThread.Synchronize(nil,

              procedure

                begin

                  ly.SendToBack;

                  ly.Visible := False;



                  lyPai.Repaint;

                end

            );

          end

      ).Start;



      Exit;

    end;

end;



procedure TMainForm.lyPaiFundoPainting(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);

var

  I: Integer;

  ly: TLayout;

  ChildForm: TForm;

begin

  for I := lyPai.ChildrenCount - 1 downto 0 do

    begin

      if lyPai.Children[I] is TLayout then

        begin

          ly := TLayout(lyPai.Children[I]);



          lbTitulo.Text := ly.TagString;



          if ly.TagObject is TForm then

            begin

              ChildForm := TForm(ly.TagObject);

              lbSubTitulo.Text := ChildForm.ClassName;

              lyPai.TagString := ChildForm.ClassName;



              if (lyPai.ChildrenCount > 1) and (not (ChildForm is TfrmHome)) and (lyHeaderAcoes.Scale.Y = 0) then

                TAnimator.AnimateFloat(lyHeaderAcoes, 'Scale.Y', 1, 0.3)

                else if (lyHeaderAcoes.Scale.Y = 1) and (ChildForm is TfrmHome) then

                  TAnimator.AnimateFloat(lyHeaderAcoes, 'Scale.Y', 0, 0.3);

            end;



          Exit;

        end;

    end;

end;



procedure TMainForm.TaskBarButtonClick(Sender: TObject);

var

  Btn: TSpeedButton;

  Frm: TCommonCustomForm;

  lyFilho: TLayout;

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



          TAnimator.AnimateFloat(lyFilho, 'Position.Y', 0, 0.3);

        end;



      TThread.CreateAnonymousThread(

        procedure

          begin

            Sleep(300);

            TThread.Synchronize(nil,

              procedure

                begin

                  if lyFilho.Align = TAlignLayout.None then

                    lyFilho.Align := TAlignLayout.Client;



                  lyFilho.TagFloat := 1;

                end

            );

          end

      ).Start;



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



end.
