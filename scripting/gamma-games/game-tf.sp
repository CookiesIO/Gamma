#if defined _gamma_game_tf
 #endinput
#endif
#define _gamma_game_tf

// Sublime text 2 autocompletion!
#include <sourcemod>
#include <dhooks>
#include <sdktools>

static bool:tf_bUseCommonHooks;
static Handle:tf_hRoundRespawnHook;
static Handle:tf_hPreviousRoundEndHook;

static Handle:tf_hSetWinningTeamCall;

stock LoadGameDataTF(Handle:gc)
{
	DEBUG_PRINT0("Gamma:LoadGameDataTF()");

	// Load game data can be called more than once, I ain't lying! (dhooks added/removed)
	// If we already have the setwinningteam call setup, it's fine no matter what
	if (tf_hSetWinningTeamCall == INVALID_HANDLE)
	{
		// Prepare the SetWinningTeam(int team, int winReason, bool forceMapreset, bool switchTeams, bool dontAddScore) call
		StartPrepSDKCall(SDKCall_GameRules);
		PrepSDKCall_SetFromConf(gc, SDKConf_Virtual, "SetWinningTeam");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
		tf_hSetWinningTeamCall = EndPrepSDKCall();
	}

	// If DHooks is available we can hook RoundRespawn and PreviousRoundEnd
	if (g_bDHooksAvailable)
	{
		DEBUG_PRINT0("Gamma:LoadGameDataTF() : Creating RoundRespawn & PreviousRoundEnd hooks");

		new roundRespawnOffset = GameConfGetOffset(gc, "RoundRespawn");
		new previousRoundEndOffset = GameConfGetOffset(gc, "PreviousRoundEnd");

		// Hook CTFGameRules::RoundRespawn() and CTFGameRules::PreviousRoundEnd()
		tf_hRoundRespawnHook = DHookCreate(roundRespawnOffset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, TF_RoundRespawn);
		tf_hPreviousRoundEndHook = DHookCreate(previousRoundEndOffset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, TF_PreviousRoundEnd);
		
		// Remember, this can be called multiple times
		tf_bUseCommonHooks = false;
	}
	else
	{
		LoadGameDataCommon(gc);
		tf_bUseCommonHooks = true;
	}
}

stock SetupTFOnMapStart()
{
	if (tf_bUseCommonHooks)
	{
		SetupCommonOnMapStart();
		return;
	}
	DEBUG_PRINT0("Gamma:SetupTFOnMapStart() : Hooking RoundRespawn and PreviousRoundEnd");
	DHookGamerules(tf_hRoundRespawnHook, true);
	DHookGamerules(tf_hPreviousRoundEndHook, true);
}

stock CleanUpTFOnMapEnd()
{
	if (tf_bUseCommonHooks)
	{
		CleanUpCommonOnMapEnd();
		return;
	}
	// Nothing, everythings auto clean upped
}

stock ForceRoundEndTF()
{
	// Team Unassigned and no reason for the stalemate
	SDKCall(tf_hSetWinningTeamCall, 0, 0, true, false, false);
}

public MRESReturn:TF_RoundRespawn()
{
	DEBUG_PRINT0("Gamma:TF_RoundRespawn()");
	ChooseAndStartGameMode();
	return MRES_Ignored;
}

public MRESReturn:TF_PreviousRoundEnd()
{
	DEBUG_PRINT0("Gamma:TF_PreviousRoundEnd()");
	StopGameMode(false);
	return MRES_Ignored;
}