#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <morecolors>

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
	HookEntityOutput("trigger_capture_area", "OnStartCap", StartCap);
	
	UpdateConVars();
	EnableBalancing();
	
	g_bRoundActive = false;
}

public void OnClientPutInServer(int client)
{
	if (g_bRoundActive)
		g_bHiding[client] = false;
}

public Action Event_RoundStart(Handle hEvent, const char[] sName, bool bDontBroadcast) 
{
	EnableBalancing();
}

public Action Event_SetupFinished(Handle hEvent, const char[] sName, bool bDontBroadcast) 
{
	DisableBalancing();
	
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
			
			TF2Attrib_SetByName(client, "mult cloak meter consume rate", 1.0);
			TF2Attrib_SetByName(client, "mult cloak meter regen rate", 1.0);
			TF2Attrib_SetByName(client, "max health additive penalty", 25.0);
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
		}
		
		FixWeapons(client);
	}
	
	return;
}

public Action Event_PlayerDeath(Handle hEvent, const char[] sName, bool bDontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (GetClientTeam(client) == view_as<int>(TFTeam_Red))
	{
		ChangeClientTeam(client, 3);
	}
	
	if (GetPlayersCount(2) == 0)
	{
		ServerCommand("mp_forcewin 3");
	}
}

void FixWeapons(int client)
{
 	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		if (GetClientTeam(client) == view_as<int>(TFTeam_Red))
		{
			for (int i = 0; i <= 4; i++) {
				if (i != 2 && i != 4) TF2_RemoveWeaponSlot(client, i);
			}
			
			TF2_SwitchtoSlot(client, TFWeaponSlot_Melee);
		}
		
		else if (GetClientTeam(client) == view_as<int>(TFTeam_Blue))
		{
			for (int i = 0; i <= 2; i++) {
				if (i != 0) TF2_RemoveWeaponSlot(client, i);
			}
			
			TF2_SwitchtoSlot(client, TFWeaponSlot_Primary);
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
	SetConVarInt(FindConVar("mp_autoteambalance"), 0);
}

void DisableBalancing()
{
	SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0);
	SetConVarInt(FindConVar("mp_autoteambalance"), 0);
}

stock int GetPlayersCount(int team) 
{ 
	int iCount, i; iCount = 0; 

	for (i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == team) 
			iCount++; 
	}

	return iCount; 
}

public StartCap(const char[] output, int caller, int activator, float delay)
{
	AcceptEntityInput(caller, "Disable");
}

public Action BlockCMD(int client, const char[] command, int iArgs)
{
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