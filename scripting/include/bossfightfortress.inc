#if defined _bossfightfortress_included
 #endinput
#endif
#define _bossfightfortress_included

// Name of our game mode
#define BFF_GAME_MODE_NAME "Boss_Fight_Fortress"

// Name of our boss behaviour type
#define BFF_BOSS_TYPE_NAME "BFF_Boss"


// Called when Boss Fight Fortress wants the max health for the boss from you
forward BFF_GetMaxHealth(enemyCount);

// Called when the behaviour should equip the boss with his badass gear and model and whatnot
forward BFF_EquipBoss(boss);

// This is optional, if it returns true you'll get BFF_ChargeAbilityUsed callbacks
// Charge time can also be set, charge ability is right click charge
// for things like superjump
forward bool:BFF_HasChargeAbility(&Float:chargeTime);

// This is optional, called when the boss uses the charge ability
// Return a value > 0 to make a cooldown
forward Float:BFF_ChargeAbilityUsed(boss, Float:charge);