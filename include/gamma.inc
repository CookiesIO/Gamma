#if defined _gamma_included
 #endinput
#endif
#define _gamma_included

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
	INVALID_GAME_MODE = -1
}

/**
 *	BehaviourType wrapper around Handle, for "type safety"
 */
enum BehaviourType
{
	INVALID_BEHAVIOUR_TYPE = -1
}

/**
 *	Behaviour wrapper around Handle, for "type safety"
 */
enum Behaviour
{
	INVALID_BEHAVIOUR = -1
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
native Handle:GetAllGameModes();

/**
 *	Returns the currently running game mode
 *
 *	@return		Current game mode or INVALID_GAME_MODE
 */
native GameMode:GameMode_GetCurrent();




/*******************************************************************************
 *	GAME MODE 					
 *******************************************************************************/

/**
 *	Registers the current plugin as a game mode in the game mode manager, only one game mode can be registered per plugin
 *
 *	@param name		Name of the game mode
 *	@return			GameMode identifier or INVALID_GAME_MODE if there's already a game mode with the same name
 */
native GameMode:RegisterGameMode(String:name[]);

/**
 *	Returns an ADT array with all behaviour types for a game mode
 *
 *	@param gameMode		Game mode to get all behaviour types from
 *	@return 			ADT array with all behaviour types in the game mode
 *	@note				Must be closed with CloseHandle!
 */
native Handle:GameMode_GetAllBehaviourTypes(GameMode:gameMode);

/**
 *	Adds an acknowledged BehaviourType to the game mode, only BehaviourTypes acknowledged by the game mode can be used in the game mode
 *
 *	@param gameMode	The game mode to add the behaviour type to
 *	@param type		The BehaviourType to add
 *	@noreturn
 *	@error			Invalid BehaviourType or already added by another game mode or invalid game mode
 */
native GameMode_AddBehaviourType(GameMode:gameMode, BehaviourType:type);

/**
 *	Gives a client a Behaviour
 *	Can only be called by the current game mode's plugin
 *
 *	@param client		Client index to give the behaviour to
 *	@param behaviour	Behaviour to give to the client
 *	@noreturn
 *	@error				Invalid client index or INVALID_BEHAVIOUR
 */
native GameMode_GiveBehaviour(client, Behaviour:behaviour);

/**
 *	Takes a clients Behaviour
 *	Can only be called by the current game mode's plugin
 *
 *	@param client		Client index to take the behaviour from
 *	@param behaviour	Behaviour to take from the client
 *	@noreturn
 *	@error				Invalid client index or INVALID_BEHAVIOUR
 */
native GameMode_TakeBehaviour(client, Behaviour:behaviour);

/**
 *	Called on the game mode when its being registered
 *	This can be used for initializing things that should only be available 
 *	after the game mode is registered in the game mode manager
 *
 *	@noreturn
 */
forward GameMode_OnCreate();

/**
 *	Called on the game mode when it's being destroyed
 *	Use this is release things that are no longer needed when it's not
 *	registered in the game mode manager anymore
 *
 *	@noreturn
 */
forward GameMode_OnDestroy();

/**
 *	Called when a game mode is registered and created
 *
 *	@noreturn
 */
forward GameMode_OnCreated(GameMode:gameMode);

/**
 *	Called when a game mode just before a game mode is wholely destroyed
 *
 *	@noreturn
 */
forward GameMode_OnDestroyed(GameMode:gameMode);

/**
 *	Called on the game mode selected in the game mode manager when a round starts
 *
 *	@return		True if the game mode can start, false otherwise
 */
forward bool:GameMode_OnCanStart();

/**
 *	Called on the game mode selected in the game mode manager when a round starts, if OnCanStart returned true
 *
 *	@noreturn
 */
forward GameMode_OnStart();

/**
 *	Called on the game mode selected in the game mode manager when a round ends
 *
 *	@noreturn
 */
forward GameMode_OnEnd();

/**
 *	Called when the game mode has fully started, this is a global forward
 *
 *	@param gameMode		Reference to the game mode started
 */
forward GameMode_OnStarted(GameMode:gameMode);

/**
 *	Called when the game mode has fully ended, this is a global forward
 *
 *	@param gameMode		Reference to the game mode ended
 */
forward GameMode_OnEnded(GameMode:gameMode);




/*******************************************************************************
 *	BEHAVIOR TYPE				
 *******************************************************************************/

/**
 *	Creates a new BehaviourType with the specified name
 *
 *	@param name		Name of the behaviour type
 *	@return			Reference to the new behaviour type or INVALID_BEHAVIOUR_TYPE if a behaviour type with the same name exists
 */
native BehaviourType:CreateBehaviourType(String:name[]);

/**
 *	Creates a new BehaviourType with the specified name
 *
 *	@param name		Name of the behaviour type
 *	@return			Reference to the new behaviour type or INVALID_BEHAVIOUR_TYPE if no behaviour type was found
 */
native BehaviourType:FindBehaviourType(String:name[]);

/**
 *	Gets the name of a behaviour type
 *
 *	@param behaviourType	Behaviour type to get the name from
 *	@param buffer			Buffer to store the behaviour type's name in
 *	@param maxlen			Maximum length of the string buffer (includes NULL terminator)
 *	@noreturn
 */
native BehaviourType_GetName(BehaviourType:behaviourType, String:buffer[], maxlen);

/**
 *	Adds a function requirement to the behaviour type
 *
 *	@param behaviourType	Behaviour type to add the requirement to
 *	@param functionName		Name of the function that the behaviour must implement
 *	@noreturn
 *	@error					The behaviour type is already associated with a game mode
 */
native BehaviourType_AddRequirement(BehaviourType:behaviourType, String:functionName[]);

/**
 *	Returns an ADT array with Behaviours
 *
 *	@param behaviourType	Behaviour type to look for
 *	@return					ADT array with behaviours
 *	@note					Must be closed with CloseHandle!
 */
native Handle:BehaviourType_GetAllBehaviours(BehaviourType:behaviourType);




/*******************************************************************************
 *	BEHAVIOR					
 *******************************************************************************/

/**
 *	Registers the current plugin as a behaviour of behaviourType
 *	Behaviours aren't allowed to used within any context, so a behaviour type must always be specified
 *	While it's possible to have the same Behaviour in different game modes, it's recommended to have only one per plugin unless they do exactly the same
 *
 *	@param behaviourType	Behaviour type to "implement"
 *	@param behaviourName	Name of the registered behaviour
 *	@return					Behaviour identifier or INVALID_BEHAVIOUR if a behaviour of the same type and name already exists
 */
native Behaviour:RegisterBehaviour(BehaviourType:behaviourType[], string:behaviourName[]);

/**
 *	Gets the behaviour type of a behaviour
 *
 *	@param behaviour	Behaviour to get the behaviour type from
 *	@return				Behaviour type of the behaviour
 */
native BehaviourType:Behaviour_GetType(Behaviour:behaviour);

/**
 *	Gets the name of a behaviour
 *
 *	@param behaviour	Behaviour to get the name from
 *	@param buffer		Buffer to store the behaviours name in
 *	@param maxlen		Maximum length of the string buffer (includes NULL terminator)
 *	@noreturn
 */
native Behaviour_GetName(Behaviour:behaviour, String:buffer[], maxlen);

/**
 *	Called on the owning behaviour when it's given to a client
 *
 *	@param client		Client the behaviour was given to
 *	@noreturn
 */
forward Behaviour_OnPossessing(client);

/**
 *	Called on the owning behaviour when it's taken from a client
 *
 *	@param client		Client the behaviour was taken from
 *	@noreturn
 */
forward Behaviour_OnReleasing(client);

/**
 *	Called after a client has been given a behaviour
 *
 *	@param client		Client the behaviour was given to
 *	@param behaviour	Behaviour that was given
 *	@noreturn
 */
forward Behaviour_OnClientPossessed(client, Behaviour:behaviour);

/**
 *	Called after a client has lost a behaviour
 *
 *	@param client		Client the behaviour was given to
 *	@param behaviour	Behaviour that was given
 *	@noreturn
 */
forward Behaviour_OnClientReleased(client, Behaviour:behaviour);

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
forward Action:Behaviour_OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2]);

// So we have FEATURECAP_PLAYERRUNCMD_11PARAMS
#include <sdktools_hooks>




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
native GameMode_SetPropertyValue(GameMode:gameMode, const String:property[], any:value);

/**
 *	Sets a property on the game mode
 *
 *	@param gameMode			Game mode reference
 *	@param property			Key to the property
 *	@param array			Array to store in the property
 *	@param num_items		Number of items in the array
 *	@noreturn
 */
native GameMode_SetPropertyArray(GameMode:gameMode, const String:property[], any:array[], num_items);

/**
 *	Sets a property on the game mode
 *
 *	@param gameMode			Game mode reference
 *	@param property			Key to the property
 *	@param value			String to store in the property
 *	@noreturn
 */
native GameMode_SetPropertyString(GameMode:gameMode, const String:property[], const String:value[]);

/**
 *	Gets a property on the game mode
 *
 *	@param gameMode			Game mode reference
 *	@param property			Key to the property
 *	@param value			Variable to store value
 *	@return					True on success, false if the the property is not set or is not set as a value
 */
native bool:GameMode_GetPropertyValue(GameMode:gameMode, const String:property[], &any:value);

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
native bool:GameMode_GetPropertyArray(GameMode:gameMode, const String:property[], any:array[], max_size, &written=0);

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
native bool:GameMode_GetPropertyString(GameMode:gameMode, const String:property[], String:value[], max_size, &written=0);




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
native Behaviour_SetPropertyValue(Behaviour:behaviour, const String:property[], any:value);

/**
 *	Sets a property in the behaviour
 *
 *	@param behaviour		Behaviour reference
 *	@param property			Key to the property
 *	@param array			Array to store in the property
 *	@param num_items		Number of items in the array
 *	@noreturn
 */
native Behaviour_SetPropertyArray(Behaviour:behaviour, const String:property[], any:array[], num_items);

/**
 *	Sets a property in the behaviour
 *
 *	@param behaviour		Behaviour reference
 *	@param property			Key to the property
 *	@param value			String to store in the property
 *	@noreturn
 */
native Behaviour_SetPropertyString(Behaviour:behaviour, const String:property[], const String:value[]);

/**
 *	Gets a property on the behaviour
 *
 *	@param behaviour		Behaviour reference
 *	@param property			Key to the property
 *	@param value			Variable to store value
 *	@return					True on success, false if the the property is not set or is not set as a value
 */
native bool:Behaviour_GetPropertyValue(Behaviour:behaviour, const String:property[], &any:value);

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
native bool:Behaviour_GetPropertyArray(Behaviour:behaviour, const String:property[], any:array[], max_size, &written=0);

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
native bool:Behaviour_GetPropertyString(Behaviour:behaviour, const String:property[], String:value[], max_size, &written=0);




/*******************************************************************************
 *	SPECIAL
 *******************************************************************************/

/**
 *	Tells the game mode manager the plugin is unloading
 *	IT MUST ALWAYS BE CALLED OnPluginEnd() IF YOU CREATE BEHAVIOURS, BEHAVIOUR TYPES OR GAME MODES
 *	Optionally, if you don't use OnPluginEnd() write GAMMA_NOTIFYUNLOAD above OnPluginStart()
 *
 *	@noreturn
 */
native __GAMMA_PluginUnloading();

#define GAMMA_NOTIFYUNLOAD public OnPluginEnd() { __GAMMA_PluginUnloading(); }






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
	MarkNativeAsOptional("GetAllGameModes");
	MarkNativeAsOptional("GameMode_GetCurrent");

	// Game mode natives
	MarkNativeAsOptional("RegisterGameMode");
	MarkNativeAsOptional("GameMode_GetAllBehaviourTypes");
	MarkNativeAsOptional("GameMode_AddBehaviourType");
	MarkNativeAsOptional("GameMode_GiveBehaviour");
	MarkNativeAsOptional("GameMode_TakeBehaviour");

	// Behaviour type natives
	MarkNativeAsOptional("CreateBehaviourType");
	MarkNativeAsOptional("FindBehaviourType");
	MarkNativeAsOptional("BehaviourType_GetName");
	MarkNativeAsOptional("BehaviourType_AddRequirement");
	MarkNativeAsOptional("BehaviourType_GetAllBehaviours");

	// Behaviour natives
	MarkNativeAsOptional("RegisterBehaviour");
	MarkNativeAsOptional("Behaviour_GetType");
	MarkNativeAsOptional("Behaviour_GetName");

	// Game mode properties natives
	MarkNativeAsOptional("GameMode_SetPropertyValue");
	MarkNativeAsOptional("GameMode_SetPropertyArray");
	MarkNativeAsOptional("GameMode_SetPropertyString");
	MarkNativeAsOptional("GameMode_GetPropertyValue");
	MarkNativeAsOptional("GameMode_GetPropertyArray");
	MarkNativeAsOptional("GameMode_GetPropertyString");

	// Behaviour properties natives
	MarkNativeAsOptional("Behaviour_SetPropertyValue");
	MarkNativeAsOptional("Behaviour_SetPropertyArray");
	MarkNativeAsOptional("Behaviour_SetPropertyString");
	MarkNativeAsOptional("Behaviour_GetPropertyValue");
	MarkNativeAsOptional("Behaviour_GetPropertyArray");
	MarkNativeAsOptional("Behaviour_GetPropertyString");

	// Special natives
	MarkNativeAsOptional("__GAMMA_PluginUnloading");
}
#endif