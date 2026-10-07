(******************************************************************************
 * Pascal port of QRencode library v 3.4.4, http://fukuchi.org/works/qrencode/
 * 2014 by Ladislav Karrach;  Generated with help of c2pas32  v0.9b
 *****************************************************************************)
unit qrencode_brgabitmap;

{$IFDEF FPC}
 {$mode objfpc}{$H+}
{$ENDIF}

interface

uses Classes, BGRABitmap, BGRABitmapTypes, Types, BaseUnix;

(**
 * qrencode - QR Code encoder
 *
 * Copyright (C) 2006-2012 Kentaro Fukuchi <kentaro@fukuchi.org>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *)

type
  cchar = shortint;
  cschar = shortint;
  cuchar = byte;
  CUINT = longword;
  pcchar = ^cchar;
  pcuchar = ^cuchar;

type
  (**
   * Encoding mode.
   *)
  QRencodeMode = (
  	QR_MODE_NUL   = -1,  ///< Terminator (NUL character). Internal use only
  	QR_MODE_NUM   = 0,   ///< Numeric mode
  	QR_MODE_AN    = 1,   ///< Alphabet-numeric mode
  	QR_MODE_8     = 2,   ///< 8-bit data mode
  	QR_MODE_KANJI = 3,   ///< Kanji (shift-jis) mode
  	QR_MODE_STRUCTURE,   ///< Internal use only
  	QR_MODE_ECI,         ///< ECI mode
  	QR_MODE_FNC1FIRST,   ///< FNC1, first position
  	QR_MODE_FNC1SECOND   ///< FNC1, second position
  );

  (**
   * Level of error correction.
   *)
  QRecLevel = (
 	QR_ECLEVEL_L = 0,    ///< lowest
 	QR_ECLEVEL_M = 1,
 	QR_ECLEVEL_Q = 2,
 	QR_ECLEVEL_H = 3     ///< highest
  );

  (**
   * QRcode class.
   * Symbol data is represented as an array contains width*width uchars.
   * Each uchar represents a module (dot). If the less significant bit of
   * the uchar is 1, the corresponding module is black. The other bits are
   * meaningless for usual applications, but here its specification is described.
   *
   * <pre>
   * MSB 76543210 LSB
   *     |||||||`- 1=black/0=white
   *     ||||||`-- data and ecc code area
   *     |||||`--- format information
   *     ||||`---- version information
   *     |||`----- timing pattern
   *     ||`------ alignment pattern
   *     |`------- finder pattern and separator
   *     `-------- non-data modules (format, timing, etc.)
   * </pre>
   *)

type
  QRcode_t = record
    version: integer; (*/< version of the symbol*)
    width: integer;   (*/< width of the symbol*)
    data: pcuchar;    (*/< symbol data*)
  end;
  pQRcode = ^QRcode_t;

type
  (* TQRCode - simple class which encapsulates QRencode library functions *)

  TQRCode = class
    private
      FMicroQR: boolean;
      FQRCode: pQRCode;
      FecLevel: QRecLevel;
      FOrientation: integer;  // rotating: 0, 900, 1800, 2700
      FText: string;
      function GetVersion: integer;
      function GetWidth: integer;
      procedure SetecLevel(AValue: QRecLevel);
      procedure SetMicroQR(AValue: boolean);
      procedure SetText(AValue: string);
    protected
      procedure Generate;
    public
      constructor Create;
      destructor Destroy; override;


      procedure Paint(const aBitmap: TBGRABitmap; const aRect: TRect); overload;
      procedure Paint(const aBitmap: TBGRABitmap; const aRect: TRect;
        aBgColor, aFgColor: TBGRAPixel); overload;

      property EcLevel: QRecLevel read FEcLevel write SetEcLevel;
      property MicroQR: boolean read FMicroQR write SetMicroQR;
      property Orientation: integer read FOrientation write FOrientation;
      property Text: string read FText write SetText;
      property Version: integer read GetVersion;
      property Width: integer read GetWidth;
  end;

  function QRcode_encodeString(s: AnsiString;  version: integer;  level: QRecLevel;  hint: QRencodeMode;  casesensitive: integer): pQRcode;
  procedure QRcode_free(qrcode: pQRcode);
  procedure QRcode_clearCache();


implementation

uses
  SysUtils;

const
  _MAJOR_VERSION = 3;
  _MINOR_VERSION = 4;
  _MICRO_VERSION = 4;
  _VERSION = '3.4.4';

  EINVAL=22;
  ERANGE=34;

 (**
  * Length of a standard mode indicator in bits.
  *)
 MODE_INDICATOR_SIZE = 4;

 (**
  * Length of a segment of structured-append header.
  *)
 STRUCTURE_HEADER_SIZE = 20;

 (**
  * Maximum number of symbols in a set of structured-appended symbols.
  *)
 MAX_STRUCTURED_SYMBOLS = 16;

 (**
  * Maximum version (size) of QR-code symbol.
  *)
 QRSPEC_VERSION_MAX = 40;
 MQRSPEC_VERSION_MAX = 4;


// bitstream.h
 type
   tBitStream = record
     length: integer;
     data: pcuchar; {unsigned char *}
   end;
   pBitStream = ^tBitStream;

// Entry of input data
// qrinput.h
 type
   pQRinput_List = ^tQRinput_List;
   tQRinput_List = record
     mode: QRencodeMode;
     size: integer; (*/< Size of data chunk (byte).*)
     data: pcuchar; (*/< Data chunk.*)
     bstream: pBitStream;
     next: pQRinput_List;
   end;

// Input Data
   tQRinput = record
     version: integer;
     level: QRecLevel;
     head: pQRinput_List;
     tail: pQRinput_List;
     mqr: integer;
     fnc1: integer;
     appid: cuchar;
   end;
   pQRinput = ^tQRinput;


// Structured append input data
   pQRinput_InputList = ^tQRinput_InputList;
   tQRinput_InputList = record
     input: pQRinput;
     next: pQRinput_InputList;
   end;

   tQRinput_Struct = record
     size: integer; (*/< number of structured symbols*)
     parity: integer;
     head: pQRinput_InputList;
     tail: pQRinput_InputList;
   end;
   pQRinput_Struct = ^tQRinput_Struct;


var
  errno: integer;


{ $DEFINE debug}
{$IFDEF debug}
procedure DebugFmt(const s: string; const Arg: array of const);
var F: TextFile;
begin
  system.Assign(F, 'qrencode.log');
  system.Append(F);
  system.WriteLn(F, Format(s, Arg));
  system.Close(F);
end;
{$ENDIF}

// Allocates a block of size bytes of memory, returning a pointer to the beginning of the block.
// The content of the newly allocated block of memory is not initialized, remaining with indeterminate values.
function cmalloc(const size: integer): pointer; inline;
begin
  Result := getmem(size);
{$IFDEF debug}
  if Result = nil then raise Exception.Create('malloc failed!');
  DebugFmt('malloc(%d bytes): %p', [size, Result]);
  assert(size = MemSize(Result), 'Check MemSize');
{$ENDIF}
end;

function ccalloc(const num, size: integer): pointer; inline;
begin
  Result := allocmem(num*size);
{$IFDEF debug}
  if Result = nil then raise Exception.Create('calloc failed!');
  DebugFmt('calloc(%d*%d bytes): %p', [num,size, Result]);
{$ENDIF}
end;

// If ptr is a null pointer, the function does nothing.
procedure cfree(ptr: pointer); inline;
begin
  if ptr = nil then Exit;
{$IFDEF debug}
  DebugFmt('free: %p', [ptr]);
{$ENDIF}
  freemem(ptr);
end;

// Sets the first num bytes of the block of memory pointed by ptr to the specified value (interpreted as an unsigned char).
function cmemset(ptr: pointer; value: integer; num: integer): pointer; inline;
begin
  Result := ptr;
  FillByte(ptr^, num, byte(value));
end;

// Copies the values of num bytes from the location pointed by source directly to the memory block pointed by destination.
// destination is returned.
function cmemcpy(destination, source: pointer; num: integer): pointer; inline;
begin
  Result := destination;
  Move(source^, destination^, num);
end;

// Copies the values of num bytes from the location pointed by source to the memory block pointed by destination.
// Copying takes place as if an intermediate buffer were used, allowing the destination and source to overlap.
// destination is returned.
function cmemmove(destination, source: pointer; num: integer): pointer; inline;
begin
  Result := destination;
  Move(source^, destination^, num);
end;


function QRinput_isSplittableMode(mode: QRencodeMode): boolean;
begin
  Result := (mode>=QR_MODE_NUM) and (mode<=QR_MODE_KANJI);
end;

{ $i bitstream.inc}
(******************************************************************************
 * bitstream.c
 *****************************************************************************)

function BitStream_new(): pBitStream;
begin
  Result := cmalloc(sizeof(tBitStream));
  if Result=nil then Exit;

  Result^.length := 0;
  Result^.data := nil;
end;

function BitStream_allocate(bstream: pBitStream;  length: integer): integer;
var
  data: pcuchar;
begin
  if bstream = nil then
  begin
    result:= -1;
    exit;
  end;

  data := cmalloc(length);
  if data=nil then
  begin
    result:= -1;
    exit;
  end;

  if bstream^.data <> nil then
    cfree(bstream^.data);

  bstream^.length:= length;
  bstream^.data:= data;
  result:= 0;
end;

procedure BitStream_free(bstream: pBitStream);
begin
  if bstream <> nil then
  begin
    cfree(bstream^.data);
    cfree(bstream);
  end;
end;

function BitStream_newFromNum(bits: integer;  num: CUINT): pBitStream;
var
  mask: CUINT;
  i: integer;
  p: pcuchar;
  bstream: pBitStream;
begin
  bstream:= BitStream_new();
  if bstream = nil then
  begin
    result:= nil;
    exit;
  end;

  if BitStream_allocate(bstream,bits) <> 0 then
  begin
    BitStream_free(bstream);
    result := nil;
    exit;
  end;

  p:= bstream^.data;
  mask:= 1 shl (bits-1);
  for i:=0 to bits-1 do
  begin
    if (num and mask) <> 0 then
      p^:=1
    else
      p^:=0;
    inc(p);
    mask:= mask shr 1;
  end;

  result:= bstream;
end;

function BitStream_newFromBytes(size: integer;  data: pcuchar): pBitStream;
var
  mask: cuchar;
  i, j: integer;
  p: pcuchar;
  bstream: pBitStream;
begin
  bstream:= BitStream_new();
  if bstream=nil then
  begin
    result:= nil;
    exit;
  end;

  if BitStream_allocate(bstream, size*8) <> 0 then
  begin
    BitStream_free(bstream);
    result:= nil;
    exit;
  end;

  p:= bstream^.data;
  for i:=0 to Pred(size) do
  begin
    mask:= $80;
    for j:=0 to 7 do
    begin
      if (data[i] and mask) <> 0 then
        p^:=1
      else
        p^:=0;
      inc(p);
      mask:= mask shr 1;
    end;
  end;

  result:= bstream;
end;

function BitStream_append(bstream: pBitStream;  arg: pBitStream): integer;
var
  data: pcuchar;
begin
  if arg =nil then
  begin
    result:= -1;
    exit;
  end;

  if arg^.length=0 then
  begin
    result:= 0;
    exit;
  end;

  if bstream^.length=0 then
  begin
    if BitStream_allocate(bstream, arg^.length) <> 0 then
    begin
      result:= -1;
      exit;
    end;
    cmemcpy(bstream^.data, arg^.data, arg^.length);
    result:= 0;
    exit;
  end;

  data:= cmalloc(bstream^.length + arg^.length);
  if data=nil then
  begin
    result:= -1;
    exit;
  end;
  cmemcpy(data, bstream^.data, bstream^.length);
  cmemcpy(data+bstream^.length, arg^.data, arg^.length);
  cfree(bstream^.data);
  bstream^.length:= bstream^.length + arg^.length;
  bstream^.data:= data;
  result:= 0;
end;

function BitStream_appendNum(bstream: pBitStream;  bits: integer;  num: CUINT): integer;
var
  b: pBitStream;
  ret: integer;
begin
  if bits=0 then
  begin
    result:= 0;
    exit;
  end;

  b:= BitStream_newFromNum(bits,num);
  if b=nil then
  begin
    result:= -1;
    exit;
  end;

  ret:= BitStream_append(bstream,b);
  BitStream_free(b);
  result:= ret;
end;

function BitStream_appendBytes(bstream: pBitStream;  size: integer;  data: pcuchar): integer;
var
  b: pBitStream;
begin
  if size=0 then
  begin
    result:= 0;
    exit;
  end;

  b:= BitStream_newFromBytes(size,data);
  if b=nil then
  begin
    result:= -1;
    exit;
  end;

  Result:= BitStream_append(bstream,b);
  BitStream_free(b);
end;

function BitStream_size(__bstream__: pBitStream): integer;
begin
  Result := __bstream__^.length;
end;

function BitStream_toByte(bstream: pBitStream): pcuchar;
var
  i, j, size, bytes: integer;
  data, p: pcuchar;
  v: cuchar;
begin
  size:= BitStream_size(bstream);
  if size=0 then
  begin
    result:= nil;
    exit;
  end;

  data:= cmalloc((size+7) div 8);
  if data=nil then
  begin
    result:= nil;
    exit;
  end;

  bytes:= size div 8;
  p:= bstream^.data;
  for i:=0 to Pred(bytes) do
  begin
    v:= 0;
    for j:=0 to Pred(8) do
    begin
      v:= v shl 1;
      v:= v or p^;
      inc(p);
    end;
    data[i]:= v;
  end;

  if (size and 7) <> 0 then
  begin
    v:= 0;
    for j:=0 to Pred((size and 7)) do
    begin
      v:= v shl 1;
      v:= v or p^;
      inc(p);
    end;
    data[bytes]:= v;
  end;

  result:= data;
end;


{ $i qrspec.inc}
(******************************************************************************
 * qrspec.c
 *****************************************************************************)

(**
 * Maximum width of a symbol
 *)
const
  QRSPEC_WIDTH_MAX = 177;

(******************************************************************************
 * Mode indicator
 *****************************************************************************)
  (**
   * Mode indicator. See Table 2 of JIS X0510:2004, pp.16.
   *)
  QRSPEC_MODEID_ECI        = 7;
  QRSPEC_MODEID_NUM        = 1;
  QRSPEC_MODEID_AN         = 2;
  QRSPEC_MODEID_8          = 4;
  QRSPEC_MODEID_KANJI      = 8;
  QRSPEC_MODEID_FNC1FIRST  = 5;
  QRSPEC_MODEID_FNC1SECOND = 9;
  QRSPEC_MODEID_STRUCTURE  = 3;
  QRSPEC_MODEID_TERMINATOR = 0;

(******************************************************************************
 * Version and capacity
 *****************************************************************************)
type
  QRspec_Capacity = record
    width: integer;                   (*< Edge length of the symbol*)
    words: integer;                   (*< Data capacity (bytes)*)
    remainder: integer;               (*< Remainder bit (bits)*)
    ec: array [QRecLevel] of integer; (*< Number of ECC code (bytes)*)
  end;

(**
 * Table of the capacity of symbols
 * See Table 1 (pp.13) and Table 12-16 (pp.30-36), JIS X0510:2004.
 *)
const
  qrspecCapacity: array [0..QRSPEC_VERSION_MAX] of QRspec_Capacity = (
    (width:0;words:0;remainder:0;ec:(0,0,0,0)),
    (width:21;words:26;remainder:0;ec:(7,10,13,17)),     // 1
    (width:25;words:44;remainder:7;ec:(10,16,22,28)),
    (width:29;words:70;remainder:7;ec:(15,26,36,44)),
    (width:33;words:100;remainder:7;ec:(20,36,52,64)),
    (width:37;words:134;remainder:7;ec:(26,48,72,88)),   // 5
    (width:41;words:172;remainder:7;ec:(36,64,96,112)),
    (width:45;words:196;remainder:0;ec:(40,72,108,130)),
    (width:49;words:242;remainder:0;ec:(48,88,132,156)),
    (width:53;words:292;remainder:0;ec:(60,110,160,192)),
    (width:57;words:346;remainder:0;ec:(72,130,192,224)),// 10
    (width:61;words:404;remainder:0;ec:(80,150,224,264)),
    (width:65;words:466;remainder:0;ec:(96,176,260,308)),
    (width:69;words:532;remainder:0;ec:(104,198,288,352)),
    (width:73;words:581;remainder:3;ec:(120,216,320,384)),
    (width:77;words:655;remainder:3;ec:(132,240,360,432)),//20
    (width:81;words:733;remainder:3;ec:(144,280,408,480)),
    (width:85;words:815;remainder:3;ec:(168,308,448,532)),
    (width:89;words:901;remainder:3;ec:(180,338,504,588)),
    (width:93;words:991;remainder:3;ec:(196,364,546,650)),
    (width:97;words:1085;remainder:3;ec:(224,416,600,700)),
    (width:101;words:1156;remainder:4;ec:(224,442,644,750)),
    (width:105;words:1258;remainder:4;ec:(252,476,690,816)),
    (width:109;words:1364;remainder:4;ec:(270,504,750,900)),
    (width:113;words:1474;remainder:4;ec:(300,560,810,960)),
    (width:117;words:1588;remainder:4;ec:(312,588,870,1050)),
    (width:121;words:1706;remainder:4;ec:(336,644,952,1110)),
    (width:125;words:1828;remainder:4;ec:(360,700,1020,1200)),
    (width:129;words:1921;remainder:3;ec:(390,728,1050,1260)),
    (width:133;words:2051;remainder:3;ec:(420,784,1140,1350)),
    (width:137;words:2185;remainder:3;ec:(450,812,1200,1440)),
    (width:141;words:2323;remainder:3;ec:(480,868,1290,1530)),
    (width:145;words:2465;remainder:3;ec:(510,924,1350,1620)),
    (width:149;words:2611;remainder:3;ec:(540,980,1440,1710)),
    (width:153;words:2761;remainder:3;ec:(570,1036,1530,1800)),
    (width:157;words:2876;remainder:0;ec:(570,1064,1590,1890)),
    (width:161;words:3034;remainder:0;ec:(600,1120,1680,1980)),
    (width:165;words:3196;remainder:0;ec:(630,1204,1770,2100)),
    (width:169;words:3362;remainder:0;ec:(660,1260,1860,2220)),
    (width:173;words:3532;remainder:0;ec:(720,1316,1950,2310)),
    (width:177;words:3706;remainder:0;ec:(750,1372,2040,2430))
  );

function QRspec_getDataLength(version: integer;  level: QRecLevel): integer;
begin
  result:= qrspecCapacity[version].words - qrspecCapacity[version].ec[level];
end;

function QRspec_getECCLength(version: integer;  level: QRecLevel): integer;
begin
  result:= qrspecCapacity[version].ec[level];
end;

function QRspec_getMinimumVersion(size: integer;  level: QRecLevel): integer;
var
  i: integer;
  words: integer;
begin
  for i:=1 to QRSPEC_VERSION_MAX do
  begin
    words:= qrspecCapacity[i].words - qrspecCapacity[i].ec[level];
    if words>=size then
    begin
      result:= i;
      Exit;
    end;
  end;
  result:= -1;
end;

function QRspec_getWidth(version: integer): integer;
begin
  result:= qrspecCapacity[version].width;
end;

function QRspec_getRemainder(version: integer): integer;
begin
  result:= qrspecCapacity[version].remainder;
end;

(******************************************************************************
 * Length indicator
 *****************************************************************************)
const
  lengthTableBits: array [0..3,0..2] of integer = (
    (10,12,14),
    (9,11,13),
    (8,16,16),
    (8,10,12)
  );

function QRspec_lengthIndicator(mode: QRencodeMode;  version: integer): integer;
var
  l: integer;
begin
  if not QRinput_isSplittableMode(mode) then
  begin
    result:= 0;
    exit;
  end;

  if version<=9 then
    l:= 0
  else if version<=26 then
    l:= 1
  else
    l:= 2;

  result:= lengthTableBits[ord(mode), l];
end;

function QRspec_maximumWords(mode: QRencodeMode;  version: integer): integer;
var
  l, bits: integer;
begin
  if not QRinput_isSplittableMode(mode) then
  begin
    result:= 0;
    exit;
  end;

  if version<=9  then
    l:= 0
  else if version<=26 then
    l:= 1
  else
    l:= 2;

  bits := lengthTableBits[ord(mode), l];
  Result := (1 shl bits)-1;
  if mode=QR_MODE_KANJI then
    Result := Result * 2; (* the number of bytes is required*)
end;

(******************************************************************************
 * Error correction code
 *****************************************************************************)
(**
 * Table of the error correction code (Reed-Solomon block)
 * See Table 12-16 (pp.30-36), JIS X0510:2004.
 *)
const
  eccTable: array [0..QRSPEC_VERSION_MAX, QRecLevel, 0..1] of integer = (
    ((0,0),(0,0),(0,0),(0,0)),
    ((1,0),(1,0),(1,0),(1,0)),
    ((1,0),(1,0),(1,0),(1,0)),
    ((1,0),(1,0),(2,0),(2,0)),
    ((1,0),(2,0),(2,0),(4,0)),
    ((1,0),(2,0),(2,2),(2,2)),
    ((2,0),(4,0),(4,0),(4,0)),
    ((2,0),(4,0),(2,4),(4,1)),
    ((2,0),(2,2),(4,2),(4,2)),
    ((2,0),(3,2),(4,4),(4,4)),
    ((2,2),(4,1),(6,2),(6,2)),
    ((4,0),(1,4),(4,4),(3,8)),
    ((2,2),(6,2),(4,6),(7,4)),
    ((4,0),(8,1),(8,4),(12,4)),
    ((3,1),(4,5),(11,5),(11,5)),
    ((5,1),(5,5),(5,7),(11,7)),
    ((5,1),(7,3),(15,2),(3,13)),
    ((1,5),(10,1),(1,15),(2,17)),
    ((5,1),(9,4),(17,1),(2,19)),
    ((3,4),(3,11),(17,4),(9,16)),
    ((3,5),(3,13),(15,5),(15,10)),
    ((4,4),(17,0),(17,6),(19,6)),
    ((2,7),(17,0),(7,16),(34,0)),
    ((4,5),(4,14),(11,14),(16,14)),
    ((6,4),(6,14),(11,16),(30,2)),
    ((8,4),(8,13),(7,22),(22,13)),
    ((10,2),(19,4),(28,6),(33,4)),
    ((8,4),(22,3),(8,26),(12,28)),
    ((3,10),(3,23),(4,31),(11,31)),
    ((7,7),(21,7),(1,37),(19,26)),
    ((5,10),(19,10),(15,25),(23,25)),
    ((13,3),(2,29),(42,1),(23,28)),
    ((17,0),(10,23),(10,35),(19,35)),
    ((17,1),(14,21),(29,19),(11,46)),
    ((13,6),(14,23),(44,7),(59,1)),
    ((12,7),(12,26),(39,14),(22,41)),
    ((6,14),(6,34),(46,10),(2,64)),
    ((17,4),(29,14),(49,10),(24,46)),
    ((4,18),(13,32),(48,14),(42,32)),
    ((20,4),(40,7),(43,22),(10,67)),
    ((19,6),(18,31),(34,34),(20,61))
  );

type
  TSpecArray = array [0..4] of integer;

procedure QRspec_getEccSpec(version: integer;  level: QRecLevel;  {int spec[5]}out spec: TSpecArray);
var
  b1, b2: integer;
  data, ecc: integer;
begin
  b1:= eccTable[version, level, 0];
  b2:= eccTable[version, level, 1];
  data:= QRspec_getDataLength(version,level);
  ecc:= QRspec_getECCLength(version,level);

  if b2=0 then
  begin
    spec[0]:= b1;
    spec[1]:= data div b1;
    spec[2]:= ecc div b1;
    spec[3]:= 0;
    spec[4]:= 0;
  end
  else
  begin
    spec[0]:= b1;
    spec[1]:= data div (b1+b2);
    spec[2]:= ecc div (b1+b2);
    spec[3]:= b2;
    spec[4]:= spec[1]+1;
  end;
end;

(******************************************************************************
 * Alignment pattern
 *****************************************************************************)
(**
 * Positions of alignment patterns.
 * This array includes only the second and the third position of the alignment
 * patterns. Rest of them can be calculated from the distance between them.
 *
 * See Table 1 in Appendix E (pp.71) of JIS X0510:2004.
 *)
const
  alignmentPattern: array [0..QRSPEC_VERSION_MAX,0..1] of integer = (
    (0,0),
    (0,0),(18,0),(22,0),(26,0),(30,0),
    (34,0),(22,38),(24,42),(26,46),(28,50),
    (30,54),(32,58),(34,62),(26,46),(26,48),
    (26,50),(30,54),(30,56),(30,58),(34,62),
    (28,50),(26,50),(30,54),(28,54),(32,58),
    (30,58),(34,62),(26,50),(30,54),(26,52),
    (30,56),(34,60),(30,58),(34,62),(30,54),
    (24,50),(28,54),(32,58),(26,54),(30,58)
  );

(**
 * Put an alignment marker.
 * @param frame
 * @param width
 * @param ox,oy center coordinate of the pattern
 *)
procedure QRspec_putAlignmentMarker(frame: pcuchar;  width: integer;  ox: integer;  oy: integer);
const
  finder: array [0..24] of cuchar = (
    $a1,$a1,$a1,$a1,$a1,
    $a1,$a0,$a0,$a0,$a1,
    $a1,$a0,$a1,$a0,$a1,
    $a1,$a0,$a0,$a0,$a1,
    $a1,$a1,$a1,$a1,$a1);
var
  s: pcuchar;
  x, y: integer;
begin
  frame:= frame + (oy-2)*width + ox - 2;
  s:= @finder;
  for y:=0 to Pred(5) do
  begin
    for x:=0 to Pred(5)  do
      frame[x]:= s[x];
    frame := frame + width;
    s := s + 5;
  end;
end;

procedure QRspec_putAlignmentPattern(version: integer;  frame: pcuchar;  width: integer);
var
  d, w, x, y, cx, cy: integer;
begin
  if version<2 then exit;

  d := alignmentPattern[version,1] - alignmentPattern[version,0];
  if d<0 then
    w:= 2
  else
    w:= (width - alignmentPattern[version,0]) div d + 2;

  if w*w-3=1 then
  begin
    x:= alignmentPattern[version,0];
    y:= alignmentPattern[version,0];
    QRspec_putAlignmentMarker(frame,width,x,y);
    exit;
  end;

  cx:= alignmentPattern[version,0];
  for x:=1 to Pred(w-1) do
  begin
    QRspec_putAlignmentMarker(frame,width,6,cx);
    QRspec_putAlignmentMarker(frame,width,cx,6);
    cx:= cx + d;
  end;

  cy:= alignmentPattern[version,0];
  for y:=0 to Pred(w-1) do
  begin
    cx:= alignmentPattern[version,0];
    for x:=0 to Pred(w-1) do
    begin
      QRspec_putAlignmentMarker(frame,width,cx,cy);
      cx:= cx + d;
    end;
    cy:= cy + d;
  end;
end;

(******************************************************************************
 * Version information pattern
 *****************************************************************************)
(**
 * Version information pattern (BCH coded).
 * See Table 1 in Appendix D (pp.68) of JIS X0510:2004.
 *)
const
  versionPattern: array [0..QRSPEC_VERSION_MAX-7] of CUINT =
    ($07c94,$085bc,$09a99,$0a4d3,$0bbf6,$0c762,$0d847,$0e60d,$0f928,$10b78,$1145d,$12a17,$13532,$149a6,$15683,$168c9,$177ec,$18ec4,$191e1,$1afab,$1b08e,$1cc1a,$1d33f,$1ed75,$1f250,$209d5,$216f0,$228ba,$2379f,$24b0b,$2542e,$26a64,$27541,$28c69);

function QRspec_getVersionPattern(version: integer): CUINT;
begin
  if (version<7) or (version>QRSPEC_VERSION_MAX) then
    result:= 0
  else
    result:= versionPattern[version-7];
end;

(******************************************************************************
 * Format information
 *****************************************************************************)
(* See calcFormatInfo in tests/test_qrspec.c *)
const
  formatInfo: array [QRecLevel,0..7] of CUINT = (
    ($77c4,$72f3,$7daa,$789d,$662f,$6318,$6c41,$6976),
    ($5412,$5125,$5e7c,$5b4b,$45f9,$40ce,$4f97,$4aa0),
    ($355f,$3068,$3f31,$3a06,$24b4,$2183,$2eda,$2bed),
    ($1689,$13be,$1ce7,$19d0,$0762,$0255,$0d0c,$083b)
  );

function QRspec_getFormatInfo(mask: integer;  level: QRecLevel): CUINT;
begin
  if (mask<0) or (mask>7) then
    result:= 0
  else
    result:= formatInfo[level,mask];
end;

(******************************************************************************
 * Frame
 *****************************************************************************)
(**
 * Cache of initial frames.
 *)
(* C99 says that static storage shall be initialized to a null pointer
 * by compiler. *)
var {was static}
  QRframes: array [0..QRSPEC_VERSION_MAX] of pcuchar;

{$ifdef HAVE_LIBPTHREAD}
  frames_mutex: pthread_mutex_t = PTHREAD_MUTEX_INITIALIZER;
{$endif}
(**
 * Put a finder pattern.
 * @param frame
 * @param width
 * @param ox,oy upper-left coordinate of the pattern
 *)
procedure putFinderPattern(frame: pcuchar;  width: integer;  ox: integer;  oy: integer);
const
  finder: array [0..48] of cuchar = (
    $c1,$c1,$c1,$c1,$c1,$c1,$c1,
    $c1,$c0,$c0,$c0,$c0,$c0,$c1,
    $c1,$c0,$c1,$c1,$c1,$c0,$c1,
    $c1,$c0,$c1,$c1,$c1,$c0,$c1,
    $c1,$c0,$c1,$c1,$c1,$c0,$c1,
    $c1,$c0,$c0,$c0,$c0,$c0,$c1,
    $c1,$c1,$c1,$c1,$c1,$c1,$c1
  );
var
  s: pcuchar;
  x, y: integer;
begin
  frame:= frame + oy*width + ox;
  s:= @finder;
  for y:=0 to Pred(7) do
  begin
    for x:=0 to Pred(7) do
      frame[x]:= s[x];
    frame:= frame + width;
    s:= s + 7;
  end;
end;

function QRspec_createFrame(version: integer): pcuchar;
var
  frame, p, q: pcuchar;
  width, x, y: integer;
  verinfo, v: CUINT;
begin
  width:= qrspecCapacity[version].width;
  frame:= cmalloc(width*width);
  if frame=nil then
  begin
    result:=nil;
    exit;
  end;

  cmemset(frame, 0, width * width);
  (* Finder pattern *)
  putFinderPattern(frame,width, 0,0);
  putFinderPattern(frame,width, width-7,0);
  putFinderPattern(frame,width, 0,width-7);

  (* Separator *)
  p:= frame;
  q:= frame+width*(width-7);
  for y:=0 to Pred(7) do
  begin
    p[7]:= $c0;
    p[width-8]:= $c0;
    q[7]:= $c0;
    inc(p, width);
    inc(q, width);
  end;
  cmemset(frame + width * 7, $c0, 8);
  cmemset(frame + width * 8 - 8, $c0, 8);
  cmemset(frame + width * (width - 8), $c0, 8);
  (* Mask format information area *)
  cmemset(frame + width * 8, $84, 9);
  cmemset(frame + width * 9 - 8, $84, 8);
  p:= frame+8;
  for y:=0 to Pred(8) do
  begin
    p^:=$84;
    inc(p, width);
  end;
  p:= frame + width*(width-7) + 8;
  for y:=0 to Pred(7) do
  begin
    p^:=$84;
    inc(p, width);
  end;
  (* Timing pattern *)
  p:= frame+width*6+8;
  q:= frame+width*8+6;
  for x:=1 to Pred(width-15) do
  begin
    p^:=$90 or (x and 1);
    q^:=$90 or (x and 1);
    inc(p);
    inc(q, width);
  end;
  (* Alignment pattern *)
  QRspec_putAlignmentPattern(version,frame,width);

  (* Version information *)
  if version>=7 then
  begin
    verinfo:= QRspec_getVersionPattern(version);
    p:= frame+width*(width-11);
    v:= verinfo;
    for x:=0 to Pred(6) do
    begin
      for y:=0 to Pred(3) do
      begin
        p[width*y+x]:= $88 or (v and 1);
        v:= v shr 1;
      end;
    end;

    p:= frame+width-11;
    v:= verinfo;
    for y:=0 to Pred(6) do
    begin
      for x:=0 to Pred(3) do
      begin
        p[x]:= $88 or (v and 1);
        v:= v shr 1;
      end;
      inc(p, width);
    end;
  end;

  (* and a little bit... *)
  frame[width*(width-8)+8]:= $81;
  result:= frame;
end;

function QRspec_newFrame(version: integer): pcuchar;
var
  width: integer;
begin
  if (version<1) or (version>QRSPEC_VERSION_MAX) then
  begin
    result:=nil;
    exit;
  end;
{$ifdef HAVE_LIBPTHREAD}
  pthread_mutex_lock(@frames_mutex);
{$endif}
  if QRframes[version]=nil then
    QRframes[version]:= QRspec_createFrame(version);
{$ifdef HAVE_LIBPTHREAD}
  pthread_mutex_unlock(@frames_mutex);
{$endif}
  if QRframes[version]=nil then
  begin
    result:=nil;
    exit;
  end;

  width:= qrspecCapacity[version].width;
  Result := cmalloc(width*width);
  if Result=nil then Exit;
  cmemcpy(Result, QRframes[version], width*width);
end;

procedure QRspec_clearCache();
var
  i: integer;
begin
{$ifdef HAVE_LIBPTHREAD}
  pthread_mutex_lock(@frames_mutex);
{$endif}
  for i:=1 to QRSPEC_VERSION_MAX do
  begin
    cfree(QRframes[i]);
    QRframes[i]:= nil;
  end;
{$ifdef HAVE_LIBPTHREAD}
  pthread_mutex_unlock(@frames_mutex);
{$endif}
end;

{#define QRspec_rsBlockNum(__spec__) (__spec__[0] + __spec__[3])}
function QRspec_rsBlockNum(__spec__: pinteger): integer; inline;
begin
  Result := (__spec__[0] + __spec__[3]);
end;

{#define QRspec_rsBlockNum1(__spec__) (__spec__[0])}
function QRspec_rsBlockNum1(__spec__: pinteger): integer; inline;
begin
  Result := __spec__[0];
end;

{#define QRspec_rsDataCodes1(__spec__) (__spec__[1])}
function QRspec_rsDataCodes1(__spec__: pinteger): integer; inline;
begin
  Result := __spec__[1];
end;

{#define QRspec_rsEccCodes1(__spec__) (__spec__[2])}
function QRspec_rsEccCodes1(__spec__: pinteger): integer; inline;
begin
  Result := __spec__[2];
end;

{#define QRspec_rsBlockNum2(__spec__) (__spec__[3])}
function QRspec_rsBlockNum2(__spec__: pinteger): integer; inline;
begin
  Result := __spec__[3];
end;

{#define QRspec_rsDataCodes2(__spec__) (__spec__[4])}
function QRspec_rsDataCodes2(__spec__: pinteger): integer; inline;
begin
  Result := __spec__[4];
end;

{#define QRspec_rsEccCodes2(__spec__) (__spec__[2])}
function QRspec_rsEccCodes2(__spec__: pinteger): integer; inline;
begin
  Result := __spec__[2];
end;

{#define QRspec_rsDataLength(__spec__) \
	((QRspec_rsBlockNum1(__spec__) * QRspec_rsDataCodes1(__spec__)) + \
	 (QRspec_rsBlockNum2(__spec__) * QRspec_rsDataCodes2(__spec__)))}
function QRspec_rsDataLength(__spec__: pinteger): integer;
begin
  Result := (QRspec_rsBlockNum1(__spec__) * QRspec_rsDataCodes1(__spec__)) +
            (QRspec_rsBlockNum2(__spec__) * QRspec_rsDataCodes2(__spec__));
end;

{#define QRspec_rsEccLength(__spec__) \
	(QRspec_rsBlockNum(__spec__) * QRspec_rsEccCodes1(__spec__))}
function QRspec_rsEccLength(__spec__: pinteger): integer;
begin
  Result := QRspec_rsBlockNum(__spec__) * QRspec_rsEccCodes1(__spec__);
end;

{ $i mqrspec.inc}
(******************************************************************************
 * mqrspec.c
 *****************************************************************************)

const
  (**
   * Maximum width of a symbol
   *)
  MQRSPEC_WIDTH_MAX       = 17;

  MQRSPEC_MODEID_NUM      = 0;
  MQRSPEC_MODEID_AN       = 1;
  MQRSPEC_MODEID_8        = 2;
  MQRSPEC_MODEID_KANJI    = 3;

(******************************************************************************
 * Version and capacity
 *****************************************************************************)
type
  MQRspec_Capacity = record
    width: integer;                   (*< Edge length of the symbol*)
    ec: array [QRecLevel] of integer; (*< Number of ECC code (bytes)*)
  end;

(**
 * Table of the capacity of symbols
 * See Table 1 (pp.106) and Table 8 (pp.113) of Appendix 1, JIS X0510:2004.
 *)
const
  mqrspecCapacity: array [0..MQRSPEC_VERSION_MAX] of MQRspec_Capacity = (
    (width:0; ec:(0,0,0,0)),
    (width:11;ec:(2,0,0,0)),
    (width:13;ec:(5,6,0,0)),
    (width:15;ec:(6,8,0,0)),
    (width:17;ec:(8,10,14,0))
  );


function MQRspec_getDataLengthBit(version: integer;  level: QRecLevel): integer;
var
  w: integer;
  ecc: integer;
begin
  w:= mqrspecCapacity[version].width-1;
  ecc:= mqrspecCapacity[version].ec[level];
  if ecc=0 then
    result:= 0
  else
    result:= w*w-64-ecc*8;
end;

function MQRspec_getDataLength(version: integer;  level: QRecLevel): integer;
begin
  result:= (MQRspec_getDataLengthBit(version,level)+4) div 8;
end;

function MQRspec_getECCLength(version: integer;  level: QRecLevel): integer;
begin
  result:= mqrspecCapacity[version].ec[level];
end;

function MQRspec_getWidth(version: integer): integer;
begin
  result:= mqrspecCapacity[version].width;
end;

(******************************************************************************
 * Length indicator
 *****************************************************************************)
(**
 * See Table 3 (pp.107) of Appendix 1, JIS X0510:2004.
 *)
const
  MQRlengthTableBits: array [0..Pred(4),0..Pred(4)] of integer = ((3,4,5,6),(0,3,4,5),(0,0,4,5),(0,0,3,4));

function MQRspec_lengthIndicator(mode: QRencodeMode;  version: integer): integer;
begin
  result:= MQRlengthTableBits[ord(mode)][version-1];
end;

function MQRspec_maximumWords(mode: QRencodeMode;  version: integer): integer;
var
  bits: integer;
begin
  bits := MQRlengthTableBits[ord(mode)][version-1];
  Result := (1 shl bits)-1;
  if mode=QR_MODE_KANJI  then
    Result := Result * 2; (* the number of bytes is required*)
end;

(******************************************************************************
 * Format information
 *****************************************************************************)
(* See calcFormatInfo in tests/test_mqrspec.c *)
const
  MQRformatInfo: array [0..Pred(4),0..Pred(8)] of CUINT = (
    ($4445,$55ae,$6793,$7678,$06de,$1735,$2508,$34e3),
    ($4172,$5099,$62a4,$734f,$03e9,$1202,$203f,$31d4),
    ($4e2b,$5fc0,$6dfd,$7c16,$0cb0,$1d5b,$2f66,$3e8d),
    ($4b1c,$5af7,$68ca,$7921,$0987,$186c,$2a51,$3bba)
  ); (* See Table 10 of Appendix 1. (pp.115) *)

  MQRtypeTable: array [0..MQRSPEC_VERSION_MAX,0..2] of integer = (
    (-1,-1,-1),
    (0,-1,-1),
    (1,2,-1),
    (3,4,-1),
    (5,6,7)
  );

function MQRspec_getFormatInfo(mask: integer;  version: integer;  level: QRecLevel): CUINT;
var
  typ: integer;
begin
  if (mask<0) or (mask>3) then
  begin
    result:= 0;
    exit;
  end;

  if (version<=0) or (version>MQRSPEC_VERSION_MAX) then
  begin
    result:= 0;
    exit;
  end;

  if level=QR_ECLEVEL_H then
  begin
    result:= 0;
    exit;
  end;

  typ:= MQRtypeTable[version][ord(level)];
  if typ<0 then
  begin
    result:= 0;
    exit;
  end;

  result:= MQRformatInfo[mask][typ];
end;

(******************************************************************************
 * Frame
 *****************************************************************************)
(**
 * Cache of initial frames.
 *)
(* C99 says that static storage shall be initialized to a null pointer
 * by compiler. *)

var {was static}
  MQRframes: array [0..MQRSPEC_VERSION_MAX] of pcuchar;
{$ifdef HAVE_LIBPTHREAD}
  frames_mutex: pthread_mutex_t = PTHREAD_MUTEX_INITIALIZER;
{$endif}

(**
 * Put a finder pattern.
 * @param frame
 * @param width
 * @param ox,oy upper-left coordinate of the pattern
 *)
procedure MQRputFinderPattern(frame: pcuchar; width: integer; ox: integer; oy: integer);
const
  finder: array [0..48] of cuchar = (
    $c1,$c1,$c1,$c1,$c1,$c1,$c1,
    $c1,$c0,$c0,$c0,$c0,$c0,$c1,
    $c1,$c0,$c1,$c1,$c1,$c0,$c1,
    $c1,$c0,$c1,$c1,$c1,$c0,$c1,
    $c1,$c0,$c1,$c1,$c1,$c0,$c1,
    $c1,$c0,$c0,$c0,$c0,$c0,$c1,
    $c1,$c1,$c1,$c1,$c1,$c1,$c1);
var
  s: pcuchar;
  x: integer;
  y: integer;
begin
  frame := frame + (oy*width + ox);
  s := finder;
  for y:=0 to Pred(7) do
  begin
    for x:=0 to Pred(7) do
    begin
      frame[x]:= s[x];
    end;
    frame:= frame + width;
    s:= s + 7;
  end;
end;

function MQRspec_createFrame(version: integer): pcuchar;
var
  frame, p, q: pcuchar;
  width, x, y: integer;
begin
  width:= mqrspecCapacity[version].width;
  frame:= cmalloc(width*width);
  if frame = nil then
  begin
    result := nil;
    exit;
  end;

  cmemset(frame, 0, width * width);
  putFinderPattern(frame,width,0,0);
  (* Finder pattern *)
  p:= frame; (* Separator *)
  for y:=0 to Pred(7) do
  begin
    p[7] := $c0;
    p := p + width;
  end;
  cmemset(frame + width * 7, $c0, 8);
  (* Mask format information area *)
  cmemset(frame + width * 8 + 1, $84, 8);

  p:= frame+width+8;
  for y:=0 to Pred(7) do
  begin
    p^:=$84;
    p := p + width;
  end;
  p:= frame+8;
  q:= frame+width*8; (* Timing pattern *)
  for x:=1 to Pred(width-7) do
  begin
    p^:=$90 or (x and 1);
    q^:=$90 or (x and 1);
    inc(p);
    q:= q + width;
  end;
  result:= frame;
end;

function MQRspec_newFrame(version: integer): pcuchar;
var
  width: integer;
begin
  if (version<1)or(version>MQRSPEC_VERSION_MAX) then
  begin
    result:= nil;
    exit;
  end;
{$ifdef HAVE_LIBPTHREAD}
  pthread_mutex_lock(&frames_mutex);
{$endif}
  if MQRframes[version]=nil then
    MQRframes[version]:= MQRspec_createFrame(version);

{$ifdef HAVE_LIBPTHREAD}
  pthread_mutex_unlock(&frames_mutex);
{$endif}
  if MQRframes[version]=nil then
  begin
    result:= nil;
    exit;
  end;

  width := mqrspecCapacity[version].width;
  Result := cmalloc(width*width);
  if Result=nil then Exit;

  cmemcpy(Result, MQRframes[version], width*width);
end;

procedure MQRspec_clearCache();
var
  i: integer;
begin
{$ifdef HAVE_LIBPTHREAD}
  pthread_mutex_lock(@frames_mutex);
{$endif}
  for i:=1 to MQRSPEC_VERSION_MAX do
  begin
    freemem(MQRframes[i]);
    MQRframes[i] := nil;
  end;
{$ifdef HAVE_LIBPTHREAD}
  pthread_mutex_unlock(@frames_mutex);
{$endif}
end;


{ $i qrinput.inc}
(******************************************************************************
 * Input data (qrinput.c)
 *****************************************************************************)
(**
   * Singly linked list to contain input strings. An instance of this class
   * contains its version and error correction level too. It is required to
   * set them by QRinput_setVersion() and QRinput_setErrorCorrectionLevel(),
   * or use QRinput_new2() to instantiate an object.
   *)

(******************************************************************************
 * Alphabet-numeric data
 *****************************************************************************)
const
  QRinput_anTable: array [0..127] of cschar = (-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,36,-1,-1,-1,37,38,-1,-1,-1,-1,39,40,-1,41,42,43,0,1,2,3,4,5,6,7,8,9,44,-1,-1,-1,-1,-1,-1,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1);

(**
 * Look up the alphabet-numeric convesion table (see JIS X0510:2004, pp.19).
 * @param __c__ character
 * @return value
 *)
function QRinput_lookAnTable(__c__: cschar): integer; overload;
begin
  if (__c__ and $80) <> 0 then
    Result := -1
  else
    Result := QRinput_anTable[__c__];
end;
function QRinput_lookAnTable(__c__: cuchar): integer; overload;
begin
  if (__c__ and $80) <> 0 then
    Result := -1
  else
    Result := QRinput_anTable[__c__];
end;


(******************************************************************************
 * Numeric data
 *****************************************************************************)
(**
 * Check the input data.
 * @param size
 * @param data
 * @return result
 *)
function QRinput_checkModeNum(size: integer;  data: pcchar): integer;
var
  i: integer;
begin
  for i:=0 to size-1 do
  begin
    if (data[i]<ord('0')) or (data[i]>ord('9')) then
    begin
      result:= -1;
      exit;
    end;
  end;
  result:= 0;
end;

(**
 * Estimates the length of the encoded bit stream of numeric data.
 * @param size
 * @return number of bits
 *)
function QRinput_estimateBitsModeNum(size: integer): integer;
var
  w: integer;
begin
  w:= size div 3;
  Result:= w*10;
  case size-w*3 of
    1: inc(Result, 4);
    2: inc(Result, 7);
  end;
end;

(**
 * Convert the number data to a bit stream.
 * @param entry
 * @param mqr
 * @retval 0 success
 * @retval -1 an error occurred and errno is set to indeicate the error.
 *            See Execptions for the details.
 * @throw ENOMEM unable to allocate memory.
 *)
function QRinput_encodeModeNum(entry: pQRinput_List;  version: integer;  mqr: integer): integer;
var
  words, i, ret: integer;
  val: CUINT;
label ABORT;
begin
  entry^.bstream:= BitStream_new();
  if entry^.bstream=nil then Exit(-1);

  if mqr<>0 then
  begin
    if version>1 then
    begin
      ret:= BitStream_appendNum(entry^.bstream, version-1, MQRSPEC_MODEID_NUM);
      if ret<0 then goto ABORT;
    end;
    ret:= BitStream_appendNum(entry^.bstream, MQRspec_lengthIndicator(QR_MODE_NUM,version), entry^.size);
    if ret<0 then goto ABORT;
  end
  else
  begin
    ret:= BitStream_appendNum(entry^.bstream, 4, QRSPEC_MODEID_NUM);
    if ret<0 then goto ABORT;
    ret:= BitStream_appendNum(entry^.bstream, QRspec_lengthIndicator(QR_MODE_NUM,version), entry^.size);
    if ret<0 then goto ABORT;
  end;

  words:= entry^.size div 3;
  for i:=0 to Pred(words) do
  begin
    val:=       (entry^.data[i*3  ]-ord('0'))*100;
    val:= val + (entry^.data[i*3+1]-ord('0'))*10;
    val:= val + (entry^.data[i*3+2]-ord('0'));
    ret:= BitStream_appendNum(entry^.bstream,10,val);
    if ret<0 then goto ABORT;
  end;

  if entry^.size-words*3=1 then
  begin
    val:= entry^.data[words*3]-ord('0');
    ret:= BitStream_appendNum(entry^.bstream,4,val);
    if ret<0 then goto ABORT;
  end
  else
  if entry^.size-words*3=2 then
  begin
    val:=       (entry^.data[words*3]  -ord('0'))*10;
    val:= val + (entry^.data[words*3+1]-ord('0'));
    BitStream_appendNum(entry^.bstream,7,val);
    if ret<0 then goto ABORT;
  end;

  Result:= 0;
  Exit;

ABORT:
  BitStream_free(entry^.bstream);
  entry^.bstream:= nil;
  Result:= -1;
end;

(* Check the input data.
 * @param size
 * @param data
 * @return result
 *)
function QRinput_checkModeAn(size: integer;  data: pcchar): integer;
var
  i: integer;
begin
  for i:=0 to Pred(size) do
  begin
    if QRinput_lookAnTable(data[i])<0 then
    begin
      result:= -1;
      exit;
    end;
  end;

  result:= 0;
end;

(**
 * Estimates the length of the encoded bit stream of alphabet-numeric data.
 * @param size
 * @return number of bits
 *)
function QRinput_estimateBitsModeAn(size: integer): integer;
var
  w, bits: integer;
begin
  w:= size div 2;
  bits:= w*11;
  if (size and 1) <> 0 then
    bits:= bits + 6;

  result:= bits;
end;

(**
 * Convert the alphabet-numeric data to a bit stream.
 * @param entry
 * @param mqr
 * @retval 0 success
 * @retval -1 an error occurred and errno is set to indeicate the error.
 *            See Execptions for the details.
 * @throw ENOMEM unable to allocate memory.
 * @throw EINVAL invalid version.
 *)
function QRinput_encodeModeAn(entry: pQRinput_List;  version: integer;  mqr: integer): integer;
var
  words, i, ret: integer;
  val: CUINT;
label ABORT;
begin
  entry^.bstream:= BitStream_new();
  if entry^.bstream=nil then
  begin
    result:= -1;
    exit;
  end;

  if mqr<>0 then
  begin
    if version<2 then
    begin
      errno:= EINVAL;
      goto ABORT;
    end;
    ret:= BitStream_appendNum(entry^.bstream, version-1, MQRSPEC_MODEID_AN);
    if ret<0 then goto ABORT;
    ret:= BitStream_appendNum(entry^.bstream, MQRspec_lengthIndicator(QR_MODE_AN, version), entry^.size);
    if ret<0 then goto ABORT;
  end
  else
  begin
    ret:= BitStream_appendNum(entry^.bstream, 4, QRSPEC_MODEID_AN);
    if ret<0 then goto ABORT;
    ret:= BitStream_appendNum(entry^.bstream, QRspec_lengthIndicator(QR_MODE_AN,version), entry^.size);
    if ret<0 then goto ABORT;
  end;

  words:= entry^.size div 2;
  for i:=0 to Pred(words) do
  begin
    val:=       CUINT(QRinput_lookAnTable(entry^.data[i*2])) * 45;
    val:= val + CUINT(QRinput_lookAnTable(entry^.data[i*2+1]));
    ret:= BitStream_appendNum(entry^.bstream,11,val);
    if ret<0 then goto ABORT;
  end;

  if (entry^.size and 1) <> 0 then
  begin
    val:= CUINT(QRinput_lookAnTable(entry^.data[words*2]));
    ret:= BitStream_appendNum(entry^.bstream,6,val);
    if ret<0 then goto ABORT;
  end;

  Result:= 0;
  Exit;

ABORT:
  BitStream_free(entry^.bstream);
  entry^.bstream:=nil;
  Result:= -1;
end;

(******************************************************************************
 * 8 bit data
 *****************************************************************************)
(**
 * Estimates the length of the encoded bit stream of 8 bit data.
 * @param size
 * @return number of bits
 *)
function QRinput_estimateBitsMode8(size: integer): integer;
begin
  result:= size*8;
end;
(**
 * Convert the 8bits data to a bit stream.
 * @param entry
 * @param mqr
 * @retval 0 success
 * @retval -1 an error occurred and errno is set to indeicate the error.
 *            See Execptions for the details.
 * @throw ENOMEM unable to allocate memory.
 *)
function QRinput_encodeMode8(entry: pQRinput_List;  version: integer;  mqr: integer): integer;
var
  ret: integer;
label ABORT;
begin
  entry^.bstream:= BitStream_new();
  if entry^.bstream=nil then
  begin
    result:= -1;
    exit;
  end;

  if mqr<>0 then
  begin
    if version<3 then
    begin
      errno:= EINVAL;
      goto ABORT;
    end;
    ret:= BitStream_appendNum(entry^.bstream, version-1, MQRSPEC_MODEID_8);
    if ret<0 then goto ABORT;
    ret:= BitStream_appendNum(entry^.bstream, MQRspec_lengthIndicator(QR_MODE_8,version), entry^.size);
    if ret<0 then goto ABORT;
  end
  else
  begin
    ret:= BitStream_appendNum(entry^.bstream, 4, QRSPEC_MODEID_8);
    if ret<0 then goto ABORT;
    ret:= BitStream_appendNum(entry^.bstream, QRspec_lengthIndicator(QR_MODE_8,version), entry^.size);
    if ret<0 then goto ABORT;
  end;
  ret:= BitStream_appendBytes(entry^.bstream, entry^.size, entry^.data);
  if ret<0 then goto ABORT;

  result:= 0;
  exit;

ABORT:
  BitStream_free(entry^.bstream);
  entry^.bstream:= nil;
  result:= -1;
end;

(******************************************************************************
 * Kanji data
 *****************************************************************************)
(**
 * Estimates the length of the encoded bit stream of kanji data.
 * @param size
 * @return number of bits
 *)
function QRinput_estimateBitsModeKanji(size: integer): integer;
begin
  result:= (size div 2)*13;
end;
(**
 * Check the input data.
 * @param size
 * @param data
 * @return result
 *)
function QRinput_checkModeKanji(size: integer;  data: pcuchar): integer;
var
  i: integer;
  val: CUINT;
begin
  if (size and 1) <> 0 then
  begin
    result:= -1;
    exit;
  end;

  i:= 0;
  while i<size do
  begin
    val:= (CUINT(data[i]) shl 8) or data[i+1];
    if (val<$8140) or ((val>$9ffc)and(val<$e040)) or (val>$ebbf) then
    begin
      result:= -1;
      exit;
    end;
    i:= i + 2;
  end;

  result:= 0;
end;
(**
 * Convert the kanji data to a bit stream.
 * @param entry
 * @param mqr
 * @retval 0 success
 * @retval -1 an error occurred and errno is set to indeicate the error.
 *            See Execptions for the details.
 * @throw ENOMEM unable to allocate memory.
 * @throw EINVAL invalid version.
 *)
function QRinput_encodeModeKanji(entry: pQRinput_List;  version: integer;  mqr: integer): integer;
var
  ret, i: integer;
  val, h: CUINT;
label ABORT;
begin
  entry^.bstream:= BitStream_new();
  if entry^.bstream=nil then
  begin
    result:= -1;
    exit;
  end;

  if mqr<>0 then
  begin
    if version<2 then
    begin
      errno:= EINVAL;
      goto ABORT;
    end;
    ret:= BitStream_appendNum(entry^.bstream, version-1, MQRSPEC_MODEID_KANJI);
    if ret<0 then goto ABORT;
    ret:= BitStream_appendNum(entry^.bstream, MQRspec_lengthIndicator(QR_MODE_KANJI,version), entry^.size div 2);
    if ret<0 then goto ABORT;
  end
  else
  begin
    ret:= BitStream_appendNum(entry^.bstream, 4, QRSPEC_MODEID_KANJI);
    if ret<0 then goto ABORT;
    ret:= BitStream_appendNum(entry^.bstream, QRspec_lengthIndicator(QR_MODE_KANJI,version), entry^.size div 2);
    if ret<0 then goto ABORT;
  end;

  i:= 0;
  while i<entry^.size do
  begin
    val:= (CUINT(entry^.data[i]) shl 8) or entry^.data[i+1];
    if val<=$9ffc then
      val:= val - $8140
    else
      val:= val - $c140;
    h:= (val shr 8)*$c0;
    val:= (val and $ff)+h;

    ret:= BitStream_appendNum(entry^.bstream,13,val);
    if ret<0 then goto ABORT;
    i:= i + 2;
  end;

  result:= 0;
  exit;

ABORT:
  BitStream_free(entry^.bstream);
  entry^.bstream:=nil;
  result:= -1;
end;

(******************************************************************************
 * Structured Symbol
 *****************************************************************************)
(**
 * Convert a structure symbol code to a bit stream.
 * @param entry
 * @param mqr
 * @retval 0 success
 * @retval -1 an error occurred and errno is set to indeicate the error.
 *            See Execptions for the details.
 * @throw ENOMEM unable to allocate memory.
 * @throw EINVAL invalid entry.
 *)
function QRinput_encodeModeStructure(entry: pQRinput_List;  mqr: integer): integer;
var
  ret: integer;
label ABORT;
begin
  if mqr<>0 then
  begin
    errno:= EINVAL;
    result:= -1;
    exit;
  end;

  entry^.bstream:= BitStream_new();
  if entry^.bstream=nil then
  begin
    result:= -1;
    exit;
  end;

  ret:= BitStream_appendNum(entry^.bstream, 4, QRSPEC_MODEID_STRUCTURE);
  if ret<0 then goto ABORT;
  ret:= BitStream_appendNum(entry^.bstream, 4, entry^.data[1]-1);
  if ret<0 then goto ABORT;
  ret:= BitStream_appendNum(entry^.bstream, 4, entry^.data[0]-1);
  if ret<0 then goto ABORT;
  ret:= BitStream_appendNum(entry^.bstream, 8, entry^.data[2]);
  if ret<0 then goto ABORT;

  result:= 0;
  exit;

ABORT:
  BitStream_free(entry^.bstream);
  entry^.bstream:=nil;
  result:= -1;
end;

(******************************************************************************
 * FNC1
 *****************************************************************************)
function QRinput_checkModeFNC1Second(size: integer;  data: pcuchar): integer;
begin
  if size<>1 then
    result:= -1
  else
    result:= 0;
end;

function QRinput_encodeModeFNC1Second(entry: pQRinput_List;  version: integer): integer;
var
  ret: integer;
label ABORT;
begin
  entry^.bstream:= BitStream_new();
  if entry^.bstream=nil then
  begin
    result:= -1;
    exit;
  end;

  ret:= BitStream_appendNum(entry^.bstream, 4, QRSPEC_MODEID_FNC1SECOND);
  if ret<0 then goto ABORT;
  ret:= BitStream_appendBytes(entry^.bstream, 1, entry^.data);
  if ret<0 then goto ABORT;

  result:= 0;
  exit;

ABORT:
  BitStream_free(entry^.bstream);
  entry^.bstream:=nil;
  result:= -1;
end;

(******************************************************************************
 * Validation
 *****************************************************************************)

function QRinput_check(mode: QRencodeMode;  size: integer;  data: pcuchar): integer;
begin
  if ((mode=QR_MODE_FNC1FIRST) and (size<0)) or (size<=0) then
  begin
    result:= -1;
    exit;
  end;

  case mode of
    QR_MODE_NUM:       result:= QRinput_checkModeNum(size, pcchar(data));
    QR_MODE_AN:        result:= QRinput_checkModeAn (size, pcchar(data));
    QR_MODE_KANJI:     result:= QRinput_checkModeKanji(size, data);
    QR_MODE_8:         result:= 0;
    QR_MODE_STRUCTURE: result:= 0;
    QR_MODE_ECI:       result:= 0;
    QR_MODE_FNC1FIRST: result:= 0;
    QR_MODE_FNC1SECOND:result:= QRinput_checkModeFNC1Second(size,data);
    QR_MODE_NUL:       result:=-1;
  end;
end;

(******************************************************************************
 * Entry of input data
 *****************************************************************************)

function QRinput_List_newEntry(mode: QRencodeMode;  size: integer;  data: pcuchar): pQRinput_List;
var
  entry: pQRinput_List;
begin
  if QRinput_check(mode,size,data) <> 0 then
  begin
    errno:= EINVAL;
    result:=nil;
    exit;
  end;

  entry:= cmalloc(sizeof(tQRinput_List));
  if entry=nil then
  begin
    result:=nil;
    exit;
  end;

  entry^.mode:= mode;
  entry^.size:= size;
  if size>0 then
  begin
    entry^.data:= cmalloc(size);
    if entry^.data=nil then
    begin
      cfree(entry);
      result:=nil;
      exit;
    end;
    cmemcpy(entry^.data, data, size);
  end;
  entry^.bstream:=nil;
  entry^.next:=nil;
  result:= entry;
end;

procedure QRinput_List_freeEntry(entry: pQRinput_List);
begin
  if entry<>nil then
  begin
    cfree(entry^.data);
    BitStream_free(entry^.bstream);
    cfree(entry);
  end;
end;

function QRinput_List_dup(entry: pQRinput_List): pQRinput_List;
var
  n: pQRinput_List;
begin
  n:= cmalloc(sizeof(tQRinput_List));
  if n=nil then
  begin
    result:=nil;
    exit;
  end;

  n^.mode:= entry^.mode;
  n^.size:= entry^.size;
  n^.data:= cmalloc(n^.size);
  if n^.data=nil then
  begin
    cfree(n);
    result:=nil;
    exit;
  end;

  cmemcpy(n^.data, entry^.data, entry^.size);
  n^.bstream:=nil;
  n^.next:=nil;
  result:= n;
end;

(******************************************************************************
 * Input Data
 *****************************************************************************)

(**
 * Instantiate an input data object.
 * @param version version number.
 * @param level Error correction level.
 * @return an input object (initialized). On error, NULL is returned and errno
 *         is set to indicate the error.
 * @throw ENOMEM unable to allocate memory for input objects.
 * @throw EINVAL invalid arguments.
 *)
function QRinput_new2(version: integer;  level: QRecLevel): pQRinput;
begin
  if (version<0) or (version>QRSPEC_VERSION_MAX) or (level>QR_ECLEVEL_H) then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  Result := cmalloc(sizeof(tQRinput));
  if Result=nil then Exit;

  Result^.head:=nil;
  Result^.tail:=nil;
  Result^.version:= version;
  Result^.level:= level;
  Result^.mqr:= 0;
  Result^.fnc1:= 0;
end;

(**
 * Instantiate an input data object. The version is set to 0 (auto-select)
 * and the error correction level is set to QR_ECLEVEL_L.
 * @return an input object (initialized). On error, NULL is returned and errno
 *         is set to indicate the error.
 * @throw ENOMEM unable to allocate memory.
 *)
function QRinput_new(): pQRinput;
begin
  result:= QRinput_new2(0,QR_ECLEVEL_L);
end;

(**
 * Instantiate an input data object. Object's Micro QR Code flag is set.
 * Unlike with full-sized QR Code, version number must be specified (>0).
 * @param version version number (1--4).
 * @param level Error correction level.
 * @return an input object (initialized). On error, NULL is returned and errno
 *         is set to indicate the error.
 * @throw ENOMEM unable to allocate memory for input objects.
 * @throw EINVAL invalid arguments.
 *)
function QRinput_newMQR(version: integer;  level: QRecLevel): pQRinput;
label INVALID;
begin
  if (version<=0) or (version>MQRSPEC_VERSION_MAX) then goto INVALID;

  if MQRspec_getECCLength(version,level)=0 then goto INVALID;

  Result := QRinput_new2(version,level);
  if Result=nil then Exit;

  Result^.mqr:= 1;
  Exit;

INVALID:
  errno:= EINVAL;
  Result := nil;
end;

function QRinput_getVersion(input: pQRinput): integer;
begin
  Result:= input^.version;
end;

(**
 * Set version of the QR code that is to be encoded.
 * This function cannot be applied to Micro QR Code.
 * @param input input object.
 * @param version version number (0 = auto)
 * @retval 0 success.
 * @retval -1 invalid argument.
 *)
function QRinput_setVersion(input: pQRinput;  version: integer): integer;
begin
  if (input^.mqr<>0) or (version<0) or (version>QRSPEC_VERSION_MAX) then
  begin
    errno:= EINVAL;
    result:= -1;
  end
  else
  begin
    input^.version:= version;
    result:= 0;
  end;
end;

function QRinput_getErrorCorrectionLevel(input: pQRinput): QRecLevel;
begin
  result:= input^.level;
end;

(**
 * Set error correction level of the QR code that is to be encoded.
 * This function cannot be applied to Micro QR Code.
 * @param input input object.
 * @param level Error correction level.
 * @retval 0 success.
 * @retval -1 invalid argument.
 *)
function QRinput_setErrorCorrectionLevel(input: pQRinput;  level: QRecLevel): integer;
begin
  if (input^.mqr<>0) or (level>QR_ECLEVEL_H) then
  begin
    errno:= EINVAL;
    result:= -1;
  end
  else
  begin
    input^.level:= level;
    result:= 0;
  end;
end;

(**
 * Set version and error correction level of the QR code at once.
 * This function is recommened for Micro QR Code.
 * @param input input object.
 * @param version version number (0 = auto)
 * @param level Error correction level.
 * @retval 0 success.
 * @retval -1 invalid argument.
 *)
function QRinput_setVersionAndErrorCorrectionLevel(input: pQRinput;  version: integer;  level: QRecLevel): integer;
label INVALID;
begin
  if input^.mqr<>0 then
  begin
    if (version<=0) or (version>MQRSPEC_VERSION_MAX) then goto INVALID;
    if MQRspec_getECCLength(version,level)=0 then goto INVALID;
  end
  else
  begin
    if (version<0) or (version>QRSPEC_VERSION_MAX) then goto INVALID;
    if level>QR_ECLEVEL_H then goto INVALID;
  end;
  input^.version:= version;
  input^.level:= level;
  result:= 0;
  exit;

INVALID:
  errno:= EINVAL;
  result:= -1;
end;

procedure QRinput_appendEntry(input: pQRinput;  entry: pQRinput_List);
begin
  if input^.tail=nil then
  begin
    input^.head:= entry;
    input^.tail:= entry;
  end
  else
  begin
    input^.tail^.next:= entry;
    input^.tail:= entry;
  end;
  entry^.next:= nil;
end;

(**
 * Append data to an input object.
 * The data is copied and appended to the input object.
 * @param input input object.
 * @param mode encoding mode.
 * @param size size of data (byte).
 * @param data a pointer to the memory area of the input data.
 * @retval 0 success.
 * @retval -1 an error occurred and errno is set to indeicate the error.
 *            See Execptions for the details.
 * @throw ENOMEM unable to allocate memory.
 * @throw EINVAL input data is invalid.
 *
 *)
function QRinput_append(input: pQRinput;  mode: QRencodeMode;  size: integer;  data: pcuchar): integer;
var
  entry: pQRinput_List;
begin
  entry:= QRinput_List_newEntry(mode,size,data);
  if entry=nil then
    result:= -1
  else
  begin
    QRinput_appendEntry(input,entry);
    result:= 0;
  end;
end;

(**
 * Insert a structured-append header to the head of the input data.
 * @param input input data.
 * @param size number of structured symbols.
 * @param number index number of the symbol. (1 <= number <= size)
 * @param parity parity among input data. (NOTE: each symbol of a set of structured symbols has the same parity data)
 * @retval 0 success.
 * @retval -1 error occurred and errno is set to indeicate the error. See Execptions for the details.
 * @throw EINVAL invalid parameter.
 * @throw ENOMEM unable to allocate memory.
 *)
function QRinput_insertStructuredAppendHeader(input: pQRinput;  size: integer;  number: integer;  parity: cuchar): integer;
var
  entry: pQRinput_List;
  buf: array [0..Pred(3)] of cuchar;
begin
  if size>MAX_STRUCTURED_SYMBOLS then
  begin
    errno:= EINVAL;
    result:= -1;
    exit;
  end;

  if (number<=0)or(number>size) then
  begin
    errno:= EINVAL;
    result:= -1;
    exit;
  end;

  buf[0]:= size;
  buf[1]:= number;
  buf[2]:= parity;
  entry:= QRinput_List_newEntry(QR_MODE_STRUCTURE,3,buf);
  if entry=nil then
  begin
    result:= -1;
    exit;
  end;
  entry^.next:= input^.head;
  input^.head:= entry;
  result:= 0;
end;

function QRinput_appendECIheader(input: pQRinput;  ecinum: CUINT): integer;
var
  data: array [0..Pred(4)] of cuchar;
begin
  if ecinum>999999 then
  begin
    errno:= EINVAL;
    result:= -1;
    exit;
  end;

  (* We manually create byte array of ecinum because (unsigned char * )&ecinum may cause bus error on some architectures, *)
  data[0]:=  ecinum and $ff;
  data[1]:= (ecinum shr 8) and $ff;
  data[2]:= (ecinum shr 16) and $ff;
  data[3]:= (ecinum shr 24) and $ff;
  result:= QRinput_append(input,QR_MODE_ECI,4,data);
end;

procedure QRinput_free(input: pQRinput);
var
  list: pQRinput_List;
  next: pQRinput_List;
begin
  if input<>nil then
  begin
    list:= input^.head;
    while list<>nil do
    begin
      next:= list^.next;
      QRinput_List_freeEntry(list);
      list:= next;
    end;
    cfree(input);
  end;
end;

function QRinput_calcParity(input: pQRinput): cuchar;
var
  parity: cuchar;
  list: pQRinput_List;
  i: integer;
begin
  parity:=0;

  list:= input^.head;
  while list<>nil do
  begin
    if list^.mode<>QR_MODE_STRUCTURE then
    begin
      for i:=list^.size-1 downto 0 do
        parity:= parity xor (list^.data[i]);
    end;
    list:= list^.next;
  end;

  result:= parity;
end;

function QRinput_dup(input: pQRinput): pQRinput;
var
  n: pQRinput;
  list: pQRinput_List;
  e: pQRinput_List;
begin
  if input^.mqr<>0then
    n:= QRinput_newMQR(input^.version, input^.level)
  else
    n:= QRinput_new2(input^.version, input^.level);

  if n=nil then
  begin
    result:= nil;
    exit;
  end;

  list:= input^.head;
  while list<>nil do
  begin
    e:= QRinput_List_dup(list);
    if e=nil then
    begin
      QRinput_free(n);
      result:= nil;
      exit;
    end;
    QRinput_appendEntry(n,e);
    list:= list^.next;
  end;

  result:= n;
end;

(******************************************************************************
 * ECI header
 *****************************************************************************)

function QRinput_decodeECIfromByteArray(data: pcuchar): CUINT;
var
  i: integer;
  ecinum: CUINT;
begin
  ecinum:= 0;
  for i:=0 to Pred(4) do
  begin
    ecinum:= ecinum shl 8;
    ecinum:= ecinum or (data[3-i]);
  end;

  result:= ecinum;
end;

function QRinput_estimateBitsModeECI(data: pcuchar): integer;
var
  ecinum: CUINT;
begin
  ecinum:= QRinput_decodeECIfromByteArray(data);
  (* See Table 4 of JISX 0510:2004 pp.17. *)
  if ecinum<128 then
    result:= MODE_INDICATOR_SIZE+8
  else if ecinum<16384 then
    result:= MODE_INDICATOR_SIZE+16
  else
    result:= MODE_INDICATOR_SIZE+24;
end;

function QRinput_encodeModeECI(entry: pQRinput_List;  version: integer): integer;
var
ret, words: integer;
ecinum, code: CUINT;
label ABORT;
begin
  entry^.bstream:= BitStream_new();
  if entry^.bstream=nil then
  begin
    result:= -1;
    exit;
  end;

  ecinum:= QRinput_decodeECIfromByteArray(entry^.data);

  (* See Table 4 of JISX 0510:2004 pp.17. *)
  if ecinum<128 then
  begin
    words:= 1;
    code:= ecinum;
  end
  else if ecinum<16384 then
  begin
    words:= 2;
    code:= $8000+ecinum;
  end
  else
  begin
    words:= 3;
    code:= $c0000+ecinum;
  end;

  ret:= BitStream_appendNum(entry^.bstream, 4, QRSPEC_MODEID_ECI);
  if ret<0 then goto ABORT;
  ret:= BitStream_appendNum(entry^.bstream, words*8, code);
  if ret<0 then goto ABORT;
  result:= 0;
  Exit;

ABORT:
  BitStream_free(entry^.bstream);
  entry^.bstream:= nil;
  result:= -1;
end;

(******************************************************************************
 * Estimation of the bit length
 *****************************************************************************)
(**
 * Estimates the length of the encoded bit stream on the current version.
 * @param entry
 * @param version version of the symbol
 * @param mqr
 * @return number of bits
 *)
function QRinput_estimateBitStreamSizeOfEntry(entry: pQRinput_List;  version: integer;  mqr: integer): integer;
var
  bits: integer;
  l, m, num: integer;
begin
  bits:=0;

  if version=0 then version:= 1;

  case entry^.mode of
    QR_MODE_NUM:
      bits:= QRinput_estimateBitsModeNum(entry^.size);
    QR_MODE_AN:
      bits:= QRinput_estimateBitsModeAn(entry^.size);
    QR_MODE_8:
      bits:= QRinput_estimateBitsMode8(entry^.size);
    QR_MODE_KANJI:
      bits:= QRinput_estimateBitsModeKanji(entry^.size);
    QR_MODE_STRUCTURE:
      begin
      result:= STRUCTURE_HEADER_SIZE;
      exit;
      end;
    QR_MODE_ECI:
      bits:= QRinput_estimateBitsModeECI(entry^.data);
    QR_MODE_FNC1FIRST:
      begin
      result:= MODE_INDICATOR_SIZE;
      exit;
      end;
    QR_MODE_FNC1SECOND:
      begin
      result:= MODE_INDICATOR_SIZE+8;
      exit;
      end
    else
      begin
      result:= 0;
      exit;
      end;
  end;{case}

  if mqr<>0 then
  begin
    l:= QRspec_lengthIndicator(entry^.mode,version);
    m:= version-1;
    bits:= bits + (l+m);
  end
  else
  begin
    l:= QRspec_lengthIndicator(entry^.mode,version);
    m:= 1 shl l;
    num:= (entry^.size+m-1) div m;
    bits:= bits + num*(MODE_INDICATOR_SIZE+l);
  end;

  result:= bits;
end;

(**
 * Estimates the length of the encoded bit stream of the data.
 * @param input input data
 * @param version version of the symbol
 * @return number of bits
 *)
function QRinput_estimateBitStreamSize(input: pQRinput;  version: integer): integer;
var
  list: pQRinput_List;
begin
  Result:=0;
  list:= input^.head;
  while list<>nil do
  begin
    Result:= Result + QRinput_estimateBitStreamSizeOfEntry(list,version,input^.mqr);
    list:= list^.next;
  end;
end;

(**
 * Estimates the required version number of the symbol.
 * @param input input data
 * @return required version number
 *)
function QRinput_estimateVersion(input: pQRinput): integer;
var
  bits: integer;
  prev: integer;
begin
  Result:= 0;
  repeat
    prev:= Result;
    bits:= QRinput_estimateBitStreamSize(input,prev);
    Result := QRspec_getMinimumVersion((bits+7) div 8, input^.level);
    if Result<0 then
    begin
      Result:= -1;
      exit;
    end;
  until not (Result>prev);
end;

(**
 * Returns required length in bytes for specified mode, version and bits.
 * @param mode
 * @param version
 * @param bits
 * @return required length of code words in bytes.
 *)
function QRinput_lengthOfCode(mode: QRencodeMode;  version: integer;  bits: integer): integer;
var
  payload, size, chunks, remain, maxsize: integer;
begin
  payload:= bits-4-QRspec_lengthIndicator(mode,version);
  case mode of
    QR_MODE_NUM:
    begin
      chunks:= payload div 10;
      remain:= payload-chunks*10;
      size:= chunks*3;
      if remain>=7 then
        size:= size + 2
      else if remain>=4 then
        size:= size + 1;
    end;
    QR_MODE_AN:
    begin
      chunks:= payload div 11;
      remain:= payload-chunks*11;
      size:= chunks*2;
      if remain>=6 then
        inc(size);
    end;
    QR_MODE_8:
    begin
      size:= payload div 8;
    end;
    QR_MODE_KANJI:
    begin
      size:= (payload div 13)*2;
    end;
    QR_MODE_STRUCTURE:
    begin
      size:= payload div 8;
    end;
    else
      size:= 0;
  end;{case}

  maxsize:= QRspec_maximumWords(mode,version);
  if size<0 then size:= 0;
  if (maxsize>0) and (size>maxsize) then size:= maxsize;

  result:= size;
end;

(******************************************************************************
 * Data conversion
 *****************************************************************************)
(**
 * Convert the input data in the data chunk to a bit stream.
 * @param entry
 * @return number of bits (>0) or -1 for failure.
 *)
function QRinput_encodeBitStream(entry: pQRinput_List;  version: integer;  mqr: integer): integer;
var
words, ret: integer;
st1, st2: pQRinput_List;
label ABORT;
begin
  st1:=nil;
  st2:=nil;

  if entry^.bstream<>nil then
  begin
    BitStream_free(entry^.bstream);
    entry^.bstream:= nil;
  end;

  words:= QRspec_maximumWords(entry^.mode,version);
  if (words<>0) and (entry^.size>words) then
  begin
    st1:= QRinput_List_newEntry(entry^.mode, words, entry^.data);
    if st1=nil then goto ABORT;
    st2:= QRinput_List_newEntry(entry^.mode, entry^.size-words, @(entry^.data[words]));
    if st2=nil then goto ABORT;
    ret:= QRinput_encodeBitStream(st1,version,mqr);
    if ret<0 then goto ABORT;
    ret:= QRinput_encodeBitStream(st2,version,mqr);
    if ret<0 then goto ABORT;
    entry^.bstream:= BitStream_new();
    if entry^.bstream=nil then goto ABORT;
    ret:= BitStream_append(entry^.bstream, st1^.bstream);
    if ret<0 then goto ABORT;
    ret:= BitStream_append(entry^.bstream, st2^.bstream);
    if ret<0 then goto ABORT;
    QRinput_List_freeEntry(st1);
    QRinput_List_freeEntry(st2);
  end
  else
  begin
    ret:= 0;
    case entry^.mode of
      QR_MODE_NUM:
        ret:= QRinput_encodeModeNum(entry,version,mqr);
      QR_MODE_AN:
        ret:= QRinput_encodeModeAn(entry,version,mqr);
      QR_MODE_8:
        ret:= QRinput_encodeMode8(entry,version,mqr);
      QR_MODE_KANJI:
        ret:= QRinput_encodeModeKanji(entry,version,mqr);
      QR_MODE_STRUCTURE:
        ret:= QRinput_encodeModeStructure(entry,mqr);
      QR_MODE_ECI:
        ret:= QRinput_encodeModeECI(entry,version);
      QR_MODE_FNC1SECOND:
        ret:= QRinput_encodeModeFNC1Second(entry,version);
    end;{case}

    if ret<0 then
    begin
      result:= -1;
      exit;
    end;
  end;

  result:= BitStream_size(entry^.bstream);
  Exit;

ABORT:
  QRinput_List_freeEntry(st1);
  QRinput_List_freeEntry(st2);
  result:= -1;
end;

(**
 * Convert the input data to a bit stream.
 * @param input input data.
 * @retval 0 success
 * @retval -1 an error occurred and errno is set to indeicate the error.
 *            See Execptions for the details.
 * @throw ENOMEM unable to allocate memory.
 *)
function QRinput_createBitStream(input: pQRinput): integer;
var
  list: pQRinput_List;
  bits, total: integer;
begin
  total:=0;
  list:= input^.head;
  while list<>nil do
  begin
    bits:= QRinput_encodeBitStream(list, input^.version, input^.mqr);
    if bits<0 then
    begin
      result:= -1;
      exit;
    end;
    total:= total + bits;
    list:= list^.next;
  end;

  result:= total;
end;

(**
 * Convert the input data to a bit stream.
 * When the version number is given and that is not sufficient, it is increased
 * automatically.
 * @param input input data.
 * @retval 0 success
 * @retval -1 an error occurred and errno is set to indeicate the error.
 *            See Execptions for the details.
 * @throw ENOMEM unable to allocate memory.
 * @throw ERANGE input is too large.
 *)
function QRinput_convertData(input: pQRinput): integer;
var
  bits, ver: integer;
begin
  ver:= QRinput_estimateVersion(input);
  if ver>QRinput_getVersion(input) then
    QRinput_setVersion(input,ver);

  while true do
  begin
    bits:= QRinput_createBitStream(input);
    if bits<0 then
    begin
      result:= -1;
      exit;
    end;
    ver:= QRspec_getMinimumVersion((bits+7) div 8, input^.level);
    if ver<0 then
    begin
      errno:= ERANGE;
      result:= -1;
      exit;
    end
    else if ver>QRinput_getVersion(input) then
      QRinput_setVersion(input,ver)
    else
      break;
  end;

  result:= 0;
end;

(**
 * Append padding bits for the input data.
 * @param bstream Bitstream to be appended.
 * @param input input data.
 * @retval 0 success
 * @retval -1 an error occurred and errno is set to indeicate the error.
 *            See Execptions for the details.
 * @throw ERANGE input data is too large.
 * @throw ENOMEM unable to allocate memory.
 *)
function QRinput_appendPaddingBit(bstream: pBitStream;  input: pQRinput): integer;
var
  bits, maxbits, words, maxwords, i, ret: integer;
  padding: pBitStream;
  padbuf: pcuchar;
  padlen: integer;
label DONE;
begin
  padding:=nil;

  bits:= BitStream_size(bstream);
  maxwords:= QRspec_getDataLength(input^.version, input^.level);
  maxbits:= maxwords*8;

  if maxbits<bits then
  begin
    errno:= ERANGE;
    result:= -1;
    exit;
  end;

  if maxbits=bits then
  begin
    result:= 0;
    exit;
  end;

  if maxbits-bits<=4 then
  begin
    ret:= BitStream_appendNum(bstream,maxbits-bits,0);
    goto DONE;
  end;

  words:= (bits+4+7) div 8;

  padding:= BitStream_new();
  if padding=nil then
  begin
    result:= -1;
    exit;
  end;

  ret:= BitStream_appendNum(padding,words*8-bits,0);
  if ret<0 then goto DONE;
  padlen:= maxwords-words;
  if padlen>0 then
  begin
    padbuf:= cmalloc(padlen);
    if padbuf=nil then
    begin
      ret:= -1;
      goto DONE;
    end;
    for i:=0 to Pred(padlen) do
      if (i and 1) <> 0 then
        padbuf[i] := $11
      else
        padbuf[i] := $ec;

    ret:= BitStream_appendBytes(padding,padlen,padbuf);
    cfree(padbuf);
    if ret<0 then goto DONE;
  end;

  ret:= BitStream_append(bstream,padding);

DONE:
  BitStream_free(padding);
  result:= ret;
end;

(**
 * Append padding bits for the input data - Micro QR Code version.
 * @param bstream Bitstream to be appended.
 * @param input input data.
 * @retval 0 success
 * @retval -1 an error occurred and errno is set to indeicate the error.
 *            See Execptions for the details.
 * @throw ERANGE input data is too large.
 * @throw ENOMEM unable to allocate memory.
 *)
function QRinput_appendPaddingBitMQR(bstream: pBitStream;  input: pQRinput): integer;
var
  bits, maxbits, words, maxwords, i, ret: integer;
  termbits: integer;
  padding: pBitStream;
  padbuf: pcuchar;
  padlen: integer;
label DONE;
begin
  padding:=nil;

  bits:= BitStream_size(bstream);
  maxbits:= MQRspec_getDataLengthBit(input^.version, input^.level);
  maxwords:= maxbits div 8;
  if maxbits<bits then
  begin
    errno:= ERANGE;
    result:= -1;
    exit;
  end;

  if maxbits=bits then
  begin
    result:= 0;
    exit;
  end;

  termbits:= input^.version*2+1;
  if maxbits-bits<=termbits then
  begin
    ret:= BitStream_appendNum(bstream,maxbits-bits,0);
    goto DONE;
  end;

  bits:= bits + (termbits);
  words:= (bits+7) div 8;
  if maxbits-words*8>0 then
  begin
    termbits:= termbits + (words*8-bits);
    if words=maxwords then
    termbits:= termbits + (maxbits-words*8);
  end
  else
    termbits:= termbits + (words*8-bits);

  padding:= BitStream_new();
  if padding=nil then
  begin
    result:= -1;
    exit;
  end;

  ret:= BitStream_appendNum(padding,termbits,0);
  if ret<0 then goto DONE;
  padlen:= maxwords-words;
  if padlen>0 then
  begin
    padbuf:= cmalloc(padlen);
    if padbuf=nil then
    begin
      ret:= -1;
      goto DONE;
    end;
    for i:=0 to Pred(padlen) do
      if (i and 1) <> 0 then
        padbuf[i]:=  $11
      else
        padbuf[i]:=  $ec;

    ret:= BitStream_appendBytes(padding,padlen,padbuf);
    cfree(padbuf);
    if ret<0 then goto DONE;

    termbits:= maxbits-maxwords*8;
    if termbits>0  then
    begin
      ret:= BitStream_appendNum(padding,termbits,0);
      if ret<0 then goto DONE;
    end;
  end;

  ret:= BitStream_append(bstream,padding);
DONE:
  BitStream_free(padding);
  result:= ret;
end;

function QRinput_insertFNC1Header(input: pQRinput): integer;
var
  entry: pQRinput_List;
begin
  entry:=nil;
  if input^.fnc1=1 then
    entry:= QRinput_List_newEntry(QR_MODE_FNC1FIRST, 0, nil)
  else if input^.fnc1=2 then
    entry:= QRinput_List_newEntry(QR_MODE_FNC1SECOND, 1, @(input^.appid));

  if entry=nil then
  begin
    result:= -1;
    exit;
  end;

  if (input^.head^.mode<>QR_MODE_STRUCTURE) or (input^.head^.mode<>QR_MODE_ECI) then
  begin
    entry^.next:= input^.head;
    input^.head:= entry;
  end
  else
  begin
    entry^.next:= input^.head^.next;
    input^.head^.next:= entry;
  end;

  result:= 0;
end;

(**
 * Merge all bit streams in the input data.
 * @param input input data.
 * @return merged bit stream
 *)
function QRinput_mergeBitStream(input: pQRinput): pBitStream;
var
  bstream: pBitStream;
  list: pQRinput_List;
  ret: integer;
begin
  if input^.mqr<>0 then
  begin
    if QRinput_createBitStream(input)<0 then
    begin
      result:= nil;
      exit;
    end;
  end
  else
  begin
    if input^.fnc1<>0 then
    begin
      if QRinput_insertFNC1Header(input)<0 then
      begin
        result:= nil;
        exit;
      end;
    end;
    if QRinput_convertData(input)<0 then
    begin
      result:= nil;
      exit;
    end;
  end;

  bstream:= BitStream_new();
  if bstream=nil then
  begin
    result:= nil;
    exit;
  end;

  list:= input^.head;
  while list<>nil do
  begin
    ret:= BitStream_append(bstream, list^.bstream);
    if ret<0 then
    begin
      BitStream_free(bstream);
      result:= nil;
      exit;
    end;
    list:= list^.next;
  end;

  result:= bstream;
end;

(**
 * Merge all bit streams in the input data and append padding bits
 * @param input input data.
 * @return padded merged bit stream
 *)
function QRinput_getBitStream(input: pQRinput): pBitStream;
var
  bstream: pBitStream;
  ret: integer;
begin
  bstream:= QRinput_mergeBitStream(input);
  if bstream=nil then
  begin
    result:= nil;
    exit;
  end;

  if input^.mqr<>0 then
    ret:= QRinput_appendPaddingBitMQR(bstream,input)
  else
    ret:= QRinput_appendPaddingBit(bstream,input);

  if ret<0 then
  begin
    BitStream_free(bstream);
    result:= nil;
    exit;
  end;

  result:= bstream;
end;

(**
 * Pack all bit streams padding bits into a byte array.
 * @param input input data.
 * @return padded merged byte stream
 *)
function QRinput_getByteStream(input: pQRinput): pcuchar;
var
  bstream: pBitStream;
begin
  bstream:= QRinput_getBitStream(input);
  if bstream=nil then
  begin
    result:= nil;
    exit;
  end;

  Result := BitStream_toByte(bstream);
  BitStream_free(bstream);
end;

(******************************************************************************
 * Structured input data
 *****************************************************************************)

function QRinput_InputList_newEntry(input: pQRinput): pQRinput_InputList;
var
  entry: pQRinput_InputList;
begin
  entry:= cmalloc(sizeof(tQRinput_InputList));
  if entry=nil then
  begin
    result:= nil;
    exit;
  end;

  entry^.input:= input;
  entry^.next:= nil;
  result:= entry;
end;

procedure QRinput_InputList_freeEntry(entry: pQRinput_InputList);
begin
  if entry<>nil then
  begin
    QRinput_free(entry^.input);
    cfree(entry);
  end;
end;

(**
 * Instantiate a set of input data object.
 * @return an instance of QRinput_Struct. On error, NULL is returned and errno
 *         is set to indicate the error.
 * @throw ENOMEM unable to allocate memory.
 *)
function QRinput_Struct_new(): pQRinput_Struct;
begin
  Result := cmalloc(sizeof(tQRinput_Struct));
  if Result = nil then Exit;

  Result^.size:= 0;
  Result^.parity:= -1;
  Result^.head:= nil;
  Result^.tail:= nil;
end;

procedure QRinput_Struct_setParity(s: pQRinput_Struct;  parity: cuchar);
begin
  s^.parity := integer(parity);
end;

(**
 * Append a QRinput object to the set. QRinput created by QRinput_newMQR()
 * will be rejected.
 * @warning never append the same QRinput object twice or more.
 * @param s structured input object.
 * @param input an input object.
 * @retval >0 number of input objects in the structure.
 * @retval -1 an error occurred. See Exceptions for the details.
 * @throw ENOMEM unable to allocate memory.
 * @throw EINVAL invalid arguments.
 *)
function QRinput_Struct_appendInput(s: pQRinput_Struct;  input: pQRinput): integer;
var
  e: pQRinput_InputList;
begin
  if input^.mqr<>0 then
  begin
    errno:= EINVAL;
    result:= -1;
    exit;
  end;

  e:= QRinput_InputList_newEntry(input);
  if e=nil then
  begin
    result:= -1;
    exit;
  end;

  inc(s^.size);
  if s^.tail=nil then
  begin
    s^.head:= e;
    s^.tail:= e;
  end
  else
  begin
    s^.tail^.next:= e;
    s^.tail:= e;
  end;

  result:= s^.size;
end;

(**
 * Free all of QRinput in the set.
 * @param s a structured input object.
 *)
procedure QRinput_Struct_free(s: pQRinput_Struct);
var
  list: pQRinput_InputList;
  next: pQRinput_InputList;
begin
  if s<>nil then
  begin
    list:= s^.head;
    while list<>nil do
    begin
      next:= list^.next;
      QRinput_InputList_freeEntry(list);
      list:= next;
    end;
    cfree(s);
  end;
end;

function QRinput_Struct_calcParity(s: pQRinput_Struct): cuchar;
var
  list: pQRinput_InputList;
begin
  Result:=0;
  list:= s^.head;
  while list<>nil do
  begin
    Result := Result xor QRinput_calcParity(list^.input);
    list:= list^.next;
  end;

  QRinput_Struct_setParity(s, Result);
end;

function QRinput_List_shrinkEntry(entry: pQRinput_List;  bytes: integer): integer;
var
  data: pcuchar;
begin
  data := cmalloc(bytes);
  if data=nil then
  begin
    result:= -1;
    exit;
  end;
  cmemcpy(data, entry^.data, bytes);
  cfree(entry^.data);
  entry^.data:= data;
  entry^.size:= bytes;
  result:= 0;
end;

function QRinput_splitEntry(entry: pQRinput_List;  bytes: integer): integer;
var
  e: pQRinput_List;
  ret: integer;
begin
  e:= QRinput_List_newEntry(entry^.mode, entry^.size-bytes, entry^.data+bytes);
  if e=nil then
  begin
    result:= -1;
    exit;
  end;

  ret:= QRinput_List_shrinkEntry(entry,bytes);
  if ret<0 then
  begin
    QRinput_List_freeEntry(e);
    result:= -1;
    exit;
  end;

  e^.next:= entry^.next;
  entry^.next:= e;

  result:= 0;
end;

(**
 * Insert structured-append headers to the input structure. It calculates
 * a parity and set it if the parity is not set yet.
 * @param s input structure
 * @retval 0 success.
 * @retval -1 an error occurred and errno is set to indeicate the error.
 *            See Execptions for the details.
 * @throw EINVAL invalid input object.
 * @throw ENOMEM unable to allocate memory.
 *)
function QRinput_Struct_insertStructuredAppendHeaders(s: pQRinput_Struct): integer;
var
  i: integer;
  list: pQRinput_InputList;
begin
  if s^.size = 1 then
  begin
    Result := 0;
    Exit;
  end;

  if s^.parity<0 then
    QRinput_Struct_calcParity(s);

  i:= 1;
  list:= s^.head;
  while list<>nil do
  begin
    if QRinput_insertStructuredAppendHeader(list^.input, s^.size, i, s^.parity)<>0 then
    begin
      result:= -1;
      exit;
    end;
    inc(i);
    list:= list^.next;
  end;

  result:= 0;
end;

(**
 * Split a QRinput to QRinput_Struct. It calculates a parity, set it, then
 * insert structured-append headers. QRinput created by QRinput_newMQR() will
 * be rejected.
 * @param input input object. Version number and error correction level must be
 *        set.
 * @return a set of input data. On error, NULL is returned, and errno is set
 *         to indicate the error. See Exceptions for the details.
 * @throw ERANGE input data is too large.
 * @throw EINVAL invalid input data.
 * @throw ENOMEM unable to allocate memory.
 *)
function QRinput_splitQRinputToStruct(input: pQRinput): pQRinput_Struct;
var
  p: pQRinput;
  s: pQRinput_Struct;
  bits, maxbits, nextbits, bytes, ret: integer;
  list, next, prev: pQRinput_List;
label ABORT;
begin
  if input^.mqr<>0 then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  s:= QRinput_Struct_new();
  if s=nil then
  begin
    result:= nil;
    exit;
  end;

  input:= QRinput_dup(input);
  if input=nil then
  begin
    QRinput_Struct_free(s);
     result:= nil;
    exit;
  end;

  QRinput_Struct_setParity(s,QRinput_calcParity(input));
  maxbits:= QRspec_getDataLength(input^.version, input^.level)*8 - STRUCTURE_HEADER_SIZE;
  if maxbits<=0 then
  begin
    QRinput_Struct_free(s);
    QRinput_free(input);
    result:= nil;
    exit;
  end;

  bits:= 0;
  list:= input^.head;
  prev:= nil;
  while list<>nil do
  begin
    nextbits:= QRinput_estimateBitStreamSizeOfEntry(list, input^.version, input^.mqr);
    if bits+nextbits<=maxbits then
    begin
      ret:= QRinput_encodeBitStream(list, input^.version, input^.mqr);
      if ret<0 then goto ABORT;
      bits:= bits + ret;
      prev:= list;
      list:= list^.next;
    end
    else
    begin
      bytes:= QRinput_lengthOfCode(list^.mode, input^.version, maxbits-bits);
      p:= QRinput_new2(input^.version, input^.level);
      if p=nil then goto ABORT;
      if bytes>0 then
      begin
        (* Splits this entry into 2 entries. *)
        ret:= QRinput_splitEntry(list,bytes);
        if ret<0 then
        begin
          QRinput_free(p);
          goto ABORT;
        end;
        next:= list^.next;
        list^.next:= nil;
        p^.head:= next;
        p^.tail:= input^.tail;
        input^.tail:= list;
        prev:= list;
        list:= next;
        (* First half is the tail of the current input. *)
        (* Second half is the head of the next input, p.*)
        (* Renew QRinput.tail. *)
        (* Point to the next entry. *)
      end
      else
      begin
        (* Current entry will go to the next input. *)
        prev^.next:= nil;
        p^.head:= list;
        p^.tail:= input^.tail;
        input^.tail:= prev;
      end;
      ret:= QRinput_Struct_appendInput(s,input);
      if ret<0 then
      begin
        QRinput_free(p);
        goto ABORT;
      end;
      input:= p;
      bits:= 0;
    end;
  end;

  ret:= QRinput_Struct_appendInput(s,input);
  if ret<0 then goto ABORT;
  if s^.size>MAX_STRUCTURED_SYMBOLS then
  begin
    QRinput_Struct_free(s);
    errno:= ERANGE;
    result:= nil;
    exit;
  end;

  ret:= QRinput_Struct_insertStructuredAppendHeaders(s);
  if ret<0 then
  begin
    QRinput_Struct_free(s);
    result:= nil;
    exit;
  end;

  result:= s;
  exit;

ABORT:
  QRinput_free(input);
  QRinput_Struct_free(s);
  result:= nil;
end;

(******************************************************************************
 * Extended encoding mode (FNC1 and ECI)
 *****************************************************************************)

function QRinput_setFNC1First(input: pQRinput): integer;
begin
  if input^.mqr<>0 then
  begin
    errno:= EINVAL;
    result:= -1;
    exit;
  end;
  input^.fnc1:= 1;
  result:= 0;
end;

function QRinput_setFNC1Second(input: pQRinput;  appid: cuchar): integer;
begin
  if input^.mqr<>0 then
  begin
    errno:= EINVAL;
    result:= -1;
    exit;
  end;
  input^.fnc1:= 2;
  input^.appid:= appid;
  result:= 0;
end;


{ $i rscode.inc}
(* Stuff specific to the 8-bit symbol version of the general purpose RS codecs
 *
 *)
type
  data_t = cuchar;
  pdata_t = ^data_t;

(**
 * Reed-Solomon codec control block
 *)
  pRS = ^tRS;
  tRS = record
    mm: integer; (* Bits per symbol *)
    nn: integer; (* Symbols per block (= (1<<mm)-1) *)
    alpha_to: pdata_t; (* log lookup table *)
    index_of: pdata_t; (* Antilog lookup table *)
    genpoly: pdata_t; (* Generator polynomial *)
    nroots: integer; (* Number of generator roots = number of parity symbols *)
    fcr: integer; (* First consecutive root, index form *)
    prim: integer; (* Primitive element, index form *)
    iprim: integer; (* prim-th root of 1, index form *)
    pad: integer; (* Padding bytes in shortened block *)
    gfpoly: integer;
    next: pRS;
end;

var {was static}
  rslist: pRS = nil;

{$ifdef HAVE_LIBPTHREAD}
  rslist_mutex: pthread_mutex_t = PTHREAD_MUTEX_INITIALIZER;
{$endif}


function modnn(rs: pRS;  x: integer): integer; inline;
begin
  while x>=rs^.nn do
  begin
    x:= x - rs^.nn;
    x:= (x shr rs^.mm) + (x and rs^.nn);
  end;
  result:= x;
end;


(* Initialize a Reed-Solomon codec
 * symsize = symbol size, bits
 * gfpoly = Field generator polynomial coefficients
 * fcr = first root of RS code generator polynomial, index form
 * prim = primitive element to generate polynomial roots
 * nroots = RS code generator polynomial degree (number of roots)
 * pad = padding bytes at front of shortened block
 *)
function init_rs_char(symsize: integer;  gfpoly: integer;  fcr: integer;  prim: integer;  nroots: integer;  pad: integer): pRS;
var
  rs: pRS;
(* Common code for intializing a Reed-Solomon control block (char or int symbols)
 * Copyright 2004 Phil Karn, KA9Q
 * May be used under the terms of the GNU Lesser General Public License (LGPL)
 *)
  i, j: integer;
  sr, root,iprim: integer;
label done;
begin
  rs:= nil;
  (* Check parameter ranges *)
  if (symsize < 0) or (symsize > 8*sizeof(data_t)) then goto done;

  if (fcr<0) or (fcr>=(1 shl symsize)) then goto done;
  if (prim<=0) or (prim>=(1 shl symsize)) then goto done;
  if (nroots<0) or (nroots>=(1 shl symsize)) then goto done; (* Can't have more roots than symbol values! *)
  if (pad<0) or (pad>=((1 shl symsize)-1-nroots)) then goto done; (* Too much padding *)

  rs:= ccalloc(1,sizeof(tRS));
  if rs=nil then goto done;

  rs^.mm:= symsize;
  rs^.nn:= (1 shl symsize)-1;
  rs^.pad:= pad;
  rs^.alpha_to:= cmalloc(sizeof(data_t)*(rs^.nn+1));
  if rs^.alpha_to=nil then
  begin
    cfree(rs);
    rs:= nil;
    goto done;
  end;

  rs^.index_of:= cmalloc(sizeof(data_t)*(rs^.nn+1));
  if rs^.index_of=nil then
  begin
    cfree(rs^.alpha_to);
    cfree(rs);
    rs:= nil;
    goto done;
  end;

  (* Generate Galois field lookup tables *)
  rs^.index_of[0]:= rs^.nn;       (* log(zero) = -inf *)
  rs^.alpha_to[rs^.nn]:= 0;       (* alpha**-inf = 0 *)

  sr:= 1;
  for i:=0 to Pred(rs^.nn) do
  begin
    assert((sr>=0) and (sr<=rs^.nn), 'index_of[sr]');
    assert((i >=0) and (i <=rs^.nn), 'alpha_to[i]');
    rs^.index_of[sr]:= i;
    rs^.alpha_to[i]:= sr;
    sr:= sr shl 1;
    if (sr and (1 shl symsize)) <> 0 then
      sr:= sr xor gfpoly;
    sr:= sr and rs^.nn;
  end;

  if sr<>1 then
  begin
    (* field generator polynomial is not primitive! *)
    cfree(rs^.alpha_to);
    cfree(rs^.index_of);
    cfree(rs);
    rs:= nil;
    goto done;
  end;

  (* Form RS code generator polynomial from its roots *)
  rs^.genpoly:= cmalloc(sizeof(data_t)*(nroots+1));
  if rs^.genpoly=nil then
  begin
    cfree(rs^.alpha_to);
    cfree(rs^.index_of);
    cfree(rs);
    rs:= nil;
    goto done;
  end;

  rs^.fcr:= fcr;
  rs^.prim:= prim;
  rs^.nroots:= nroots;
  rs^.gfpoly:= gfpoly;

  (* Find prim-th root of 1, used in decoding *)
  iprim:= 1;
  while (iprim mod prim)<>0 do iprim:= iprim + rs^.nn;

  rs^.iprim:= iprim div prim;

  rs^.genpoly[0]:= 1;
  i:= 0;
  root:= fcr*prim;
  while i<nroots do begin
    assert((i>=0) and (i+1<=nroots), 'genpoly[i+1]');
    rs^.genpoly[i+1]:= 1;
    (* Multiply rs->genpoly[] by  @**(root + x) *)
    for j:=i downto 1 do
    begin
      if rs^.genpoly[j]<>0 then
        rs^.genpoly[j]:= rs^.genpoly[j-1] xor rs^.alpha_to[modnn(rs,rs^.index_of[rs^.genpoly[j]]+root)]
      else
        rs^.genpoly[j]:= rs^.genpoly[j-1];
    end;
    (* rs->genpoly[0] can never be zero *)
    rs^.genpoly[0]:= rs^.alpha_to[modnn(rs,rs^.index_of[rs^.genpoly[0]]+root)];

    inc(i);
    root:= root + prim;
  end;
  (* convert rs->genpoly[] to index form for quicker encoding *)
  for i:=0 to nroots do
    rs^.genpoly[i]:= rs^.index_of[rs^.genpoly[i]];
done:
  result:= rs;
end;

function init_rs(symsize: integer;  gfpoly: integer;  fcr: integer;  prim: integer;  nroots: integer;  pad: integer): pRS;
var
  rs: pRS;
label DONE;
begin
{$ifdef HAVE_LIBPTHREAD}
  pthread_mutex_lock(@rslist_mutex);
{$endif}
  rs:= rslist;
  while rs<>nil do
  begin
    if (rs^.pad<>pad) or
       (rs^.nroots<>nroots) or
       (rs^.mm<>symsize) or
       (rs^.gfpoly<>gfpoly) or
       (rs^.fcr<>fcr) or
       (rs^.prim<>prim) then
      rs:= rs^.next
    else
      goto DONE;
  end;

  rs:= init_rs_char(symsize,gfpoly,fcr,prim,nroots,pad);
  if rs=nil then goto DONE;

  rs^.next:= rslist;
  rslist:= rs;

DONE:
{$ifdef HAVE_LIBPTHREAD}
  pthread_mutex_unlock(@rslist_mutex);
{$endif}
  result:= rs;
end;

procedure free_rs_char(rs: pRS);
begin
  cfree(rs^.alpha_to);
  cfree(rs^.index_of);
  cfree(rs^.genpoly);
  cfree(rs);
end;

procedure free_rs_cache();
var
  rs, next: pRS;
begin
{$ifdef HAVE_LIBPTHREAD}
  pthread_mutex_lock(@rslist_mutex);
{$endif}
  rs:= rslist;
  while rs<>nil do
  begin
    next:= rs^.next;
    free_rs_char(rs);
    rs:= next;
  end;
  rslist:= nil;
{$ifdef HAVE_LIBPTHREAD}
  pthread_mutex_unlock(@rslist_mutex);
{$endif}
end;

(* The guts of the Reed-Solomon encoder, meant to be #included
 * into a function body with the following typedefs, macros and variables supplied
 * according to the code parameters:
 * data_t - a typedef for the data symbol
 * data_t data[] - array of NN-NROOTS-PAD and type data_t to be encoded
 * data_t parity[] - an array of NROOTS and type data_t to be written with parity symbols
 * NROOTS - the number of roots in the RS code generator polynomial,
 *          which is the same as the number of parity symbols in a block.
            Integer variable or literal.
     *
 * NN - the total number of symbols in a RS block. Integer variable or literal.
 * PAD - the number of pad symbols in a block. Integer variable or literal.
 * ALPHA_TO - The address of an array of NN elements to convert Galois field
 *            elements in index (log) form to polynomial form. Read only.
 * INDEX_OF - The address of an array of NN elements to convert Galois field
 *            elements in polynomial form to index (log) form. Read only.
 * MODNN - a function to reduce its argument modulo NN. May be inline or a macro.
 * GENPOLY - an array of NROOTS+1 elements containing the generator polynomial in index form
 * The memset() and memmove() functions are used. The appropriate header
 * file declaring these functions (usually <string.h>) must be included by the calling
 * program.
 * Copyright 2004, Phil Karn, KA9Q
 * May be used under the terms of the GNU Lesser General Public License (LGPL)
 *)

{
#define MM (rs->mm)
#define NN (rs->nn)
#define ALPHA_TO (rs->alpha_to)
#define INDEX_OF (rs->index_of)
#define GENPOLY (rs->genpoly)
#define NROOTS (rs->nroots)
#define FCR (rs->fcr)
#define PRIM (rs->prim)
#define IPRIM (rs->iprim)
#define PAD (rs->pad)
#define A0 (NN)
}

procedure encode_rs_char(rs: pRS;  data: pdata_t;  parity: pdata_t);
var
  i,j : integer;
  feedback: data_t;
begin
  cmemset(parity, 0, {NROOTS}rs^.nroots*sizeof(data_t));

  for i:=0 to Pred({NN}rs^.nn-{NROOTS}rs^.nroots-{PAD}rs^.pad) do
  begin
    feedback:= {INDEX_OF}rs^.index_of[data[i] xor parity[0]];
    if feedback<>rs^.nn then  (* feedback term is non-zero *)
    begin
{$ifdef UNNORMALIZED}
      (* This line is unnecessary when GENPOLY[NROOTS] is unity, as it must
       * always be for the polynomials constructed by init_rs()
       *)
      feedback:= MODNN(NN-GENPOLY[NROOTS]+feedback);
{$endif}
      for j:=1 to Pred({NROOTS}rs^.nroots) do
        parity[j]:= parity[j] xor ({ALPHA_TO}rs^.alpha_to[{MODNN}modnn(rs, feedback + {GENPOLY}rs^.genpoly[{NROOTS}rs^.nroots-j])]);
    end;

    (* Shift *)
    cmemmove(@parity[0], @parity[1], sizeof(data_t)*({NROOTS}rs^.nroots-1));
    if feedback<>rs^.nn then
      parity[{NROOTS}rs^.nroots-1]:= {ALPHA_TO}rs^.alpha_to[{MODNN}modnn(rs, feedback + {GENPOLY}rs^.genpoly[0])]
    else
      parity[{NROOTS}rs^.nroots-1]:= 0;
  end;
end;


{ $i mask.inc}
(******************************************************************************
 * mask.c
 *****************************************************************************)

function Mask_writeFormatInformation(width: integer;  frame: pcuchar;  mask: integer;  level: QRecLevel): integer;
var
  format: CUINT;
  v: cuchar;
  i: integer;
begin
  Result:=0;
  format:= QRspec_getFormatInfo(mask,level);
  for i:=0 to Pred(8) do
  begin
    if (format and 1) <> 0 then
    begin
      Result := Result + 2;
      v:= $85;
    end
    else
      v:= $84;

    frame[width*8+width-1-i]:= v;
    if i<6 then
      frame[width*i+8]:= v
    else
      frame[width*(i+1)+8]:= v;

    format:= format shr 1;
  end;

  for i:=0 to Pred(7) do
  begin
    if (format and 1) <> 0 then
    begin
      Result := Result + 2;
      v:= $85;
    end
    else
      v:= $84;

    frame[width*(width-7+i)+8]:= v;
    if i=0 then
      frame[width*8+7]:= v
    else
      frame[width*8+6-i]:= v;

    format:= format shr 1;
  end;
end;

(**
 * Demerit coefficients.
 * See Section 8.8.2, pp.45, JIS X0510:2004.
 *)
const
  N1 =  3;
  N2 =  3;
  N3 = 40;
  N4 = 10;

{
#define MASKMAKER(__exp__) \
   int x, y;
	int b = 0;

	for(y=0; y<width; y++) {
		for(x=0; x<width; x++) {
			if(*s & 0x80) {
				*d = *s;
			} else {
				*d = *s ^ ((__exp__) == 0);
			}
			b += (int)(*d & 1);
			s++; d++;
		}
	}
	return b;
}

type
  TMaskFunction = function(x,y: integer):cuchar;

function MASKMAKER(width: integer;  s: pcuchar;  d: pcuchar; f: TMaskFunction): integer;
var
  x,y,b: integer;
begin
  b:=0;
  for y:=0 to width-1 do
    for x:=0 to width-1 do begin
      if (s^ and $80) <> 0 then
        d^ := s^
      else
        d^ := s^ xor ord( f(x,y) = 0 );
      inc(b, d^ and 1);
      inc(s);
      inc(d);
    end;
  Result:=b;
end;

function f0(x,y: integer): cuchar;
begin
  Result := ((x+y) and 1);
end;
function Mask_mask0(width: integer;  s: pcuchar;  d: pcuchar): integer;
begin
  {MASKMAKER((x+y) and 1);}
  Result:=MASKMAKER(width, s, d, @f0);
end;

function f1(x,y: integer): cuchar;
begin
  Result := (y and 1);
end;
function Mask_mask1(width: integer;  s: pcuchar;  d: pcuchar): integer;
begin
  {MASKMAKER(y and 1);}
  Result:=MASKMAKER(width, s, d, @f1);
end;

function f2(x,y: integer): cuchar;
begin
  Result := (x mod 3);
end;
function Mask_mask2(width: integer;  s: pcuchar;  d: pcuchar): integer;
begin
  {MASKMAKER(x mod 3);}
  Result:=MASKMAKER(width, s, d, @f2);
end;

function f3(x,y: integer): cuchar;
begin
  Result := ((x+y) mod 3);
end;
function Mask_mask3(width: integer;  s: pcuchar;  d: pcuchar): integer;
begin
  {MASKMAKER((x+y) mod 3);}
  Result:=MASKMAKER(width, s, d, @f3);
end;

function f4(x,y: integer): cuchar;
begin
  Result := (((y div 2)+(x div 3)) and 1);
end;
function Mask_mask4(width: integer;  s: pcuchar;  d: pcuchar): integer;
begin
  {MASKMAKER(((y div 2)+(x div 3)) and 1);}
  Result:=MASKMAKER(width, s, d, @f4);
end;

function f5(x,y: integer): cuchar;
begin
  Result := (((x*y) and 1)+(x*y) mod 3);
end;
function Mask_mask5(width: integer;  s: pcuchar;  d: pcuchar): integer;
begin
  {MASKMAKER(((x*y) and 1)+(x*y) mod 3);}
  Result:=MASKMAKER(width, s, d, @f5);
end;

function f6(x,y: integer): cuchar;
begin
  Result := ((((x*y) and 1)+(x*y) mod 3) and 1);
end;
function Mask_mask6(width: integer;  s: pcuchar;  d: pcuchar): integer;
begin
  {MASKMAKER((((x*y) and 1)+(x*y) mod 3) and 1);}
  Result:=MASKMAKER(width, s, d, @f6);
end;

function f7(x,y: integer): cuchar;
begin
  Result := ((((x*y) mod 3)+((x+y) and 1)) and 1);
end;
function Mask_mask7(width: integer;  s: pcuchar;  d: pcuchar): integer;
begin
  {MASKMAKER((((x*y) mod 3)+((x+y) and 1)) and 1);}
  Result:=MASKMAKER(width, s, d, @f7);
end;

type
  TMaskMakerFunc = function(width: integer; s: pcuchar; d: pcuchar): integer;

var {was static}
  maskMakers: array [0..7] of TMaskMakerFunc =
    (@Mask_mask0,@Mask_mask1,@Mask_mask2,@Mask_mask3,@Mask_mask4,@Mask_mask5,@Mask_mask6,@Mask_mask7);


function Mask_makeMask(width: integer;  frame: pcuchar;  mask: integer;  level: QRecLevel): pcuchar;
begin
  if (mask<0) or (mask>high(maskMakers)) then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  Result := cmalloc(width*width);
  if Result=nil then Exit;

  maskMakers[mask](width, frame, Result);
  Mask_writeFormatInformation(width, Result, mask, level);
end;

(*static int n1;*)
(*static int n2;*)
(*static int n3;*)
(*static int n4;*)

function Mask_calcN1N3(length: integer;  runLength: pinteger): integer;
var
  i, demerit, fact: integer;
begin
  demerit:=0;
  for i:=0 to Pred(length) do
  begin
    if runLength[i]>=5 then
    begin
      demerit:= demerit + (N1+(runLength[i]-5));
      (*n1 += N1 + (runLength[i] - 5);*)
    end;
    if (i and 1) <> 0 then
    begin
      if (i>=3) and (i<length-2) and ((runLength[i] mod 3)=0) then
      begin
        fact:= runLength[i] div 3;
        if (runLength[i-2]=fact)and(runLength[i-1]=fact)and(runLength[i+1]=fact)and(runLength[i+2]=fact) then
        begin
          if (i=3)or(runLength[i-3]>=4*fact) then
          begin
            demerit:= demerit + N3;
            (*n3 += N3;*)
          end
          else if (i+4>=length)or(runLength[i+3]>=4*fact) then
          begin
            demerit:= demerit + N3;
            (*n3 += N3;*)
          end;
        end;
      end;
    end;
  end;

  result:= demerit;
end;

function Mask_calcN2(width: integer;  frame: pcuchar): integer;
var
  x, y: integer;
  p: pcuchar;
  b22, w22: cuchar;
  demerit: integer;
begin
  demerit:=0;
  p:= frame+width+1;
  for y:=1 to Pred(width) do
  begin
    for x:=1 to Pred(width) do
    begin
      b22:= p[0] and p[-1] and p[-width] and p[-width-1];
      w22:= p[0] or p[-1] or p[-width] or p[-width-1];
      if ((b22 or (w22 xor 1)) and 1) <> 0 then
        demerit:= demerit + N2;
      inc(p);
    end;
    inc(p);
  end;

  result:= demerit;
end;

function Mask_calcRunLength(width: integer;  frame: pcuchar;  dir: integer;  runLength: pinteger): integer;
var
  head: integer;
  i: integer;
  p: pcuchar;
  pitch: integer;
begin
  if dir=0 then
    pitch:= 1
  else
    pitch:= width;

  if (frame[0] and 1) <> 0 then
  begin
    runLength[0]:= -1;
    head:= 1;
  end
  else
    head:= 0;

  runLength[head]:= 1;
  p:= frame+pitch;
  for i:=1 to Pred(width) do
  begin
    if ((p[0] xor p[-pitch]) and 1) <> 0 then
    begin
      inc(head);
      runLength[head]:= 1;
    end
    else
      inc(runLength[head]);
    p:= p + pitch;
  end;

  result:= head+1;
end;

function Mask_evaluateSymbol(width: integer;  frame: pcuchar): integer;
var
  x: integer;
  y: integer;
  demerit: integer;
  runLength: array [0..Pred(QRSPEC_WIDTH_MAX+1)] of integer;
  length: integer;
begin
  demerit:=0;
  demerit:= demerit + (Mask_calcN2(width,frame));
  for y:=0 to Pred(width) do
  begin
    length:= Mask_calcRunLength(width,frame+y*width,0,runLength);
    demerit:= demerit + Mask_calcN1N3(length,runLength);
  end;
  for x:=0 to Pred(width) do
  begin
    length:= Mask_calcRunLength(width,frame+x,1,runLength);
    demerit:= demerit + Mask_calcN1N3(length,runLength);
  end;

  result:= demerit;
end;

function Mask_mask(width: integer;  frame: pcuchar;  level: QRecLevel): pcuchar;
var
  i: integer;
  mask, bestMask: pcuchar;
  minDemerit: integer;

  blacks: integer;
  bratio: integer;
  demerit: integer;
  w2: integer;
begin
  minDemerit:={INT_MAX}$7FFFFFFF;
  w2:=width*width;
  mask:= cmalloc(w2);
  if mask=nil then
  begin
    result:= nil;
    exit;
  end;

  bestMask:= nil;
  for i:=0 to high(maskMakers) do
  begin
    (*  n1 = n2 = n3 = n4 = 0;*)
    demerit:= 0;
    blacks:= maskMakers[i](width,frame,mask);
    blacks:= blacks + Mask_writeFormatInformation(width,mask,i,level);
    bratio:= (200*blacks+w2) div w2 div 2; (* (int)(100*blacks/w2+0.5) *)
    demerit:= (abs(bratio-50) div 5)*N4;
    (*  n4 = demerit;*)
    demerit:= demerit + Mask_evaluateSymbol(width,mask);

    if demerit<minDemerit then
    begin
      minDemerit:= demerit;
      cfree(bestMask);
      bestMask:= mask;
      mask:= cmalloc(w2);
      if mask=nil then break;
    end;
  end;
  cfree(mask);
  result:= bestMask;
end;


(******************************************************************************
 * mmask.c
 *****************************************************************************)

procedure MMask_writeFormatInformation(version: integer;  width: integer;  frame: pcuchar;  mask: integer;  level: QRecLevel);
var
  format: CUINT;
  v: cuchar;
  i: integer;
begin
  format:= MQRspec_getFormatInfo(mask,version,level);
  for i:=0 to Pred(8) do
  begin
    v:= $84 or (format and 1);
    frame[width*(i+1)+8]:= v;
    format:= format shr 1;
  end;
  for i:=0 to Pred(7) do
  begin
    v:= $84 or (format and 1);
    frame[width*8+7-i]:= v;
    format:= format shr 1;
  end;
end;

function MMASKMAKER(width: integer;  s: pcuchar;  d: pcuchar; f: TMaskFunction): integer;
var
  x,y: integer;
begin
  for y:=0 to width-1 do
    for x:=0 to width-1 do begin
      if (s^ and $80) <> 0 then
        d^ := s^
      else
        d^ := s^ xor ord( f(x,y) = 0 );
      inc(s);
      inc(d);
    end;
  Result:=0;
end;

function Mf0(x,y: integer): cuchar;
begin
  Result := (y and 1);
end;
function MMask_mask0(width: integer;  s: pcuchar;  d: pcuchar): integer;
begin
  {MASKMAKER(y and 1);}
  Result:=MMASKMAKER(width, s, d, @Mf0);
end;

function Mf1(x,y: integer): cuchar;
begin
  Result := (((y div 2)+(x div 3)) and 1);
end;
function MMask_mask1(width: integer;  s: pcuchar;  d: pcuchar): integer;
begin
  {MASKMAKER(((y div 2)+(x div 3)) and 1);}
  Result:=MMASKMAKER(width, s, d, @Mf1);
end;

function Mf2(x,y: integer): cuchar;
begin
  Result := ((((x*y) and 1)+(x*y) mod 3) and 1);
end;
function MMask_mask2(width: integer;  s: pcuchar;  d: pcuchar): integer;
begin
  {MASKMAKER((((x*y) and 1)+(x*y) mod 3) and 1);}
  Result:=MMASKMAKER(width, s, d, @Mf2);
end;

function Mf3(x,y: integer): cuchar;
begin
  Result := ((((x+y) and 1)+((x*y) mod 3)) and 1);
end;
function MMask_mask3(width: integer;  s: pcuchar;  d: pcuchar): integer;
begin
  {MASKMAKER((((x+y) and 1)+((x*y) mod 3)) and 1);}
  Result:=MMASKMAKER(width, s, d, @Mf3);
end;

var {was static}
  MmaskMakers: array [0..3] of TMaskMakerFunc =
    (@MMask_mask0,@MMask_mask1,@MMask_mask2,@MMask_mask3);

{$ifdef WITH_TESTS}
function MMask_makeMaskedFrame(width: integer;  frame: pcuchar;  mask: integer): pcuchar;
begin
  Result := cmalloc(width*width);
  if Result=nil then Exit;

  MmaskMakers[mask](width,frame,Result);
end;
{$endif}

function MMask_makeMask(version: integer;  frame: pcuchar;  mask: integer;  level: QRecLevel): pcuchar;
var
  width: integer;
begin
  if (mask<0) or (mask>high(MmaskMakers)) then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  width:= MQRspec_getWidth(version);
  Result := cmalloc(width*width);
  if Result=nil then Exit;

  MmaskMakers[mask](width, frame, Result);
  MMask_writeFormatInformation(version, width, Result, mask, level);
end;

function MMask_evaluateSymbol(width: integer;  frame: pcuchar): integer;
var
  x, y: integer;
  p: pcuchar;
  sum1, sum2: integer;
begin
  sum1:=0;
  sum2:=0;
  p:= frame+width*(width-1);
  for x:=1 to Pred(width) do
    sum1:= sum1 + (p[x] and 1);

  p:= frame+width*2-1;
  for y:=1 to Pred(width) do
  begin
    sum2:= sum2 + (p^ and 1);
    p:= p + width;
  end;

  if (sum1<=sum2) then
    result := sum1*16 + sum2
  else
    result := sum2*16 + sum1;
end;

function MMask_mask(version: integer;  frame: pcuchar;  level: QRecLevel): pcuchar;
var
  i: integer;
  mask, bestMask: pcuchar;
  maxScore,score, width: integer;
begin
  maxScore:=0;

  width:= MQRspec_getWidth(version);
  mask:= cmalloc(width*width);
  if mask=nil then
  begin
    result:= nil;
    exit;
  end;

  bestMask:= nil;
  for i:=0 to high(MmaskMakers) do
  begin
    score:= 0;
    MmaskMakers[i](width,frame,mask);
    MMask_writeFormatInformation(version,width,mask,i,level);
    score:= MMask_evaluateSymbol(width,mask);
    if score>maxScore then
    begin
      maxScore:= score;
      cfree(bestMask);
      bestMask:= mask;
      mask:= cmalloc(width*width);
      if mask=nil then break;
    end;
  end;
  cfree(mask);
  result:= bestMask;
end;


{ $i split.inc}
function isdigit(__c__: cchar): boolean;
begin
  Result := (__c__ >= ord('0')) and (__c__ <= ord('9'));
end;

function isalnum(__c__: cchar): boolean;
begin
  Result := QRinput_lookAnTable(__c__) >= 0;
end;

function Split_identifyMode(s: pcchar;  hint: QRencodeMode): QRencodeMode;
var
  c, d: cuchar;
  word: CUINT;
begin
  c:= s[0];
  if c=0 then
  begin
    result:= QR_MODE_NUL;
    exit;
  end;

  if isdigit(c) then
  begin
    result:= QR_MODE_NUM;
    exit;
  end
  else if isalnum(c) then
  begin
    result:= QR_MODE_AN;
    exit;
  end
  else if hint=QR_MODE_KANJI then
  begin
    d:= s[1];
    if d<>0 then
    begin
      word:= (cuint(c) shl 8) or d;
      if ((word>=$8140)and(word<=$9ffc))or((word>=$e040)and(word<=$ebbf)) then
      begin
        result:= QR_MODE_KANJI;
        exit;
      end;
    end;
  end;

  result:= QR_MODE_8;
end;

function Split_eat8(s: pcchar;  input: pQRinput;  hint: QRencodeMode): integer;
var
  p: pcchar;
  q: pcchar;
  mode: QRencodeMode;
  ret, run, dif: integer;
  la, ln, l8: integer;
  swcost: integer;
begin
  la:= QRspec_lengthIndicator(QR_MODE_AN,input^.version);
  ln:= QRspec_lengthIndicator(QR_MODE_NUM,input^.version);
  l8:= QRspec_lengthIndicator(QR_MODE_8,input^.version);
  p:= s+1;
  while p^<>0 do
  begin
    mode:= Split_identifyMode(p,hint);
    if mode=QR_MODE_KANJI then
      break
    else if mode=QR_MODE_NUM then
    begin
      q:= p;
      while isdigit(q^) do inc(q);
      if Split_identifyMode(q,hint)=QR_MODE_8 then
        swcost:= 4+l8
      else
        swcost:= 0;
      dif:= QRinput_estimateBitsMode8(p-s)+
            QRinput_estimateBitsModeNum(q-p)+4+ln+
            swcost-
            QRinput_estimateBitsMode8(q-s);
      if dif<0  then
        break
      else
        p:= q;
    end
    else if mode=QR_MODE_AN then
    begin
      q:= p;
      while isalnum(q^) do inc(q);
      if Split_identifyMode(q,hint)=QR_MODE_8 then
        swcost:= 4+l8
      else
        swcost:= 0;

      dif:= QRinput_estimateBitsMode8(p-s)+
            QRinput_estimateBitsModeAn(q-p)+4+la+
            swcost-
            QRinput_estimateBitsMode8(q-s);
      if dif<0 then
        break
      else
        p:= q;
    end
    else
      inc(p);
  end;

  run:= p-s;
  ret:= QRinput_append(input,QR_MODE_8,run, pcuchar(s));
  if ret<0 then
    result:= -1
  else
    result:= run;
end;

function Split_eatAn(s: pcchar;  input: pQRinput;  hint: QRencodeMode): integer;
var
  p, q: pcchar;
  ret: integer;
  run: integer;
  dif: integer;
  la: integer;
  ln: integer;
begin
  la:= QRspec_lengthIndicator(QR_MODE_AN,input^.version);
  ln:= QRspec_lengthIndicator(QR_MODE_NUM,input^.version);
  p:= s;
  while isalnum(p^) do
  begin
    if isdigit(p^) then
    begin
      q:= p;
      while isdigit(q^) do
        inc(q);
      dif:= QRinput_estimateBitsModeAn(p-s)+
            QRinput_estimateBitsModeNum(q-p)+4+ln
            -QRinput_estimateBitsModeAn(q-s);
      if isalnum(q^) then dif:=dif+ (4+ln);

      if dif<0 then
        break
      else
        p:= q;
    end
    else
      inc(p);
  end;

  run:= p-s;
  if (p^ <> 0) and (not isalnum(p^)) then
  begin
    dif:= QRinput_estimateBitsModeAn(run)+4+la+
          QRinput_estimateBitsMode8(1)-
          QRinput_estimateBitsMode8(run+1);
    if dif>0 then
    begin
      result:= Split_eat8(s,input,hint);
      exit;
    end;
  end;
  ret:= QRinput_append(input,QR_MODE_AN,run, pcuchar(s));
  if ret<0 then
    result:= -1
  else
    result:= run;
end;

function Split_eatNum(s: pcchar;  input: pQRinput;  hint: QRencodeMode): integer;
var
  p: pcchar;
  ret: integer;
  run: integer;
  dif: integer;
  ln: integer;
  mode: QRencodeMode;
begin
  ln:= QRspec_lengthIndicator(QR_MODE_NUM,input^.version);
  p:= s;
  while isdigit(p^) do
    inc(p);

  run:= p-s;
  mode:= Split_identifyMode(p,hint);
  if mode=QR_MODE_8 then
  begin
    dif:= QRinput_estimateBitsModeNum(run)+4+ln
          +QRinput_estimateBitsMode8(1)
          -QRinput_estimateBitsMode8(run+1);
    if dif>0 then
    begin
      result:= Split_eat8(s,input,hint);
      exit;
    end;
  end;
  if mode=QR_MODE_AN then
  begin
    dif:= QRinput_estimateBitsModeNum(run)+4+ln
          +QRinput_estimateBitsModeAn(1)
          -QRinput_estimateBitsModeAn(run+1);
    if dif>0 then
    begin
      result:= Split_eatAn(s,input,hint);
      exit;
    end;
  end;

  ret:= QRinput_append(input, QR_MODE_NUM, run, pcuchar(s));
  if ret<0 then
    result:= -1
  else
    result:= run;
end;

function Split_eatKanji(s: pcchar;  input: pQRinput;  hint: QRencodeMode): integer;
var
 p: pcchar;
 ret, run: integer;
begin
  p:= s;
  while Split_identifyMode(p,hint)=QR_MODE_KANJI do
    p:= p + (2);

  run:= p-s;
  ret:= QRinput_append(input,QR_MODE_KANJI,run, pcuchar(s));
  if ret<0 then
    result:= -1
  else
    result:= run;
end;

function Split_splitString(s: pcchar;  input: pQRinput;  hint: QRencodeMode): integer;
var
  length: integer;
  mode: QRencodeMode;
begin
  if s^=0 then
  begin
    result:= 0;
    exit;
  end;

  mode:= Split_identifyMode(s,hint);
  if mode=QR_MODE_NUM then
    length:= Split_eatNum(s,input,hint)
  else if mode=QR_MODE_AN then
    length:= Split_eatAn(s,input,hint)
  else if (mode=QR_MODE_KANJI)and(hint=QR_MODE_KANJI) then
    length:= Split_eatKanji(s,input,hint)
  else
    length:= Split_eat8(s,input,hint);

  if length=0 then
    result:= 0
  else if length<0 then
    result:= -1
  else
    result:= Split_splitString(@s[length],input,hint);
end;


function strdup(s: pcchar): pcchar;
var
  len: size_t;
  new: pointer;
begin
  len:=strlen(PAnsiChar(s)) + 1;
  new:=cmalloc(len);
  if new=nil then
  begin
    result:= nil;
    exit;
  end;

  result:= cmemcpy(new,s,len);
end;

function dupAndToUpper(str: pcchar;  hint: QRencodeMode): pcchar;
var
  newstr, p: pcchar;
  mode: QRencodeMode;
begin
  newstr:= strdup(str);
  if newstr=nil then
  begin
    result:= nil;
    exit;
  end;

  p:= newstr;
  while p^<>0 do
  begin
    mode:= Split_identifyMode(p,hint);
    if mode=QR_MODE_KANJI then
      p:= p + (2)
    else
    begin
      if (p^>=ord('a')) and (p^<=ord('z')) then
        p^:=p^-32;
      inc(p);
    end;
  end;

  result:= newstr;
end;

function Split_splitStringToQRinput(str: pcchar;  input: pQRinput;  hint: QRencodeMode;  casesensitive: integer): integer;
var
  newstr: pcchar;
begin
  if (str=nil) or (str^=0)then
  begin
    errno:= EINVAL;
    result:= -1;
    exit;
  end;

  if casesensitive = 0 then
  begin
    newstr:= dupAndToUpper(str,hint);
    if newstr=nil then
    begin
      result:= -1;
      exit;
    end;
    Result := Split_splitString(newstr,input,hint);
    freemem(newstr);
  end
  else
    Result := Split_splitString(str,input,hint);
end;


(******************************************************************************
 * QRcode output (qrencode.c)
 *****************************************************************************)

type
(**
 * Singly-linked list of QRcode. Used to represent a structured symbols.
 * A list is terminated with NULL.
 *)
  pQRcode_List = ^tQRcode_List;
  tQRcode_List = record
    code: pQRcode;
    next: pQRcode_List;
  end;

(******************************************************************************
 * Raw code
 *****************************************************************************)
type
  tRSblock = record
    dataLength: integer;
    data: pcuchar;
    eccLength: integer;
    ecc: pcuchar;
  end;
  pRSblock = ^tRSblock;

  tQRRawCode = record
    version: integer;
    dataLength: integer;
    eccLength: integer;
    datacode: pcuchar;
    ecccode: pcuchar;
    b1: integer;
    blocks: integer;
    rsblock: pRSblock;
    count: integer;
  end;
  pQRRawCode = ^tQRRawCode;

procedure RSblock_initBlock(block: pRSblock;  dl: integer;  data: pcuchar;  el: integer;  ecc: pcuchar;  rs: pRS);
begin
  block^.dataLength:= dl;
  block^.data:= data;
  block^.eccLength:= el;
  block^.ecc:= ecc;

  encode_rs_char(rs,data,ecc);
end;

function RSblock_init(blocks: pRSblock; {int spec[5]}spec: TSpecArray;  data: pcuchar;  ecc: pcuchar): integer;
var
  i: integer;
  block: pRSblock;
  dp, ep: pcuchar;
  rs: pRS;
  el, dl: integer;
begin
  dl:= QRspec_rsDataCodes1(spec);
  el:= QRspec_rsEccCodes1(spec);
  rs:= init_rs(8, $11d, 0, 1, el, 255-dl-el);
  if rs=nil then
  begin
    result:= -1;
    exit;
  end;

  block:= blocks;
  dp:= data;
  ep:= ecc;
  for i:=0 to Pred(QRspec_rsBlockNum1(spec)) do
  begin
    RSblock_initBlock(block,dl,dp,el,ep,rs);
    inc(dp, dl);
    inc(ep, el);
    inc(block);
  end;

  if QRspec_rsBlockNum2(spec)=0 then
  begin
    result:= 0;
    exit;
  end;

  dl:= QRspec_rsDataCodes2(spec);
  el:= QRspec_rsEccCodes2(spec);
  rs:= init_rs(8, $11d, 0, 1, el, 255-dl-el);
  if rs=nil then
  begin
    result:= -1;
    exit;
  end;

  for i:=0 to Pred(QRspec_rsBlockNum2(spec)) do
  begin
    RSblock_initBlock(block,dl,dp,el,ep,rs);
    inc(dp, dl);
    inc(ep, el);
    inc(block);
  end;

  result:= 0;
end;

procedure QRraw_free(raw: pQRRawCode);
begin
  if raw<>nil then
  begin
    cfree(raw^.datacode);
    cfree(raw^.ecccode);
    cfree(raw^.rsblock);
    cfree(raw);
  end;
end;

function QRraw_new(input: pQRinput): pQRRawCode; //OK
var
  raw: pQRRawCode;
  spec: TSpecArray;
begin
  raw:= cmalloc(sizeof(tQRRawCode));
  if raw=nil then
  begin
    result:= nil;
    exit;
  end;

  raw^.datacode:= QRinput_getByteStream(input);
  if raw^.datacode=nil then
  begin
    cfree(raw);
    result:= nil;
    exit;
  end;

  QRspec_getEccSpec(input^.version, input^.level, spec);
  raw^.version:= input^.version;
  raw^.b1:= QRspec_rsBlockNum1(spec);
  raw^.dataLength:= QRspec_rsDataLength(spec);
  raw^.eccLength:= QRspec_rsEccLength(spec);
  raw^.ecccode:= cmalloc(raw^.eccLength);
  if raw^.ecccode=nil then
  begin
    cfree(raw^.datacode);
    cfree(raw);
    result:= nil;
    exit;
  end;

  raw^.blocks:= QRspec_rsBlockNum(spec);
  raw^.rsblock:= ccalloc(raw^.blocks, sizeof(tRSblock));
  if raw^.rsblock=nil then
  begin
    QRraw_free(raw);
    result:= nil;
    exit;
  end;

  if RSblock_init(raw^.rsblock, spec, raw^.datacode, raw^.ecccode) < 0 then
  begin
    QRraw_free(raw);
    result:= nil;
    exit;
  end;

  raw^.count:= 0;
  result:= raw;
end;

(**
 * Return a code (byte).
 * This function can be called iteratively.
 * @param raw raw code.
 * @return code
 *)
function QRraw_getCode(raw: pQRRawCode): cuchar;
var
  col, row: integer;
begin
  if raw^.count<raw^.dataLength then
  begin
    row:= raw^.count mod raw^.blocks;
    col:= raw^.count div raw^.blocks;
    if col>=raw^.rsblock[0].dataLength then
      row:= row + raw^.b1;
    Result := raw^.rsblock[row].data[col];
  end
  else if raw^.count<raw^.dataLength+raw^.eccLength then
  begin
    row:= (raw^.count-raw^.dataLength) mod raw^.blocks;
    col:= (raw^.count-raw^.dataLength) div raw^.blocks;
    Result := raw^.rsblock[row].ecc[col];
  end
  else
  begin
    Result:= 0;
    exit;
  end;

  inc(raw^.count);
end;

(******************************************************************************
 * Raw code for Micro QR Code
 *****************************************************************************)
type
  tMQRRawCode = record
    version: integer;
    dataLength: integer;
    eccLength: integer;
    datacode: pcuchar;
    ecccode: pcuchar;
    rsblock: pRSblock;
    oddbits: integer;
    count: integer;
   end;
   pMQRRawCode = ^tMQRRawCode;

procedure MQRraw_free(raw: pMQRRawCode);
begin
  if raw<>nil then
  begin
    cfree(raw^.datacode);
    cfree(raw^.ecccode);
    cfree(raw^.rsblock);
    cfree(raw);
  end;
end;

function MQRraw_new(input: pQRinput): pMQRRawCode;
var
  raw: pMQRRawCode;
  rs: pRS;
begin
  raw:= cmalloc(sizeof(tMQRRawCode));
  if raw=nil then
  begin
    result:= nil;
    exit;
  end;

  raw^.version:= input^.version;
  raw^.dataLength:= MQRspec_getDataLength(input^.version, input^.level);
  raw^.eccLength:= MQRspec_getECCLength(input^.version, input^.level);
  raw^.oddbits:= raw^.dataLength*8-MQRspec_getDataLengthBit(input^.version, input^.level);
  raw^.datacode:= QRinput_getByteStream(input);
  if raw^.datacode=nil then
  begin
    cfree(raw);
    result:= nil;
    exit;
  end;

  raw^.ecccode:= cmalloc(raw^.eccLength);
  if raw^.ecccode=nil then
  begin
    cfree(raw^.datacode);
    cfree(raw);
    result:= nil;
    exit;
  end;

  raw^.rsblock:= ccalloc(1,sizeof(tRSblock));
  if raw^.rsblock=nil then
  begin
    MQRraw_free(raw);
    result:= nil;
    exit;
  end;

  rs:= init_rs(8,$11d,0,1,raw^.eccLength,255-raw^.dataLength-raw^.eccLength);
  if rs=nil then
  begin
    MQRraw_free(raw);
    result:= nil;
    exit;
  end;

  RSblock_initBlock(raw^.rsblock,raw^.dataLength,raw^.datacode,raw^.eccLength,raw^.ecccode,rs);
  raw^.count:= 0;
  result:= raw;
end;

(**
 * Return a code (byte).
 * This function can be called iteratively.
 * @param raw raw code.
 * @return code
 *)
function MQRraw_getCode(raw: pMQRRawCode): cuchar;
begin
  if raw^.count<raw^.dataLength then
    Result := raw^.datacode[raw^.count]
  else if raw^.count<raw^.dataLength+raw^.eccLength then
    Result := raw^.ecccode[raw^.count-raw^.dataLength]
  else
    begin
    Result := 0;
    exit;
    end;

  inc(raw^.count);
end;

(******************************************************************************
 * Frame filling
 *****************************************************************************)
type
  tFrameFiller = record
    width: integer;
    frame: pcuchar;
    x: integer;
    y: integer;
    dir: integer;
    bit: integer;
    mqr: integer;
  end;
  pFrameFiller = ^tFrameFiller;

function FrameFiller_new(width: integer;  frame: pcuchar;  mqr: integer): pFrameFiller;
begin
  Result := cmalloc(sizeof(tFrameFiller));
  if Result=nil then Exit;

  Result^.width:= width;
  Result^.frame:= frame;
  Result^.x:= width-1;
  Result^.y:= width-1;
  Result^.dir:= -1;
  Result^.bit:= -1;
  Result^.mqr:= mqr;
end;

function FrameFiller_next(filler: pFrameFiller): pcuchar; //OK
var
  p: pcuchar;
  x, y, w: integer;
begin
  if filler^.bit=-1 then
  begin
    filler^.bit:= 0;
    result:= filler^.frame + filler^.y*filler^.width + filler^.x;
    exit;
  end;

  x:= filler^.x;
  y:= filler^.y;
  p:= filler^.frame;
  w:= filler^.width;

  if filler^.bit=0 then
  begin
    dec(x);
    inc(filler^.bit);
  end
  else
  begin
    inc(x);
    y:= y + filler^.dir;
    dec(filler^.bit);
  end;

  if filler^.dir<0 then
  begin
    if y<0 then
    begin
      y:= 0;
      x:= x - 2;
      filler^.dir:= 1;
      if ({!filler->mqr}filler^.mqr=0) and (x=6) then
      begin
        dec(x);
        y:= 9;
      end;
    end;
  end
  else
  begin
    if y=w then
    begin
      y:= w-1;
      x:= x - 2;
      filler^.dir:= -1;
      if ({!filler->mqr}filler^.mqr=0) and (x=6) then
      begin
        dec(x);
        y:= y - 8;
      end;
    end;
  end;
  if (x<0)or(y<0) then
  begin
    result:= nil;
    exit;
  end;

  filler^.x:= x;
  filler^.y:= y;
  if (p[y*w+x] and $80) <> 0  then
  begin
    (* This tail recursion could be optimized.*)
    result:= FrameFiller_next(filler)
  end
  else
    result:= @p[y*w+x];
end;


(******************************************************************************
 * QR-code encoding
 *****************************************************************************)

function QRcode_new(version: integer;  width: integer;  data: pcuchar): pQRcode;
begin
  Result := cmalloc(sizeof(QRcode_t));
  if Result=nil then Exit;

  Result^.version:= version;
  Result^.width:= width;
  Result^.data:= data;
end;

procedure QRcode_free(qrcode: pQRcode);
begin
  if qrcode<>nil then
  begin
    cfree(qrcode^.data);
    cfree(qrcode);
  end;
end;

function QRcode_encodeMask(input: pQRinput;  mask: integer): pQRcode; //OK
var
  width, version: integer;
  raw: pQRRawCode;
  frame, masked, p: pcuchar;
  code, bit: cuchar;
  filler: pFrameFiller;
  i, j: integer;
label lEXIT;
begin
  Result := nil;

  if input^.mqr<>0 then
  begin
    errno:= EINVAL;
    exit;
  end;

  if (input^.version<0) or (input^.version>QRSPEC_VERSION_MAX) then
  begin
    errno:= EINVAL;
    exit;
  end;

  if input^.level>QR_ECLEVEL_H then
  begin
    errno:= EINVAL;
    exit;
  end;

  raw:= QRraw_new(input);
  if raw=nil then Exit;

  version:= raw^.version;
  width:= QRspec_getWidth(version);
  frame:= QRspec_newFrame(version);
  if frame=nil then
  begin
    QRraw_free(raw);
    exit;
  end;

  filler:= FrameFiller_new(width,frame,0);
  if filler=nil then
  begin
    QRraw_free(raw);
    cfree(frame);
    exit;
  end;

  (* inteleaved data and ecc codes *)
  for i:=0 to Pred(raw^.dataLength+raw^.eccLength) do
  begin
    code:= QRraw_getCode(raw);
    bit:= $80;
    for j:=0 to Pred(8) do
    begin
      p:= FrameFiller_next(filler);
      if p=nil then goto lEXIT;
      // In C, data type of result of comparison operations is int
      // The result of a relational expression is 1 if the tested relationship is true and 0 if it is false.
      // non-zero scalar value is interpreted as true
      if (bit and code)<>0 then p^:=$03 else p^:=$02; {*p = 0x02 | ((bit & code) != 0)}
      bit:= bit shr 1;
    end;
  end;
  QRraw_free(raw);
  raw:= nil;
  (* remainder bits *)
  j:= QRspec_getRemainder(version);
  for i:=0 to Pred(j) do
  begin
    p:= FrameFiller_next(filler);
    if p=nil then goto lEXIT;
    p^:=$02;
  end;

  (* masking *)
  if mask=-2 then
  begin
    (* just for debug purpose*)
    masked:= cmalloc(width*width);
    cmemcpy(masked,frame,width*width);
  end
  else if mask<0 then
    masked:= Mask_mask(width, frame, input^.level)
  else
    masked:= Mask_makeMask(width, frame, mask, input^.level);

  if masked=nil then goto lEXIT;

  Result := QRcode_new(version,width,masked);
  if Result = nil then
    cfree(masked);

lEXIT:
  QRraw_free(raw);
  cfree(filler);
  cfree(frame);
end;

function QRcode_encodeMaskMQR(input: pQRinput;  mask: integer): pQRcode;
var
  width: integer;
  version: integer;
  raw: pMQRRawCode;
  frame, masked, p: pcuchar;
  code, bit: cuchar;
  filler: pFrameFiller;
  i, j: integer;
label lEXIT;
begin
  Result:=nil;

  if input^.mqr = 0 then
  begin
    errno:= EINVAL;
    exit;
  end;

  if (input^.version<=0) or (input^.version>MQRSPEC_VERSION_MAX) then
  begin
    errno:= EINVAL;
    exit;
  end;

  if input^.level>QR_ECLEVEL_Q then
  begin
    errno:= EINVAL;
    exit;
  end;

  raw:= MQRraw_new(input);
  if raw=nil then
    exit;

  version:= raw^.version;
  width:= MQRspec_getWidth(version);
  frame:= MQRspec_newFrame(version);
  if frame=nil then
  begin
    MQRraw_free(raw);
    exit;
  end;

  filler:= FrameFiller_new(width,frame,1);
  if filler=nil then
  begin
    MQRraw_free(raw);
    cfree(frame);
    exit;
  end;

  (* inteleaved data and ecc codes *)
  for i:=0 to Pred(raw^.dataLength+raw^.eccLength) do
  begin
    code:= MQRraw_getCode(raw);
    if (raw^.oddbits<>0) and (i=raw^.dataLength-1) then
    begin
      bit:= 1 shl (raw^.oddbits-1);
      for j:=0 to Pred(raw^.oddbits) do
      begin
        p:= FrameFiller_next(filler);
        if p=nil then goto lEXIT;
        p^ := $02 or ord((bit and code)<>0); {*p = 0x02 | ((bit & code) != 0);}
        bit:= bit shr 1;
      end;
    end
    else
    begin
      bit:= $80;
      for j:=0 to Pred(8) do
      begin
        p:= FrameFiller_next(filler);
        if p=nil then goto lEXIT;
        p^ := $02 or ord((bit and code)<>0);
        bit:= bit shr 1;
      end;
    end;
  end;

  MQRraw_free(raw);
  raw:= nil;

  (* masking *)
  if mask<0 then
    masked:= MMask_mask(version,frame,input^.level)
  else
    masked:= MMask_makeMask(version,frame,mask,input^.level);

  if masked=nil then goto lEXIT;

  Result := QRcode_new(version,width,masked);

lEXIT:
  MQRraw_free(raw);
  cfree(filler);
  cfree(frame);
end;

function QRcode_encodeInput(input: pQRinput): pQRcode;
begin
  if input^.mqr<>0 then
    result:= QRcode_encodeMaskMQR(input,-1)
  else
    result:= QRcode_encodeMask(input,-1);
end;

function QRcode_encodeStringReal(s: pcchar;  version: integer;  level: QRecLevel;  mqr: integer;  hint: QRencodeMode;  casesensitive: integer): pQRcode;
var
  input: pQRinput;
  ret: integer;
begin
  if s=nil then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  if (hint<>QR_MODE_8) and (hint<>QR_MODE_KANJI) then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  if mqr<>0 then
    input:= QRinput_newMQR(version,level)
  else
    input:= QRinput_new2(version,level);

  if input=nil then
  begin
    result:= nil;
    exit;
  end;

  ret:= Split_splitStringToQRinput(s,input,hint,casesensitive);
  if ret<0 then
  begin
    QRinput_free(input);
    result:= nil;
    exit;
  end;

  Result := QRcode_encodeInput(input);
  QRinput_free(input);
end;

(**
 * Create a symbol from the string. The library automatically parses the input
 * string and encodes in a QR Code symbol.
 * @warning This function is THREAD UNSAFE when pthread is disabled.
 * @param string input string. It must be NUL terminated.
 * @param version version of the symbol. If 0, the library chooses the minimum
 *                version for the given input data.
 * @param level error correction level.
 * @param hint tell the library how Japanese Kanji characters should be
 *             encoded. If QR_MODE_KANJI is given, the library assumes that the
 *             given string contains Shift-JIS characters and encodes them in
 *             Kanji-mode. If QR_MODE_8 is given, all of non-alphanumerical
 *             characters will be encoded as is. If you want to embed UTF-8
 *             string, choose this. Other mode will cause EINVAL error.
 * @param casesensitive case-sensitive(1) or not(0).
 * @return an instance of QRcode class. The version of the result QRcode may
 *         be larger than the designated version. On error, NULL is returned,
 *         and errno is set to indicate the error. See Exceptions for the
 *         details.
 * @throw EINVAL invalid input object.
 * @throw ENOMEM unable to allocate memory for input objects.
 * @throw ERANGE input data is too large.
 *)
function QRcode_encodeString(s: AnsiString;  version: integer;  level: QRecLevel;  hint: QRencodeMode;  casesensitive: integer): pQRcode;
begin
  result:= QRcode_encodeStringReal(pcchar(s), version, level, 0, hint, casesensitive);
end;

(**
 * Micro QR Code version of QRcode_encodeString().
 * @warning This function is THREAD UNSAFE when pthread is disabled.
 *)
function QRcode_encodeStringMQR(s: AnsiString;  version: integer;  level: QRecLevel;  hint: QRencodeMode;  casesensitive: integer): pQRcode;
begin
  result:= QRcode_encodeStringReal(pcchar(s), version, level, 1, hint, casesensitive);
end;

function QRcode_encodeDataReal(data: pcuchar;  length: integer;  version: integer;  level: QRecLevel;  mqr: integer): pQRcode;
var
  input: pQRinput;
  ret: integer;
begin
  if (data=nil)or(length=0) then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  if mqr<>0then
    input:= QRinput_newMQR(version,level)
  else
    input:= QRinput_new2(version,level);
  if input=nil then
  begin
    result:= nil;
    exit;
  end;

  ret:= QRinput_append(input,QR_MODE_8,length,data);
  if ret<0 then
  begin
    QRinput_free(input);
    result:= nil;
    exit;
  end;

  Result := QRcode_encodeInput(input);
  QRinput_free(input);
end;

function QRcode_encodeData(size: integer;  data: pcuchar;  version: integer;  level: QRecLevel): pQRcode;
begin
  result:= QRcode_encodeDataReal(data,size,version,level,0);
end;

function QRcode_encodeDataMQR(size: integer;  data: pcuchar;  version: integer;  level: QRecLevel): pQRcode;
begin
  result:= QRcode_encodeDataReal(data,size,version,level,1);
end;

(**
 * Same to QRcode_encodeString(), but encode whole data in 8-bit mode.
 * @warning This function is THREAD UNSAFE when pthread is disabled.
 *)
function QRcode_encodeString8bit(s: PAnsiChar;  version: integer;  level: QRecLevel): pQRcode;
begin
  if s=nil then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  result:= QRcode_encodeDataReal(pcuchar(s), strlen(s), version, level, 0);
end;

(**
 * Micro QR Code version of QRcode_encodeString8bit().
 * @warning This function is THREAD UNSAFE when pthread is disabled.
 *)
function QRcode_encodeString8bitMQR(s: PAnsiChar;  version: integer;  level: QRecLevel): pQRcode;
begin
  if s=nil then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  result:= QRcode_encodeDataReal(pcuchar(s), strlen(s), version, level, 1);
end;

(******************************************************************************
 * Structured QR-code encoding
 *****************************************************************************)

function QRcode_List_newEntry(): pQRcode_List;
begin
  Result := cmalloc(sizeof(tQRcode_List));
  if Result=nil then Exit;

  Result^.next:= nil;
  Result^.code:= nil;
end;

procedure QRcode_List_freeEntry(entry: pQRcode_List);
begin
  if entry<>nil then
  begin
    QRcode_free(entry^.code);
    cfree(entry);
  end;
end;

procedure QRcode_List_free(qrlist: pQRcode_List);
var
  list, next: pQRcode_List;
begin
  list:=qrlist;
  while list<>nil do
  begin
    next:= list^.next;
    QRcode_List_freeEntry(list);
    list:= next;
  end;
end;

function QRcode_List_size(qrlist: pQRcode_List): integer;
var
  list: pQRcode_List;
begin
  list:=qrlist;
  Result:=0;
  while list<>nil do
  begin
    inc(Result);
    list:= list^.next;
  end;
end;

{$if 0}
function QRcode_parity(str: pcchar;  size: integer): cuchar;
var
  i: integer;
begin
  Result:=0;
  for i:=0 to Pred(size) do
    Result := Result xor str[i];
end;
{$endif}

function QRcode_encodeInputStructured(s: pQRinput_Struct): pQRcode_List;
var
  head, tail, entry: pQRcode_List;
  list: pQRinput_InputList;
label ABORT;
begin
  head:=nil;
  tail:=nil;
  list:=s^.head;
  while list<>nil do
  begin
    if head=nil then
    begin
      entry:= QRcode_List_newEntry();
      if entry=nil then goto ABORT;
      head:= entry;
      tail:= head;
    end
    else
    begin
      entry:= QRcode_List_newEntry();
      if entry=nil then goto ABORT;
      tail^.next:= entry;
      tail:= tail^.next;
    end;
    tail^.code:= QRcode_encodeInput(list^.input);
    if tail^.code=nil then goto ABORT;
    list:= list^.next;
  end;

  result:= head;
  Exit;

ABORT:
  QRcode_List_free(head);
  result:= nil;
  exit;
end;

function QRcode_encodeInputToStructured(input: pQRinput): pQRcode_List;
var
  s: pQRinput_Struct;
begin
  s:= QRinput_splitQRinputToStruct(input);
  if s=nil then
  begin
    result:= nil;
    exit;
  end;

  Result := QRcode_encodeInputStructured(s);
  QRinput_Struct_free(s);
end;

function QRcode_encodeDataStructuredReal(size: integer;  data: pcuchar;  version: integer;  level: QRecLevel;  eightbit: integer;  hint: QRencodeMode;  casesensitive: integer): pQRcode_List;
var
  input: pQRinput;
  ret: integer;
begin
  if version<=0 then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  if (eightbit=0) and ((hint<>QR_MODE_8) and (hint<>QR_MODE_KANJI)) then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  input:= QRinput_new2(version,level);
  if input=nil then
  begin
    result:= nil;
    exit;
  end;

  if eightbit<>0 then
    ret:= QRinput_append(input,QR_MODE_8,size,data)
  else
    ret:= Split_splitStringToQRinput(pcchar(data),input,hint,casesensitive);

  if ret<0 then
  begin
    QRinput_free(input);
    result:= nil;
    exit;
  end;

  Result := QRcode_encodeInputToStructured(input);
  QRinput_free(input);
end;

function QRcode_encodeDataStructured(size: integer;  data: pcuchar;  version: integer;  level: QRecLevel): pQRcode_List;
begin
  result:= QRcode_encodeDataStructuredReal(size,data,version,level,1,QR_MODE_NUL,0);
end;

function QRcode_encodeString8bitStructured(s: PAnsiChar;  version: integer;  level: QRecLevel): pQRcode_List;
begin
  if s=nil then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  result:= QRcode_encodeDataStructured(strlen(s), pcuchar(s), version, level);
end;

function QRcode_encodeStringStructured(s: PAnsiChar;  version: integer;  level: QRecLevel;  hint: QRencodeMode;  casesensitive: integer): pQRcode_List;
begin
  if s=nil then
  begin
    errno:= EINVAL;
    result:= nil;
    exit;
  end;

  result:= QRcode_encodeDataStructuredReal(strlen(s), pcuchar(s), version, level, 0, hint, casesensitive);
end;

(******************************************************************************
 * System utilities
 *****************************************************************************)
(**
 * Return a string that identifies the library version.
 * @param major_version
 * @param minor_version
 * @param micro_version
 *)

procedure QRcode_APIVersion(major_version: pinteger;  minor_version: pinteger;  micro_version: pinteger);
begin
  if major_version<>nil then
    major_version^:=_MAJOR_VERSION;

  if minor_version<>nil then
    minor_version^:=_MINOR_VERSION;

  if micro_version<>nil then
    micro_version^:=_MICRO_VERSION;
end;

(**
 * Return a string that identifies the library version.
 * @return a string identifies the library version. The string is held by the
 * library. Do NOT free it.
 *)
function QRcode_APIVersionString(): pchar;
begin
  result:= pchar(_VERSION);
end;

(**
 * Clear all caches. This is only for debug purpose. If you are attacking a
 * complicated memory leak bug, try this to reduce the reachable blocks record.
 * @warning This function is THREAD UNSAFE when pthread is disabled.
 *)
procedure QRcode_clearCache();
begin
  QRspec_clearCache();
  MQRspec_clearCache();
  free_rs_cache();
end;

{ TQRCode }

constructor TQRCode.Create;
begin
  inherited;
  FecLevel:=QR_ECLEVEL_Q;
  FMicroQR:=False;
end;

destructor TQRCode.Destroy;
begin
  if assigned(FQRCode) then QRcode_free(FQRCode);
  inherited Destroy;
end;

procedure TQRCode.SetecLevel(AValue: QRecLevel);
begin
   if FecLevel=AValue then Exit;
   FecLevel:=AValue;
   Generate;
end;

procedure TQRCode.SetMicroQR(AValue: boolean);
begin
   if FMicroQR=AValue then Exit;
   FMicroQR:=AValue;
   Generate;
end;

procedure TQRCode.SetText(AValue: string);
begin
   if FText=AValue then Exit;
   FText:=AValue;
   Generate;
end;

function TQRCode.GetVersion: integer;
begin
   if assigned(FQRCode) then
     Result := FQRCode^.version
   else
     Result := 0;
end;

function TQRCode.GetWidth: integer;
begin
   if assigned(FQRCode) then
     Result := FQRCode^.width
   else
     Result := 0;
end;

procedure TQRCode.Generate;
begin
   if assigned(FQRCode) then QRcode_free(FQRCode);
   if FMicroQR then
     FQRCode := QRcode_encodeStringMQR(FText, 4, FecLevel, QR_MODE_8, 1)
   else
     FQRCode := QRcode_encodeString   (FText, 0, FecLevel, QR_MODE_8, 1);
end;

procedure TQRCode.Paint(const aBitmap: TBGRABitmap; const aRect: TRect);
begin
  Paint(aBitmap, aRect, BGRAWhite, BGRABlack);
end;

procedure TQRCode.Paint(const aBitmap: TBGRABitmap; const aRect: TRect;
  aBgColor: TBGRAPixel; aFgColor: TBGRAPixel);
var
  scale, yscale, w: integer;
  r, c, x, y: integer;
  p: pcuchar;
  color: TBGRAPixel;
begin
  w := Width;
  if w = 0 then Exit;

  scale  := (aRect.Right - aRect.Left) div w;
  yscale := (aRect.Bottom - aRect.Top) div w;
  if yscale < scale then scale := yscale;
  if scale <= 0 then Exit;

  for r := 0 to w - 1 do
  begin
    for c := 0 to w - 1 do
    begin
      p := FQRCode^.data;
      case FOrientation of
         900: inc(p, c*w + w-1-r);
        1800: inc(p, w*w-1-r*w - c);
        2700: inc(p, w*(w-1-c) + r);
        else  inc(p, r*w + c);
      end;
      x := aRect.Left + c*scale;
      y := aRect.Top  + r*scale;
      if (p^ and 1) = 1 then
        color := aFgColor
      else
        color := aBgColor;
      aBitmap.FillRect(x, y, x+scale, y+scale, color, dmSet);
    end;
  end;
end;


initialization
finalization
  QRcode_clearCache;

end.
