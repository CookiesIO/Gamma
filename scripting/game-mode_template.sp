#pragma semicolon 1

// Uncomment if your plugin includes a game mode
// Automatically implements OnPluginEnd to notify about the plugin unloading to Gamma
#define GAMMA_CONTAINS_GAME_MODE

// Uncomment if your plugin includes a behaviour
// Automatically implements OnPluginEnd to notify about the plugin unloading to Gamma
//#define GAMMA_CONTAINS_BEHAVIOUR

// Uncomment if your plugin includes a game mode and/or behaviour but you need
// to use OnPluginEnd, but you MUST CALL __GAMMA_PluginUnloading() in OnPluginEnd()
//#define GAMMA_MANUAL_UNLOAD_NOTIFICATION 


#include <sourcemod>
#include <gamma>

// We might not use g_hMyGameMode now, but that doesn't mean it's not nice to have it
#pragma unused g_hMyGameMode

// Storage variables for MyGameMode and MyBehaviourType
new GameMode:g_hMyGameMode;
new BehaviourType:g_hMyBehaviourType;

public Gamma_PluginDetected()
{
	// Create MyGameMode, Gamma_PluginDetected should only run once per gamma/plugin life time
	g_hMyGameMode = Gamma_RegisterGameMode("MyGameMode");
}

public Gamma_OnCreateGameMode()
{
	// Create the behaviour type MyBehaviourType for my game mode!
	// Note, that they can only be created in Gamma_OnCreateGameMode
	g_hMyBehaviourType = Gamma_CreateBehaviourType("MyBehaviourType");
	Gamma_AddBehaviourTypeRequirement(g_hMyBehaviourType, "MyFunctionRequirement");
}

// This is called when Gamma wants to know if your game mode can start
// Do not do any initialilizing work here, only make sure you all you need to be able to start
public bool:Gamma_IsGameModeAbleToStartRequest()
{
	// We can start if there's 1 or more behaviours of MyBehaviourType
	return Gamma_BehaviourTypeHasBehaviours(g_hMyBehaviourType);
}

public Gamma_OnGameModeStart()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		// Give a random behaviour to all clients on round start!
		if (IsClientInGame(i))
		{
			new Behaviour:behaviour = Gamma_GiveRandomBehaviour(i, g_hMyBehaviourType);

			// Also, now that the player is given the behaviour we want to call MyFunctionRequirement
			Gamma_SimpleBehaviourFunctionCall(behaviour, "MyFunctionRequirement", _, i);
		}
	}
}