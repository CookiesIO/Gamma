#pragma semicolon 1

// Uncomment if your plugin includes a game mode
// Automatically implements OnPluginEnd to notify about the plugin unloading to Gamma
//#define GAMMA_CONTAINS_GAME_MODE

// Uncomment if your plugin includes a behaviour
// Automatically implements OnPluginEnd to notify about the plugin unloading to Gamma
#define GAMMA_CONTAINS_BEHAVIOUR

// Uncomment if your plugin includes a game mode and/or behaviour but you need
// to use OnPluginEnd
//#define GAMMA_MANUAL_UNLOAD_NOTIFICATION 


#include <sourcemod>
#include <gamma>

// Storage variable for MyBehaviour
new Behaviour:g_hMyBehaviour;

public Gamma_OnGameModeCreated(GameMode:gameMode)
{
	if (gameMode == Gamma_FindGameMode("MyGameMode"))
	{
		// Create our behaviour!
		new BehaviourType:behaviourType = Gamma_FindBehaviourType("MyBehaviourType");
		g_hMyBehaviour = Gamma_RegisterBehaviour(behaviourType, "MyBehaviour");
	}
}

public MyFunctionRequirement(client)
{
	PrintToServer("MyBehaviour's MyFunctionRequirement (%N)", client);
}

public Gamma_OnBehaviourPossessingClient(client)
{
	PrintToServer("MyBehaviour possessed %N", client);
}

public Gamma_OnBehaviourReleasingClient(client)
{
	PrintToServer("MyBehaviour released %N", client);
}