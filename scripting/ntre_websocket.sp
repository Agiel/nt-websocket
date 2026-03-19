// Neotokyo Websocket Relay

// Changeolg

// 2.0 - Major changes for NT;RE compatibility
// 2.0.1 - Default class to recon to avoid desync

// TODO:

// Player equip/drop to keep track of player inventory

// Separate XP, frags and assists?

/**
 * Control chars:
 * A: Inform others there's another spectator
 * B: Round timer in seconds
 * C: Player connected
 * D: Player disconnected
 * E: Player equipped weapon
 * F: Player fired gun
 * G: Ghost overtime toggled
 * H: Player was hurt
 * I: Initial child socket connect. Sends game and map
 * J: Player changed class
 * K: Player died
 * L: Veto map list
 * M: Map changed
 * N: Player changed his name
 * O: Observer target changed
 * P: Player score changed
 * Q:
 * R: Round start
 * S: Player spawned
 * T: Player changed team
 * U: Player dropped weapon
 * V: ConVar changed
 * W: Player switched to weapon
 * X: Chat message
 */
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <websocket>
#include <neotokyo>

#define PLUGIN_VERSION "2.0.1"

#define NEO_MAX_CLIENTS 32
#define MAX_PLAYER_NAME_LENGTH 32

// If true, include the "sm_relaydbg" and "sm_relaydbg_populate" server commands for sending simulated relay data.
#define NT_RELAY_DEBUG false
// If true, print all SendToAllChildren() relay data to the SRCDS server console.
#define NT_RELAY_DEBUG_PRINT_SENDS false

WebSocketServer g_hWsServer;

ConVar g_hostname;
ConVar g_wsPort;

int g_iRoundNumber = -1;

int g_playerXP[NEO_MAX_CLIENTS + 1];
int g_playerDeaths[NEO_MAX_CLIENTS + 1];
int g_playerClass[NEO_MAX_CLIENTS + 1];
char g_playerActiveWeapon[NEO_MAX_CLIENTS + 1][20];
int g_playerEquippedWeapons[NEO_MAX_CLIENTS + 1];

int g_currentObserver = 0;
int g_currentObserverTarget = 0;

#if NT_RELAY_DEBUG
int g_maxFakeClients = 10;
#endif

char weapon_list[][] = {
		"weapon_aa13",
		"wepon_balc",
		"weapon_detpack",
		"weapon_ghost",
		"weapon_grenade",
		"weapon_jitte",
		"weapon_jittescoped",
		"weapon_knife",
		"weapon_kyla",
		"weapon_mosok",
		"weapon_mosokl",
		"weapon_mosoks",
		"weapon_milso",
		"weapon_mpn_unsilenced",
		"weapon_mpn",
		"weapon_mx",
		"weapon_mxs",
		"weapon_proxmine",
		"weapon_pz",
		"weapon_smac",
		"weapon_smoke",
		"weapon_srm",
		"weapon_srms",
		"weapon_srs",
		"weapon_supa7",
		"weapon_tachi",
		"weapon_zr68c",
		"weapon_zr68l",
		"weapon_zr68s"
	};

int GetWeaponBit(char[] name) {
	for (int i = 0; i < sizeof(weapon_list); i++) {
		if (StrEqual(name, weapon_list[i])) {
			return 1 << i;
		}
	}
	return 0;
}

public Plugin myinfo =
{
	name = "Neotokyo WebSocket",
	author = "Agiel",
	description = "Neotokyo WebSocket relay.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Agiel/nt-websocket"
}

public OnPluginStart()
{
	AddCommandListener(CmdLstnr_Say, "say");

	g_hostname = FindConVar("hostname");

	g_wsPort = CreateConVar("sm_nt_websocket_port", "12346", "Port to use for the WebSocket server.", FCVAR_PROTECTED, true, 0.0, true, 65535.0);

	RegConsoleCmd("sm_setobserver", OnSetObserver, "Set current observer for spectator overlay");
	RegConsoleCmd("sm_setobserve", OnSetObserver, "Alias for sm_setobserver");
#if NT_RELAY_DEBUG
	RegConsoleCmd("sm_relaydbg", OnRelayDebug, "Send fake relay output for debugging purposes");
	RegConsoleCmd("sm_relaydbg_populate", OnRelayWepsDebug, "Populate the server relay with fake players. Optionally, pass in the number of fake players wanted.");
#endif

	HookEvent("player_team", Event_OnPlayerTeam);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_hurt", Event_OnPlayerHurt);
	HookEvent("player_changeneoname", Event_OnChangeName);
	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("team_score", Event_OnTeamScore);

	// Hook again if plugin is restarted
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			OnClientPutInServer(client);
		}
	}

	AutoExecConfig(true);
}

public OnConfigsExecuted()
{
    if (g_hWsServer)
        return;

    PrintToServer("WebSocket server running on port %d", g_wsPort.IntValue);
    g_hWsServer = new WebSocketServer("0.0.0.0", g_wsPort.IntValue);
    g_hWsServer.SetMessageCallback(OnSrvMessage);
    g_hWsServer.SetOpenCallback(OnSrvOpen);
    g_hWsServer.SetCloseCallback(OnSrvClose);
    g_hWsServer.SetErrorCallback(OnSrvError);
    g_hWsServer.Start();
}

public OnPluginEnd()
{
    g_hWsServer.Stop();
}

void OnSrvMessage(WebSocketServer ws, WebSocket client, const char[] message, int wireSize, const char[] RemoteAddr, const char[] RemoteId)
{
    // PrintToServer("message: %s, wireSize: %d, RemoteAddr: %s, RemoteId: %s", message, wireSize, RemoteAddr, RemoteId);
}

void OnSrvError(WebSocketServer ws, const char[] errMsg, const char[] RemoteAddr, const char[] RemoteId)
{
    // PrintToServer("onError: %s, RemoteAddr: %s, RemoteId: %s", errMsg, RemoteAddr, RemoteId);
}

void OnSrvOpen(WebSocketServer ws, const char[] RemoteAddr, const char[] RemoteId)
{
    // PrintToServer("onOpen: %x, RemoteAddr: %s, RemoteId: %s", ws, RemoteAddr, RemoteId);
    SendFullUpdate(RemoteId);
}

void OnSrvClose(WebSocketServer ws, int code, const char[] reason, const char[] RemoteAddr, const char[] RemoteId)
{
    // PrintToServer("onClose: %d, reason: %s, RemoteAddr: %s, RemoteId: %s", code, reason, RemoteAddr, RemoteId);
}

void SendFullUpdate(const char[] RemoteId)
{
	decl String:sMap[64], String:sGameFolder[64], String:sBuffer[256], String:sTeam1[32], String:sTeam2[32], String:sHostName[128];
	GetCurrentMap(sMap, sizeof(sMap));
	GetGameFolderName(sGameFolder, sizeof(sGameFolder));
	GetTeamName(2, sTeam1, sizeof(sTeam1));
	GetTeamName(3, sTeam2, sizeof(sTeam2));
	GetConVarString(g_hostname, sHostName, sizeof(sHostName));
	Format(sBuffer, sizeof(sBuffer), "I%s:%s:%s:%s:%s", sGameFolder, sMap, sTeam1, sTeam2, sHostName);

	g_hWsServer.SendMessageToClient(RemoteId, sBuffer);

	if(g_iRoundNumber != -1)
	{
		int jinraiScore = GetTeamScore(TEAM_JINRAI);
		int nsfScore = GetTeamScore(TEAM_NSF);
		Format(sBuffer, sizeof(sBuffer), "R%d:%d:%d", g_iRoundNumber, jinraiScore, nsfScore);
		g_hWsServer.SendMessageToClient(RemoteId, sBuffer);
	}

	// Add all players to it's list
	for(new i=1;i<=MaxClients;i++)
	{
		if(IsClientInGame(i))
		{
			GetClientAuthId(i, AuthId_SteamID64, sBuffer, sizeof(sBuffer));
			char name[MAX_PLAYER_NAME_LENGTH];
			GetPlayerName(i, name);
			Format(sBuffer, sizeof(sBuffer), "C%d:%d:%s:%d:%d:%d:%d:%d:%d:%s:%s:%d", GetClientUserId(i), i, sBuffer, GetClientTeam(i), IsPlayerAlive(i), GetClientXP(i), GetClientDeaths(i), GetClientHealth(i), GetPlayerClass(i), g_playerActiveWeapon[i], name, g_playerEquippedWeapons[i]);

			g_hWsServer.SendMessageToClient(RemoteId, sBuffer);
		}
	}
}

public Action OnSetObserver(int client, int args)
{
	g_currentObserver = client;
	CreateTimer(0.1, CheckObserverTarget, _, TIMER_REPEAT);

	ReplyToCommand(client, "You are now set as the stream observer.");

	return Plugin_Handled;
}

public Action CheckObserverTarget(Handle timer)
{
	int target = 0;

	if (g_currentObserver != 0 && IsClientInGame(g_currentObserver))
	{
		int mode = GetEntProp(g_currentObserver, Prop_Send, "m_iObserverMode");
		target = mode == 4 ? GetEntPropEnt(g_currentObserver, Prop_Send, "m_hObserverTarget") : 0;
	}

	if (target != g_currentObserverTarget)
	{
		g_currentObserverTarget = target;
		char sBuffer[128];
		Format(sBuffer, sizeof(sBuffer), "O%d", target);
		SendToAllChildren(sBuffer);
	}

	if (g_currentObserver == 0) {
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

Action CheckScores(Handle timer)
{
	for(new i=1;i<=MaxClients;i++)
	{
		if(IsClientInGame(i))
		{
			int xp = GetClientXP(i);
			int deaths = GetClientDeaths(i);

			if (g_playerXP[i] != xp || g_playerDeaths[i] != deaths)
			{
				g_playerXP[i] = xp;
				g_playerDeaths[i] = deaths;
				char sBuffer[128];
				Format(sBuffer, sizeof(sBuffer), "P%d:%d:%d", GetClientUserId(i), xp, deaths);
				SendToAllChildren(sBuffer);
			}
		}
	}

	return Plugin_Stop;
}

// public OnMapStart()
// {
//     if (!g_hWsServer.ClientsCount)
//         return;

// 	decl String:sBuffer[128];
// 	GetCurrentMap(sBuffer, sizeof(sBuffer));
// 	Format(sBuffer, sizeof(sBuffer), "M%s", sBuffer);

// 	SendToAllChildren(sBuffer);
// }

public OnClientPutInServer(client)
{
	g_playerXP[client] = GetClientXP(client);
	g_playerDeaths[client] = GetClientDeaths(client);
	g_playerClass[client] = 0;

	SDKHook(client, SDKHook_WeaponSwitchPost, Event_OnWeaponSwitch_Post);
	SDKHook(client, SDKHook_WeaponEquipPost, Event_OnWeaponEquip);
	SDKHook(client, SDKHook_WeaponDropPost, Event_OnWeaponDrop);
	SDKHook(client, SDKHook_FireBulletsPost, Event_OnFireBullets);

	if (!g_hWsServer || !g_hWsServer.ClientsCount)
	    return;

	char sBuffer[128];
	GetClientAuthId(client, AuthId_SteamID64, sBuffer, sizeof(sBuffer));

	char name[MAX_PLAYER_NAME_LENGTH];
	GetPlayerName(client, name);
	Format(sBuffer, sizeof(sBuffer), "C%d:%d:%s:%d:0:0:0:100:0::%s", GetClientUserId(client), client, sBuffer, GetClientTeam(client), name);

	SendToAllChildren(sBuffer);
}

public OnClientDisconnect(client)
{
	if(IsClientInGame(client))
	{
		if(!g_hWsServer.ClientsCount)
			return;

		decl String:sBuffer[20];
		Format(sBuffer, sizeof(sBuffer), "D%d", GetClientUserId(client));

		SendToAllChildren(sBuffer);
	}

	if (client == g_currentObserver)
	{
		g_currentObserver = 0;
	}

	g_playerXP[client] = 0;
	g_playerDeaths[client] = 0;
}

public Event_OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_hWsServer.ClientsCount)
		return;

	new userid = GetEventInt(event, "userid");
	new team = GetEventInt(event, "team");

	if(team == 0)
		return;

	decl String:sBuffer[10];
	Format(sBuffer, sizeof(sBuffer), "T%d:%d", userid, team);

	SendToAllChildren(sBuffer);
}

public Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_hWsServer.ClientsCount)
		return;

	new victim = GetEventInt(event, "userid");
	new attacker = GetEventInt(event, "attacker");

	new String:sBuffer[64];
	GetEventString(event, "weapon", sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "K%d:%d:%s", victim, attacker, sBuffer);

	SendToAllChildren(sBuffer);

	CreateTimer(0.1, CheckScores);
}

public Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_hWsServer.ClientsCount)
		return;

	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if (GetClientTeam(client) < 2)
		return;

	g_playerEquippedWeapons[client] = 0;

	decl String:sBuffer[20];
	Format(sBuffer, sizeof(sBuffer), "S%d:%d", userid, IsPlayerAlive(client));

	SendToAllChildren(sBuffer);
}

public Event_OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_hWsServer.ClientsCount)
		return;

	new userid = GetEventInt(event, "userid");

	decl String:sBuffer[20];
	Format(sBuffer, sizeof(sBuffer), "H%d:%d", userid, GetEventInt(event, "health"));

	SendToAllChildren(sBuffer);
}

public Event_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_hWsServer.ClientsCount)
		return;

	g_iRoundNumber = GameRules_GetProp("m_iRoundNumber");
    int jinraiScore = GetTeamScore(TEAM_JINRAI);
	int nsfScore = GetTeamScore(TEAM_NSF);

	char sBuffer[20];
	Format(sBuffer, sizeof(sBuffer), "R%d:%d:%d", g_iRoundNumber, jinraiScore, nsfScore);
	SendToAllChildren(sBuffer);

	CreateTimer(0.1, CheckScores);
}

public Event_OnTeamScore(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_hWsServer.ClientsCount)
		return;

	CreateTimer(0.1, CheckScores);
}

public Event_OnChangeName(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_hWsServer.ClientsCount)
		return;

	new userid = GetEventInt(event, "userid");
	decl String:sOldName[MAX_NAME_LENGTH];
	decl String:sNewName[MAX_NAME_LENGTH];
	GetEventString(event, "oldname", sOldName, sizeof(sOldName));
	GetEventString(event, "newname", sNewName, sizeof(sNewName));

	if(StrEqual(sNewName, sOldName))
		return;

	decl String:sBuffer[MAX_NAME_LENGTH+10];
	Format(sBuffer, sizeof(sBuffer), "N%d:%s", userid, sNewName);

	SendToAllChildren(sBuffer);
}

public void Event_OnWeaponEquip(int client, int weapon)
{
	int userid = GetClientUserId(client);

	// Euipping a new gun could mean the player changed class
	int newClass = GetPlayerClass(client);
	if (newClass != g_playerClass[client])
	{
	    g_playerClass[client] = newClass;
	    char sBuffer[8];
		Format(sBuffer, sizeof(sBuffer), "J%d:%d", userid, newClass);
		SendToAllChildren(sBuffer);
	}

	char weaponName[20];
	GetEntityClassname(weapon, weaponName, sizeof(weaponName));

	if (!StrEqual(weaponName, "weapon_ghost"))
	{
		return;
	}

	char sBuffer[32];
	Format(sBuffer, sizeof(sBuffer), "E%d:%s", userid, weaponName);

	SendToAllChildren(sBuffer);

	g_playerEquippedWeapons[client] += GetWeaponBit(weaponName);
}

public void Event_OnWeaponDrop(int client, int weapon)
{
	int userid = GetClientUserId(client);

	if (weapon == -1)
	    return;

	char weaponName[20];
	GetEntityClassname(weapon, weaponName, sizeof(weaponName));

	if (!StrEqual(weaponName, "weapon_ghost"))
	{
		return;
	}

	char sBuffer[32];
	Format(sBuffer, sizeof(sBuffer), "U%d:%s", userid, weaponName);

	SendToAllChildren(sBuffer);

	g_playerEquippedWeapons[client] -= GetWeaponBit(weaponName);
}

public void Event_OnWeaponSwitch_Post(int client, int weapon)
{
	int userid = GetClientUserId(client);

	char weaponName[20];
	GetEntityClassname(weapon, weaponName, sizeof(weaponName));
	g_playerActiveWeapon[client] = weaponName;

	char sBuffer[32];
	Format(sBuffer, sizeof(sBuffer), "W%d:%s", userid, weaponName);

	SendToAllChildren(sBuffer);
}

public void Event_OnFireBullets(int client)
{
    int userid = GetClientUserId(client);

	char sBuffer[10];
	Format(sBuffer, sizeof(sBuffer), "F%d", userid);

	SendToAllChildren(sBuffer);
}

public Action:CmdLstnr_Say(client, const String:command[], argc)
{
	decl String:sBuffer[128];
	GetCmdArgString(sBuffer, sizeof(sBuffer));

	StripQuotes(sBuffer);
	if(strlen(sBuffer) == 0)
		return Plugin_Continue;

	// Send console messages either.
	new userid = 0;
	if(client)
		userid = GetClientUserId(client);

	Format(sBuffer, sizeof(sBuffer), "X%d:%s", userid, sBuffer);

	SendToAllChildren(sBuffer);

	return Plugin_Continue;
}

SendToAllChildren(const char[] sData)
{
#if NT_RELAY_DEBUG_PRINT_SENDS
	PrintToServer("SendToAllChildren: %s", sData);
#endif

    g_hWsServer.BroadcastMessage(sData);
}

int GetClientXP(int i)
{
    return GetEntProp(i, Prop_Send, "m_iXP");
}

void GetPlayerName(int i, char[] buffer)
{
    GetClientInfo(i, "neo_name", buffer, MAX_PLAYER_NAME_LENGTH);
    if (!strlen(buffer))
    {
        GetClientInfo(i, "name", buffer, MAX_PLAYER_NAME_LENGTH);
    }
}
