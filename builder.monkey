
Import webcc
Import reflection.reflector

Class Builder

	Method New( WCC:WebCC )
		Self.WCC=WCC
	End
	
	Method IsValid:Bool() Abstract
	
	Method Begin:Void() Abstract
	
	Method MakeTarget:Void() Abstract
	
	Method Make:Void()
	
		Select WCC.opt_config
		Case "","debug"
			WCC.opt_config="debug"
			casedConfig="Debug"
		Case "release" 
			casedConfig="Release"
		Default
			Die "Invalid config"
		End
	
		If FileType( WCC.opt_srcpath )<>FILETYPE_FILE Die "Invalid source file"
		WCC.opt_srcpath=RealPath( WCC.opt_srcpath )

		If Not WCC.opt_modpath WCC.opt_modpath=WCC.monkeydir+"/modules"

		WCC.opt_modpath=".;"+ExtractDir( WCC.opt_srcpath )+";"+WCC.opt_modpath+";"+WCC.monkeydir+"/targets/"+WCC.target.dir+"/modules"
		
		If Not WCC.opt_check
			WCC.opt_check=True
			WCC.opt_update=True
			WCC.opt_build=True
		Endif
		
		ENV_HOST=HostOS
		ENV_CONFIG=WCC.opt_config
		ENV_SAFEMODE=WCC.opt_safe
		ENV_MODPATH=WCC.opt_modpath
		ENV_TARGET=WCC.target.system
			
		Self.Begin

		'***** TRANSLATE *****
		If Not WCC.opt_check Return

		Print "Parsing..."
		
		SetConfigVar "HOST",ENV_HOST
		SetConfigVar "LANG",ENV_LANG
		SetConfigVar "TARGET",ENV_TARGET
		SetConfigVar "CONFIG",ENV_CONFIG
		SetConfigVar "SAFEMODE",ENV_SAFEMODE
		
		app=ParseApp( WCC.opt_srcpath )

		Print "Semanting..."
		If GetConfigVar("REFLECTION_FILTER")
			Local r:=New Reflector
			r.Semant app
		Else
			app.Semant
		Endif
		
		Print "Translating..."
		Local transbuf:=New StringStack
		For Local file$=Eachin app.fileImports
			If ExtractExt( file ).ToLower()=ENV_LANG
				transbuf.Push LoadString( file )
				transbuf.Push "~n"
			Endif
		Next
		transbuf.Push _trans.TransApp( app )
		
		'***** UPDATE *****
		If Not WCC.opt_update Return
		
		Print "Building..."

		transCode=transbuf.Join()
		
		Local buildPath:String
		
		If WCC.opt_builddir
			buildPath=ExtractDir( WCC.opt_srcpath )+"/"+WCC.opt_builddir
		Else
			buildPath=StripExt( WCC.opt_srcpath )+".build"+WCC.GetReleaseVersion()
		Endif
		
		Local targetPath:=buildPath+"/"+WCC.target.dir	'ENV_TARGET

		If WCC.opt_clean
			DeleteDir targetPath,True
			If FileType( targetPath )<>FILETYPE_NONE Die "Failed to clean target dir"
		Endif

		If FileType( targetPath )=FILETYPE_NONE
			If FileType( buildPath )=FILETYPE_NONE CreateDir buildPath
			If FileType( buildPath )<>FILETYPE_DIR Die "Failed to create build dir: "+buildPath
			If Not CopyDir( WCC.monkeydir+"/targets/"+WCC.target.dir+"/template",targetPath,True,False ) Die "Failed to copy target dir"
		Endif
		If FileType( targetPath )<>FILETYPE_DIR Die "Failed to create target dir: "+targetPath
		
		Local cfgPath:=targetPath+"/CONFIG.MONKEY"
		If FileType( cfgPath )=FILETYPE_FILE PreProcess cfgPath
		
		TEXT_FILES=GetConfigVar( "TEXT_FILES" )
		IMAGE_FILES=GetConfigVar( "IMAGE_FILES" )
		SOUND_FILES=GetConfigVar( "SOUND_FILES" )
		MUSIC_FILES=GetConfigVar( "MUSIC_FILES" )
		BINARY_FILES=GetConfigVar( "BINARY_FILES" )
		
		DATA_FILES=TEXT_FILES
		If IMAGE_FILES DATA_FILES+="|"+IMAGE_FILES
		If SOUND_FILES DATA_FILES+="|"+SOUND_FILES
		If MUSIC_FILES DATA_FILES+="|"+MUSIC_FILES
		If BINARY_FILES DATA_FILES+="|"+BINARY_FILES
		DATA_FILES=DATA_FILES.Replace( ";","|" )
	
		syncData=GetConfigVar( "FAST_SYNC_PROJECT_DATA" )="1"
		
		Local cd:=CurrentDir

		ChangeDir targetPath
		Self.MakeTarget
		ChangeDir cd

	End
	
	Field WCC:WebCC
	Field app:AppDecl
	Field transCode:String
	Field casedConfig:String
	Field dataFiles:=New StringMap<String>	'maps real src path to virtual target path
	Field syncData:Bool
	Field DATA_FILES$
	Field TEXT_FILES$
	Field IMAGE_FILES$
	Field SOUND_FILES$
	Field MUSIC_FILES$
	Field BINARY_FILES$
	
	Method Execute:Bool( cmd:String,failHard:Bool=True )
		Return WCC.Execute( cmd,failHard )
	End
	
	Method CCopyFile:Void( src:String,dst:String )
		If FileTime( src )>FileTime( dst ) Or FileSize( src )<>FileSize( dst )
			DeleteFile dst
			CopyFile src,dst
		Endif
	End
	
	Method CreateDataDir:Void( dir:String )
	
		dir=RealPath( dir )
	
		If Not syncData DeleteDir dir,True
		CreateDir dir
		
		If FileType( dir )<>FILETYPE_DIR Die "Failed to create target project data dir: "+dir
		
		Local dataPath:=StripExt( WCC.opt_srcpath )+".data"
		If FileType( dataPath )<>FILETYPE_DIR dataPath=""
		
		'all used data...
		Local udata:=New StringSet
		
		'Copy data from monkey project to target project
		If dataPath
		
			Local srcs:=New StringStack
			srcs.Push dataPath
			
			While Not srcs.IsEmpty()
			
				Local src:=srcs.Pop()
				
				For Local f:=Eachin LoadDir( src )
					If f.StartsWith( "." ) Continue

					Local p:=src+"/"+f
					Local r:=p[dataPath.Length+1..]
					Local t:=dir+"/"+r
					
					Select FileType( p )
					Case FILETYPE_FILE
						If MatchPath( r,DATA_FILES )
							CCopyFile p,t
							udata.Insert t
							dataFiles.Set p,r
						Endif
					Case FILETYPE_DIR
						CreateDir t
						srcs.Push p
					End
				Next
			
			Wend
		
		Endif
		
		'Copy dodgy module data imports...
		For Local p:=Eachin app.fileImports
			Local r:=StripDir( p )
			Local t:=dir+"/"+r
			If MatchPath( r,DATA_FILES )
				CCopyFile p,t
				udata.Insert t
				dataFiles.Set p,r
			Endif
		Next
		
		'Clean up...delete data in target project not in monkey project.
		If dataPath
		
			Local dsts:=New StringStack
			dsts.Push dir
			
			While Not dsts.IsEmpty()
				
				Local dst:=dsts.Pop()
				
				For Local f:=Eachin LoadDir( dst )
					If f.StartsWith( "." ) Continue
	
					Local p:=dst+"/"+f
					Local r:=p[dir.Length+1..]
					Local t:=dataPath+"/"+r
					
					Select FileType( p )
					Case FILETYPE_FILE
						If Not udata.Contains( p )
							DeleteFile p
						Endif
					Case FILETYPE_DIR
						If FileType( t )=FILETYPE_DIR
							dsts.Push p
						Else
							DeleteDir p,True
						Endif
					End
				Next
				
			Wend
		End
		
	End
	
End