unit PreProcessor;

interface

uses
  Classes, Types, Windows, SysUtils,
  Lexer, Token, Macro, Generics.Collections;

type
  TPreProcessor = class
  private
    FMacros: TObjectList<TMacro>;
    function GetEmptyString(ACount: Integer): string;
    function GetEmptyLines(ACount: Integer): string;
    function GetTokenContent(AToken: TToken): string;
    function GetRelativeTokenLineOffset(AToken: TToken): Integer;
    function ProcessToken(ALexer: TLexer; AToken: TToken; var ALinePosition, ALastLine: Integer): string;
    function IsMacro(AToken: TToken): Boolean;
    function TryGetMacro(const AName: string; var AMacro: TMacro): Boolean;
    function ProcessMacro(AMacro: TMacro; AParameters: TStringList): string;
    procedure ParseParameters(ALexer: TLexer; AParameters: TStringList);
  public
    constructor Create();
    destructor Destroy(); override;
    procedure RegisterMacro(AMacro: TMacro);
    procedure ProcessFile(const AName: string);
  end;

implementation

uses
  StrUtils;

{ TPreProcessor }

constructor TPreProcessor.Create;
begin
  inherited;
  FMacros := TObjectList<TMacro>.Create();
end;

destructor TPreProcessor.Destroy;
begin
  FMacros.Free;
  inherited;
end;

function TPreProcessor.GetEmptyLines(ACount: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to ACount - 1 do
  begin
    Result := Result + sLineBreak;
  end;
end;

function TPreProcessor.GetEmptyString(ACount: Integer): string;
begin
  Result := StringOfChar(' ', ACount);
end;

function TPreProcessor.GetTokenContent(AToken: TToken): string;
begin
  if AToken.IsType(ttCharLiteral) then
  begin
    Result := QuotedStr(AToken.Content);
  end
  else
  begin
    Result := AToken.Content;
  end;
end;

function TPreProcessor.GetRelativeTokenLineOffset(AToken: TToken): Integer;
begin
  if AToken.IsType(ttCharLiteral) then
  begin
    Result := AToken.RelativeLineOffset - 1;
  end
  else
  begin
    Result := AToken.RelativeLineOffset;
  end;
end;

function TPreProcessor.IsMacro(AToken: TToken): Boolean;
var
  LMacro: TMacro;
begin
  Result := AToken.IsType(ttIdentifier) and TryGetMacro(AToken.Content, LMacro);
end;

procedure TPreProcessor.ParseParameters(ALexer: TLexer;
  AParameters: TStringList);
var
  LLevel: Integer;
  LParameter: string;
begin
  LLevel := 0;
  if ALexer.PeekToken.IsContent('(') then
  begin
    ALexer.GetToken();
    LParameter := '';
    while not ALexer.EOF do
    begin
      if (LLevel = 0) and ALexer.PeekToken.IsContent(',') then
      begin
        AParameters.Add(LParameter);
        LParameter := '';
        ALexer.GetToken()
      end;
      if (LLevel = 0) and ALexer.PeekToken.IsContent(')') then
      begin
        if LParameter <> '' then
        begin
          AParameters.Add(LParameter);
        end;
        ALexer.GetToken();
        Break;
      end;

      LParameter := LParameter + ALexer.PeekToken.Content;
      if ALexer.PeekToken.IsContent('(') then
      begin
        Inc(LLevel);
      end
      else
      begin
        if ALexer.PeekToken.IsContent(')') then
        begin
          Dec(LLevel);
        end;
      end;
      ALexer.GetToken();
    end;
  end;
end;

procedure TPreProcessor.ProcessFile(const AName: string);
var
  LLexer: TLexer;
  LOutput: string;
  LLinePosition: Integer;
  LToken: TToken;
  LFile: TStringList;
  LLastLine: Integer;
begin
  LLexer := TLexer.Create();
  try
    LOutput := '';
    LLinePosition := 0;
    LLastLine := 1;
    LLexer.KeepComments := True;
    LLexer.LoadFromFile(AName);
    while not LLexer.EOF do
    begin
      LToken := LLexer.GetToken();
      LOutput := LOutput + ProcessToken(LLexer, LToken, LLinePosition, LLastLine);
    end;
    LFile := TStringList.Create();
    try
      LFile.Text := LOutput;
      LFile.SaveToFile('Generated.pas');
    finally
      LFile.Free;
    end;
  finally
    LLexer.Free;
  end;
end;

function TPreProcessor.ProcessMacro(AMacro: TMacro;
  AParameters: TStringList): string;
var
  LLexer: TLexer;
  LContent: string;
  LIndex, LLinePosition, LLastLine: Integer;
  LToken: TToken;
begin
  Result := '';
  if AParameters.Count <> AMacro.Parameters.Count then
  begin
    raise Exception.Create('Parameter count does not match');
  end;
  LLexer := TLexer.Create();
  try
    LLinePosition := 0;
    LLastLine := 1;
    LLexer.LoadFromString(AMacro.Content);
    while not LLexer.EOF do
    begin
      LContent := GetTokenContent(LLexer.PeekToken);
      LIndex := AMacro.Parameters.IndexOf(LowerCase(LContent));
      if LIndex > -1 then
      begin
        LToken := TToken.Create(AParameters[LIndex], ttIdentifier);
        try
          LToken.FollowedByNewLine := LLexer.PeekToken.FollowedByNewLine;
          LToken.FoundInLine := LLexer.PeekToken.FoundInLine;
          LToken.LineOffset := LLexer.PeekToken.LineOffset;
          LToken.RelativeLineOffset := LLexer.PeekToken.RelativeLineOffset;
          Result := Result + ProcessToken(LLexer, LToken, LLinePosition, LLastLine);
        finally
          LToken.Free;
        end;
      end
      else
      begin
        Result := Result + ProcessToken(LLexer, LLexer.PeekToken, LLinePosition, LLastLine);
      end;
      LLexer.GetToken();
    end;
  finally
    LLexer.Free;
  end;
end;

function TPreProcessor.ProcessToken(ALexer: TLexer; AToken: TToken; var ALinePosition, ALastLine: Integer): string;
var
  LContent, LOutput: string;
  LMacro: TMacro;
  LParameters: TStringList;
  LRelativeOffset: Integer;
begin
  LContent := GetTokenContent(AToken);
  LRelativeOffset := GetRelativeTokenLineOffset(AToken);
//  LPositionOffset := LOffset - ALinePosition;
  LOutput := GetEmptyLines(AToken.FoundInLine - ALastLine - 1);
  LOutput := LOutput + GetEmptyString(LRelativeOffset);
  if IsMacro(AToken) then
  begin
    LParameters := TStringList.Create();
    try
      TryGetMacro(AToken.Content, LMacro);
      ParseParameters(ALexer, LParameters);
      LOutput := LOutput + ProcessMacro(LMacro, LParameters);
    finally
      LParameters.Free;
    end;
  end
  else
  begin
    LOutput := LOutput + LContent;
  end;

  ALinePosition := ALinePosition + LRelativeOffset + Length(LContent);
  ALastLine := AToken.FoundInLine;
  if AToken.FollowedByNewLine then
  begin
    LOutput := LOutput + sLineBreak;
    ALinePosition := 0;
  end;
  Result := LOutput;
end;

procedure TPreProcessor.RegisterMacro(AMacro: TMacro);
begin
  FMacros.Add(AMacro);
end;

function TPreProcessor.TryGetMacro(const AName: string;
  var AMacro: TMacro): Boolean;
var
  LMacro: TMacro;
begin
  Result := False;
  for LMacro in FMacros do
  begin
    if SameText(LMacro.Name, AName) then
    begin
      Result := True;
      AMacro := LMacro;
      Break;
    end;
  end;
end;

end.
