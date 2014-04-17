#if defined _gamma_game_css
 #endinput
#endif
#define _gamma_game_css

// Sublime text 2 autocompletion!
#include <sourcemod>

// cstrike ext isn't needed, except for css and csgo
#undef REQUIRE_EXTENSIONS
#include <cstrike>
#define REQUIRE_EXTENSIONS

stock LoadGameDataCS(Handle:gc)
{
	// We really, really want the cstrike library for cs:s/csgo
	if (!LibraryExists("cstrike"))
	{
		SetFailState("cstrike library not loaded");
	}

	// We're just using events for cs:s/csgo, they're in the gamedata
	LoadGameDataCommon(gc);
}

stock SetupCSOnMapStart()
{
	SetupCommonOnMapStart();
}

stock CleanUpCSOnMapEnd()
{
	CleanUpCommonOnMapEnd();
}

stock ForceRoundEndCS()
{
	CS_TerminateRound(0.0, CSRoundEnd_Draw);
}