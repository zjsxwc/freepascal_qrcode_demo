unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  qrencode_brgabitmap,BGRABitmap, BGRABitmapTypes;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Edit1: TEdit;
    Image1: TImage;
    procedure Button1Click(Sender: TObject);
    procedure Edit1Change(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
var
  w,h : Integer;
  bmp: TBGRABitmap;
  R: TRect;
  QRcode : TQRcode;
begin
  w := 140;
  h := w;

  Image1.Height := h;
  Image1.Width := w;

  bmp := TBGRABitmap.Create(w, h, BGRAWhite);
  QRcode := TQRCode.Create();
  try
    R := Rect(0, 0, w, h);

    QRcode.EcLevel := QR_ECLEVEL_L;
    QRcode.Text := Edit1.Text;
    QRcode.Paint(bmp, R);
    bmp.SaveToFile('qrcode.bmp');

    // 显示到 TImage
    Image1.Picture.Assign(bmp.Bitmap);
  finally
    QRcode.Free;
    bmp.Free;
  end;
end;

procedure TForm1.Edit1Change(Sender: TObject);
begin

end;

end.
