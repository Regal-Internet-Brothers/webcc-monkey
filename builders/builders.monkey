
' Imports:
Import webcc

Import jshtml5

' Functions:
Function Builders:StringMap<Builder>(WCC:WebCC)
	Local BuildMap:= New StringMap<Builder>()
	
	BuildMap.Set("html5", New Html5Builder(WCC))
	
	Return BuildMap
End
