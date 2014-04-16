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
#include <sdktools>
#include <tf2_stocks>
#include <dhooks>

#include <gamma>
#include <bossfightfortress>

// Storage variables for MyGameMode and BossBehaviourType
new GameMode:g_hMyGameMode;
new BehaviourType:g_hBossBehaviourType;

// Valid map?
new bool:g_bIsValidMap;

// Who're the bosses!
new g_bClientIsBoss[MAXPLAYERS+1];
new Behaviour:g_hClientBossBehaviour[MAXPLAYERS+1]; // Faster lookup than natives

// Welcome to the Boss Health Management Center, how much health would you like?
new g_iBossHealth[MAXPLAYERS+1];
new g_iBossMaxHealth[MAXPLAYERS+1];

// GetMaxHealth hook, lovely, lets display health as a %!
new Handle:g_hGetMaxHealthHook;
new g_iGetMaxHealthHookIds[MAXPLAYERS+1];

// OnTakeDamage_Alive, Works like OnTakeDamage from SDKHooks, just with the actual damage!
new Handle:g_hOnTakeDamage_AliveHook;
new g_iOnTakeDamage_AliveHookIds[MAXPLAYERS+1];

// PlayerRunCmd hook
new Handle:g_hPlayerRunCmdHook;
new g_iPlayerRunCmdHookIds[MAXPLAYERS+1];

// Now for the reason we have the playerruncmd hook
new Float:g_fBossMaxChargeTime[MAXPLAYERS+1];
new Float:g_fBossChargeTime[MAXPLAYERS+1];
new Float:g_fBossChargeCooldown[MAXPLAYERS+1];
new bool:g_bIsCharging[MAXPLAYERS+1];

// Meh, just keeping it for the queue that needs to be remade anyway
new g_iCurrentBoss;

public OnPluginStart()
{
	new Handle:gc = LoadGameConfigFile("bossfightfortress");
	if (gc == INVALID_HANDLE)
	{
		SetFailState("Couldn't find gamedata");
	}
	
	// PlayerRunCommand
	new playerRunCmdOffset = GameConfGetOffset(gc, "PlayerRunCommand");
	g_hPlayerRunCmdHook = DHookCreate(playerRunCmdOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, Internal_PlayerRunCmd);
	DHookAddParam(g_hPlayerRunCmdHook, HookParamType_ObjectPtr);
	DHookAddParam(g_hPlayerRunCmdHook, HookParamType_ObjectPtr);
	
	// GetMaxHealth
	new getMaxHealthOffset = GameConfGetOffset(gc, "GetMaxHealth");
	g_hGetMaxHealthHook = DHookCreate(getMaxHealthOffset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, Internal_GetMaxHealth);
	
	// OnTakeDamage_Alive
	new onTakeDamage_AliveOffset = GameConfGetOffset(gc, "OnTakeDamage_Alive");
	g_hOnTakeDamage_AliveHook = DHookCreate(onTakeDamage_AliveOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, Internal_OnTakeDamage_Alive);
	DHookAddParam(g_hOnTakeDamage_AliveHook, HookParamType_ObjectPtr);
}

public OnMapStart()
{
	// It's valid map if there's a tf_logic_arena entity swarming around
	g_bIsValidMap = false;
	if (FindEntityByClassname(-1, "tf_logic_arena") != -1)
	{
		g_bIsValidMap = true;
	}
}

// Called when Gamma detects the plugin
public Gamma_PluginDetected()
{
	// Register Boss Fight Fortress
	g_hMyGameMode = Gamma_RegisterGameMode(BFF_GAME_MODE_NAME);
}

// Called during Gamma_RegisterGameMode, if any errors occurs here, Gamma_RegisterGameMode fails
public Gamma_OnCreateGameMode()
{
	// Create our Boss behaviour type, which boss behaviours use to extend our game mode with!
	// Note, that behaviour types can only be created in Gamma_OnCreateGameMode
	g_hBossBehaviourType = Gamma_CreateBehaviourType(BFF_BOSS_TYPE_NAME);
	Gamma_AddBehaviourTypeRequirement(g_hBossBehaviourType, "BFF_GetMaxHealth");
	Gamma_AddBehaviourTypeRequirement(g_hBossBehaviourType, "BFF_EquipBoss");
}

// This is called when Gamma wants to know if your game mode can start
// Do not do any initialilizing work here, only make sure you all you need to be able to start
public bool:Gamma_IsGameModeAbleToStartRequest()
{
	// We can only start in valid maps
	new bool:canStart = g_bIsValidMap;

	// We can start if there's 1 or more behaviours of BossBehaviourType
	if (canStart)
	{
		new Handle:behaviours = Gamma_GetBehaviourTypeBehaviours(g_hBossBehaviourType);
		canStart = GetArraySize(behaviours) > 0;
		CloseHandle(behaviours);
	}

	// We must also be sure we have a client to become the boss
	if (canStart)
	{
		new nextBoss = GetNextInQueue();
		canStart = nextBoss != -1;
	}
	return canStart;
}

public Gamma_OnGameModeStart()
{
	// Get a random behaviour of BossBehaviourType
	new Handle:behaviours = Gamma_GetBehaviourTypeBehaviours(g_hBossBehaviourType);
	new Behaviour:bossBehaviour = GetArrayBehaviour(behaviours, GetRandomInt(0, GetArraySize(behaviours) - 1));

	// Don't forget to close the behaviours handle! It's a cloned array of the one internal in Gamma
	CloseHandle(behaviours);

	// Get our next boss! And give him the boss as well
	new nextBoss = GetNextInQueue();
	g_iCurrentBoss = nextBoss;
	Gamma_GiveBehaviour(nextBoss, bossBehaviour);

	for (new i = 1; i <= MaxClients; i++)
	{
		// Shift all players to correct teams
		if (IsClientInGame(i))
		{
			if (g_bClientIsBoss[i])
			{
				ChangeClientTeam(i, _:TFTeam_Blue);
			}
			else
			{
				ChangeClientTeam(i, _:TFTeam_Red);
			}
		}
	}

	// We use the following events to determine when to do certain things to the boss (rawrrr)
	HookEvent("arena_round_start", Event_RoundStartPreparation);
	HookEvent("post_inventory_application", Event_EquipmentUpdate);
	HookEvent("player_spawn", Event_EquipmentUpdate);
}

public Gamma_OnGameModeEnd()
{
	// Unhook our events
	UnhookEvent("arena_round_start", Event_RoundStartPreparation);
	UnhookEvent("post_inventory_application", Event_EquipmentUpdate);
	UnhookEvent("player_spawn", Event_EquipmentUpdate);
}

// We use these forwards for easier extensions of the game mode later
public Gamma_OnBehaviourPossessedClient(client, Behaviour:behaviour)
{
	// Set the boss' behaviour
	g_hClientBossBehaviour[client] = behaviour;
	g_bClientIsBoss[client] = true;

	// Uhhh, woops, hax needed, the only way to get byref args
	static Handle:hasChargeAbilityFwd = INVALID_HANDLE;
	if (hasChargeAbilityFwd == INVALID_HANDLE)
	{
		hasChargeAbilityFwd = CreateForward(ET_Single, Param_FloatByRef);
	}

	// Always, ALWAYS RESET THIS to -1
	g_iPlayerRunCmdHookIds[client] = -1;

	// Add the function to the forward
	if (Gamma_AddBehaviourFunctionToForward(g_hClientBossBehaviour[client], "BFF_HasChargeAbility", hasChargeAbilityFwd))
	{
		new Float:chargeTime;
		new bool:result;

		// Call the forward and get the result!
		Call_StartForward(hasChargeAbilityFwd);
		Call_PushFloatRef(chargeTime);
		Call_Finish(result);

		// Let's see if it's 0 or 1 or true or false, anyways who cares, hook if needed
		if (result)
		{
			if (chargeTime < 0.0)
			{
				chargeTime = 1.0;
			}
			g_fBossMaxChargeTime[client] = chargeTime;
			g_iPlayerRunCmdHookIds[client] = DHookEntity(g_hPlayerRunCmdHook, true, client);
		}

		// Don't forget to clear the forward!
		Gamma_RemoveBehaviourFunctionFromForward(g_hClientBossBehaviour[client], "BFF_HasChargeAbility", hasChargeAbilityFwd);
	}

	// Hook 
	DHookEntity(g_hGetMaxHealthHook, false, client);
	DHookEntity(g_hOnTakeDamage_AliveHook, false, client);
}

public Gamma_OnBehaviourReleasedClient(client, Behaviour:behaviour)
{
	// Remove our hooks
	if (g_iPlayerRunCmdHookIds[client] != -1)
	{
		DHookRemoveHookID(g_iPlayerRunCmdHookIds[client]);
	}
	DHookRemoveHookID(g_iGetMaxHealthHookIds[client]);
	DHookRemoveHookID(g_iOnTakeDamage_AliveHookIds[client]);

	// Reset variables
	g_hClientBossBehaviour[client] = INVALID_BEHAVIOUR;
	g_bClientIsBoss[client] = false;
	g_bIsCharging[client] = false;
}

// Give the bosses the health they deserve!
public Event_RoundStartPreparation(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		// If the client is a boss, get his max health!
		if (IsClientInGame(i) && g_bClientIsBoss[i])
		{
			new health = Gamma_SimpleBehaviourFunctionCall(g_hClientBossBehaviour[i], "BFF_GetMaxHealth", _, GetTeamPlayerCount(TFTeam_Red));
			g_iBossMaxHealth[i] = g_iBossHealth[i] = health;
		}
	}
}

// Give the bosses the gear they don't deserve!
public Event_EquipmentUpdate(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (g_bClientIsBoss[client])
	{
		Gamma_SimpleBehaviourFunctionCall(g_hClientBossBehaviour[client], "BFF_EquipBoss", _, client);
	}
}

// Our player run cmd hook, fresh outta DHooks!
public MRESReturn:Internal_PlayerRunCmd(this, Handle:hParams)
{
	static lastButtons[MAXPLAYERS+1];
	new buttons = GetClientButtons(this);
	if ((buttons & IN_ATTACK2) == IN_ATTACK2)
	{
		// Charging can begin when the client is not charging and when the cooldown has ended
		if (!g_bIsCharging[this] && g_fBossChargeCooldown[this] < GetGameTime())
		{
			PrintToServer("%N started charging", this);
			g_fBossChargeTime[this] = GetGameTime();
			g_bIsCharging[this] = true;
		}
	}
	else if ((lastButtons[this] & IN_ATTACK2) == IN_ATTACK2 && g_bIsCharging[this])
	{
		PrintToServer("%N Used ability", this);
		// Get charge percent and send the ChargeAbilityUsed message to the behaviour!
		new Float:chargePercent = GetChargePercent(this);
		new Float:cooldown = Float:Gamma_SimpleBehaviourFunctionCall(g_hClientBossBehaviour[this], "BFF_ChargeAbilityUsed", _, this, chargePercent);
		g_fBossChargeCooldown[this] = GetGameTime() + cooldown;
		g_bIsCharging[this] = false;
	}
	lastButtons[this] = buttons;
	return MRES_Ignored;
}

// Get max health, we override this for our bosses to return 100, always
public MRESReturn:Internal_GetMaxHealth(this, Handle:hReturn)
{
	DHookSetReturn(hReturn, 100);
	return MRES_Supercede;
}

// OnTakeDamage_Alive, we gotta change the damage so we don't get totally owned
public MRESReturn:Internal_OnTakeDamage_Alive(this, Handle:hParams)
{
	// 48 is the offset to get the damage part of CTakeDamageInfo
	new Float:damage = DHookGetParamObjectPtrVar(hParams, 1, 48, ObjectValueType_Float);
	damage = float(RoundFloat(damage));

	// Boost health the equalivant of the damage, we round the damage but it shouldn't be noticable in the game
	new newHealth = GetEntProp(this, Prop_Send, "m_iHealth") + RoundFloat(damage);
	SetEntProp(this, Prop_Send, "m_iHealth", newHealth);

	// Now we set the damage to damage + (/damage/maxhealth) * 100) to get the percentage of actual damage done
	damage = damage + ((damage / g_iBossMaxHealth[this]) * 100);
	DHookSetParamObjectPtrVar(hParams, 1, 48, ObjectValueType_Float, damage);

	// Make sure the override gets in
	return MRES_ChangedHandled;
}


// A little helper stock
stock Float:GetChargePercent(client)
{
	// If we aren't charging it can be counted as charged
	if (!g_bIsCharging[client])
	{
		return 0.0;
	}

	// Get max charge, if it's 0 we could get a division by zero, we don't want that
	// So, it we're charging and the charge time is 0, then it's already 100%
	new Float:maxCharge = g_fBossMaxChargeTime[client];
	if (maxCharge == 0)
	{
		return 1.0;
	}

	// BossChargeTime is the time at which charging began, so subtract it from the current gametime
	// to get the total time spent charging and then divide by maxcharge to get %
	return (GetGameTime() - g_fBossChargeTime[client]) / maxCharge;
}

// Queue handling - proper impl later
stock GetNextInQueue()
{
	// We only have one person as a boss atm, so this'll be fine
	// But it still needs a proper implementation at one point
	for (new i = g_iCurrentBoss + 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			return i;
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			return i;
		}
	}
	return -1;
}

// Count players in a team!
stock GetTeamPlayerCount(any:team)
{
	new count = 0;
	for (new i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == team)
		{
			count++;
		}
	}
	return count;
}