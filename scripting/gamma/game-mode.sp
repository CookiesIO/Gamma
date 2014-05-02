#if defined _gamma_game_mode
 #endinput
#endif
#define _gamma_game_mode

// Sublime text 2 autocompletion!
#include <sourcemod>
#include "gamma/behaviour-type.sp"
#include "gamma/behaviour.sp"

/*******************************************************************************
 *	DEFINITIONS
 *******************************************************************************/

/**
 *	GameMode
 *		Plugin : PluginHandle
 *		Name : String[GAME_MODE_NAME_MAX_LENGTH]
 *		BehaviourTypes : List<BehaviourType>
 */
#define GAME_MODE_PLUGIN "Plugin"
#define GAME_MODE_NAME "Name"
#define GAME_MODE_BEHAVIOUR_TYPES "BehaviourTypes"


// Error codes for CreateGameMode()
enum GameModeCreationError
{
	GameModeCreationError_None,
	GameModeCreationError_InvalidName,				// Invalid name for a game mode
	GameModeCreationError_AlreadyExists,			// A game mode with the same name already exists
	GameModeCreationError_PluginAlreadyHasGameMode,	// The plugin registering a game mode already has a game mode registered
	GameModeCreationError_CreationFailed,			// An error was thrown Gamma_OnCreateGameMode
}



/*******************************************************************************
 *	PRIVATE VARIABLES
 *******************************************************************************/

// Game modes data
static Handle:g_hArrayGameModes;	// List<GameMode>
static Handle:g_hTrieGameModes;		// Map<GameMode.Name, GameMode>

// Global forwards
static Handle:g_hGlobal_OnGameModeCreated;		// Gamma_OnGameModeCreated(GameMode:gameMode)
static Handle:g_hGlobal_OnGameModeDestroyed;	// Gamma_OnGameModeDestroyed(GameMode:gameMode)

static Handle:g_hGlobal_OnGameModeStarted;		// Gamma_OnGameModeStarted(GameMode:gameMode)
static Handle:g_hGlobal_OnGameModeEnded;		// Gamma_OnGameModeEnded(GameMode:gameMode)

// Current game mode
static GameMode:g_hCurrentGameMode;		// Active game mode
static Handle:g_hCurrentGameModePlugin;	// Active game mode's plugin

// Game mode creation variables
static GameMode:g_hGameModeInitializing;
static Handle:g_hGameModeInitializingPlugin;
static bool:g_bGameModeInitializationFailed;



/*******************************************************************************
 *	LIBRARY FUNCTIONS
 *******************************************************************************/

stock RegisterGameModeNatives()
{
	// Misc natives
	CreateNative("Gamma_GetAllGameModes", Native_Gamma_GetAllGameModes);
	CreateNative("Gamma_GetCurrentGameMode", Native_Gamma_GetCurrentGameMode);

	// Game mode natives
	CreateNative("Gamma_RegisterGameMode", Native_Gamma_RegisterGameMode);
	CreateNative("Gamma_FindGameMode", Native_Gamma_FindGameMode);
	CreateNative("Gamma_GetGameModeName", Native_Gamma_GetGameModeName);
	CreateNative("Gamma_GetGameModeBehaviourTypes", Native_Gamma_GetGameModeBehaviourTypes);
	CreateNative("Gamma_ForceStopGameMode", Native_Gamma_ForceStopGameMode);
}

stock GameMode_OnPluginStart()
{
	// Game mode data
	g_hArrayGameModes = CreateArray();
	g_hTrieGameModes = CreateTrie();

	// Game mode creation variables
	g_bGameModeInitializationFailed = false;
	g_hGameModeInitializing = INVALID_GAME_MODE;
	g_hGameModeInitializingPlugin = INVALID_HANDLE;

	// Current game mode
	g_hCurrentGameMode = INVALID_GAME_MODE;
	g_hCurrentGameModePlugin = INVALID_HANDLE;
}

stock GameMode_OnAllPluginsLoaded()
{
	g_hGlobal_OnGameModeCreated = CreateGlobalForward("Gamma_OnGameModeCreated", ET_Ignore, Param_Cell);
	g_hGlobal_OnGameModeDestroyed = CreateGlobalForward("Gamma_OnGameModeDestroyed", ET_Ignore, Param_Cell);

	g_hGlobal_OnGameModeStarted = CreateGlobalForward("Gamma_OnGameModeStarted", ET_Ignore, Param_Cell);
	g_hGlobal_OnGameModeEnded = CreateGlobalForward("Gamma_OnGameModeEnded", ET_Ignore, Param_Cell, Param_Cell);
}

stock GameMode_PluginUnloading(Handle:plugin)
{
	// Since only a single game mode can be created by 1 plugin, find it
	new GameMode:gameMode = FindGameModeByPlugin(plugin);
	if (gameMode != INVALID_GAME_MODE)
	{
		// And destroy it
		DestroyGameMode(gameMode);
	}
}

stock GetGameModeCount()
{
	return GetArraySize(g_hArrayGameModes);
}

stock GameMode:GetGameMode(index)
{
	return GetArrayGameMode(g_hArrayGameModes, index);
}

stock GameMode:GetCurrentGameMode()
{
	return g_hCurrentGameMode;
}

stock Handle:GetCurrentGameModePlugin()
{
	return g_hCurrentGameModePlugin;
}

stock bool:IsInitializingGameMode()
{
	return (g_hGameModeInitializing != INVALID_GAME_MODE);
}

stock GameMode:GetInitializingGameMode()
{
	return g_hGameModeInitializing;
}

stock Handle:GetInitializingGameModePlugin()
{
	return g_hGameModeInitializingPlugin;
}

stock FailGameModeInitialization()
{
	if (!IsInitializingGameMode())
	{
		ThrowError("Can't fail game mode initization, not initializing any");
		return;
	}
	g_bGameModeInitializationFailed = true;
}


/*******************************************************************************
 *	START/STOP GAME MODE
 *******************************************************************************/

stock StopGameMode(GameModeEndReason:reason)
{
	if (g_hCurrentGameMode != INVALID_GAME_MODE)
	{
		DEBUG_PRINT1("Gamma:StopGameMode(reason=%d)", reason);

		RemoveTargetFilters(g_hCurrentGameMode);

		SimpleOptionalPluginCallOneParam(g_hCurrentGameModePlugin, "Gamma_OnGameModeEnd", reason);
		SimpleForwardCallTwoParams(g_hGlobal_OnGameModeEnded, g_hCurrentGameMode, reason);

		// Release all clients from their behaviours (curses!)
		DEBUG_PRINT1("Gamma:StopGameMode(reason=%d) : Releasing all players", reason);
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				ReleasePlayerFromBehaviours(i, BehaviourReleaseReason_GameModeEnded);
			}
		}
		DEBUG_PRINT1("Gamma:StopGameMode(reason=%d) : Released all players", reason);

		if (reason == GameModeEndReason_ForceStopped)
		{
			// Force roundend/stalemate
			ForceRoundEnd();
		}

		g_eTargetFilterVerbosity = TargetFilterVerbosity_None;

		g_hCurrentGameMode = INVALID_GAME_MODE;
		g_hCurrentGameModePlugin = INVALID_HANDLE;

		g_bIsActive = false;
	}
}

stock ChooseAndStartGameMode()
{
	// In some cases the game mode doesn't stop without a little push from here
	// One of the cases are CTeamplayGameRules::RoundRespawn being called with a
	// PreviousRoundEnd in between, a little helper fix is to never start without
	// Any players, which I'll add a little further down!
	StopGameMode(GameModeEndReason_RoundEnded);

	if (GetConVarBool(g_hCvarEnabled))
	{
		DEBUG_PRINT0("Gamma:ChooseAndStartGameMode() : Enabled");

		new clientCount = GetClientCount();
		if (clientCount == 0)
		{
			DEBUG_PRINT0("Gamma:ChooseAndStartGameMode() : No clients ingame, never mind starting a game mode");
			return;
		}

		DEBUG_PRINT0("Gamma:ChooseAndStartGameMode() : Auto finding plugins - Start");

		new Handle:pluginIter = GetPluginIterator();
		new Handle:newKnownPlugins = CreateArray();
		new Handle:knownGameModes = CloneArray(g_hArrayGameModes);

		if (g_hArrayKnownPlugins == INVALID_HANDLE)
		{
			DEBUG_PRINT0("Gamma:ChooseAndStartGameMode() : Auto finding plugins - No knowns");

			// We don't have any known plugins, so we'll just call it on all plugins
			while (MorePlugins(pluginIter))
			{
				new Handle:plugin = ReadPlugin(pluginIter);
				DetectedPlugin(plugin, knownGameModes);
				PushArrayCell(newKnownPlugins, plugin);
			}
		}
		else
		{
			DEBUG_PRINT0("Gamma:ChooseAndStartGameMode() : Auto finding plugins - Have knowns");

			// We have known plugins, so see if we know the plugin before called PluginDetected
			while (MorePlugins(pluginIter))
			{
				new Handle:plugin = ReadPlugin(pluginIter);
				if (FindValueInArray(g_hArrayKnownPlugins, plugin) == -1)
				{
					DetectedPlugin(plugin, knownGameModes);
				}
				PushArrayCell(newKnownPlugins, plugin);
			}
			CloseHandle(g_hArrayKnownPlugins);
		}

		g_hArrayKnownPlugins = newKnownPlugins;
		CloseHandle(pluginIter);
		CloseHandle(knownGameModes);


		DEBUG_PRINT0("Gamma:ChooseAndStartGameMode() : Auto finding plugins - Ended");

		g_eTargetFilterVerbosity = TargetFilterVerbosity:GetConVarInt(g_hCvarTargetFilters);

		new String:gameModeName[GAME_MODE_NAME_MAX_LENGTH];
		GetConVarString(g_hCvarGameMode, gameModeName, sizeof(gameModeName));

		new gameModeSelectionMode = GetConVarInt(g_hCvarGameModeSelectionMode);

		switch (gameModeSelectionMode)
		{
			// Strictly by Cvar
			case 1:
			{
				DEBUG_PRINT0("Gamma:ChooseAndStartGameMode() : Strictly by Cvar");
				AttemptStart(FindGameMode(gameModeName));
			}
			// First game mode able to start
			case 2:
			{
				DEBUG_PRINT0("Gamma:ChooseAndStartGameMode() : First game mode able to start");
				AttemptStartAny();
			}
			// Try cvar, if it fails then first to start
			case 3:
			{
				DEBUG_PRINT0("Gamma:ChooseAndStartGameMode() : Try by Cvar then any");
				if (!AttemptStart(FindGameMode(gameModeName)))
				{
					AttemptStartAny();
				}
			}
		}
	}
}

stock DetectedPlugin(Handle:plugin, Handle:knownGameModes)
{
	SimpleOptionalPluginCall(plugin, "Gamma_PluginDetected");
	DECREASING_LOOP(i,GetArraySize(knownGameModes))
	{
		// Uhh, just to be safe, lets see if the behaviour hasn't already created it's behaviour
		// for the game mode we're about to signal has been created
		new GameMode:gameMode = GetArrayGameMode(knownGameModes, i);

		if (GetGameModePlugin(gameMode) != plugin)
		{
			DEBUG_PRINT1("Gamma:DetectedPlugin(%X) : Calling Gamma_OnGameModeCreated",plugin);
			SimpleOptionalPluginCallOneParam(plugin, "Gamma_OnGameModeCreated", gameMode);
		}
	}
}

stock AttemptStartAny()
{
	DEBUG_PRINT0("Gamma:AttemptStartAny()");

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
		#if defined DEBUG || defined DEBUG_LOG

		new String:gameModeName[GAME_MODE_NAME_MAX_LENGTH];
		GetGameModeName(gameMode, gameModeName, sizeof(gameModeName));

		#endif

		DEBUG_PRINT1("Gamma:AttemptStart(\"%s\")", gameModeName);

		new Handle:gameModePlugin = GetGameModePlugin(gameMode);

		new bool:canStart = bool:SimpleOptionalPluginCall(gameModePlugin, "Gamma_IsGameModeAbleToStartRequest", true);
		if (canStart)
		{
			DEBUG_PRINT1("Gamma:AttemptStart(\"%s\") : Able to start", gameModeName);

			g_hCurrentGameMode = gameMode;
			g_hCurrentGameModePlugin = gameModePlugin;

			SimpleOptionalPluginCall(gameModePlugin, "Gamma_OnGameModeStart");
			SimpleForwardCallOneParam(g_hGlobal_OnGameModeStarted, gameMode);

			AddTargetFilters(gameMode);

			g_bIsActive = true;
			return true;
		}

		DEBUG_PRINT1("Gamma:AttemptStart(\"%s\") : Unable to start", gameModeName);
	}
	return false;
}



/*******************************************************************************
 *	TARGET FILTERS
 *******************************************************************************/

stock AddTargetFilters(GameMode:gameMode)
{
	if (g_eTargetFilterVerbosity != TargetFilterVerbosity_None)
	{
		new Handle:behaviourTypes = GetGameModeBehaviourTypes(gameMode);
		DECREASING_LOOP(i,GetArraySize(behaviourTypes))
		{
			new BehaviourType:behaviourType = GetArrayBehaviourType(behaviourTypes, i);
			AddBehaviourTypeTargetFilter(behaviourType);
		}
	}
}

stock RemoveTargetFilters(GameMode:gameMode)
{
	if (g_eTargetFilterVerbosity != TargetFilterVerbosity_None)
	{
		new Handle:behaviourTypes = GetGameModeBehaviourTypes(gameMode);
		DECREASING_LOOP(i,GetArraySize(behaviourTypes))
		{
			new BehaviourType:behaviourType = GetArrayBehaviourType(behaviourTypes, i);
			RemoveBehaviourTypeTargetFilter(behaviourType);
		}
	}
}



/*******************************************************************************
 *	NATIVES
 *******************************************************************************/

public Native_Gamma_GetAllGameModes(Handle:plugin, numParams)
{
	// Clone the array so the target plugin can't make changes to the internal data
	new Handle:arrayGameModesClone = CloneArray(g_hArrayGameModes);
	return _:TransferHandleOwnership(arrayGameModesClone, plugin);
}

public Native_Gamma_GetCurrentGameMode(Handle:plugin, numParams)
{
	return _:g_hCurrentGameMode;
}

public Native_Gamma_RegisterGameMode(Handle:plugin, numParams)
{
	// Get the game mode name
	new String:gameModeName[GAME_MODE_NAME_MAX_LENGTH];
	GetNativeString(1, gameModeName, sizeof(gameModeName));

	new GameModeCreationError:error;
	new GameMode:gameMode = CreateGameMode(plugin, gameModeName, error);

	// throw error, if there's any
	switch (error)
	{
		case BehaviourCreationError_InvalidName:
		{
			return ThrowNativeError(SP_ERROR_NATIVE, "Game mode name (%s) is invalid", gameModeName);
		}
		case GameModeCreationError_AlreadyExists:
		{
			return ThrowNativeError(SP_ERROR_NATIVE, "A game mode with the same name already exists (%s)", gameModeName);
		}
		case GameModeCreationError_PluginAlreadyHasGameMode:
		{
			return ThrowNativeError(SP_ERROR_NATIVE, "Plugin already has a game mode registered");
		}
		case GameModeCreationError_CreationFailed:
		{
			return ThrowNativeError(SP_ERROR_NATIVE, "Game mode creation failed");
		}
	}

	return _:gameMode;
}

public Native_Gamma_FindGameMode(Handle:plugin, numParams)
{
	new length;
	GetNativeStringLength(1, length);
	new String:buffer[length+1];
	GetNativeString(1, buffer, length+1);

	return _:FindGameMode(buffer);
}

public Native_Gamma_GetGameModeName(Handle:plugin, numParams)
{
	new GameMode:gameMode = GameMode:GetNativeCell(1);
	new String:gameModeName[GAME_MODE_NAME_MAX_LENGTH];
	GetGameModeName(gameMode, gameModeName, sizeof(gameModeName));

	SetNativeString(2, gameModeName, GetNativeCell(3));
}

public Native_Gamma_GetGameModeBehaviourTypes(Handle:plugin, numParams)
{
	new GameMode:gameMode = GameMode:GetNativeCell(1);

	// GetGameModeBehaviourTypes is an accessor, so it returns the internal handle for behaviour types
	new Handle:behaviourTypes = GetGameModeBehaviourTypes(gameMode);

	// Clone the array so the target plugin can't make changes to the internal data
	behaviourTypes = CloneArray(behaviourTypes);
	return _:TransferHandleOwnership(behaviourTypes, plugin);
}

public Native_Gamma_ForceStopGameMode(Handle:plugin, numParams)
{
	if (plugin != g_hCurrentGameModePlugin)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Only the currently active game mode plugin can call Gamma_ForceStopGameMode");
	}
	StopGameMode(GameModeEndReason_ForceStopped);
	return 1;
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
stock GameMode:CreateGameMode(Handle:plugin, const String:name[], &GameModeCreationError:error)
{
	DEBUG_PRINT2("Gamma:CreateGameMode(%X, \"%s\")", plugin, name);

	// Validate behaviour name
	if (!ValidateName(name))
	{
		DEBUG_PRINT0("Gamma:CreateGameMode() : Invalid name");
		error = GameModeCreationError_InvalidName;
		return INVALID_GAME_MODE;
	}

	// Has the plugin has already registered a game mode?
	if (FindGameModeByPlugin(plugin) != INVALID_GAME_MODE)
	{
		DEBUG_PRINT0("Gamma:CreateGameMode() : Plugin already has a game mode");
		error = GameModeCreationError_PluginAlreadyHasGameMode;
		return INVALID_GAME_MODE;
	}

	// Does another existing game mode with this name?
	if (FindGameMode(name) != INVALID_GAME_MODE)
	{
		DEBUG_PRINT0("Gamma:CreateGameMode() : Game mode already exists");
		error = GameModeCreationError_AlreadyExists;
		return INVALID_GAME_MODE;
	}

	// Create the trie to hold the data about the game mode
	new Handle:gameMode = CreateTrie();

	SetTrieValue(gameMode, GAME_MODE_PLUGIN, plugin);
	SetTrieString(gameMode, GAME_MODE_NAME, name);
	SetTrieValue(gameMode, GAME_MODE_BEHAVIOUR_TYPES, CreateArray());

	// Then push it to the global array and trie
	// Don't forget to convert the string to lower cases!
	PushArrayCell(g_hArrayGameModes, gameMode);
	SetTrieValueCaseInsensitive(g_hTrieGameModes, name, gameMode);

	// Make the game mode initialize it's BehaviourTypes, if it needs to, also it's only valid during this call!
	g_hGameModeInitializing = GameMode:gameMode;
	g_hGameModeInitializingPlugin = plugin;
	g_bGameModeInitializationFailed = false;

	new onCreateError;
	SimpleOptionalPluginCall(plugin, "Gamma_OnCreateGameMode", _, onCreateError);

	g_hGameModeInitializing = INVALID_GAME_MODE;
	g_hGameModeInitializingPlugin = INVALID_HANDLE;
	if (g_bGameModeInitializationFailed || onCreateError != SP_ERROR_NONE)
	{
		DEBUG_PRINT0("Gamma:CreateGameMode() : Initializing failed");

		// Creation failed, don't forget to destroy the game mode
		error = GameModeCreationError_CreationFailed;
		DestroyGameMode(GameMode:gameMode);
		return INVALID_GAME_MODE;
	}

	DEBUG_PRINT0("Gamma:CreateGameMode() : Initializing success");

	// Finally notify other plugins about it's creation
	SimpleForwardCallOneParam(g_hGlobal_OnGameModeCreated, gameMode);

	error = GameModeCreationError_None;
	return GameMode:gameMode;
}

// Finds a game mode from a name
stock GameMode:FindGameMode(const String:name[])
{
	new GameMode:gameMode;
	if (GetTrieValueCaseInsensitive(g_hTrieGameModes, name, gameMode))
	{
		return gameMode;
	}
	return INVALID_GAME_MODE;
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
	// First we make sure that the behaviour type owner is the game mode (a little redundant, but better safe than sorry!)
	if (GetBehaviourTypeOwner(behaviourType) == gameMode)
	{
		new Handle:behaviourTypes = GetGameModeBehaviourTypes(gameMode);
		PushArrayCell(behaviourTypes, behaviourType);
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
	new String:name[GAME_MODE_NAME_MAX_LENGTH];
	GetGameModeName(gameMode, name, sizeof(name));

	DEBUG_PRINT1("Gamma:DestroyGameMode(\"%s\")", name);

	// If the game mode is currently running, stop it forcefully
	if (gameMode == g_hCurrentGameMode)
	{
		StopGameMode(GameModeEndReason_ForceStopped);
	}

	// Call the Destroy listeners
	SimpleOptionalPluginCall(GetGameModePlugin(gameMode), "Gamma_OnDestroyGameMode");
	SimpleForwardCallOneParam(g_hGlobal_OnGameModeDestroyed, gameMode);

	// Remove from global array and trie
	RemoveFromArray(g_hArrayGameModes, FindValueInArray(g_hArrayGameModes, gameMode));
	RemoveFromTrieCaseInsensitive(g_hTrieGameModes, name);

	// Destroy all associated behaviour types
	DEBUG_PRINT1("Gamma:DestroyGameMode(\"%s\") : Destroy Behaviour Types", name);
	new Handle:behaviourTypes = GetGameModeBehaviourTypes(gameMode);
	DECREASING_LOOP(i,GetArraySize(behaviourTypes))
	{
		new BehaviourType:behaviourType = GetArrayBehaviourType(behaviourTypes, i);
		DestroyBehaviourType(behaviourType);
	}
	DEBUG_PRINT1("Gamma:DestroyGameMode(\"%s\") : Destroyed Behaviour Types", name);

	// Lastly close the behaviour type array and the game mode trie
	CloseHandle(behaviourTypes);
	CloseHandle(Handle:gameMode);
}