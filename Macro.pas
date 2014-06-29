unit Macro;

interface

uses
  Classes, Types, SysUtils;

type
  TMacro = class
  private
    FName: string;
    FParameters: TStringList;
    FContent: string;
    FAddAsExternal: Boolean;
  public
    constructor Create(const AName: string);
    destructor Destroy(); override;
    property Name: string read FName;
    property Parameters: TStringList read FParameters;
    property Content: string read FContent write FContent;
    property AddAsExternal: Boolean read FAddAsExternal write FAddAsExternal;
  end;

implementation

{ TMacro }

constructor TMacro.Create(const AName: string);
begin
  inherited Create();
  FName := AName;
  FParameters := TStringList.Create();
end;

destructor TMacro.Destroy;
begin
  FParameters.Free;
  inherited;
end;

end.
