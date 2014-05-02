#if defined _gamma_included
 #endinput
#endif
#define _gamma_included

#include <sourcemod>

// Maximum length a game mode name can be, including the NULL terminator
#define GAME_MODE_NAME_MAX_LENGTH 32

// Maximum length a behaviour type name can be, including the NULL terminator
#define BEHAVIOUR_TYPE_NAME_MAX_LENGTH 32

// Maximum length a behaviour name can be, including the NULL terminator
#define BEHAVIOUR_NAME_MAX_LENGTH 32

// The maximum size of the full name of a behaviour
#define BEHAVIOUR_FULL_NAME_MAX_LENGTH BEHAVIOUR_TYPE_NAME_MAX_LENGTH+BEHAVIOUR_NAME_MAX_LENGTH

/*******************************************************************************
 *	TYPE ENUMS					
 *******************************************************************************/

/**
 *	GameMode wrapper around Handle, for "type safety"
 */
enum GameMode
{
	INVALID_GAME_MODE = INVALID_HANDLE
}

/**
 *	BehaviourType wrapper around Handle, for "type safety"
 */
enum BehaviourType
{
	INVALID_BEHAVIOUR_TYPE = INVALID_HANDLE
}

/**
 *	Behaviour wrapper around Handle, for "type safety"
 */
enum Behaviour
{
	INVALID_BEHAVIOUR = INVALID_HANDLE
}


/*******************************************************************************
 *	REASON ENUMS					
 *******************************************************************************/

/**
 *	The reason the game mode ended
 */
enum GameModeEndReason
{
	GameModeEndReason_RoundEnded,
	GameModeEndReason_ForceStopped,
}

/**
 *	The reason the game mode ended
 */
enum BehaviourReleaseReason
{
	BehaviourReleaseReason_GameModeTook,
	BehaviourReleaseReason_GameModeEnded,
	BehaviourReleaseReason_BehaviourUnloaded,
	BehaviourReleaseReason_ClientDisconnected,
}


/*******************************************************************************
 *	MISC					
 *******************************************************************************/

/**
 *	Called when Gamma runs it auto detection during round start, if it's the first time it sees the plugin
 *	This is inteded to be used for creation of game modes
 *
 *	@noreturn
 */
forward Gamma_PluginDetected();

/**
 *	Returns an ADT array with all game modes
 *
 *	@return		ADT array with all game modes
 *	@note		Must be closed with CloseHandle!
 */
native Handle:Gamma_GetAllGameModes();

/**
 *	Returns the currently running game mode
 *
 *	@return		Current game mode or INVALID_GAME_MODE
 */
native GameMode:Gamma_GetCurrentGameMode();



/*******************************************************************************
 *	GAME MODES 					
 *******************************************************************************/

/**
 *	Called on the game mode when its being registered
 *	This can be used for initializing things that should only be available 
 *	after the game mode is registered in the game mode manager
 *
 *	@noreturn
 */
forward Gamma_OnCreateGameMode();

/**
 *	Called on the game mode when it's being destroyed
 *	Use this is release things that are no longer needed when it's not
 *	registered in the game mode manager anymore
 *
 *	@noreturn
 */
forward Gamma_OnDestroyGameMode();

/**
 *	Called when a game mode is registered and created
 *	This forward can lie, it can also be called right after PluginDetected
 *	for all game modes created before detection
 *
 *	@noreturn
 */
forward Gamma_OnGameModeCreated(GameMode:gameMode);

/**
 *	Called when a game mode just before a game mode is wholely destroyed
 *
 *	@noreturn
 */
forward Gamma_OnGameModeDestroyed(GameMode:gameMode);

/**
 *	Called on the game mode selected in the game mode manager when a round starts
 *
 *	@return		True if the game mode can start, false otherwise
 */
forward bool:Gamma_IsGameModeAbleToStartRequest();

/**
 *	Called on the game mode selected in the game mode manager when a round starts, if OnCanStart returned true
 *
 *	@noreturn
 */
forward Gamma_OnGameModeStart();

/**
 *	Called on the game mode selected in the game mode manager when a round ends
 *
 *	@param reason	Reason the game mode ended
 *	@noreturn
 */
forward Gamma_OnGameModeEnd(GameModeEndReason:reason);

/**
 *	Called when the game mode has fully started, this is a global forward
 *
 *	@param gameMode		Reference to the game mode started
 */
forward Gamma_OnGameModeStarted(GameMode:gameMode);

/**
 *	Called when the game mode has fully ended, this is a global forward
 *
 *	@param gameMode		Reference to the game mode ended
 *	@param reason		Reason the game mode ended
 */
forward Gamma_OnGameModeEnded(GameMode:gameMode, GameModeEndReason:reason);

/**
 *	Registers the current plugin as a game mode in the game mode manager, only one game mode can be registered per plugin
 *
 *	@param name		Name of the game mode
 *	@return			GameMode reference
 *	@error			Game mode with same name exists, plugin has already registered a game mode or creation failed
 */
native GameMode:Gamma_RegisterGameMode(const String:name[]);

/**
 *	Finds a game mode by name
 *
 *	@param name		Name of the game mode to search for
 *	@return			GameMode reference or INVALID_GAME_MODE if not found
 */
native GameMode:Gamma_FindGameMode(const String:name[]);

/**
 *	Gets the name of a game mode
 *
 *	@param gameMode		Game mode to get the name from
 *	@param buffer		Buffer to store game mode name in
 *	@param maxlen		Maximum size of the buffer
 */
native Gamma_GetGameModeName(GameMode:gameMode, String:buffer[], maxlen);

/**
 *	Returns an ADT array with all behaviour types for a game mode
 *
 *	@param gameMode		Game mode to get all behaviour types from
 *	@return 			ADT array with all behaviour types in the game mode
 *	@note				Must be closed with CloseHandle!
 */
native Handle:Gamma_GetGameModeBehaviourTypes(GameMode:gameMode);

/**
 *	Forces the game mode to end
 *	Can only be called by the currently active game mode
 *
 *	@noreturn
 */
native Gamma_ForceStopGameMode();



/*******************************************************************************
 *	BEHAVIOR TYPES				
 *******************************************************************************/

/**
 *	Creates a new BehaviourType with the specified name
 *
 *	@param name		Name of the behaviour type
 *	@return			Reference to the new behaviour type
 *	@error			Behaviour type of same name exists or not called in Gamma_OnCreateGameMode
 */
native BehaviourType:Gamma_CreateBehaviourType(const String:name[]);

/**
 *	Creates a new BehaviourType with the specified name
 *
 *	@param name		Name of the behaviour type
 *	@return			Reference to the new behaviour type or INVALID_BEHAVIOUR_TYPE if no behaviour type was found
 */
native BehaviourType:Gamma_FindBehaviourType(const String:name[]);

/**
 *	Gets the name of a behaviour type
 *
 *	@param behaviourType	Behaviour type to get the name from
 *	@param buffer			Buffer to store the behaviour type's name in
 *	@param maxlen			Maximum length of the string buffer (includes NULL terminator)
 *	@noreturn
 */
native Gamma_GetBehaviourTypeName(BehaviourType:behaviourType, String:buffer[], maxlen);

/**
 *	Adds a function requirement to the behaviour type
 *
 *	@param behaviourType	Behaviour type to add the requirement to
 *	@param functionName		Name of the function that the behaviour must implement
 *	@noreturn
 *	@error					Called outside of Gamma_OnCreateGameMode
 */
native Gamma_AddBehaviourTypeRequirement(BehaviourType:behaviourType, const String:functionName[]);

/**
 *	Gets whether or not the behaviour type type owns the behaviour
 *
 *	@param behahviourType	Behaviour type see if behaviour is a child of
 *	@param behaviour		Behaviour to check the behaviour type from
 *	@return					True if the behaviour type owns the behaviour type, false otherwise
 */
native bool:Gamma_BehaviourTypeOwnsBehaviour(BehaviourType:behaviourType, Behaviour:behaviour);

/**
 *	Returns an ADT array with Behaviours
 *
 *	@param behaviourType	Behaviour type to look for
 *	@return					ADT array with behaviours
 *	@note					Must be closed with CloseHandle!
 */
native Handle:Gamma_GetBehaviourTypeBehaviours(BehaviourType:behaviourType);

/**
 *	Returns whether or not a behaviour type has registered behaviours
 *
 *	@param behaviourType	Behaviour type to see if it has any behaviours
 *	@return					True if it has behaviours, false otherwise
 */
native bool:Gamma_BehaviourTypeHasBehaviours(BehaviourType:behaviourType);

/**
 *	Gets a random behaviour of type
 *
 *	@param behaviourType	Behaviour type to get a random behaviour of
 *	@return					Behaviour if the behaviour type has behaviours, otherwise INVALID_BEHAVIOUR
 */
native Behaviour:Gamma_GetRandomBehaviour(BehaviourType:behaviourType);



/*******************************************************************************
 *	BEHAVIORS					
 *******************************************************************************/

/**
 *	Sets a function override, only works for forwards called/referred to using
 *	Gamma_BehaviourHasFunction, Gamma_AddBehaviourFunctionToForward
 *	Gamma_RemoveBehaviourFunctionFromForward and Gamma_SimpleBehaviourFunctionCall
 *	Can only be called in Gamma_OnCreateBehaviour
 *
 *	@param functionName	Name of the function to override
 *	@param behaviour	Function to point to instead
 *	@return				True if the function was found, false otherwise
 *	@error				Not in Gamma_OnCreateBehaviour
 */
native Gamma_SetBehaviourFunctionOverride(const String:functionName[], Function:function);

/**
 *	Called on the game mode when its being registered
 *	This can be used for initializing things that should only be available 
 *	after the game mode is registered in the game mode manager
 *
 *	@noreturn
 */
forward Gamma_OnCreateBehaviour();
functag public Gamma_OnCreateBehaviourTag();


/**
 *	Called on the game mode when it's being destroyed
 *	Use this is release things that are no longer needed when it's not
 *	registered in the game mode manager anymore
 *
 *	@noreturn
 */
forward Gamma_OnDestroyBehaviour();
functag public Gamma_OnDestroyBehaviourTag();

/**
 *	Called when a game mode is registered and created
 *	This forward can lie, it can also be called right after PluginDetected
 *	for all behaviours created before detection
 *
 *	@param behaviour	Behaviour just created
 *	@noreturn
 */
forward Gamma_OnBehaviourCreated(Behaviour:behaviour);
/**
 *	Called when a game mode just before a game mode is wholely destroyed
 *
 *	@param behaviour	Behaviour just destroyed
 *	@noreturn
 */
forward Gamma_OnBehaviourDestroyed(Behaviour:behaviour);

/**
 *	Called on the owning behaviour when it's given to a client
 *
 *	@param client		Client the behaviour was given to
 *	@noreturn
 */
forward Gamma_OnBehaviourPossessingClient(client);
functag public Gamma_OnBehaviourPossessingClientTag(client);

/**
 *	Called on the owning behaviour when it's taken from a client
 *
 *	@param client		Client the behaviour was taken from
 *	@param reason		Reason the client was released
 *	@noreturn
 */
forward Gamma_OnBehaviourReleasingClient(client, BehaviourReleaseReason:reason);
functag public Gamma_OnBehaviourReleasingClientTag(client, BehaviourReleaseReason:reason);

/**
 *	Called after a client has been given a behaviour
 *
 *	@param client		Client the behaviour was given to
 *	@param behaviour	Behaviour that was given
 *	@noreturn
 */
forward Gamma_OnBehaviourPossessedClient(client, Behaviour:behaviour);

/**
 *	Called after a client has lost a behaviour
 *
 *	@param client		Client the behaviour was given to
 *	@param behaviour	Behaviour that was given
 *	@param reason		Reason the client was released
 *	@noreturn
 */
forward Gamma_OnBehaviourReleasedClient(client, Behaviour:behaviour, BehaviourReleaseReason:reason);

/**
 *	Called on a behaviour when a clients movement buttons are being processed, if the client owns the behaviour
 *
 *	@param client		Index of the client.
 *	@param buttons		Copyback buffer containing the current commands (as bitflags - see entity_prop_stocks.inc).
 *	@param impulse		Copyback buffer containing the current impulse command.
 *	@param vel			Players desired velocity.
 *	@param angles		Players desired view angles.
 *	@param weapon		Entity index of the new weapon if player switches weapon, 0 otherwise.
 *	@param subtype		Weapon subtype when selected from a menu.
 *	@param cmdnum		Command number. Increments from the first command sent.
 *	@param tickcount	Tick count. A client's prediction based on the server's GetGameTickCount value.
 *	@param seed			Random seed. Used to determine weapon recoil, spread, and other predicted elements.
 *	@param mouse		Mouse direction (x, y).
 *
 *	@return 			Plugin_Handled to block the commands from being processed, Plugin_Continue otherwise.
 *
 *	@note				To see if all 11 params are avaliable, use FeatureType_Capability and
 *						FEATURECAP_PLAYERRUNCMD_11PARAMS.
 */
forward Action:Gamma_OnBehaviourPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2]);
functag public Action:Gamma_OnBehaviourPlayerRunCmdTag(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2]);

// So we have FEATURECAP_PLAYERRUNCMD_11PARAMS
#include <sdktools_hooks>

/**
 *	Sets OnBehaviourPossessingClient override
 *
 *	@param onPossessingClient	Function to use instead of the forward Gamma_OnBehaviourPossessingClient
 */
stock Gamma_SetBehaviourPossessingClientOverride(Gamma_OnBehaviourPossessingClientTag:onPossessingClient)
{
	Gamma_SetBehaviourFunctionOverride("Gamma_OnBehaviourPossessingClient", onPossessingClient);
}

/**
 *	Sets OnBehaviourReleasingClient override
 *
 *	@param onReleasingClient	Function to use instead of the forward Gamma_OnBehaviourReleasingClient
 */
stock Gamma_SetBehaviourReleasingClientOverride(Gamma_OnBehaviourPossessingClientTag:onReleasingClient)
{
	Gamma_SetBehaviourFunctionOverride("Gamma_OnBehaviourReleasingClient", onReleasingClient);
}

/**
 *	Sets OnBehaviourPlayerRunCmd override
 *
 *	@param onBehaviourRunCmd	Function to use instead of the forward Gamma_OnBehaviourPlayerRunCmd
 */
stock Gamma_SetBehaviourPlayerRunCmdOverride(Gamma_OnBehaviourPlayerRunCmdTag:onBehaviourRunCmd)
{
	Gamma_SetBehaviourFunctionOverride("Gamma_OnBehaviourPlayerRunCmd", onBehaviourRunCmd);
}

/**
 *	Sets OnDestroyBehaviour override
 *
 *	@param onDestroyBehaviour	Function to use instead of the forward Gamma_OnDestroyBehaviour
 */
stock Gamma_SetDestroyBehaviourOverride(Gamma_OnDestroyBehaviourTag:onDestroyBehaviour)
{
	Gamma_SetBehaviourFunctionOverride("Gamma_OnDestroyBehaviour", onDestroyBehaviour);
}

/**
 *	Registers the current plugin as a behaviour of behaviourType
 *	Behaviours aren't allowed to used within any context, so a behaviour type must always be specified
 *	While it's possible to have the same Behaviour in different game modes, it's recommended to have only one per plugin unless they do exactly the same
 *
 *	@param behaviourType		Behaviour type to "implement"
 *	@param behaviourName		Name of the registered behaviour
 *	@param onCreateBehaviour	Optional override function for Gamma_OnCreateBehaviour
 *	@return						Behaviour identifier
 *	@error						Behaviour with same name exists
 */
native Behaviour:Gamma_RegisterBehaviour(BehaviourType:behaviourType, const String:behaviourName[], Gamma_OnCreateBehaviourTag:onCreateBehaviour=INVALID_FUNCTION);

/**
 *	Gets the behaviour type of a behaviour
 *
 *	@param behaviour	Behaviour to get the behaviour type from
 *	@return				Behaviour type of the behaviour
 */
native BehaviourType:Gamma_GetBehaviourType(Behaviour:behaviour);

/**
 *	Gets the name of a behaviour
 *
 *	@param behaviour	Behaviour to get the name from
 *	@param buffer		Buffer to store the behaviours name in
 *	@param maxlen		Maximum length of the string buffer (includes NULL terminator)
 *	@noreturn
 */
native Gamma_GetBehaviourName(Behaviour:behaviour, String:buffer[], maxlen);

/**
 *	Gets the full name of a behaviour
 *
 *	@param behaviour	Behaviour to get the full name from
 *	@param buffer		Buffer to store the behaviours full name in
 *	@param maxlen		Maximum length of the string buffer (includes NULL terminator)
 *	@noreturn
 */
native Gamma_GetBehaviourFullName(Behaviour:behaviour, String:buffer[], maxlen);

/**
 *	Gets the players possessed by the behaviour
 *
 *	@param behaviour	Behaviour to get the possessed players from
 *	@return				Handle to and ADT array containing the possessed players
 *	@note				Handle must be closed!
 */
native Handle:Gamma_GetPossessedPlayers(Behaviour:behaviour);

/**
 *	Gets whether or not a Behaviour has implemented a function
 *
 *	@param behaviour	Behaviour to check whether or not has implemented a function
 *	@param functionName	Name of the function to check exists
 *	@return				True if the function was found, false otherwise
 */
native bool:Gamma_BehaviourHasFunction(Behaviour:behaviour, const String:functionName[]);

/**
 *	Adds a function in the behaviour to the forward, if it exists
 *
 *	@param behaviour	Behaviour to fetch function from
 *	@param functionName	Name of the function to get
 *	@param fwd			Forward to add the function to
 *	@return				True if the function was found, false otherwise
 */
native bool:Gamma_AddBehaviourFunctionToForward(Behaviour:behaviour, const String:functionName[], Handle:fwd);

/**
 *	Removes a function in the behaviour from the forward, if it exists
 *
 *	@param behaviour	Behaviour to fetch function from
 *	@param functionName	Name of the function to get
 *	@param fwd			Forward to add the function to
 *	@return				True if the function was found, false otherwise
 */
native bool:Gamma_RemoveBehaviourFunctionFromForward(Behaviour:behaviour, const String:functionName[], Handle:fwd);

/**
 *	Calls a function in the behaviour, if it exists
 *	However parameters are limited to cells
 *
 *	@param behaviour		Behaviour to call the function in
 *	@param functionName		Name of the function to call
 *	@param defaultValue		Default return value
 *	@param ...				Parameters to pass onto the function call
 *	@return					Return value of the function or default return value
 */
native Gamma_SimpleBehaviourFunctionCall(Behaviour:behaviour, const String:functionName[], any:defaultValue=0, any:...);



/*******************************************************************************
 *	CLIENTS					
 *******************************************************************************/

/**
 *	Gives a client a Behaviour
 *	Can only be called by the current game mode's plugin
 *
 *	@param client		Client index to give the behaviour to
 *	@param behaviour	Behaviour to give to the client
 *	@noreturn
 *	@error				Invalid client index or INVALID_BEHAVIOUR
 */
native Gamma_GiveBehaviour(client, Behaviour:behaviour);

/**
 *	Takes a clients Behaviour
 *	Can only be called by the current game mode's plugin
 *
 *	@param client		Client index to take the behaviour from
 *	@param behaviour	Behaviour to take from the client
 *	@noreturn
 *	@error				Invalid client index or INVALID_BEHAVIOUR
 */
native Gamma_TakeBehaviour(client, Behaviour:behaviour);

/**
 *	Gives a client a random Behaviour
 *	Can only be called by the current game mode's plugin
 *
 *	@param client			Client index to give the behaviour to
 *	@param behaviourType	A random behaviour of this type to give to the client
 *	@return					Behaviour given or INVALID_BEHAVIOUR
 *	@error					Invalid client index or INVALID_BEHAVIOUR_TYPE
 */
native Behaviour:Gamma_GiveRandomBehaviour(client, BehaviourType:behaviourType);

/**
 *	Gets all the behaviours possessing a player
 *
 *	@param client	Client index to get behaviours from
 *	@param filter	Behaviour type filter, INVALID_BEHAVIOUR_TYPE to get all behaviours
 *	@return			Handle to an ADT array containing the players behaviours
 *	@note			Handle must be closed!
 *	@error			Invalid client index
 */
native Handle:Gamma_GetPlayerBehaviours(client, BehaviourType:filter=INVALID_BEHAVIOUR_TYPE);



/*******************************************************************************
 *	STOCKS				
 *******************************************************************************/

/**
 *	Retrives a game mode from an array
 *
 *	@param array	Array handle
 *	@param index	Index in array
 *	@param block	Optionally specify which block to read from (useful if the blocksize > 0)
 *	@return			Game mode read
 *	@error			Invalid Handle, invalid index, or invalid block
 */
stock GameMode:GetArrayGameMode(Handle:array, index, block=0)
{
	return GameMode:GetArrayCell(array, index, block);
}

/**
 *	Retrives a behaviour type from an array
 *
 *	@param array	Array handle
 *	@param index	Index in array
 *	@param block	Optionally specify which block to read from (useful if the blocksize > 0)
 *	@return			Behaviour type read
 *	@error			Invalid Handle, invalid index, or invalid block
 */
stock BehaviourType:GetArrayBehaviourType(Handle:array, index, block=0)
{
	return BehaviourType:GetArrayCell(array, index, block);
}

/**
 *	Retrives a behaviour from an array
 *
 *	@param array	Array handle
 *	@param index	Index in array
 *	@param block	Optionally specify which block to read from (useful if the blocksize > 0)
 *	@return			Behaviour read
 *	@error			Invalid Handle, invalid index, or invalid block
 */
stock Behaviour:GetArrayBehaviour(Handle:array, index, block=0)
{
	return Behaviour:GetArrayCell(array, index, block);
}




/*******************************************************************************
 *	SPECIAL
 *******************************************************************************/

/**
 *	Tells the game mode manager the plugin is unloading
 *	IT MUST ALWAYS BE CALLED OnPluginEnd() IF YOU CREATE BEHAVIOURS OR GAME MODES
 *	If you require to use OnPluginEnd() then define GAMMA_MANUAL_UNLOAD_NOTIFY and make sure to call this function
 *
 *	@noreturn
 */
native __GAMMA_PluginUnloading();

#if !defined GAMMA_MANUAL_UNLOAD_NOTIFICATION

#if (defined GAMMA_CONTAINS_GAME_MODE || defined GAMMA_CONTAINS_BEHAVIOUR)
public OnPluginEnd()
{
	if (LibraryExists("gamma"))
	{
		__GAMMA_PluginUnloading();
	}
}
#endif // (defined GAMMA_CONTAINS_GAME_MODE || defined GAMMA_CONTAINS_BEHAVIOUR)

#endif// !defined GAMMA_MANUAL_UNLOAD_NOTIFICATION





// No touchy
public SharedPlugin:__pl_gamma = 
{
    name = "gamma",
    file = "gamma.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_gamma_SetNTVOptional()
{
	// Misc natives
	MarkNativeAsOptional("Gamma_GetAllGameModes");
	MarkNativeAsOptional("Gamma_GetCurrentGameMode");

	// Game mode natives
	MarkNativeAsOptional("Gamma_RegisterGameMode");
	MarkNativeAsOptional("Gamma_FindGameMode");
	MarkNativeAsOptional("Gamma_GetGameModeName");
	MarkNativeAsOptional("Gamma_GetGameModeBehaviourTypes");
	MarkNativeAsOptional("Gamma_ForceStopGameMode");

	// Behaviour type natives
	MarkNativeAsOptional("Gamma_CreateBehaviourType");
	MarkNativeAsOptional("Gamma_FindBehaviourType");
	MarkNativeAsOptional("Gamma_GetBehaviourTypeName");
	MarkNativeAsOptional("Gamma_AddBehaviourTypeRequirement");
	MarkNativeAsOptional("Gamma_BehaviourTypeOwnsBehaviour");
	MarkNativeAsOptional("Gamma_GetBehaviourTypeBehaviours");
	MarkNativeAsOptional("Gamma_BehaviourTypeHasBehaviours");
	MarkNativeAsOptional("Gamma_GetRandomBehaviour");

	// Behaviour natives
	MarkNativeAsOptional("Gamma_RegisterBehaviour");
	MarkNativeAsOptional("Gamma_GetBehaviourType");
	MarkNativeAsOptional("Gamma_GetBehaviourName");
	MarkNativeAsOptional("Gamma_GetBehaviourFullName");
	MarkNativeAsOptional("Gamma_GetPossessedPlayers");
	MarkNativeAsOptional("Gamma_BehaviourHasFunction");
	MarkNativeAsOptional("Gamma_AddBehaviourFunctionToForward");
	MarkNativeAsOptional("Gamma_RemoveBehaviourFunctionFromForward");
	MarkNativeAsOptional("Gamma_SimpleBehaviourFunctionCall");
	MarkNativeAsOptional("Gamma_SetBehaviourFunctionOverride");

	// Client natives
	MarkNativeAsOptional("Gamma_GiveBehaviour");
	MarkNativeAsOptional("Gamma_TakeBehaviour");
	MarkNativeAsOptional("Gamma_GiveRandomBehaviour");
	MarkNativeAsOptional("Gamma_GetPlayerBehaviours");

	// Game mode properties natives
	MarkNativeAsOptional("Gamma_SetGameModeValue");
	MarkNativeAsOptional("Gamma_SetGameModeArray");
	MarkNativeAsOptional("Gamma_SetGameModeString");
	MarkNativeAsOptional("Gamma_GetGameModeValue");
	MarkNativeAsOptional("Gamma_GetGameModeArray");
	MarkNativeAsOptional("Gamma_GetGameModeString");

	// Behaviour properties natives
	MarkNativeAsOptional("Gamma_SetBehaviourValue");
	MarkNativeAsOptional("Gamma_SetBehaviourArray");
	MarkNativeAsOptional("Gamma_SetBehaviourString");
	MarkNativeAsOptional("Gamma_GetBehaviourValue");
	MarkNativeAsOptional("Gamma_GetBehaviourArray");
	MarkNativeAsOptional("Gamma_GetBehaviourString");

	// Special natives
	MarkNativeAsOptional("__GAMMA_PluginUnloading");
}
#endif