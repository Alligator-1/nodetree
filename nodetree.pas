unit nodetree;
{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

type
  TEmptyRecord = record
  end;

  TAbstractDataIO = class
    procedure ReadData(var data; size: UInt64); virtual; abstract;
    procedure WriteData(const data; size: UInt64); virtual; abstract;
  end;

  TAbstractNodeComparator = class
    class function IsEqual(node_data: Pointer; data: Pointer): Boolean; virtual; abstract;
  end;

  generic TNodeTreeLoaderSaver<TNodeTree, TNodeDataIO> = class sealed
    class procedure SaveToFile(node: Pointer; const filename: string; const fileext: string); static;
    class procedure LoadFromFile(node: Pointer; const filename: string); static;
  end;

  generic TPointerArrayNodeTree<TNodeData, TNodeDataIO, TNodeComparator> = class
  type
    TNodeDataType = TNodeData;
    PNode = ^TNode;
    TNode = record
      node_data: TNodeData;
      child_nodes: array of PNode;
    end;

    TSelf = specialize TPointerArrayNodeTree<TNodeData, TNodeDataIO, TNodeComparator>;
    TLoaderSaver = specialize TNodeTreeLoaderSaver<TSelf, TNodeDataIO>;
  strict private
    class procedure free_reqursive(node: PNode); static;
  public
    root_node: TNode;
    class function get_child_count(node: PNode): SizeInt; static; inline;
    class procedure set_child_count(node: PNode; count: SizeInt); static; inline;
    class function get_child(node: PNode; i: SizeInt): PNode; static; inline;
    class function add_child(node: PNode): PNode; static; inline;
    class function find_child_node(node: PNode; data: Pointer): PNode; static; inline;
    destructor Destroy; override;
    procedure Clear;
    procedure SaveToFile(const filename: string; const fileext: string);
    procedure LoadFromFile(const filename: string);
  end;

implementation

class procedure TPointerArrayNodeTree.free_reqursive(node: PNode);
var
  i: SizeInt;
begin
  for i:=0 to Length(node^.child_nodes)-1 do free_reqursive(node^.child_nodes[i]);
  SetLength(node^.child_nodes, 0);
  Dispose(node);
end;

class function TPointerArrayNodeTree.get_child_count(node: PNode): SizeInt;
begin
  Result:=Length(node^.child_nodes);
end;

class procedure TPointerArrayNodeTree.set_child_count(node: PNode; count: SizeInt);
var
  old_len, i: SizeInt;
begin
  old_len:=Length(node^.child_nodes);
  if count>old_len then
  begin
    SetLength(node^.child_nodes, count);
    for i:=old_len to count-1 do
    begin
      New(node^.child_nodes[i]);
      FillChar(node^.child_nodes[i]^, SizeOf(TNode), 0);
    end;
  end else
  begin
    for i:=count to old_len-1 do free_reqursive(node^.child_nodes[i]);
    SetLength(node^.child_nodes, count);
  end;
end;

class function TPointerArrayNodeTree.get_child(node: PNode; i: SizeInt): PNode;
begin
  Result:=node^.child_nodes[i];
end;

class function TPointerArrayNodeTree.add_child(node: PNode): PNode;
var
  child_count: SizeInt;
begin
  child_count := get_child_count(node);
  set_child_count(node, child_count+1);
  Result:=get_child(node, child_count);
end;

class function TPointerArrayNodeTree.find_child_node(node: PNode; data: Pointer): PNode;
var
  i: longint;
begin
  for i:=0 to get_child_count(node)-1 do
    if TNodeComparator.IsEqual(@get_child(node, i)^.node_data, data) then Exit(get_child(node, i));
  Result:=nil
end;

destructor TPointerArrayNodeTree.Destroy;
begin
  inherited Destroy;
  Clear;
end;

procedure TPointerArrayNodeTree.Clear;
begin
  set_child_count(@root_node, 0);
end;

procedure TPointerArrayNodeTree.SaveToFile(const filename: string; const fileext: string);
begin
  TLoaderSaver.SaveToFile(@root_node, filename, fileext);
end;

procedure TPointerArrayNodeTree.LoadFromFile(const filename: string);
begin
  Clear;
  TLoaderSaver.LoadFromFile(@root_node, filename);
end;



// --------------------
class procedure TNodeTreeLoaderSaver.SaveToFile(node: Pointer; const filename: string; const fileext: string);
var
  NodeDataIO: TNodeDataIO;
  child_count: UInt32;

  procedure SaveNodeRecursive(node: Pointer);
  var
    i: Int32;
  begin
    NodeDataIO.WriteData(TNodeTree.PNode(node)^.node_data, SizeOf(TNodeTree.TNodeDataType));

    child_count:=TNodeTree.get_child_count(node);
    NodeDataIO.WriteData(child_count, SizeOf(child_count));

    for i:=0 to TNodeTree.get_child_count(node)-1 do
      SaveNodeRecursive(TNodeTree.get_child(node, i));
  end;
begin
  NodeDataIO:=TNodeDataIO.Create(filename, fileext);

  SaveNodeRecursive(node);

  NodeDataIO.Free;
end;

class procedure TNodeTreeLoaderSaver.LoadFromFile(node: Pointer; const filename: string);
var
  NodeDataIO: TNodeDataIO;
  child_count: UInt32;

  procedure LoadNodeRecursive(node: Pointer);
  var
    i: Int32;
  begin
    NodeDataIO.ReadData(TNodeTree.PNode(node)^.node_data, SizeOf(TNodeTree.TNodeDataType));
    NodeDataIO.ReadData(child_count, SizeOf(child_count));
    TNodeTree.set_child_count(node, child_count);

    for i:=0 to TNodeTree.get_child_count(node)-1 do
    begin
      LoadNodeRecursive(TNodeTree.get_child(node, i));
    end;
  end;
begin
  NodeDataIO:=TNodeDataIO.Create(filename,'');

  LoadNodeRecursive(node);

  NodeDataIO.Free;
end;


end.

