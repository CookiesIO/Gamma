#if defined _gamma_game_common
 #endinput
#endif
#define _gamma_game_common

// Sublime text 2 autocompletion!
#include <sourcemod>

new String:common_strRoundStartEvent[32];
new String:common_strRoundEndEvent[32];

// We only have the bare minimum knowledge
stock LoadGameDataCommon(Handle:gc)
{
	if (!GameConfGetKeyValue(gc, "RoundStartEvent", common_strRoundStartEvent, sizeof(common_strRoundStartEvent)))
	{
		SetFailState("No RoundStartEvent in the Key/Value section in the gamedata");
	}
	if (!GameConfGetKeyValue(gc, "RoundEndEvent", common_strRoundEndEvent, sizeof(common_strRoundEndEvent)))
	{
		SetFailState("No RoundEndEvent in the Key/Value section in the gamedata");
	}
}

stock SetupCommonOnMapStart()
{
	HookEvent(common_strRoundStartEvent, Common_RoundStartEvent);
	HookEvent(common_strRoundEndEvent, Common_RoundEndEvent);
}

stock CleanUpCommonOnMapEnd()
{
	UnhookEvent(common_strRoundStartEvent, Common_RoundStartEvent);
	UnhookEvent(common_strRoundEndEvent, Common_RoundEndEvent);
}

stock ForceRoundEndCommon()
{
	// This should be okay, riiiight? Thanks to Mitchell and Leonardo
    new flags = GetCommandFlags("mp_forcewin");
    SetCommandFlags("mp_forcewin", flags & ~FCVAR_CHEAT);
    ServerCommand("mp_forcewin %i", 0);
    SetCommandFlags("mp_forcewin", flags);
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