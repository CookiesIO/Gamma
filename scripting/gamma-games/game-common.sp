#if defined _gamma_game_common
 #endinput
#endif
#define _gamma_game_common

// Sublime text 2 autocompletion!
#include <sourcemod>

static bool:common_bDidLoad = false;

static bool:common_bHasRoundEndEvent;

static String:common_strRoundStartEvent[32];
static String:common_strRoundEndEvent[32];

// We only have the bare minimum knowledge
stock LoadGameDataCommon(Handle:gc)
{
	if (!common_bDidLoad)
	{
		if (!GameConfGetKeyValue(gc, "RoundStartEvent", common_strRoundStartEvent, sizeof(common_strRoundStartEvent)))
		{
			SetFailState("No RoundStartEvent in the Key/Value section in the gamedata");
		}
		if (!GameConfGetKeyValue(gc, "RoundEndEvent", common_strRoundEndEvent, sizeof(common_strRoundEndEvent)))
		{
			// Actually, round end isn't needed, but lets just log this message, could help catch woopsies
			LogMessage("No RoundEndEvent found in gamedata, is this on purpose?");
			common_bHasRoundEndEvent = false;
		}
		else
		{
			common_bHasRoundEndEvent = true;
		}
		common_bDidLoad = true;
	}
}

stock SetupCommonOnMapStart()
{
	// At least RoundStart is required
	HookEvent(common_strRoundStartEvent, Common_RoundStartEvent, EventHookMode_Pre);
	if (common_bHasRoundEndEvent)
	{
		HookEvent(common_strRoundEndEvent, Common_RoundEndEvent, EventHookMode_PostNoCopy);
	}
}

stock CleanUpCommonOnMapEnd()
{
	UnhookEvent(common_strRoundStartEvent, Common_RoundStartEvent, EventHookMode_Pre);
	if (common_bHasRoundEndEvent)
	{
		UnhookEvent(common_strRoundEndEvent, Common_RoundEndEvent, EventHookMode_PostNoCopy);
	}
}

stock ForceRoundEndCommon()
{
	// Untested, Mitchell and Leonardo and suggested it added it just-in-case
    new flags = GetCommandFlags("mp_forcewin");
    SetCommandFlags("mp_forcewin", flags & ~FCVAR_CHEAT);
    ServerCommand("mp_forcewin %i", 0);
    SetCommandFlags("mp_forcewin", flags);
}

public Common_RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	DEBUG_PRINT1("Gamma:Common_RoundStartEvent() : %s", name);
	ChooseAndStartGameMode();
}

public Common_RoundEndEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	DEBUG_PRINT1("Gamma:Common_RoundEndEvent() : %s", name);
	StopGameMode(GameModeEndReason_RoundEnded);
}