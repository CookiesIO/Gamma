#if defined _gamma_game_common
 #endinput
#endif
#define _gamma_game_common

// Sublime text 2 autocompletion!
#include <sourcemod>

// We only have the bare minimum knowledge
stock LoadGameDataCommon(Handle:gc)
{
	new String:roundStartEvent[32];
	new String:roundEndEvent[32];

	if (!GameConfGetKeyValue(gc, "RoundStartEvent", roundStartEvent, sizeof(roundStartEvent)))
	{
		SetFailState("No RoundStartEvent in the Key/Value section in the gamedata");
	}
	if (!GameConfGetKeyValue(gc, "RoundEndEvent", roundEndEvent, sizeof(roundEndEvent)))
	{
		SetFailState("No RoundEndEvent in the Key/Value section in the gamedata");
	}

	HookEvent(roundStartEvent, Common_RoundStartEvent);
	HookEvent(roundEndEvent, Common_RoundEndEvent);
}

stock SetupCommonOnMapStart()
{
	// Nothing here, at least yet
}

public Common_RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	DEBUG_PRINT0("Gamma:Common_RoundStartEvent()");
	ChooseAndStartGameMode();
}

public Common_RoundEndEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	DEBUG_PRINT0("Gamma:Common_RoundEndEvent()");
	StopGameMode(false);
}