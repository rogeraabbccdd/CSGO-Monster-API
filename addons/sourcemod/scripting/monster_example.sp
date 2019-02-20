#include <sourcemod>
#include <sdktools>
#include <monster>

#define TYPE "chicken"
#define MODEL "models/chicken/chicken.mdl"
#define HEALTH "20"
#define DAMAGE "1"

int count;

public Plugin myinfo =
{
	name = "[CS:GO] Monster API sample plugin",
	author = "Kento",
	version = "1.0",
	description = "Monster API sample plugin",
	url = "http://steamcommunity.com/id/kentomatoryoshika/"
};

public void OnPluginStart() 
{
	RegConsoleCmd("sm_spawnchicken", CMD_Chicken);
}

public Action CMD_Chicken(int client, int args)
{
	float pos[3];
	float clientEye[3], clientAngle[3];
	GetClientEyePosition(client, clientEye);
	GetClientEyeAngles(client, clientAngle);
		
	TR_TraceRayFilter(clientEye, clientAngle, MASK_SOLID, RayType_Infinite, HitSelf, client);
	
	if (TR_DidHit(INVALID_HANDLE))	TR_GetEndPosition(pos);

	char monstername[64];
	Format(monstername, sizeof(monstername), "%s%d", TYPE, count);
	count++;
	Monster_Spawn(monstername, MODEL, pos);
	Monster_Set(monstername, "animation", "run01Flap");
	Monster_Set(monstername, "damage", DAMAGE);
	Monster_Set(monstername, "health", HEALTH);
	Monster_Set(monstername, "attack", "ct");
}

public Action Monster_OnBreak(int monster, int client, const char [] weapon)
{
	char name[64];
	GetEntPropString(monster, Prop_Data, "m_iName", name, sizeof(name));
	PrintToChat(client, "You killed monster %s", name);
}

public bool HitSelf(int entity, int contentsMask, any data)
{
	if (entity == data)	return false;
	return true;
}