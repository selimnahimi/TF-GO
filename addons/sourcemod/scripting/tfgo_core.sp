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

#define REQUIRE_EXTENSIONS
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdktools>
#include <sdkhooks>
#include <kvizzle>
#include <tf2items_giveweapon>
#undef REQUIRE_EXTENSIONS
#include <SteamWorks>
#include <multicolors>

#pragma semicolon 1

#define PLUGIN_VERSION 			"1.6.0"

#define SOUND_THROW 			"weapons/grenade_throw.wav"
#define SOUND_FAILED 			"common/wpn_denyselect.wav"
#define SOUND_EXPLOSION			"weapons/tacky_grenadier_explode3.wav"
#define SOUND_SMOKE				"tfgo/sg_explode.wav"
#define MODEL_GRENADE 			"models/weapons/w_models/w_grenade_frag.mdl"
#define MODEL_MOLOTOV			"models/props_junk/garbage_glassbottle003a.mdl"
#define MODEL_C4				"models/weapons/w_suitcase_passenger.mdl"

#define SOUND_BUY				"items/gunpickup2.wav"
#define SOUND_BOMBTICK			"ui/hitsound_electro1.wav"

#define SOUND_COMMAND_BLOW		"tfgo/radio/blow.wav"
#define SOUND_COMMAND_CLEAR		"tfgo/radio/clear.wav"
#define SOUND_COMMAND_GETINPOS	"tfgo/radio/com_getinpos.wav"
#define SOUND_COMMAND_GO		"tfgo/radio/com_go.wav"
#define SOUND_COMMAND_REPORTIN	"tfgo/radio/com_reportin.wav"
#define SOUND_COMMAND_AFFIRM	"tfgo/radio/ct_affirm.wav"
#define SOUND_COMMAND_BACKUP	"tfgo/radio/ct_backup.wav"
#define SOUND_COMMAND_COVERME	"tfgo/radio/ct_coverme.wav"
#define SOUND_COMMAND_ENEMYS	"tfgo/radio/ct_enemys.wav"
#define SOUND_COMMAND_FINHOLE	"tfgo/radio/ct_fireinhole.wav"
#define SOUND_COMMAND_INPOS		"tfgo/radio/ct_inpos.wav"
#define SOUND_COMMAND_REPORTING	"tfgo/radio/ct_reportingin.wav"
#define SOUND_COMMAND_ENEMYD	"tfgo/radio/enemydown.wav"
#define SOUND_COMMAND_FALLBACK	"tfgo/radio/fallback.wav"
#define SOUND_COMMAND_FIREASSIS	"tfgo/radio/fireassis.wav"
#define SOUND_COMMAND_FOLLOWME	"tfgo/radio/followme.wav"
#define SOUND_COMMAND_LETSGO	"tfgo/radio/letsgo.wav"
#define SOUND_COMMAND_LOCKNLOAD	"tfgo/radio/locknload.wav"
#define SOUND_COMMAND_MOVEOUT	"tfgo/radio/moveout.wav"
#define SOUND_COMMAND_NEGATIVE	"tfgo/radio/negative.wav"
#define SOUND_COMMAND_POSITION	"tfgo/radio/position.wav"
#define SOUND_COMMAND_REGROUP	"tfgo/radio/regroup.wav"
#define SOUND_COMMAND_ROGER		"tfgo/radio/roger.wav"
#define SOUND_COMMAND_STICKTOG	"tfgo/radio/sticktog.wav"
#define SOUND_COMMAND_STORM		"tfgo/radio/stormfront.wav"
#define SOUND_COMMAND_TAKEPOINT	"tfgo/radio/takepoint.wav"

#define SOUND_COMMAND_PLANTED	"tfgo/radio/bombpl.wav"
#define SOUND_COMMAND_DEFUSED	"tfgo/radio/bombdef.wav"

#define SPRITE_RADIO_VMT		"materials/tfgo/radio_icon.vmt"
#define SPRITE_RADIO_VTF		"materials/tfgo/radio_icon.vtf"

#define TOTALGRENADES		3
#define GRENADE_FRAG		1
#define GRENADE_SMOKE		2
#define GRENADE_MOLOTOV		3

#define WEAPON_PISTOL		1
#define WEAPON_SMG			2
#define WEAPON_RIFLE		3
#define WEAPON_HEAVY		4

#define CLASS_MEDIC			5

#define TF_TEAM_BLU			3
#define TF_TEAM_RED			2

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
		Format(error, err_max, "TF:GO only works for Team Fortress 2, duh"); // Error
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
int tfgo_clientWeapons[MAXPLAYERS+1][6]; 				// Bought weapons, by ID
int tfgo_clientGrenades[MAXPLAYERS+1][TOTALGRENADES+1];	// Amount of grenades of every client
float tfgo_clientSpawnPos[MAXPLAYERS+1][3]; 				// Save the position where a specific player spawned at to check buyzone distance.
bool tfgo_canClientBuy[MAXPLAYERS+1];					// Is the player in the bounds of the buytime?
int tfgo_radioEnts[MAXPLAYERS+1];						// Radio sprite entities
bool tfgo_canThrowGrenade[MAXPLAYERS+1];					// Can the player throw a grenade?
bool tfgo_canTalk[MAXPLAYERS+1];							// Can the player play a voice command?
bool tfgo_canSwitchClass[MAXPLAYERS+1];					// Can the player switch classes?
//bool player_CanPlant[MAXPLAYERS + 1];					// Can the player plant the bomb?
bool bomber_canplant = false;
int bomber;

int notifycount;
new String:notifications[2][128];

new g_velocityOffset;

bool tfgo_warmupmode = false;
bool tfgo_roundisgoing = false;

bool tfgo_bombplanted = false;

new Float:bombpos[3];
int bombtime;

int defuser;
float defuse_amount;

int bomb;
int bomb_explosion;
int bomb_dropped;

bool freeze;

// Weapons
new String:tfgo_weapons_name[256][32];
new String:tfgo_weapons_logname[256][32];
int tfgo_weapons[256][4];
int tfgo_grenades[5][1];

// Plant zones
new Float:tfgo_plantzones[128][8];							// Plant zones for maps
new Float:plants_current[8];								// Current map's plantzones
new String:tfgo_plantzones_str[128][32];					// Plant zone map name

new roundwin1, roundwin2, gamerules, timer_bomb, timer_nobomb;

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
Handle g_tfgoSmokeTime;
Handle g_tfgoGrenadeSpam;
Handle g_tfgoGrenadeThrowDelay;
Handle g_tfgoBuyAnywhere;

Handle g_tfgoChatNotify;
Handle g_tfgoNotifyDelay;

// HUD elements
Handle hudMoney;
Handle hudPlus1;
Handle hudPlus2;

// Timers
//Handle DashTimerHandle = INVALID_HANDLE;
//Handle PlantCheck = INVALID_HANDLE;
Handle notifytimer = INVALID_HANDLE;
Handle DefuseCheck = INVALID_HANDLE;
Handle disallowspawn = INVALID_HANDLE;

// Menus
Menu BuyMenu = null;
Menu BuyMenu_pistols = null;
Menu BuyMenu_smgs = null;
Menu BuyMenu_rifles = null;
Menu BuyMenu_heavy = null;
Menu BuyMenu_grenades = null;

Menu VoiceMenu_VoiceResponses = null;
Menu VoiceMenu_VoiceGroup = null;
Menu VoiceMenu_VoiceCommand = null;

// Other
new dashoffset;

///////////////////////////
//P L U G I N   S T A R T//
///////////////////////////
public OnPluginStart()
{
	Precache();
	
	char buffer[128];
	notifications[0] = 		"To open the command menu, type \x05!commands\x01!";
	Format(buffer, sizeof(buffer), "This server is running \x04TF:GO Version %s\x01 by \x05HUNcamper\x01", PLUGIN_VERSION);
	notifications[1] = 		buffer;
	
	
	// C O N V A R S //
	g_tfgoDefaultMoney = CreateConVar("tfgo_defaultmoney", "800", "Default amount of money a player recieves on start");
	g_tfgoMaxMoney = CreateConVar("tfgo_maxmoney", "16000", "Maximum money a player can reach in total");
	g_tfgoMaxBuyDistance = CreateConVar("tfgo_maxbuydistance", "500.0", "Max distance between player and their spawn in hammer units to allow buy");
	g_tfgoBuyTime = CreateConVar("tfgo_buytime", "30", "Buy time in seconds, -1 for infinite");
	g_tfgoBuyAnywhere = CreateConVar("tfgo_buy_anywhere", "0", "If 1, anyone can buy anywhere on the map");
	g_tfgoMoneyOnKill = CreateConVar("tfgo_moneyonkill", "300", "Amount of money to give when killing a player");
	g_tfgoMoneyOnAssist = CreateConVar("tfgo_moneyonassist", "150", "Amount of money to give when assisting in a kill of a player");
	g_tfgoMoneyOnWin = CreateConVar("tfgo_moneyonwin", "3000", "After winning, the players in the winning team recieve $X");
	g_tfgoMoneyOnLose = CreateConVar("tfgo_moneyonlose", "1000", "After losing, the players in the losing team recieve $X");
	g_tfgoSpeed = CreateConVar("tfgo_speed", "250.0", "Speed of players, -1 to disable speed modify feature");
	g_tfgoDefaultMelee = CreateConVar("tfgo_default_melee", "461", "Default melee weapon on spawn, -1 for nothing");
	g_tfgoDefaultSecondary = CreateConVar("tfgo_default_secondary", "23", "Default secondary weapon on spawn, -1 for nothing");
	g_tfgoDefaultPrimary = CreateConVar("tfgo_default_primary", "-1", "Default primary weapon on spawn, -1 for nothing");
	g_tfgoCanDoubleJump = CreateConVar("tfgo_doublejump", "0", "Enable/Disable the Scout's ability to double jump");
	g_tfgoGrenadeDmg = CreateConVar("tfgo_grenade_damage", "100.0", "Damage that the grenade deals (Note that this reduces with distance)");
	g_tfgoGrenadeRadius = CreateConVar("tfgo_grenade_radius", "198.0", "Grenade explosion radius");
	g_tfgoGrenadeDelay = CreateConVar("tfgo_grenade_delay", "3.0", "Grenade explosion delay, in seconds");
	g_tfgoGrenadeSpeed = CreateConVar("tfgo_grenade_speed", "1000.0", "Speed of the grenade when thrown");
	g_tfgoSmokeTime = CreateConVar("tfgo_grenade_smoke_time", "10.0", "Smoke grenade's lifetime, in seconds");
	g_tfgoGrenadeSpam = CreateConVar("tfgo_grenade_spam", "0", "0: delay between grenade throws, 1: no delay");
	g_tfgoGrenadeThrowDelay = CreateConVar("tfgo_grenade_cooldown", "2.0", "Time in seconds between 2 grenade throws, if spam is disabled");
	g_tfgoChatNotify = CreateConVar("tfgo_chat_notify", "1", "Enable/Disable chat notifications");
	g_tfgoNotifyDelay = CreateConVar("tfgo_notify_delay", "30.0", "Time in seconds between 2 chat notifications");
	
	HookConVarChange(g_tfgoNotifyDelay, convarchange_notifydelay);
	
	// A D M I N   C O M M A N D S //
	RegAdminCmd("sm_setmoney", Command_TFGO_Admin_SetMoney, ADMFLAG_ROOT, "sm_setmoney <amount> [player]");
	RegAdminCmd("tfgo_reloadweapons", Command_TFGO_ReloadWeapons, ADMFLAG_ROOT, "tfgo_reloadweapons");
	RegAdminCmd("tfgo_reloadmaps", Command_TFGO_ReloadPlantzones, ADMFLAG_ROOT, "tfgo_reloadmaps");
	RegAdminCmd("sm_givegrenade", Command_TFGO_GiveGrenade, ADMFLAG_ROOT, "sm_givegrenade <player> <amount>");
	RegAdminCmd("sm_forcewin", Command_TFGO_ForceWin, ADMFLAG_ROOT, "sm_forcewin <team>");
	RegAdminCmd("sm_forceplant", Command_TFGO_Admin_ForcePlant, ADMFLAG_ROOT, "sm_forceplant <player>");
	
	// C L I E N T   C O M M A N D S //
	RegConsoleCmd("sm_buy", Command_TFGO_BuyWeapon, "sm_buy <weaponID>");
	RegConsoleCmd("sm_buymenu", Command_TFGO_BuyMenu, "sm_buymenu");
	RegConsoleCmd("sm_grenade", Command_TFGO_ThrowGrenade, "sm_grenade");
	RegConsoleCmd("sm_smoke", Command_TFGO_ThrowSmoke, "sm_smoke");
	//RegConsoleCmd("sm_molotov", Command_TFGO_ThrowMolotov, "sm_molotov");
	// ^^^ molotovs don't work, just yet.
	
	RegConsoleCmd("sm_voice1", Command_TFGO_VoiceGroupMenu);
	RegConsoleCmd("sm_voice2", Command_TFGO_VoiceResponsesMenu);
	RegConsoleCmd("sm_voice3", Command_TFGO_VoiceCommandMenu);
	
	RegConsoleCmd("sm_plant", Command_TFGO_PlantBomb);
	RegConsoleCmd("sm_dropbomb", Command_TFGO_DropBomb);
	
	// H O O K S //
	HookEvent("player_death", Player_Death);
	HookEvent("post_inventory_application", event_PlayerResupply);
	HookEvent("player_spawn", player_spawn); 
	HookEvent("teamplay_round_win", teamplay_round_win);
	HookEvent("teamplay_round_active", teamplay_round_active);
	HookEvent("player_changeclass", player_changeclass, EventHookMode_Pre);
	HookEvent("teamplay_round_start", teamplay_round_start);
	
	// H U D   E L E M E N T S //
	hudMoney = CreateHudSynchronizer();
	hudPlus1 = CreateHudSynchronizer();
	hudPlus2 = CreateHudSynchronizer();
	bomber_canplant = false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		tfgo_player_money[i] = GetConVarInt(g_tfgoDefaultMoney);
		tfgo_canThrowGrenade[i] = true;
		tfgo_canTalk[i] = true;
		for(int b = 0 ; b < 3 ; b++)
		{
			tfgo_clientWeapons[i][b] = -1;
		}
		for(int b = 1 ; b < TOTALGRENADES ; b++)
		{
			tfgo_clientGrenades[i][b] = 0;
		}
	}
	
	for (int i = 0; i < sizeof(tfgo_plantzones); i++)
	{
		tfgo_plantzones[i][0] = -1.0; // A Size
		
		tfgo_plantzones[i][2] = -1.0; // A X
		tfgo_plantzones[i][3] = -1.0; // A Y
		tfgo_plantzones[i][4] = -1.0; // A Z
		
		tfgo_plantzones[i][1] = -1.0; // B Size
		tfgo_plantzones[i][5] = -1.0; // B X
		tfgo_plantzones[i][6] = -1.0; // B Y
		tfgo_plantzones[i][7] = -1.0; // B Z
		
		tfgo_plantzones_str[i] = "NULL"; // Mapname
	}
	
	// T I M E R S //
	//
	
	// O T H E R //
	LoadTranslations("common.phrases"); // Load common translation file
	dashoffset = FindSendPropInfo("CTFPlayer", "m_iAirDash");
	
	for(new client = 1; client <= MaxClients; client++)
	{
		OnClientPostAdminCheck(client);
	}
	
	TFGO_ReloadWeapons();
	//TFGO_ReloadPlantzones();
	
	VoiceMenu_VoiceResponses = BuildVoiceResponseMenu();
	VoiceMenu_VoiceGroup = BuildVoiceGroupMenu();
	VoiceMenu_VoiceCommand = BuildVoiceCommandMenu();
	
	// Auto config
	AutoExecConfig(true, "tfgo_config");
	
	tfgo_warmupmode = false;
	tfgo_roundisgoing = false;
	
	bomber = 1;
	bomb = -999999;
	bomb_explosion = -999999;
	bomb_dropped = -999999;
	freeze = false;
}

public convarchange_notifydelay(ConVar convar, const char[] oldValue, const char[] newValue)
{
	PrintToChatAll("Convar changed");
	if(notifytimer != INVALID_HANDLE)
		notifytimer = INVALID_HANDLE;
		
	notifytimer = CreateTimer(GetConVarFloat(g_tfgoNotifyDelay), timer_notify, _, TIMER_REPEAT);
}

/////////////////////////////
//P L U G I N   U N L O A D//
/////////////////////////////
/*
public OnPluginEnd()
{
	
}
*/

/////////////////////
//M A P   S T A R T//
/////////////////////

public void OnMapStart()
{
	notifytimer = CreateTimer(0.1, timerJump, _, TIMER_REPEAT);
	if(GetConVarBool(g_tfgoChatNotify)) CreateTimer(GetConVarFloat(g_tfgoNotifyDelay), timer_notify, _, TIMER_REPEAT);
	
	TFGO_ReloadWeapons();
	TFGO_ReloadPlantzones();
	
	Precache();
	defuser = -1;
	bomb = -999999;
	defuse_amount = 0.0;
}

public Action:timer_notify(Handle:timer)
{
	if(GetConVarBool(g_tfgoChatNotify))
	{
		PrintToChatAll("\x04[TFGO]\x01 %s", notifications[notifycount]);
		
		if(notifycount+1 > sizeof(notifications)-1)
			notifycount = 0;
		else
			notifycount++;
	}
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
	for(int b = 1 ; b < TOTALGRENADES+1 ; b++)
	{
		tfgo_clientGrenades[client][b] = 0;
	}
	
	if(IsValidClient(client, false) && client != 0)
	{
		tfgo_MoneyHUD[client] = CreateTimer(5.0, DrawHud, client); // Create a HUD timer for the player
		SDKHook(client, SDKHook_PreThink, SDKHooks_tfgoOnPreThink); // Create prethink for Speed changing
		if(tfgo_warmupmode)
		{
			tfgo_player_money[client] = GetConVarInt(g_tfgoMaxMoney); // Set the player's money to max, as it's warmup
		}
		else
		{
			tfgo_player_money[client] = GetConVarInt(g_tfgoDefaultMoney); // Set the player's money to default
		}
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

///////////////////////////
//C L A S S   C H A N G E//
///////////////////////////
public player_changeclass(Handle:event, const char[] name, bool:dontBroadcast)
{
	int id = GetEventInt(event, "userid");
	int class = GetEventInt(event, "class");
	int client = GetClientOfUserId(id);
	if(class == CLASS_MEDIC)
	{
		if(IsValidClient(client, false))
		{
			int team = GetClientTeam(client);
			ShowVGUIPanel(client, team == TF_TEAM_BLU ? "class_blue" : "class_red");
			TF2_SetPlayerClass(client, TFClass_Scout);
			TF2_RespawnPlayer(client);
			PrintToChat(client, "[TFGO] The Medic class is disabled.");
		}
	}
	CreateTimer(1.0, timer_teamcheck);
}

/////////////////////////
//R O U N D   S T A R T//
/////////////////////////
public teamplay_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Round Started");
	tfgo_warmupmode = false;
	tfgo_roundisgoing = false;
	tfgo_bombplanted = false;
	defuser = -1;
	bomb = -999999;
	defuse_amount = 0.0;
	bomber = -1;
	DefuseCheck = INVALID_HANDLE;
	freeze = true;
	
	for (int i = 1; i < MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			SetEntityMoveType(i, MOVETYPE_NONE);
		}
	}
	
	randomBomber();
	KillGameplayEnts();
}

///////////////////////////
//R O U N D   A C T I V E//
///////////////////////////
public teamplay_round_active(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Delay it because the actual event happens 4 seconds before it should??
	CreateTimer(4.0, timer_roundactive);
	disallowspawn = CreateTimer(10.0, timer_disallowspawn);
}

public Action:timer_disallowspawn(Handle:timer)
{
	if(!tfgo_warmupmode)
		tfgo_roundisgoing = true;
	
	freeze = false;
}

public Action:timer_roundactive(Handle:timer)
{
	bool found1 = false; bool found2 = false;
	int random = GetRandomInt(0, 2);
	char command[64];
	if(random == 0) 			command = "letsmove";
	else if(random == 1) 		command = "letsgo";
	else if(random == 2) 		command = "locknload";
	
	for(int i = 0; i < MaxClients ; i++)
	{
		if(IsValidClient(i))
		{
			SetEntityMoveType(i, MOVETYPE_WALK);
			if(GetClientTeam(i) == 2 && !found1)
			{
				PlayVoiceCommand(i, command);
				found1 = true;
			}
			else if(GetClientTeam(i) == 3 && !found2)
			{
				PlayVoiceCommand(i, command);
				found2 = true;
			}
		}
	}
}

///////////////////////////////////////////////////////////
//W A R M U P   ( W A I T I N G   F O R   P L A Y E R S )//
///////////////////////////////////////////////////////////
public void TF2_OnWaitingForPlayersStart()
{
	tfgo_warmupmode = true;
	tfgo_roundisgoing = false;
	for(new i = 0;i < MaxClients;i++)
	{
		if(IsValidClient(i, false))
		{
			if(GetClientTeam(i) == TF_TEAM_BLU || GetClientTeam(i) == TF_TEAM_RED)
			{
				tfgo_player_money[i] = GetConVarInt(g_tfgoMaxMoney);
				TF2_RespawnPlayer(i);
			}
		}
	}
	PrintToChatAll("[TFGO] Warmup Started");
	KillGameplayEnts();
}

public void TF2_OnWaitingForPlayersEnd()
{
	for(new i = 0;i < MaxClients;i++)
	{
		if(IsValidClient(i, false))
		{
			tfgo_player_money[i] = GetConVarInt(g_tfgoDefaultMoney);
			for(int b = 0 ; b < 3 ; b++)
			{
				tfgo_clientWeapons[i][b] = -1; // Reset player inventory
			}
			for(int b = 1 ; b < TOTALGRENADES+1 ; b++)
			{
				tfgo_clientGrenades[i][b] = 0;
			}
		}
	}
	tfgo_warmupmode = false;
	KillGameplayEnts();
	PrintToChatAll("[TFGO] Warmup Ended");
}

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
	tfgo_roundisgoing = false;
}

///////////////////////////
//P L A Y E R   S P A W N//
///////////////////////////

public player_spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid")); // Get client
	// Don't let them spawn mid-round
	if(tfgo_roundisgoing)
	{
		ForcePlayerSuicide(client);
		return;
	}
	float pos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos); // Get the client's current pos
	tfgo_clientSpawnPos[client] = pos; // set it to the global array
	CreateTimer(0.2, timer_SetPlayerHealth, client);
	if(GetConVarFloat(g_tfgoBuyTime) > -1.0)
	{
		CreateTimer(GetConVarFloat(g_tfgoBuyTime), timer_BuyTimeOver, client);
	}
	tfgo_canClientBuy[client] = true;
	tfgo_canThrowGrenade[client] = true;
	
	g_velocityOffset = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	
	BuyMenu.Display(client, MENU_TIME_FOREVER);
	
	tfgo_canSwitchClass[client] = true;
	
	CreateTimer(5.0, timer_disableClassSwitch, client);
	
	// Below was just for debugging
	//PrintToChatAll("Position: %f %f %f", pos[0], pos[1], pos[2]);
}

public Action:timer_disableClassSwitch(Handle:timer, any:client)
{
	tfgo_canSwitchClass[client] = false;
}

public Action:timer_BuyTimeOver(Handle:timer, any:client)
{
	tfgo_canClientBuy[client] = false;
}

public Action:timer_SetPlayerHealth(Handle:timer, any:client)
{
	new MaxHealth = 200;
	SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), MaxHealth, 4, true);
	SetEntData(client, FindDataMapInfo(client, "m_iHealth"), MaxHealth, 4, true);
}

/////////////////////////////////
//P L A Y E R   R E S U P P L Y//
/////////////////////////////////
public event_PlayerResupply(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.1, timer_PlayerResupply, client); // Delay to avoid bugs
	if(IsValidClient(client))
	{
		if(freeze)
			SetEntityMoveType(client, MOVETYPE_NONE);
		else
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
		}
	}
}

public Action:timer_PlayerResupply(Handle:timer, any:client)
{
	decl container[1], melee, secondary, primary;
	char melee_str[32]; char secondary_str[32]; char primary_str[32];
	container[0] = client; // put client id in container, since stripPlayers only accepts arrays
	stripPlayers( container, 1, 0, true ); // strip all weapons from client
	melee = GetConVarInt(g_tfgoDefaultMelee); // melee convar
	secondary = GetConVarInt(g_tfgoDefaultSecondary); // secondary convar
	primary = GetConVarInt(g_tfgoDefaultPrimary); // primary convar
	GetConVarString(g_tfgoDefaultMelee, melee_str, sizeof(melee_str));
	GetConVarString(g_tfgoDefaultSecondary, secondary_str, sizeof(secondary_str));
	GetConVarString(g_tfgoDefaultPrimary, primary_str, sizeof(primary_str));
	
	bool custom = false;
	
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
		if(melee == 0)
		{
			if(!StrEqual(melee_str, "0"))
			{
				melee = GetWeaponByName(melee_str);
				custom = true;
			}
		}
		if(custom) GiveCustomWeapon(client, melee);
		else if(TF2Items_CheckWeapon(melee))
		{
			TF2Items_GiveWeapon(client,melee);
		}
		else
		{
			PrintToChat(client, "[TFGO] Error: Invalid Weapon ID %i", melee); // error if id isn't valid
		}
	}
	custom = false;
	if(secondary != -1)
	{
		if(secondary == 0)
		{
			if(!StrEqual(secondary_str, "0"))
			{
				secondary = GetWeaponByName(secondary_str);
				custom = true;
			}
		}
		if(custom) GiveCustomWeapon(client, secondary);
		else if(TF2Items_CheckWeapon(secondary))
		{
			TF2Items_GiveWeapon(client,secondary);
		}
		else
		{
			PrintToChat(client, "[TFGO] Error: Invalid Weapon ID %i", secondary);
		}
	}
	custom = false;
	if(primary != -1)
	{
		if(primary == 0)
		{
			if(!StrEqual(primary_str, "0"))
			{
				primary = GetWeaponByName(primary_str);
				custom = true;
			}
		}
		if(custom) GiveCustomWeapon(client, primary);
		else if(TF2Items_CheckWeapon(primary))
		{
			TF2Items_GiveWeapon(client,primary);
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
	for(int b = 1 ; b < TOTALGRENADES+1 ; b++)
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
	if(assister != killed && assister != client && GetConVarInt(g_tfgoMoneyOnAssist) >= 1 && IsValidClient(assister, false))
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
	
	if(killed == bomber) {
		TFGO_DropBomb(killed);
	}
	
	CreateTimer(1.0, timer_teamcheck);
}

public Action:timer_teamcheck(Handle:timer)
{
	int ct = CheckTeamNum(TF_TEAM_RED);
	int t = CheckTeamNum(TF_TEAM_BLU);
	PrintToChatAll("CT: %i", ct);
	PrintToChatAll("T: %i", t);
	if(ct < 1)
	{
		TFGO_TWin();
	}
	else if(t < 1 && !tfgo_bombplanted)
	{
		TFGO_CTWin();
	}
}

int CheckTeamNum(team)
{
	int ct = 0;
	int t = 0;
	for (int i = 1; i < MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			if(GetClientTeam(i) == TF_TEAM_RED)
				ct++;
			else if(GetClientTeam(i) == TF_TEAM_BLU)
				t++;
		}
	}
	
	if(team == TF_TEAM_RED)
	{
		return ct;
	}
	else if(team == TF_TEAM_BLU)
	{
		return t;
	}
	else
	{
		PrintToServer("[TFGO] Invalid team: %i", team);
		return -1;
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
	if(IsValidClient(client) && speed > 0.0) SetSpeed(client, speed);
}

// ---- C O M M A N D S ----- //

//////////////////////////
//V O I C E   M E N U S //
//////////////////////////
public Action:Command_TFGO_VoiceGroupMenu(client, args)
{
	VoiceMenu_VoiceGroup.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action:Command_TFGO_VoiceCommandMenu(client, args)
{
	VoiceMenu_VoiceCommand.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action:Command_TFGO_VoiceResponsesMenu(client, args)
{
	VoiceMenu_VoiceResponses.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

/////////////////////
//D R O P   B O M B//
/////////////////////
public Action:Command_TFGO_DropBomb(client, args)
{
	if(IsValidClient(client)) {
		TFGO_DropBomb(client);
	} else {
		ReplyToCommand(client, "[TFGO] Invalid Client");
	}
	return Plugin_Handled;
}

TFGO_DropBomb(client)
{
	if(client != bomber) {
		return;
	}
	new Float:pos[3];
	GetClientEyePosition(client, pos);
	pos[2] -= 30.0;
	
	bomb_dropped = CreateEntityByName("prop_dynamic_override");
	
	if (IsValidEntity(bomb_dropped))
	{
		PrintToChatAll("valid entity, dropping");
		DispatchKeyValue(bomb_dropped, "model", MODEL_C4);
		SetEntProp(bomb_dropped, Prop_Data, "m_CollisionGroup", 1);
		SetEntProp(bomb_dropped, Prop_Send, "m_usSolidFlags", 12);
		//SetEntProp(bomb_dropped, Prop_Data, "m_usSolidFlags", 0x18);
		SetEntProp(bomb_dropped, Prop_Data, "m_nSolidType", 6);
		SetEntityGravity(bomb_dropped, 0.5);
		SetEntPropFloat(bomb_dropped, Prop_Data, "m_flFriction", 5.0); // old: 0.8
		SetEntPropFloat(bomb_dropped, Prop_Send, "m_flElasticity", 0.1); // old: 0.45
		
		DispatchKeyValue(bomb_dropped, "renderfx", "0");
		DispatchKeyValue(bomb_dropped, "rendercolor", "255 255 255");
		DispatchKeyValue(bomb_dropped, "renderamt", "255");
		//SetEntPropEnt(bomb, Prop_Data, "m_hOwnerEntity", client);
		DispatchSpawn(bomb_dropped);
		TeleportEntity(bomb_dropped, pos, NULL_VECTOR, NULL_VECTOR);
		GetEntPropVector(bomb_dropped, Prop_Send, "m_vecOrigin", bombpos);
		CreateTimer(1.0, HookBombPickup);
		bomber = -1;
		PrintToChatTeam(TF_TEAM_BLU, "[TFGO] %N Has dropped the bomb!", client);
	} else {
		PrintToServer("[TFGO] !ERROR! FAILED TO CREATE DROPPED BOMB?");
	}
}

public Action:HookBombPickup(Handle:timer) {
	SDKHook(bomb_dropped, SDKHook_Touch, OnDroppedBombTouch);
}

public OnDroppedBombTouch(client, other)
{
	if(other > MaxClients || other < 1) return;
	if(!IsValidClient(other)) return;
	if(GetClientTeam(other) != TF_TEAM_BLU) return;
	bomber = other;
	PrintCenterText(other, "You've picked up the bomb");
	SDKUnhook(bomb_dropped, SDKHook_Touch, OnDroppedBombTouch);
	AcceptEntityInput(bomb_dropped, "Kill");
}

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
	TFGO_ThrowGrenade(client, GRENADE_FRAG);
	return Plugin_Handled;
}

public Action:Command_TFGO_ThrowSmoke(client, args)
{
	TFGO_ThrowGrenade(client, GRENADE_SMOKE);
	return Plugin_Handled;
}

public Action:Command_TFGO_ThrowMolotov(client, args)
{
	tfgo_clientGrenades[client][GRENADE_MOLOTOV] = 1;
	TFGO_ThrowGrenade(client, GRENADE_MOLOTOV);
	return Plugin_Handled;
}

stock TFGO_ThrowGrenade(client, grenadetype)
{
	// Invalid grenade type
	if(grenadetype != GRENADE_FRAG && grenadetype != GRENADE_SMOKE)
	{
		PrintToServer("[TFGO] %N tried to throw an invalid grenade type: %i", client, grenadetype);
		PrintToConsole(client, "[TFGO] Invalid grenade type. Please contact the server owner.");
	}
	
	// Set grenade model
	new String:model[PLATFORM_MAX_PATH] = MODEL_GRENADE;
	switch(grenadetype)
	{
		case GRENADE_FRAG: model = MODEL_GRENADE;
		case GRENADE_SMOKE: model = MODEL_GRENADE;
		case GRENADE_MOLOTOV: model = MODEL_MOLOTOV;
		default: model = MODEL_GRENADE;
	}
	
	// If the client is valid, ready and can throw a grenade or the spam convar is on
	if(IsValidClient(client) && IsClientReady(client) && (tfgo_canThrowGrenade[client] || GetConVarBool(g_tfgoGrenadeSpam)))
	{
		// If there are too many entities, do not throw the grenade.
		if (GetMaxEntities() - GetEntityCount() < 200)
		{
			PrintToServer("[TFGO] !ERROR! Cannot spawn grenade, too many entities exist. Try reloading the map.");
			PrintToConsole(client, "[TFGO] Failed to throw grenade: too many edicts");
			EmitSoundToClient(client, SOUND_FAILED, client, _, _, _, 1.0);
		}
		
		// Check if player has more than 0 frag grenades
		if (tfgo_clientGrenades[client][grenadetype] > 0)
		{
			decl Float:pos[3];
			decl Float:angs[3];
			decl Float:vecs[3];
			GetClientEyePosition(client, pos);						// Get the position of the player
			GetClientEyeAngles(client, angs);						// Get the angles of the player
			GetAngleVectors(angs, vecs, NULL_VECTOR, NULL_VECTOR);	// Generate angle
			//PrintToChat(client, "Eye angles: %f %f %f", angs[0], angs[1], angs[2]);
			
			// Set throw position to directly in front of player
			pos[0] += vecs[0] * 32.0;
			pos[1] += vecs[1] * 32.0;
			
			ScaleVector(vecs, GetConVarFloat(g_tfgoGrenadeSpeed));
			
			// Create prop entity for the grenade
			new grenade;
			if(grenadetype == GRENADE_MOLOTOV)
				grenade = CreateEntityByName("prop_physics");
			else
				grenade = CreateEntityByName("prop_physics_override");
			
			if (IsValidEntity(grenade))
			{
				DispatchKeyValue(grenade, "model", model);
				DispatchKeyValue(grenade, "solid", "6");
				SetEntityGravity(grenade, 0.5);
				SetEntPropFloat(grenade, Prop_Data, "m_flFriction", 5.0); // old: 0.8
				SetEntPropFloat(grenade, Prop_Send, "m_flElasticity", 0.1); // old: 0.45
				SetEntProp(grenade, Prop_Data, "m_CollisionGroup", 2);
				SetEntProp(grenade, Prop_Data, "m_usSolidFlags", 0x18);
				SetEntProp(grenade, Prop_Data, "m_nSolidType", 6); 
				
				DispatchKeyValue(grenade, "renderfx", "0");
				DispatchKeyValue(grenade, "rendercolor", "255 255 255");
				DispatchKeyValue(grenade, "renderamt", "255");					
				SetEntPropEnt(grenade, Prop_Data, "m_hOwnerEntity", client);
				DispatchSpawn(grenade);
				TeleportEntity(grenade, pos, NULL_VECTOR, vecs);
				
				float idelay = GetConVarFloat(g_tfgoGrenadeDelay);
				
				switch(grenadetype)
				{
					case GRENADE_FRAG: CreateTimer(idelay, Function_GrenadeExplode, grenade);
					case GRENADE_SMOKE: CreateTimer(idelay, Function_SmokeExplode, grenade);
					case GRENADE_MOLOTOV: HookSingleEntityOutput(grenade, "OnBreak", Hook_Molotov, true);
				}
			}
			EmitSoundToAll(SOUND_THROW, client, _, _, _, 1.0);
			tfgo_clientGrenades[client][grenadetype]--;
			//CreateTimer(0.1, timer_fragout, client);
			PlayVoiceCommand(client, "fragout");
			
			if(!GetConVarBool(g_tfgoGrenadeSpam))
			{
				tfgo_canThrowGrenade[client] = false;
				CreateTimer(GetConVarFloat(g_tfgoGrenadeThrowDelay)+0.1, timer_canThrowGrenade, client);
			}
		}
		else
		{
			EmitSoundToClient(client, SOUND_FAILED, client, _, _, _, 1.0);
		}
	}
}

// TO DO
public Action:Hook_Molotov(const char[] output, int caller, int activator, float delay)
{
	int grenade = caller;
	if(IsValidEntity(grenade))
	{
		decl Float:pos[3];
		GetEntPropVector(grenade, Prop_Data, "m_vecOrigin", pos);
		PrintToChatAll("WOHOO, %i IS A VALID ENTITY INDEX! AND IT JUST BROKE! position: %f %f %f", grenade, pos[0], pos[1], pos[2]);
		
		// ATTENTION
		
		// ENV_FIRE IS NOT WORKING IN TF2, APPARENTLY
		// SO NOTHING WILL FUCKING WORK.
		
		new fire = CreateEntityByName("env_fire");
		
		if(IsValidEntity(fire))
		{
			PrintToChatAll("Fire entity is valid");
		}
		
		int client = GetEntProp(grenade, Prop_Send, "m_hOwnerEntity");
		SetEntPropEnt(fire, Prop_Send, "m_hOwnerEntity", client);
		DispatchKeyValue(fire, "firesize", "220");
		//DispatchKeyValue(fire, "fireattack", "5");
		DispatchKeyValue(fire, "health", "5");
		DispatchKeyValue(fire, "firetype", "Normal");
		
		DispatchKeyValueFloat(fire, "damagescale", 5.0);
		DispatchKeyValue(fire, "spawnflags", "256");  //Used to controll flags
		SetVariantString("WaterSurfaceExplosion");
		AcceptEntityInput(fire, "DispatchEffect"); 
		DispatchSpawn(fire);
		TeleportEntity(fire, pos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(fire, "StartFire");
		EmitAmbientSound( SOUND_EXPLOSION, pos, fire, SNDLEVEL_NORMAL );
	}
	else
	{
		PrintToChatAll("GOD DAMN INVALID ENTITY: %i FIX IT YOU PRICK!", grenade);
	}
}

/*

public Action:timer_fragout(Handle:timer, any:client)
{
	PlayVoiceCommand(client, "fragout");
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return entity > MaxClients || !entity;
}

public MolotovTouch(grenade, ent)
{
	if(IsValidEntity(grenade))
	{
		decl String:strName[50];
		GetEntPropString(ent, Prop_Data, "m_iName", strName, sizeof(strName));
		
		if(StrEqual(strName, "outdoors") || StrEqual(strName, "blutriggerfail") || StrEqual(strName, "indoors")) //  || StrEqual(strName, "")
		{
			PrintToChatAll("%i HAS TOUCHED %i, CLASSNAME: %s", grenade, ent, strName);
		}
		else
		{
			CreateTimer(0.1, Function_GrenadeExplode, grenade);
			PrintToChatAll("%i HAS TOUCHED %i, CLASSNAME: %s, EXPLODING!!!", grenade, ent, strName);
			SDKUnhook(grenade, SDKHook_Touch, MolotovTouch);
		}
	}
}
*/
// TO DO END

public Action:timer_canThrowGrenade(Handle:timer, any:client)
{
	tfgo_canThrowGrenade[client] = true;
}

public Action:timer_canTalk(Handle:timer, any:client)
{
	tfgo_canTalk[client] = true;
}

/////////////////////////////////
//S M O K E   E X P L O S I O N//
/////////////////////////////////

public Action:Function_SmokeExplode(Handle:timer, any:grenade)
{
	new Float:delay = GetConVarFloat(g_tfgoSmokeTime);
	//new String:SmokeTransparency[32];
	
	decl Float:pos[3];
	GetEntPropVector(grenade, Prop_Data, "m_vecOrigin", pos);
	
	EmitAmbientSound(SOUND_SMOKE, pos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, 0.0);
	
	new String:originData[64];
	Format(originData, sizeof(originData), "%f %f %f", pos[0], pos[1], pos[2]);
	
	AcceptEntityInput(grenade, "Kill");
	new SmokeEnt = CreateEntityByName("env_smokestack");
	
	if(SmokeEnt)
	{
		// Create the Smoke
		new String:SName[128];
		Format(SName, sizeof(SName), "Smoke%i", grenade);
		DispatchKeyValue(SmokeEnt,"targetname", SName);
		DispatchKeyValue(SmokeEnt,"Origin", originData);
		DispatchKeyValue(SmokeEnt,"BaseSpread", "60");
		DispatchKeyValue(SmokeEnt,"SpreadSpeed", "20");
		DispatchKeyValue(SmokeEnt,"Speed", "50");
		DispatchKeyValue(SmokeEnt,"StartSize", "400");
		DispatchKeyValue(SmokeEnt,"EndSize", "2");
		DispatchKeyValue(SmokeEnt,"Rate", "30");
		DispatchKeyValue(SmokeEnt,"JetLength", "200");
		DispatchKeyValue(SmokeEnt,"Twist", "20"); 
		DispatchKeyValue(SmokeEnt,"RenderColor", "150 150 150"); //red green blue
		DispatchKeyValue(SmokeEnt,"RenderAmt", "255");
		DispatchKeyValue(SmokeEnt,"SmokeMaterial", "particle/particle_smokegrenade1.vmt");
		
		/* OLD, LAGGY SMOKE
		DispatchKeyValue(SmokeEnt,"targetname", SName);
		DispatchKeyValue(SmokeEnt,"Origin", originData);
		DispatchKeyValue(SmokeEnt,"BaseSpread", "100");
		DispatchKeyValue(SmokeEnt,"SpreadSpeed", "20");
		DispatchKeyValue(SmokeEnt,"Speed", "50");
		DispatchKeyValue(SmokeEnt,"StartSize", "300");
		DispatchKeyValue(SmokeEnt,"EndSize", "2");
		DispatchKeyValue(SmokeEnt,"Rate", "100");
		DispatchKeyValue(SmokeEnt,"JetLength", "300");
		DispatchKeyValue(SmokeEnt,"Twist", "20"); 
		DispatchKeyValue(SmokeEnt,"RenderColor", "150 150 150"); //red green blue
		DispatchKeyValue(SmokeEnt,"RenderAmt", "255");
		DispatchKeyValue(SmokeEnt,"SmokeMaterial", "particle/particle_smokegrenade1.vmt");
		*/
		
		DispatchSpawn(SmokeEnt);
		AcceptEntityInput(SmokeEnt, "TurnOn");
		
		new Handle:pack;
		CreateDataTimer(delay, Timer_KillSmoke, pack);
		WritePackCell(pack, SmokeEnt);
		
		//Start timer to remove smoke
		new Float:longerdelay = 5.0 + delay;
		new Handle:pack2;
		CreateDataTimer(longerdelay, Timer_StopSmoke, pack2);
		WritePackCell(pack2, SmokeEnt);
	}
}

public Action:Timer_KillSmoke(Handle:timer, Handle:pack)
{	
	ResetPack(pack);
	new SmokeEnt = ReadPackCell(pack);
	
	StopSmokeEnt(SmokeEnt);
}

public Action:Timer_StopSmoke(Handle:timer, Handle:pack)
{	
	ResetPack(pack);
	new SmokeEnt = ReadPackCell(pack);
	
	RemoveSmokeEnt(SmokeEnt);
}

StopSmokeEnt(target)
{

	if (IsValidEntity(target))
	{
		AcceptEntityInput(target, "TurnOff");
	}
}

RemoveSmokeEnt(target)
{
	if (IsValidEntity(target))
	{
		AcceptEntityInput(target, "Kill");
	}
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
		
		EmitAmbientSound(SOUND_EXPLOSION, pos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, 0.0);
		
		// Raise the position up a bit
		pos[2] += 32.0;

		// Get the owner of the grenade, and which team its on
		new client = GetEntPropEnt(grenade, Prop_Data, "m_hOwnerEntity");
		new team = GetEntProp(client, Prop_Send, "m_iTeamNum");
		
		// Kill the grenade entity
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
		if (!isPlayerNearSpawn(client) && !GetConVarBool(g_tfgoBuyAnywhere) && !tfgo_warmupmode)
		{
			PrintCenterText(client, "Not in a buy zone");
			return Plugin_Handled;
		}
		else if(!tfgo_canClientBuy[client])
		{
			PrintCenterText(client, "Buytime is over");
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
			
			//int givewepid;
			//givewepid = tfgo_weapons[arg][0];
			
			GiveCustomWeapon(client, arg);
			
			// Show on HUD and in chat
			EmitSoundToAll(SOUND_BUY, client, _, _, _, 1.0);
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

/////////////////////////////////////
//R E L O A D   P L A N T Z O N E S//
/////////////////////////////////////
public Action:Command_TFGO_ReloadPlantzones(client, args)
{
	TFGO_ReloadPlantzones();
	return Plugin_Handled;
}

public TFGO_ReloadPlantzones()
{
	for (int i = 0; i < sizeof(tfgo_plantzones); i++)
	{
		tfgo_plantzones[i][0] = -1.0; // A Size
		
		tfgo_plantzones[i][2] = -1.0; // A X
		tfgo_plantzones[i][3] = -1.0; // A Y
		tfgo_plantzones[i][4] = -1.0; // A Z
		
		tfgo_plantzones[i][1] = -1.0; // B Size
		tfgo_plantzones[i][5] = -1.0; // B X
		tfgo_plantzones[i][6] = -1.0; // B Y
		tfgo_plantzones[i][7] = -1.0; // B Z
		
		tfgo_plantzones_str[i] = "NULL"; // Mapname
	}
	// load config file
	decl String:config[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, config, PLATFORM_MAX_PATH, "configs/tfgo_plants.cfg");  
	
	new Handle:kv = KvizCreateFromFile("plantzones", config);
	
	new count = 0;
	
	// Maps
	for (new i = 1; KvizExists(kv, ":nth-child(%i)", i); i++) {
		decl String:map[32], Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, Float:size1, Float:size2;
		bool error = false;
		if (!KvizGetStringExact(kv, map, sizeof(map), ":nth-child(%i):key", i)) { error = true; map = "NOTSET"; }
		if(!KvizGetFloatExact(kv, size1, ":nth-child(%i).a.size", i)) size1=500.0;
		if(!KvizGetFloatExact(kv, x1, ":nth-child(%i).a.x", i)) error=true;
		if(!KvizGetFloatExact(kv, y1, ":nth-child(%i).a.y", i)) error=true;
		if(!KvizGetFloatExact(kv, z1, ":nth-child(%i).a.z", i)) error=true;
		if(!KvizGetFloatExact(kv, size2, ":nth-child(%i).b.size", i)) size2=500.0;
		if(!KvizGetFloatExact(kv, x2, ":nth-child(%i).b.x", i)) error=true;
		if(!KvizGetFloatExact(kv, y2, ":nth-child(%i).b.y", i)) error=true;
		if(!KvizGetFloatExact(kv, z2, ":nth-child(%i).b.z", i)) error=true;
		
		if(!error)
		{
			tfgo_plantzones[count][0] = size1;
			tfgo_plantzones[count][1] = size2;
			tfgo_plantzones[count][2] = x1;
			tfgo_plantzones[count][3] = y1;
			tfgo_plantzones[count][4] = z1;
			tfgo_plantzones[count][5] = x2;
			tfgo_plantzones[count][6] = y2;
			tfgo_plantzones[count][7] = z2;
			tfgo_plantzones_str[count] = map;
			
			count++;
			PrintToServer("[TFGO] Map %s successfully set up", map);
		}
		else
		{
			PrintToServer("[TFGO] BUMPED INTO AN ERROR IN MAP CONFIG FILE (AT: %s), MAKE SURE THAT IT IS CORRECTLY MADE!", map);
		}
	}
	
	TFGO_OnMapConfigLoaded();
	
	KvizClose(kv);
}

// Below will be called when the map config successfully loads.
public TFGO_OnMapConfigLoaded()
{
	//if(PlantCheck != INVALID_HANDLE)
	//	PlantCheck = INVALID_HANDLE;
	char map[64];
	bool found = false;
	GetCurrentMap(map, sizeof(map));
	PrintToChatAll("current map: %s", map);
	
	for (int i = 0; i < sizeof(tfgo_plantzones_str); i++)
	{
		if(StrEqual(tfgo_plantzones_str[i], map))
		{
			for (int b = 0; b < 8; b++)
			{
				plants_current[b] = tfgo_plantzones[i][b];
			}
			found = true;
		}
	}
	if(found)
	{
		// Create a timer for checking the plant
		//PlantCheck = 
		CreateTimer(0.1, TFGO_PlantCheck);
		PrintToServer("[TFGO] Found the current map, timer created");
		KillGameplayEnts();
	}
	else
	{
		PrintToServer("[TFGO] No plant zone config found for the current map (%s), ignoring.", map);
	}
}

// Kills all gameplay changing entities.
public KillGameplayEnts()
{
	new String:ents[19][32];
	ents[0] = "point_template";
	ents[1] = "game_round_win";
	ents[2] = "team_round_timer";
	ents[3] = "team_control_point_master";
	ents[4] = "team_control_point";
	ents[5] = "game_text_tf";
	ents[6] = "logic_auto";
	ents[7] = "point_servercommand";
	ents[8] = "func_capturezone";
	ents[9] = "item_teamflag";
	ents[10] = "item_ammopack_small";
	ents[11] = "item_ammopack_medium";
	ents[11] = "item_ammopack_full";
	ents[12] = "item_healthkit_small";
	ents[13] = "item_healthkit_medium";
	ents[14] = "item_healthkit_full";
	ents[15] = "trigger_capture_area";
	ents[16] = "prop_dynamic";
	ents[17] = "func_brush";
	ents[18] = "trigger_stun";
	
	 
	char cls[32];
	char mn[PLATFORM_MAX_PATH];
	int checked = 0;
	int deleted = 0;
	for(int i = 0; i <= GetMaxEntities() ; i++)
	{
		if(!IsValidEntity(i))
			continue;
		
		GetEntityClassname(i, cls, sizeof(cls));
		
		for (int b = 0; b < sizeof(ents); b++)
		{
			checked++;
			if(StrEqual(cls, ents[b], false))
			{
				if(StrEqual(cls, "prop_dynamic", false))
				{
					GetEntPropString(i, Prop_Data, "m_ModelName", mn, sizeof(mn));
					if(StrEqual(mn, "models/props_doomsday/cap_point_small.mdl", false))
					{
						deleted++;
						RemoveEdict(i);
						PrintToChatAll("Deleted edict: %s", cls);
					}
				}
				else if(StrEqual(cls, "func_brush", false))
				{
					GetEntPropString(i, Prop_Data, "m_iName", mn, sizeof(mn));
					if(StrEqual(mn, "startblock_jumpers", false))
					{
						deleted++;
						RemoveEdict(i);
						PrintToChatAll("Deleted edict: %s", cls);
					}
				}
				else if(StrEqual(cls, "func_brush", false))
				{
					GetEntPropString(i, Prop_Data, "m_iName", mn, sizeof(mn));
					if(StrEqual(mn, "startblock_jumpers", false))
					{
						deleted++;
						RemoveEdict(i);
						PrintToChatAll("Deleted edict: %s", cls);
					}
				}
				else if(StrEqual(cls, "trigger_stun", false))
				{
					GetEntPropString(i, Prop_Data, "m_iName", mn, sizeof(mn));
					if(StrEqual(mn, "stunt_start", false))
					{
						deleted++;
						RemoveEdict(i);
						PrintToChatAll("Deleted edict: %s", cls);
					}
				}
				else
				{
					deleted++;
					RemoveEdict(i);
					PrintToChatAll("Deleted edict: %s", cls);
				}
			}
		}
	}
	PrintToChatAll("Checked: %i, deleted: %i", checked, deleted);
	PrintToChatAll("Creating map timer, gamerules and winround entities");
	
	roundwin1 = CreateEntityByName("game_round_win");
	
	if (IsValidEntity(roundwin1))
	{
		DispatchKeyValue(roundwin1, "force_map_reset", "1");
		DispatchKeyValue(roundwin1, "targetname", "win_blue");
		DispatchKeyValue(roundwin1, "teamnum", "3");
		SetVariantInt(TF_TEAM_BLU);
		AcceptEntityInput(roundwin1, "SetTeam");
		if (!DispatchSpawn(roundwin1))
			PrintToChatAll("[TFGO] ENTITY ERROR Failed to dispatch blue round win entity");
		else
			PrintToChatAll("Created blue win entity");
	}
	else
	{
		PrintToChatAll("Failed to create blue win entity");
	}
	
	roundwin2 = CreateEntityByName("game_round_win");
	
	if (IsValidEntity(roundwin2))
	{
		DispatchKeyValue(roundwin2, "force_map_reset", "1");
		DispatchKeyValue(roundwin2, "targetname", "win_red");
		DispatchKeyValue(roundwin2, "teamnum", "2");
		SetVariantInt(TF_TEAM_RED);
		AcceptEntityInput(roundwin2, "SetTeam");
		if (!DispatchSpawn(roundwin2))
			PrintToChatAll("[TFGO] ENTITY ERROR Failed to dispatch red round win entity");
		else
			PrintToChatAll("Created red win entity");
	}
	else
	{
		PrintToChatAll("Failed to create red win entity");
	}
	
	gamerules = CreateEntityByName("tf_gamerules");
	
	if (IsValidEntity(gamerules))
	{
		DispatchKeyValue(gamerules, "ctf_overtime", "0");
		DispatchKeyValue(gamerules, "hud_type", "0");
		DispatchKeyValue(gamerules, "targetname", "tf_gamerules");
		DispatchSpawn(gamerules);
		PrintToChatAll("Created gamerule entity");
	}
	else
	{
		PrintToChatAll("Failed to create gamerule entity");
	}
	
	timer_bomb = CreateEntityByName("team_round_timer");
	
	if (IsValidEntity(timer_bomb))
	{
		DispatchKeyValue(timer_bomb, "targetname", "timer_bomb");
		DispatchKeyValue(timer_bomb, "StartDisabled", "1");
		DispatchKeyValue(timer_bomb, "start_paused", "0");
		DispatchKeyValue(timer_bomb, "show_time_remaining", "1");
		DispatchKeyValue(timer_bomb, "show_in_hud", "0");
		DispatchKeyValue(timer_bomb, "reset_time", "0");
		DispatchKeyValue(timer_bomb, "max_length", "45");
		DispatchKeyValue(timer_bomb, "auto_countdown", "1");
		DispatchKeyValue(timer_bomb, "timer_length", "45");
		DispatchKeyValue(timer_bomb, "setup_length", "0");
		DispatchSpawn(timer_bomb);
		PrintToChatAll("Created bomb timer entity");
	}
	else
	{
		PrintToChatAll("Failed to create bomb timer entity");
	}
	
	timer_nobomb = CreateEntityByName("team_round_timer");
	
	if (IsValidEntity(timer_nobomb))
	{
		DispatchKeyValue(timer_nobomb, "targetname", "timer_nobomb");
		DispatchKeyValue(timer_nobomb, "StartDisabled", "0");
		DispatchKeyValue(timer_nobomb, "start_paused", "0");
		DispatchKeyValue(timer_nobomb, "show_time_remaining", "1");
		DispatchKeyValue(timer_nobomb, "show_in_hud", "1");
		DispatchKeyValue(timer_nobomb, "reset_time", "1");
		DispatchKeyValue(timer_nobomb, "max_length", "121");
		DispatchKeyValue(timer_nobomb, "auto_countdown", "1");
		DispatchKeyValue(timer_nobomb, "timer_length", "121");
		DispatchKeyValue(timer_nobomb, "setup_length", "10");
		DispatchSpawn(timer_nobomb);
		HookSingleEntityOutput(timer_nobomb, "OnFinished", Hook_Timeout_nobomb, true);
		PrintToChatAll("Created nobomb timer entity");
		AcceptEntityInput(timer_nobomb, "Enable");
	}
	else
	{
		PrintToChatAll("Failed to create nobomb timer entity");
	}
	
	//AcceptEntityInput(roundwin1, "RoundWin");
}

public Action:Hook_Timeout_nobomb(const char[] output, int caller, int activator, float delay)
{
	TFGO_CTWin();
}

public TFGO_CTWin()
{
	if(IsValidEntity(roundwin2))
	{
		disallowspawn = INVALID_HANDLE;
		tfgo_roundisgoing = false;
		AcceptEntityInput(roundwin2, "RoundWin");
	}
	else
	{
		PrintToServer("[TFGO] Tried to call CT Round win, but the win entity doesn't exist, ignoring");
	}
}

public TFGO_TWin()
{
	if(IsValidEntity(roundwin1))
	{
		disallowspawn = INVALID_HANDLE;
		tfgo_roundisgoing = false;
		AcceptEntityInput(roundwin1, "RoundWin");
	}
	else
	{
		PrintToServer("[TFGO] Tried to call T Round win, but the win entity doesn't exist, ignoring");
	}
}

public Action:Command_TFGO_ForceWin(client, args)
{
	char arg[16];
	GetCmdArg(1, arg, sizeof(arg));
	if(StrEqual(arg, "ct"))
	{
		if(IsValidEntity(roundwin2))
		{
			AcceptEntityInput(roundwin2, "RoundWin");
			ReplyToCommand(client, "[TFGO] Successfully forced team %s to win",  arg);
		}
		else
		{
			ReplyToCommand(client, "[TFGO] Could not find entity for the %s team.",  arg);
		}
	}
	else if(StrEqual(arg, "t"))
	{
		if(IsValidEntity(roundwin1))
		{
			AcceptEntityInput(roundwin1, "RoundWin");
			ReplyToCommand(client, "[TFGO] Successfully forced team %s to win",  arg);
		}
		else
		{
			ReplyToCommand(client, "[TFGO] Could not find entity for the %s team.",  arg);
		}
	}
	else
	{
		ReplyToCommand(client, "[TFGO] Invalid team: %s", arg);
	}
	return Plugin_Handled;
}

public Action:TFGO_DefuseCheck(Handle:timer)
{
	if(tfgo_bombplanted)
	{
		if(!IsValidClient(defuser))
		{
			new Float:pos[3];
			for (int i = 1; i < MaxClients; i++)
			{
				if(IsValidClient(i))
				{
					if(GetClientTeam(i) == TF_TEAM_RED)
					{
						GetClientEyePosition(i, pos);
						
						if(GetVectorDistance(pos, bombpos) < 100)
						{
							defuser = i;
						}
					}
				}
			}
		}
		else
		{
			new Float:pos[3];
			GetClientEyePosition(defuser, pos);
			if(GetClientTeam(defuser) == TF_TEAM_RED && GetVectorDistance(pos, bombpos) < 100)
			{
				if(defuse_amount < 100.0)
				{
					defuse_amount += 1.0;
					PrintCenterText(defuser, "Defusing %f%", defuse_amount);
				}
				else
				{
					TFGO_CTWin();
					EmitSoundToAll(SOUND_COMMAND_DEFUSED);
					PrintCenterTextAll("The bomb has been defused");
					KillTimer(timer);
					//AcceptEntityInput(bomb, "Kill");
					tfgo_bombplanted = false;
					//if (PlantCheck != INVALID_HANDLE)
					//	PlantCheck = INVALID_HANDLE;
				}
			}
			else
			{
				defuser = -1;
				defuse_amount = 0.0;
			}
		}
	}
	else
	{
		DefuseCheck = INVALID_HANDLE;
		KillTimer(timer);
	}
}

public Action:TFGO_PlantCheck(Handle:timer)
{
	if(!tfgo_bombplanted)
	{
		CreateTimer(0.1, TFGO_PlantCheck);
	}
	
	//if(!tfgo_bombplanted)
	//{
	for (int i = 1; i < MaxClients; i++)
	{
		if(IsValidClient(i) && bomber == i)
		{
			new Float:pos[3];
			new Float:aPos[3];
			new Float:bPos[3];
			aPos[0] = plants_current[2];
			aPos[1] = plants_current[3];
			aPos[2] = plants_current[4];
			bPos[0] = plants_current[5];
			bPos[1] = plants_current[6];
			bPos[2] = plants_current[7];
			
			new Float:sizeA = plants_current[0];
			new Float:sizeB = plants_current[1];
			GetClientEyePosition(i, pos);
			if(GetVectorDistance(pos, aPos) < sizeA)
			{
				if((GetEntityFlags(i) & FL_ONGROUND) && (GetEntityFlags(i) != FL_DUCKING) )
				{
					// Player is at A, and they're on the ground and not crouching, ready to plant
					if(!bomber_canplant)
					{
						bomber_canplant = true;
						PrintCenterText(bomber, "You have the bomb! Plant it with /plant");
					}
				}
				else
				{
					// Player is at A, but not standing on the ground.
					if(bomber_canplant) bomber_canplant = false;
				}
			}
			else if(GetVectorDistance(pos, bPos) < sizeB)
			{
				if((GetEntityFlags(i) & FL_ONGROUND) && (GetEntityFlags(i) != FL_DUCKING) )
				{
					// Player is at B, and they're on the ground and not crouching, ready to plant
					if(!bomber_canplant)
					{
						bomber_canplant = true;
						PrintCenterText(bomber, "You have the bomb! Plant it with /plant");
					}
				}
				else
				{
					// Player is at B, but not standing on the ground.
					if(bomber_canplant) bomber_canplant = false;
				}
			}
			else
			{
				if(bomber_canplant) bomber_canplant = false;
			}
		}
	}
	//}
}

///////////////////////
//P L A N T   B O M B//
///////////////////////
public Action:Command_TFGO_PlantBomb(client, args)
{
	if(bomber_canplant && bomber == client && !tfgo_bombplanted)
	{
		PrintToChat(client, "attempting to plant");
		new Float:pos[3];
		GetClientEyePosition(client, pos);
		pos[2] -= 40.0;
		
		bomb = CreateEntityByName("prop_dynamic");
		bomb_explosion = CreateEntityByName("env_explosion");
		
		if (IsValidEntity(bomb))
		{
			DispatchKeyValue(bomb, "model", MODEL_C4);
			DispatchKeyValue(bomb, "solid", "6");
			SetEntProp(bomb, Prop_Data, "m_CollisionGroup", 2);
			SetEntProp(bomb, Prop_Data, "m_usSolidFlags", 0x18);
			SetEntProp(bomb, Prop_Data, "m_nSolidType", 6); 
			
			DispatchKeyValue(bomb, "renderfx", "0");
			DispatchKeyValue(bomb, "rendercolor", "255 255 255");
			DispatchKeyValue(bomb, "renderamt", "255");
			//SetEntPropEnt(bomb, Prop_Data, "m_hOwnerEntity", client);
			DispatchSpawn(bomb);
			TeleportEntity(bomb, pos, NULL_VECTOR, NULL_VECTOR);
			GetEntPropVector(bomb, Prop_Send, "m_vecOrigin", bombpos);
			
			tfgo_bombplanted = true;
			PrintCenterTextAll("A bomb has been planted");
			EmitSoundToAll(SOUND_COMMAND_PLANTED);
			defuser = -1;
			defuse_amount = 0.0;
			if(DefuseCheck == INVALID_HANDLE)
				DefuseCheck = CreateTimer(0.1, TFGO_DefuseCheck, _, TIMER_REPEAT);
			
			if(IsValidEntity(timer_bomb) && IsValidEntity(timer_nobomb))
			{
				AcceptEntityInput(timer_nobomb, "Disable");
				AcceptEntityInput(timer_bomb, "Enable");
			}
			else
			{
				PrintToServer("[TFGO] ERROR timers are not valid?");
			}
			bombtime = 0;
			CreateTimer(1.0, timer_bombtick_sound);
			CreateTimer(1.0, timer_bombtick);
			
			bomber = -1;
			
			//if (PlantCheck != INVALID_HANDLE)
			//	PlantCheck = INVALID_HANDLE;
		}
		
		if(IsValidEntity(bomb_explosion))
		{
			DispatchKeyValue(bomb_explosion, "fireballsprite", "sprites/zerogxplode.spr");
			DispatchKeyValue(bomb_explosion, "iMagnitude", "10000");
			DispatchKeyValue(bomb_explosion, "rendermode", "5");
			DispatchSpawn(bomb_explosion);
			TeleportEntity(bomb_explosion, bombpos, NULL_VECTOR, NULL_VECTOR);
		}
	}
	else
	{
		ReplyToCommand(client, "[TFGO] You can't plant!");
	}
	return Plugin_Handled;
}

public Action:timer_bombtick_sound(Handle:timer)
{
	if(IsValidEntity(bomb) && tfgo_bombplanted)
	{
		EmitSoundToAll(SOUND_BOMBTICK, bomb, _, _, _, 1.0);
		if(bombtime <= 20)
		{
			CreateTimer(1.5, timer_bombtick_sound);
		}
		else if(bombtime > 20 && bombtime <= 30)
		{
			CreateTimer(1.0, timer_bombtick_sound);
		}
		else if(bombtime < 40 && bombtime > 30)
		{
			CreateTimer(0.1, timer_bombtick_sound);
		}
		else
		{
			AcceptEntityInput(bomb_explosion, "Explode");
			TFGO_TWin();
		}
	}
	else
	{
		PrintToServer("[TFGO] Bomb entity is invalid");
	}
}

public Action:timer_bombtick(Handle:timer)
{
	if(tfgo_bombplanted)
	{
		if(bombtime < 40)
		{
			bombtime++;
			CreateTimer(1.0, timer_bombtick);
		}
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
		for(int b = 0; b < 4 ; b++)
		{
			tfgo_weapons[i][b] = -1;
		}
	}
	
	int count = 0;
	
	// load config file
	decl String:config[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, config, PLATFORM_MAX_PATH, "configs/tfgo_weapons.cfg");  
	
	new Handle:kv = KvizCreateFromFile("weapons", config);
	
	// PISTOLS
	for (new i = 1; KvizExists(kv, "pistol:nth-child(%i)", i); i++) {
		decl String:weaponname[32], String:logname[32], String:classname[32], String:attributes[256], String:viewmodel[PLATFORM_MAX_PATH], wepid, slot, level, price, ammo;
		bool error = false;
		int customid = 9000+count;
		if(!KvizGetStringExact(kv, logname, sizeof(logname), "pistol:nth-child(%i):key", i)) error=true;
		if(!KvizGetStringExact(kv, weaponname, sizeof(weaponname), "pistol:nth-child(%i).displayname", i)) error=true;
		if(!KvizGetStringExact(kv, classname, sizeof(classname), "pistol:nth-child(%i).weaponclass", i)) error=true;
		if(!KvizGetNumExact(kv, slot, "pistol:nth-child(%i).slot", i)) error=true;
		if(!KvizGetNumExact(kv, level, "pistol:nth-child(%i).level", i)) level=1;
		if(!KvizGetNumExact(kv, wepid, "pistol:nth-child(%i).weaponid", i)) error=true;
		if(!KvizGetNumExact(kv, ammo, "pistol:nth-child(%i).ammo", i)) ammo=-1;
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
			tfgo_weapons[count][3] = ammo;
			tfgo_weapons_logname[count] = logname;
			count++;
		}
		else
		{
			PrintToServer("[TFGO] BUMPED INTO AN ERROR IN CONFIG FILE (AT: PISTOL), MAKE SURE THAT IT IS CORRECTLY MADE!");
		}
	}
	
	// SMGS
	for (new i = 1; KvizExists(kv, "smg:nth-child(%i)", i); i++) {
		decl String:weaponname[32], String:logname[32], String:classname[32], String:attributes[256], String:viewmodel[PLATFORM_MAX_PATH], wepid, slot, level, price, ammo;
		bool error = false;
		int customid = 9000+count;
		if(!KvizGetStringExact(kv, logname, sizeof(logname), "smg:nth-child(%i):key", i)) error=true;
		if(!KvizGetStringExact(kv, weaponname, sizeof(weaponname), "smg:nth-child(%i).displayname", i)) error=true;
		if(!KvizGetStringExact(kv, classname, sizeof(classname), "smg:nth-child(%i).weaponclass", i)) error=true;
		if(!KvizGetNumExact(kv, slot, "smg:nth-child(%i).slot", i)) error=true;
		if(!KvizGetNumExact(kv, level, "smg:nth-child(%i).level", i)) level=1;
		if(!KvizGetNumExact(kv, wepid, "smg:nth-child(%i).weaponid", i)) error=true;
		if(!KvizGetNumExact(kv, ammo, "smg:nth-child(%i).ammo", i)) ammo=-1;
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
			tfgo_weapons[count][3] = ammo;
			tfgo_weapons_logname[count] = logname;
			count++;
		}
		else
		{
			PrintToServer("[TFGO] BUMPED INTO AN ERROR IN CONFIG FILE (AT: SMG), MAKE SURE THAT IT IS CORRECTLY MADE!");
		}
	}
	
	// RIFLES
	for (new i = 1; KvizExists(kv, "rifle:nth-child(%i)", i); i++) {
		decl String:weaponname[32], String:logname[32], String:classname[32], String:attributes[256], String:viewmodel[PLATFORM_MAX_PATH], wepid, slot, level, price, ammo;
		bool error = false;
		int customid = 9000+count;
		if(!KvizGetStringExact(kv, logname, sizeof(logname), "rifle:nth-child(%i):key", i)) error=true;
		if(!KvizGetStringExact(kv, weaponname, sizeof(weaponname), "rifle:nth-child(%i).displayname", i)) error=true;
		if(!KvizGetStringExact(kv, classname, sizeof(classname), "rifle:nth-child(%i).weaponclass", i)) error=true;
		if(!KvizGetNumExact(kv, slot, "rifle:nth-child(%i).slot", i)) error=true;
		if(!KvizGetNumExact(kv, level, "rifle:nth-child(%i).level", i)) level=1;
		if(!KvizGetNumExact(kv, wepid, "rifle:nth-child(%i).weaponid", i)) error=true;
		if(!KvizGetNumExact(kv, ammo, "rifle:nth-child(%i).ammo", i)) ammo=-1;
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
			tfgo_weapons[count][3] = ammo;
			tfgo_weapons_logname[count] = logname;
			count++;
		}
		else
		{
			PrintToServer("[TFGO] BUMPED INTO AN ERROR IN CONFIG FILE (AT: RIFLE), MAKE SURE THAT IT IS CORRECTLY MADE!");
		}
	}
	
	// HEAVIES
	for (new i = 1; KvizExists(kv, "heavy:nth-child(%i)", i); i++) {
		decl String:weaponname[32], String:logname[32], String:classname[32], String:attributes[256], String:viewmodel[PLATFORM_MAX_PATH], wepid, slot, level, price, ammo;
		bool error = false;
		int customid = 9000+count;
		if(!KvizGetStringExact(kv, logname, sizeof(logname), "heavy:nth-child(%i):key", i)) error=true;
		if(!KvizGetStringExact(kv, weaponname, sizeof(weaponname), "heavy:nth-child(%i).displayname", i)) error=true;
		if(!KvizGetStringExact(kv, classname, sizeof(classname), "heavy:nth-child(%i).weaponclass", i)) error=true;
		if(!KvizGetNumExact(kv, slot, "heavy:nth-child(%i).slot", i)) error=true;
		if(!KvizGetNumExact(kv, level, "heavy:nth-child(%i).level", i)) level=1;
		if(!KvizGetNumExact(kv, wepid, "heavy:nth-child(%i).weaponid", i)) error=true;
		if(!KvizGetNumExact(kv, ammo, "heavy:nth-child(%i).ammo", i)) ammo=-1;
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
			tfgo_weapons[count][3] = ammo;
			tfgo_weapons_logname[count] = logname;
			count++;
		}
		else
		{
			PrintToServer("[TFGO] BUMPED INTO AN ERROR IN CONFIG FILE (AT: HEAVY), MAKE SURE THAT IT IS CORRECTLY MADE!");
		}
	}
	
	bool hegrenade_found = false;
	bool smoke_found = false;
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
		else if(StrEqual(id, "smokegrenade"))
		{
			decl price;
			KvizGetNumExact(kv, price, "grenadeprices:nth-child(%i).price", i);
			tfgo_grenades[GRENADE_SMOKE][0] = price;
			smoke_found = true;
		}
	}
	if(!hegrenade_found)
	{
		tfgo_grenades[GRENADE_FRAG][0] = 200;
		PrintToServer("[TFGO] Couldn't find hegrenade in config, setting hardcoded price ($200)");
	}
	if(!smoke_found)
	{
		tfgo_grenades[GRENADE_SMOKE][0] = 200;
		PrintToServer("[TFGO] Couldn't find smokegrenade in config, setting hardcoded price ($200)");
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

/////////////////////////
//F O R C E   P L A N T//
/////////////////////////
public Action:Command_TFGO_Admin_ForcePlant(client, args)
{
	if(args == 1)
	{
		char arg[32];
		GetCmdArg(1, arg, sizeof(arg)); // Get the second argument
		
		char target_name[MAX_TARGET_LENGTH]; // Target's name
		int target_list[MAXPLAYERS], target_count; // Target list and count
		bool tn_is_ml; // ???
		
		if ((target_count = ProcessTargetString(
				arg,
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
			FakeClientCommandEx(target_list[i], "sm_plant");
		}
		return Plugin_Handled;
	}
	else // No arguments
	{
		ReplyToCommand(client, "[TFGO] usage: sm_forceplant <player>");
		return Plugin_Handled;
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
	if (!isPlayerNearSpawn(client) && !GetConVarBool(g_tfgoBuyAnywhere) && !tfgo_warmupmode)
	{
		PrintCenterText(client, "Not in a buy zone");
		return Plugin_Handled;
	}
	else if(!tfgo_canClientBuy[client])
	{
		PrintCenterText(client, "Buytime is over");
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

Menu BuildVoiceResponseMenu()
{
	Menu menu = new Menu(Menu_VoiceCommand);
	menu.SetTitle("Radio Responses/Reports");
	menu.AddItem("roger", "Affirmative/Roger");
	menu.AddItem("enemys", "Enemy Spotted");
	menu.AddItem("backup", "Need Backup");
	menu.AddItem("clear", "Sector Clear");
	menu.AddItem("position", "I'm in position");
	menu.AddItem("reporting", "Reporting In");
	menu.AddItem("blow", "She's gonna Blow!");
	menu.AddItem("negative", "Negative");
	menu.AddItem("enemyd", "Enemy Down");
	
	return menu;
}

Menu BuildVoiceGroupMenu()
{
	Menu menu = new Menu(Menu_VoiceCommand);
	menu.SetTitle("Group Radio Commands");
	menu.AddItem("go", "Go");
	menu.AddItem("fallback", "Fall Back");
	menu.AddItem("sticktog", "Stick Together Team");
	menu.AddItem("getinpos", "Get in Position");
	menu.AddItem("stormthefront", "Storm the Front");
	
	return menu;
}

Menu BuildVoiceCommandMenu()
{
	Menu menu = new Menu(Menu_VoiceCommand);
	menu.SetTitle("Radio Commands");
	menu.AddItem("coverme", "Cover Me");
	menu.AddItem("takepoint", "You Take the Point");
	menu.AddItem("holdpos", "Hold This Position");
	menu.AddItem("regroup", "Regroup Team");
	menu.AddItem("followme", "Follow Me");
	menu.AddItem("needassis", "Taking Fire, Need Assistance");
	
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
			char buffer[64];
			int price = tfgo_weapons[i][1];
			char name[32]; name = tfgo_weapons_name[i];
			Format(buffer, sizeof(buffer), "($%i) %s", price, name);
			menu.AddItem(currentid, buffer);
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
			char buffer[64];
			int price = tfgo_weapons[i][1];
			char name[32]; name = tfgo_weapons_name[i];
			Format(buffer, sizeof(buffer), "($%i) %s", price, name);
			menu.AddItem(currentid, buffer);
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
			char buffer[64];
			int price = tfgo_weapons[i][1];
			char name[32]; name = tfgo_weapons_name[i];
			Format(buffer, sizeof(buffer), "($%i) %s", price, name);
			menu.AddItem(currentid, buffer);
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
			char buffer[64];
			int price = tfgo_weapons[i][1];
			char name[32]; name = tfgo_weapons_name[i];
			Format(buffer, sizeof(buffer), "($%i) %s", price, name);
			menu.AddItem(currentid, buffer);
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
	Menu menu = new Menu(Menu_BuyMenu_buy);
	menu.SetTitle("Gear");
	
	char buffer[64];
	
	int price = tfgo_grenades[GRENADE_FRAG][0];
	Format(buffer, sizeof(buffer), "($%i) HE Grenade", price);
	menu.AddItem("grenade_frag", buffer);
	price = tfgo_grenades[GRENADE_SMOKE][0];
	Format(buffer, sizeof(buffer), "($%i) Smoke Grenade", price);
	menu.AddItem("grenade_smoke", buffer);
	
	menu.ExitBackButton = true;
	
	return menu;
}

public int Menu_VoiceCommand(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		
		menu.GetItem(param2, info, sizeof(info));
		
		PlayVoiceCommand(param1, info);
	}
}

public int Menu_BuyMenu_buy(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		
		menu.GetItem(param2, info, sizeof(info));
		
		if(StrEqual(info, "grenade_frag"))
		{
			if(tfgo_canClientBuy[param1])
			{
				if(tfgo_clientGrenades[param1][GRENADE_FRAG] > 0)
				{
					PrintToChat(param1, "[TFGO] You can't carry any more!");
				}
				else
				{
					if(tfgo_player_money[param1] >= tfgo_grenades[GRENADE_FRAG][0])
					{
						tfgo_clientGrenades[param1][GRENADE_FRAG]++;
						tfgo_player_money[param1] -= tfgo_grenades[GRENADE_FRAG][0];
						EmitSoundToAll(SOUND_BUY, param1, _, _, _, 1.0);
						PrintToChat(param1, "[TFGO] Bought HE Grenade for $%i", tfgo_grenades[GRENADE_FRAG][0]);
						SetHudTextParams(0.14, 0.93, 2.0, 255, 200, 100, 150, 1);
						ShowSyncHudText(param1, hudPlus1, "-$%i", tfgo_grenades[GRENADE_FRAG][0]);
					}
					else
					{
						PrintToChat(param1, "[TFGO] Not enough money! Price: $%i", tfgo_grenades[GRENADE_FRAG][0]);
					}
				}
			}
		}
		else if(StrEqual(info, "grenade_smoke"))
		{
			if(tfgo_canClientBuy[param1])
			{
				if(tfgo_clientGrenades[param1][GRENADE_SMOKE] > 0)
				{
					PrintToChat(param1, "[TFGO] You can't carry any more!");
				}
				else
				{
					if(tfgo_player_money[param1] >= tfgo_grenades[GRENADE_SMOKE][0])
					{
						tfgo_clientGrenades[param1][GRENADE_SMOKE]++;
						tfgo_player_money[param1] -= tfgo_grenades[GRENADE_SMOKE][0];
						EmitSoundToAll(SOUND_BUY, param1, _, _, _, 1.0);
						PrintToChat(param1, "[TFGO] Bought Smoke Grenade for $%i", tfgo_grenades[GRENADE_SMOKE][0]);
						SetHudTextParams(0.14, 0.93, 2.0, 255, 200, 100, 150, 1);
						ShowSyncHudText(param1, hudPlus1, "-$%i", tfgo_grenades[GRENADE_SMOKE][0]);
					}
					else
					{
						PrintToChat(param1, "[TFGO] Not enough money! Price: $%i", tfgo_grenades[GRENADE_SMOKE][0]);
					}
				}
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
		
		menu.GetItem(param2, info, sizeof(info));
		
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

// GAME FRAME
public OnGameFrame()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		new ref = tfgo_radioEnts[i];
		if (ref != 0 && IsValidClient(i))
		{
			new ent = EntRefToEntIndex(ref);
			if (ent > 0)
			{
				new Float:vOrigin[3];
				GetClientEyePosition(i, vOrigin);
				vOrigin[2] += 30.0;

				new Float:vVelocity[3];
				GetEntDataVector(i, g_velocityOffset, vVelocity);

				TeleportEntity(ent, vOrigin, NULL_VECTOR, vVelocity);
			}
		}
	}
	for (new i=1;i<MaxClients; i++)
	{
		if (IsClientInGame(i)&&IsPlayerAlive(i))
		{
			TF2_AddCondition(i, TFCond_Healing, 1.0);
		}
	}
}

stock Precache()
{
	// MATERIALS
	PrecacheGeneric(SPRITE_RADIO_VMT, true);
	PrecacheGeneric("materials/sprites/zerogxplode.spr", true);
	//PrecacheGeneric("materials/models/weapons/w_models/w_c4/w_c4.vmt", true);
	//PrecacheGeneric("materials/models/weapons/w_models/w_c4/w_c4.vtf", true);
	
	// MODELS
	PrecacheModel(MODEL_GRENADE, true);
	PrecacheModel(MODEL_C4, true);
	//PrecacheModel("models/weapons/w_c4_planted.mdl", true);
	
	// SOUNDS
	PrecacheSound(SOUND_FAILED, true);
	PrecacheSound(SOUND_EXPLOSION, true);
	PrecacheSound(SOUND_THROW, true);
	PrecacheSound(SOUND_SMOKE, true);
	PrecacheSound(SOUND_BUY, true);
	PrecacheSound(SOUND_BOMBTICK, true);
	
	// VOICE COMMANDS
	PrecacheSound(SOUND_COMMAND_BLOW, true);
	PrecacheSound(SOUND_COMMAND_CLEAR, true);
	PrecacheSound(SOUND_COMMAND_GETINPOS, true);
	PrecacheSound(SOUND_COMMAND_GO, true);
	PrecacheSound(SOUND_COMMAND_REPORTIN, true);
	PrecacheSound(SOUND_COMMAND_AFFIRM, true);
	PrecacheSound(SOUND_COMMAND_BACKUP, true);
	PrecacheSound(SOUND_COMMAND_COVERME, true);
	PrecacheSound(SOUND_COMMAND_ENEMYS, true);
	PrecacheSound(SOUND_COMMAND_FINHOLE, true);
	PrecacheSound(SOUND_COMMAND_INPOS, true);
	PrecacheSound(SOUND_COMMAND_REPORTING, true);
	PrecacheSound(SOUND_COMMAND_ENEMYD, true);
	PrecacheSound(SOUND_COMMAND_FALLBACK, true);
	PrecacheSound(SOUND_COMMAND_FIREASSIS, true);
	PrecacheSound(SOUND_COMMAND_FOLLOWME, true);
	PrecacheSound(SOUND_COMMAND_LETSGO, true);
	PrecacheSound(SOUND_COMMAND_LOCKNLOAD, true);
	PrecacheSound(SOUND_COMMAND_MOVEOUT, true);
	PrecacheSound(SOUND_COMMAND_NEGATIVE, true);
	PrecacheSound(SOUND_COMMAND_POSITION, true);
	PrecacheSound(SOUND_COMMAND_REGROUP, true);
	PrecacheSound(SOUND_COMMAND_ROGER, true);
	PrecacheSound(SOUND_COMMAND_STICKTOG, true);
	PrecacheSound(SOUND_COMMAND_STORM	, true);
	PrecacheSound(SOUND_COMMAND_TAKEPOINT, true);
	PrecacheSound(SOUND_COMMAND_PLANTED, true);
	PrecacheSound(SOUND_COMMAND_DEFUSED, true);
	
	// Finally, add everything to the download table
	char buffer[PLATFORM_MAX_PATH];
	AddFileToDownloadsTable("sound/tfgo/sg_explode.wav");
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_BLOW);			AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_CLEAR);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_GETINPOS);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_GO);			AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_REPORTIN);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_AFFIRM);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_BACKUP);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_COVERME);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_ENEMYS);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_FINHOLE);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_INPOS);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_REPORTING);	AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_ENEMYD);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_FALLBACK); 	AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_FIREASSIS);	AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_FOLLOWME);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_LETSGO);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_LOCKNLOAD);	AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_MOVEOUT);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_NEGATIVE);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_POSITION);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_REGROUP);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_ROGER);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_STICKTOG);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_STORM);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_TAKEPOINT);	AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_PLANTED);		AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "sound/%s", SOUND_COMMAND_DEFUSED);		AddFileToDownloadsTable(buffer);
	
	/*
	AddFileToDownloadsTable("models/weapons/w_c4_planted.dx80.vtx");
	AddFileToDownloadsTable("models/weapons/w_c4_planted.dx90.vtx");
	AddFileToDownloadsTable("models/weapons/w_c4_planted.phy");
	AddFileToDownloadsTable("models/weapons/w_c4_planted.sw.vtx");
	AddFileToDownloadsTable("models/weapons/w_c4_planted.vvd");
	*/
	
	//AddFileToDownloadsTable(MODEL_C4);
	AddFileToDownloadsTable(SPRITE_RADIO_VMT);
	AddFileToDownloadsTable(SPRITE_RADIO_VTF);
}

stock SetSpeed(client, Float:flSpeed)
{
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", flSpeed);
}

stock PlayVoiceCommand(client, String:info[])
{
	char sound[PLATFORM_MAX_PATH];
	char message[64];
	if(StrEqual(info, "roger"))
	{
		sound = SOUND_COMMAND_ROGER;
		message = "Roger that.";
	}
	else if(StrEqual(info, "enemys"))
	{
		sound = SOUND_COMMAND_ENEMYS;
		message = "Enemy Spotted!";
	}
	else if(StrEqual(info, "backup"))
	{
		sound = SOUND_COMMAND_BACKUP;
		message = "Need Backup!";
	}
	else if(StrEqual(info, "clear"))
	{
		sound = SOUND_COMMAND_CLEAR;
		message = "Sector Clear";
	}
	else if(StrEqual(info, "position"))
	{
		sound = SOUND_COMMAND_INPOS;
		message = "I'm in position";
	}
	else if(StrEqual(info, "reporting"))
	{
		sound = SOUND_COMMAND_REPORTING;
		message = "Reporting in";
	}
	else if(StrEqual(info, "blow"))
	{
		sound = SOUND_COMMAND_BLOW;
		message = "Get out of here, it's gonna blow!";
	}
	else if(StrEqual(info, "negative"))
	{
		sound = SOUND_COMMAND_NEGATIVE;
		message = "Negative.";
	}
	else if(StrEqual(info, "enemyd"))
	{
		sound = SOUND_COMMAND_ENEMYD;
		message = "Enemy Down";
	}
	else if(StrEqual(info, "go"))
	{
		sound = SOUND_COMMAND_GO;
		message = "Go Go Go!";
	}
	else if(StrEqual(info, "fallback"))
	{
		sound = SOUND_COMMAND_FALLBACK;
		message = "Team, Fall Back!";
	}
	else if(StrEqual(info, "sticktog"))
	{
		sound = SOUND_COMMAND_STICKTOG;
		message = "Stick together, Team.";
	}
	else if(StrEqual(info, "getinpos"))
	{
		sound = SOUND_COMMAND_GETINPOS;
		message = "Get in position";
	}
	else if(StrEqual(info, "stormthefront"))
	{
		sound = SOUND_COMMAND_STORM;
		message = "Storm the Front!";
	}
	else if(StrEqual(info, "coverme"))
	{
		sound = SOUND_COMMAND_COVERME;
		message = "Cover me!";
	}
	else if(StrEqual(info, "takepoint"))
	{
		sound = SOUND_COMMAND_TAKEPOINT;
		message = "You take the point";
	}
	else if(StrEqual(info, "holdpos"))
	{
		sound = SOUND_COMMAND_POSITION;
		message = "Hold this position";
	}
	else if(StrEqual(info, "regroup"))
	{
		sound = SOUND_COMMAND_REGROUP;
		message = "Regroup, team";
	}
	else if(StrEqual(info, "followme"))
	{
		sound = SOUND_COMMAND_FOLLOWME;
		message = "Follow me!";
	}
	else if(StrEqual(info, "needassis"))
	{
		sound = SOUND_COMMAND_FIREASSIS;
		message = "Taking fire, need Assistance!";
	}
	else if(StrEqual(info, "letsgo"))
	{
		sound = SOUND_COMMAND_LETSGO;
		message = "NONE";
	}
	else if(StrEqual(info, "letsmove"))
	{
		sound = SOUND_COMMAND_MOVEOUT;
		message = "NONE";
	}
	else if(StrEqual(info, "locknload"))
	{
		sound = SOUND_COMMAND_LOCKNLOAD;
		message = "NONE";
	}
	else if(StrEqual(info, "fragout"))
	{
		sound = SOUND_COMMAND_FINHOLE;
		message = "Fire in the Hole!";
	}
	else if(StrEqual(info, "smokeout"))
	{
		sound = SOUND_COMMAND_FINHOLE;
		message = "Fire in the Hole!";
	}
	else
	{
		sound = "";
		message = "ERROR";
	}
	
	if(!IsValidClient(client)) message = "ERROR";
	
	if(!StrEqual(message, "ERROR"))
	{
		if(tfgo_canTalk[client] || StrEqual(info, "smokeout") || StrEqual(info, "fragout"))
		{
			for(int i = 1; i < MaxClients ; i++)
			{
				if(IsValidClient(i, false))
				{
					if(GetClientTeam(i) == GetClientTeam(client))
					{
						if(!StrEqual(message, "NONE")) PrintToChat(i, "%N (radio): %s", client, message);
						EmitSoundToClient(i, sound);
					}
				}
			}
			if(tfgo_canTalk[client])
			{
				createRadioSprite(client);
				tfgo_canTalk[client] = false;
				CreateTimer(2.1, timer_canTalk, client);
			}
		}
	}
}

/* Chooses a random bomber from the Terrorist team (BLU) */
stock randomBomber()
{
	bool notenough = false;
	if(GetTeamClientCount(TF_TEAM_BLU) < 1)
	{
		// Not enough players
		notenough = true;
	}
	
	if(!notenough)
	{
		int count = 0;
		int plys[MAXPLAYERS + 1];
		for (int i = 1; i < MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				if(GetClientTeam(i) == TF_TEAM_BLU) // if player is in terrorist team (BLU)
				{
					plys[count] = i;
					count++;
				}
			}
		}
		
		int retries = 5; // Max retries of random generation before giving up
		
		for (int i = 0; i < retries; i++)
		{
			new random = GetRandomInt(0, count);
			int ply = plys[random];
			if(IsValidClient(ply))
			{
				if(GetClientTeam(ply) == TF_TEAM_BLU)
				{
					bomber = ply;
					PrintCenterText(ply, "You have the bomb! Go to a bombsite, and plant it with /plant");
					break;
				}
			}
		}
	}
	else
	{
		PrintToServer("[TFGO] Not enough players in the Terrorist team, ignoring random bomb giving");
	}
}

stock createRadioSprite(client) {
	new ent = CreateEntityByName("env_sprite_oriented");
	if (ent) {
		decl String:sprite[40];
		decl String:spriteName[16];
		
		sprite = SPRITE_RADIO_VMT;
		spriteName = "sprite_radio";
		
		DispatchKeyValue(ent, "model", sprite);
		DispatchKeyValue(ent, "classname", "env_sprite_oriented");
		DispatchKeyValue(ent, "spawnflags", "1");
		DispatchKeyValue(ent, "scale", "1");
		DispatchKeyValue(ent, "rendermode", "1");
		DispatchKeyValue(ent, "rendercolor", "255 255 255");
		DispatchKeyValue(ent, "targetname", spriteName);
		DispatchSpawn(ent);
		
		new Float:vOrigin[3];
		GetClientEyePosition(client, vOrigin);

		vOrigin[2] += 30.0;

		TeleportEntity(ent, vOrigin, NULL_VECTOR, NULL_VECTOR);
		CreateTimer(2.0, timer_killSprite, client);
		
		tfgo_radioEnts[client] = EntIndexToEntRef(ent);
		
		SetEntityMoveType(ent, MOVETYPE_NOCLIP);
	}
}

public Action:timer_killSprite(Handle:timer, any:client)
{
	new ref = tfgo_radioEnts[client];
	if (ref != 0)
	{
		new ent = EntRefToEntIndex(ref);
		if (ent > 0 && IsValidEntity(ent))
		{
			AcceptEntityInput(ent, "kill");
		}
		tfgo_radioEnts[client] = 0;
	}
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

public PrintToChatTeam(team, const char[] text, any ...)
{
	for (int i = 1; i < MaxClients; i++)
	{
		if(IsValidClient(i, false))
		{
			if(GetClientTeam(i) == team)
			{
				int len = strlen(text) + 255;
				char[] textFormatted = new char[len];
				VFormat(textFormatted, len, text, 3);
				PrintToChat(i, textFormatted);
			}
		}
	}
}

public int GetWeaponByName(String:weapon[])
{
	PrintToServer("Searching for: %s", weapon);
	for(int i = 0 ; i < sizeof(tfgo_weapons_logname) ; i++)
	{
		if(StrEqual(tfgo_weapons_logname[i], weapon))
		{
			PrintToServer("Found");
			return i;
		}
	}
	PrintToServer("not found");
	return -1;
}

public bool GiveCustomWeapon(client, id)
{
	int ammo = tfgo_weapons[id][3];
	int wep = tfgo_weapons[id][0];
	TF2Items_GiveWeapon(client, wep);
	if(ammo != -1)
	{
		new weapon;
		if(tfgo_weapons[id][2] == WEAPON_PISTOL)
		{
			weapon = GetPlayerWeaponSlot(client, 1);
		}
		else if(tfgo_weapons[id][2] == WEAPON_SMG)
		{
			weapon = GetPlayerWeaponSlot(client, 0);
		}
		else if(tfgo_weapons[id][2] == WEAPON_RIFLE)
		{
			weapon = GetPlayerWeaponSlot(client, 0);
		}
		else if(tfgo_weapons[id][2] == WEAPON_HEAVY)
		{
			weapon = GetPlayerWeaponSlot(client, 0);
		}
		new iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		new iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		if(IsValidEntity(weapon))
		{
			SetEntData(client, iAmmoTable+iOffset, ammo, 4, true);
		}
		else
		{
			PrintToServer("[TFGO] SET AMMO ERROR: INVALID SLOT/WEAPON");
		}
	}
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