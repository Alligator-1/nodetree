unit nodetree;
{$mode objfpc}{$h+}
{$modeswitch advancedrecords}

interface

procedure MyZeroMemory(var x; count: SizeInt); inline;

type
  TSimpleAllocator = class
    class function GetMem(Size: PtrUInt): Pointer; static; inline;
    class procedure FreeMem(p: Pointer); static; inline;
  end;

  generic TNode<TNodeData, TNodeComparator, TAllocator> = record
  type
    PNode = ^TNode;
    PNodeData = ^TNodeData;
  public
    Sibling: PNode;
    Child: PNode;
    NodeData: TNodeData;

    procedure FreeReqursive;
    class function NewNode: PNode; static; inline;
    procedure AddChild(node: PNode); inline;
    procedure AddSibling(node: PNode); inline;
    function AddChild: PNode; inline;
    function AddSibling: PNode; inline;
    function FindChild(Data: Pointer): PNode; inline;
  end;

implementation

procedure MyZeroMemory(var x; count: SizeInt); inline;
begin
  if IsConstValue(count) then
  begin
    if count mod 8 = 0 then FillQWord(x, count div 8, 0)
    else if count mod 4 = 0 then FillDWord(x, count div 4, 0)
    else if count mod 2 = 0 then FillWord(x, count div 2, 0)
    else FillChar(x, count, 0);
  end else FillChar(x, count, 0);
end;

class function TSimpleAllocator.GetMem(Size: PtrUInt): Pointer;
begin
  Result:=System.GetMem(Size);
  MyZeroMemory(Result^, Size);
end;

class procedure TSimpleAllocator.FreeMem(p: Pointer);
begin
  System.FreeMem(p);
end;

procedure TNode.FreeReqursive;
begin
  if Assigned(Sibling) then Sibling^.FreeReqursive;
  if Assigned(Child) then Child^.FreeReqursive;
  TAllocator.FreeMem(@Self);
end;

class function TNode.NewNode: PNode;
begin
  Result:=TAllocator.GetMem(SizeOf(TNode)); // Инициализацию памяти (обнуление) - должен делать аллокатор
end;

procedure TNode.AddChild(node: PNode);
begin
  node^.Sibling:=Child;
  Child:=node;
end;

procedure TNode.AddSibling(node: PNode);
begin
  node^.Sibling:=Sibling;
  Sibling:=node;
end;

function TNode.AddChild: PNode;
begin
  Result:=NewNode;
  AddChild(Result);
end;

function TNode.AddSibling: PNode;
begin
  Result:=NewNode;
  AddSibling(Result);
end;

function TNode.FindChild(Data: Pointer): PNode;
begin
  Result:=Child;
  while Assigned(Result) do
  begin
    if TNodeComparator.Compare(@Result^.NodeData, Data)=0 then Exit;
    Result:=Result^.Sibling;
  end;
end;

end.

