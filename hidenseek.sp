#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>

int g_iSeeker;

bool
	g_bRoundActive			  = false;
	g_bHiding[MAXPLAYERS + 1] = false;

public Plugin myinfo = 
{
	name = "Titan.TF - Hide n' Seek",
	author = "myst",
	version = "1.0",
	url = "https://www.youtube.com/watch?v=m2_X_sktuJ8"
}

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_setup_finished", Event_SetupFinished);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	
	AddCommandListener(BlockCMD, "jointeam");
	AddCommandListener(BlockCMD, "autoteam");
}

public void OnMapStart()
{
	HookEntityOutput("trigger_capture_area", "OnStartCap", DisableCap);
	
	UpdateConVars();
	EnableBalancing();
	
	g_bRoundActive = false;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
	
	if (g_bRoundActive)
		g_bHiding[client] = false;
}

public void OnClientDisconnect(int client)
{
	if (GetPlayersCount(2) == 0)
	{
		ServerCommand("mp_forcewin 3");
	}
	
	if (IsValidClient(client))
		if (client == g_iSeeker) UpdateSeeker();
}

void UpdateSeeker()
{
	g_iSeeker = GetRandomPlayer();
	
	for (int client = 1; client <= MaxClients; client++) 
	{
		if (IsValidClient(client))
		{
			if (client == g_iSeeker)
			{
				g_bHiding[client] = false;
				
				if (GetClientTeam(client) == view_as<int>(TFTeam_Red))
					ChangeClientTeam(client, 3);
			}
			
			else if (client != g_iSeeker)
			{
				g_bHiding[client] = true;
				
				if (GetClientTeam(client) == view_as<int>(TFTeam_Blue))
					ChangeClientTeam(client, 2);
			}
		}
	}
}

public Action Event_RoundStart(Handle hEvent, const char[] sName, bool bDontBroadcast) 
{
	EnableBalancing();
	DeleteLockers();
	
	UpdateSeeker();
	
	g_bRoundActive = false;
}

public Action Event_SetupFinished(Handle hEvent, const char[] sName, bool bDontBroadcast) 
{
	DisableBalancing();
	DeleteDoors();
	
	g_bRoundActive = true;
	
	for (int client = 1; client <= MaxClients; client++) 
	{
		if (IsValidClient(client))
		{
			if (GetClientTeam(client) == view_as<int>(TFTeam_Red))
				g_bHiding[client] = true;
			else
				g_bHiding[client] = false;
		}
	}
	
	if (GetPlayersCount(2) == 0)
	{
		ServerCommand("mp_forcewin 3");
	}
}

public Action Event_RoundEnd(Handle hEvent, const char[] sName, bool bDontBroadcast) 
{
	for (int client = 1; client <= MaxClients; client++) 
	{
		if (IsValidClient(client))
		{
			g_bHiding[client] = true;
		}
	}
}

public Action Event_PlayerSpawn(Handle hEvent, const char[] sName, bool bDontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (IsPlayerAlive(client))
	{
		TFClassType TFClass = TF2_GetPlayerClass(client);
		
		if (GetClientTeam(client) == view_as<int>(TFTeam_Red))
		{
			if (g_bRoundActive)
			{
				if (!g_bHiding[client])
				{
					ChangeClientTeam(client, 3);
					return;
				}
			}
			
			if (TFClass != TFClass_Spy)
			{
				TF2_SetPlayerClass(client, TFClass_Spy);
				TF2_RespawnPlayer(client);
			}
			
			TF2Attrib_SetByName(client, "become fireproof on hit by fire", 1.0);
			TF2Attrib_SetByName(client, "cloak consume rate increased", 5.0);
			TF2Attrib_SetByName(client, "cloak regen rate increased", 5.0);
			TF2Attrib_SetByName(client, "max health additive penalty", -25.0);
		}
		
		else if (GetClientTeam(client) == view_as<int>(TFTeam_Blue))
		{
			if (g_bRoundActive)
			{
				if (g_bHiding[client])
					g_bHiding[client] = false;
			}
			
			if (TFClass != TFClass_Pyro)
			{
				TF2_SetPlayerClass(client, TFClass_Pyro);
				TF2_RespawnPlayer(client);
			}
			
			TF2Attrib_SetByName(client, "maxammo primary increased", 2.0);
			TF2Attrib_SetByName(client, "flame size penalty", 5.0);
			TF2Attrib_SetByName(client, "flame life penalty", 5.0);
		}
		
		FixWeapons(client);
	}
	
	return;
}

public Action Event_PlayerDeath(Handle hEvent, const char[] sName, bool bDontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (g_bRoundActive)
	{
		if (GetClientTeam(client) == view_as<int>(TFTeam_Red))
		{
			ChangeClientTeam(client, 3);
		}
		
		if (GetPlayersCount(2) == 0)
		{
			ServerCommand("mp_forcewin 3");
		}
	}
}

void FixWeapons(int client)
{
 	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		if (GetClientTeam(client) == view_as<int>(TFTeam_Red))
		{
			TF2_RemoveWeaponSlot(client, 0);
			TF2_SwitchtoSlot(client, TFWeaponSlot_Melee);
		}
		
		else if (GetClientTeam(client) == view_as<int>(TFTeam_Blue))
		{
			/*for (int i = 0; i <= 2; i++) {
				if (i != 0) TF2_RemoveWeaponSlot(client, i);
			}
			
			TF2_SwitchtoSlot(client, TFWeaponSlot_Primary);*/
			
			new weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			new index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			
			if (index == 12)
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				TF2_SwitchtoSlot(client, TFWeaponSlot_Primary);
			}
		}
	} 
}

void TF2_SwitchtoSlot(int client, int slot)
{
	if (slot >= 0 && slot <= 5 && IsValidClient(client) && IsPlayerAlive(client))
	{
		char sClassname[64];
		int iWep = GetPlayerWeaponSlot(client, slot);
		if (iWep > MaxClients && IsValidEdict(iWep) && GetEdictClassname(iWep, sClassname, sizeof(sClassname)))
		{
			FakeClientCommandEx(client, "use %s", sClassname);
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWep);
		}
	}
}

void UpdateConVars()
{
	SetConVarInt(FindConVar("mp_disable_respawn_times"), 1);
	SetConVarInt(FindConVar("tf_weapon_criticals"), 0);
	SetConVarInt(FindConVar("tf_weapon_criticals_melee"), 0);
}

void EnableBalancing()
{
	SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 1);
	SetConVarInt(FindConVar("mp_autoteambalance"), 1);
}

void DisableBalancing()
{
	SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0);
	SetConVarInt(FindConVar("mp_autoteambalance"), 0);
}

void DeleteLockers()
{
	int iRegenerate = -1;
	while ((iRegenerate = FindEntityByClassname(iRegenerate, "func_regenerate")) != -1)
	{
		AcceptEntityInput(iRegenerate, "Kill");
	}
}

void DeleteDoors()
{
	int iDoor = -1;
	while ((iDoor = FindEntityByClassname(iDoor, "func_door")) != -1)
	{
		AcceptEntityInput(iDoor, "Open");
		AcceptEntityInput(iDoor, "Unlock");
	}
	
	int iAreaPortal = -1;
	while ((iAreaPortal = FindEntityByClassname(iAreaPortal, "func_areaportal")) != -1)
	{
		AcceptEntityInput(iAreaPortal, "Open");
	}
	
	int iFilter = -1;
	while ((iFilter = FindEntityByClassname(iFilter, "filter_activator_tfteam")) != -1)
	{
		SetVariantInt(0);
		AcceptEntityInput(iFilter, "SetTeam");
	}
	
	int iVisualizer = -1;
	while ((iVisualizer = FindEntityByClassname(iVisualizer, "func_respawnroomvisualizer")) != -1)
	{
		AcceptEntityInput(iVisualizer, "Kill");
	}
	
	int iRespawn = -1;
	while ((iRespawn = FindEntityByClassname(iRespawn, "func_respawnroom")) != -1)
	{
		AcceptEntityInput(iRespawn, "Kill");
	}
}

stock int GetPlayersCount(int team) 
{ 
	int iCount, i; iCount = 0; 

	for (i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == team) 
			iCount++; 
	}

	return iCount; 
}

stock int GetRandomPlayer() 
{
	int[] clients = new int[MaxClients+1]; int clientCount;
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
			clients[clientCount++] = i;
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

public DisableCap(const char[] output, int caller, int activator, float delay)
{
	AcceptEntityInput(caller, "Disable");
}

public Action BlockCMD(int client, const char[] command, int iArgs)
{
	return Plugin_Handled;
}

public Action Hook_SetTransmit(int entity, int client)
{
	if (GetClientTeam(client) == view_as<int>(TFTeam_Blue) && GetClientTeam(entity) == view_as<int>(TFTeam_Red) || client == entity) return Plugin_Continue;
	else if (GetClientTeam(client) == view_as<int>(TFTeam_Red) && GetClientTeam(entity) == view_as<int>(TFTeam_Red)) return Plugin_Handled;
	return Plugin_Handled;
}

stock bool IsValidClient(int client, bool bReplay = true)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return false;
	if (bReplay && (IsClientSourceTV(client) || IsClientReplay(client)))
		return false;
	return true;
}
