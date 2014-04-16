#if defined _gamma_game_tf
 #endinput
#endif
#define _gamma_game_tf

// Sublime text 2 autocompletion!
#include <sourcemod>
#include <dhooks>

new bool:tf_bUseCommon;
new Handle:tf_hRoundRespawn;
new Handle:tf_hPreviousRoundEnd;

stock LoadGameDataTF(Handle:gc)
{
	DEBUG_PRINT0("Gamma:LoadGameDataTF()");

	new roundRespawnOffset = GameConfGetOffset(gc, "RoundRespawn");
	new previousRoundEndOffset = GameConfGetOffset(gc, "PreviousRoundEnd");
	if (roundRespawnOffset == -1 || previousRoundEndOffset == -1)
	{
		DEBUG_PRINT0("Gamma:LoadGameDataTF() : Unable to find RoundRespawn or PreviousRoundEnd offsets in game data, attempts safe mode");
		LoadGameDataCommon(gc);
		tf_bUseCommon = true;
		return;
	}

	DEBUG_PRINT0("Gamma:LoadGameDataTF() : Creating hooks");

	tf_hRoundRespawn = DHookCreate(roundRespawnOffset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, TF_RoundRespawn);
	tf_hPreviousRoundEnd = DHookCreate(previousRoundEndOffset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, TF_PreviousRoundEnd);
}

stock SetupTFOnMapStart()
{
	if (tf_bUseCommon)
	{
		SetupCommonOnMapStart();
		return;
	}
	DEBUG_PRINT0("Gamma:SetupTFOnMapStart() : Hooking RoundRespawn and PreviousRoundEnd");
	DHookGamerules(tf_hRoundRespawn, true);
	DHookGamerules(tf_hPreviousRoundEnd, true);
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