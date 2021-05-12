// Neotokyo Websocket Relay

// Changeolg

// 1.2.1 - Add optional compile flags for including debug commands
// 1.2 - Track shooting players
// 1.1 - Oberver target tracking
// 1.0 - Initial release

// TODO:

// Player equip/drop to keep track of player inventory
// Does throwing grenade trigger drop?

// Separate XP, frags and assists? Might be hard to keep in sync with the comp plugin shenanigans.

// Map vetos

// Track shooting players

// Players "spawning" mid round, usually after switching team, are reported as alive even if they're dead.

/**
 * Control chars:
 * A: Inform others there's another spectator
 * B:
 * C: Player connected
 * D: Player disconnected
 * E: Player equipped weapon
 * F: Player fired gun
 * G:
 * H: Player was hurt
 * I: Initial child socket connect. Sends game and map
 * J:
 * K: Player died
 * L:
 * M: Map changed
 * N: Player changed his name
 * O: Observer target changed
 * P: Player score changed
 * Q:
 * R: Round start
 * S: Player spawned
 * T: Player changed team
 * U:
 * V: ConVar changed
 * W: Player switched to weapon
 * X: Chat message
 * Y:
 * Z:
 */
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <websocket>
#include <neotokyo>

#define PLUGIN_VERSION "1.2.1"

#define NEO_MAX_CLIENTS 32

// If true, include the "sm_relaydbg" and "sm_relaydbg_populate" server commands for sending simulated relay data.
#define NT_RELAY_DEBUG false
// If true, print all SendToAllChildren() relay data to the SRCDS server console.
#define NT_RELAY_DEBUG_PRINT_SENDS false

new WebsocketHandle:g_hListenSocket = INVALID_WEBSOCKET_HANDLE;
new Handle:g_hChildren;
new Handle:g_hChildIP;

new Handle:g_hostname;

new g_iRoundNumber = -1;

int g_playerXP[NEO_MAX_CLIENTS + 1];
int g_playerDeaths[NEO_MAX_CLIENTS + 1];
char g_playerActiveWeapon[NEO_MAX_CLIENTS + 1][20];

int g_currentObserver = 0;
int g_currentObserverTarget = 0;

public Plugin:myinfo =
{
	name = "Neotokyo WebSocket",
	author = "Agiel",
	description = "Neotokyo WebSocket relay. Based on Jannik \"Peace-Maker\" Hartung's SourceTV 2D Server",
	version = PLUGIN_VERSION,
	url = "http://www.wcfan.de/"
}

public OnPluginStart()
{
	g_hChildren = CreateArray();
	g_hChildIP = CreateArray(ByteCountToCells(33));

	AddCommandListener(CmdLstnr_Say, "say");

	g_hostname = FindConVar("hostname");

	RegConsoleCmd("sm_setobserver", OnSetObserver, "Set current observer for spectator overlay");
#if NT_RELAY_DEBUG
	RegConsoleCmd("sm_relaydbg", OnRelayDebug, "Send fake relay output for debugging purposes");
	RegConsoleCmd("sm_relaydbg_populate", OnRelayWepsDebug, "Populate the server relay with fake players");
#endif

	HookEvent("player_team", Event_OnPlayerTeam);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_hurt", Event_OnPlayerHurt);
	HookEvent("player_changename", Event_OnChangeName);

	// Neotokyo
	HookEventEx("game_round_start", Event_OnRoundStart);

	AddTempEntHook("Shotgun Shot", Hook_FireBullets);

	// Hook again if plugin is restarted
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			OnClientPutInServer(client);
		}
	}
}

public OnAllPluginsLoaded()
{
	decl String:sServerIP[40];
	new longip = GetConVarInt(FindConVar("hostip")), pieces[4];
	pieces[0] = (longip >> 24) & 0x000000FF;
	pieces[1] = (longip >> 16) & 0x000000FF;
	pieces[2] = (longip >> 8) & 0x000000FF;
	pieces[3] = longip & 0x000000FF;
	FormatEx(sServerIP, sizeof(sServerIP), "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3]);
	if(g_hListenSocket == INVALID_WEBSOCKET_HANDLE)
		g_hListenSocket = Websocket_Open(sServerIP, 12346, OnWebsocketIncoming, OnWebsocketMasterError, OnWebsocketMasterClose);
}

public OnPluginEnd()
{
	if(g_hListenSocket != INVALID_WEBSOCKET_HANDLE)
		Websocket_Close(g_hListenSocket);
}

public Action OnSetObserver(int client, int args)
{
	g_currentObserver = client;
	CreateTimer(0.1, CheckObserverTarget, _, TIMER_REPEAT);

	PrintToConsole(client, "Tracking observer target for %N", client);

	return Plugin_Handled;
}

#if NT_RELAY_DEBUG
public Action OnRelayDebug(int client, int args)
{
	if (client != 0) {
		ReplyToCommand(client, "This command can only be executed by the server");
		return Plugin_Handled;
	}

	char sBuffer[128];

	if (args != 1) {
		GetCmdArg(0, sBuffer, sizeof(sBuffer));
		ReplyToCommand(client, "Usage: %s \"simulated output\"", sBuffer);
		return Plugin_Handled;
	}

	if (GetCmdArg(1, sBuffer, sizeof(sBuffer)) < 1) {
		ReplyToCommand(client, "Can't send empty output");
		return Plugin_Handled;
	}

	SendToAllChildren(sBuffer);

	return Plugin_Handled;
}

public Action OnRelayWepsDebug(int client, int argc)
{
	if (client != 0) {
		ReplyToCommand(client, "This command can only be executed by the server");
		return Plugin_Handled;
	}

	char sBuffer[128];
	// Fake disconnect any existing clients
	for (int i = 1; i <= MaxClients; ++i) {
		Format(sBuffer, sizeof(sBuffer), "D%d", i);
		SendToAllChildren(sBuffer);
	}

	CreateTimer(1.0, Timer_WepsDebug_AsyncRelay, 0);

	return Plugin_Handled;
}

// Purpose: Delayed relay access to ensure correct execution order (could technically still go out of order, but good enough for debug).
public Action Timer_WepsDebug_AsyncRelay(Handle timer, int phase)
{
	new const String:weps[][] = {
		"weapon_aa13",
		"weapon_ghost",
		"weapon_grenade",
		"weapon_jitte",
		"weapon_jittescoped",
		"weapon_knife",
		"weapon_kyla",
		"weapon_m41",
		"weapon_m41s",
		"weapon_milso",
		"weapon_mp5",
		"weapon_mpn",
		"weapon_mx",
		"weapon_mx_silenced",
		"weapon_pz",
		"weapon_smac",
		"weapon_smokegrenade",
		"weapon_spidermine",
		"weapon_srm",
		"weapon_srm_s",
		"weapon_srs",
		"weapon_supa7",
		"weapon_tachi",
		"weapon_zr68c",
		"weapon_zr68l",
		"weapon_zr68s"
	};

	char sBuffer[128];

	// Populate with fake players
	for (int i = 1, playerclass = CLASS_RECON; i <= MaxClients; ++i) {
		int fakeuserid = i;
		int team = (i <= MaxClients / 2) ? TEAM_NSF : TEAM_JINRAI;
		switch (phase) {
			case 0:
			{
				Format(sBuffer, sizeof(sBuffer), "C%d:%d:%s:%d:0:0:0:100:0::Fake Player %d", fakeuserid++, i, "STEAM_ID_PLACEHOLDER", team, i, i);
			}
			case 1:
			{
				Format(sBuffer, sizeof(sBuffer), "T%d:%d", fakeuserid, team);
			}
			case 2:
			{
				Format(sBuffer, sizeof(sBuffer), "S%d:%d:1", fakeuserid, playerclass);
			}
			case 3:
			{
				int wep_index = (i - 1) % sizeof(weps); // cycle through weps for predictable position in the overlay, so it's easier to compare visually
				Format(sBuffer, sizeof(sBuffer), "W%d:%s", i, weps[wep_index]);
			}
			default:
			{
				return Plugin_Stop;
			}
		}
		SendToAllChildren(sBuffer);

		playerclass += 1;
		if (playerclass > CLASS_SUPPORT) {
			playerclass = CLASS_RECON;
		}
	}

	CreateTimer(1.0, Timer_WepsDebug_AsyncRelay, phase + 1);
	return Plugin_Stop;
}
#endif

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

public Action CheckScores(Handle timer)
{
	for(new i=1;i<=MaxClients;i++)
	{
		if(IsClientInGame(i))
		{
			int xp = GetClientFrags(i);
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
}

public OnMapStart()
{
	new iSize = GetArraySize(g_hChildren);
	if(iSize == 0)
		return;

	decl String:sBuffer[128];
	GetCurrentMap(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "M%s", sBuffer);

	SendToAllChildren(sBuffer);
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen)
{
	if(IsFakeClient(client))
		return true;

	decl String:sIP[33], String:sSocketIP[33];
	GetClientIP(client, sIP, sizeof(sIP));
	new iSize = GetArraySize(g_hChildIP);
	for(new i=0;i<iSize;i++)
	{
		GetArrayString(g_hChildIP, i, sSocketIP, sizeof(sSocketIP));
		if(StrEqual(sIP, sSocketIP))
		{
			Websocket_UnhookChild(WebsocketHandle:GetArrayCell(g_hChildren, i));
			RemoveFromArray(g_hChildIP, i);
			RemoveFromArray(g_hChildren, i);
			if(iSize == 1)
				break;
			i--;
			iSize--;
		}
	}

	return true;
}

public OnClientPutInServer(client)
{
	g_playerXP[client] = GetClientFrags(client);
	g_playerDeaths[client] = GetClientDeaths(client);

	SDKHook(client, SDKHook_WeaponSwitchPost, Event_OnWeaponSwitch_Post);
	//SDKHook(client, SDKHook_WeaponEquipPost, Event_OnWeaponEquip);

	// SDKHook(client, SDKHook_FireBulletsPost, OnFireBulletsPost);

	new iSize = GetArraySize(g_hChildren);
	if(iSize == 0)
		return;

	decl String:sBuffer[128];
	GetClientAuthId(client, AuthId_SteamID64, sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "C%d:%d:%s:%d:0:0:0:100:0::%N", GetClientUserId(client), client, sBuffer, GetClientTeam(client), client);

	SendToAllChildren(sBuffer);
}

public OnClientDisconnect(client)
{
	if(IsClientInGame(client))
	{
		new iSize = GetArraySize(g_hChildren);
		if(iSize == 0)
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

public OnGhostCapture(client)
{
	CreateTimer(0.1, CheckScores);
}

public Event_OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iSize = GetArraySize(g_hChildren);
	if(iSize == 0)
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
	new iSize = GetArraySize(g_hChildren);
	if(iSize == 0)
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
	int iSize = GetArraySize(g_hChildren);
	if(iSize == 0)
		return;

	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if (GetClientTeam(client) < 2)
		return;

	int class = GetPlayerClass(client);

	decl String:sBuffer[20];
	Format(sBuffer, sizeof(sBuffer), "S%d:%d:%d", userid, class, IsPlayerAlive(client));

	SendToAllChildren(sBuffer);
}

public Event_OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iSize = GetArraySize(g_hChildren);
	if(iSize == 0)
		return;

	new userid = GetEventInt(event, "userid");

	decl String:sBuffer[20];
	Format(sBuffer, sizeof(sBuffer), "H%d:%d", userid, GetEventInt(event, "health"));

	SendToAllChildren(sBuffer);
}

public Event_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iSize = GetArraySize(g_hChildren);
	if(iSize == 0)
		return;

	g_iRoundNumber = GameRules_GetProp("m_iRoundNumber");

	decl String:sBuffer[32];
	Format(sBuffer, sizeof(sBuffer), "R%d", g_iRoundNumber);

	SendToAllChildren(sBuffer);

	CreateTimer(0.1, CheckScores);
}

public Event_OnChangeName(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iSize = GetArraySize(g_hChildren);
	if(iSize == 0)
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

public Action:Hook_FireBullets(const String:te_name[], const Players[], numClients, Float:delay)
{
	new iSize = GetArraySize(g_hChildren);
	if (iSize == 0)
		return;

	int client = TE_ReadNum("m_iPlayer") + 1;
	int userid = GetClientUserId(client);

	char sBuffer[10];
	Format(sBuffer, sizeof(sBuffer), "F%d", userid);

	SendToAllChildren(sBuffer);
}

public void Event_OnWeaponEquip(int client, int weapon)
{
	int userid = GetClientUserId(client);

	char weaponName[20];
	GetEntityClassname(weapon, weaponName, sizeof(weaponName));

	char sBuffer[32];
	Format(sBuffer, sizeof(sBuffer), "E%d:%s", userid, weaponName);

	SendToAllChildren(sBuffer);
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

	new iSize = GetArraySize(g_hChildren);
	for(new i=0;i<iSize;i++)
		Websocket_Send(GetArrayCell(g_hChildren, i), SendType_Text, sBuffer);

	return Plugin_Continue;
}

public Action:OnWebsocketIncoming(WebsocketHandle:websocket, WebsocketHandle:newWebsocket, const String:remoteIP[], remotePort, String:protocols[256])
{
	// Make sure there's no ghosting!
	decl String:sIP[33];
	for(new i=1;i<=MaxClients;i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			GetClientIP(i, sIP, sizeof(sIP));
			if(StrEqual(sIP, remoteIP))
				return Plugin_Stop;
		}
	}

	Websocket_HookChild(newWebsocket, OnWebsocketReceive, OnWebsocketDisconnect, OnChildWebsocketError);
	Websocket_HookReadyStateChange(newWebsocket, OnWebsocketReadyStateChanged);
	PushArrayCell(g_hChildren, newWebsocket);
	PushArrayString(g_hChildIP, remoteIP);
	return Plugin_Continue;
}

public OnWebsocketReadyStateChanged(WebsocketHandle:websocket, WebsocketReadyState:readystate)
{
	new iIndex = FindValueInArray(g_hChildren, websocket);
	if(iIndex == -1)
		return;

	if(readystate != State_Open)
		return;

	decl String:sMap[64], String:sGameFolder[64], String:sBuffer[256], String:sTeam1[32], String:sTeam2[32], String:sHostName[128];
	GetCurrentMap(sMap, sizeof(sMap));
	GetGameFolderName(sGameFolder, sizeof(sGameFolder));
	GetTeamName(2, sTeam1, sizeof(sTeam1));
	GetTeamName(3, sTeam2, sizeof(sTeam2));
	GetConVarString(g_hostname, sHostName, sizeof(sHostName));
	Format(sBuffer, sizeof(sBuffer), "I%s:%s:%s:%s:%s", sGameFolder, sMap, sTeam1, sTeam2, sHostName);

	Websocket_Send(websocket, SendType_Text, sBuffer);

	if(g_iRoundNumber != -1)
	{
		Format(sBuffer, sizeof(sBuffer), "R%d", g_iRoundNumber);
		Websocket_Send(websocket, SendType_Text, sBuffer);
	}

	// Inform others there's another spectator!
	Format(sBuffer, sizeof(sBuffer), "A%d", GetArraySize(g_hChildren));
	new iSize = GetArraySize(g_hChildren);
	new WebsocketHandle:hHandle;
	for(new i=0;i<iSize;i++)
	{
		hHandle = WebsocketHandle:GetArrayCell(g_hChildren, i);
		if(Websocket_GetReadyState(hHandle) == State_Open)
			Websocket_Send(hHandle, SendType_Text, sBuffer);
	}

	// Add all players to it's list
	for(new i=1;i<=MaxClients;i++)
	{
		if(IsClientInGame(i))
		{
			GetClientAuthId(i, AuthId_SteamID64, sBuffer, sizeof(sBuffer));
			Format(sBuffer, sizeof(sBuffer), "C%d:%d:%s:%d:%d:%d:%d:%d:%d:%s:%N", GetClientUserId(i), i, sBuffer, GetClientTeam(i), IsPlayerAlive(i), GetClientFrags(i), GetClientDeaths(i), GetClientHealth(i), GetPlayerClass(i), g_playerActiveWeapon[i], i);

			Websocket_Send(websocket, SendType_Text, sBuffer);
		}
	}

	return;
}

public OnWebsocketMasterError(WebsocketHandle:websocket, const errorType, const errorNum)
{
	LogError("MASTER SOCKET ERROR: handle: %d type: %d, errno: %d", _:websocket, errorType, errorNum);
	g_hListenSocket = INVALID_WEBSOCKET_HANDLE;
}

public OnWebsocketMasterClose(WebsocketHandle:websocket)
{
	g_hListenSocket = INVALID_WEBSOCKET_HANDLE;
}

public OnChildWebsocketError(WebsocketHandle:websocket, const errorType, const errorNum)
{
	LogError("CHILD SOCKET ERROR: handle: %d, type: %d, errno: %d", _:websocket, errorType, errorNum);
	new iIndex = FindValueInArray(g_hChildren, websocket);
	RemoveFromArray(g_hChildren, iIndex);
	RemoveFromArray(g_hChildIP, iIndex);

	// Inform others there's one spectator less!
	decl String:sBuffer[10];
	Format(sBuffer, sizeof(sBuffer), "A%d", GetArraySize(g_hChildren));
	SendToAllChildren(sBuffer);
}

public OnWebsocketReceive(WebsocketHandle:websocket, WebsocketSendType:iType, const String:receiveData[], const dataSize)
{
	if(iType != SendType_Text)
		return;

	decl String:sBuffer[dataSize+4];
	Format(sBuffer, dataSize+4, "Z%s", receiveData);

	new iSize = GetArraySize(g_hChildren);
	new WebsocketHandle:hHandle;
	for(new i=0;i<iSize;i++)
	{
		hHandle = WebsocketHandle:GetArrayCell(g_hChildren, i);
		if(hHandle != websocket && Websocket_GetReadyState(hHandle) == State_Open)
			Websocket_Send(hHandle, SendType_Text, sBuffer);
	}
}

public OnWebsocketDisconnect(WebsocketHandle:websocket)
{
	new iIndex = FindValueInArray(g_hChildren, websocket);
	RemoveFromArray(g_hChildren, iIndex);
	RemoveFromArray(g_hChildIP, iIndex);

	// Inform others there's one spectator less!
	decl String:sBuffer[10];
	Format(sBuffer, sizeof(sBuffer), "A%d", GetArraySize(g_hChildren));
	SendToAllChildren(sBuffer);
}

SendToAllChildren(const String:sData[])
{
#if NT_RELAY_DEBUG_PRINT_SENDS
	PrintToServer("SendToAllChildren: %s", sData);
#endif

	new iSize = GetArraySize(g_hChildren);
	new WebsocketHandle:hHandle;
	for(new i=0;i<iSize;i++)
	{
		hHandle = WebsocketHandle:GetArrayCell(g_hChildren, i);
		if(Websocket_GetReadyState(hHandle) == State_Open)
			Websocket_Send(hHandle, SendType_Text, sData);
	}
}

stock UTF8_Encode(const String:sText[], String:sReturn[], const maxlen)
{
	new iStrLenI = strlen(sText);
	new iStrLen = 0;
	for(new i=0;i<iStrLenI;i++)
	{
		iStrLen += GetCharBytes(sText[i]);
	}

	decl String:sBuffer[iStrLen+1];

	new i = 0;
	for(new w=0;w<iStrLenI;w++)
	{
		if(sText[w] < 0x80)
		{
			sBuffer[i++] = sText[w];
		}
		else if(sText[w] < 0x800)
		{
			sBuffer[i++] = 0xC0 | sText[w] >> 6;
			sBuffer[i++] = 0x80 | sText[w] & 0x3F;
		}
		else if(sText[w] < 0x10000)
		{
			sBuffer[i++] = 0xE0 | sText[w] >> 12;
			sBuffer[i++] = 0x80 | sText[w] >> 6 & 0x3F;
			sBuffer[i++] = 0x80 | sText[w] & 0x3F;
		}
	}
	sBuffer[i] = '\0';
	strcopy(sReturn, maxlen, sBuffer);
}
