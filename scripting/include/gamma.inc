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
 *	MISC					
 *******************************************************************************/

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
 *	@noreturn
 */
forward Gamma_OnGameModeEnd();

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
 */
forward Gamma_OnGameModeEnded(GameMode:gameMode);




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
 *	Returns an ADT array with Behaviours
 *
 *	@param behaviourType	Behaviour type to look for
 *	@return					ADT array with behaviours
 *	@note					Must be closed with CloseHandle!
 */
native Handle:Gamma_GetBehaviourTypeBehaviours(BehaviourType:behaviourType);




/*******************************************************************************
 *	BEHAVIORS					
 *******************************************************************************/

/**
 *	Registers the current plugin as a behaviour of behaviourType
 *	Behaviours aren't allowed to used within any context, so a behaviour type must always be specified
 *	While it's possible to have the same Behaviour in different game modes, it's recommended to have only one per plugin unless they do exactly the same
 *
 *	@param behaviourType	Behaviour type to "implement"
 *	@param behaviourName	Name of the registered behaviour
 *	@return					Behaviour identifier
 *	@error					Behaviour with same name exists or plugin has already registered a behaviour for same game mode
 */
native Behaviour:Gamma_RegisterBehaviour(BehaviourType:behaviourType, const String:behaviourName[]);

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
 *	Gets the players possessed by the behaviour
 *
 *	@param behaviour	Behaviour to get the possessed players from
 *	@return				Handle to and ADT array containing the possessed players
 *	@note				Handle must be closed!
 */
native Handle:Gamma_GetPossessedPlayers(Behaviour:behaviour);

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

/**
 *	Called on the owning behaviour when it's given to a client
 *
 *	@param client		Client the behaviour was given to
 *	@noreturn
 */
forward Gamma_OnBehaviourPossessingClient(client);

/**
 *	Called on the owning behaviour when it's taken from a client
 *
 *	@param client		Client the behaviour was taken from
 *	@noreturn
 */
forward Gamma_OnBehaviourReleasingClient(client);

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
 *	@noreturn
 */
forward Gamma_OnBehaviourReleasedClient(client, Behaviour:behaviour);

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

// So we have FEATURECAP_PLAYERRUNCMD_11PARAMS
#include <sdktools_hooks>




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
 *	GAME MODE PROPERTIES
 *******************************************************************************/

/**
 *	Sets a property on the game mode
 *
 *	@param gameMode			Game mode reference
 *	@param property			Key to the property
 *	@param value			Value to store in the property
 *	@noreturn
 */
native Gamma_SetGameModeValue(GameMode:gameMode, const String:property[], any:value);

/**
 *	Sets a property on the game mode
 *
 *	@param gameMode			Game mode reference
 *	@param property			Key to the property
 *	@param array			Array to store in the property
 *	@param num_items		Number of items in the array
 *	@noreturn
 */
native Gamma_SetGameModeArray(GameMode:gameMode, const String:property[], any:array[], num_items);

/**
 *	Sets a property on the game mode
 *
 *	@param gameMode			Game mode reference
 *	@param property			Key to the property
 *	@param value			String to store in the property
 *	@noreturn
 */
native Gamma_SetGameModeString(GameMode:gameMode, const String:property[], const String:value[]);

/**
 *	Gets a property on the game mode
 *
 *	@param gameMode			Game mode reference
 *	@param property			Key to the property
 *	@param value			Variable to store value
 *	@return					True on success, false if the the property is not set or is not set as a value
 */
native bool:Gamma_GetGameModeValue(GameMode:gameMode, const String:property[], &any:value);

/**
 *	Gets a property on the game mode
 *
 *	@param gameMode			Game mode reference
 *	@param property			Key to the property
 *	@param array			Buffer to store array
 *	@param max_size			Maximum size of the array
 *	@param written			Optional parameter to store the number of elements written to the buffer
 *	@return					True on success, false if the the property is not set or is not set as an array
 */
native bool:Gamma_GetGameModeArray(GameMode:gameMode, const String:property[], any:array[], max_size, &written=0);

/**
 *	Gets a property on the game mode
 *
 *	@param gameMode			Game mode reference
 *	@param property			Key to the property
 *	@param value			Buffer to store string
 *	@param max_size			Maximum size of the string
 *	@param written			Optional parameter to store the number of elements written to the buffer
 *	@return					True on success, false if the the property is not set or is not set as a string
 */
native bool:Gamma_GetGameModeString(GameMode:gameMode, const String:property[], String:value[], max_size, &written=0);




/*******************************************************************************
 *	BEHAVIOUR PROPERTIES
 *******************************************************************************/

/**
 *	Sets a property in the behaviour
 *
 *	@param behaviour		Behaviour reference
 *	@param property			Key to the property
 *	@param value			Value to store in the property
 *	@noreturn
 */
native Gamma_SetBehaviourValue(Behaviour:behaviour, const String:property[], any:value);

/**
 *	Sets a property in the behaviour
 *
 *	@param behaviour		Behaviour reference
 *	@param property			Key to the property
 *	@param array			Array to store in the property
 *	@param num_items		Number of items in the array
 *	@noreturn
 */
native Gamma_SetBehaviourArray(Behaviour:behaviour, const String:property[], any:array[], num_items);

/**
 *	Sets a property in the behaviour
 *
 *	@param behaviour		Behaviour reference
 *	@param property			Key to the property
 *	@param value			String to store in the property
 *	@noreturn
 */
native Gamma_SetBehaviourString(Behaviour:behaviour, const String:property[], const String:value[]);

/**
 *	Gets a property on the behaviour
 *
 *	@param behaviour		Behaviour reference
 *	@param property			Key to the property
 *	@param value			Variable to store value
 *	@return					True on success, false if the the property is not set or is not set as a value
 */
native bool:Gamma_GetBehaviourValue(Behaviour:behaviour, const String:property[], &any:value);

/**
 *	Gets a property on the behaviour
 *
 *	@param behaviour		Behaviour reference
 *	@param property			Key to the property
 *	@param array			Buffer to store array
 *	@param max_size			Maximum size of the array
 *	@param written			Optional parameter to store the number of elements written to the buffer
 *	@return					True on success, false if the the property is not set or is not set as an array
 */
native bool:Gamma_GetBehaviourArray(Behaviour:behaviour, const String:property[], any:array[], max_size, &written=0);

/**
 *	Gets a property on the behaviour
 *
 *	@param behaviour		Behaviour reference
 *	@param property			Key to the property
 *	@param value			Buffer to store string
 *	@param max_size			Maximum size of the string
 *	@param written			Optional parameter to store the number of elements written to the buffer
 *	@return					True on success, false if the the property is not set or is not set as a string
 */
native bool:Gamma_GetBehaviourString(Behaviour:behaviour, const String:property[], String:value[], max_size, &written=0);




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
	// TODO: Add native to forcefully end the game mode?

	// Behaviour type natives
	MarkNativeAsOptional("Gamma_CreateBehaviourType");
	MarkNativeAsOptional("Gamma_FindBehaviourType");
	MarkNativeAsOptional("Gamma_GetBehaviourTypeName");
	MarkNativeAsOptional("Gamma_AddBehaviourTypeRequirement");
	MarkNativeAsOptional("Gamma_GetBehaviourTypeBehaviours");

	// Behaviour natives
	MarkNativeAsOptional("Gamma_RegisterBehaviour");
	MarkNativeAsOptional("Gamma_GetBehaviourType");
	MarkNativeAsOptional("Gamma_GetBehaviourName");
	MarkNativeAsOptional("Gamma_GetPossessedPlayers");
	MarkNativeAsOptional("Gamma_AddBehaviourFunctionToForward");
	MarkNativeAsOptional("Gamma_RemoveBehaviourFunctionFromForward");
	MarkNativeAsOptional("Gamma_SimpleBehaviourFunctionCall");

	// Client natives
	MarkNativeAsOptional("Gamma_GiveBehaviour");
	MarkNativeAsOptional("Gamma_TakeBehaviour");
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