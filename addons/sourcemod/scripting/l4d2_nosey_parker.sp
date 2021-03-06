#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

new Handle:hTongueParalyzeTimer = INVALID_HANDLE;

new iDamage[MAXPLAYERS + 1][MAXPLAYERS + 1];

new Float:fGhostDelay;
new Float:fReported[MAXPLAYERS + 1][MAXPLAYERS + 1];

public Plugin:myinfo =
{
    name        = "L4D2 Display Infected HP",
    author      = "Visor",
    version     = "1.2",
    description = "Survivors receive damage reports after they get capped",
    url         = "https://github.com/Attano/Equilibrium"
};

public OnPluginStart()
{
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("charger_carry_start", Event_CHJ_Attack);
    HookEvent("charger_pummel_start", Event_CHJ_Attack);
    HookEvent("lunge_pounce", Event_CHJ_Attack);
    HookEvent("jockey_ride", Event_CHJ_Attack);
    HookEvent("tongue_grab", Event_SmokerAttackFirst);
    HookEvent("choke_start", Event_SmokerAttackSecond);
}

public OnConfigsExecuted()
{
    fGhostDelay = GetConVarFloat(FindConVar("z_ghost_delay_min"));
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!IsInfected(victim) || IsTargetedSi(victim) < 0)
        return;

    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    if (attacker == 0 || !IsClientInGame(attacker) || !IsSurvivor(attacker) || IsFakeClient(attacker) || !IsPlayerAlive(attacker))
        return;

    iDamage[attacker][victim] += GetEventInt(event, "dmg_health");
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client == 0 || !IsClientInGame(client) || !IsInfected(client))
        return;

    new zombieclass = IsTargetedSi(client);
    if (zombieclass < 0)
        return;    

    for (new i = 1; i <= MaxClients; i++)
    {
        iDamage[i][client] = 0;
    }

    if (zombieclass == _:L4D2Infected_Smoker)
    {
        ClearTimer(hTongueParalyzeTimer);
    }
}

public Event_CHJ_Attack(Handle:event, const String:name[], bool:dontBroadcast)
{
    new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
    if (attacker == 0 || !IsClientInGame(attacker) || !IsInfected(attacker) || !IsPlayerAlive(attacker))
        return;
        
    new victim = GetClientOfUserId(GetEventInt(event, "victim"));
    if (victim == 0 || !IsClientInGame(victim) || !IsSurvivor(victim) || IsFakeClient(victim) || !IsPlayerAlive(victim))
        return;
        
    PrintInflictedDamage(victim, attacker);
}

public Event_SmokerAttackFirst(Handle:event, const String:name[], bool:dontBroadcast)
{
    new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
    new victim = GetClientOfUserId(GetEventInt(event, "victim"));
    new checks = 0;

    new Handle:hEventMembers = CreateStack(3);
    PushStackCell(hEventMembers, attacker);
    PushStackCell(hEventMembers, victim);
    PushStackCell(hEventMembers, checks);

    // It takes exactly 1.0s of dragging to get paralyzed, so we'll give the timer additional 0.1s to update
    hTongueParalyzeTimer = CreateTimer(1.1, CheckSurvivorState, hEventMembers, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:CheckSurvivorState(Handle:timer, any:hEventMembers)
{
    static checks, victim, attacker;
    if (!IsStackEmpty(hEventMembers))
    {
        PopStackCell(hEventMembers, checks);
        PopStackCell(hEventMembers, victim);
        PopStackCell(hEventMembers, attacker);
    }

    if (IsSurvivorParalyzed(victim))
    {
        PrintInflictedDamage(victim, attacker);
    }
}

bool:IsSurvivorParalyzed(client)
{
    return (GetGameTime() - GetEntDataFloat(client, 13292) >= 1.0) && (GetEntData(client, 13284) > 0);
}

public Event_SmokerAttackSecond(Handle:event, const String:name[], bool:dontBroadcast)
{
    new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
    new victim = GetClientOfUserId(GetEventInt(event, "victim"));

    ClearTimer(hTongueParalyzeTimer);
    PrintInflictedDamage(victim, attacker);
}

public PrintInflictedDamage(iSurvivor, iInfected)
{
    new Float:fGameTime = GetGameTime();
    if ((fReported[iSurvivor][iInfected] + fGhostDelay) >= fGameTime)    // Used as a workaround to prevent double prints that might happen for Charger/Smoker
        return;

    if (iDamage[iSurvivor][iInfected] == 0)   // Don't bother
        return;

    PrintToChat(iSurvivor, 
    "\x04[DmgReport]\x01 \x03%N\x01(\x04%s\x01) took \x05%d\x01 damage from you!", 
    iInfected, 
    L4D2_InfectedNames[_:GetEntProp(iInfected, Prop_Send, "m_zombieClass")-1], 
    iDamage[iSurvivor][iInfected]);

    fReported[iSurvivor][iInfected] = GetGameTime();
    iDamage[iSurvivor][iInfected] = 0;
}

IsTargetedSi(client)
{
    new L4D2_Infected:zombieclass = GetInfectedClass(client);

    if (zombieclass == L4D2Infected_Charger || 
    zombieclass == L4D2Infected_Hunter || 
    zombieclass == L4D2Infected_Jockey || 
    zombieclass == L4D2Infected_Smoker
    ) return _:zombieclass;

    return -1;
}

ClearTimer(&Handle:timer)
{
    if (timer != INVALID_HANDLE)
    {
        KillTimer(timer);
        timer = INVALID_HANDLE;
    }     
}