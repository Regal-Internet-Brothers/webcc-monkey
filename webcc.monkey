
#Rem
	'jstool' application: "WebCC" - Driver program for the Monkey transpiler.
	
	Based heavily on 'TransCC': Original software placed into the public domain. (02/24/2011)
	No warranty implied; use at your own risk.
#End

'Strict

Public

' Preprocessor related:

' Tell 'jstool' that we'll be starting this natively. (Button, function call, etc)
#JSTOOL_STANDALONE = True

' Imports:

' JavaScript:
Import "native/wcc_support.js"

' Monkey:
Import trans
Import builders

' Constant variable(s):
Const VERSION:String = "1.86"

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
		
		__Monkey_DirectoryLoaded = True
	Endif
	
	CC.Run(AppArgs())
	
	' Return the default response.
	Return 0
End

Function Die:Int(Message:String, ExitCode:Int=-1)
	Print("TRANS FAILED: " + Message)
	
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
		Self.dir=dir
		Self.name=name
		Self.system=system
		Self.builder=builder
	End
End

Class WebCC
	' Fields:
	
	' Command-line arguments:
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
	
	'config file
	Field ANDROID_PATH:String
	Field ANDROID_NDK_PATH:String
	Field ANT_PATH:String
	Field JDK_PATH:String
	Field FLEX_PATH:String
	Field MINGW_PATH:String
	Field MSBUILD_PATH:String
	Field PSS_PATH:String
	Field PSM_PATH:String
	Field HTML_PLAYER:String
	Field FLASH_PLAYER:String
	
	Field args:String[]
	Field monkeydir:String
	Field target:Target
	
	Field _builders:= New StringMap<Builder>
	Field _targets:= New StringMap<Target>
	
	Method Run:Void(args:String[])
		Self.args=args
		
		Print("TRANS monkey compiler V" + VERSION)
		
		#If CONFIG = "debug"
			'DebugStop()
		#End
		
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
		
			If j=-1
				Select arg.ToLower()
				Case "-safe"
					opt_safe=True
				Case "-clean"
					opt_clean=True
				Case "-check"
					opt_check=True
				Case "-update"
					opt_check=True
					opt_update=True
				Case "-build"
					opt_check=True
					opt_update=True
					opt_build=True
				Case "-run"
					opt_check=True
					opt_update=True
					opt_build=True
					opt_run=True
				Default
					Die "Unrecognized command line option: "+arg
				End
			Else If arg.StartsWith( "-" )
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
			Else If arg.StartsWith( "+" )
				SetConfigVar arg[1..],rhs
			Else
				Die "Command line arg error: "+arg
			End
		Next
		
	End

	Method LoadConfig:Void()
		#If CONFIG = "debug"
			'DebugStop()
		#End
		
		Local cfgpath:=monkeydir+"/bin/"
		If opt_cfgfile 
			cfgpath+=opt_cfgfile
		Else
			cfgpath+="config."+HostOS+".txt"
		Endif
		If FileType( cfgpath )<>FILETYPE_FILE Die "Failed to open config file"
		
		Local cfg:=LoadString( cfgpath )
			
		'Print("CFG ["+cfgpath+"] ("+cfg.Length+"): " + cfg)
			
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
				If Not opt_modpath
					opt_modpath=path
				Endif
			Case "ANDROID_PATH"
				If Not ANDROID_PATH And FileType( path )=FILETYPE_DIR
					ANDROID_PATH=path
				Endif
			Case "ANDROID_NDK_PATH"
				If Not ANDROID_NDK_PATH And FileType( path )=FILETYPE_DIR
					ANDROID_NDK_PATH=path
				Endif
			Case "JDK_PATH" 
				If Not JDK_PATH And FileType( path )=FILETYPE_DIR
					JDK_PATH=path
				Endif
			Case "ANT_PATH"
				If Not ANT_PATH And FileType( path )=FILETYPE_DIR
					ANT_PATH=path
				Endif
			Case "FLEX_PATH"
				If Not FLEX_PATH And FileType( path )=FILETYPE_DIR
					FLEX_PATH=path
				Endif
			Case "MINGW_PATH"
				If Not MINGW_PATH And FileType( path )=FILETYPE_DIR
					MINGW_PATH=path
				Endif
			Case "PSM_PATH"
				If Not PSM_PATH And FileType( path )=FILETYPE_DIR
					PSM_PATH=path
				Endif
			Case "MSBUILD_PATH"
				If Not MSBUILD_PATH And FileType( path )=FILETYPE_FILE
					MSBUILD_PATH=path
				Endif
			Case "HTML_PLAYER" 
				HTML_PLAYER=rhs
			Case "FLASH_PLAYER" 
				FLASH_PLAYER=rhs
			Default 
				Print "Trans: ignoring unrecognized config var: "+lhs
			End
	
		Next
		
		Select HostOS
		Case "winnt"
			Local path:=GetEnv( "PATH" )
			
			If ANDROID_PATH path+=";"+ANDROID_PATH+"/tools"
			If ANDROID_PATH path+=";"+ANDROID_PATH+"/platform-tools"
			If JDK_PATH path+=";"+JDK_PATH+"/bin"
			If ANT_PATH path+=";"+ANT_PATH+"/bin"
			If FLEX_PATH path+=";"+FLEX_PATH+"/bin"
			
			If MINGW_PATH path=MINGW_PATH+"/bin;"+path	'override existing mingw path if any...
	
			SetEnv "PATH",path
			
			If JDK_PATH SetEnv "JAVA_HOME",JDK_PATH
	
		Case "macos"

			'Execute "echo $PATH"
			'Print GetEnv( "PATH" )
		
			Local path:=GetEnv( "PATH" )
			
			If ANDROID_PATH path+=":"+ANDROID_PATH+"/tools"
			If ANDROID_PATH path+=":"+ANDROID_PATH+"/platform-tools"
			If ANT_PATH path+=":"+ANT_PATH+"/bin"
			If FLEX_PATH path+=":"+FLEX_PATH+"/bin"
			
			SetEnv "PATH",path
			
			'Execute "echo $PATH"
			'Print GetEnv( "PATH" )
			
		Case "linux"

			Local path:=GetEnv( "PATH" )
			
			If JDK_PATH path=JDK_PATH+"/bin:"+path
			If ANDROID_PATH path=ANDROID_PATH+"/platform-tools:"+path
			If FLEX_PATH path=FLEX_PATH+"/bin:"+path
			
			SetEnv "PATH",path
			
		End
		
	End
	
	Method Execute:Bool( cmd:String,failHard:Bool=True )
	'	Print "Execute: "+cmd
		Local r:=os.Execute( cmd )
		If Not r Return True
		If failHard Die "Error executing '"+cmd+"', return code="+r
		Return False
	End

End
