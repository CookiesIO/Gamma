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
#include <tf2_stocks>
#include <gamma>
#include <bossfightfortress>

// Storage variable for SampleBoss
new Behaviour:g_hSampleBoss = INVALID_BEHAVIOUR;

public Gamma_OnGameModeCreated(GameMode:gameMode)
{
	if (gameMode == Gamma_FindGameMode(BFF_GAME_MODE_NAME))
	{
		// Create our sample boss!
		new BehaviourType:behaviourType = Gamma_FindBehaviourType(BFF_BOSS_TYPE_NAME);
		g_hSampleBoss = Gamma_RegisterBehaviour(behaviourType, "Sample_Boss");
	}
}

public BFF_GetMaxHealth(enemyCount)
{
	return RoundToFloor(Pow(512.0*enemyCount, 1.1));
}

public BFF_EquipBoss(boss)
{
	// Meh, lets just remove all but the melee weapon, it's just a sample anyway
	TF2_RemoveWeaponSlot(boss, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(boss, TFWeaponSlot_Secondary);
	TF2_RemoveWeaponSlot(boss, TFWeaponSlot_Grenade);
	TF2_RemoveWeaponSlot(boss, TFWeaponSlot_Building);
	TF2_RemoveWeaponSlot(boss, TFWeaponSlot_PDA);
	TF2_RemoveWeaponSlot(boss, TFWeaponSlot_Item1);
	TF2_RemoveWeaponSlot(boss, TFWeaponSlot_Item2);
}

public bool:BFF_HasChargeAbility(&Float:chargeTime)
{
	chargeTime = 2.0;
	return true;
}

public Float:BFF_ChargeAbilityUsed(boss, Float:charge)
{
	// Do nothing with less than 15% charge
	if (charge < 0.15)
	{
		return 0.0;
	}

	new Float:angle[3];
	GetClientEyeAngles(boss, angle);

	if (angle[0] < -25)
	{
		// Booom.... superb jump, whatevs
		new Float:velocity[3];

		GetAngleVectors(angle, velocity, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(velocity, velocity);
		ScaleVector(velocity, 300 + (1000 * charge));

		TeleportEntity(boss, NULL_VECTOR, NULL_VECTOR, velocity);

		// 5 seconds cooldown
		return 5.0;
	}
	// Else no cooldown, jump never initiated
	return 0.0;
}