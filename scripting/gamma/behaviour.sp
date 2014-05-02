#if defined _gamma_behaviour
 #endinput
#endif
#define _gamma_behaviour

// Sublime Text 2 auto completion
#include <gamma>

/*******************************************************************************
 *	DEFINITIONS
 *******************************************************************************/

/**
 *	Behaviour
 *		Plugin : PluginHandle
 *		Type : BehaviourType
 *		Name : String[BEHAVIOUR_NAME_MAX_LENGTH]
 *		PossessedPlayers : List<client>
 *		FunctionOverrides : Map<function name, function>
 */
#define BEHAVIOUR_PLUGIN "Plugin"
#define BEHAVIOUR_TYPE "Type"
#define BEHAVIOUR_NAME "Name"
#define BEHAVIOUR_POSSESSED_PLAYERS "PossessedPlayers"
#define BEHAVIOUR_FUNCTION_OVERRIDES "FunctionOverrides"


// Error codes for CreateBehaviour()
enum BehaviourCreationError
{
	BehaviourCreationError_None,
	BehaviourCreationError_InvalidName,			// Invalid name for a behaviour
	BehaviourCreationError_AlreadyExists,		// A behaviour with the same name and behaviour type already exists
	BehaviourCreationError_RequirementsNotMet,	// The behaviour did not meet the requirements of the behaviour type
	BehaviourCreationError_CreationFailed,		// An error was thrown in Gamma_OnCreateBehaviour
}



/*******************************************************************************
 *	PRIVATE VARIABLES
 *******************************************************************************/

// Behaviour data
static Handle:g_hArrayBehaviours;	// List<Behaviour>
static Handle:g_hTrieBehaviours;	// Map<BehaviourType.Name+':'+Behaviour.Name, Behaviour>

// Client data
static Handle:g_hPlayerArrayBehaviours[MAXPLAYERS+1];				// List<Behaviour>[MAXPLAYERS+1]
static Handle:g_hPlayerPrivateBehaviourPlayerRunCmd[MAXPLAYERS+1]; 	// Forward[MAXPLAYERS+1]
static bool:g_bClientHasPrivateBehaviourPlayerRunCmd[MAXPLAYERS+1];	// bool[MAXPLAYERS+1]

// Global forwards
static Handle:g_hGlobal_OnBehaviourCreated;		// Gamma_OnBehaviourCreated(Behaviour:behaviour)
static Handle:g_hGlobal_OnBehaviourDestroyed;	// Gamma_OnBehaviourDestroyed(Behaviour:behaviour)

static Handle:g_hGlobal_OnBehaviourPossessedClient;	// Gamma_OnClientPossessedByBehaviour(client, Behaviour:behaviour)
static Handle:g_hGlobal_OnBehaviourReleasedClient;	// Gamma_OnClientReleasedFromBehaviour(client, Behaviour:behaviour, BehaviourReleaseReason:reason)

// Behaviour creation variables
static Behaviour:g_hBehaviourInitializing;
static Handle:g_hBehaviourInitializingPlugin;


/*******************************************************************************
 *	LIBRARY FUNCTIONS
 *******************************************************************************/

stock RegisterBehaviourNatives()
{
	// Behaviour natives
	CreateNative("Gamma_RegisterBehaviour", Native_Gamma_RegisterBehaviour);
	CreateNative("Gamma_GetBehaviourType", Native_Gamma_GetBehaviourType);
	CreateNative("Gamma_GetBehaviourName", Native_Gamma_GetBehaviourName);
	CreateNative("Gamma_GetBehaviourFullName", Native_Gamma_GetBehaviourFullName);
	CreateNative("Gamma_GetPossessedPlayers", Native_Gamma_GetPossessedPlayers);
	CreateNative("Gamma_BehaviourHasFunction", Native_Gamma_BehaviourHasFunction);
	CreateNative("Gamma_AddBehaviourFunctionToForward", Native_Gamma_AddBehaviourFunctionToForward);
	CreateNative("Gamma_RemoveBehaviourFunctionFromForward", Native_Gamma_RemoveBehaviourFunctionFromForward);
	CreateNative("Gamma_SimpleBehaviourFunctionCall", Native_Gamma_SimpleBehaviourFunctionCall);
	CreateNative("Gamma_SetBehaviourFunctionOverride", Native_Gamma_SetBehaviourFunctionOverride);

	// Client natives
	CreateNative("Gamma_GiveBehaviour", Native_Gamma_GiveBehaviour);
	CreateNative("Gamma_TakeBehaviour", Native_Gamma_TakeBehaviour);
	CreateNative("Gamma_GiveRandomBehaviour", Native_Gamme_GiveRandomBehaviour);
	CreateNative("Gamma_GetPlayerBehaviours", Native_Gamma_GetPlayerBehaviours);
}

stock Behaviour_OnPluginStart()
{
	// Behaviour data
	g_hArrayBehaviours = CreateArray();
	g_hTrieBehaviours = CreateTrie();
}

stock Behaviour_OnAllPluginsLoaded()
{
	g_hGlobal_OnBehaviourCreated = CreateGlobalForward("Gamma_OnBehaviourCreated", ET_Ignore, Param_Cell);
	g_hGlobal_OnBehaviourDestroyed = CreateGlobalForward("Gamma_OnBehaviourDestroyed", ET_Ignore, Param_Cell);

	g_hGlobal_OnBehaviourPossessedClient = CreateGlobalForward("Gamma_OnBehaviourPossessedClient", ET_Ignore, Param_Cell, Param_Cell);
	g_hGlobal_OnBehaviourReleasedClient = CreateGlobalForward("Gamma_OnBehaviourReleasedClient", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
}

stock Behaviour_PluginUnloading(Handle:plugin)
{
	// Look through all behaviours and destroy if the behaviour is created by the plugin
	DECREASING_LOOP(i,GetArraySize(g_hArrayBehaviours))
	{
		new Behaviour:behaviour = GetArrayBehaviour(g_hArrayBehaviours, i);
		if (GetBehaviourPlugin(behaviour) == plugin)
		{
			DestroyBehaviour(behaviour);
		}
	}
}

stock Behaviour_OnClientConnected(client)
{
	g_hPlayerArrayBehaviours[client] = CreateArray();
	g_hPlayerPrivateBehaviourPlayerRunCmd[client] = CreateForward(ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_Array);
	g_bClientHasPrivateBehaviourPlayerRunCmd[client] = false;
}

stock Behaviour_OnClientDisconnect(client)
{
	ReleasePlayerFromBehaviours(client, BehaviourReleaseReason_ClientDisconnected);

	CloseHandle(g_hPlayerArrayBehaviours[client]);
	CloseHandle(g_hPlayerPrivateBehaviourPlayerRunCmd[client]);

	g_hPlayerArrayBehaviours[client] = INVALID_HANDLE;
	g_hPlayerPrivateBehaviourPlayerRunCmd[client] = INVALID_HANDLE;
	g_bClientHasPrivateBehaviourPlayerRunCmd[client] = false;
}

 // Frees a player from all his behaviours
stock ReleasePlayerFromBehaviours(client, BehaviourReleaseReason:reason)
{
	new Handle:behaviours = g_hPlayerArrayBehaviours[client];

	DEBUG_PRINT2("Gamma:ReleasePlayerFromBehaviours(\"%N\") : Behaviour count (%d)", client, GetArraySize(behaviours));

	DECREASING_LOOP(j,GetArraySize(behaviours))
	{
		BehaviourReleasePlayer(GetArrayBehaviour(behaviours, j), client, reason);
	}
}



/*******************************************************************************
 *	TARGET FILTERS
 *******************************************************************************/

stock AddBehaviourTargetFilter(Behaviour:behaviour)
{
	if (g_eTargetFilterVerbosity == TargetFilterVerbosity_BehaviourTypesAndBehaviours)
	{
		// Use behaviour full name as it prevents ambiguous targetting
		new String:behaviourFullName[BEHAVIOUR_FULL_NAME_MAX_LENGTH];
		GetBehaviourFullName(behaviour, behaviourFullName, sizeof(behaviourFullName));

		new String:targetFilter[BEHAVIOUR_FULL_NAME_MAX_LENGTH+2];

		// Only those with the behaviour
		Format(targetFilter, sizeof(targetFilter), "@%s", behaviourFullName);
		AddMultiTargetFilter(targetFilter, BehaviourFullNameMultiTargetFilter, targetFilter, false);

		// Only those without the behaviour
		Format(targetFilter, sizeof(targetFilter), "@!%s", behaviourFullName);
		AddMultiTargetFilter(targetFilter, BehaviourFullNameMultiTargetFilter, targetFilter, false);


		// But for ease of use also include just the behaviour name, as the above is only in rare circumstances
		GetBehaviourName(behaviour, behaviourFullName, sizeof(behaviourFullName));

		// Only those with the behaviour
		Format(targetFilter, sizeof(targetFilter), "@%s", behaviourFullName);
		AddMultiTargetFilter(targetFilter, BehaviourMultiTargetFilter, targetFilter, false);

		// Only those without the behaviour
		Format(targetFilter, sizeof(targetFilter), "@!%s", behaviourFullName);
		AddMultiTargetFilter(targetFilter, BehaviourMultiTargetFilter, targetFilter, false);
	}
}

stock RemoveBehaviourTargetFilter(Behaviour:behaviour)
{
	if (g_eTargetFilterVerbosity == TargetFilterVerbosity_BehaviourTypesAndBehaviours)
	{
		// Use behaviour full name as it prevents ambiguous targetting
		new String:behaviourFullName[BEHAVIOUR_FULL_NAME_MAX_LENGTH];
		GetBehaviourFullName(behaviour, behaviourFullName, sizeof(behaviourFullName));

		new String:targetFilter[BEHAVIOUR_FULL_NAME_MAX_LENGTH+2];

		// Only those with the behaviour
		Format(targetFilter, sizeof(targetFilter), "@%s", behaviourFullName);
		RemoveMultiTargetFilter(targetFilter, BehaviourFullNameMultiTargetFilter);

		// Only those without the behaviour
		Format(targetFilter, sizeof(targetFilter), "@!%s", behaviourFullName);
		RemoveMultiTargetFilter(targetFilter, BehaviourFullNameMultiTargetFilter);


		// But for ease of use also include just the behaviour name, as the above is only in rare circumstances
		GetBehaviourName(behaviour, behaviourFullName, sizeof(behaviourFullName));

		// Only those with the behaviour
		Format(targetFilter, sizeof(targetFilter), "@%s", behaviourFullName);
		RemoveMultiTargetFilter(targetFilter, BehaviourMultiTargetFilter);

		// Only those without the behaviour
		Format(targetFilter, sizeof(targetFilter), "@!%s", behaviourFullName);
		RemoveMultiTargetFilter(targetFilter, BehaviourMultiTargetFilter);
	}
}

public bool:BehaviourMultiTargetFilter(const String:pattern[], Handle:clients)
{
	// Check if the pattern is with or without a behaviour
	new bool:without = false;
	new startIndex = 1;

	if (pattern[1] == '!')
	{
		without = true;
		startIndex++;
	}

	// Find the behaviour, we have to do this since there could potentially be multiple
	// behaviours with the same name, but over 2 behaviour types - not likely, but can still happen
	new Handle:behavioursFromPattern = CreateArray();
	new Handle:behaviourTypes = GetGameModeBehaviourTypes(GetCurrentGameMode());
	DECREASING_LOOP(i,GetArraySize(behaviourTypes))
	{
		new BehaviourType:behaviourType = GetArrayBehaviourType(behaviourTypes, i);
		new Behaviour:behaviour = FindBehaviour(behaviourType, pattern[startIndex]);

		if (behaviour != INVALID_BEHAVIOUR)
		{
			PushArrayCell(behavioursFromPattern, behaviour);
		}
	}

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			// Get all behaviours of behaviour type on the client
			// this is not a direct accessor to internal data, so it must be closed
			new Handle:behaviours = GetPlayerBehaviours(i, INVALID_BEHAVIOUR_TYPE);
			if (GetArraySize(behaviours) > 0)
			{
				new bool:hasBehaviour = false;

				// loop through behavioursFromPattern since it has the highest chance of being with few elements
				// Few elements == less FindValueInArray calls, which is lovely, no?
				DECREASING_LOOP(j,GetArraySize(behavioursFromPattern))
				{
					// Lets see if we can find the behaviour in the players behaviours
					new Behaviour:behaviour = GetArrayBehaviour(behavioursFromPattern, j);
					if (FindValueInArray(behaviours, behaviour) != -1)
					{
						hasBehaviour = true;
						break;
					}
				}

				// Add the target if he has the behaviour and we search for those with
				// or add the target if he does not have the behaviour and we search for those without
				if (hasBehaviour)
				{
					if (!without)
					{
						PushArrayCell(clients, i);
					}
				}
				else if (without)
				{
					PushArrayCell(clients, i);
				}
			}
			CloseHandle(behaviours);
		}
	}
	return true;
}

public bool:BehaviourFullNameMultiTargetFilter(const String:pattern[], Handle:clients)
{
	// Check if the pattern is with or without a behaviour
	new bool:without = false;
	new startIndex = 1;

	if (pattern[1] == '!')
	{
		without = true;
		startIndex++;
	}

	// Find the behaviour
	new Behaviour:behaviour = FindBehaviourByFullName(pattern[startIndex]);

	// Get the players possessed by the behaviour
	new Handle:possessedPlayers = GetBehaviourPossessedPlayers(behaviour);

	if (without)
	{
		// Add those who aren't possessed by the behaviour to the client array
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && FindValueInArray(possessedPlayers, i) == -1)
			{
				PushArrayCell(clients, i);
			}
		}
	}
	else
	{
		// Copy the possessed players into the client array since 
		// we're searching for those without the behaviour
		DECREASING_LOOP(i,GetArraySize(possessedPlayers))
		{
			new client = GetArrayCell(possessedPlayers, i);
			PushArrayCell(clients, client);
		}
	}
	return true;
}


/*******************************************************************************
 *	WELP, WHAT TO DO
 *******************************************************************************/

// TODO: Changing this into using DHooks with a stock to register it in the behaviours would probably be more optimal, performance considered
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	if (!g_bIsActive)
	{
		return Plugin_Continue;
	}

	if (g_bClientHasPrivateBehaviourPlayerRunCmd[client])
	{
		Call_StartForward(g_hPlayerPrivateBehaviourPlayerRunCmd[client]);
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
 *	BEHAVIOUR NATIVES
 *******************************************************************************/

public Native_Gamma_RegisterBehaviour(Handle:plugin, numParams)
{
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(1);
	new String:behaviourName[BEHAVIOUR_NAME_MAX_LENGTH];
	GetNativeString(2, behaviourName, sizeof(behaviourName));
	new Function:onCreateBehaviour = Function:GetNativeCell(3);

	new BehaviourCreationError:error;
	new Behaviour:behaviour = CreateBehaviour(plugin, behaviourType, behaviourName, onCreateBehaviour, error);

	// Throw error, if there's any
	switch (error)
	{
		case BehaviourCreationError_InvalidName:
		{
			return ThrowNativeError(SP_ERROR_NATIVE, "Behaviour name (%s) is invalid", behaviourName);
		}
		case BehaviourCreationError_AlreadyExists:
		{
			return ThrowNativeError(SP_ERROR_NATIVE, "Behaviour of same type and name already exists");
		}
		case BehaviourCreationError_RequirementsNotMet:
		{
			return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is not meeting the behaviour type requirements");
		}
		case BehaviourCreationError_CreationFailed:
		{
			return ThrowNativeError(SP_ERROR_NATIVE, "Behaviour creation failed");
		}
	}

	return _:behaviour;
}

public Native_Gamma_GetBehaviourType(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);
	return _:GetBehaviourType(behaviour);
}

public Native_Gamma_GetBehaviourName(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);
	new String:behaviourName[BEHAVIOUR_NAME_MAX_LENGTH];
	GetBehaviourName(behaviour, behaviourName, sizeof(behaviourName));

	SetNativeString(2, behaviourName, GetNativeCell(3));
}

public Native_Gamma_GetBehaviourFullName(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);
	new String:behaviourFullName[BEHAVIOUR_FULL_NAME_MAX_LENGTH];
	GetBehaviourFullName(behaviour, behaviourFullName, sizeof(behaviourFullName));

	SetNativeString(2, behaviourFullName, GetNativeCell(3));
}

public Native_Gamma_GetPossessedPlayers(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);

	// GetBehaviourPossessedPlayers is an accessor, so it returns the internal handle for possessed players
	new Handle:possessedPlayers = GetBehaviourPossessedPlayers(behaviour);

	// Clone the array so the target plugin can't make changes to the internal data
	possessedPlayers = CloneArray(possessedPlayers);
	return _:TransferHandleOwnership(possessedPlayers, plugin);
}

public Native_Gamma_BehaviourHasFunction(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);

	new length;
	GetNativeStringLength(2, length);
	new String:functionName[length+1];
	GetNativeString(2, functionName, length+1);

	new Function:function = GetFunctionInBehaviour(behaviour, functionName);
	return (function != INVALID_FUNCTION);
}

public Native_Gamma_AddBehaviourFunctionToForward(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);

	new length;
	GetNativeStringLength(2, length);
	new String:functionName[length+1];
	GetNativeString(2, functionName, length+1);
	
	new Handle:fwd = Handle:GetNativeCell(3);

	new Function:function = GetFunctionInBehaviour(behaviour, functionName);
	if (function != INVALID_FUNCTION)
	{
		AddToForward(fwd, GetBehaviourPlugin(behaviour), function);
		return true;
	}
	return false;
}

public Native_Gamma_RemoveBehaviourFunctionFromForward(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);

	new length;
	GetNativeStringLength(2, length);
	new String:functionName[length+1];
	GetNativeString(2, functionName, length+1);
	
	new Handle:fwd = Handle:GetNativeCell(3);

	new Function:function = GetFunctionInBehaviour(behaviour, functionName);
	if (function != INVALID_FUNCTION)
	{
		RemoveFromForward(fwd, GetBehaviourPlugin(behaviour), function);
		return true;
	}
	return false;
}

public Native_Gamma_SimpleBehaviourFunctionCall(Handle:plugin, numParams)
{
	new Behaviour:behaviour = Behaviour:GetNativeCell(1);

	new length;
	GetNativeStringLength(2, length);
	new String:functionName[length+1];
	GetNativeString(2, functionName, length+1);
	
	new returnValue = GetNativeCell(3);

	new Function:function = GetFunctionInBehaviour(behaviour, functionName);
	if (function != INVALID_FUNCTION)
	{
		Call_StartFunction(GetBehaviourPlugin(behaviour), function);
		for (new i = 4; i <= numParams; i++)
		{
			Call_PushCell(GetNativeCellRef(i));
		}
		Call_Finish(returnValue);
	}
	return returnValue;
}

public Native_Gamma_SetBehaviourFunctionOverride(Handle:plugin, numParams)
{
	new length;
	GetNativeStringLength(1, length);
	new String:functionName[length+1];
	GetNativeString(1, functionName, length+1);
	
	new Function:function = Function:GetNativeCell(2);

	// Woopsies, errors
	if (g_hBehaviourInitializing == INVALID_BEHAVIOUR)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Cannot call Gamma_SetBehaviourFunctionOverride outside of Gamma_OnCreateBehaviour");
	}
	if (g_hBehaviourInitializingPlugin != plugin)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Cannot call Gamma_SetBehaviourFunctionOverride from another plugin");
	}

	AddBehaviourFunctionOverride(g_hBehaviourInitializing, functionName, function);
	return 1;
}


/*******************************************************************************
 *	CLIENT NATIVES
 *******************************************************************************/

public Native_Gamma_GiveBehaviour(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new Behaviour:behaviour = Behaviour:GetNativeCell(2);

	if (GetCurrentGameModePlugin() != plugin)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Only the currently active game mode plugin can call Gamma_GiveBehaviour");
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

public Native_Gamma_TakeBehaviour(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new Behaviour:behaviour = Behaviour:GetNativeCell(2);

	if (GetCurrentGameModePlugin() != plugin)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Only the currently active game mode plugin can call Gamma_TakeBehaviour");
	}
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	}
	if (!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);
	}

	BehaviourReleasePlayer(behaviour, client, BehaviourReleaseReason_GameModeTook);
	return 1;
}

public Native_Gamme_GiveRandomBehaviour(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(2);

	if (GetCurrentGameModePlugin() != plugin)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Only the currently active game mode plugin can call Gamma_GiveRandomBehaviour");
	}
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	}
	if (!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);
	}

	new Behaviour:behaviour = GetRandomBehaviour(behaviourType);
	BehaviourPossessPlayer(behaviour, client);
	return _:behaviour;
}

public Native_Gamma_GetPlayerBehaviours(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(2);

	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	}
	if (!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);
	}

	// GetPlayerBehaviours returns a new handle, since it's not an accessor
	new Handle:behaviours = GetPlayerBehaviours(client, behaviourType);

	return _:TransferHandleOwnership(behaviours, plugin);
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
 *		FunctionOverrides : Map<function name, function>
 */

 // Creates a behaviour from a plugin, type and name
stock Behaviour:CreateBehaviour(Handle:plugin, BehaviourType:type, const String:name[], Function:onCreateBehaviour, &BehaviourCreationError:error)
{
	#if defined DEBUG || defined DEBUG_LOG

	new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
	GetBehaviourTypeName(type, behaviourTypeName, sizeof(behaviourTypeName));

	#endif

	DEBUG_PRINT4("Gamma:CreateBehaviour(%X, \"%s\", \"%s\", %X)", plugin, behaviourTypeName, name, onCreateBehaviour);

	// Validate behaviour name
	if (!ValidateName(name))
	{
		DEBUG_PRINT0("Gamma:CreateBehaviour() : Invalid name");
		error = BehaviourCreationError_InvalidName;
		return INVALID_BEHAVIOUR;
	}

	// A behaviour can only be registered if there's no behaviour with the same name and behaviour type
	if (FindBehaviour(type, name) != INVALID_BEHAVIOUR)
	{
		DEBUG_PRINT0("Gamma:CreateBehaviour() : Behaviour already exists");
		error = BehaviourCreationError_AlreadyExists;
		return INVALID_BEHAVIOUR;
	}

	// Create the trie to store the data in
	new Handle:behaviour = CreateTrie();

	SetTrieValue(behaviour, BEHAVIOUR_PLUGIN, plugin);
	SetTrieValue(behaviour, BEHAVIOUR_TYPE, type);
	SetTrieString(behaviour, BEHAVIOUR_NAME, name);
	SetTrieValue(behaviour, BEHAVIOUR_POSSESSED_PLAYERS, CreateArray());
	SetTrieValue(behaviour, BEHAVIOUR_FUNCTION_OVERRIDES, CreateTrie());

	new String:behaviourFullName[BEHAVIOUR_FULL_NAME_MAX_LENGTH];
	GetBehaviourFullNameEx(type, name, behaviourFullName, sizeof(behaviourFullName));
	
	DEBUG_PRINT1("Gamma:CreateBehaviour() : Full name(%s)", behaviourFullName);

	// Now push it to the global array and trie for behaviours
	// Don't forget to convert the name to lower cases
	PushArrayCell(g_hArrayBehaviours, behaviour);
	SetTrieValueCaseInsensitive(g_hTrieBehaviours, name, behaviour);
	AddBehaviourTypeBehaviour(type, Behaviour:behaviour);

	// Tell the behaviours it's being created, and that it should do any initializing it needs
	// (as well as tell which functions to override)
	g_hBehaviourInitializing = Behaviour:behaviour;
	g_hBehaviourInitializingPlugin = plugin;

	// Don't forget the override is optional, and is the notification as well
	new onCreateError = SP_ERROR_NONE;
	if (onCreateBehaviour == INVALID_FUNCTION)
	{
		onCreateBehaviour = GetFunctionByName(plugin, "Gamma_OnCreateBehaviour");
	}
	if (onCreateBehaviour != INVALID_FUNCTION)
	{
		Call_StartFunction(plugin, onCreateBehaviour);
		onCreateError = Call_Finish();
	}

	g_hBehaviourInitializing = INVALID_BEHAVIOUR;
	g_hBehaviourInitializingPlugin = INVALID_HANDLE;
	if (onCreateError != SP_ERROR_NONE)
	{
		DEBUG_PRINT0("Gamma:CreateBehaviour() : Initializing failed");

		// Creation failed, don't forget to destroy the behaviour
		error = BehaviourCreationError_CreationFailed;
		DestroyBehaviour(Behaviour:behaviour);
		return INVALID_BEHAVIOUR;
	}

	// If the behaviour doesn't match the requirements of the behaviour type return INVALID_BEHAVIOUR
	// Oh, and this is waaay down here as it needs the overrides!
	if (!BehaviourTypeCheck(type, Behaviour:behaviour))
	{
		DEBUG_PRINT0("Gamma:CreateBehaviour() : Plugin check failed");
		error = BehaviourCreationError_RequirementsNotMet;
		DestroyBehaviour(Behaviour:behaviour);
		return INVALID_BEHAVIOUR;
	}

	DEBUG_PRINT0("Gamma:CreateBehaviour() : Initializing success");

	// Finally notify plugins about it's creation
	SimpleForwardCallOneParam(g_hGlobal_OnBehaviourCreated, behaviour);

	// If current game mode == behaviour types owner, we should add the behaviour as a target filter as well!
	if (GetCurrentGameMode() == GetBehaviourTypeOwner(type))
	{
		AddBehaviourTargetFilter(Behaviour:behaviour);
	}

	error = BehaviourCreationError_None;
	return Behaviour:behaviour;
}

// Searches for a behaviour of behaviour type by name
stock Behaviour:FindBehaviour(BehaviourType:behaviourType, const String:name[])
{
	new String:behaviourFullName[BEHAVIOUR_FULL_NAME_MAX_LENGTH];
	GetBehaviourFullNameEx(behaviourType, name, behaviourFullName, sizeof(behaviourFullName));

	return FindBehaviourByFullName(behaviourFullName);
}

// Searches for a behaviour by full name (a full name includes the behaviour type name)
stock Behaviour:FindBehaviourByFullName(const String:fullname[])
{
	new Behaviour:behaviour;
	if (GetTrieValueCaseInsensitive(g_hTrieBehaviours, fullname, behaviour))
	{
		return behaviour;
	}
	return INVALID_BEHAVIOUR;
}

// Searches for a behaviour of behaviour type by plugin
stock Behaviour:FindBehaviourByPlugin(BehaviourType:behaviourType, Handle:plugin)
{
	new Handle:behaviours = GetBehaviourTypeBehaviours(behaviourType);
	DECREASING_LOOP(i,GetArraySize(behaviours))
	{
		new Behaviour:behaviour = GetArrayBehaviour(behaviours, i);
		if (GetBehaviourPlugin(behaviour) == plugin)
		{
			return behaviour;
		}
	}
	return INVALID_BEHAVIOUR;
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
	new index = FindValueInArray(g_hPlayerArrayBehaviours[client], behaviour);
	if (index == -1)
	{
		#if defined DEBUG || defined DEBUG_LOG

		new String:behaviourFullName[BEHAVIOUR_NAME_MAX_LENGTH];
		GetBehaviourFullName(behaviour, behaviourFullName, sizeof(behaviourFullName));

		#endif

		DEBUG_PRINT2("Gamma:BehaviourPossessPlayer(\"%s\", \"%N\")", behaviourFullName, client);

		// Add the behaviour to the clients behaviour list
		PushArrayCell(g_hPlayerArrayBehaviours[client], behaviour);

		// TODO: Make a stock for dhooks that is easily usable in the behaviours instead?
		// Add the OnPlayerRunCmd in the behaviour if needed to the clients private forward
		new Handle:plugin = GetBehaviourPlugin(behaviour);
		new Function:onPlayerRunCmd = GetFunctionInBehaviour(behaviour, "Gamma_OnBehaviourPlayerRunCmd");
		if (onPlayerRunCmd != INVALID_FUNCTION)
		{
			DEBUG_PRINT2("Gamma:BehaviourPossessPlayer(\"%s\", \"%N\") : Has Gamma_OnBehaviourPlayerRunCmd", behaviourFullName, client);

			AddToForward(g_hPlayerPrivateBehaviourPlayerRunCmd[client], plugin, onPlayerRunCmd);
			g_bClientHasPrivateBehaviourPlayerRunCmd[client] = true;
		}

		// Add the player to the behaviours possessed list
		new Handle:possessedPlayers = GetBehaviourPossessedPlayers(behaviour);
		PushArrayCell(possessedPlayers, client);

		// Then notify the behaviour and other plugins that the client has been possessed
		Gamma_SimpleBehaviourFunctionCall(behaviour, "Gamma_OnBehaviourPossessingClient", _, client);
		SimpleForwardCallTwoParams(g_hGlobal_OnBehaviourPossessedClient, client, behaviour);
	}
}

// Releases a player from the grasp of the behaviour
stock BehaviourReleasePlayer(Behaviour:behaviour, client, BehaviourReleaseReason:reason)
{
	// Check if the client owns the behaviour before attempting to take it away from him
	new index = FindValueInArray(g_hPlayerArrayBehaviours[client], behaviour);
	if (index != -1)
	{
		#if defined DEBUG || defined DEBUG_LOG

		new String:behaviourFullName[BEHAVIOUR_FULL_NAME_MAX_LENGTH];
		GetBehaviourFullName(behaviour, behaviourFullName, sizeof(behaviourFullName));

		#endif

		DEBUG_PRINT2("Gamma:BehaviourReleasePlayer(\"%s\", \"%N\")", behaviourFullName, client);

		// Remove behaviour from the clients behaviour list
		RemoveFromArray(g_hPlayerArrayBehaviours[client], index);

		// TODO: Make a stock for dhooks that is easily usable in the behaviours instead?
		// Remove the OnPlayerRunCmd in the behaviour if needed from the clients private forward
		new Handle:plugin = GetBehaviourPlugin(behaviour);
		new Function:onPlayerRunCmd = GetFunctionInBehaviour(behaviour, "Gamma_OnBehaviourPlayerRunCmd");
		if (onPlayerRunCmd != INVALID_FUNCTION)
		{
			DEBUG_PRINT2("Gamma:BehaviourReleasePlayer(\"%s\", \"%N\") : Has Gamma_OnBehaviourPlayerRunCmd", behaviourFullName, client);

			RemoveFromForward(g_hPlayerPrivateBehaviourPlayerRunCmd[client], plugin, onPlayerRunCmd);
			g_bClientHasPrivateBehaviourPlayerRunCmd[client] = (GetForwardFunctionCount(g_hPlayerPrivateBehaviourPlayerRunCmd[client]) != 0);
		}

		// Remove the player from the behaviours possessed list
		new Handle:possessedPlayers = GetBehaviourPossessedPlayers(behaviour);
		RemoveFromArray(possessedPlayers, FindValueInArray(possessedPlayers, client));

		// Then notify the behaviour and other plugins that the client has been released
		Gamma_SimpleBehaviourFunctionCall(behaviour, "Gamma_OnBehaviourReleasingClient", _, client, reason);
		SimpleForwardCallThreeParams(g_hGlobal_OnBehaviourReleasedClient, client, behaviour, reason);
	}
}

// Gets all behaviours on a client, if filter != INVALID_BEHAVIOUR_TYPE then only of that behaviour type
stock Handle:GetPlayerBehaviours(client, BehaviourType:filter)
{
	new Handle:behaviours;
	if (filter == INVALID_BEHAVIOUR_TYPE)
	{
		// If there's no filter, just clone the array
		behaviours = CloneArray(g_hPlayerArrayBehaviours[client]);
	}
	else
	{
		// Else we'll have to look through all the playes behaviours and add them to an array
		behaviours = CreateArray();
		new Handle:playerBehaviours = g_hPlayerArrayBehaviours[client];
		new count = GetArraySize(playerBehaviours);
		for (new i = 0; i < count; i++)
		{
			// Now push all playerBehaviours that match the filter into behaviours
			new Behaviour:behaviour = GetArrayBehaviour(playerBehaviours, i);
			if (GetBehaviourType(behaviour) == filter)
			{
				PushArrayCell(behaviours, behaviour);
			}
		}
	}
	return behaviours;
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

stock Handle:GetFunctionOverridesTrie(Behaviour:behaviour)
{
	new Handle:functionOverrides;
	if (GetTrieValue(Handle:behaviour, BEHAVIOUR_FUNCTION_OVERRIDES, functionOverrides))
	{
		return functionOverrides;
	}
	// Shouldn't actually get here, but we keep it just incase
	return INVALID_HANDLE;
}

// Overrides a function in the behaviour
stock AddBehaviourFunctionOverride(Behaviour:behaviour, const String:functionName[], Function:function)
{
	new Handle:functionOverrides = GetFunctionOverridesTrie(behaviour);
	SetTrieValue(functionOverrides, functionName, function);
}

// Gets a function by name in the behaviour
stock Function:GetFunctionInBehaviour(Behaviour:behaviour, const String:functionName[])
{
	new Function:function;
	new Handle:functionOverrides = GetFunctionOverridesTrie(behaviour);
	if (GetTrieValue(functionOverrides, functionName, function) && function != INVALID_FUNCTION)
	{
		return function;
	}
	new Handle:plugin = GetBehaviourPlugin(behaviour);
	return GetFunctionByName(plugin, functionName);
}

// Destroys the behaviour, freeing all it's resources
stock DestroyBehaviour(Behaviour:behaviour)
{
	new String:behaviourFullName[BEHAVIOUR_FULL_NAME_MAX_LENGTH];
	GetBehaviourFullName(behaviour, behaviourFullName, sizeof(behaviourFullName));

	DEBUG_PRINT1("Gamma:DestroyBehaviour(\"%s\")", behaviourFullName);

	// Call the Destroy listeners
	Gamma_SimpleBehaviourFunctionCall(behaviour, "Gamma_OnDestroyBehaviour", _, behaviour);
	SimpleForwardCallOneParam(g_hGlobal_OnBehaviourDestroyed, behaviour);

	// Remove from the global array and trie
	RemoveFromArray(g_hArrayBehaviours, FindValueInArray(g_hArrayBehaviours, behaviour));
	RemoveFromTrieCaseInsensitive(g_hTrieBehaviours, behaviourFullName);
	RemoveBehaviourTypeBehaviour(GetBehaviourType(behaviour), behaviour);

	// Take away the behaviour from all possessed players
	DEBUG_PRINT1("Gamma:DestroyBehaviour(\"%s\") : Releasing players", behaviourFullName);
	new Handle:possessedPlayers = GetBehaviourPossessedPlayers(behaviour);
	DECREASING_LOOP(i,GetArraySize(possessedPlayers))
	{
		BehaviourReleasePlayer(behaviour, GetArrayCell(possessedPlayers, i), BehaviourReleaseReason_BehaviourUnloaded);
	}
	DEBUG_PRINT1("Gamma:DestroyBehaviour(\"%s\") : Released players", behaviourFullName);

	// If current game mode == behaviour types owner, we should remove from target filter
	if (GetCurrentGameMode() == GetBehaviourTypeOwner(GetBehaviourType(behaviour)))
	{
		RemoveBehaviourTargetFilter(behaviour);
	}

	// Then close the possessed players and behaviour trie handles
	CloseHandle(possessedPlayers);
	CloseHandle(Handle:behaviour);
}
