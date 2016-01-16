
#Rem
	'jstool' application: "WebCC" - Driver program for the Monkey transpiler.
	
	Based heavily on 'TransCC': Original software placed into the public domain. (02/24/2011)
	No warranty implied; use at your own risk.
#End

'Strict

Public

' Preprocessor related:
#WEBCC_EXTENSION_REGAL_MODULES = True

' Tell 'jstool' that we'll be starting this natively. (Button, function call, etc)
#JSTOOL_STANDALONE = True

' Imports:

' JavaScript:
Import "native/wcc_support.js"

' Monkey:
Import trans
Import builders

' Constant variable(s):
Const VERSION:String = "1.0.1 {1.86}"

' External bindings:
Extern

' Global variable(s):

' This is externally defined so we can bypass 'bbInit' at the target/translator level.
Global __Monkey_DirectoryLoaded:Bool="__monkey_DirectoryLoaded"

Public

' Functions:
Function Main:Int()
	' Local variable(s):
	Local CC:= New WebCC()
	
	If (Not __Monkey_DirectoryLoaded) Then
		__OS_AddFileSystem(__OS_ToRemotePath(RealPath("data/webcc_filesystem.txt")))
		
		#If WEBCC_EXTENSION_REGAL_MODULES
			__OS_AddFileSystem(__OS_ToRemotePath(RealPath("data/modules/regal/regal_filesystem.txt")))
		#End
		
		__Monkey_DirectoryLoaded = True
	Endif
	
	CC.Run(AppArgs())
	
	' Return the default response.
	Return 0
End

Function Die:Int(Message:String, ExitCode:Int=-1)
	Print("WEBCC (TRANS) FAILED: " + Message)
	
	ExitApp(ExitCode)
	
	Return ExitCode
End

Function StripQuotes:String(Str:String)
	If (Str.Length >= 2 And Str.StartsWith("~q") And Str.EndsWith("~q")) Then
		Return Str[1..-1]
	Endif
	
	Return Str
End

Function ReplaceEnv:String(Str:String)
	Local Bits:= New StringStack()
	
	Repeat
		Local i:= Str.Find("${")
		If (i = -1) Then Exit
		
		Local e:= Str.Find("}", i+2)
		If (e = -1) Then Exit
		
		If (i >= 2 And Str[i-2..i] = "//") Then
			Bits.Push(Str[..e+1])
			Str = Str[e+1..]
			
			Continue
		Endif
		
		Local t:= Str[i+2..e]
		
		Local v:= GetConfigVar(t)
		If (Not v) Then v = GetEnv(t)
		
		Bits.Push(Str[..i])
		Bits.Push(v)
		
		Str = Str[e+1..]
	Forever
	
	If (Bits.IsEmpty()) Then
		Return Str
	Endif
	
	Bits.Push(Str)
	
	Return Bits.Join("")
End

Function ReplaceBlock:String(text:String, tag:String, repText:String, mark:String="~n//")
	' Find the beginning tag.
	Local beginTag:= mark + "${" + tag + "_BEGIN}"
	Local i:= text.Find(beginTag)
	
	If (i = -1) Then
		Die("Error updating target project - can't find block begin tag '" + tag + "'. You may need to delete target .build directory.")
	Endif
	
	i += beginTag.Length
	
	While (i < text.Length And text[i-1] <> 10)
		i += 1
	Wend
	
	' Find the ending tag.
	Local endTag:= mark + "${" + tag + "_END}"
	Local i2:= text.Find(endTag, i-1)
	
	If (i2 = -1) Then
		Die("Error updating target project - can't find block end tag '" + tag + "'.")
	Endif
	
	If (Not repText Or repText[repText.Length-1] = 10) Then
		i2 += 1
	Endif
	
	Return text[..i] + repText + text[i2..]
End

Function MatchPathAlt:Bool(text:String, alt:String)
	If (Not alt.Contains( "*" )) Then
		Return (alt = text)
	Endif
	
	Local Bits:= alt.Split( "*" )
	
	If (Not text.StartsWith(Bits[0])) Then
		Return False
	Endif
	
	Local n:= (Bits.Length - 1)
	Local i:= Bits[0].Length
	
	For Local j:= 1 Until n
		Local bit:= Bits[j]
		
		i = text.Find(bit, i)
		
		If (i = -1) Then
			Return False
		Endif
		
		i += bit.Length
	Next

	Return text[i..].EndsWith(Bits[n])
End

Function MatchPath:Bool(text:String, pattern:String)
	text = "/" + text
	
	Local alts:= pattern.Split("|")
	Local match:= False

	For Local alt:= Eachin alts
		If (Not alt) Then
			Continue
		Endif
		
		If (alt.StartsWith("!")) Then
			If (MatchPathAlt(text, alt[1..])) Then
				Return False
			Endif
		Else
			If (MatchPathAlt(text, alt)) Then
				match = True
			Endif
		Endif
	Next
	
	Return match
End

' Classes:
Class Target
	' Fields:
	Field dir:String
	Field name:String
	Field system:String
	Field builder:Builder
	
	' Constructor(s):
	Method New(dir:String, name:String, system:String, builder:Builder)
		Self.dir = dir
		Self.name = name
		Self.system = system
		Self.builder = builder
	End
End

Class WebCC
	' Fields (Protected):
	Protected
	
	' Command-line options:
	Field opt_safe:Bool
	Field opt_clean:Bool
	Field opt_check:Bool
	Field opt_update:Bool
	Field opt_build:Bool
	Field opt_run:Bool

	Field opt_srcpath:String
	Field opt_cfgfile:String
	Field opt_output:String
	Field opt_config:String
	Field opt_casedcfg:String
	Field opt_target:String
	Field opt_modpath:String
	Field opt_builddir:String
	
	' Configuration file:
	Field HTML_PLAYER:String
	
	' Meta:
	Field args:String[]
	Field monkeydir:String
	
	Field target:Target
	
	Public
	
	' Fields (Private):
	Private
	
	Field _builders:= New StringMap<Builder>
	Field _targets:= New StringMap<Target>
	
	Public
	
	' Methods:
	Method Run:Void(args:String[])
		Self.args = args
		
		Print("WebCC Monkey compiler V" + VERSION)
		
		Local APath:= AppPath()
		Local EDir:= ExtractDir(APath)
		
		monkeydir=RealPath( EDir +"/.." )
		
		SetEnv "MONKEYDIR",monkeydir
		SetEnv "TRANSDIR",monkeydir+"/bin"
		
		ParseArgs
		
		LoadConfig
		
		EnumBuilders
		
		EnumTargets "targets"
		
		If args.Length<2
			Local valid:=""
			For Local it:=Eachin _targets
				valid+=" "+it.Key.Replace( " ","_" )
			Next
			Print "TRANS Usage: WebCC [-update] [-build] [-run] [-clean] [-config=...] [-target=...] [-cfgfile=...] [-modpath=...] <main_monkey_source_file>"
			Print "Valid targets:"+valid
			Print "Valid configs: debug release"
			ExitApp 0
		Endif
		
		target=_targets.Get( opt_target.Replace( "_"," " ) )
		If Not target Die "Invalid target"
		
		target.builder.Make
	End

	Method GetReleaseVersion:String()
		Local f:=LoadString( monkeydir+"/VERSIONS.TXT" )
		For Local t:=Eachin f.Split( "~n" )
			t=t.Trim()
			If t.StartsWith( "***** v" ) And t.EndsWith( " *****" ) Return t[6..-6]
		Next
		Return ""
	End
	
	Method EnumBuilders:Void()
		For Local it:=Eachin Builders( Self )
			If it.Value.IsValid() _builders.Set it.Key,it.Value
		Next
	End
	
	Method EnumTargets:Void( dir:String )
	
		Local p:=monkeydir+"/"+dir
		
		For Local f:=Eachin LoadDir( p )
			Local t:=p+"/"+f+"/TARGET.MONKEY"
			If FileType(t)<>FILETYPE_FILE Continue
			
			PushConfigScope
			
			PreProcess t
			
			Local name:=GetConfigVar( "TARGET_NAME" )
			If name
				Local system:=GetConfigVar( "TARGET_SYSTEM" )
				If system
					Local builder:=_builders.Get( GetConfigVar( "TARGET_BUILDER" ) )
					If builder
						Local host:=GetConfigVar( "TARGET_HOST" )
						If Not host Or host=HostOS
							_targets.Set name,New Target( f,name,system,builder )
						Endif
					Endif
				Endif
			Endif
			
			PopConfigScope
			
		Next
	End
	
	Method ParseArgs:Void()
	
		If args.Length>1 opt_srcpath=StripQuotes( args[args.Length-1].Trim() )
	
		For Local i:=1 Until args.Length-1
		
			Local arg:=args[i].Trim(),rhs:=""
			Local j:=arg.Find( "=" )
			If j<>-1
				rhs=StripQuotes( arg[j+1..] )
				arg=arg[..j]
			Endif
		
			If (j = -1) Then
				Select arg.ToLower()
					Case "-safe"
						opt_safe = True
					Case "-clean"
						opt_clean = True
					Case "-check"
						opt_check = True
					Case "-update"
						opt_check = True
						opt_update = True
					Case "-build"
						opt_check = True
						opt_update = True
						opt_build = True
					Case "-run"
						opt_check = True
						opt_update = True
						opt_build = True
						opt_run = True
					Default
						Die("Unrecognized command-line option: " + arg)
				End Select
			Elseif (arg.StartsWith("-")) Then
				Select arg.ToLower()
				Case "-cfgfile"
					opt_cfgfile=rhs
				Case "-output"
					opt_output=rhs
				Case "-config"
					opt_config=rhs.ToLower()
				Case "-target"
					opt_target=rhs
				Case "-modpath"
					opt_modpath=rhs
				Case "-builddir"
					opt_builddir=rhs
				Default
					Die "Unrecognized command line option: "+arg
				End
			Elseif (arg.StartsWith("+")) Then
				SetConfigVar(arg[1..], rhs)
			Else
				Die("Command-line parser error: " + arg)
			End
		Next
		
	End

	Method LoadConfig:Void()
		Local cfgpath:=monkeydir+"/bin/"
		
		If opt_cfgfile 
			cfgpath+=opt_cfgfile
		Else
			cfgpath+="config."+HostOS+".txt"
		Endif
		If FileType( cfgpath )<>FILETYPE_FILE Die "Failed to open config file"
		
		Local cfg:= LoadString(cfgpath)
			
		For Local line:=Eachin cfg.Split( "~n" )
			line=line.Trim()
			
			If Not line Or line.StartsWith( "'" ) Continue
			
			Local i:= line.Find( "=" )
			If i=-1 Die "Error in config file, line="+line
			
			Local lhs:=line[..i].Trim()
			Local rhs:=line[i+1..].Trim()
			
			rhs=ReplaceEnv( rhs )
			
			Local path:=StripQuotes( rhs )
	
			While path.EndsWith( "/" ) Or path.EndsWith( "\" ) 
				path=path[..-1]
			Wend
			
			Select lhs
				Case "MODPATH"
					If (Not opt_modpath) Then
						opt_modpath = path
					Endif
				Case "HTML_PLAYER" 
					HTML_PLAYER = rhs
				Default 
					Print("WebCC: Ignoring unrecognized config variable: " + lhs)
			End Select
		Next
	End
	
	Method Execute:Bool(CommandLine:String, FailHard:Bool=True)
		Local ResponseCode:= os.Execute(CommandLine)
		
		If (Not ResponseCode) Then
			Return True
		Endif
		
		If (FailHard) Then
			Die("Error executing '" + CommandLine + "', return code: " + ResponseCode)
		Endif
		
		' Return the default response.
		Return False
	End
End
