#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <gamma>



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
 *	have the tools needed nor do I have a test server, so yeah. Search for TODO:'s
 *
 *	And one final thing, GameMode, BehaviourType and Behaviour's aren't validated that often
 *	in any way, but are assumed to be proper instances where expected, should probably at
 *	least throw some errors if they receive INVALID_GAME_MODE, INVALID_BEHAVIOUR_TYPE or
 *	INVALID_BEHAVIOUR instead of causing more incomprehensible errors.
 */

#define PLUGIN_VERSION "0.1 alpha"

public Plugin:myinfo = 
{
	name = "Gamma",
	author = "Cookies.net",
	description = "Manages game modes written against the plugin and makes it easier to extend game modes",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
};



/*******************************************************************************
 *	TYPE DEFINITIONS
 *******************************************************************************/

#define PROPERTY_PREFIX "Prop_"
#define PROPERTY_PREFIX_LENGTH 5

/**
 *	GameMode
 *		Plugin : PluginHandle
 *		Name : String[GAME_MODE_NAME_MAX_LENGTH]
 *		BehaviourTypes : List<BehaviourType>
 */
#define GAME_MODE_PLUGIN "Plugin"
#define GAME_MODE_NAME "Name"
#define GAME_MODE_BEHAVIOUR_TYPES "BehaviourTypes"

/**
 *	BehaviourType
 *		Plugin : PluginHandle
 *		Owner : GameMode
 *		Name : String[BEHAVIOUR_TYPE_NAME_MAX_LENGTH]
 *		Requirements : List<FunctionName>
 *		Behaviours : List<Behaviour>
 */
#define BEHAVIOUR_TYPE_PLUGIN "Plugin"
#define BEHAVIOUR_TYPE_OWNER "Owner"
#define BEHAVIOUR_TYPE_NAME "Name"
#define BEHAVIOUR_TYPE_REQUIREMENTS "Requirements"
#define BEHAVIOUR_TYPE_BEHAVIOURS "Behaviours"

/**
 *	Behaviour
 *		Plugin : PluginHandle
 *		Type : BehaviourType
 *		Name : String[BEHAVIOUR_NAME_MAX_LENGTH]
 *		PossessedPlayers : List<client>
 */
#define BEHAVIOUR_PLUGIN "Plugin"
#define BEHAVIOUR_TYPE "Type"
#define BEHAVIOUR_NAME "Name"
#define BEHAVIOUR_POSSESSED_PLAYERS "PossessedPlayers"

// The maximum size of the full name of a behaviour
#define BEHAVIOUR_FULL_NAME_MAX_LENGTH BEHAVIOUR_TYPE_NAME_MAX_LENGTH+BEHAVIOUR_NAME_MAX_LENGTH

// Maximum length of a symbol in SourcePawn including the NULL terminator
#define SYMBOL_MAX_LENGTH 64

// Decreasing loop macro (using decreasing loops a lot, likely to make a mistake (forgetting -1))
// Usage: DECREASING_LOOP(indexer,adtarray)
#define DECREASING_LOOP(%1,%2) for (new %1 = GetArraySize(%2)-1; %1 >= 0; %1--)



/*******************************************************************************
 *	GLOBAL VARIABLES
 *******************************************************************************/

// Game modes data
new Handle:g_hArrayGameModes;				// List<GameMode>
new Handle:g_hTrieGameModes;				// Map<GameMode.Name, GameMode>

// Behaviour types data
new Handle:g_hArrayBehaviourTypes;			// List<BehaviourType>
new Handle:g_hTrieBehaviourTypes;			// Map<BehaviourType.Name, BehaviourType>

// Behaviour data
new Handle:g_hArrayBehaviours;				// List<Behaviour>
new Handle:g_hTrieBehaviours;				// Map<BehaviourType.Name+':'+Behaviour.Name, Behaviour>

// Client data
new Handle:g_hClientArrayBehaviours[MAXPLAYERS+1];					// List<Behaviour>[MAXPLAYERS+1]
new Handle:g_hClientPrivateBehaviourPlayerRunCmd[MAXPLAYERS+1]; 	// Forward[MAXPLAYERS+1]
new bool:g_bClientHasPrivateBehaviourPlayerRunCmd[MAXPLAYERS+1];	// bool[MAXPLAYERS+1]

// State variables
new bool:g_bIsActive;
new GameMode:g_hCurrentGameMode;
new Handle:g_hGameModePlugin;

// Global forwards
new Handle:g_hGlobalGameMode_OnCreated;				//	GameMode_OnCreated(GameMode:gameMode)
new Handle:g_hGlobalGameMode_OnDestroyed;			//	GameMode_OnDestroyed(GameMode:gameMode)

new Handle:g_hGlobalGameMode_OnStarted;				//	GameMode_OnStarted(GameMode:gameMode)
new Handle:g_hGlobalGameMode_OnEnded;				//	GameMode_OnEnded(GameMode:gameMode)

new Handle:g_hGlobalBehaviour_OnClientPossessed;	//	Behaviour_OnClientPossessed(client, Behaviour:behaviour)
new Handle:g_hGlobalBehaviour_OnClientReleased;		//	Behaviour_OnClientReleased(client, Behaviour:behaviour)

// Cvars
new Handle:g_hCvarEnabled;					// gamma_enabled "<0|1>"
new Handle:g_hCvarGameMode;					// gamma_gamemode "gamemode name"

// Game mode selection method, 1=strictly by cvar, 2=first able to start, 3=by cvar but if it can't start then the first able to start
new Handle:g_hCvarGameModeSelectionMode;	// gamma_gamemode_selection_mode "<1|2|3>" 



/*******************************************************************************
 *	PLUGIN LOAD
 *******************************************************************************/

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	// Misc natives
	CreateNative("GetAllGameModes", Native_GetAllGameModes);
	CreateNative("GameMode_GetCurrent", Native_GameMode_GetCurrent);

	// Game mode natives
	CreateNative("RegisterGameMode", Native_RegisterGameMode);
	CreateNative("GameMode_GetAllBehaviourTypes", Native_GameMode_GetAllBehaviourTypes);
	CreateNative("GameMode_AddBehaviourType", Native_GameMode_AddBehaviourType);
	CreateNative("GameMode_GiveBehaviour", Native_GameMode_GiveBehaviour);
	CreateNative("GameMode_TakeBehaviour", Native_GameMode_TakeBehaviour);
	// TODO: Add native to forcefully end the game mode?

	// Behaviour type natives
	CreateNative("CreateBehaviourType", Native_CreateBehaviourType);
	CreateNative("FindBehaviourType", Native_FindBehaviourType);
	CreateNative("BehaviourType_GetName", Native_BehaviourType_GetName);
	CreateNative("BehaviourType_AddRequirement", Native_BehaviourType_AddRequirement);
	CreateNative("BehaviourType_GetAllBehaviours", Native_BehaviourType_GetAllBehaviours);

	// Behaviour natives
	CreateNative("RegisterBehaviour", Native_RegisterBehaviour);
	CreateNative("Behaviour_GetType", Native_Behaviour_GetType);
	CreateNative("Behaviour_GetName", Native_Behaviour_GetName);

	// Game mode properties natives
	CreateNative("GameMode_SetPropertyValue", Native_GameMode_SetPropertyValue);
	CreateNative("GameMode_SetPropertyArray", Native_GameMode_SetPropertyArray);
	CreateNative("GameMode_SetPropertyString", Native_GameMode_SetPropertyString);
	CreateNative("GameMode_GetPropertyValue", Native_GameMode_GetPropertyValue);
	CreateNative("GameMode_GetPropertyArray", Native_GameMode_GetPropertyArray);
	CreateNative("GameMode_GetPropertyString", Native_GameMode_GetPropertyString);

	// Behaviour properties natives
	CreateNative("Behaviour_SetPropertyValue", Native_Behaviour_SetPropertyValue);
	CreateNative("Behaviour_SetPropertyArray", Native_Behaviour_SetPropertyArray);
	CreateNative("Behaviour_SetPropertyString", Native_Behaviour_SetPropertyString);
	CreateNative("Behaviour_GetPropertyValue", Native_Behaviour_GetPropertyValue);
	CreateNative("Behaviour_GetPropertyArray", Native_Behaviour_GetPropertyArray);
	CreateNative("Behaviour_GetPropertyString", Native_Behaviour_GetPropertyString);

	// Special natives
	CreateNative("__GAMMA_PluginUnloading", Native__GAMMA_PluginUnloading);

	RegPluginLibrary("gamma");
	return APLRes_Success;
}

public OnPluginStart()
{
	// Game mode data initialization
	g_hArrayGameModes = CreateArray();
	g_hTrieGameModes = CreateTrie();

	// Bhevaiour type data initialization
	g_hArrayBehaviourTypes = CreateArray();
	g_hTrieBehaviourTypes = CreateTrie();

	// Behaviour data
	g_hArrayBehaviours = CreateArray();

	// Global forwards
	g_hGlobalGameMode_OnCreated = CreateGlobalForward("GameMode_OnCreated", ET_Ignore, Param_Cell);
	g_hGlobalGameMode_OnDestroyed = CreateGlobalForward("GameMode_OnDestroyed", ET_Ignore, Param_Cell);

	g_hGlobalGameMode_OnStarted = CreateGlobalForward("GameMode_OnStarted", ET_Ignore, Param_Cell);
	g_hGlobalGameMode_OnEnded = CreateGlobalForward("GameMode_OnEnded", ET_Ignore, Param_Cell);

	g_hGlobalBehaviour_OnClientPossessed = CreateGlobalForward("Behaviour_OnClientPossessed", ET_Ignore, Param_Cell, Param_Cell);
	g_hGlobalBehaviour_OnClientReleased = CreateGlobalForward("Behaviour_OnClientReleased", ET_Ignore, Param_Cell, Param_Cell);

	// State variable initialization
	g_bIsActive = false;
	g_hCurrentGameMode = INVALID_GAME_MODE;
	g_hGameModePlugin = INVALID_HANDLE;

	// Cvars
	g_hCvarEnabled = CreateConVar("gamma_enabled", "1", "Whether or not gamma is enabled (0|1)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hCvarGameMode = CreateConVar("gamma_gamemode", "", "Name of the game mode to play", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hCvarGameModeSelectionMode = CreateConVar("gamma_gamemode_selection_mode", "3", "Game mode selection method, 1=strictly by cvar, 2=first able to start, 3=by cvar but if it can't start then the first able to start", FCVAR_PLUGIN, true, 1.0, true, 3.0);

	// Version cvar
	CreateConVar("gamma_version", PLUGIN_VERSION, "Version of Gamma Game Mode Manager", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD|FCVAR_PLUGIN);

	// Event hooks
	// TODO: Hook GameRules::RoundRespawn for round start and something else for round end
	// Also, these events can be changed to fit a specific game
	HookEvent("teamplay_round_start", Event_RoundStart); // <- This should be replaced by a hook onto GameRules::RoundRespawn
	HookEvent("teamplay_round_win", Event_RoundEnd); // <- Could be placed in GameRules::RoundRespawn as well, at the top but there are other options as well
}

public OnPluginEnd()
{
	StopGameMode(true);
}




/*******************************************************************************
 *	EVENTS
 *******************************************************************************/

public OnMapEnd()
{
	StopGameMode(false);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	ChooseAndStartGameMode();
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	StopGameMode(false);
}

public OnClientPutInServer(client)
{
	g_hClientArrayBehaviours[client] = CreateArray();
	g_hClientPrivateBehaviourPlayerRunCmd[client] = CreateForward(ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_Array);
	g_bClientHasPrivateBehaviourPlayerRunCmd[client] = false;
}

public OnClientDisconnect(client)
{
	CloseHandle(g_hClientArrayBehaviours[client]);
	CloseHandle(g_hClientPrivateBehaviourPlayerRunCmd[client]);

	g_hClientArrayBehaviours[client] = INVALID_HANDLE;
	g_hClientPrivateBehaviourPlayerRunCmd[client] = INVALID_HANDLE;
	g_bClientHasPrivateBehaviourPlayerRunCmd[client] = false;
}

// TODO: Changing this into using DHooks with a stock to register it in the behaviours would probably be more optimal, performance considered
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	if (!g_bIsActive)
	{
		return Plugin_Continue;
	}

	if (g_bClientHasPrivateBehaviourPlayerRunCmd[client])
	{
		Call_StartForward(g_hClientPrivateBehaviourPlayerRunCmd[client]);
		Call_PushCell(client);
		Call_PushCellRef(buttons);
		Call_PushCellRef(impulse);
		Call_PushArray(vel, sizeof(vel));
		Call_PushArray(angles, sizeof(angles));
		Call_PushCellRef(weapon);
		Call_PushCellRef(subtype);
		Call_PushCellRef(cmdnum);
		Call_PushCellRef(tickcount);
		Call_PushCellRef(seed);
		Call_PushArray(mouse, sizeof(mouse));

		new Action:result;
		Call_Finish(result);

		return result;
	}
	return Plugin_Continue;
}


/*******************************************************************************
 *	EVENT HELPERS
 *******************************************************************************/

stock StopGameMode(bool:forceful)
{
	if (g_hCurrentGameMode != INVALID_GAME_MODE)
	{
		SimpleOptionalPluginCall(g_hGameModePlugin, "GameMode_OnEnd");
		SimpleForwardCallOneCell(g_hGlobalGameMode_OnEnded, g_hCurrentGameMode);

		g_hCurrentGameMode = INVALID_GAME_MODE;
		g_hGameModePlugin = INVALID_HANDLE;

		// Release all clients from their behaviours (curses!)
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				new Handle:behaviours = g_hClientArrayBehaviours[i];
				DECREASING_LOOP(j,behaviours)
				{
					BehaviourReleasePlayer(GetArrayBehaviour(behaviours, j), i);
				}
			}
		}

		g_bIsActive = false;
	}
}

stock ChooseAndStartGameMode()
{
	if (GetConVarBool(g_hCvarEnabled))
	{
		new String:gameModeName[GAME_MODE_NAME_MAX_LENGTH];
		GetConVarString(g_hCvarGameMode, gameModeName, sizeof(gameModeName));

		new gameModeSelectionMode = GetConVarInt(g_hCvarGameModeSelectionMode);

		switch (gameModeSelectionMode)
		{
			// Strictly by Cvar
			case 1:
			{
				AttemptStart(FindGameMode(gameModeName));
			}
			// First game mode able to start
			case 2:
			{
				AttemptStartAny();
			}
			// Try cvar, if it fails then first to start
			case 3:
			{
				if (!AttemptStart(FindGameMode(gameModeName)))
				{
					AttemptStartAny();
				}
			}
		}
	}
}

stock AttemptStartAny()
{
	new count = GetArraySize(g_hArrayGameModes);
	for (new i = 0; i < count; i++)
	{
		new GameMode:gameMode = GetArrayGameMode(g_hArrayGameModes, i);
		if (AttemptStart(gameMode))
		{
			break;
		}
	}
}

stock bool:AttemptStart(GameMode:gameMode)
{
	if (gameMode != INVALID_GAME_MODE)
	{
		new Handle:gameModePlugin = GetGameModePlugin(gameMode);

		new bool:canStart = bool:SimpleOptionalPluginCallReturnCell(gameModePlugin, "GameMode_OnCanStart", true);
		if (canStart)
		{
			g_hCurrentGameMode = gameMode;
			g_hGameModePlugin = gameModePlugin;

			SimpleOptionalPluginCall(gameModePlugin, "GameMode_OnStart");
			SimpleForwardCallOneCell(g_hGlobalGameMode_OnStarted, gameMode);

			g_bIsActive = true;
			return true;
		}
	}
	return false;
}




/*******************************************************************************
 *	SPECIAL NATIVES
 *******************************************************************************/

public Native__GAMMA_PluginUnloading(Handle:plugin, numParams)
{
	// Look through all game mode and destroy the game mode if the plugin created it
	DECREASING_LOOP(i,g_hArrayGameModes)
	{
		new GameMode:gameMode = GetArrayGameMode(g_hArrayGameModes, i);
		if (GetGameModePlugin(gameMode) == plugin)
		{
			// Stop the game mode if it's running and unloading (oh the horrors D:)
			if (gameMode == g_hCurrentGameMode)
			{
				StopGameMode(true);
			}
			DestroyGameMode(gameMode);
		}
	}

	// It's not neccesary to look through BehaviourTypes since they're created by the game mode plugin

	// Look through all behaviours and destroy if the behaviour is created by the plugin
	DECREASING_LOOP(i,g_hArrayBehaviours)
	{
		new Behaviour:behaviour = GetArrayBehaviour(g_hArrayBehaviours, i);
		if (GetBehaviourPlugin(behaviour) == plugin)
		{
			DestroyBehaviour(behaviour);
		}
	}
}




/*******************************************************************************
 *	MISC NATIVES
 *******************************************************************************/

public Native_GetAllGameModes(Handle:plugin, numParams)
{
	return _:CloneArray(g_hArrayGameModes);
}

public Native_GameMode_GetCurrent(Handle:plugin, numParams)
{
	return _:g_hCurrentGameMode;
}


/*******************************************************************************
 *	GAME MODE NATIVES
 *******************************************************************************/

public Native_RegisterGameMode(Handle:plugin, numParams)
{
	// Get the game mode name
	new String:buffer[GAME_MODE_NAME_MAX_LENGTH];
	GetNativeString(1, buffer, sizeof(buffer));

	// The plugin has already registered a game mode, fail
	// TODO: Should this be an error instead?
	new GameMode:gameMode = FindGameModeByPlugin(plugin);
	if (gameMode != INVALID_GAME_MODE)
	{
		return _:INVALID_GAME_MODE;
	}

	// If it already exists, fail
	// TODO: Should this be an error instead?
	gameMode = FindGameMode(buffer);
	if (gameMode != INVALID_GAME_MODE)
	{
		return _:INVALID_GAME_MODE;
	}

	// Else create a new game mode
	return _:CreateGameMode(plugin, buffer);
}

public Native_GameMode_GetAllBehaviourTypes(Handle:plugin, numParams)
{
	new GameMode:gameMode = GameMode:GetNativeCell(1);
	new Handle:behaviourTypes = GameMode_GetAllBehaviourTypes(gameMode);
	return _:CloneArray(behaviourTypes);
}

public Native_GameMode_AddBehaviourType(Handle:plugin, numParams)
{
	new GameMode:gameMode = GameMode:GetNativeCell(1);
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(2);

	// If the game mode plugin and behaviour type plugin isn't the same plugin, it's not possible to add it
	if (GetGameModePlugin(gameMode) != GetBehaviourTypePlugin(behaviourType))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "A behaviour type can only be added by the owning game mode plugin");
	}

	AddBehaviourType(gameMode, behaviourType);
	return 1;
}

public Native_GameMode_GiveBehaviour(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new Behaviour:behaviour = Behaviour:GetNativeCell(2);

	if (g_hGameModePlugin != plugin)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Only the currently active game mode plugin can call GameMode_GiveBehaviour");
	}
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	} 
	if (!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);
	}

	BehaviourPossessPlayer(behaviour, client);
	return 1;
}

public Native_GameMode_TakeBehaviour(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new Behaviour:behaviour = Behaviour:GetNativeCell(2);

	if (g_hGameModePlugin != plugin)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Only the currently active game mode plugin can call GameMode_TakeBehaviour");
	}
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	} 
	if (!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);
	}

	BehaviourReleasePlayer(behaviour, client);
	return 1;
}


/*******************************************************************************
 *	BEHAVIOUR TYPE NATIVES
 *******************************************************************************/

public Native_CreateBehaviourType(Handle:plugin, numParams)
{
	new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
	GetNativeString(1, behaviourTypeName, sizeof(behaviourTypeName));

	// If we find a behaviour type with the same name, we can't use this name
	// TODO: Should this be an error instead?
	if (Internal_FindBehaviourType(behaviourTypeName) != INVALID_BEHAVIOUR_TYPE)
	{
		return _:INVALID_BEHAVIOUR_TYPE;
	}

	// Else we create a new behaviour type with that name
	return _:Internal_CreateBehaviourType(plugin, behaviourTypeName);
}

public Native_FindBehaviourType(Handle:plugin, numParams)
{
	new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
	GetNativeString(1, behaviourTypeName, sizeof(behaviourTypeName));

	return _:Internal_FindBehaviourType(behaviourTypeName);
}

public Native_BehaviourType_GetName(Handle:plugin, numParams)
{
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(1);

	new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
	GetBehaviourTypeName(behaviourType, behaviourTypeName, sizeof(behaviourTypeName));

	SetNativeString(2, behaviourTypeName, GetNativeCell(3));
}

public Native_BehaviourType_AddRequirement(Handle:plugin, numParams)
{
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(1);
	new String:functionName[SYMBOL_MAX_LENGTH];
	GetNativeString(2, functionName, sizeof(functionName));

	// Requirements can only be added before the behaviour type is added to a game mode
	if (GetBehaviourTypeOwner(behaviourType) != INVALID_GAME_MODE)
	{
		new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
		GetBehaviourTypeName(behaviourType, behaviourTypeName, sizeof(behaviourTypeName));

		return ThrowNativeError(SP_ERROR_NATIVE, "The behaviour type (%s) is already associated with a game mode", behaviourTypeName);
	}

	// If it's not added to a game mode add the requirement to the behaviour type
	AddBehaviourTypeRequirement(behaviourType, functionName);
	return 1;
}

public Native_BehaviourType_GetAllBehaviours(Handle:plugin, numParams)
{
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(1);
	return _:CloneArray(GetBehaviourTypeBehaviours(behaviourType));
}


/*******************************************************************************
 *	BEHAVIOUR NATIVES
 *******************************************************************************/

public Native_RegisterBehaviour(Handle:plugin, numParams)
{
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(1);
	new String:behaviourName[BEHAVIOUR_NAME_MAX_LENGTH];
	GetNativeString(2, behaviourName, sizeof(behaviourName));

	// A behaviour can only be registered if there's no behaviour with the same name and behaviour type
	// TODO: Should this throw an error?
	if (FindBehaviour(behaviourType, behaviourName) != INVALID_BEHAVIOUR)
	{
		return _:INVALID_BEHAVIOUR;
	}

	// If it's unique, create the behaviour
	return _:CreateBehaviour(plugin, behaviourType, behaviourName);
}

public Native_Behaviour_GetType(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);
	return _:GetBehaviourType(behaviour);
}

public Native_Behaviour_GetName(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);
	new String:behaviourName[BEHAVIOUR_NAME_MAX_LENGTH];
	GetBehaviourName(behaviour, behaviourName, sizeof(behaviourName));

	SetNativeString(2, behaviourName, GetNativeCell(3));
}


/*******************************************************************************
 *	GAME MODE PROPERTIES NATIVES
 *******************************************************************************/

public Native_GameMode_SetPropertyValue(Handle:plugin, numParams)
{
	new GameMode:gameMode = GameMode:GetNativeCell(1);

	// Get the property string length and then the property string
	new propertyLength;
	GetNativeStringLength(2, propertyLength);
	propertyLength = PROPERTY_PREFIX_LENGTH + propertyLength + 1;

	new String:property[propertyLength];
	GetNativeString(2, property, propertyLength);

	// Mustn't forget the property prefix
	Format(property, propertyLength, "%s%s", PROPERTY_PREFIX, property);

	// Then call SetTrieValue
	SetTrieValue(Handle:gameMode, property, GetNativeCell(3));
}

public Native_GameMode_SetPropertyArray(Handle:plugin, numParams)
{
	new GameMode:gameMode = GameMode:GetNativeCell(1);

	// Get the property string length and then the property string
	new propertyLength;
	GetNativeStringLength(2, propertyLength);
	propertyLength = PROPERTY_PREFIX_LENGTH + propertyLength + 1;

	new String:property[propertyLength];
	GetNativeString(2, property, propertyLength);

	// Mustn't forget the property prefix
	Format(property, propertyLength, "%s%s", PROPERTY_PREFIX, property);

	// Get the array length and array
	new arrayLength = GetNativeCell(4);
	new array[arrayLength];
	GetNativeArray(3, array, arrayLength);

	// Then call SetTrieArray
	SetTrieArray(Handle:gameMode, property, array, arrayLength);
}

public Native_GameMode_SetPropertyString(Handle:plugin, numParams)
{
	new GameMode:gameMode = GameMode:GetNativeCell(1);

	// Get the property string length and then the property string
	new propertyLength;
	GetNativeStringLength(2, propertyLength);
	propertyLength = PROPERTY_PREFIX_LENGTH + propertyLength + 1;

	new String:property[propertyLength];
	GetNativeString(2, property, propertyLength);

	// Mustn't forget the property prefix
	Format(property, propertyLength, "%s%s", PROPERTY_PREFIX, property);

	// Get the value length and string
	new stringLength;
	GetNativeStringLength(2, stringLength);

	new String:value[stringLength+1];
	GetNativeString(2, value, stringLength+1);

	// Then call SetTrieString
	SetTrieString(Handle:gameMode, property, value);
}

public Native_GameMode_GetPropertyValue(Handle:plugin, numParams)
{
	new GameMode:gameMode = GameMode:GetNativeCell(1);

	// Get the property string length and then the property string
	new propertyLength;
	GetNativeStringLength(2, propertyLength);
	propertyLength = PROPERTY_PREFIX_LENGTH + propertyLength + 1;

	new String:property[propertyLength];
	GetNativeString(2, property, propertyLength);

	// Mustn't forget the property prefix
	Format(property, propertyLength, "%s%s", PROPERTY_PREFIX, property);

	// Get the value from the trie
	new value;
	new bool:result = GetTrieValue(Handle:gameMode, property, value);

	// Set the third parameter to the value
	SetNativeCellRef(3, value);
	return _:result;
}

public Native_GameMode_GetPropertyArray(Handle:plugin, numParams)
{
	new GameMode:gameMode = GameMode:GetNativeCell(1);

	// Get the property string length and then the property string
	new propertyLength;
	GetNativeStringLength(2, propertyLength);
	propertyLength = PROPERTY_PREFIX_LENGTH + propertyLength + 1;

	new String:property[propertyLength];
	GetNativeString(2, property, propertyLength);

	// Mustn't forget the property prefix
	Format(property, propertyLength, "%s%s", PROPERTY_PREFIX, property);

	// Get the array from the trie
	new max_size = GetNativeCell(4);
	new array[max_size];
	new written;
	new bool:result = GetTrieArray(Handle:gameMode, property, array, max_size, written);

	// Set the native array and written parameters
	SetNativeArray(3, array, max_size);
	SetNativeCellRef(5, written);

	return _:result;
}

public Native_GameMode_GetPropertyString(Handle:plugin, numParams)
{
	new GameMode:gameMode = GameMode:GetNativeCell(1);

	// Get the property string length and then the property string
	new propertyLength;
	GetNativeStringLength(2, propertyLength);
	propertyLength = PROPERTY_PREFIX_LENGTH + propertyLength + 1;

	new String:property[propertyLength];
	GetNativeString(2, property, propertyLength);

	// Mustn't forget the property prefix
	Format(property, propertyLength, "%s%s", PROPERTY_PREFIX, property);

	// Get the string from the trie
	new max_size = GetNativeCell(4);
	new String:value[max_size];
	new written;
	new bool:result = GetTrieString(Handle:gameMode, property, value, max_size, written);

	// Set the native string and written parameters
	SetNativeString(3, value, max_size);
	SetNativeCellRef(5, written);

	return _:result;
}


/*******************************************************************************
 *	BEHAVIOUR PROPERTIES NATIVES
 *******************************************************************************/

public Native_Behaviour_SetPropertyValue(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);

	// Get the property string length and then the property string
	new propertyLength;
	GetNativeStringLength(2, propertyLength);
	propertyLength = PROPERTY_PREFIX_LENGTH + propertyLength + 1;

	new String:property[propertyLength];
	GetNativeString(2, property, propertyLength);

	// Mustn't forget the property prefix
	Format(property, propertyLength, "%s%s", PROPERTY_PREFIX, property);

	// Then call SetTrieValue
	SetTrieValue(Handle:behaviour, property, GetNativeCell(3));
}

public Native_Behaviour_SetPropertyArray(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);

	// Get the property string length and then the property string
	new propertyLength;
	GetNativeStringLength(2, propertyLength);
	propertyLength = PROPERTY_PREFIX_LENGTH + propertyLength + 1;

	new String:property[propertyLength];
	GetNativeString(2, property, propertyLength);

	// Mustn't forget the property prefix
	Format(property, propertyLength, "%s%s", PROPERTY_PREFIX, property);

	// Get the array length and array
	new arrayLength = GetNativeCell(4);
	new array[arrayLength];
	GetNativeArray(3, array, arrayLength);

	// Then call SetTrieArray
	SetTrieArray(Handle:behaviour, property, array, arrayLength);
}

public Native_Behaviour_SetPropertyString(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);

	// Get the property string length and then the property string
	new propertyLength;
	GetNativeStringLength(2, propertyLength);
	propertyLength = PROPERTY_PREFIX_LENGTH + propertyLength + 1;

	new String:property[propertyLength];
	GetNativeString(2, property, propertyLength);

	// Mustn't forget the property prefix
	Format(property, propertyLength, "%s%s", PROPERTY_PREFIX, property);

	// Get the value length and string
	new stringLength;
	GetNativeStringLength(2, stringLength);

	new String:value[stringLength+1];
	GetNativeString(2, value, stringLength+1);

	// Then call SetTrieString
	SetTrieString(Handle:behaviour, property, value);
}

public Native_Behaviour_GetPropertyValue(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);

	// Get the property string length and then the property string
	new propertyLength;
	GetNativeStringLength(2, propertyLength);
	propertyLength = PROPERTY_PREFIX_LENGTH + propertyLength + 1;

	new String:property[propertyLength];
	GetNativeString(2, property, propertyLength);

	// Mustn't forget the property prefix
	Format(property, propertyLength, "%s%s", PROPERTY_PREFIX, property);

	// Get the value from the trie
	new value;
	new bool:result = GetTrieValue(Handle:behaviour, property, value);

	// Set the third parameter to the value
	SetNativeCellRef(3, value);
	return _:result;
}

public Native_Behaviour_GetPropertyArray(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);

	// Get the property string length and then the property string
	new propertyLength;
	GetNativeStringLength(2, propertyLength);
	propertyLength = PROPERTY_PREFIX_LENGTH + propertyLength + 1;

	new String:property[propertyLength];
	GetNativeString(2, property, propertyLength);

	// Mustn't forget the property prefix
	Format(property, propertyLength, "%s%s", PROPERTY_PREFIX, property);

	// Get the array from the trie
	new max_size = GetNativeCell(4);
	new array[max_size];
	new written;
	new bool:result = GetTrieArray(Handle:behaviour, property, array, max_size, written);

	// Set the native array and written parameters
	SetNativeArray(3, array, max_size);
	SetNativeCellRef(5, written);

	return _:result;
}

public Native_Behaviour_GetPropertyString(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);

	// Get the property string length and then the property string
	new propertyLength;
	GetNativeStringLength(2, propertyLength);
	propertyLength = PROPERTY_PREFIX_LENGTH + propertyLength + 1;

	new String:property[propertyLength];
	GetNativeString(2, property, propertyLength);

	// Mustn't forget the property prefix
	Format(property, propertyLength, "%s%s", PROPERTY_PREFIX, property);

	// Get the string from the trie
	new max_size = GetNativeCell(4);
	new String:value[max_size];
	new written;
	new bool:result = GetTrieString(Handle:behaviour, property, value, max_size, written);

	// Set the native string and written parameters
	SetNativeString(3, value, max_size);
	SetNativeCellRef(5, written);

	return _:result;
}


/*******************************************************************************
 *	GAME MODE FUNCTIONS
 *******************************************************************************/

/**
 *	GameMode
 *		Plugin : PluginHandle
 *		Name : String[GAME_MODE_NAME_MAX_LENGTH]
 *		BehaviourTypes : List<BehaviourType>
 */

// Creates a game mode from a plugin and name
stock GameMode:CreateGameMode(Handle:plugin, const String:name[])
{
	// Create the trie to hold the data about the game mode
	new Handle:gameMode = CreateTrie();

	SetTrieValue(gameMode, GAME_MODE_PLUGIN, plugin);
	SetTrieString(gameMode, GAME_MODE_NAME, name);
	SetTrieValue(gameMode, GAME_MODE_BEHAVIOUR_TYPES, CreateArray());

	// Then push it to the global array and trie
	PushArrayCell(g_hArrayGameModes, gameMode);
	SetTrieValue(g_hTrieGameModes, name, gameMode);

	// Finally notify the game mode and other plugins about it's creation
	SimpleOptionalPluginCall(plugin, "GameMode_OnCreate");
	SimpleForwardCallOneCell(g_hGlobalGameMode_OnCreated, gameMode);

	return GameMode:gameMode;
}

// Finds a game mode from a plugin
stock GameMode:FindGameModeByPlugin(Handle:plugin)
{
	new count = GetArraySize(g_hArrayGameModes);
	for (new i = 0; i < count; i++)
	{
		new GameMode:gameMode = GetArrayGameMode(g_hArrayGameModes, i);
		if (GetGameModePlugin(gameMode) == plugin)
		{
			return gameMode;
		}
	}
	return INVALID_GAME_MODE;
}

// Finds a game mode from a name
stock GameMode:FindGameMode(const String:name[])
{
	new GameMode:gameMode;
	if (GetTrieValue(g_hTrieGameModes, name, gameMode))
	{
		return gameMode;
	}
	return INVALID_GAME_MODE;
}

// Gets the game mode at index
stock GameMode:GetArrayGameMode(Handle:array, index)
{
	return GameMode:GetArrayCell(array, index);
}

// Gets a game modes plugin, the one that registered the game mode
stock Handle:GetGameModePlugin(GameMode:gameMode)
{
	new Handle:plugin;
	if (GetTrieValue(Handle:gameMode, GAME_MODE_PLUGIN, plugin))
	{
		return plugin;
	}
	// Shouldn't actually get here, but we keep it just incase
	return INVALID_HANDLE;
}

// Gets the name of a game mode
stock bool:GetGameModeName(GameMode:gameMode, String:buffer[], maxlen)
{
	if (GetTrieString(Handle:gameMode, GAME_MODE_NAME, buffer, maxlen))
	{
		return true;
	}
	// Shouldn't actually get here, but we keep it just incase
	buffer[0] = '\0';
	return false;
}

// Adds a behaviour type to a game mode
stock AddBehaviourType(GameMode:gameMode, BehaviourType:behaviourType)
{
	// First we make sure that the behaviour type doesn't have an owner before adding it
	if (GetBehaviourTypeOwner(behaviourType) == INVALID_GAME_MODE)
	{
		new Handle:behaviourTypes = GetGameModeBehaviourTypes(gameMode);
		PushArrayCell(behaviourTypes, behaviourType);
		SetBehaviourTypeOwner(behaviourType, gameMode);
	}
}

// Gets an ADT array of all the behaviour types associated to a game mode
stock Handle:GetGameModeBehaviourTypes(GameMode:gameMode)
{
	new Handle:behaviourTypes;
	if (GetTrieValue(Handle:gameMode, GAME_MODE_BEHAVIOUR_TYPES, behaviourTypes))
	{
		return behaviourTypes;
	}
	// Shouldn't actually get here, but we keep it just incase
	return INVALID_HANDLE;
}

stock DestroyGameMode(GameMode:gameMode)
{
	// Call the Destroy listeners
	SimpleOptionalPluginCall(GetGameModePlugin(gameMode), "GameMode_OnDestroy");
	SimpleForwardCallOneCell(g_hGlobalGameMode_OnDestroyed, gameMode);

	// Remove from global array and trie
	RemoveFromArray(g_hArrayGameModes, FindValueInArray(g_hArrayGameModes, gameMode));

	new String:name[GAME_MODE_NAME_MAX_LENGTH];
	GetGameModeName(gameMode, name, sizeof(name));
	RemoveFromTrie(g_hTrieGameModes, name);

	// Destroy all associated behaviour types
	new Handle:behaviourTypes = GetGameModeBehaviourTypes(gameMode);
	DECREASING_LOOP(i,behaviourTypes)
	{
		new BehaviourType:behaviourType = GetArrayBehaviourType(behaviourTypes, i);
		DestroyBehaviourType(behaviourType);
	}

	// Lastly close the behaviour type array and the game mode trie
	CloseHandle(behaviourTypes);
	CloseHandle(Handle:gameMode);
}



/*******************************************************************************
 *	BEHAVIOUR TYPE FUNCTIONS
 *******************************************************************************/

/**
 *	BehaviourType
 *		Plugin : PluginHandle
 *		Owner : GameMode
 *		Name : String[BEHAVIOUR_TYPE_NAME_MAX_LENGTH]
 *		Requirements : List<FunctionName>
 *		Behaviours : List<Behaviour>
 */

// Creates a behaviour type from a plugin and name
stock BehaviourType:Internal_CreateBehaviourType(Handle:plugin, String:name[])
{
	// TODO: I need a better way of doing this - possibly I should make a native
	// which takes a game mode and a behaviour type name or something
	if (FindGameModeByPlugin(plugin) == INVALID_GAME_MODE)
	{
		return INVALID_BEHAVIOUR_TYPE;
	}

	// Create the trie to hold the behaviour type data
	new Handle:behaviourType = CreateTrie();

	SetTrieValue(behaviourType, BEHAVIOUR_TYPE_PLUGIN, plugin);
	SetTrieValue(behaviourType, BEHAVIOUR_TYPE_OWNER, INVALID_GAME_MODE);
	SetTrieString(behaviourType, BEHAVIOUR_TYPE_NAME, name);
	SetTrieValue(behaviourType, BEHAVIOUR_TYPE_REQUIREMENTS, CreateArray());
	SetTrieValue(behaviourType, BEHAVIOUR_TYPE_BEHAVIOURS, CreateArray());

	// Then push the new behaviour type to the global array and trie
	PushArrayCell(g_hArrayBehaviourTypes, behaviourType);
	SetTrieValue(g_hTrieBehaviourTypes, name, behaviourType);

	return BehaviourType:behaviourType;
}

// Searches for a behaviour type from a name
stock BehaviourType:Internal_FindBehaviourType(String:name[])
{
	new BehaviourType:behaviourType;
	if (GetTrieValue(g_hTrieBehaviourTypes, name, behaviourType))
	{
		return behaviourType;
	}
	return INVALID_BEHAVIOUR_TYPE;
}

// Gets the behaviour type at an index in an ADT array
stock BehaviourType:GetArrayBehaviourType(Handle:array, index)
{
	return BehaviourType:GetArrayCell(array, index);
}

// Gets the plugin that made the behaviour type
stock Handle:GetBehaviourTypePlugin(BehaviourType:behaviourType)
{
	new Handle:plugin;
	if (GetTrieValue(Handle:behaviourType, BEHAVIOUR_PLUGIN, plugin))
	{
		return plugin;
	}
	// Shouldn't actually get here, but we keep it just incase
	return INVALID_HANDLE;
}

// Gets the owner game mode of the behaviour type
stock GameMode:GetBehaviourTypeOwner(BehaviourType:behaviourType)
{
	new GameMode:owner;
	if (GetTrieValue(Handle:behaviourType, BEHAVIOUR_TYPE_OWNER, owner))
	{
		return owner;
	}
	// Shouldn't actually get here, but we keep it just incase
	return INVALID_GAME_MODE;
}

// Sets the owner game mode of the behaviour type if it doesn't have one yet
stock SetBehaviourTypeOwner(BehaviourType:behaviourType, GameMode:owner)
{
	if (GetBehaviourTypeOwner(behaviourType) == INVALID_GAME_MODE)
	{
		SetTrieValue(Handle:behaviourType, BEHAVIOUR_TYPE_OWNER, owner);
	}
}

// Gets the name of the behaviour type
stock bool:GetBehaviourTypeName(BehaviourType:behaviourType, String:buffer[], maxlen)
{
	if (GetTrieString(Handle:behaviourType, BEHAVIOUR_TYPE_NAME, buffer, maxlen))
	{
		return true;
	}
	// Shouldn't actually get here, but we keep it just incase
	buffer[0] = '\0';
	return false;
}

// Gets the ADT array with all the function requirements from the behaviour type
stock Handle:GetBehaviourTypeRequirements(BehaviourType:behaviourType)
{
	new Handle:requirements;
	if (GetTrieValue(Handle:behaviourType, BEHAVIOUR_TYPE_REQUIREMENTS, requirements))
	{
		return requirements;
	}
	// Shouldn't actually get here, but we keep it just incase
	return INVALID_HANDLE;
}

// Adds a function requirement to the behaviour, but only if there isn't an owner yet
stock bool:AddBehaviourTypeRequirement(BehaviourType:behaviourType, const String:requirement[])
{
	if (GetBehaviourTypeOwner(behaviourType) == INVALID_GAME_MODE)
	{
		PushArrayString(GetBehaviourTypeRequirements(behaviourType), requirement);
		return true;
	}
	return false;
}

// Checks if a plugin meets the requirements to be a behaviour of this type
stock bool:BehaviourTypePluginCheck(BehaviourType:behaviourType, Handle:plugin)
{
	new String:functionName[SYMBOL_MAX_LENGTH];

	new Handle:requirements = GetBehaviourTypeRequirements(behaviourType);
	new count = GetArraySize(requirements);
	for (new i = 0; i < count; i++)
	{
		GetArrayString(requirements, i, functionName, sizeof(functionName));
		if (GetFunctionByName(plugin, functionName) == INVALID_FUNCTION)
		{
			return false;
		}
	}

	return true;
}

// Gets the behaviours of this type
stock Handle:GetBehaviourTypeBehaviours(BehaviourType:behaviourType)
{
	new Handle:behaviours;
	if (GetTrieValue(Handle:behaviourType, BEHAVIOUR_TYPE_BEHAVIOURS, behaviours))
	{
		return behaviours;
	}
	// Shouldn't actually get here, but we keep it just incase
	return INVALID_HANDLE;
}

stock DestroyBehaviourType(BehaviourType:behaviourType)
{
	// Remove from global array and trie
	RemoveFromArray(g_hArrayBehaviourTypes, FindValueInArray(g_hArrayBehaviourTypes, behaviourType));

	new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
	GetBehaviourTypeName(behaviourType, behaviourTypeName, sizeof(behaviourTypeName));
	RemoveFromTrie(g_hTrieBehaviourTypes, behaviourTypeName);


	// Close the requirements handle
	new Handle:requirements = GetBehaviourTypeRequirements(behaviourType);
	CloseHandle(requirements);

	// Destroy all child behaviours
	new Handle:behaviours = GetBehaviourTypeBehaviours(behaviourType);
	DECREASING_LOOP(i,behaviours)
	{
		new Behaviour:behaviour = GetArrayBehaviour(behaviours, i);
		DestroyBehaviour(behaviour);
	}

	// Destroy the behaviors array and then the behaviour type trie
	CloseHandle(behaviours);
	CloseHandle(Handle:behaviourType);
}



/*******************************************************************************
 *	BEHAVIOUR FUNCTIONS
 *******************************************************************************/

/**
 *	Behaviour
 *		Plugin : PluginHandle
 *		Type : BehaviourType
 *		Name : String[BEHAVIOUR_NAME_MAX_LENGTH]
 *		PossessedPlayers : List<client>
 */

 // Creates a behaviour from a plugin, type and name
stock Behaviour:CreateBehaviour(Handle:plugin, BehaviourType:type, const String:name[])
{
	// If the plugin doesn't match the requirements of the behaviour type return INVALID_BEHAVIOUR
	if (!BehaviourTypePluginCheck(type, plugin))
	{
		return INVALID_BEHAVIOUR;
	}

	// Create the trie to store the data in
	new Handle:behaviour = CreateTrie();

	SetTrieValue(behaviour, BEHAVIOUR_PLUGIN, plugin);
	SetTrieValue(behaviour, BEHAVIOUR_TYPE, type);
	SetTrieString(behaviour, BEHAVIOUR_NAME, name);
	SetTrieValue(behaviour, BEHAVIOUR_POSSESSED_PLAYERS, CreateArray());

	// Now push it to the global array and trie for behaviours
	PushArrayCell(g_hArrayBehaviours, behaviour);

	new String:behaviourFullName[BEHAVIOUR_FULL_NAME_MAX_LENGTH];
	GetBehaviourFullNameEx(type, name, behaviourFullName, sizeof(behaviourFullName));
	SetTrieValue(g_hTrieBehaviours, behaviourFullName, behaviour);

	return Behaviour:behaviour;
}

// Searches for a behaviour of behaviour type
stock Behaviour:FindBehaviour(BehaviourType:behaviourType, const String:name[])
{
	new String:behaviourFullName[BEHAVIOUR_FULL_NAME_MAX_LENGTH];
	GetBehaviourFullNameEx(behaviourType, name, behaviourFullName, sizeof(behaviourFullName));

	new Behaviour:behaviour;
	if (GetTrieValue(g_hTrieBehaviours, behaviourFullName, behaviour))
	{
		return behaviour;
	}
	return INVALID_BEHAVIOUR;
}

// Gets the behaviour at an index in an ADT array
stock Behaviour:GetArrayBehaviour(Handle:array, index)
{
	return Behaviour:GetArrayCell(array, index);
}

// Gets the full name of the behaviour (BehaviourTypeName:BehaviourName)
stock GetBehaviourFullName(Behaviour:behaviour, String:buffer[], maxlen)
{
	new BehaviourType:behaviourType = GetBehaviourType(behaviour);

	new String:behaviourName[BEHAVIOUR_NAME_MAX_LENGTH];
	GetBehaviourName(behaviour, behaviourName, sizeof(behaviourName));

	GetBehaviourFullNameEx(behaviourType, behaviourName, buffer, maxlen);
}

// Gets the full name of the behaviour (BehaviourTypeName:BehaviourName) without having a behaviour instance
stock GetBehaviourFullNameEx(BehaviourType:behaviourType, const String:behaviourName[], String:buffer[], maxlen)
{
	new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
	GetBehaviourTypeName(behaviourType, behaviourTypeName, sizeof(behaviourTypeName));

	Format(buffer, maxlen, "%s:%s", behaviourTypeName, behaviourName);
}

// Gets the behaviours plugin, the one that created the behaviour
stock Handle:GetBehaviourPlugin(Behaviour:behaviour)
{
	new Handle:plugin;
	if (GetTrieValue(Handle:behaviour, BEHAVIOUR_PLUGIN, plugin))
	{
		return plugin;
	}
	// Shouldn't actually get here, but we keep it just incase
	return INVALID_HANDLE;
}

// Gets the behaviours type
stock BehaviourType:GetBehaviourType(Behaviour:behaviour)
{
	new BehaviourType:behaviourType;
	if (GetTrieValue(Handle:behaviour, BEHAVIOUR_TYPE, behaviourType))
	{
		return behaviourType;
	}
	// Shouldn't actually get here, but we keep it just incase
	return INVALID_BEHAVIOUR_TYPE;
}

// Gets the name of the behaviour
stock bool:GetBehaviourName(Behaviour:behaviour, String:buffer[], maxlen)
{
	if (GetTrieString(Handle:behaviour, BEHAVIOUR_NAME, buffer, maxlen))
	{
		return true;
	}
	// Shouldn't actually get here, but we keep it just incase
	buffer[0] = '\0';
	return false;
}

// Possesses a player with a behaviour
stock BehaviourPossessPlayer(Behaviour:behaviour, client)
{
	// Check if the client already owns the behaviour or not before giving it to him
	new index = FindValueInArray(g_hClientArrayBehaviours[client], behaviour);
	if (index == -1)
	{
		// Add the behaviour to the clients behaviour list
		PushArrayCell(g_hClientArrayBehaviours[client], behaviour);

		// TODO: Make some sort of dynamic hook that is easily usable in the behviours instead?
		// Add the OnPlayerRunCmd in the behaviour if needed to the clients private forward
		new Handle:plugin = GetBehaviourPlugin(behaviour);
		new Function:onPlayerRunCmd = GetBehaviourOnPlayerRunCmd(behaviour);
		if (onPlayerRunCmd != INVALID_FUNCTION)
		{
			AddToForward(g_hClientPrivateBehaviourPlayerRunCmd[client], plugin, onPlayerRunCmd);
			g_bClientHasPrivateBehaviourPlayerRunCmd[client] = true;
		}

		// Add the player to the behaviours possessed list
		new Handle:possessedPlayers = GetBehaviourPossessedPlayers(behaviour);
		PushArrayCell(possessedPlayers, client);

		// Then notify the behaviour and other plugins that the client has been possessed
		SimpleOptionalPluginCallOneParam(plugin, "Behaviour_OnPossessing", client);
		SimpleForwardCallTwoCells(g_hGlobalBehaviour_OnClientPossessed, client, behaviour);
	}
}

// Releases a player from the grasp of the behaviour
stock BehaviourReleasePlayer(Behaviour:behaviour, client)
{
	// Check if the client owns the behaviour before attempting to take it away from him
	new index = FindValueInArray(g_hClientArrayBehaviours[client], behaviour);
	if (index != -1)
	{
		RemoveFromArray(g_hClientArrayBehaviours[client], index);

		// TODO: Make some sort of dynamic hook that is easily usable in the behviours instead?
		// Remove the OnPlayerRunCmd in the behaviour if needed from the clients private forward
		new Handle:plugin = GetBehaviourPlugin(behaviour);
		new Function:onPlayerRunCmd = GetBehaviourOnPlayerRunCmd(behaviour);
		if (onPlayerRunCmd != INVALID_FUNCTION)
		{
			RemoveFromForward(g_hClientPrivateBehaviourPlayerRunCmd[client], plugin, onPlayerRunCmd);
			g_bClientHasPrivateBehaviourPlayerRunCmd[client] = (GetForwardFunctionCount(g_hClientPrivateBehaviourPlayerRunCmd[client]) != 0);
		}

		// Remove the player from the behaviours possessed list
		new Handle:possessedPlayers = GetBehaviourPossessedPlayers(behaviour);
		RemoveFromArray(possessedPlayers, FindValueInArray(possessedPlayers, client));

		// Then notify the behaviour and other plugins that the client has been released
		SimpleOptionalPluginCallOneParam(plugin, "Behaviour_OnReleasing", client);
		SimpleForwardCallTwoCells(g_hGlobalBehaviour_OnClientReleased, client, behaviour);
	}
}

// Gets the handle to the ADT array with all the players possessed by this behaviour right now
stock Handle:GetBehaviourPossessedPlayers(Behaviour:behaviour)
{
	new Handle:possessedPlayers;
	if (GetTrieValue(Handle:behaviour, BEHAVIOUR_POSSESSED_PLAYERS, possessedPlayers))
	{
		return possessedPlayers;
	}
	// Shouldn't actually get here, but we keep it just incase
	return INVALID_HANDLE;
}

// Gets the Behaviour_OnPlayerRunCmd function id from the behaviour, if it has it implemented
stock Function:GetBehaviourOnPlayerRunCmd(Behaviour:behaviour)
{
	new Handle:plugin = GetBehaviourPlugin(behaviour);
	return GetFunctionByName(plugin, "Behaviour_OnPlayerRunCmd");
}

// Destroys the behaviour, freeing all it's resources
stock DestroyBehaviour(Behaviour:behaviour)
{
	// Remove from the global array and trie
	RemoveFromArray(g_hArrayBehaviours, FindValueInArray(g_hArrayBehaviours, behaviour));

	new String:behaviourFullName[BEHAVIOUR_FULL_NAME_MAX_LENGTH];
	GetBehaviourFullName(behaviour, behaviourFullName, sizeof(behaviourFullName));
	RemoveFromTrie(g_hTrieBehaviours, behaviourFullName);

	// Take away the behaviour from all possessed players and then close the possessed players array
	new Handle:possessedPlayers = GetBehaviourPossessedPlayers(behaviour);
	DECREASING_LOOP(i,possessedPlayers)
	{
		BehaviourReleasePlayer(behaviour, GetArrayCell(possessedPlayers, i));
	}
	CloseHandle(possessedPlayers);

	// Then close the behaviour trie
	CloseHandle(Handle:behaviour);
}


/*******************************************************************************
 *	Helpers
 *******************************************************************************/

// Calls an optional function in the targetted plugin, if it exists, without parameters
stock SimpleOptionalPluginCallReturnCell(Handle:plugin, const String:function[], any:defaultValue)
{
	new Function:func = GetFunctionByName(plugin, function);
	if(func != INVALID_FUNCTION)
	{
		new result;
		Call_StartFunction(plugin, func);
		Call_Finish(result);
		return result;
	}
	return defaultValue;
}

// Calls an optional function in the targetted plugin, if it exists, without parameters
stock SimpleOptionalPluginCall(Handle:plugin, const String:function[])
{
	new Function:func = GetFunctionByName(plugin, function);
	if(func != INVALID_FUNCTION)
	{
		Call_StartFunction(plugin, func);
		Call_Finish();
	}
}

// Calls an optional function in the targetted plugin, if it exists, with 1 cell parameter
stock SimpleOptionalPluginCallOneParam(Handle:plugin, const String:function[], any:param)
{
	new Function:func = GetFunctionByName(plugin, function);
	if(func != INVALID_FUNCTION)
	{
		Call_StartFunction(plugin, func);
		Call_PushCell(param);
		Call_Finish();
	}
}

// Calls a forward with a single cell parameter
stock SimpleForwardCallOneCell(Handle:fwd, any:param)
{
	Call_StartForward(fwd);
	Call_PushCell(param);
	Call_Finish();
}

// Calls a forward with two cell parameters
stock SimpleForwardCallTwoCells(Handle:fwd, any:param1, any:param2)
{
	Call_StartForward(fwd);
	Call_PushCell(param1);
	Call_PushCell(param2);
	Call_Finish();
}

