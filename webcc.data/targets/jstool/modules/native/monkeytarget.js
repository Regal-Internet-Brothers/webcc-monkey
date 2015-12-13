
// This is called initially by the default template html-file.
// Don't bother if you intend to pass arguments with JavaScript or Monkey code.
function __monkey_jstool_exec()
{
	if (typeof CFG_JSTOOL_STANDALONE == 'undefined' || !CFG_JSTOOL_STANDALONE)
	{
		executeMonkey(null);
	}
}

// The following variables are global, and could be misleading under certain bootstrapping conditions.

// Constant variable(s):

// This is used to check if a 'jstool' program has been loaded.
var __monkey_jstool = true;

// Global variable(s) (Read only):

// This describes if a compiled Monkey program has been run at least once (Safely).
var __monkey_jstool_has_run_once = false;

// Functions:

// This begins the compiled Monkey program, using the arguments specified (If any).
function executeMonkey(appArgs)
{
	if ((typeof CFG_VIRTUALOS_IMPLEMENTED !== 'undefined') && __os_appargs != null)
	{
		__os_appargs = appArgs;
	}
	
	if (typeof CFG_CONFIG !== 'undefined' && CFG_CONFIG === "debug")
	{
		try
		{
			__monkey_begin();
		}
		catch( ex )
		{
			if (ex != null)
			{
				alert("EXCEPTION CAUGHT: " + ex + " (" + ex.fileName + ":" + ex.lineNumber + ")");
				
				throw ex;
			}
			
			return;
		}
	}
	else
	{
		__monkey_begin();
	}
	
	__monkey_jstool_has_run_once = true;
	
	return;
}

// Please call 'executeMonkey' instead of this.
function __monkey_begin()
{
	bbInit();
	bbMain();
	
	return;
}
