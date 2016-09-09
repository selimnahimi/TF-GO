///////////////////////////////////////////////////////////////////////////////////////////////	//
//  _______ ______   _____  ____     _____          __  __ ______ __  __  ____  _____  ______ 	//
// |__   __|  ____| / ____|/ __ \   / ____|   /\   |  \/  |  ____|  \/  |/ __ \|  __ \|  ____|	//
//    | |  | |__ (_) |  __| |  | | | |  __   /  \  | \  / | |__  | \  / | |  | | |  | | |__   	//
//    | |  |  __|  | | |_ | |  | | | | |_ | / /\ \ | |\/| |  __| | |\/| | |  | | |  | |  __|  	//
//    | |  | |    _| |__| | |__| | | |__| |/ ____ \| |  | | |____| |  | | |__| | |__| | |____ 	//
//    |_|  |_|   (_)\_____|\____/   \_____/_/    \_\_|  |_|______|_|  |_|\____/|_____/|______|	//
//																								//
// 									WRITTEN BY HUNCAMPER										//
//																								//
//////////////////////////////////////////////////////////////////////////////////////////////////

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdktools>
#include <sdkhooks>
#include <kvizzle>
#include <tf2items_giveweapon>
#undef REQUIRE_EXTENSIONS
#include <SteamWorks>

#pragma semicolon 1

#define PLUGIN_VERSION 		"1.0.0"
#define SOUND_THROW 		"weapons/grenade_throw.wav"
#define SOUND_FAILED 		"common/wpn_denyselect.wav"
#define SOUND_EXPLOSION		"weapons/tacky_grenadier_explode3.wav"
#define MODEL_GRENADE 		"models/weapons/w_models/w_grenade_frag.mdl"

#define TOTALGRENADES		2
#define GRENADE_FRAG		1
#define GRENADE_SMOKE		2

#define WEAPON_PISTOL		1
#define WEAPON_SMG			2
#define WEAPON_RIFLE		3
#define WEAPON_HEAVY		4

public Plugin:myinfo =
{
	name = "TF:GO Gamemode",
	author = "HUNcamper",
	description = "The gamemode that brings Counter Strike to Team Fortress!",
	version = PLUGIN_VERSION,
	url = "http://www.camperservers.hu/plugins"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) // Ask to load the plugin...
{
	if(GetEngineVersion() != Engine_TF2) // If game isn't TF2
	{
		Format(error, err_max, "This plugin only works for Team Fortress 2"); // Error
		return APLRes_Failure; // Don't load the plugin
	}
	return APLRes_Success; // Load the plugin
}

bool steamworks = false;

public void OnAllPluginsLoaded()
{
	// S T E A M W O R K S //
	steamworks = LibraryExists("SteamWorks");
	if(steamworks)
	{
		SteamWorks_SetGameDescription("TF:Global Offensive");
	}
	else
	{
		PrintToServer("[TFGO] SteamWorks is not loaded, ignoring");
	}
}

/////////////////////
//V A R I A B L E S//
/////////////////////

// Client Arrays
int tfgo_player_money[MAXPLAYERS + 1]; 					// Each player's current money
Handle tfgo_MoneyHUD[MAXPLAYERS + 1]; 					// Each player's HUD timer
int tfgo_clientWeapons[MAXPLAYERS+1][6]; 				// Bought weapons, by ID, 4th value is the type of the grenade, 5th is the amount of grenades.
int tfgo_clientGrenades[MAXPLAYERS+1][TOTALGRENADES+1];	// Amount of grenades of every client
float tfgo_clientSpawnPos[MAXPLAYERS+1][3]; 				// Save the position where a specific player spawned at to check buyzone distance.
bool tfgo_canClientBuy[MAXPLAYERS+1];					// Is the player in the bounds of the buytime?

// Weapons
new String:tfgo_weapons_name[256][32];
int tfgo_weapons[256][3];
int tfgo_grenades[5][1];

// Convars
Handle g_tfgoDefaultMoney;
Handle g_tfgoMoneyOnKill;
Handle g_tfgoMoneyOnAssist;
Handle g_tfgoMaxMoney;
Handle g_tfgoDefaultMelee;
Handle g_tfgoDefaultSecondary;
Handle g_tfgoDefaultPrimary;
Handle g_tfgoCanDoubleJump;
Handle g_tfgoMaxBuyDistance;
Handle g_tfgoMoneyOnWin;
Handle g_tfgoMoneyOnLose;
Handle g_tfgoSpeed;
Handle g_tfgoBuyTime;
Handle g_tfgoGrenadeDmg;
Handle g_tfgoGrenadeRadius;
Handle g_tfgoGrenadeDelay;
Handle g_tfgoGrenadeSpeed;

// HUD elements
Handle hudMoney;
Handle hudPlus1;
Handle hudPlus2;

// Timers
Handle DashTimerHandle = INVALID_HANDLE;

// Menus
Menu BuyMenu = null;
Menu BuyMenu_pistols = null;
Menu BuyMenu_smgs = null;
Menu BuyMenu_rifles = null;
Menu BuyMenu_heavy = null;
Menu BuyMenu_grenades = null;

// Other
new dashoffset;

///////////////////////////
//P L U G I N   S T A R T//
///////////////////////////
public OnPluginStart()
{
	PrecacheModel(MODEL_GRENADE, true);
	PrecacheSound(SOUND_FAILED, true);
	PrecacheSound(SOUND_EXPLOSION, true);
	PrecacheSound(SOUND_THROW, true);
	
	// C O N V A R S //
	g_tfgoDefaultMoney = CreateConVar("tfgo_defaultmoney", "800", "Default amount of money a player recieves on start");
	g_tfgoMoneyOnKill = CreateConVar("tfgo_moneyonkill", "300", "Amount of money to give when killing a player");
	g_tfgoMoneyOnAssist = CreateConVar("tfgo_moneyonassist", "150", "Amount of money to give when assisting in a kill of a player");
	g_tfgoMoneyOnWin = CreateConVar("tfgo_moneyonwin", "3000", "After winning, the players in the winning team recieves $X");
	g_tfgoMoneyOnLose = CreateConVar("tfgo_moneyonlose", "1000", "After losing, the players in the losing team recieves $X");
	g_tfgoMaxMoney = CreateConVar("tfgo_maxmoney", "16000", "Maximum money a player can reach in total");
	g_tfgoSpeed = CreateConVar("tfgo_speed", "250.0", "Speed of players");
	g_tfgoBuyTime = CreateConVar("tfgo_buytime", "30", "Buy time in seconds, -1 for infinite");
	g_tfgoDefaultMelee = CreateConVar("tfgo_default_melee", "461", "Default melee weapon on spawn, -1 to disable");
	g_tfgoDefaultSecondary = CreateConVar("tfgo_default_secondary", "23", "Default secondary weapon on spawn, -1 to disable");
	g_tfgoDefaultPrimary = CreateConVar("tfgo_default_primary", "-1", "Default primary weapon on spawn, -1 to disable");
	g_tfgoCanDoubleJump = CreateConVar("tfgo_doublejump", "0", "Enable/Disable the Scout's ability to double jump");
	g_tfgoMaxBuyDistance = CreateConVar("tfgo_maxbuydistance", "500.0", "Max distance between player and their spawn in units to allow buy");
	g_tfgoGrenadeDmg = CreateConVar("tfgo_grenade_damage", "100.0", "Damage that the grenade deals");
	g_tfgoGrenadeRadius = CreateConVar("tfgo_grenade_radius", "198.0", "Grenade explosion radius");
	g_tfgoGrenadeDelay = CreateConVar("tfgo_grenade_delay", "3.0", "Grenade explosion delay, in seconds");
	g_tfgoGrenadeSpeed = CreateConVar("tfgo_grenade_speed", "1000.0", "Speed of the grenade when thrown");
	
	// A D M I N   C O M M A N D S //
	RegAdminCmd("sm_setmoney", Command_TFGO_Admin_SetMoney, ADMFLAG_ROOT, "sm_setmoney <amount> [player]");
	RegAdminCmd("tfgo_reloadweapons", Command_TFGO_ReloadWeapons, ADMFLAG_ROOT, "tfgo_reloadweapons");
	RegAdminCmd("sm_givegrenade", Command_TFGO_GiveGrenade, ADMFLAG_ROOT, "sm_givegrenade <player> <amount>");
	
	// C L I E N T   C O M M A N D S //
	RegConsoleCmd("sm_buy", Command_TFGO_BuyWeapon, "sm_buy <weaponID>");
	RegConsoleCmd("sm_buymenu", Command_TFGO_BuyMenu, "sm_buymenu");
	RegConsoleCmd("sm_grenade", Command_TFGO_ThrowGrenade, "sm_grenade");
	
	// H O O K S //
	HookEvent("player_death", Player_Death);
	HookEvent("post_inventory_application", event_PlayerResupply);
	HookEvent("player_spawn", player_spawn); 
	HookEvent("teamplay_round_win", teamplay_round_win);
	
	// H U D   E L E M E N T S //
	hudMoney = CreateHudSynchronizer();
	hudPlus1 = CreateHudSynchronizer();
	hudPlus2 = CreateHudSynchronizer();
	
	for(int i = 1; i <= MaxClients; i++)
	{
		tfgo_player_money[i] = GetConVarInt(g_tfgoDefaultMoney);
		for(int b = 0 ; b < 3 ; b++)
		{
			tfgo_clientWeapons[i][b] = -1;
		}
		for(int b = 1 ; b < TOTALGRENADES ; b++)
		{
			tfgo_clientGrenades[i][b] = 0;
		}
	}
	
	// T I M E R S //
	DashTimerHandle = CreateTimer(0.1, timerJump, _, TIMER_REPEAT);
	
	// O T H E R //
	LoadTranslations("common.phrases"); // Load common translation file
	dashoffset = FindSendPropInfo("CTFPlayer", "m_iAirDash");
	
	for(new client = 1; client <= MaxClients; client++)
	{
		OnClientPostAdminCheck(client);
	}
	
	TFGO_ReloadWeapons();
}

public void OnMapStart()
{
	TFGO_ReloadWeapons();
	
	// PRECACHE GRENADE
	PrecacheModel(MODEL_GRENADE, true);
	PrecacheSound(SOUND_FAILED, true);
	PrecacheSound(SOUND_EXPLOSION, true);
}

//////////////////////////////////
//C L I E N T  C O N N E C T E D//
//////////////////////////////////
public OnClientPostAdminCheck(client)
{
	for(int b = 0 ; b < 3 ; b++)
	{
		tfgo_clientWeapons[client][b] = -1; // Reset player inventory
	}
	for(int b = 1 ; b < TOTALGRENADES ; b++)
	{
		tfgo_clientGrenades[client][b] = 0;
	}
	
	tfgo_player_money[client] = GetConVarInt(g_tfgoDefaultMoney); // Set the player's money to default
	
	if(IsValidClient(client, false) && client != 0)
	{
		tfgo_MoneyHUD[client] = CreateTimer(5.0, DrawHud, client); // Create a HUD timer for the player
		SDKHook(client, SDKHook_PreThink, SDKHooks_tfgoOnPreThink); // Create prethink for Speed changing
	}
}

//////////////////
//D R A W  H U D//
//////////////////
public Action:DrawHud(Handle:timer, any:client)
{
	if(IsValidClient(client))
	{
		SetHudTextParams(0.14, 0.90, 2.0, 100, 200, 255, 150);
		ShowSyncHudText(client, hudMoney, "Money: $%i", tfgo_player_money[client]);
	}
	tfgo_MoneyHUD[client] = CreateTimer(2.0, DrawHud, client);
	return Plugin_Handled;
}

// ---- H O O K S ---- //



// ---- E V E N T S ---- //

/////////////////////
//R O U N D   W I N//
/////////////////////
public teamplay_round_win(Handle:event, const String:name[], bool:dontBroadcast)
{
	new team = GetEventInt(event, "team");
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i, false))
		{
			if(GetClientTeam(i) == team)
			{
				int moneyonwin = GetConVarInt(g_tfgoMoneyOnWin);
				if(tfgo_player_money[i]+moneyonwin > GetConVarInt(g_tfgoMaxMoney))
				{
					moneyonwin = GetConVarInt(g_tfgoMaxMoney)-tfgo_player_money[i];
					tfgo_player_money[i] = tfgo_player_money[i] + moneyonwin;
				}
				else
				{
					tfgo_player_money[i] = tfgo_player_money[i] + moneyonwin;
				}
				
				SetHudTextParams(0.14, 0.93, 2.0, 255, 200, 100, 150, 1);
				ShowSyncHudText(i, hudPlus1, "+$%i", moneyonwin);
				PrintToChat(i, "[TFGO] +$%i for winning this round", moneyonwin);
			}
			else if(GetClientTeam(i) == 3 || GetClientTeam(i) == 2)
			{
				int moneyonwin = GetConVarInt(g_tfgoMoneyOnLose); // Lazy to replace "win" with "lose", ok?
				if(tfgo_player_money[i]+moneyonwin > GetConVarInt(g_tfgoMaxMoney))
				{
					moneyonwin = GetConVarInt(g_tfgoMaxMoney)-tfgo_player_money[i];
					tfgo_player_money[i] = tfgo_player_money[i] + moneyonwin;
				}
				else
				{
					tfgo_player_money[i] = tfgo_player_money[i] + moneyonwin;
				}
				
				SetHudTextParams(0.14, 0.93, 2.0, 255, 200, 100, 150, 1);
				ShowSyncHudText(i, hudPlus1, "+$%i", moneyonwin);
				PrintToChat(i, "[TFGO] +$%i for losing this round", moneyonwin);
			}
		}
	}
}

///////////////////////////
//P L A Y E R   S P A W N//
///////////////////////////

public player_spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid")); // Get client
	float pos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos); // Get the client's current pos
	tfgo_clientSpawnPos[client] = pos; // set it to the global array
	CreateTimer(0.2, timer_SetPlayerHealth, client);
	if(GetConVarFloat(g_tfgoBuyTime) > -1.0)
	{
		CreateTimer(GetConVarFloat(g_tfgoBuyTime), timer_BuyTimeOver, client);
	}
	tfgo_canClientBuy[client] = true;
	
	// Below was just for debugging
	//PrintToChatAll("Position: %f %f %f", pos[0], pos[1], pos[2]);
}

public Action:timer_BuyTimeOver(Handle:timer, any:client)
{
	tfgo_canClientBuy[client] = false;
}

public Action:timer_SetPlayerHealth(Handle:timer, any:client)
{
	new MaxHealth = 100;
	SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), MaxHealth, 4, true);
	SetEntData(client, FindDataMapInfo(client, "m_iHealth"), MaxHealth, 4, true);
}

/////////////////////////////////
//P L A Y E R   R E S U P P L Y//
/////////////////////////////////
public event_PlayerResupply(Handle:event, const String:name[], bool:dontBroadcast) // Resupply instead of spawn
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.1, timer_PlayerResupply, client); // Delay to avoid bugs
}

public Action:timer_PlayerResupply(Handle:timer, any:client)
{
	decl container[1], melee, secondary, primary;
	container[0] = client; // put client id in container, since stripPlayers only accepts arrays
	stripPlayers( container, 1, 0, true ); // strip all weapons from client
	melee = GetConVarInt(g_tfgoDefaultMelee); // melee convar
	secondary = GetConVarInt(g_tfgoDefaultSecondary); // secondary convar
	primary = GetConVarInt(g_tfgoDefaultPrimary); // primary convar
	
	// If the player had a weapon in their "inventory", they will recieve it on resupply/spawn
	// The player's "inventory" resets on dying. Also, picking up or giving weapons won't work this way.
	// If someone manages to find a way to update the inventory when the player picks up a new weapon,
	// they will recieve a cookie from me. So keep looking :)
	
	if(tfgo_clientWeapons[client][2] != -1)
	{
		int curr = tfgo_clientWeapons[client][2];
		if(TF2Items_CheckWeapon(tfgo_weapons[curr][0]))
		{
			melee = tfgo_weapons[curr][0];
		}
	}
	
	if(tfgo_clientWeapons[client][1] != -1)
	{
		int curr = tfgo_clientWeapons[client][1];
		if(TF2Items_CheckWeapon(tfgo_weapons[curr][0]))
		{
			secondary = tfgo_weapons[curr][0];
		}
	}
	
	if(tfgo_clientWeapons[client][0] != -1)
	{
		int curr = tfgo_clientWeapons[client][0];
		if(TF2Items_CheckWeapon(tfgo_weapons[curr][0]))
		{
			primary = tfgo_weapons[curr][0];
		}
	}
	
	if(melee != -1) // melee on spawn is disabled?
	{
		if(TF2Items_CheckWeapon(melee)) // check if weapon id is valid
		{
			TF2Items_GiveWeapon(client, melee); // give weapon if valid
		}
		else
		{
			PrintToChat(client, "[TFGO] Error: Invalid Weapon ID %i", melee); // error if id isn't valid
		}
	}
	if(secondary != -1)
	{
		if(TF2Items_CheckWeapon(secondary))
		{
			TF2Items_GiveWeapon(client, secondary);
		}
		else
		{
			PrintToChat(client, "[TFGO] Error: Invalid Weapon ID %i", secondary);
		}
	}
	if(primary != -1)
	{
		if(TF2Items_CheckWeapon(primary))
		{
			TF2Items_GiveWeapon(client, primary);
		}
		else
		{
			PrintToChat(client, "[TFGO] Error: Invalid Weapon ID %i", primary);
		}
	}
	CreateTimer(0.1, timer_SetPlayerHealth, client);
}

////////////////////////////
//P L A Y E R  K I L L E D//
////////////////////////////
public Player_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "attacker"));
	new killed = GetClientOfUserId(GetEventInt(event, "userid"));
	new assister = GetClientOfUserId(GetEventInt(event, "assister"));
	for(int b = 0 ; b < 3 ; b++)
	{
		tfgo_clientWeapons[killed][b] = -1;
	}
	for(int b = 1 ; b < TOTALGRENADES ; b++)
	{
		tfgo_clientGrenades[killed][b] = 0;
	}
	if(client != killed && GetConVarInt(g_tfgoMoneyOnKill) >= 1 && IsValidClient(client))
	{
		new moneyonkill = GetConVarInt(g_tfgoMoneyOnKill);
		if(tfgo_player_money[client]+moneyonkill > GetConVarInt(g_tfgoMaxMoney))
		{
			moneyonkill = GetConVarInt(g_tfgoMaxMoney)-tfgo_player_money[client];
			tfgo_player_money[client] = tfgo_player_money[client] + moneyonkill;
		}
		else
		{
			tfgo_player_money[client] = tfgo_player_money[client] + moneyonkill;
		}
		SetHudTextParams(0.14, 0.93, 2.0, 255, 200, 100, 150, 1);
		ShowSyncHudText(client, hudPlus1, "+$%i", moneyonkill);
		PrintToChat(client, "[TFGO] +$%i for killing %N", moneyonkill, killed);
	}
	if(assister != killed && assister != client && GetConVarInt(g_tfgoMoneyOnAssist) >= 1 && IsClientInGame(client))
	{
		new moneyonassist = GetConVarInt(g_tfgoMoneyOnAssist);
		if(tfgo_player_money[assister]+moneyonassist > GetConVarInt(g_tfgoMaxMoney))
		{
			tfgo_player_money[assister] = GetConVarInt(g_tfgoMaxMoney);
			moneyonassist = GetConVarInt(g_tfgoMaxMoney)-tfgo_player_money[client];
		}
		else
		{
			tfgo_player_money[assister] = tfgo_player_money[assister] + moneyonassist;
		}
		SetHudTextParams(0.14, 0.93, 2.0, 255, 200, 100, 150, 1);
		ShowSyncHudText(assister, hudPlus2, "+$%i", moneyonassist);
		PrintToChat(assister, "[TFGO] +$%i for assisting in killing %N", moneyonassist, killed);
	}
}

///////////////////////////////////////
//D O U B L E   J U M P ( S C O U T )//
///////////////////////////////////////
public Action:timerJump(Handle:timer)
{
	new g = GetConVarInt(g_tfgoCanDoubleJump);
	if(g < 1)
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i)) // If client is valid
			{
				SetEntData(i, dashoffset, 1); // Set dash offset to 1, making the scout unable to double jump.
			}
		}
	}
}

/////////////////////
//S D K   H O O K S//
/////////////////////
public SDKHooks_tfgoOnPreThink(client)
{
	float speed = GetConVarFloat(g_tfgoSpeed);
	if(IsValidClient(client)) SetSpeed(client, speed);
}

// ---- C O M M A N D S ----- //

///////////////////////////
//S E T   G R E N A D E S//
///////////////////////////
public Action:Command_TFGO_GiveGrenade(client, args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "[TFGO] Usage: sm_givegrenade <player> <amount> [type]");
		return Plugin_Handled;
	}
	else
	{
		char arg[32];
		char grenadetype_str[32];
		int grenadetype;
		GetCmdArg(2, arg, sizeof(arg)); // Get the second argument, and write it into the arg variable
		if(args > 2)
		{
			GetCmdArg(3, grenadetype_str, sizeof(grenadetype_str));
			if(StrEqual(grenadetype_str, "he"))
			{
				grenadetype = GRENADE_FRAG;
			}
			else if(StrEqual(grenadetype_str, "smoke"))
			{
				grenadetype = GRENADE_SMOKE;
			}
			else
			{
				PrintToChat(client, "[TFGO] Invalid grenade type %s, possible types: he, smoke", grenadetype_str);
				return Plugin_Handled;
			}
		}
		else
		{
			grenadetype_str = "he";
			grenadetype = GRENADE_FRAG;
		}
		
		if(!IsInteger(arg)) // If the argument is an integer
		{
			ReplyToCommand(client, "[TFGO] Invalid Amount"); // Not integer - don't continue
			return Plugin_Handled; // Break the command
		}
		
		// Argument is an integer
		
		int amount;
		amount = StringToInt(arg); // Convert the arg variable to an integer
		
		char arg2[32];
		GetCmdArg(1, arg2, sizeof(arg2)); // Get the first argument
		
		char target_name[MAX_TARGET_LENGTH]; // Target's name
		int target_list[MAXPLAYERS], target_count; // Target list and count
		bool tn_is_ml; // ???
		
		if ((target_count = ProcessTargetString(
				arg2,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_CONNECTED,
				target_name,
				sizeof(target_name),
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		
		for (int i = 0; i < target_count; i++)
		{
			char targetname[64];
			char sendername[64];
			GetClientName(target_list[i], targetname, sizeof(targetname)); // Get the player's name to display it
			GetClientName(client, sendername, sizeof(sendername)); // Get the sender's name
			tfgo_clientGrenades[target_list[i]][grenadetype] = amount; // Set the player's grenade
			ReplyToCommand(client, "[TFGO] Set %s's %s grenades to %i", targetname, grenadetype_str, amount); // Return a confirmation message to the player
			PrintToChat(target_list[i], "[TFGO] %s just set your %s grenades to %i!", sendername, grenadetype_str, amount); // Tell the target about these amazing news!
		}
		return Plugin_Handled;
	}
}

/////////////////////////////
//T H R O W   G R E N A D E//
/////////////////////////////
public Action:Command_TFGO_ThrowGrenade(client, args)
{
	if(IsValidClient(client) && IsClientReady(client))
	{
		// If there are too many entities, do not throw the grenade.
		if (GetMaxEntities() - GetEntityCount() < 200)
		{
			PrintToServer("[TFGO] !ERROR! Cannot spawn grenade, too many entities exist. Try reloading the map.");
			EmitSoundToClient(client, SOUND_FAILED, client, _, _, _, 1.0);
			return Plugin_Handled;
		}
		
		// Check if player has more than 0 frag grenades
		if (tfgo_clientGrenades[client][GRENADE_FRAG] > 0)
		{
			decl Float:pos[3];
			decl Float:ePos[3];
			decl Float:angs[3];
			decl Float:vecs[3];
			GetClientEyePosition(client, pos);						// Get Eye position of the player
			GetClientEyeAngles(client, angs);						// Get Eye angles of the player
			GetAngleVectors(angs, vecs, NULL_VECTOR, NULL_VECTOR);	// Get the angle of the player
			
			// Set throw position to directly in front of player
			pos[0] += vecs[0] * 32.0;
			pos[1] += vecs[1] * 32.0;
			
			ScaleVector(vecs, GetConVarFloat(g_tfgoGrenadeSpeed));
			
			// Create prop entity for the Dynamite Pack
			new grenade = CreateEntityByName("prop_physics_override");
			if (IsValidEntity(grenade))
			{
				DispatchKeyValue(grenade, "model", MODEL_GRENADE);
				DispatchKeyValue(grenade, "solid", "6");
				SetEntityGravity(grenade, 0.5);
				SetEntPropFloat(grenade, Prop_Data, "m_flFriction", 0.8);
				SetEntPropFloat(grenade, Prop_Send, "m_flElasticity", 0.45);
				SetEntProp(grenade, Prop_Data, "m_CollisionGroup", 1);
				SetEntProp(grenade, Prop_Data, "m_usSolidFlags", 0x18);
				SetEntProp(grenade, Prop_Data, "m_nSolidType", 6); 
				
				DispatchKeyValue(grenade, "renderfx", "0");
				DispatchKeyValue(grenade, "rendercolor", "255 255 255");
				DispatchKeyValue(grenade, "renderamt", "255");					
				SetEntPropEnt(grenade, Prop_Data, "m_hOwnerEntity", client);
				DispatchSpawn(grenade);
				TeleportEntity(grenade, pos, NULL_VECTOR, vecs);
				
				float delay = GetConVarFloat(g_tfgoGrenadeDelay);
				CreateTimer(delay, Function_GrenadeExplode, grenade);
			}
			EmitSoundToAll(SOUND_THROW, client, _, _, _, 1.0);
			tfgo_clientGrenades[client][GRENADE_FRAG] --;
		}
		else
		{
			EmitSoundToClient(client, SOUND_FAILED, client, _, _, _, 1.0);
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

/////////////////////////////////////
//G R E N A D E   E X P L O S I O N//
/////////////////////////////////////
public Action:Function_GrenadeExplode(Handle:timer, any:grenade)
{
	if (IsValidEntity(grenade))
	{
		// Make sure we don't crash the map with entities
		if (GetMaxEntities() - GetEntityCount() < 200)
		{
			ThrowError("Cannot spawn initial explosion, too many entities exist. Try reloading the map.");
			return Plugin_Handled;
		}
		
		decl Float:pos[3];
		GetEntPropVector(grenade, Prop_Data, "m_vecOrigin", pos);
		
		// Play corny "explode" sound
		EmitAmbientSound(SOUND_EXPLOSION, pos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, 0.0);
		
		// Raise the position up a bit
		pos[2] += 32.0;

		// Get the owner of the Dynamite Pack, and which team he's on
		new client = GetEntPropEnt(grenade, Prop_Data, "m_hOwnerEntity");
		new team = GetEntProp(client, Prop_Send, "m_iTeamNum");
		
		// Kill the Dynamite Pack entity
		AcceptEntityInput(grenade, "Kill");
		
		// Set up the explosion
		new explosion = CreateEntityByName("env_explosion");
		if (explosion != -1)
		{
			decl String:tMag[8];
			IntToString(GetConVarInt(g_tfgoGrenadeDmg), tMag, sizeof(tMag));
			DispatchKeyValue(explosion, "iMagnitude", tMag);
			decl String:tRad[8];
			IntToString(GetConVarInt(g_tfgoGrenadeRadius), tRad, sizeof(tRad));
			DispatchKeyValue(explosion, "iRadiusOverride", tRad);
			DispatchKeyValue(explosion, "spawnflags", "0");
			DispatchKeyValue(explosion, "rendermode", "5");
			SetEntProp(explosion, Prop_Send, "m_iTeamNum", team);
			SetEntPropEnt(explosion, Prop_Data, "m_hOwnerEntity", client);
			DispatchSpawn(explosion);
			ActivateEntity(explosion);
			TeleportEntity(explosion, pos, NULL_VECTOR, NULL_VECTOR);				
			AcceptEntityInput(explosion, "Explode");
			AcceptEntityInput(explosion, "Kill");
		}
	}
	return Plugin_Handled;
}

///////////////////////
//B U Y   W E A P O N//
///////////////////////
public Action:Command_TFGO_BuyWeapon(client, args)
{
	if(IsValidClient(client, false)) // If client is valid
	{
		if (!isPlayerNearSpawn(client))
		{
			PrintToChat(client, "[TFGO] You're too far away from the buy zone!");
			return Plugin_Handled;
		}
		else if(!tfgo_canClientBuy[client])
		{
			PrintToChat(client, "[TFGO] Buytime is over");
			return Plugin_Handled;
		}
		
		if (args == 1)
		{
			char arg_str[32];
			GetCmdArg(1, arg_str, sizeof(arg_str)); // Get the first argument, and write it into the arg variable
			
			if(!IsInteger(arg_str)) // If the argument is an integer
			{
				PrintToChat(client, "[TFGO] Invalid ID"); // Not integer - don't continue
				return Plugin_Handled; // Break the command
			}
			
			int arg;
			arg = StringToInt(arg_str); // Convert the arg variable to an integer
			
			if(arg > 256 || arg < 0)
			{
				PrintToChat(client, "[TFGO] Invalid ID %i", arg);
				return Plugin_Handled;
			}
			
			if(StrEqual(tfgo_weapons_name[arg], "0"))
			{
				PrintToChat(client, "[TFGO] Invalid ID %i", arg);
				return Plugin_Handled;
			}
			
			// Everything seems to be fine, continue.
			
			int pr = tfgo_weapons[arg][1];
			char wpnname[32];
			wpnname = tfgo_weapons_name[arg];
			
			if(tfgo_player_money[client] < pr)
			{
				PrintToChat(client, "[TFGO] Not Enough Money! Price: $%i", pr);
				return Plugin_Handled;
			}
			
			// Check if player has the weapon, if they do, don't allow the purchase.
			if(PlayerHasWeapon(client, arg))
			{
				PrintToChat(client, "[TFGO] You've already bought this weapon!");
				return Plugin_Handled;
			}
			
			if(tfgo_weapons[arg][2] == WEAPON_PISTOL) // PISTOL
			{
				tfgo_clientWeapons[client][1] = arg; // put to 2nd slot
				tfgo_player_money[client] = tfgo_player_money[client] - pr;
			}
			else if(tfgo_weapons[arg][2] == WEAPON_SMG) // SMG
			{
				tfgo_clientWeapons[client][0] = arg; // put to 1st slot
				tfgo_player_money[client] = tfgo_player_money[client] - pr;
			}
			else if(tfgo_weapons[arg][2] == WEAPON_RIFLE) // RIFLE
			{
				tfgo_clientWeapons[client][0] = arg; // put to 1st slot
				tfgo_player_money[client] = tfgo_player_money[client] - pr;
			}
			else if(tfgo_weapons[arg][2] == WEAPON_HEAVY) // HEAVY
			{
				tfgo_clientWeapons[client][0] = arg; // put to 1st slot
				tfgo_player_money[client] = tfgo_player_money[client] - pr;
			}
			else
			{
				PrintToChat(client, "[TFGO] Something went wrong");
				return Plugin_Handled;
			}
			
			int givewepid;
			givewepid = tfgo_weapons[arg][0];
			
			TF2Items_GiveWeapon(client, givewepid);
			
			// Show on HUD and in chat
			SetHudTextParams(0.14, 0.93, 2.0, 255, 200, 100, 150, 1);
			ShowSyncHudText(client, hudPlus1, "-$%i", pr);
			PrintToChat(client, "[TFGO] Bought %s for $%i", wpnname, pr);
			return Plugin_Handled;
		}
		else
		{
			PrintToChat(client, "[TFGO] Usage: sm_buy <weaponid>");
			return Plugin_Handled;
		}
	}
	else
	{
		ReplyToCommand(client, "[TFGO] Invalid Client");
		return Plugin_Handled;
	}
}

///////////////////////////////
//R E L O A D   W E A P O N S//
///////////////////////////////
public Action:Command_TFGO_ReloadWeapons(client, args)
{
	TFGO_ReloadWeapons();
	return Plugin_Handled;
}

public TFGO_ReloadWeapons()
{
	for(int i = 0; i < sizeof(tfgo_weapons); i++)
	{
		tfgo_weapons_name[i] = "0";
	}
	
	int count = 0;
	
	// load config file
	decl String:config[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, config, PLATFORM_MAX_PATH, "configs/tfgo_weapons.cfg");  
	
	new Handle:kv = KvizCreateFromFile("weapons", config);
	
	// PISTOLS
	for (new i = 1; KvizExists(kv, "pistol:nth-child(%i)", i); i++) {
		decl String:weaponname[32], String:logname[32], String:classname[32], String:attributes[256], String:viewmodel[PLATFORM_MAX_PATH], wepid, slot, level, price;
		bool error = false;
		int customid = 9000+count;
		if(!KvizGetStringExact(kv, logname, sizeof(logname), "pistol:nth-child(%i):key", i)) error=true;
		if(!KvizGetStringExact(kv, weaponname, sizeof(weaponname), "pistol:nth-child(%i).displayname", i)) error=true;
		if(!KvizGetStringExact(kv, classname, sizeof(classname), "pistol:nth-child(%i).weaponclass", i)) error=true;
		if(!KvizGetNumExact(kv, slot, "pistol:nth-child(%i).slot", i)) error=true;
		if(!KvizGetNumExact(kv, level, "pistol:nth-child(%i).level", i)) level=1;
		if(!KvizGetNumExact(kv, wepid, "pistol:nth-child(%i).weaponid", i)) error=true;
		if(!KvizGetStringExact(kv, attributes, sizeof(attributes), "pistol:nth-child(%i).attributes", i)) attributes="";
		if(!KvizGetStringExact(kv, viewmodel, sizeof(viewmodel), "pistol:nth-child(%i).viewmodel", i)) viewmodel="";
		if(!KvizGetNumExact(kv, price, "pistol:nth-child(%i).price", i)) error=true;
		
		if(!error)
		{
			TF2Items_CreateWeapon(customid, classname, wepid, slot, 1, level, attributes, -1, viewmodel, true);
			tfgo_weapons_name[count] = weaponname;
			tfgo_weapons[count][0] = customid;
			tfgo_weapons[count][1] = price;
			tfgo_weapons[count][2] = WEAPON_PISTOL; // pistol
			count++;
		}
		else
		{
			PrintToServer("[TFGO] BUMPED INTO AN ERROR IN CONFIG FILE (AT: PISTOL), MAKE SURE THAT IT IS CORRECTLY MADE!");
		}
	}
	
	// SMGS
	for (new i = 1; KvizExists(kv, "smg:nth-child(%i)", i); i++) {
		decl String:weaponname[32], String:logname[32], String:classname[32], String:attributes[256], String:viewmodel[PLATFORM_MAX_PATH], wepid, slot, level, price;
		bool error = false;
		int customid = 9000+count;
		if(!KvizGetStringExact(kv, logname, sizeof(logname), "smg:nth-child(%i):key", i)) error=true;
		if(!KvizGetStringExact(kv, weaponname, sizeof(weaponname), "smg:nth-child(%i).displayname", i)) error=true;
		if(!KvizGetStringExact(kv, classname, sizeof(classname), "smg:nth-child(%i).weaponclass", i)) error=true;
		if(!KvizGetNumExact(kv, slot, "smg:nth-child(%i).slot", i)) error=true;
		if(!KvizGetNumExact(kv, level, "smg:nth-child(%i).level", i)) level=1;
		if(!KvizGetNumExact(kv, wepid, "smg:nth-child(%i).weaponid", i)) error=true;
		if(!KvizGetStringExact(kv, attributes, sizeof(attributes), "smg:nth-child(%i).attributes", i)) attributes="";
		if(!KvizGetStringExact(kv, viewmodel, sizeof(viewmodel), "smg:nth-child(%i).viewmodel", i)) viewmodel="";
		if(!KvizGetNumExact(kv, price, "smg:nth-child(%i).price", i)) error=true;
		
		if(!error)
		{
			TF2Items_CreateWeapon(customid, classname, wepid, slot, 1, level, attributes, -1, viewmodel, true);
			tfgo_weapons_name[count] = weaponname;
			tfgo_weapons[count][0] = customid;
			tfgo_weapons[count][1] = price;
			tfgo_weapons[count][2] = WEAPON_SMG; // smg
			count++;
		}
		else
		{
			PrintToServer("[TFGO] BUMPED INTO AN ERROR IN CONFIG FILE (AT: SMG), MAKE SURE THAT IT IS CORRECTLY MADE!");
		}
	}
	
	// RIFLES
	for (new i = 1; KvizExists(kv, "rifle:nth-child(%i)", i); i++) {
		decl String:weaponname[32], String:logname[32], String:classname[32], String:attributes[256], String:viewmodel[PLATFORM_MAX_PATH], wepid, slot, level, price;
		bool error = false;
		int customid = 9000+count;
		if(!KvizGetStringExact(kv, logname, sizeof(logname), "rifle:nth-child(%i):key", i)) error=true;
		if(!KvizGetStringExact(kv, weaponname, sizeof(weaponname), "rifle:nth-child(%i).displayname", i)) error=true;
		if(!KvizGetStringExact(kv, classname, sizeof(classname), "rifle:nth-child(%i).weaponclass", i)) error=true;
		if(!KvizGetNumExact(kv, slot, "rifle:nth-child(%i).slot", i)) error=true;
		if(!KvizGetNumExact(kv, level, "rifle:nth-child(%i).level", i)) level=1;
		if(!KvizGetNumExact(kv, wepid, "rifle:nth-child(%i).weaponid", i)) error=true;
		if(!KvizGetStringExact(kv, attributes, sizeof(attributes), "rifle:nth-child(%i).attributes", i)) attributes="";
		if(!KvizGetStringExact(kv, viewmodel, sizeof(viewmodel), "rifle:nth-child(%i).viewmodel", i)) viewmodel="";
		if(!KvizGetNumExact(kv, price, "rifle:nth-child(%i).price", i)) error=true;
		
		if(!error)
		{
			TF2Items_CreateWeapon(customid, classname, wepid, slot, 1, level, attributes, -1, viewmodel, true);
			tfgo_weapons_name[count] = weaponname;
			tfgo_weapons[count][0] = customid;
			tfgo_weapons[count][1] = price;
			tfgo_weapons[count][2] = WEAPON_RIFLE; // rifle
			count++;
		}
		else
		{
			PrintToServer("[TFGO] BUMPED INTO AN ERROR IN CONFIG FILE (AT: RIFLE), MAKE SURE THAT IT IS CORRECTLY MADE!");
		}
	}
	
	// HEAVIES
	for (new i = 1; KvizExists(kv, "heavy:nth-child(%i)", i); i++) {
		decl String:weaponname[32], String:logname[32], String:classname[32], String:attributes[256], String:viewmodel[PLATFORM_MAX_PATH], wepid, slot, level, price;
		bool error = false;
		int customid = 9000+count;
		if(!KvizGetStringExact(kv, logname, sizeof(logname), "heavy:nth-child(%i):key", i)) error=true;
		if(!KvizGetStringExact(kv, weaponname, sizeof(weaponname), "heavy:nth-child(%i).displayname", i)) error=true;
		if(!KvizGetStringExact(kv, classname, sizeof(classname), "heavy:nth-child(%i).weaponclass", i)) error=true;
		if(!KvizGetNumExact(kv, slot, "heavy:nth-child(%i).slot", i)) error=true;
		if(!KvizGetNumExact(kv, level, "heavy:nth-child(%i).level", i)) level=1;
		if(!KvizGetNumExact(kv, wepid, "heavy:nth-child(%i).weaponid", i)) error=true;
		if(!KvizGetStringExact(kv, attributes, sizeof(attributes), "heavy:nth-child(%i).attributes", i)) attributes="";
		if(!KvizGetStringExact(kv, viewmodel, sizeof(viewmodel), "heavy:nth-child(%i).viewmodel", i)) viewmodel="";
		if(!KvizGetNumExact(kv, price, "heavy:nth-child(%i).price", i)) error=true;
		
		if(!error)
		{
			TF2Items_CreateWeapon(customid, classname, wepid, slot, 1, level, attributes, -1, viewmodel, true);
			tfgo_weapons_name[count] = weaponname;
			tfgo_weapons[count][0] = customid;
			tfgo_weapons[count][1] = price;
			tfgo_weapons[count][2] = WEAPON_HEAVY; // heavy
			count++;
		}
		else
		{
			PrintToServer("[TFGO] BUMPED INTO AN ERROR IN CONFIG FILE (AT: HEAVY), MAKE SURE THAT IT IS CORRECTLY MADE!");
		}
	}
	
	bool hegrenade_found = false;
	// GRENADES
	for (new i = 1; KvizExists(kv, "grenadeprices:nth-child(%i)", i); i++) {
		decl String:id[32];
		KvizGetStringExact(kv, id, sizeof(id), "grenadeprices:nth-child(%i):key", i);
		if(StrEqual(id, "hegrenade"))
		{
			decl price;
			KvizGetNumExact(kv, price, "grenadeprices:nth-child(%i).price", i);
			tfgo_grenades[GRENADE_FRAG][0] = price;
			hegrenade_found = true;
		}
	}
	if(!hegrenade_found)
	{
		tfgo_grenades[GRENADE_FRAG][0] = 200;
		PrintToServer("[TFGO] Couldn't find hegrenade in config, setting hardcoded price ($200)");
	}
	
	KvizClose(kv);
	
	if (BuyMenu == INVALID_HANDLE)
	{
		BuyMenu = BuildBuyMenu();
		BuyMenu_heavy = BuildBuyMenu_heavy();
		BuyMenu_pistols = BuildBuyMenu_pistols();
		BuyMenu_rifles = BuildBuyMenu_rifles();
		BuyMenu_smgs = BuildBuyMenu_smgs();
		BuyMenu_grenades = BuildBuyMenu_grenades();
	}
	else
	{
		delete(BuyMenu);
		delete(BuyMenu_heavy);
		delete(BuyMenu_pistols);
		delete(BuyMenu_rifles);
		delete(BuyMenu_smgs);
		delete(BuyMenu_grenades);
		BuyMenu = null; BuyMenu_heavy = null; BuyMenu_pistols = null; BuyMenu_rifles = null; BuyMenu_smgs = null; BuyMenu_grenades = null;
		BuyMenu = BuildBuyMenu();
		BuyMenu_heavy = BuildBuyMenu_heavy();
		BuyMenu_pistols = BuildBuyMenu_pistols();
		BuyMenu_rifles = BuildBuyMenu_rifles();
		BuyMenu_smgs = BuildBuyMenu_smgs();
		BuyMenu_grenades = BuildBuyMenu_grenades();
	}
}


/////////////////////
//S E T   M O N E Y//
/////////////////////
public Action:Command_TFGO_Admin_SetMoney(client, args)
{
	if (args == 1) // If only 1 argument was sent
	{
		// Check if client is valid
		if(!IsValidClient(client, false))
		{
			ReplyToCommand(client, "[TFGO] Invalid Client");
			return Plugin_Handled;
		}
		
		char arg[32];
		GetCmdArg(1, arg, sizeof(arg)); // Get the first argument, and write it into the arg variable
		
		if(!IsInteger(arg)) // If the argument is an integer
		{
			ReplyToCommand(client, "[TFGO] Invalid Amount"); // Not integer - don't continue
			return Plugin_Handled; // Break the command
		}
		
		// Argument is an integer
		
		int amount;
		amount = StringToInt(arg); // Convert the arg variable to an integer
		
		tfgo_player_money[client] = amount; // Set the player's money amount
		ReplyToCommand(client, "[TFGO] Set your money to $%i", amount); // Reply to the player
		return Plugin_Handled;
	}
	else if(args == 2)
	{
		char arg[32];
		GetCmdArg(1, arg, sizeof(arg)); // Get the first argument, and write it into the arg variable
		
		if(!IsInteger(arg)) // If the argument is an integer
		{
			ReplyToCommand(client, "[TFGO] Invalid Amount"); // Not integer - don't continue
			return Plugin_Handled; // Break the command
		}
		
		// Argument is an integer
		
		int amount;
		amount = StringToInt(arg); // Convert the arg variable to an integer
		
		char arg2[32];
		GetCmdArg(2, arg2, sizeof(arg2)); // Get the second argument
		
		char target_name[MAX_TARGET_LENGTH]; // Target's name
		int target_list[MAXPLAYERS], target_count; // Target list and count
		bool tn_is_ml; // ???
		
		if ((target_count = ProcessTargetString(
				arg2,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_CONNECTED,
				target_name,
				sizeof(target_name),
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		
		for (int i = 0; i < target_count; i++)
		{
			char targetname[64];
			char sendername[64];
			GetClientName(target_list[i], targetname, sizeof(targetname)); // Get the player's name to display it
			GetClientName(client, sendername, sizeof(sendername)); // Get the sender's name
			tfgo_player_money[target_list[i]] = amount; // Set the player's money amount
			ReplyToCommand(client, "[TFGO] Set %s's money to $%i", targetname, amount); // Return a confirmation message to the player
			PrintToChat(target_list[i], "[TFGO] %s just set your money to $%i!", sendername, amount); // Tell the target about these amazing news!
		}
		return Plugin_Handled;
	}
	else // No arguments
	{
		ReplyToCommand(client, "[TFGO] usage: sm_setmoney <amount> [player]");
		return Plugin_Handled;
	}
}

/////////////////
//B U Y M E N U//
/////////////////
public Action:Command_TFGO_BuyMenu(client, args)
{
	if (!isPlayerNearSpawn(client))
	{
		PrintToChat(client, "[TFGO] You're too far away from the buy zone!");
		return Plugin_Handled;
	}
	else if(!tfgo_canClientBuy[client])
	{
		PrintToChat(client, "[TFGO] Buytime is over");
		return Plugin_Handled;
	}
	
	BuyMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

Menu BuildBuyMenu()
{
	Menu menu = new Menu(Menu_BuyMenu);
	menu.SetTitle("Buy Menu");
	menu.AddItem("pistol", "Pistols");
	menu.AddItem("smg", "SMGs");
	menu.AddItem("rifle", "Rifles");
	menu.AddItem("heavy" ,"Heavies");
	menu.AddItem("grenade", "Grenades");
	
	return menu;
}

Menu BuildBuyMenu_pistols()
{
	bool currentfound = false;
	Menu menu = new Menu(Menu_BuyMenu_buy);
	menu.SetTitle("Pistols");
	
	for(int i = 0 ; i < sizeof(tfgo_weapons_name); i++)
	{
		if(tfgo_weapons[i][2] == 1)
		{
			char currentid[32];
			IntToString(i, currentid, sizeof(currentid));
			menu.AddItem(currentid, tfgo_weapons_name[i]);
			currentfound = true;
		}
	}
	
	if(!currentfound)
	{
		menu.AddItem("", "No weapons in this category.", ITEMDRAW_DISABLED);
	}
	
	menu.ExitBackButton = true;
	
	return menu;
}

Menu BuildBuyMenu_smgs()
{
	bool currentfound = false;
	Menu menu = new Menu(Menu_BuyMenu_buy);
	menu.SetTitle("Smgs");
	
	for(int i = 0 ; i < sizeof(tfgo_weapons_name); i++)
	{
		if(tfgo_weapons[i][2] == 2)
		{
			char currentid[32];
			IntToString(i, currentid, sizeof(currentid));
			menu.AddItem(currentid, tfgo_weapons_name[i]);
			currentfound = true;
		}
	}
	
	if(!currentfound)
	{
		menu.AddItem("", "No weapons in this category.", ITEMDRAW_DISABLED);
	}
	
	menu.ExitBackButton = true;
	
	return menu;
}

Menu BuildBuyMenu_rifles()
{
	bool currentfound = false;
	Menu menu = new Menu(Menu_BuyMenu_buy);
	menu.SetTitle("Rifles");
	
	for(int i = 0 ; i < sizeof(tfgo_weapons_name); i++)
	{
		if(tfgo_weapons[i][2] == 3)
		{
			char currentid[32];
			IntToString(i, currentid, sizeof(currentid));
			menu.AddItem(currentid, tfgo_weapons_name[i]);
			currentfound = true;
		}
	}
	
	if(!currentfound)
	{
		menu.AddItem("", "No weapons in this category.", ITEMDRAW_DISABLED);
	}
	
	menu.ExitBackButton = true;
	
	return menu;
}

Menu BuildBuyMenu_heavy()
{
	bool currentfound = false;
	Menu menu = new Menu(Menu_BuyMenu_buy);
	menu.SetTitle("Heavy");
	
	for(int i = 0 ; i < sizeof(tfgo_weapons_name); i++)
	{
		if(tfgo_weapons[i][2] == 4)
		{
			char currentid[32];
			IntToString(i, currentid, sizeof(currentid));
			menu.AddItem(currentid, tfgo_weapons_name[i]);
			currentfound = true;
		}
	}
	
	if(!currentfound)
	{
		menu.AddItem("", "No weapons in this category.", ITEMDRAW_DISABLED);
	}
	
	menu.ExitBackButton = true;
	
	return menu;
}

Menu BuildBuyMenu_grenades()
{
	bool currentfound = false;
	Menu menu = new Menu(Menu_BuyMenu_buy);
	menu.SetTitle("Grenades");
	
	menu.AddItem("grenade_frag", "HE Grenade");
	
	menu.ExitBackButton = true;
	
	return menu;
}

public int Menu_BuyMenu_buy(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		
		bool found = menu.GetItem(param2, info, sizeof(info));
		
		if(StrEqual(info, "grenade_frag"))
		{
			if(tfgo_clientWeapons[param1][4] == GRENADE_FRAG && tfgo_clientWeapons[param1][5] > 0)
			{
				PrintToChat(param1, "[TFGO] You can't carry any more!");
			}
			else
			{
				tfgo_clientGrenades[param1][GRENADE_FRAG]++;
				PrintToChat(param1, "[TFGO] Bought HE Grenade for $%i", tfgo_grenades[GRENADE_FRAG][0]);
			}
		}
		else
		{
			FakeClientCommandEx(param1, "sm_buy %s", info);
		}
		
		BuyMenu.Display(param1, MENU_TIME_FOREVER);
 
		//PrintToConsole(param1, "You selected item: %d (found? %d info: %s)", param2, found, info);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        BuyMenu.Display(param1, MENU_TIME_FOREVER);
    }

}

public int Menu_BuyMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		
		bool found = menu.GetItem(param2, info, sizeof(info));
		
		if(StrEqual(info, "pistol"))
		{
			BuyMenu_pistols.Display(param1, MENU_TIME_FOREVER);
		}
		if(StrEqual(info, "smg"))
		{
			BuyMenu_smgs.Display(param1, MENU_TIME_FOREVER);
		}
		if(StrEqual(info, "rifle"))
		{
			BuyMenu_rifles.Display(param1, MENU_TIME_FOREVER);
		}
		if(StrEqual(info, "heavy"))
		{
			BuyMenu_heavy.Display(param1, MENU_TIME_FOREVER);
		}
		if(StrEqual(info, "grenade"))
		{
			BuyMenu_grenades.Display(param1, MENU_TIME_FOREVER);
		}
	}
}

/////////////////////////////////
//O T H E R   F U N C T I O N S//
/////////////////////////////////

stock SetSpeed(client, Float:flSpeed)
{
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", flSpeed);
}

public bool:IsInteger(String:buffer[])
{
    new len = strlen(buffer);
    for (new i = 0; i < len; i++)
    {
        if ( !IsCharNumeric(buffer[i]) )
            return false;
    }

    return true;
}

public bool:isPlayerNearSpawn(client)
{
	if(!IsValidClient(client)) return false;
	float currentpos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", currentpos);
	if(GetVectorDistance(currentpos, tfgo_clientSpawnPos[client]) > GetConVarFloat(g_tfgoMaxBuyDistance)) return false;
	return true;
}

stock bool:IsValidClient(client, bool:bCheckAlive=true)
{
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsClientSourceTV(client) || IsClientReplay(client)) return false;
	if(bCheckAlive) return IsPlayerAlive(client);
	return true;
}

public bool:IsClientReady(client)
{
	if(TF2_IsPlayerInCondition(client, TFCond_Cloaked))return false;
	if(TF2_IsPlayerInCondition(client, TFCond_Dazed)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_Taunting)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_Bonked)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_RestrictToMelee)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_MeleeOnly)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_HalloweenKart)) return false;
	return true;
}

public bool:PlayerHasWeapon(client, weapon)
{
	for(int i; i < 3 ; i++)
	{
		if(tfgo_clientWeapons[client][i] == weapon)
		{
			return true;
		}
	}
	return false;
}

///////////////////////////////////////
//C R E D I T : S T A R M A N 2 0 9 8//
///////////////////////////////////////

//https://forums.alliedmods.net/showthread.php?t=97342//

void stripPlayers( const int[] iTargets, const int iTargetCount, const int iSlotFlags, const bool bAreFlagsExcluded/*else = only*/ )
{
	//We know they are alive @ COMMAND_FILTER_ALIVE
	int iCurrentTarget;
	int wpnEnt;
	int wpnSlotIndex;
	
	if ( bAreFlagsExcluded == true )
	{
		for ( int i; i < iTargetCount; ++i )
		{
			iCurrentTarget = iTargets[ i ];
			for ( wpnSlotIndex = 9; wpnSlotIndex >= 0; --wpnSlotIndex )
			{
				//Is slot excluded ?
				if ( ( 1 << wpnSlotIndex ) & iSlotFlags )
					continue;
				
				while ( -1 != ( wpnEnt = GetPlayerWeaponSlot( iCurrentTarget, wpnSlotIndex ) ) && 
					IsValidEntity( wpnEnt ) )
				{
					if ( false == RemovePlayerItem( iCurrentTarget, wpnEnt ) )
						break; //can't remove item, GTFO : change slotIndex
					AcceptEntityInput( wpnEnt, "kill" );
				}
			}
		}
	}
	else //stripOnly flags
	{
		int bitIterator;
		int flags;
		for ( int i; i < iTargetCount; ++i )
		{
			iCurrentTarget = iTargets[ i ];
			//here wpnSlotIndexis a ~~bitIterator
			for ( wpnSlotIndex = 0, bitIterator = 1, flags = iSlotFlags; flags != 0; bitIterator = ( 1 << ++wpnSlotIndex ) )
			{
				//Is slot excluded ?
				if ( bitIterator & flags == 0 )
					continue;
				
				flags &= ~bitIterator; //removed current flag
				
				while ( -1 != ( wpnEnt = GetPlayerWeaponSlot( iCurrentTarget, wpnSlotIndex ) ) && 
					IsValidEntity( wpnEnt ) )
				{
					if ( false == RemovePlayerItem( iCurrentTarget, wpnEnt ) )
						break; //can't remove item, GTFO : change slotIndex
					AcceptEntityInput( wpnEnt, "kill" );
				}
			}
		}
	}
}