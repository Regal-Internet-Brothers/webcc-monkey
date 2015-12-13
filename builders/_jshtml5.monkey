
Import builder

Class Html5Builder Extends Builder

	Method New( tcc:TransCC )
		Super.New( tcc )
	End
	
	Method Config:String()
		Local config:=New StringStack
		
		For Local kv:=Eachin GetConfigVars()
			config.Push "CFG_"+kv.Key+"="+Enquote( kv.Value,"js" )+";"
		Next
		
		Return config.Join( "~n" )
	End
	
	Method MetaData:String()
		Return ""
	End
	
	Method IsValid:Bool()
		Return True
	End
	
	Method Begin:Void()
		ENV_LANG="js"
		_trans=New JsTranslator
	End
	
	Method MakeTarget:Void()

		CreateDataDir "data"

		Local meta:="var META_DATA=~q"+MetaData()+"~q;~n"
		
		Local main:=LoadString( "main.js" )
		
		main=ReplaceBlock( main,"TRANSCODE",transCode )
		main=ReplaceBlock( main,"METADATA",meta )
		main=ReplaceBlock( main,"CONFIG",Config() )
		
		SaveString main,"main.js"
		
		If tcc.opt_run
			Local p:=RealPath( "MonkeyGame.html" )
			Local t:=tcc.HTML_PLAYER+" ~q"+p+"~q"
			Execute t,False
		Endif
	End
	
End