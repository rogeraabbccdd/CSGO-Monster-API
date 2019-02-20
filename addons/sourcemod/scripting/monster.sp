#include <sourcemod>
#include <sdktools>

#define MAX_MONSTERS 64
#pragma newdecls required

Handle MonsterList;
Handle MonsterCollision;
Handle MonsterDamageList;
Handle MonsterModel;
Handle MonsterAnimation;
Handle MonsterHealth;
Handle MonsterDamage;
Handle MonsterDamageRange;
Handle MonsterDamageDelay;
Handle MonsterColor;
Handle MonsterAlpha;
Handle MonsterSpeed;
Handle MonsterScale;
Handle MonsterOffset;
Handle MonsterMinRange;
Handle MonsterMaxRange;
Handle MonsterFollow;
Handle MonsterZone;
Handle MonsterAttack;

Handle TargetList[MAX_MONSTERS];

bool isImmune[MAXPLAYERS][MAX_MONSTERS];

Handle fOnMonsterBreak;

#define PLUGIN_VERSION "1.0"
public Plugin myinfo = 
{
	name = "Monster API",
	author = "Panzer, shanapu, Kento",
	description = "Creates a monster that chases the nearest player",
	version = PLUGIN_VERSION,
	url = "forums.alliedmodders.com"
}

#include <monster>

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	// Create arrays
	MonsterList = CreateArray();
	MonsterCollision = CreateArray();
	MonsterDamageList = CreateArray();
	MonsterModel = CreateArray(64);
	MonsterAnimation = CreateArray(64);
	MonsterHealth = CreateArray();
	MonsterDamage = CreateArray();
	MonsterDamageRange = CreateArray();
	MonsterDamageDelay = CreateArray();
	MonsterColor = CreateArray(16);
	MonsterAlpha = CreateArray();
	MonsterSpeed = CreateArray();
	MonsterScale = CreateArray();
	MonsterOffset = CreateArray();
	MonsterMinRange = CreateArray();
	MonsterMaxRange = CreateArray();
	MonsterFollow = CreateArray();
	MonsterZone = CreateArray(64);
	MonsterAttack = CreateArray();
	
	// Add existing monster collisions to monster collision list
	int monsterCollision = -1;
	while ((monsterCollision = FindEntityByClassname(monsterCollision, "prop_physics")) != -1)
	{
		char targetname[32];
		GetEntPropString(monsterCollision, Prop_Data, "m_iName", targetname, sizeof(targetname));
		int mIndex;
		if (StrContains(targetname, "_c_123monster321_") != -1)
			mIndex = PushArrayCell(MonsterCollision, monsterCollision);
			
		// Create default random target list
		TargetList[mIndex] = CreateArray();
		for (int clients = 1; clients <= MaxClients; clients++)
			if (IsValidClient(clients))
				PushArrayCell(TargetList[mIndex], clients);
		
		// Set default attributes
		char model[64];
		GetEntPropString(monsterCollision, Prop_Data, "m_ModelName", model, sizeof(model));
		PushArrayString(MonsterModel, model);
		PushArrayString(MonsterAnimation, "");
		PushArrayCell(MonsterHealth, 150);
		PushArrayCell(MonsterDamage, 2);
		PushArrayCell(MonsterDamageRange, 64.0);
		PushArrayCell(MonsterDamageDelay, 0.1);
		PushArrayString(MonsterColor, "255,255,255");
		PushArrayCell(MonsterAlpha, 255);
		PushArrayCell(MonsterSpeed, 250.0);
		PushArrayCell(MonsterScale, 1.0);
		PushArrayCell(MonsterOffset, 32.0);
		PushArrayCell(MonsterMinRange, 4.0);
		PushArrayCell(MonsterMaxRange, 999999.0);
		PushArrayCell(MonsterFollow, -1);
		PushArrayString(MonsterZone, "");
		PushArrayCell(MonsterAttack, 0);
		
		// Default monster collision values
		DispatchKeyValue(monsterCollision, "solid", "6");
		HookSingleEntityOutput(monsterCollision, "OnBreak", OnMonsterBreak);
		SetEntProp(monsterCollision, Prop_Data, "m_takedamage", 2);
		SetEntProp(monsterCollision, Prop_Data, "m_iMaxHealth", 150);
		SetEntProp(monsterCollision, Prop_Data, "m_iHealth", 150);
		SetEntProp(monsterCollision, Prop_Send, "m_usSolidFlags", 1);
		SetEntProp(monsterCollision, Prop_Send, "m_CollisionGroup", 11);
	}
	
	// Add existing monsters to monster list
	int monster = -1;
	while ((monster = FindEntityByClassname(monster, "prop_dynamic")) != -1)
	{
		char targetname[32];
		GetEntPropString(monster, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrContains(targetname, "_v_123monster321_") != -1)
			PushArrayCell(MonsterList, monster);
			
		// Default monster values
		SetEntityRenderColor(monster, 255, 255, 255, 255);
		DispatchKeyValue(monster, "solid", "0");
	}
	
	// Add existing damage entities to damage list
	int damage = -1;
	while ((damage = FindEntityByClassname(damage, "point_hurt")) != -1)
	{
		char targetname[32];
		GetEntPropString(damage, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrContains(targetname, "_d_123monster321_") != -1)
			PushArrayCell(MonsterDamageList, damage);
			
		// Default damage values
		DispatchKeyValue(damage, "damage", "2");
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Monster_Spawn", Native_Spawn);
	CreateNative("Monster_Set", Native_Set);
	CreateNative("Monster_Remove", Native_Remove);
	CreateNative("Monster_Clear", Native_Clear);
	CreateNative("Monster_Tele", Native_Tele);

	fOnMonsterBreak = CreateGlobalForward("Monster_OnBreak", ET_Ignore, Param_Cell, Param_Cell, Param_String);
}

public int Native_Spawn(Handle plugin, int numParams)
{
	char name[64], model[64];
	GetNativeString(1, name, sizeof(name));
	GetNativeString(2, model, sizeof(model));
	
	float pos[3];
	GetNativeArray(3, pos, 3);

	if (GetArraySize(MonsterList) > MAX_MONSTERS)	return -1;
	
	int spawn = SpawnMonster(name, model, pos);
	return spawn;
}

public int Native_Set(Handle plugin, int numParams)
{
	char name[64], attribute[16], value[64];
	GetNativeString(1, name, sizeof(name));
	GetNativeString(2, attribute, sizeof(attribute));
	GetNativeString(3, value, sizeof(value));
	
	bool found = false;
	for (int mIndex = 0; mIndex < GetArraySize(MonsterList); mIndex++)
	{
		int monster = GetArrayCell(MonsterList, mIndex);
		int monsterCollision = GetArrayCell(MonsterCollision, mIndex);
		int monsterHurt = GetArrayCell(MonsterDamageList, mIndex);
		char targetname[64];
		GetEntPropString(monster, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrContains(targetname, name) != -1)	found = true;
		
		if (StrEqual(attribute, "model"))
		{
			if (!IsModelPrecached(value))
				PrecacheModel(value);
			SetEntityModel(monster, value);
			SetEntityModel(monsterCollision, value);
			SetArrayString(MonsterModel, mIndex, value);
		}
		else if (StrEqual(attribute, "animation"))
		{
			SetVariantString(value);
			AcceptEntityInput(monster, "SetAnimation");
			SetArrayString(MonsterAnimation, mIndex, value);
		}
		else if (StrEqual(attribute, "health"))
		{
			int health = StringToInt(value);
			SetEntProp(monsterCollision, Prop_Data, "m_iMaxHealth", health);
			SetEntProp(monsterCollision, Prop_Data, "m_iHealth", health);
			SetArrayCell(MonsterHealth, mIndex, health);
		}
		else if (StrEqual(attribute, "damage"))
		{
			DispatchKeyValue(monsterHurt, "damage", value);
			int damage = StringToInt(value);
			SetArrayCell(MonsterDamage, mIndex, damage);
		}
		else if (StrEqual(attribute, "damagerange"))
		{
			float damageRange = StringToFloat(value);
			SetArrayCell(MonsterDamageRange, mIndex, damageRange);
		}
		else if (StrEqual(attribute, "damagedelay"))
		{
			float damageDelay = StringToFloat(value);
			SetArrayCell(MonsterDamageDelay, mIndex, damageDelay);
		}
		else if (StrEqual(attribute, "color"))
		{
			char color[3][8];
			ExplodeString(value, ",", color, sizeof(color), sizeof(color[]));
			int alpha = GetArrayCell(MonsterAlpha, mIndex);
			SetEntityRenderColor(monster, StringToInt(color[0]), StringToInt(color[1]), StringToInt(color[2]), alpha);
			SetArrayString(MonsterColor, mIndex, value);
		}
		else if (StrEqual(attribute, "alpha"))
		{
			char colors[16];
			GetArrayString(MonsterColor, mIndex, colors, sizeof(colors));
			char colors2[3][8];
			ExplodeString(colors, ",", colors2, sizeof(colors2), sizeof(colors2[]));
			int alpha = StringToInt(value);
			SetEntityRenderMode(monster, RENDER_TRANSCOLOR);
			SetEntityRenderColor(monster, StringToInt(colors2[0]), StringToInt(colors2[1]), StringToInt(colors2[2]), alpha)
			SetArrayCell(MonsterAlpha, mIndex, alpha);
		}
		else if (StrEqual(attribute, "speed"))
		{
			float speed = StringToFloat(value);
			SetArrayCell(MonsterSpeed, mIndex, speed);
		}
		else if (StrEqual(attribute, "scale"))
		{
			float scale = StringToFloat(value);
			SetEntPropFloat(monster, Prop_Send, "m_flModelScale", scale);
			SetEntPropFloat(monsterCollision, Prop_Send, "m_flModelScale", scale);
			SetArrayCell(MonsterScale, mIndex, scale);
		}
		else if (StrEqual(attribute, "offset"))
		{
			float offset = StringToFloat(value);
			SetArrayCell(MonsterOffset, mIndex, offset);
		}
		else if (StrEqual(attribute, "minrange"))
		{
			float minRange = StringToFloat(value);
			SetArrayCell(MonsterMinRange, mIndex, minRange);
		}
		else if (StrEqual(attribute, "maxrange"))
		{
			float maxRange = StringToFloat(value);
			SetArrayCell(MonsterMaxRange, mIndex, maxRange);
		}
		else if (StrEqual(attribute, "sound"))
		{
			float delay;
			char sound[PLATFORM_MAX_PATH];
			int len = BreakString(value, sound, sizeof(sound));
			if (len == -1)
			{
				len = 0;
				value[0] = '\0';
			}
			else delay = StringToFloat(value[len]);
			
			PrecacheSound(sound);
			EmitSoundToAll(sound, monster);
			
			if (delay)
			{
				Handle data;
				CreateDataTimer(delay, Timer_PlaySound, data, TIMER_FLAG_NO_MAPCHANGE);
				WritePackString(data, sound);
				WritePackFloat(data, delay);
				WritePackCell(data, EntIndexToEntRef(monster));
				ResetPack(data);
			}
		}
		else if (StrEqual(attribute, "attack"))
		{
			ClearArray(TargetList[mIndex]);
			
			if (StrEqual(value, "none"))
			{
				// array has already be cleaned
			}
			else if (StrEqual(value, "all"))
			{
				// Create random target list
				for (int clients = 1; clients <= MaxClients; clients++)
					if (IsValidClient(clients))
						PushArrayCell(TargetList[mIndex], clients);
			}
			else if (StrEqual(value, "tr"))
			{
				// Create random target list
				for (int clients = 1; clients <= MaxClients; clients++)
					if (IsValidClient(clients) && GetClientTeam(clients) == 2)
						PushArrayCell(TargetList[mIndex], clients);
			}
			else if (StrEqual(value, "ct"))
			{
				// Create random target list
				for (int clients = 1; clients <= MaxClients; clients++)
					if (IsValidClient(clients) && GetClientTeam(clients) == 3)
						PushArrayCell(TargetList[mIndex], clients);
			}
			else
			{
				int target = FindTarget(0, value);
				if (target > -1)
				{
					int uid = GetClientUserId(target);
					SetArrayCell(MonsterAttack, mIndex, uid);
				}
				else return false;
			}
		}
		else	return false;
	}
	
	if(!found)	return false;

	return true;
}

public int Native_Remove(Handle plugin, int numParams)
{
	char name[64];
	GetNativeString(1, name, sizeof(name));

	bool found = false;
	for (int mIndex = 0; mIndex < GetArraySize(MonsterList); mIndex++)
	{
		int monster = GetArrayCell(MonsterList, mIndex);
		char targetname[64];
		GetEntPropString(monster, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrContains(targetname, name) != -1)
		{
			found = true;
			AcceptEntityInput(monster, "Kill");
		}
	}
	
	if (!found)	return false;
	return true;
}

public int Native_Clear(Handle plugin, int numParams)
{
	// Remove all monsers and clear all attributes
	for (int mIndex = 0; mIndex < GetArraySize(MonsterList); mIndex++)
	{
		int monster, collision, damagelist;
		monster	= GetArrayCell(MonsterList, mIndex);
		collision	= GetArrayCell(MonsterCollision, mIndex);
		damagelist	= GetArrayCell(MonsterDamageList, mIndex);
		
		if (IsValidEntity(monster)) AcceptEntityInput(monster, "Kill");
		if (IsValidEntity(collision)) AcceptEntityInput(collision, "Kill");
		if (IsValidEntity(damagelist)) AcceptEntityInput(damagelist, "Kill");
		ClearArray(TargetList[mIndex]);
	}

	ClearArray(MonsterList);
	ClearArray(MonsterCollision);
	ClearArray(MonsterDamageList);
	ClearArray(MonsterModel);
	ClearArray(MonsterAnimation);
	ClearArray(MonsterHealth);
	ClearArray(MonsterDamage);
	ClearArray(MonsterDamageRange);
	ClearArray(MonsterDamageDelay);
	ClearArray(MonsterColor);
	ClearArray(MonsterAlpha);
	ClearArray(MonsterSpeed);
	ClearArray(MonsterScale);
	ClearArray(MonsterOffset);
	ClearArray(MonsterMinRange);
	ClearArray(MonsterMaxRange);
	ClearArray(MonsterFollow);
	ClearArray(MonsterZone);
	ClearArray(MonsterAttack);

	return true;
}

public int Native_Tele(Handle plugin, int numParams)
{
	char name[64];
	GetNativeString(1, name, sizeof(name));
	
	float pos[3];
	GetNativeArray(3, pos, 3);

	bool found = false;
	for (int mIndex = 0; mIndex < GetArraySize(MonsterList); mIndex++)
	{
		int monster = GetArrayCell(MonsterList, mIndex);
		char targetname[64];
		GetEntPropString(monster, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrContains(targetname, name) != -1)
		{
			found = true;
			TeleportEntity(monster, pos, NULL_VECTOR, NULL_VECTOR);
		}
	}
	
	if (!found)	return false;
	return true;
}

public void OnMapEnd()
{
	for (int i = 0; i < GetArraySize(MonsterList); i++)
		ClearArray(TargetList[i]);
	ClearArray(MonsterList);
	ClearArray(MonsterDamageList);
	ClearArray(MonsterCollision);
	ClearArray(MonsterModel);
	ClearArray(MonsterAnimation);
	ClearArray(MonsterHealth);
	ClearArray(MonsterDamage);
	ClearArray(MonsterDamageRange);
	ClearArray(MonsterDamageDelay);
	ClearArray(MonsterColor);
	ClearArray(MonsterAlpha);
	ClearArray(MonsterSpeed);
	ClearArray(MonsterScale);
	ClearArray(MonsterOffset);
	ClearArray(MonsterMinRange);
	ClearArray(MonsterMaxRange);
	ClearArray(MonsterFollow);
	ClearArray(MonsterZone);
	ClearArray(MonsterAttack);
}

public void OnGameFrame()
{
	for (int mIndex = 0; mIndex < GetArraySize(MonsterList); mIndex++)
	{
		int monster = GetArrayCell(MonsterList, mIndex);
		int monsterCollision = GetArrayCell(MonsterCollision, mIndex);
		if (!IsValidEdict(monster)) continue;
		float mPos[3];
		GetEntPropVector(monster, Prop_Data, "m_vecOrigin", mPos);

		float distance;
		float minDistance = -1.0;
		int specificTarget = GetClientOfUserId(GetArrayCell(MonsterAttack, mIndex));
		if (specificTarget)
		{
			if (!IsPlayerAlive(specificTarget)) specificTarget = 0;
		}
		for (int target = 0; target < GetArraySize(TargetList[mIndex]); target++)
		{
			int client = GetArrayCell(TargetList[mIndex], target);
			if (specificTarget && client != specificTarget) continue;
			if (IsValidClient(client) && IsPlayerAlive(client))
			{
				// Get distance between players and monster
				float cPos[3];
				float vecDistance[3];
				GetClientAbsOrigin(client, cPos);
				float offset = GetArrayCell(MonsterOffset, mIndex);
				cPos[2] += offset; // Height Offset
				for (int j = 0; j < 3; j++)
					vecDistance[j] = cPos[j] - mPos[j];
				
				distance = GetVectorLength(vecDistance);
				if (minDistance == -1.0 || distance < minDistance)
					minDistance = distance;
					
				// Hurt the player if they are within a certain distance
				if (distance < GetArrayCell(MonsterDamageRange, mIndex) && !isImmune[client][mIndex])
				{
					char targetname[32];
					GetEntPropString(client, Prop_Data, "m_iName", targetname, sizeof(targetname));
					char name[64];
					GetClientName(client, name, sizeof(name));
					DispatchKeyValue(client, "targetname", name);
					//DispatchKeyValue(GetArrayCell(MonsterDamageList, mIndex), "target", "tempdamagetarget");
					DispatchKeyValue(GetArrayCell(MonsterDamageList, mIndex), "damagetarget", name);
					AcceptEntityInput(GetArrayCell(MonsterDamageList, mIndex), "hurt");
					DispatchKeyValue(client, "targetname", targetname);
					isImmune[client][mIndex] = true;
					Handle pack;
					CreateDataTimer(GetArrayCell(MonsterDamageDelay, mIndex), Timer_RemoveImmunity, pack);
					WritePackCell(pack, client);
					WritePackCell(pack, mIndex);
				}
				
				if (minDistance == distance) // This is the closest player
				{
					// Set angles to track player
					float angles[3];
					GetVectorAngles(vecDistance, angles);
					
					// Move towards player
					float minRange = GetArrayCell(MonsterMinRange, mIndex);
					float maxRange = GetArrayCell(MonsterMaxRange, mIndex);
					if (minDistance > minRange && minDistance < maxRange) // Min/Max range
					{
						NormalizeVector(vecDistance, vecDistance);
						float speed = GetArrayCell(MonsterSpeed, mIndex);
						ScaleVector(vecDistance, speed * GetTickInterval()); // Set speed
						AddVectors(vecDistance, mPos, vecDistance);
						TeleportEntity(monster, vecDistance, NULL_VECTOR, NULL_VECTOR);
						TeleportEntity(monsterCollision, vecDistance, NULL_VECTOR, NULL_VECTOR);
					}
					
					TeleportEntity(monster, NULL_VECTOR, angles, NULL_VECTOR);
					TeleportEntity(monsterCollision, NULL_VECTOR, angles, NULL_VECTOR);
				}
			}
		}
	}
}

public Action Timer_RemoveImmunity(Handle timer, Handle pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);
	int mIndex = ReadPackCell(pack);
	isImmune[client][mIndex] = false;
}

public Action Timer_PlaySound(Handle timer, Handle data)
{
	char sound[PLATFORM_MAX_PATH];
	float delay, ref;
	ReadPackString(data, sound, sizeof(sound));
	delay	= ReadPackFloat(data);
	ref		= ReadPackCell(data);
	int monster = EntRefToEntIndex(ReadPackCell(data));
	if (!IsValidEntity(monster)) return;
	EmitSoundToAll(sound, monster);
	Handle data2;
	CreateDataTimer(delay, Timer_PlaySound, data2, TIMER_FLAG_NO_MAPCHANGE);
	WritePackString(data2, sound);
	WritePackFloat(data2, delay);
	WritePackCell(data2, ref);
	ResetPack(data2);
}

public int SpawnMonster(char name[64], char model[64], float pos[3])
{
	if (!IsModelPrecached(model))
		PrecacheModel(model);
	
	// Collision model
	int monsterCollision = CreateEntityByName("prop_physics_override");
	if (!IsModelPrecached("models/props_farm/concrete_block001.mdl"))
		PrecacheModel("models/props_farm/concrete_block001.mdl");
	DispatchKeyValue(monsterCollision, "model", "models/props_farm/concrete_block001.mdl");
	char cName[64];
	Format(cName, sizeof(cName), "_c_123monster321_%s", name);
	DispatchKeyValue(monsterCollision, "targetname", cName);
	DispatchKeyValue(monsterCollision, "solid", "6");
	DispatchKeyValue(monsterCollision, "nodamageforces", "0");
	DispatchSpawn(monsterCollision);
	HookSingleEntityOutput(monsterCollision, "OnBreak", OnMonsterBreak);
	TeleportEntity(monsterCollision, pos, NULL_VECTOR, NULL_VECTOR);
	SetEntityModel(monsterCollision, model);
	AcceptEntityInput(monsterCollision, "disablemotion");
	SetEntProp(monsterCollision, Prop_Data, "m_takedamage", 2, 1);
	SetEntProp(monsterCollision, Prop_Data, "m_iMaxHealth", 150);
	SetEntProp(monsterCollision, Prop_Data, "m_iHealth", 150);
	SetEntProp(monsterCollision, Prop_Send, "m_usSolidFlags", 1);
	SetEntProp(monsterCollision, Prop_Send, "m_CollisionGroup", 11);
	SetEntityRenderMode(monsterCollision, RENDER_TRANSCOLOR);
	SetEntityRenderColor(monsterCollision, 255, 255, 255, 0);
	
	// Add to monster collision list
	PushArrayCell(MonsterCollision, monsterCollision);
	
	// Visual model
	int monster = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(monster, "model", model);
	char vName[64];
	Format(vName, sizeof(vName), "_v_123monster321_%s", name);
	DispatchKeyValue(monster, "targetname", vName);
	DispatchKeyValue(monster, "solid", "0");
	DispatchSpawn(monster);
	TeleportEntity(monster, pos, NULL_VECTOR, NULL_VECTOR);
	
	// Add to monster list
	int mIndex = PushArrayCell(MonsterList, monster);
	
	// Create damage entity
	int damage = CreateEntityByName("point_hurt");
	char dName[64];
	Format(dName, sizeof(dName), "_d_123monster321_%s", name);
	DispatchKeyValue(damage, "targetname", dName);
	DispatchKeyValue(damage, "damage", "2");
	DispatchSpawn(damage);
	
	// Add damage entity to list
	PushArrayCell(MonsterDamageList, damage);
	
	// Create default random target list
	TargetList[mIndex] = CreateArray();
	for (int clients = 1; clients <= MaxClients; clients++)
		if (IsValidClient(clients))
			PushArrayCell(TargetList[mIndex], clients);
	
	// Set default attributes
	PushArrayString(MonsterModel, model);
	PushArrayString(MonsterAnimation, "");
	PushArrayCell(MonsterHealth, 150);
	PushArrayCell(MonsterDamage, 2);
	PushArrayCell(MonsterDamageRange, 64.0);
	PushArrayCell(MonsterDamageDelay, 0.1);
	PushArrayString(MonsterColor, "255,255,255");
	PushArrayCell(MonsterAlpha, 255);
	PushArrayCell(MonsterSpeed, 250.0);
	PushArrayCell(MonsterScale, 1.0);
	PushArrayCell(MonsterOffset, 32.0);
	PushArrayCell(MonsterMinRange, 4.0);
	PushArrayCell(MonsterMaxRange, 999999.0);
	PushArrayCell(MonsterFollow, -1);
	PushArrayString(MonsterZone, "");
	PushArrayCell(MonsterAttack, 0);

	return monsterCollision;
}

public void OnMonsterBreak(const char [] output, int caller, int activator, float delay)
{
	// Death event
	Handle event = CreateEvent("player_death");
	SetEventInt(event, "userid", -1);
	SetEventInt(event, "attacker", GetClientUserId(activator));
	SetEventInt(event, "assister", -1);
	
	char weapon[64];
	GetClientWeapon(activator, weapon, sizeof(weapon));
	ReplaceString(weapon, sizeof(weapon), "weapon_", "");
	SetEventString(event, "weapon", weapon);
	FireEvent(event);

	Call_StartForward(fOnMonsterBreak);
	Call_PushCell(caller);
	Call_PushCell(activator);
	Call_PushString(weapon);
	Call_Finish();
	
	// Remove monster entities
	int mIndex = FindValueInArray(MonsterCollision, caller);
	RemoveEdict(GetArrayCell(MonsterList, mIndex));
	RemoveEdict(GetArrayCell(MonsterDamageList, mIndex));
	RemoveFromArray(MonsterList, mIndex);
	RemoveFromArray(MonsterCollision, mIndex);
	RemoveFromArray(MonsterDamageList, mIndex);
	ClearArray(TargetList[mIndex]);
	// Move target list down one position in the array (keeps targetlist indexes in line with other lists)
	if (mIndex + 1 < MAX_MONSTERS && TargetList[mIndex + 1] != INVALID_HANDLE)
		for (int i = 0; i < GetArraySize(TargetList[mIndex + 1]); i++)
			PushArrayCell(TargetList[mIndex], GetArrayCell(TargetList[mIndex + 1], i));
	
	RemoveFromArray(MonsterModel, mIndex);
	RemoveFromArray(MonsterHealth, mIndex);
	RemoveFromArray(MonsterDamage, mIndex);
	RemoveFromArray(MonsterDamageRange, mIndex);
	RemoveFromArray(MonsterDamageDelay, mIndex);
	RemoveFromArray(MonsterColor, mIndex);
	RemoveFromArray(MonsterAlpha, mIndex);
	RemoveFromArray(MonsterSpeed, mIndex);
	RemoveFromArray(MonsterScale, mIndex);
	RemoveFromArray(MonsterOffset, mIndex);
	RemoveFromArray(MonsterMinRange, mIndex);
	RemoveFromArray(MonsterMaxRange, mIndex);
	RemoveFromArray(MonsterFollow, mIndex);
	RemoveFromArray(MonsterZone, mIndex);
	RemoveFromArray(MonsterAttack, mIndex);
}

stock bool IsValidClient(int client, bool nobots = false) 
{  
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;  
	}
	return IsClientInGame(client);  
}