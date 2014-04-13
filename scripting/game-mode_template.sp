#pragma semicolon 1

// Uncomment if your plugin includes a game mode
// Automatically implements OnPluginEnd to notify about the plugin unloading to Gamma
#define GAMMA_CONTAINS_GAME_MODE

// Uncomment if your plugin includes a behaviour
// Automatically implements OnPluginEnd to notify about the plugin unloading to Gamma
//#define GAMMA_CONTAINS_BEHAVIOUR

// Uncomment if your plugin includes a game mode and/or behaviour but you need
// to use OnPluginEnd
//#define GAMMA_MANUAL_UNLOAD_NOTIFICATION 


#include <sourcemod>
#include <gamma>

// Storage variables for MyGameMode and MyBehaviourType
new GameMode:g_hMyGameMode;
new BehaviourType:g_hMyBehaviourType;

public OnAllPluginsLoaded()
{
	// Create MyGameMode in OnPluginStart (gamma is required, so it should be safe, right?)
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
	new Handle:behaviours = Gamma_GetBehaviourTypeBehaviours(g_hMyBehaviourType);
	new bool:canStart = GetArraySize(behaviours) > 0;
	CloseHandle(behaviours);
	return canStart;
}

public Gamma_OnGameModeStart()
{
	// Get all behaviours of MyBehaviourType
	new Handle:behaviours = Gamma_GetBehaviourTypeBehaviours(g_hMyBehaviourType);

	for (new i = 1; i <= MaxClients; i++)
	{
		// Give a random behaviour to all clients on round start!
		if (IsClientInGame(i))
		{
			new Behaviour:behaviour = Behaviour:GetArrayCell(behaviours, GetRandomInt(0, GetArraySize(behaviours) - 1));
			Gamma_GiveBehaviour(i, behaviour);

			// Also, now that the player is given the behaviour we want to call MyFunctionRequirement
			Gamma_SimpleBehaviourFunctionCall(behaviour, "MyFunctionRequirement", _, i);
		}
	}

	// Don't forget to close the behaviours handle! It's a cloned array of the one internal in Gamma
	CloseHandle(behaviours);
}