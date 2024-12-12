unit nodeio;
{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, nodetree, ZStream;

type
  generic TNodeIO<PNodeType> = class sealed
  type
    {$PUSH}{$PACKENUM 1}
    TNodeStreamType = (Child, Sibling, Last);
    {$POP}
  private
    fs, cs, ds: TStream;
    procedure LoadNodeInternal(node: PNodeType);
    procedure SaveNodeInternal(node: PNodeType; NodeStreamType: TNodeStreamType);
  public
    constructor Create(FileName: String; const FileExt: String; Compression: Boolean = True);
    destructor Destroy; override;
    procedure LoadNode(node: PNodeType);
    procedure SaveNode(node: PNodeType);
  end;

implementation

constructor TNodeIO.Create(FileName: String; const FileExt: String; Compression: Boolean = True);
begin
  inherited Create;

  if FileName='' then FileName:=FormatDateTime('yyyymmddHHMMSS', Now) + FileExt;

  if FileExists(FileName) then
    fs := TFileStream.Create(FileName, fmOpenReadWrite)
  else
    fs := TFileStream.Create(FileName, fmCreate);

  if Compression then
  begin
    cs := TCompressionStream.Create(clfastest, fs);
    ds := TDecompressionStream.create(fs);
  end else
  begin
    cs := fs;
    ds := fs;
  end;
end;

destructor TNodeIO.Destroy;
begin
  if ds<>cs then
  begin
    ds.Free;
    cs.Free;
  end;
  fs.Free;

  inherited Destroy;
end;

procedure TNodeIO.LoadNodeInternal(node: PNodeType);
var
  NodeStreamType: TNodeStreamType;
begin
  while (ds.Read(NodeStreamType, SizeOf(NodeStreamType))<>0) do
  begin
    case NodeStreamType of
      TNodeStreamType.Child:
        begin
          ds.Read(node^.AddChild^.NodeData, SizeOf(node^.NodeData));
          LoadNodeInternal(node^.Child);
        end;
      TNodeStreamType.Sibling:
        begin
          node:=node^.AddSibling;
          ds.Read(node^.NodeData, SizeOf(node^.NodeData));
        end;
      else
        begin
          Exit;
        end;
    end;
  end;
end;

procedure TNodeIO.LoadNode(node: PNodeType);
var
  NodeStreamType: TNodeStreamType;
begin
  if ds.Read(NodeStreamType, SizeOf(NodeStreamType))=0 then Exit;
  if ds.Read(node^.NodeData, SizeOf(node^.NodeData))=0 then Exit;

  LoadNodeInternal(node);
end;

procedure TNodeIO.SaveNodeInternal(node: PNodeType; NodeStreamType: TNodeStreamType);
begin
  while Assigned(node) do
  begin
    cs.Write(NodeStreamType, SizeOf(NodeStreamType));
    cs.Write(node^.NodeData, SizeOf(node^.NodeData));

    if Assigned(node^.Child) then SaveNodeInternal(node^.Child, TNodeStreamType.Child);

    node:=node^.Sibling;
    NodeStreamType:=TNodeStreamType.Sibling;
  end;

  NodeStreamType:=TNodeStreamType.Last;
  cs.Write(NodeStreamType, SizeOf(NodeStreamType));
end;

procedure TNodeIO.SaveNode(node: PNodeType);
begin
  SaveNodeInternal(node, TNodeStreamType.Child);
end;

end.

