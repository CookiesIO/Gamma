#if defined _gamma_behaviour_type
 #endinput
#endif
#define _gamma_behaviour_type

// Sublime text 2 autocompletion!
#include <sourcemod>
#include "gamma/game-mode.sp"

/*******************************************************************************
 *	DEFINITIONS
 *******************************************************************************/

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


// Error codes for CreateBehaviourType()
enum BehaviourTypeCreationError
{
	BehaviourTypeCreationError_None,
	BehaviourTypeCreationError_InvalidName,				// Invalid name for a behaviour type
	BehaviourTypeCreationError_AlreadyExists,			// A behaviour type with the same name already exists
	BehaviourTypeCreationError_GameModeNotInCreation,	// The game mode is not in creation AKA in the Gamma_OnCreateGameMode function
}



/*******************************************************************************
 *	PRIVATE VARIABLES
 *******************************************************************************/

// Behaviour types data
static Handle:g_hArrayBehaviourTypes;	// List<BehaviourType>
static Handle:g_hTrieBehaviourTypes;	// Map<BehaviourType.Name, BehaviourType>



/*******************************************************************************
 *	LIBRARY FUNCTIONS
 *******************************************************************************/

stock RegisterBehaviourTypeNatives()
{
	CreateNative("Gamma_CreateBehaviourType", Native_Gamma_CreateBehaviourType);
	CreateNative("Gamma_FindBehaviourType", Native_Gamma_FindBehaviourType);
	CreateNative("Gamma_GetBehaviourTypeName", Native_Gamma_GetBehaviourTypeName);
	CreateNative("Gamma_AddBehaviourTypeRequirement", Native_Gamma_AddBehaviourTypeRequirement);
	CreateNative("Gamma_BehaviourTypeOwnsBehaviour", Native_Gamma_BehaviourTypeOwnsBehaviour);
	CreateNative("Gamma_GetBehaviourTypeBehaviours", Native_Gamma_GetBehaviourTypeBehaviours);
	CreateNative("Gamma_BehaviourTypeHasBehaviours", Native_Gamma_BehaviourTypeHasBehaviours);
	CreateNative("Gamma_GetRandomBehaviour", Native_Gamma_GetRandomBehaviour);
}

stock BehaviourType_OnPluginStart()
{
	// Behaviour type data
	g_hArrayBehaviourTypes = CreateArray();
	g_hTrieBehaviourTypes = CreateTrie();
}



/*******************************************************************************
 *	TARGET FILTERS
 *******************************************************************************/

stock AddBehaviourTypeTargetFilter(BehaviourType:behaviourType)
{
	if (g_eTargetFilterVerbosity >= TargetFilterVerbosity_BehaviourTypeOnly)
	{
		new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
		GetBehaviourTypeName(behaviourType, behaviourTypeName, sizeof(behaviourTypeName));

		new String:targetFilter[BEHAVIOUR_TYPE_NAME_MAX_LENGTH+2];

		// Only those with a behaviour of type
		Format(targetFilter, sizeof(targetFilter), "@%s", behaviourTypeName);
		AddMultiTargetFilter(targetFilter, BehaviourTypeMultiTargetFilter, targetFilter, false);

		// Only those without a behaviour of type
		Format(targetFilter, sizeof(targetFilter), "@!%s", behaviourTypeName);
		AddMultiTargetFilter(targetFilter, BehaviourTypeMultiTargetFilter, targetFilter, false);

		// Add behaviour target filters if the verbosity says yes!
		if (g_eTargetFilterVerbosity == TargetFilterVerbosity_BehaviourTypesAndBehaviours)
		{
			new Handle:behaviours = GetBehaviourTypeBehaviours(behaviourType);
			DECREASING_LOOP(i,GetArraySize(behaviours))
			{
				new Behaviour:behaviour = GetArrayBehaviour(behaviours, i);
				AddBehaviourTargetFilter(behaviour);
			}
		}
	}
}



stock RemoveBehaviourTypeTargetFilter(BehaviourType:behaviourType)
{
	if (g_eTargetFilterVerbosity == TargetFilterVerbosity_BehaviourTypeOnly ||
		g_eTargetFilterVerbosity == TargetFilterVerbosity_BehaviourTypesAndBehaviours)
	{
		new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
		GetBehaviourTypeName(behaviourType, behaviourTypeName, sizeof(behaviourTypeName));

		new String:targetFilter[BEHAVIOUR_TYPE_NAME_MAX_LENGTH+2];

		// Only those with a behaviour of type
		Format(targetFilter, sizeof(targetFilter), "@%s", behaviourTypeName);
		RemoveMultiTargetFilter(targetFilter, BehaviourTypeMultiTargetFilter);

		// Only those without a behaviour of type
		Format(targetFilter, sizeof(targetFilter), "@!%s", behaviourTypeName);
		RemoveMultiTargetFilter(targetFilter, BehaviourTypeMultiTargetFilter);

		// Remove behaviour target filters if the verbosity says so
		if (g_eTargetFilterVerbosity == TargetFilterVerbosity_BehaviourTypesAndBehaviours)
		{
			new Handle:behaviours = GetBehaviourTypeBehaviours(behaviourType);
			DECREASING_LOOP(i,GetArraySize(behaviours))
			{
				new Behaviour:behaviour = GetArrayBehaviour(behaviours, i);
				RemoveBehaviourTargetFilter(behaviour);
			}
		}
	}
}

public bool:BehaviourTypeMultiTargetFilter(const String:pattern[], Handle:clients)
{
	// Check if the pattern is with or without a behaviour of type
	new bool:without = false;
	new startIndex = 1;

	if (pattern[1] == '!')
	{
		without = true;
		startIndex++;
	}

	// Find the behaviour type
	new BehaviourType:behaviourType = FindBehaviourType(pattern[startIndex]);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			// Get all behaviours of behaviour type on the client
			// this is not a direct accessor to internal data, so it must be closed
			new Handle:behaviours = GetPlayerBehaviours(i, behaviourType);


			// Add the target if he has a behaviour of type and we search for those with
			// or add the target if he does not have a behaviour of type and we search for those without
			if (GetArraySize(behaviours) > 0)
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
			CloseHandle(behaviours);
		}
	}
	return true;
}

/*******************************************************************************
 *	NATIVES
 *******************************************************************************/

public Native_Gamma_CreateBehaviourType(Handle:plugin, numParams)
{
	new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
	GetNativeString(1, behaviourTypeName, sizeof(behaviourTypeName));

	new BehaviourTypeCreationError:error;
	new BehaviourType:behaviourType = CreateBehaviourType(plugin, behaviourTypeName, error);

	// throw errors, if we have any
	switch (error)
	{
		case BehaviourTypeCreationError_InvalidName:
		{
			FailGameModeInitialization();
			return ThrowNativeError(SP_ERROR_NATIVE, "Behaviour type name (%s) is invalid", behaviourTypeName);
		}
		case BehaviourTypeCreationError_AlreadyExists:
		{
			FailGameModeInitialization();
			return ThrowNativeError(SP_ERROR_NATIVE, "Behaviour type (%s) already exists", behaviourTypeName);
		}
		case BehaviourTypeCreationError_GameModeNotInCreation:
		{
			return ThrowNativeError(SP_ERROR_NATIVE, "Cannot call Gamma_CreateBehaviourType outside of Gamma_OnCreateGameMode");
		}
	}

	return _:behaviourType;
}

public Native_Gamma_FindBehaviourType(Handle:plugin, numParams)
{
	new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
	GetNativeString(1, behaviourTypeName, sizeof(behaviourTypeName));

	return _:FindBehaviourType(behaviourTypeName);
}

public Native_Gamma_GetBehaviourTypeName(Handle:plugin, numParams)
{
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(1);

	new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
	GetBehaviourTypeName(behaviourType, behaviourTypeName, sizeof(behaviourTypeName));

	SetNativeString(2, behaviourTypeName, GetNativeCell(3));
}

public Native_Gamma_AddBehaviourTypeRequirement(Handle:plugin, numParams)
{
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(1);
	new String:functionName[SYMBOL_MAX_LENGTH];
	GetNativeString(2, functionName, sizeof(functionName));

	// Requirements can only be added before the behaviour type is added to a game mode
	if (GetInitializingGameModePlugin() != plugin)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Requirements to behaviours types can only be added in Gamma_OnCreateGameMode, by the owning plugin");
	}

	// If it's not added to a game mode add the requirement to the behaviour type
	AddBehaviourTypeRequirement(behaviourType, functionName);
	return 1;
}

public Native_Gamma_BehaviourTypeOwnsBehaviour(Handle:plugin, numParams)
{
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(1);
	new Behaviour:behaviour = Behaviour:GetNativeCell(2);
	return _:BehaviourTypeOwnsBehaviour(behaviourType, behaviour);
}

public Native_Gamma_GetBehaviourTypeBehaviours(Handle:plugin, numParams)
{
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(1);

	// GetBehaviourTypeBehaviours is an accessor, so it returns the internal handle for behaviours
	new Handle:behaviours = GetBehaviourTypeBehaviours(behaviourType);

	// Clone the array so the target plugin can't make changes to the internal data
	behaviours = CloneArray(behaviours);
	return _:TransferHandleOwnership(behaviours, plugin);
}

public Native_Gamma_BehaviourTypeHasBehaviours(Handle:plugin, numParams)
{
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(1);
	return _:BehaviourTypeHasBehaviours(behaviourType);
}

public Native_Gamma_GetRandomBehaviour(Handle:plugin, numParams)
{
	new BehaviourType:behaviourType = BehaviourType:GetNativeCell(1);
	return _:GetRandomBehaviour(behaviourType);
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
stock BehaviourType:CreateBehaviourType(Handle:plugin, const String:name[], &BehaviourTypeCreationError:error)
{
	DEBUG_PRINT2("Gamma:CreateBehaviourType(%X, \"%s\")", plugin, name);

	// Only valid to create behaviour types when a game mode is initializing, also only by the same plugin
	if (GetInitializingGameModePlugin() != plugin)
	{
		error = BehaviourTypeCreationError_GameModeNotInCreation;
		return INVALID_BEHAVIOUR_TYPE;
	}

	// Validate behaviour name
	if (!ValidateName(name))
	{
		error = BehaviourTypeCreationError_InvalidName;
		return INVALID_BEHAVIOUR_TYPE;
	}

	// If we find a behaviour type with the same name, we can't use this name
	if (FindBehaviourType(name) != INVALID_BEHAVIOUR_TYPE)
	{
		error = BehaviourTypeCreationError_AlreadyExists;
		return INVALID_BEHAVIOUR_TYPE;
	}

	// Create the trie to hold the behaviour type data
	new Handle:behaviourType = CreateTrie();

	SetTrieValue(behaviourType, BEHAVIOUR_TYPE_PLUGIN, plugin);
	SetTrieValue(behaviourType, BEHAVIOUR_TYPE_OWNER, GetInitializingGameMode());
	SetTrieString(behaviourType, BEHAVIOUR_TYPE_NAME, name);
	SetTrieValue(behaviourType, BEHAVIOUR_TYPE_REQUIREMENTS, CreateArray(ByteCountToCells(SYMBOL_MAX_LENGTH)));
	SetTrieValue(behaviourType, BEHAVIOUR_TYPE_BEHAVIOURS, CreateArray());

	// Then push the new behaviour type to the global array and trie
	// Make sure to lower the case of name
	PushArrayCell(g_hArrayBehaviourTypes, behaviourType);
	SetTrieValueCaseInsensitive(g_hTrieBehaviourTypes, name, behaviourType);

	// Add behaviour type to game mode
	AddBehaviourType(GetInitializingGameMode(), BehaviourType:behaviourType);

	error = BehaviourTypeCreationError_None;
	return BehaviourType:behaviourType;
}

// Searches for a behaviour type from a name
stock BehaviourType:FindBehaviourType(const String:name[])
{
	new BehaviourType:behaviourType;
	if (GetTrieValueCaseInsensitive(g_hTrieBehaviourTypes, name, behaviourType))
	{
		return behaviourType;
	}
	return INVALID_BEHAVIOUR_TYPE;
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
	// Only able to add requirements while initilizing the game mode - and only to a behaviour of that game mode
	if (GetBehaviourTypeOwner(behaviourType) == GetInitializingGameMode())
	{
		PushArrayString(GetBehaviourTypeRequirements(behaviourType), requirement);
		return true;
	}
	return false;
}

// Checks if a plugin meets the requirements to be a behaviour of this type
stock bool:BehaviourTypeCheck(BehaviourType:behaviourType, Behaviour:behaviour)
{
	#if defined DEBUG || defined DEBUG_LOG

	new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
	GetBehaviourTypeName(behaviourType, behaviourTypeName, sizeof(behaviourTypeName));

	#endif

	new String:functionName[SYMBOL_MAX_LENGTH];

	new Handle:requirements = GetBehaviourTypeRequirements(behaviourType);
	new count = GetArraySize(requirements);
	for (new i = 0; i < count; i++)
	{
		GetArrayString(requirements, i, functionName, sizeof(functionName));
		if (GetFunctionInBehaviour(behaviour, functionName) == INVALID_FUNCTION)
		{
			DEBUG_PRINT3("Gamma:BehaviourTypePluginCheck(\"%s\", %X) : No match (%s)", behaviourTypeName, behaviour, functionName);
			return false;
		}
	}

	DEBUG_PRINT2("Gamma:BehaviourTypePluginCheck(\"%s\", %X) : Match", behaviourTypeName, behaviour);
	return true;
}

// Checks if the behaviour type owns the behaviour
stock bool:BehaviourTypeOwnsBehaviour(BehaviourType:behaviourType, Behaviour:behaviour)
{
	new BehaviourType:type = GetBehaviourType(behaviour);
	return (type == behaviourType);
}

// Adds a behaviour to the behaviour types behaviour list
stock AddBehaviourTypeBehaviour(BehaviourType:behaviourType, Behaviour:behaviour)
{
	new Handle:behaviours = GetBehaviourTypeBehaviours(behaviourType);
	PushArrayCell(behaviours, behaviour);
}

// Removes a behaviour from the behaviour types behaviour list
stock RemoveBehaviourTypeBehaviour(BehaviourType:behaviourType, Behaviour:behaviour)
{
	new Handle:behaviours = GetBehaviourTypeBehaviours(behaviourType);
	RemoveFromArray(behaviours, FindValueInArray(behaviours, behaviour));
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

// Gets a random behaviour
stock bool:BehaviourTypeHasBehaviours(BehaviourType:behaviourType)
{
	new Handle:behaviours = GetBehaviourTypeBehaviours(behaviourType);
	return (GetArraySize(behaviours) > 0);
}

// Gets a random behaviour
stock Behaviour:GetRandomBehaviour(BehaviourType:behaviourType)
{
	new Handle:behaviours = GetBehaviourTypeBehaviours(behaviourType);
	if (GetArraySize(behaviours) > 0)
	{
		return GetArrayBehaviour(behaviours, GetRandomInt(0, GetArraySize(behaviours) - 1));
	}
	return INVALID_BEHAVIOUR;
}

// Destroys the behaviour type
stock DestroyBehaviourType(BehaviourType:behaviourType)
{
	new String:behaviourTypeName[BEHAVIOUR_TYPE_NAME_MAX_LENGTH];
	GetBehaviourTypeName(behaviourType, behaviourTypeName, sizeof(behaviourTypeName));

	DEBUG_PRINT1("Gamma:DestroyBehaviourType(\"%s\")", behaviourTypeName);

	// Remove from global array and trie
	RemoveFromArray(g_hArrayBehaviourTypes, FindValueInArray(g_hArrayBehaviourTypes, behaviourType));
	RemoveFromTrieCaseInsensitive(g_hTrieBehaviourTypes, behaviourTypeName);


	// Close the requirements handle
	new Handle:requirements = GetBehaviourTypeRequirements(behaviourType);
	CloseHandle(requirements);

	// Destroy all child behaviours
	DEBUG_PRINT1("Gamma:DestroyBehaviourType(\"%s\") : Destroy Behaviours", behaviourTypeName);
	new Handle:behaviours = GetBehaviourTypeBehaviours(behaviourType);
	DECREASING_LOOP(i,GetArraySize(behaviours))
	{
		new Behaviour:behaviour = GetArrayBehaviour(behaviours, i);
		DestroyBehaviour(behaviour);
	}
	DEBUG_PRINT1("Gamma:DestroyBehaviourType(\"%s\") : Destroyed Behaviours", behaviourTypeName);

	// Destroy the behaviors array and then the behaviour type trie
	CloseHandle(behaviours);
	CloseHandle(Handle:behaviourType);
}