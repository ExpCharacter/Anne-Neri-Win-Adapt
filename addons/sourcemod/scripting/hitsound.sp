#pragma semicolon 1
#pragma newdecls required
//使用新语法
#include <sourcemod>
#include <dhooks>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <l4d2_ems_hud>

#define PLUGIN_VERSION "1.1.0"
#define CVAR_FLAGS FCVAR_NOTIFY

#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))


ConVar plugin_enable;
ConVar sound_enable;
ConVar pic_enable;
ConVar pic_infect_kill_enable;
ConVar pic_infect_hit_enable;

int g_iActiveWO = -1;

int    g_iReport, g_iReportLine, g_iReportTime;
ConVar g_hReport, g_hReportLine, g_hReportTime;

float    ihud_x, ihud_y, ihud_width, ihud_height;
ConVar ghud_x, ghud_y, ghud_width, ghud_height;


int 	g_style[MAXPLAYERS+1] = {1, ...};
int 	g_crosshair_red[MAXPLAYERS+1] = {100, ...};
int 	g_crosshair_red_change[MAXPLAYERS+1] = {255, ...};
int 	g_crosshair_blue[MAXPLAYERS+1] = {100, ...};
int 	g_crosshair_blue_change[MAXPLAYERS+1] = {0, ...};
int 	g_crosshair_green[MAXPLAYERS+1] = {255, ...};
int 	g_crosshair_green_change[MAXPLAYERS+1] = {0, ...};

Handle g_styleCookie = INVALID_HANDLE;
Handle g_crosshair_red_Cookie = INVALID_HANDLE;
Handle g_crosshair_red_change_Cookie = INVALID_HANDLE;
Handle g_crosshair_blue_Cookie = INVALID_HANDLE;
Handle g_crosshair_blue_change_Cookie = INVALID_HANDLE;
Handle g_crosshair_green_Cookie = INVALID_HANDLE;
Handle g_crosshair_green_change_Cookie = INVALID_HANDLE;

Handle Time = INVALID_HANDLE;
Handle Time1 = INVALID_HANDLE;
Handle sound_1 = INVALID_HANDLE;
Handle sound_2 = INVALID_HANDLE;
Handle sound_3 = INVALID_HANDLE;
Handle style2_sound1 = INVALID_HANDLE;
Handle style2_sound2 = INVALID_HANDLE;
Handle style2_sound3 = INVALID_HANDLE;
Handle hit1 = INVALID_HANDLE;
Handle hit2 = INVALID_HANDLE;
Handle hit3 = INVALID_HANDLE;
Handle hit4 = INVALID_HANDLE;
Handle g_blast = INVALID_HANDLE;
Handle g_fire = INVALID_HANDLE;
Handle g_hit = INVALID_HANDLE;
Handle g_kill = INVALID_HANDLE;
Handle g_melee = INVALID_HANDLE;

char g_sZombieClass[][] = 
{
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"witch",
	"Tank"
};

char g_sZombieName[][] = 
{
	"舌头",
	"胖子",
	"猎人",
	"口水",
	"猴子",
	"牛牛",
	"女巫",
	"坦克"
};

enum {
	kill_1,
	hit_armor,
	kill,
	hit_armor_1
};

Handle g_taskCountdown[33] = {INVALID_HANDLE, ...};
Handle g_taskClean[33] = {INVALID_HANDLE, ...};
int g_killCount[33] = {0, ...};
bool IsVictimDeadPlayer[MAXPLAYERS+1] = { false, ... };

public Plugin myinfo = 
{
	name = "击中反馈",
	author = "TsukasaSato",
	description = "自定义击中和击杀的图标、声音、时长",
	version = "PLUGIN_VERSION"
}

public void OnPluginStart()
{
	LoadGameCFG();
	char Game_Name[64];
	GetGameFolderName(Game_Name, sizeof(Game_Name));
	if(!StrEqual(Game_Name, "left4dead2", false))
	{
		SetFailState("本插件仅支持L4D2!");
	}

	CreateConVar("l4d2_hitsound", PLUGIN_VERSION, "Plugin version", 0);
	Time = CreateConVar("sm_hitsound_showtime_kill", "2.0", "击杀图标存在的时长(默认为0.3)");
	Time1 = CreateConVar("sm_hitsound_showtime_hit", "0.2", "击中图标存在的时长(默认为0.1)");
	sound_1 = CreateConVar("sm_hitsound_mp3_headshot", "hitsound/headshot.mp3", "爆头音效的地址");	
	sound_2 = CreateConVar("sm_hitsound_mp3_hit", "hitsound/hit.mp3", "击中音效的地址");
	sound_3 = CreateConVar("sm_hitsound_mp3_kill", "hitsound/kill.mp3", "击杀音效的地址");
	style2_sound1 = CreateConVar("sm_hitsound_classic_headshot", "level/timer_bell.wav", "无需下载内容的爆头音效的地址");	
	style2_sound2 = CreateConVar("sm_hitsound_classic_hit", "buttons/button22.wav", "无需下载内容的击中音效的地址");
	style2_sound3 = CreateConVar("sm_hitsound_classic_kill", "level/pointscored.wav", "无需下载内容的击杀音效的地址");
	hit1 = CreateConVar("sm_hitsound_pic_headshot", "overlays/head2", "爆头图标的地址");
	hit2 = CreateConVar("sm_hitsound_pic_hit", "overlays/body2", "击中图标的地址");
	hit3 = CreateConVar("sm_hitsound_pic_kill", "overlays/head2", "击杀图标的地址");
	hit4 = CreateConVar("sm_hitsound_pic_hit_auto", "overlays/body2", "自动武器击杀图标的地址");
	
	g_iActiveWO	= FindSendPropInfo("CBasePlayer", "m_hActiveWeapon");
	
	sound_enable = CreateConVar("sm_hitsound_sound_enable", "1", "是否开启音效(0-关, 1-开)", CVAR_FLAGS);
	pic_enable = CreateConVar("sm_hitsound_pic_enable", "1", "是否开启特感的击杀图标(0-关, 1-开)", CVAR_FLAGS);
	pic_infect_kill_enable = CreateConVar("sm_hitsound_pic_infect_kill_enable", "1", "是否开启感染者的击杀图标(0-关, 1-开)", CVAR_FLAGS);	
	pic_infect_hit_enable = CreateConVar("sm_hitsound_pic_infect_hit_enable", "1", "是否开启感染者的命中图标(0-关, 1-开)", CVAR_FLAGS);	
	
	g_blast = CreateConVar("sm_blast_damage_enable", "0", "是否开启爆炸反馈提示(0-关, 1-开 建议关闭)", CVAR_FLAGS);
	g_fire = CreateConVar("sm_fire_damage_enable", "0", "是否开启火烧反馈提示", CVAR_FLAGS);
	g_hit = CreateConVar("sm_hit_infected_enable", "1", "是否开启感染者击中反馈声音(0-关, 1-开 建议开启)", CVAR_FLAGS);
	g_kill = CreateConVar("sm_kill_infected_enable", "1", "是否开启感染者击杀反馈声音(0-关, 1-开 建议开启)", CVAR_FLAGS);
	g_melee = CreateConVar("sm_hitsound_melee_enable", "1", "是否开启近战反馈(0-关, 1-开 建议开启)", CVAR_FLAGS);
	
	g_hReport = CreateConVar("sm_hitsound_death_report_enable", "1", "是否开启单人模式仿COD的击杀播报(0-关, 1-开)", CVAR_FLAGS);
	g_hReportLine = CreateConVar("sm_hitsound_death_report_line", "5", "设置单人模式仿COD的击杀播报显示多少行. 0=禁用(最多5行).", CVAR_FLAGS);
	g_hReportTime = CreateConVar("sm_hitsound_death_report_time", "5", "设置多少秒后删除击杀播报首行(最低5秒).", CVAR_FLAGS);
	
	ghud_x = CreateConVar("sm_hitsound_death_report_x", "-0.315", "单人模式仿COD的击杀播报的X坐标", CVAR_FLAGS);
	ghud_y = CreateConVar("sm_hitsound_death_report_y", "0.4", "单人模式仿COD的击杀播报的Y坐标", CVAR_FLAGS);
	ghud_width = CreateConVar("sm_hitsound_death_report_width", "1.0", "单人模式仿COD的击杀播报的宽度", CVAR_FLAGS);
	ghud_height = CreateConVar("sm_hitsound_death_report_height", "0.22", "单人模式仿COD的击杀播报的高度", CVAR_FLAGS);
	
	plugin_enable = CreateConVar("sm_hitsound_enable","1","是否开启本插件(0-关, 1-开)", CVAR_FLAGS);
	
	g_styleCookie	 = RegClientCookie("hm_style", "", CookieAccess_Protected);
	g_crosshair_red_Cookie = RegClientCookie("hm_red", "", CookieAccess_Protected);
	g_crosshair_red_change_Cookie = RegClientCookie("hm_red_change", "", CookieAccess_Protected);
	g_crosshair_blue_Cookie = RegClientCookie("hm_blue", "", CookieAccess_Protected);
	g_crosshair_blue_change_Cookie = RegClientCookie("hm_blue_change", "", CookieAccess_Protected);
	g_crosshair_green_Cookie = RegClientCookie("hm_green", "", CookieAccess_Protected);
	g_crosshair_green_change_Cookie = RegClientCookie("hm_green_change", "", CookieAccess_Protected);
	
	RegConsoleCmd("sm_hitmarker", Command_HM);
	RegConsoleCmd("sm_hitmarkers", Command_HM);
	RegConsoleCmd("sm_hm", Command_HM);
	RegConsoleCmd("sm_bhm", Command_HM);
	RegConsoleCmd("sm_hmarker", Command_HM);
	RegConsoleCmd("sm_crosshair_green", Command_Green, "换自己的准星颜色green");
	RegConsoleCmd("sm_crosshair_green_change", Command_Green_Change, "换自己的反馈变色时准星颜色green");
	RegConsoleCmd("sm_crosshair_red", Command_Red, "换自己的准星颜色red");
	RegConsoleCmd("sm_crosshair_red_change", Command_Red_Change, "换自己的反馈变色时准星颜色red");
	RegConsoleCmd("sm_crosshair_blue", Command_Blue, "换自己的准星颜色blue");
	RegConsoleCmd("sm_crosshair_blue_change", Command_Blue_Change, "换自己的反馈变色时准星颜色blue");
	
	AutoExecConfig(true, "l4d2_hitsound");//是否生成cfg注释即不生成
	if (GetConVarInt(plugin_enable) == 1)
	{
		HookEvent("infected_hurt",			Event_InfectedHurt, EventHookMode_Pre); //感染受伤
		HookEvent("infected_death",			Event_InfectedDeath); //感染死亡
		HookEvent("player_death",			Event_PlayerDeath); // 玩家死亡
		HookEvent("player_hurt",				Event_PlayerHurt, EventHookMode_Pre); //玩家受伤
		HookEvent("tank_spawn", Event_TankSpawn);
		HookEvent("player_spawn", Event_Spawn);
		HookEvent("round_end",		Event_RoundEnd);	//回合结束.
		HookEvent("round_start", Event_round_start,EventHookMode_Post);
		HookEvent("player_incapacitated", PlayerIncap);
	}
}

void LoadGameCFG()
{
	GameData hGameData = new GameData("l4d2_emshud_info");
	if(!hGameData) 
		SetFailState("Failed to load 'l4d2_emshud_info.txt' gamedata.");
	DHookSetup hDetour = DHookCreateFromConf(hGameData, "HibernationUpdate");
	CloseHandle(hGameData);
}

public void OnPluginEnd()
{
	Cleanup(true);
}

void Cleanup(bool bPluginEnd = false)
{
	if (bPluginEnd)
	{
		if (g_styleCookie != INVALID_HANDLE)
			CloseHandle(g_styleCookie);
		if (g_crosshair_red_Cookie != INVALID_HANDLE)
			CloseHandle(g_crosshair_red_Cookie);
		if (g_crosshair_red_change_Cookie != INVALID_HANDLE)
			CloseHandle(g_crosshair_red_change_Cookie);
		if (g_crosshair_blue_Cookie != INVALID_HANDLE)
			CloseHandle(g_crosshair_blue_Cookie);
		if (g_crosshair_blue_change_Cookie != INVALID_HANDLE)
			CloseHandle(g_crosshair_blue_change_Cookie);
		if (g_crosshair_green_Cookie != INVALID_HANDLE)
			CloseHandle(g_crosshair_green_Cookie);
		if (g_crosshair_green_change_Cookie != INVALID_HANDLE)
			CloseHandle(g_crosshair_green_change_Cookie);
	}
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int Client = GetClientOfUserId(GetEventInt(event, "userid"));
	IsVictimDeadPlayer[Client] = false;
}


public Action PlayerIncap(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(victim) && GetClientTeam(victim) == 3 && GetEntProp(victim, Prop_Send, "m_zombieClass") == 8)
	IsVictimDeadPlayer[victim] = true;
	return Plugin_Continue;
}

public Action Event_TankSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int tank = GetClientOfUserId(GetEventInt(event, "userid"));
	IsVictimDeadPlayer[tank] = false;
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	bool heatshout = false;
	heatshout = GetEventBool(event, "headshot");
	int IsHeatshout = 0;
	int damagetype = GetEventInt(event, "type");
	char WeaponName[64];
	GetEventString(event, "weapon", WeaponName, sizeof(WeaponName));
	
	if(GetConVarInt(g_fire) == 0 && damagetype & DMG_BURN)
        return Plugin_Changed;
		
	if(GetConVarInt(g_blast) == 0 && damagetype & DMG_BLAST)
		return Plugin_Changed;

	if (heatshout) IsHeatshout = 1;
	
	if(IsValidClient(victim))
	{
		if(GetClientTeam(victim) == 3)
		{
			if(IsValidClient(attacker))
			{
				if(GetClientTeam(attacker) == 2)	
				{
					if(!IsFakeClient(attacker))
					{
						char sType[32];
						strcopy(sType, sizeof(sType), IsHeatshout == 0 ? "击杀" : "爆头");
						int iHLZClass = GetEntProp(victim, Prop_Send, "m_zombieClass") - 1;
						if(IsHeatshout)
						{
							if(GetConVarInt(pic_enable) == 1)
							{
								if(strcmp(WeaponName, "melee", false) == 0 || strcmp(WeaponName, "chainsaw", false) == 0){
									if(GetConVarInt(g_melee) == 1){
								switch(g_style[attacker])
								{
								case 1:{
								ShowKillMessage(attacker,kill_1);}
								case 2:{
								PrintToChat(attacker, "\x04%s\x01了%s", sType, GetPlayerName(victim, iHLZClass));
								}
								case 3:{
								}
								}
								}}
								else{
								switch(g_style[attacker])
								{
								case 1:{
								ShowKillMessage(attacker,kill_1);}
								case 2:{
								PrintToChat(attacker, "\x04%s\x01了%s", sType, GetPlayerName(victim, iHLZClass));
								}
								case 3:{
								}
								}}
							}
							char sound1[64],sound1_2[64]; 
							GetConVarString(sound_1, sound1, sizeof(sound1));
							GetConVarString(style2_sound1, sound1_2, sizeof(sound1_2));
							if (GetConVarInt(sound_enable) == 1)
							{
								PrecacheSound(sound1, true);
								PrecacheSound(sound1_2, true);
								if(strcmp(WeaponName, "melee", false) == 0 || strcmp(WeaponName, "chainsaw", false) == 0){
								if(GetConVarInt(g_melee) == 1){
								switch(g_style[attacker])
								{
								case 1:{
								EmitSoundToClient(attacker, sound1, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								}
								case 2:{
								EmitSoundToClient(attacker, sound1_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								}
								case 3:{
								}
								}
								}}
								else{
								switch(g_style[attacker])
								{
								case 1:{
								EmitSoundToClient(attacker, sound1, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								}
								case 2:{
								EmitSoundToClient(attacker, sound1_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								}
								case 3:{
								}
								}}
							}
							if(g_taskClean[attacker] != INVALID_HANDLE)
							{
								KillTimer(g_taskClean[attacker]);
								g_taskClean[attacker] = INVALID_HANDLE;
							}
							float showtime = GetConVarFloat(Time);
							g_taskClean[attacker] = CreateTimer(showtime,task_Clean,attacker);
							}else{
							if(GetConVarInt(pic_enable) == 1)
							{
							if(strcmp(WeaponName, "melee", false) == 0 || strcmp(WeaponName, "chainsaw", false) == 0){
							if(GetConVarInt(g_melee) == 1){
								switch(g_style[attacker])
								{
								case 1:{
								ShowKillMessage(attacker,kill);}
								case 2:{
								PrintToChat(attacker, "\x04%s\x01了%s", sType, GetPlayerName(victim, iHLZClass));
								}
								case 3:{
								}
								}}}
							else{
							switch(g_style[attacker])
								{
								case 1:{
								ShowKillMessage(attacker,kill);}
								case 2:{
								PrintToChat(attacker, "\x04%s\x01了%s", sType, GetPlayerName(victim, iHLZClass));
								}
								case 3:{
								}
								}}
							}
							if(g_taskClean[attacker] != INVALID_HANDLE)
							{
								KillTimer(g_taskClean[attacker]);
								g_taskClean[attacker] = INVALID_HANDLE;
							}
							float showtime = GetConVarFloat(Time);
							g_taskClean[attacker] = CreateTimer(showtime,task_Clean,attacker);
							char sound3[64],sound3_2[64];
							GetConVarString(sound_3, sound3, sizeof(sound3));
							GetConVarString(style2_sound3, sound3_2, sizeof(sound3_2));
							if (GetConVarInt(sound_enable) == 1)
							{
								PrecacheSound(sound3, true);
								PrecacheSound(sound3_2, true);
								if(strcmp(WeaponName, "melee", false) == 0 || strcmp(WeaponName, "chainsaw", false) == 0){
								if(GetConVarInt(g_melee) == 1){
								switch(g_style[attacker])
								{
								case 1:{
								EmitSoundToClient(attacker, sound3, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								}
								case 2:{
								EmitSoundToClient(attacker, sound3_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								}
								case 3:{
								}
								}
								}}
								else{
								switch(g_style[attacker])
								{
								case 1:{
								EmitSoundToClient(attacker, sound3, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								}
								case 2:{
								EmitSoundToClient(attacker, sound3_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								}
								case 3:{
								}
								}} 
							}				
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int damagetype = GetEventInt(event, "type");
	char WeaponName[64];
	GetEventString(event, "weapon", WeaponName, sizeof(WeaponName));
//火inferno
//火entityflame

	if(GetConVarInt(g_fire) == 0 && damagetype & DMG_BURN)
        return Plugin_Changed;

	if(GetConVarInt(g_blast) == 0 && damagetype & DMG_BLAST)
        return Plugin_Changed;
		
	
	if(strcmp(WeaponName, "sniper_awp", false) == 0||strcmp(WeaponName, "sniper_scout", false) == 0||strcmp(WeaponName, "pistol_magnum", false) == 0||strcmp(WeaponName, "shotgun_spas", false) == 0||strcmp(WeaponName, "hunting_rifle", false) == 0||strcmp(WeaponName, "sniper_military", false) == 0||strcmp(WeaponName, "autoshotgun", false) == 0||strcmp(WeaponName, "pumpshotgun", false) == 0||strcmp(WeaponName, "shotgun_chrome", false) == 0||strcmp(WeaponName, "pistol", false) == 0)
	{
	if(IsValidClient(victim))
	{
		if(IsValidClient(attacker))
		{
			if(!IsFakeClient(attacker))
			{
				if(GetClientTeam(victim) == 3)
				{
					if(IsVictimDeadPlayer[victim] == false)
					{
					if(GetConVarInt(pic_enable) == 1)
							{
							if(strcmp(WeaponName, "melee", false) == 0 || strcmp(WeaponName, "chainsaw", false) == 0){
							if(GetConVarInt(g_melee) == 1){
								ShowKillMessage(attacker,hit_armor);}}
							else{
							ShowKillMessage(attacker,hit_armor);}
							}
					char sound2[64],sound2_2[64];
					GetConVarString(sound_2, sound2, sizeof(sound2));	
					GetConVarString(style2_sound2, sound2_2, sizeof(sound2_2));
					if (GetConVarInt(sound_enable) == 1)
					{
						//PrintToChatAll("获取到的武器是%s", WeaponName);
						PrecacheSound(sound2, true);
						PrecacheSound(sound2_2, true);
						if(strcmp(WeaponName, "melee", false) == 0 || strcmp(WeaponName, "chainsaw", false) == 0){
						if(GetConVarInt(g_melee) == 1){
						switch(g_style[attacker])
						{
						case 1:{
						EmitSoundToClient(attacker, sound2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
						}
						case 2:{
						EmitSoundToClient(attacker, sound2_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
						}
						case 3:{
								}
						}
						}}
						else{
						switch(g_style[attacker])
						{
						case 1:{
						EmitSoundToClient(attacker, sound2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
						}
						case 2:{
						EmitSoundToClient(attacker, sound2_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
						}
						case 3:{
								}
						}}
					}
					if(g_taskClean[attacker] != INVALID_HANDLE)
					{
						KillTimer(g_taskClean[attacker]);
						g_taskClean[attacker] = INVALID_HANDLE;
					}
					float showtime = GetConVarFloat(Time1);
					g_taskClean[attacker] = CreateTimer(showtime,task_Clean,attacker);
					}
				}
			}
		}
	}
	}
	else
	{
	if(IsValidClient(victim))
	{
		if(IsValidClient(attacker))
		{
			if(!IsFakeClient(attacker))
			{
				if(GetClientTeam(victim) == 3)
				{
					if(IsVictimDeadPlayer[victim] == false)
					{
					if (GetConVarInt(pic_enable) == 1)
					{
						if(strcmp(WeaponName, "melee", false) == 0 || strcmp(WeaponName, "chainsaw", false) == 0){
							if(GetConVarInt(g_melee) == 1){
								ShowKillMessage(attacker,hit_armor_1);}}
						else{
							ShowKillMessage(attacker,hit_armor_1);}
					}
					char sound2[64],sound2_2[64];
					GetConVarString(sound_2, sound2, sizeof(sound2));	
					GetConVarString(style2_sound2, sound2_2, sizeof(sound2_2));
					if (GetConVarInt(sound_enable) == 1)
					{
						//PrintToChatAll("获取到的武器是%s", WeaponName);
						PrecacheSound(sound2, true);
						PrecacheSound(sound2_2, true);
						if(strcmp(WeaponName, "melee", false) == 0 || strcmp(WeaponName, "chainsaw", false) == 0){
						if(GetConVarInt(g_melee) == 1){
						switch(g_style[attacker])
						{
						case 1:{
						EmitSoundToClient(attacker, sound2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
						}
						case 2:{
						EmitSoundToClient(attacker, sound2_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
						}
						case 3:{
								}
						}
						}}
						else{
						switch(g_style[attacker])
						{
						case 1:{
						EmitSoundToClient(attacker, sound2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
						}
						case 2:{
						EmitSoundToClient(attacker, sound2_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
						}
						case 3:{
								}
						}} 
					}
					if(g_taskClean[attacker] != INVALID_HANDLE)
					{
						KillTimer(g_taskClean[attacker]);
						g_taskClean[attacker] = INVALID_HANDLE;
					}
					float showtime = GetConVarFloat(Time1);
					g_taskClean[attacker] = CreateTimer(showtime,task_Clean,attacker);
					}
				}
			}
		}
	}
	
	}
	
	return Plugin_Changed;
}

public Action Event_InfectedDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetEventInt(event, "infected_id");
	char sname[32];
	GetEdictClassname(victim, sname, sizeof(sname));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	bool heatshout = false;
	heatshout = GetEventBool(event, "headshot");
	bool damagetype = GetEventBool(event, "blast");
	int IsHeatshout = 0;
	int WeaponID = GetEventInt(event, "weapon_id");


	if(GetConVarInt(g_fire) == 0 && WeaponID == 0)
    return Plugin_Changed;


	if(GetConVarInt(g_blast) == 0 && damagetype)
    return Plugin_Changed;
	
	if (heatshout) IsHeatshout = 1;
	
	if(IsValidClient(attacker))
	{
	if (IsHeatshout)
	{
		if(GetClientTeam(attacker) == 2)	
		{
			if(!IsFakeClient(attacker))
			{
				if(GetConVarInt(pic_infect_kill_enable) == 1)
							{
							int iWeapon;
							char WeaponName[21];
							iWeapon = GetEntDataEnt2(attacker, g_iActiveWO);
							if(IsValidEntity(iWeapon)==false) return Plugin_Continue;
							
							GetEntityNetClass( iWeapon, WeaponName, sizeof( WeaponName ) );
							if (StrEqual(WeaponName,"CTerrorMeleeWeapon",false)==true){
							if(GetConVarInt(g_melee) == 1){
								ShowKillMessage(attacker,kill_1);}}
							else{
							ShowKillMessage(attacker,kill_1);}
							}
				char sound1[64],sound1_2[64];
				GetConVarString(sound_1, sound1, sizeof(sound1));
				GetConVarString(style2_sound1, sound1_2, sizeof(sound1_2));
				if (GetConVarInt(sound_enable) == 1)
				{
				if(GetConVarInt(g_kill) == 1)
				{
							PrecacheSound(sound1, true);
							PrecacheSound(sound1_2, true);
							int iWeapon;
							char WeaponName[21];
							iWeapon = GetEntDataEnt2(attacker, g_iActiveWO);
							if(IsValidEntity(iWeapon)==false) return Plugin_Continue;
							
							GetEntityNetClass( iWeapon, WeaponName, sizeof( WeaponName ) );
							if (StrEqual(WeaponName,"CTerrorMeleeWeapon",false)==true){
								if(GetConVarInt(g_melee) == 1){
								switch(g_style[attacker])
								{
								case 1:{
								EmitSoundToClient(attacker, sound1, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								}
								case 2:{
								EmitSoundToClient(attacker, sound1_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								}
								case 3:{
								}
								}}}
							else {switch(g_style[attacker])
								{
								case 1:{
								EmitSoundToClient(attacker, sound1, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								}
								case 2:{
								EmitSoundToClient(attacker, sound1_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								}
								case 3:{
								}
								}}
				}
				}
				if(g_taskClean[attacker] != INVALID_HANDLE)
				{
				KillTimer(g_taskClean[attacker]);
				g_taskClean[attacker] = INVALID_HANDLE;
				}
				float showtime = GetConVarFloat(Time);
				g_taskClean[attacker] = CreateTimer(showtime,task_Clean,attacker);
			}
		}
	}
	else 
	{
	if(GetClientTeam(attacker) == 2)	
		{
			if(!IsFakeClient(attacker))
			{
			if(GetConVarInt(pic_infect_kill_enable) == 1)
							{
							int iWeapon;
							char WeaponName[21];
							iWeapon = GetEntDataEnt2(attacker, g_iActiveWO);
							if(IsValidEntity(iWeapon)==false) return Plugin_Continue;
							
							GetEntityNetClass( iWeapon, WeaponName, sizeof( WeaponName ) );
							if (StrEqual(WeaponName,"CTerrorMeleeWeapon",false)==true){
							if(GetConVarInt(g_melee) == 1){
								ShowKillMessage(attacker,kill);}}
							else{
							ShowKillMessage(attacker,kill);}
							}
			char sound3[64],sound3_2[64];
			GetConVarString(sound_3, sound3, sizeof(sound3));
			GetConVarString(style2_sound3, sound3_2, sizeof(sound3_2));
			if (GetConVarInt(sound_enable) == 1)
			{
				if(GetConVarInt(g_kill) == 1)
				{
				//PrintToChatAll("获取到的id是%i", WeaponID);
							PrecacheSound(sound3, true);
							PrecacheSound(sound3_2, true);
							int iWeapon;
							char WeaponName[21];
							iWeapon = GetEntDataEnt2(attacker, g_iActiveWO);
							if(IsValidEntity(iWeapon)==false) return Plugin_Continue;
							
							GetEntityNetClass( iWeapon, WeaponName, sizeof( WeaponName ) );
							if (StrEqual(WeaponName,"CTerrorMeleeWeapon",false)==true){
							if(GetConVarInt(g_melee) == 1){
							switch(g_style[attacker])
							{
							case 1:{
							EmitSoundToClient(attacker, sound3, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							case 2:{
							EmitSoundToClient(attacker, sound3_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							case 3:{
								}
							}
							}}
							else{
							switch(g_style[attacker])
							{
							case 1:{
							EmitSoundToClient(attacker, sound3, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							case 2:{
							EmitSoundToClient(attacker, sound3_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							case 3:{
								}
							}} 
				}				
			}
			if(g_taskClean[attacker] != INVALID_HANDLE)
			{
				KillTimer(g_taskClean[attacker]);
				g_taskClean[attacker] = INVALID_HANDLE;
			}
			float showtime = GetConVarFloat(Time);
			g_taskClean[attacker] = CreateTimer(showtime,task_Clean,attacker);
				}
			}
		}
	}
	return Plugin_Continue;
}

public void OnMapStart()
{
	GetCvars();
	EnableHUD();
}


public Action Event_InfectedHurt(Handle event, const char[] event_name, bool dontBroadcast)
{
	int victim = GetEventInt(event, "entityid");
	char sname[32];
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int dmg = GetEventInt(event, "amount");
	int eventhealth = GetEntProp(victim, Prop_Data, "m_iHealth");
	bool IsVictimDead = false;
	int damagetype = GetEventInt(event, "type");

	if(GetConVarInt(g_fire) == 0 && damagetype & DMG_BURN)
        return Plugin_Changed;

	if(GetConVarInt(g_blast) == 0 && damagetype & DMG_BLAST)
        return Plugin_Changed;
	
	if(IsValidClient(attacker))
	{
	if(!IsFakeClient(attacker))
		{
	if((eventhealth - dmg) <= 0)
			{
				IsVictimDead = true;
			}


	if(!IsVictimDead)
	{
		if (StrEqual(sname, "witch"))
		{
			if(GetConVarInt(pic_infect_hit_enable) == 1)
							{
							int iWeapon;
							char WeaponName[21];
							iWeapon = GetEntDataEnt2(attacker, g_iActiveWO);
							if(IsValidEntity(iWeapon)==false) return Plugin_Continue;
							
							GetEntityNetClass( iWeapon, WeaponName, sizeof( WeaponName ) );
							if (StrEqual(WeaponName,"CTerrorMeleeWeapon",false)==true){
							if(GetConVarInt(g_melee) == 1){
								ShowKillMessage(attacker,hit_armor);}}
							else{
							ShowKillMessage(attacker,hit_armor);}
							}
			char sound2[64],sound2_2[64];
			GetConVarString(sound_2, sound2, sizeof(sound2));
			GetConVarString(style2_sound2, sound2_2, sizeof(sound2_2));
			if (GetConVarInt(sound_enable) == 1)
			{
				if(GetConVarInt(g_hit) == 1)
				{
							PrecacheSound(sound2, true);
							PrecacheSound(sound2_2, true);
							int iWeapon;
							char WeaponName[21];
							iWeapon = GetEntDataEnt2(attacker, g_iActiveWO);
							if(IsValidEntity(iWeapon)==false) return Plugin_Continue;
							
							GetEntityNetClass( iWeapon, WeaponName, sizeof( WeaponName ) );
							if (StrEqual(WeaponName,"CTerrorMeleeWeapon",false)==true){
							if(GetConVarInt(g_melee) == 1){
							switch(g_style[attacker])
							{
							case 1:{
							EmitSoundToClient(attacker, sound2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							case 2:{
							EmitSoundToClient(attacker, sound2_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							case 3:{
								}
							}
							}}
							else{
							switch(g_style[attacker])
							{
							case 1:{
							EmitSoundToClient(attacker, sound2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							case 2:{
							EmitSoundToClient(attacker, sound2_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							case 3:{
								}
							}
							}
				}
			}
			if(g_taskClean[attacker] != INVALID_HANDLE)
			{
				KillTimer(g_taskClean[attacker]);
				g_taskClean[attacker] = INVALID_HANDLE;
			}
			float showtime = GetConVarFloat(Time1);
			g_taskClean[attacker] = CreateTimer(showtime,task_Clean,attacker);
			}else{
			if(GetConVarInt(pic_infect_hit_enable) == 1)
							{
							int iWeapon;
							char WeaponName[21];
							iWeapon = GetEntDataEnt2(attacker, g_iActiveWO);
							if(IsValidEntity(iWeapon)==false) return Plugin_Continue;
							
							GetEntityNetClass( iWeapon, WeaponName, sizeof( WeaponName ) );
							if (StrEqual(WeaponName,"CTerrorMeleeWeapon",false)==true){
							if(GetConVarInt(g_melee) == 1){
								ShowKillMessage(attacker,hit_armor_1);}}
							else{
							ShowKillMessage(attacker,hit_armor_1);}
							}
			char sound2[64],sound2_2[64];
			GetConVarString(sound_2, sound2, sizeof(sound2));
			GetConVarString(style2_sound2, sound2_2, sizeof(sound2_2));
			if (GetConVarInt(sound_enable) == 1)
			{
				if(GetConVarInt(g_hit) == 1)
				{
							PrecacheSound(sound2, true);
							PrecacheSound(sound2_2, true);
							int iWeapon;
							char WeaponName[21];
							iWeapon = GetEntDataEnt2(attacker, g_iActiveWO);
							if(IsValidEntity(iWeapon)==false) return Plugin_Continue;
							
							GetEntityNetClass( iWeapon, WeaponName, sizeof( WeaponName ) );
							if (StrEqual(WeaponName,"CTerrorMeleeWeapon",false)==true){
							if(GetConVarInt(g_melee) == 1){
							switch(g_style[attacker])
							{
							case 1:{
							EmitSoundToClient(attacker, sound2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							case 2:{
							EmitSoundToClient(attacker, sound2_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							case 3:{
								}
							}
							}}
							else{
							switch(g_style[attacker])
							{
							case 1:{
							EmitSoundToClient(attacker, sound2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							case 2:{
							EmitSoundToClient(attacker, sound2_2, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							case 3:{
								}
							}} 
				}
			}
			if(g_taskClean[attacker] != INVALID_HANDLE)
			{
				KillTimer(g_taskClean[attacker]);
				g_taskClean[attacker] = INVALID_HANDLE;
			}
			float showtime = GetConVarFloat(Time1);
			g_taskClean[attacker] = CreateTimer(showtime,task_Clean,attacker);
				}
			}

	
	
		}
	}
	return Plugin_Changed;
}

public void Event_round_start(Handle event,const char[] name,bool dontBroadcast)
{
	for(int client=1;client <= MaxClients;client++)
	{
		g_killCount[client] = 0;
		if(g_taskCountdown[client] != INVALID_HANDLE)
		{
			KillTimer(g_taskCountdown[client]);
			g_taskCountdown[client] = INVALID_HANDLE;
		}
	}
	IsDisplayTimeOut();
}

public Action task_Countdown(Handle Timer, int client)
{
	g_killCount[client] --;
	if(!IsPlayerAlive(client) || g_killCount[client]==0)
	{
		KillTimer(Timer);
		g_taskCountdown[client] = INVALID_HANDLE;
	}
	return Plugin_Continue;
}

public Action task_Clean(Handle Timer, int client)
{
	KillTimer(Timer);
	g_taskClean[client] = INVALID_HANDLE;
	int iFlags = GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", iFlags);
	switch(g_style[client])
	{
	case 1:{
	ClientCommand(client, "r_screenoverlay \"\"");
	IsRemoveOtherHUD();
	}
	case 2:{
		ClientCommand(client, "cl_crosshair_green %d",g_crosshair_green[client]);
		ClientCommand(client, "cl_crosshair_red %d",g_crosshair_red[client]);
		ClientCommand(client, "cl_crosshair_blue %d",g_crosshair_blue[client]);
		IsRemoveOtherHUD();
	}
	case 3:{
								}
	}
	return Plugin_Handled;
}

public void ShowKillMessage(int client,int type)
{
	char overlays_file[64];
	char pic1[64];
	char pic2[64];
	char pic3[64];
	char pic4[64];
	GetConVarString(hit1, pic1, sizeof(pic1));
	GetConVarString(hit2, pic2, sizeof(pic2));
	GetConVarString(hit3, pic3, sizeof(pic3));
	GetConVarString(hit4, pic4, sizeof(pic4));
	Format(overlays_file,sizeof(overlays_file),"%s.vtf",pic1);
	PrecacheDecal(overlays_file,true);
	Format(overlays_file,sizeof(overlays_file),"%s.vtf",pic2);
	PrecacheDecal(overlays_file,true);
	Format(overlays_file,sizeof(overlays_file),"%s.vtf",pic3);
	PrecacheDecal(overlays_file,true);
	Format(overlays_file,sizeof(overlays_file),"%s.vtf",pic4);
	PrecacheDecal(overlays_file,true);
	Format(overlays_file,sizeof(overlays_file),"%s.vmt",pic1);
	PrecacheDecal(overlays_file,true);
	Format(overlays_file,sizeof(overlays_file),"%s.vmt",pic2);
	PrecacheDecal(overlays_file,true);
	Format(overlays_file,sizeof(overlays_file),"%s.vmt",pic3);
	PrecacheDecal(overlays_file,true);
	Format(overlays_file,sizeof(overlays_file),"%s.vmt",pic4);
	PrecacheDecal(overlays_file,true);
	
	
	int iFlags = GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", iFlags);
	
	switch(g_style[client])
	{
	case 1:{
	switch(type)
	{
		case (kill_1):{
			ClientCommand(client, "r_screenoverlay \"%s\"",pic1);
			if(g_iReport==1){
			IsDeathMessage();
			ZombieKillHeadShot();}
			}
		case (kill):{
			ClientCommand(client, "r_screenoverlay \"%s\"",pic3);
			if(g_iReport==1){
			IsDeathMessage();
			ZombieKill();}
			}
		case (hit_armor):ClientCommand(client, "r_screenoverlay \"%s\"",pic2);
		case (hit_armor_1):ClientCommand(client, "r_screenoverlay \"%s\"",pic4);
		
	}
	}
	case 2:{
	switch(type)
	{
		case (hit_armor):
		{
		ClientCommand(client, "cl_crosshair_green %d",g_crosshair_green_change[client]);
		ClientCommand(client, "cl_crosshair_red %d",g_crosshair_red_change[client]);
		ClientCommand(client, "cl_crosshair_blue %d",g_crosshair_blue_change[client]);
		}
		case (hit_armor_1):
		{
		ClientCommand(client, "cl_crosshair_green %d",g_crosshair_green_change[client]);
		ClientCommand(client, "cl_crosshair_red %d",g_crosshair_red_change[client]);
		ClientCommand(client, "cl_crosshair_blue %d",g_crosshair_blue_change[client]);
		}
		case (kill_1):
		{
		if(g_iReport==1){
		IsDeathMessage();
		ZombieKillHeadShot();}
		}
		case (kill):
		{
		if(g_iReport==1){
			IsDeathMessage();
			ZombieKill();}
		}
	}
	}
	case 3:{
								}
	}
}

#define Amount	5
//int g_iReportLine;
int g_iDeathTime;
char g_sTemp[Amount - 1][128], g_sDeathKill[Amount][128], g_sDeathInfo[256];
Handle g_hTimerHUD, g_hTimerCSKill, g_hDisplayNumber;
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hTimerCSKill;
}
//地图结束.
public void OnMapEnd()
{
	delete g_hTimerCSKill;
}
void IsDisplayTimeOut()
{
	delete g_hTimerCSKill;
	g_hTimerCSKill = CreateTimer(1.0, IsTimerImitationCSKillTip, _, TIMER_REPEAT);
}
int g_iTemp;
public Action IsTimerImitationCSKillTip(Handle timer)
{
	if(g_iReportLine <= 0)
		return Plugin_Continue;

	int g_iDeathKill = GetStringContent();
	if(g_iDeathKill > 0)
	{
		if(g_iDeathTime < g_iReportTime)
		{
			g_iDeathTime += 1;
			return Plugin_Continue;
		}
		if(g_iDeathKill >= g_iReportLine)
		{
			g_iTemp = g_iReportLine - 1;
			if(g_iDeathKill - 1 != g_iTemp)
				g_iTemp = g_iDeathKill - 1;
			g_iDeathKill = g_iTemp;
		}
		IsReorderDeath(g_iDeathKill);
		g_sDeathKill[g_iDeathKill][0] = '\0';
		ImplodeStrings(g_sDeathKill, sizeof(g_sDeathKill), "\n", g_sDeathInfo, sizeof(g_sDeathInfo));//打包字符串.
	}
	g_iDeathTime = 0;
	return Plugin_Continue;
}

//清除其它的HUD.
void IsRemoveOtherHUD()
{
	//删除仿CS击杀提示HUD.
	if(HUDSlotIsUsed(HUD_FAR_LEFT))
		RemoveHUD(HUD_FAR_LEFT);
}
//丧尸击杀提示.
void ZombieKill()
{
	//if (g_iReportLine <= 0)
		//return;
	
	int g_iDeathKill = GetStringContent();
	if(g_iDeathKill >= 5)
	{
		g_iTemp = 5 - 1;
		if(g_iDeathKill - 1 != g_iTemp)
			g_iTemp = g_iDeathKill - 1;
		g_iDeathKill = g_iTemp;
		IsReorderDeath(g_iDeathKill);
	}
	FormatEx(g_sDeathKill[g_iDeathKill], sizeof(g_sDeathKill[]), ">XP 丧尸击杀");
	ImplodeStrings(g_sDeathKill, sizeof(g_sDeathKill), "\n", g_sDeathInfo, sizeof(g_sDeathInfo));//打包字符串.
}
//丧尸暴击击杀提示.
void ZombieKillHeadShot()
{
	//if (g_iReportLine <= 0)
		//return;
	
	int g_iDeathKill = GetStringContent();
	if(g_iDeathKill >= 5)
	{
		g_iTemp = 5 - 1;
		if(g_iDeathKill - 1 != g_iTemp)
			g_iTemp = g_iDeathKill - 1;
		g_iDeathKill = g_iTemp;
		IsReorderDeath(g_iDeathKill);
	}
	FormatEx(g_sDeathKill[g_iDeathKill], sizeof(g_sDeathKill[]), ">XP 丧尸暴击击杀");
	ImplodeStrings(g_sDeathKill, sizeof(g_sDeathKill), "\n", g_sDeathInfo, sizeof(g_sDeathInfo));//打包字符串.
}
//清除数组第一行的内容,然后把后面的内容全部上移.
void IsReorderDeath(int iCycle)
{
	for (int i = 0; i < iCycle; i++)
		strcopy(g_sTemp[i], sizeof(g_sTemp[]), g_sDeathKill[i + 1]);
	for (int i = 0; i < iCycle; i++)
		strcopy(g_sDeathKill[i], sizeof(g_sDeathKill[]), g_sTemp[i]);
}
//获取数组里有多少内容.
int GetStringContent()
{
	for (int i = 0; i < sizeof(g_sDeathKill); i++)
		if(g_sDeathKill[i][0] == '\0')
			return i;//break;
		
	return sizeof(g_sDeathKill);
}


public void OnClientDisconnect(int client)
{
	SetClientCookies(client);
}

public void OnClientDisconnect_Post(int client)
{
	if(g_taskCountdown[client] != INVALID_HANDLE)
	{
		KillTimer(g_taskCountdown[client]);
		g_taskCountdown[client] = INVALID_HANDLE;
	}
	
	if(g_taskClean[client] != INVALID_HANDLE)
	{
		KillTimer(g_taskClean[client]);
		g_taskClean[client] = INVALID_HANDLE;
	}
}

public void OnClientCookiesCached(int client)
{
	ReadClientCookies(client);
}

public void OnClientPutInServer(int client)
{
	if (AreClientCookiesCached(client))
	{
		ReadClientCookies(client);
	}
}

void ReadClientCookies(int client)
{
	char sBuffer[4];

	GetClientCookie(client, g_styleCookie, sBuffer, sizeof(sBuffer));
	g_style[client] = (sBuffer[0] == '\0' ? 3 : StringToInt(sBuffer));
	
	GetClientCookie(client, g_crosshair_green_Cookie, sBuffer, sizeof(sBuffer));
	g_crosshair_green[client] = (sBuffer[0] == '\0' ? 255 : StringToInt(sBuffer));
	
	GetClientCookie(client, g_crosshair_green_change_Cookie, sBuffer, sizeof(sBuffer));
	g_crosshair_green_change[client] = (sBuffer[0] == '\0' ? 0 : StringToInt(sBuffer));
	
	GetClientCookie(client, g_crosshair_blue_Cookie, sBuffer, sizeof(sBuffer));
	g_crosshair_blue[client] = (sBuffer[0] == '\0' ? 100 : StringToInt(sBuffer));
	
	GetClientCookie(client, g_crosshair_blue_change_Cookie, sBuffer, sizeof(sBuffer));
	g_crosshair_blue_change[client] = (sBuffer[0] == '\0' ? 0 : StringToInt(sBuffer));
	
	GetClientCookie(client, g_crosshair_red_Cookie, sBuffer, sizeof(sBuffer));
	g_crosshair_red[client] = (sBuffer[0] == '\0' ? 100 : StringToInt(sBuffer));
	
	GetClientCookie(client, g_crosshair_red_change_Cookie, sBuffer, sizeof(sBuffer));
	g_crosshair_red_change[client] = (sBuffer[0] == '\0' ? 255 : StringToInt(sBuffer));

}

void SetClientCookies(int client)
{
	char sValue[4];

	Format(sValue, sizeof(sValue), "%i", g_style[client]);
	SetClientCookie(client, g_styleCookie, sValue);

}

char[] GetPlayerName(int client, int iHLZClass)
{
	char sName[32];
	GetClientName(client, sName, sizeof(sName));

	if(!IsFakeClient(client))
	{
		Format(sName, sizeof(sName), "%s\x04%s", g_sZombieName[iHLZClass], sName);
	}
	else
	{
		SplitString(sName, g_sZombieClass[iHLZClass], sName, sizeof(sName));
		Format(sName, sizeof(sName), "%s%s", g_sZombieName[iHLZClass], sName);
	}
	return sName;
}

//---------------------------------------
// 自选菜单
//---------------------------------------

public Action Command_HM(int client, int args)
{
	if(GetConVarInt(plugin_enable) == 0)
	{
		PrintToChat(client, "\x04[提示]\x03击中反馈被禁用了!");//聊天窗提示.
		return Plugin_Handled;
	}

	HMMenu(client);
	return Plugin_Handled;
}

public Action HMMenu(int client)
{
	Menu menu = CreateMenu(Callback_HMMenu);
	SetMenuTitle(menu, "==================\n请选择你的命中反馈风格\n==================");
	AddMenuItem(menu, "option1", "原版");
	AddMenuItem(menu, "option2", "屏幕字幕+聊天窗提示");
	AddMenuItem(menu, "option3", "关闭");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
        return Plugin_Continue;
}

public int Callback_HMMenu(Menu menu, MenuAction action, int client, int itemNum)
{
	if(action == MenuAction_Select)
	{
			char item[64];
			GetMenuItem(menu, itemNum, item, sizeof(item));
			if(StrEqual(item, "option1")) 
			{
				g_style[client] = 1;
				PrintToChat(client, "\x04[提示]\x03击中反馈风格为\x05原版");//聊天窗提示.
			}
			
			else if(StrEqual(item, "option2")) 
			{
				g_style[client] = 2;
				PrintToChat(client, "\x04[提示]\x03击中反馈风格为\x05屏幕字幕+聊天窗提示");//聊天窗提示.
				
			}
			
			else if(StrEqual(item, "option3")) 
			{
				g_style[client] = 3;
				PrintToChat(client, "\x04[提示]\x03击中反馈风格为\x05关闭");//聊天窗提示.
				
			}
	}
	return 0;
}

public Action Command_Green(int client, int args)
{
	if (args < 1)
	{
		PrintToChat(client, "\x04[提示]\x03用法: \x01sm_crosshair_green 255");
		return Plugin_Handled;
	}

	char arg[512];
	GetCmdArg(1, arg, sizeof(arg));
	g_crosshair_green[client] = StringToInt(arg);
	PrintToChat(client, "\x04[提示]\x03准星颜色green已改为\x05%d",g_crosshair_green[client]);
	
	
	return Plugin_Handled;
}

public Action Command_Green_Change(int client, int args)
{
	if (args < 1)
	{
		PrintToChat(client, "\x04[提示]\x03用法: \x01sm_crosshair_green_change 0");
		return Plugin_Handled;
	}

	char arg[512];
	GetCmdArg(1, arg, sizeof(arg));
	g_crosshair_green_change[client] = StringToInt(arg);
	PrintToChat(client, "\x04[提示]\x03反馈的准星颜色green已改为\x05%d",g_crosshair_green_change[client]);
	
	
	return Plugin_Handled;
}

public Action Command_Blue(int client, int args)
{
	if (args < 1)
	{
		PrintToChat(client, "\x04[提示]\x03用法: \x01sm_crosshair_blue 255");
		return Plugin_Handled;
	}

	char arg[512];
	GetCmdArg(1, arg, sizeof(arg));
	g_crosshair_blue[client] = StringToInt(arg);
	PrintToChat(client, "\x04[提示]\x03准星颜色blue已改为\x05%d",g_crosshair_blue[client]);
	
	
	return Plugin_Handled;
}

public Action Command_Blue_Change(int client, int args)
{
	if (args < 1)
	{
		PrintToChat(client, "\x04[提示]\x03用法: \x01sm_crosshair_blue_change 0");
		return Plugin_Handled;
	}

	char arg[512];
	GetCmdArg(1, arg, sizeof(arg));
	g_crosshair_blue_change[client] = StringToInt(arg);
	PrintToChat(client, "\x04[提示]\x03反馈的准星颜色blue已改为\x05%d",g_crosshair_blue_change[client]);
	
	
	return Plugin_Handled;
}

public Action Command_Red(int client, int args)
{
	if (args < 1)
	{
		PrintToChat(client, "\x04[提示]\x03用法: \x01sm_crosshair_red 255");
		return Plugin_Handled;
	}

	char arg[512];
	GetCmdArg(1, arg, sizeof(arg));
	g_crosshair_red[client] = StringToInt(arg);
	PrintToChat(client, "\x04[提示]\x03准星颜色red已改为\x05%d",g_crosshair_red[client]);
	
	
	return Plugin_Handled;
}

public Action Command_Red_Change(int client, int args)
{
	if (args < 1)
	{
		PrintToChat(client, "\x04[提示]\x03用法: \x01sm_crosshair_red_change 0");
		return Plugin_Handled;
	}

	char arg[512];
	GetCmdArg(1, arg, sizeof(arg));
	g_crosshair_red_change[client] = StringToInt(arg);
	PrintToChat(client, "\x04[提示]\x03反馈的准星颜色red已改为\x05%d",g_crosshair_red_change[client]);
	
	
	return Plugin_Handled;
}

//显示仿CS击杀提示.
void IsDeathMessage()
{
	ihud_x			= ghud_x.FloatValue;
	ihud_y		= ghud_y.FloatValue;
	ihud_width		= ghud_width.FloatValue;
	ihud_height		= ghud_height.FloatValue;
	HUDSetLayout(HUD_FAR_LEFT, HUD_FLAG_ALIGN_RIGHT|HUD_FLAG_NOBG|HUD_FLAG_TEXT, g_sDeathInfo);
	HUDPlace(HUD_FAR_LEFT,ihud_x,ihud_y,ihud_width,ihud_height);
}

//重置字符串.
void IsResetString()
{
	for (int i = 0; i < sizeof(g_sDeathKill); i++)
		g_sDeathKill[i][0] = '\0';
	g_sDeathInfo[0] = '\0';
}

void GetCvars()
{
	g_iReport			= g_hReport.IntValue;
	g_iReportLine		= g_hReportLine.IntValue;
	g_iReportTime		= g_hReportTime.IntValue;
	
	if( g_iReportTime < 5)
		g_iReportTime = 5;
	if( g_iReportLine > Amount)
		g_iReportLine = Amount;
}