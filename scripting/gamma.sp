#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <gamma>

// DHooks not required, but recommended
#undef REQUIRE_EXTENSIONS
#include <dhooks>
#define REQUIRE_EXTENSIONS


/**
 *	Gamma is made to easily develop game modes that can coexist with other game modes,
 *	but also to be easily extended by third parties, by creating new behaviours or 
 *	whatever they could think of.
 *	
 *	A behaviour is a type of plugin that changes how player interacts with the game,
 *	they are attached to, possessing, players (should i start calling them curses i wonder?).
 *	They are allowed to change what they want about the player, but only when they are
 *	possessing a player - which only the game mode can decide whether they do or not.
 *	
 *	In order for a behaviour to be created it needs a Behaviour Type, which explains
 *	to gamma certain function requirements that the behaviour needs in order to
 *	be valid. An example could be a game mode like VSH/FF2, which needs to know
 *	how much health a boss gets - and could thus place a requirement for the function
 *	"GetBossMaxHealth" to be implemented, unfortunately it's not possible to set the
 *	return and parameter types for the requirement, but an include which defines a
 *	forward like so "forward GetBossMaxHealth(enemyCount)".
 *
 *	So, what creates a behaviour type? A game mode does, only a game mode can create
 *	behaviour types - and it can only create behaviour types for itself.
 *	A game mode modifies the game to play how it wants the game to be, it gives and takes
 *	behaviours (CURSES!) to and from players and scrambles teams to be however it likes
 *	AND NOTHING CAN STOP IT (except for limitations, we all love limitations don't we?).
 *
 *	Gamma was written in roughly 2 days - and hasn't been tested, but hey, it compiles!
 *	There are some thing I would like to have different, but ehh, how to say it, I don't
 *	have the tools needed nor do I have a test server yet, so yeah.
 *	Search for TODO:'s (Actually not that many of them)
 *
 *	And one final thing, GameMode, BehaviourType and Behaviour's aren't validated that often
 *	in any way, but are assumed to be proper instances where expected, should probably at
 *	least throw some errors if they receive INVALID_GAME_MODE, INVALID_BEHAVIOUR_TYPE or
 *	INVALID_BEHAVIOUR instead of causing more incomprehensible errors.
 */

#define PLUGIN_VERSION "0.3 alpha"

public Plugin:myinfo = 
{
	name = "Gamma",
	author = "Cookies.net",
	description = "Manages game modes written against the plugin and makes it easier to extend game modes",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
};



/*******************************************************************************
 *	DEFINITIONS
 *******************************************************************************/

#define PROPERTY_PREFIX "Prop_"
#define PROPERTY_PREFIX_LENGTH 5


/*******************************************************************************
 *	MISC DEFINITIONS
 *******************************************************************************/

// Maximum length of a symbol in SourcePawn including the NULL terminator
#define SYMBOL_MAX_LENGTH 64

// Decreasing loop macro (using decreasing loops a lot, likely to make a mistake (forgetting -1))
// Usage: DECREASING_LOOP(indexer,size)
#define DECREASING_LOOP(%1,%2) for (new %1 = %2-1; %1 >= 0; %1--)


// The almight important DEBUG_PRINTx's
// set DEBUG to 1 for PrintToServer, 2 for LogMessageEx or 0 for no debug messages
#define DEBUG 1

#if defined DEBUG && DEBUG == 1
#define DEBUG_PRINT0(%1) PrintToServer(%1)
#define DEBUG_PRINT1(%1,%2) PrintToServer(%1,%2)
#define DEBUG_PRINT2(%1,%2,%3) PrintToServer(%1,%2,%3)
#define DEBUG_PRINT3(%1,%2,%3,%4) PrintToServer(%1,%2,%3,%4)
#define DEBUG_PRINT4(%1,%2,%3,%4,%5) PrintToServer(%1,%2,%3,%4,%5)
#define DEBUG_PRINT5(%1,%2,%3,%4,%5,%6) PrintToServer(%1,%2,%3,%4,%5,%6)
#define DEBUG_PRINT6(%1,%2,%3,%4,%5,%6,%7) PrintToServer(%1,%2,%3,%4,%5,%6,%7)
#elseif defined DEBUG && DEBUG == 2
#define DEBUG_PRINT0(%1) LogMessageEx(%1)
#define DEBUG_PRINT1(%1,%2) LogMessageEx(%1,%2)
#define DEBUG_PRINT2(%1,%2,%3) LogMessageEx(%1,%2,%3)
#define DEBUG_PRINT3(%1,%2,%3,%4) LogMessageEx(%1,%2,%3,%4)
#define DEBUG_PRINT4(%1,%2,%3,%4,%5) LogMessageEx(%1,%2,%3,%4,%5)
#define DEBUG_PRINT5(%1,%2,%3,%4,%5,%6) LogMessageEx(%1,%2,%3,%4,%5,%6)
#define DEBUG_PRINT6(%1,%2,%3,%4,%5,%6,%7) LogMessageEx(%1,%2,%3,%4,%5,%6,%7)
#else
#define DEBUG_PRINT0(%1)
#define DEBUG_PRINT1(%1,%2)
#define DEBUG_PRINT2(%1,%2,%3)
#define DEBUG_PRINT3(%1,%2,%3,%4)
#define DEBUG_PRINT4(%1,%2,%3,%4,%5)
#define DEBUG_PRINT5(%1,%2,%3,%4,%5,%6)
#define DEBUG_PRINT6(%1,%2,%3,%4,%5,%6,%7)
#endif

// Verbosity of the added target filters
enum TargetFilterVerbosity
{
	TargetFilterVerbosity_None,
	TargetFilterVerbosity_BehaviourTypeOnly,
	TargetFilterVerbosity_BehaviourTypesAndBehaviours
}


/*******************************************************************************
 *	GLOBAL VARIABLES
 *******************************************************************************/

// Which engine version?
new EngineVersion:g_eEngineVersion;

// Known plugins, used to auto detect new plugins
new Handle:g_hArrayKnownPlugins;

// State variable (used to have 3 here!)
new bool:g_bIsActive;	// Is gamma active?

// Target filter verbosity
new TargetFilterVerbosity:g_eTargetFilterVerbosity;	// Verbosity of target filters added (none, behaviour types only or behaviour types and behaviours)

// Cvars
new Handle:g_hCvarEnabled;	// gamma_enabled "<0|1>"
new Handle:g_hCvarGameMode;	// gamma_gamemode "gamemode name"

// Game mode selection method, 1=strictly by cvar, 2=first able to start, 3=by cvar but if it can't start then the first able to start
new Handle:g_hCvarGameModeSelectionMode;	// gamma_gamemode_selection_mode "<1|2|3>"

// Target filters verbosity, 0=no target filters, 1=behaviour type filters, 2=behaviour type and behaviour target filters
new Handle:g_hCvarTargetFilters;	// gamma_target_filters "<0|1|2>"

// Extension state variables
new bool:g_bDHooksAvailable;


/*******************************************************************************
 *	GAME SPECIFIC INCLUDES
 *******************************************************************************/

// These do stuff specfic for a game!
#include "gamma-games/game-common.sp"
#include "gamma-games/game-tf.sp"
#include "gamma-games/game-cs.sp"


/*******************************************************************************
 *	THE IMPORTANT BITS OF GAMMA INCLUDES
 *******************************************************************************/

 #include "gamma/game-mode.sp"
 #include "gamma/behaviour-type.sp"
 #include "gamma/behaviour.sp"
 #include "gamma/iterators.sp"


/*******************************************************************************
 *	PLUGIN LOAD
 *******************************************************************************/

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegisterGameModeNatives();
	RegisterBehaviourTypeNatives();
	RegisterBehaviourNatives();
	RegisterIteratorNatives();

	// Special natives
	CreateNative("__GAMMA_PluginUnloading", Native__GAMMA_PluginUnloading);

	RegPluginLibrary("gamma");
	return APLRes_Success;
}

public OnPluginStart()
{
	// Check if our optional extensions are available (dhooks only atm)
	g_bDHooksAvailable = LibraryExists("dhooks");

	g_eEngineVersion = GetEngineVersion();

	// Load game data, it selects which game to use it self based on above detection
	LoadGameData();

	// Initialize our global (sorta) variables
	GameMode_OnPluginStart();
	BehaviourType_OnPluginStart();
	Behaviour_OnPluginStart();

	// State variables
	g_bIsActive = false;

	// Version cvar
	CreateConVar("gamma_version", PLUGIN_VERSION, "Version of Gamma Game Mode Manager", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD|FCVAR_PLUGIN);
	
	// Cvars
	g_hCvarEnabled = CreateConVar("gamma_enabled", "1", "Whether or not gamma is enabled (0|1)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hCvarGameMode = CreateConVar("gamma_gamemode", "", "Name of the game mode to play", FCVAR_PLUGIN);
	g_hCvarGameModeSelectionMode = CreateConVar("gamma_gamemode_selection_mode", "3", "Game mode selection method, 1=Strictly by cvar, 2=First able to start, 3=Attempt by cvar then first able to start", FCVAR_PLUGIN, true, 1.0, true, 3.0);
	g_hCvarTargetFilters = CreateConVar("gamma_target_filters", "1", "Target filter verbosity, 0=No target filters, 1=Behaviour type only filters, 2=Behaviour type and behaviour filters", FCVAR_PLUGIN, true, 0.0, true, 2.0);

	// Commands
	RegAdminCmd("gamma_list_gamemodes", Command_ListGameModes, ADMFLAG_GENERIC, "Lists all game modes installed", "Gamma");
	RegAdminCmd("gamma_list_behaviour_types", Command_ListBehaviourTypes, ADMFLAG_GENERIC, "Lists all behaviour types for a game mode", "Gamma");
	RegAdminCmd("gamma_list_behaviours", Command_ListBehaviours, ADMFLAG_GENERIC, "Lists all behaviours for a behaviour type", "Gamma");

	// Make sure all player data is initialized for currently ingame players
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}

	AutoExecConfig(true, "gamma");
}

public OnAllPluginsLoaded()
{
	GameMode_OnAllPluginsLoaded();
	Behaviour_OnAllPluginsLoaded();
}

public OnPluginEnd()
{
	StopGameMode(GameModeEndReason_ForceStopped);

	// Destroy all game modes when the plugin ends,
	// cleans up all plugins tied to them as well,
	// so no need to destroy behaviours manually
	DECREASING_LOOP(i,GetGameModeCount())
	{
		new GameMode:gameMode = GetGameMode(i);
		DestroyGameMode(gameMode);
	}
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "dhooks"))
	{
		// Oh snap, we lost dhooks! Clean up the hooks! Load the game data! Setup our new hooks!
		g_bDHooksAvailable = false;
		CleanUpOnMapEnd();
		LoadGameData();
		SetupOnMapStart();
	}
}



/*******************************************************************************
 *	COMMANDS
 *******************************************************************************/

public Action:Command_ListGameModes(client, args)
{
	new count = GetGameModeCount();
	if (count == 0)
	{
		PrintToConsole(client, "No game modes installed");
	}
	else
	{
		new String:gameModeName[GAME_MODE_NAME_MAX_LENGTH];
		for (new i = 0; i < count; i++)
		{
			new GameMode:gameMode = GetGameMode(i);
			GetGameModeName(gameMode, gameModeName, sizeof(gameModeName));
			PrintToConsole(client, "[%02.2i] : %s", i, gameModeName);
		}
	}
	return Plugin_Handled;
}

public Action:Command_ListBehaviourTypes(client, args)
{
	if (args < 1)
	{
		PrintToConsole(client, "Usage: gamma_list_behaviour_types <game mode name/index>");
	}
	else
	{
		new String:arg1[GAME_MODE_NAME_MAX_LENGTH];
		GetCmdArg(1, arg1, sizeof(arg1));

		new GameMode:gameMode = INVALID_GAME_MODE;

		// Attempt to find the game mode
		new index;
		if (StringToIntEx(arg1, index))
		{
			new count = GetGameModeCount();
			if (index >= 0 && index < count)
			{
				gameMode = GetGameMode(index);
			}
		}
		if (gameMode == INVALID_GAME_MODE)
		{
			gameMode = FindGameMode(arg1);
		}

		if (gameMode == INVALID_GAME_MODE)
		{
			PrintToConsole(client, "Game mode with name or index %s does not exist", arg1);
		}
		else
		{
			// Get game mode behaviour types and print them, if there's any
			new Handle:behaviourTypes = GetGameModeBehaviourTypes(gameMode);
			new count = GetArraySize(behaviourTypes);
			if (count == 0)
			{
				GetGameModeName(gameMode, arg1, sizeof(arg1));
				PrintToConsole(client, "Game mode %s does not have any behaviour types", arg1);
			}
			else
			{
				new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
				for (new i = 0; i < count; i++)
				{
					new BehaviourType:behaviourType = GetArrayBehaviourType(behaviourTypes, i);

					GetBehaviourTypeName(behaviourType, behaviourTypeName, sizeof(behaviourTypeName));

					PrintToConsole(client, "  %s", behaviourTypeName);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action:Command_ListBehaviours(client, args)
{
	if (args < 1)
	{
		PrintToConsole(client, "Usage: gamma_list_behaviours <behaviour type name>");
	}
	else
	{
		new String:arg1[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
		GetCmdArg(1, arg1, sizeof(arg1));

		new BehaviourType:behaviourType = INVALID_BEHAVIOUR_TYPE;

		// Attempt to find the behaviour type
		if (behaviourType == INVALID_BEHAVIOUR_TYPE)
		{
			behaviourType = FindBehaviourType(arg1);
		}

		if (behaviourType == INVALID_BEHAVIOUR_TYPE)
		{
			PrintToConsole(client, "Behaviour type with name %s does not exist", arg1);
		}
		else
		{
			// Get behaviour type behaviours and print them, if there's any
			new Handle:behaviours = GetBehaviourTypeBehaviours(behaviourType);
			new count = GetArraySize(behaviours);
			if (count == 0)
			{
				GetBehaviourTypeName(behaviourType, arg1, sizeof(arg1));
				PrintToConsole(client, "Behaviour type %s does not have any behaviours", arg1);
			}
			else
			{
				new String:behaviourName[BEHAVIOUR_NAME_MAX_LENGTH];
				new String:behaviourFullName[BEHAVIOUR_FULL_NAME_MAX_LENGTH];
				for (new i = 0; i < count; i++)
				{
					new Behaviour:behaviour = GetArrayBehaviour(behaviours, i);

					GetBehaviourName(behaviour, behaviourName, sizeof(behaviourName));
					GetBehaviourFullName(behaviour, behaviourFullName, sizeof(behaviourFullName));

					PrintToConsole(client, "  %s (%s)", behaviourFullName, behaviourName);
				}
			}
		}
	}
	return Plugin_Handled;
}



/*******************************************************************************
 *	EVENTS
 *******************************************************************************/

public OnMapStart()
{
	// Check if dhooks was loaded during previous map, if it is, reload our game data
	if (!g_bDHooksAvailable && LibraryExists("dhooks"))
	{
		g_bDHooksAvailable = true;
		LoadGameData();
	}
	SetupOnMapStart();
}

public OnMapEnd()
{
	CleanUpOnMapEnd();
	StopGameMode(GameModeEndReason_RoundEnded);
}

public OnClientPutInServer(client)
{
	Behaviour_OnClientConnected(client);
}

public OnClientDisconnect(client)
{
	Behaviour_OnClientDisconnect(client);
}


/*******************************************************************************
 *	SPECIAL NATIVES
 *******************************************************************************/

public Native__GAMMA_PluginUnloading(Handle:plugin, numParams)
{
	DEBUG_PRINT0("native __GAMMA_PluginUnloading() : Start");

	GameMode_PluginUnloading(Handle:plugin);

	// It's not neccesary to look through BehaviourTypes since they're created by the game mode plugin
	// And will be destroyed when the game mode gets destroyed

	Behaviour_PluginUnloading(Handle:plugin);

	DEBUG_PRINT0("native __GAMMA_PluginUnloading() : End");
}



/*******************************************************************************
 *	GAME MODE/BEHAVIOUR TYPE/BEHAVIOUR HELPERS
 *******************************************************************************/

// Checks whether or not the input string contains illegal characters for a game mode/behaviour type/begaviour name
stock bool:ValidateName(const String:name[])
{
	new length = strlen(name);
	for(new i = 0; i < length; i++)
	{
		new char = name[i];
		if (!(IsCharAlpha(char) || IsCharNumeric(char) || char == '_'))
		{
			// Invalid name, names may only contains numbers, underscores and normal letters
			return false;
		}
	}
	// A name is, of course, only valid if it's 1 or more chars long, though longer is recommended
	return (length > 0);
}

// Converts a string to lower case
stock StringToLower(const String:input[], String:output[], size)
{
	for (new i = 0; i < size; i++)
	{
		if (IsCharUpper(input[i]))
		{
			output[i] = CharToLower(input[i]);
		}
		else
		{
			output[i] = input[i];
		}
	}
}

// Gets a trie value case insensitive (well, lower cased, meant to be used together with the 2 others)
stock bool:GetTrieValueCaseInsensitive(Handle:trie, const String:key[], &any:value)
{
	new length = strlen(key)+1;
	new String:trieKey[length];
	StringToLower(key, trieKey, length);
	return GetTrieValue(trie, trieKey, value);
}

// Sets a trie value case insensitive (well, lower cased, meant to be used together with the 2 others)
stock bool:SetTrieValueCaseInsensitive(Handle:trie, const String:key[], any:value)
{
	new length = strlen(key)+1;
	new String:trieKey[length];
	StringToLower(key, trieKey, length);
	return SetTrieValue(trie, trieKey, value);
}

// Removes a trie value case insensitive (well, lower cased, meant to be used together with the 2 others)
stock RemoveFromTrieCaseInsensitive(Handle:trie, const String:key[])
{
	new length = strlen(key)+1;
	new String:trieKey[length];
	StringToLower(key, trieKey, length);
	return RemoveFromTrie(trie, trieKey);
}




/*******************************************************************************
 *	INTERNAL WRAPPERS
 *******************************************************************************/

stock LoadGameData()
{
	// Load game data!
	new Handle:gc = LoadGameConfigFile("gamma.games");
	if (gc == INVALID_HANDLE)
	{
		SetFailState("Unable to load gamedata");
	}

	// Look for which game we should call LoadGameData on!
	switch (g_eEngineVersion)
	{
		case Engine_TF2:
		{
			LoadGameDataTF(gc);
		}
		case Engine_CSS, Engine_CSGO:
		{
			LoadGameDataCS(gc);
		}
		default:
		{
			LoadGameDataCommon(gc);
		}
	}

	CloseHandle(gc);
}

stock SetupOnMapStart()
{
	// Look for which game we should call SetupOnMapStart on!
	switch (g_eEngineVersion)
	{
		case Engine_TF2:
		{
			SetupTFOnMapStart();
		}
		case Engine_CSS, Engine_CSGO:
		{
			SetupCSOnMapStart();
		}
		default:
		{
			SetupCommonOnMapStart();
		}
	}
}

stock CleanUpOnMapEnd()
{
	// Look for which game we should call SetupOnMapStart on!
	switch (g_eEngineVersion)
	{
		case Engine_TF2:
		{
			CleanUpTFOnMapEnd();
		}
		case Engine_CSS, Engine_CSGO:
		{
			CleanUpCSOnMapEnd();
		}
		default:
		{
			CleanUpCommonOnMapEnd();
		}
	}
}

stock ForceRoundEnd()
{
	// Look for which game we should call ForceRoundEnd on!
	switch (g_eEngineVersion)
	{
		case Engine_TF2:
		{
			ForceRoundEndTF();
		}
		case Engine_CSS, Engine_CSGO:
		{
			ForceRoundEndCS();
		}
		default:
		{
			ForceRoundEndCommon();
		}
	}
}


/*******************************************************************************
 *	WRAPPERS
 *******************************************************************************/

// Calls an optional function in the targetted plugin, if it exists, without parameters
stock SimpleOptionalPluginCall(Handle:plugin, const String:function[], any:defaultValue=0, &error=0)
{
	new Function:func = GetFunctionByName(plugin, function);
	if(func != INVALID_FUNCTION)
	{
		new result;
		Call_StartFunction(plugin, func);
		error = Call_Finish(result);
		return result;
	}
	error = SP_ERROR_NONE;
	return defaultValue;
}

// Calls an optional function in the targetted plugin, if it exists, with 1 cell parameter
stock SimpleOptionalPluginCallOneParam(Handle:plugin, const String:function[], any:param, any:defaultValue=0, &error=0)
{
	new Function:func = GetFunctionByName(plugin, function);
	if(func != INVALID_FUNCTION)
	{
		new result;
		Call_StartFunction(plugin, func);
		Call_PushCell(param);
		error = Call_Finish(result);
		return result;
	}
	error = SP_ERROR_NONE;
	return defaultValue;
}

// Calls an optional function in the targetted plugin, if it exists, with 1 cell parameter
stock SimpleOptionalPluginCallTwoParams(Handle:plugin, const String:function[], any:param1, any:param2, any:defaultValue=0, &error=0)
{
	new Function:func = GetFunctionByName(plugin, function);
	if(func != INVALID_FUNCTION)
	{
		new result;
		Call_StartFunction(plugin, func);
		Call_PushCell(param1);
		Call_PushCell(param2);
		error = Call_Finish(result);
		return result;
	}
	error = SP_ERROR_NONE;
	return defaultValue;
}

// Calls a forward with a single cell parameter
stock SimpleForwardCallOneParam(Handle:fwd, any:param, &error=0)
{
	new result;
	Call_StartForward(fwd);
	Call_PushCell(param);
	error = Call_Finish(result);
	return result;
}

// Calls a forward with two cell parameters
stock SimpleForwardCallTwoParams(Handle:fwd, any:param1, any:param2, &error=0)
{
	new result;
	Call_StartForward(fwd);
	Call_PushCell(param1);
	Call_PushCell(param2);
	error = Call_Finish(result);
	return result;
}

// Calls a forward with three cell parameters
stock SimpleForwardCallThreeParams(Handle:fwd, any:param1, any:param2, any:param3, &error=0)
{
	new result;
	Call_StartForward(fwd);
	Call_PushCell(param1);
	Call_PushCell(param2);
	Call_PushCell(param3);
	error = Call_Finish(result);
	return result;
}

// Transfers ownership of the handle to the plugin, it closes the original handle
stock Handle:TransferHandleOwnership(Handle:handle, Handle:plugin)
{
	new Handle:temp = CloneHandle(handle, plugin);
	CloseHandle(handle);
	return temp;
}

