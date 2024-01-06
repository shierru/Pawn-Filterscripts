/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * The original code is copyright (c) 2024, shierru (Nikita).
*/
#define STRONG_TAGS
#include <open.mp>

/* YSI */
#define YSI_NO_HEAP_MALLOC

// Coding
#include <YSI_Coding\y_timers>

// Data
#include <YSI_Data\y_iterate>

/* MapAndreas */
#include <mapandreas>

/* Macros */
#define GRAVITY_DEFAULT                 0.008
#define GRAVITY_JUMP                    0.004

#define VEHICLE_MODEL                   411
#define VEHICLE_OBJECT_MODELID          18849

#define INACCURACY_VALUE                1.000
#define VELOCITY_VALUE                  RandomFloat(0.400, 0.750)

#define TIMER_INTERVAL                  500                    

/* Variables */
new Float:g_Gravity = 0.0;

// Vehicle
new Timer:g_VehicleTimer[MAX_VEHICLES] = {Timer:-1, ...};

new g_VehicleObjectID[MAX_VEHICLES] = {INVALID_OBJECT_ID, ...};

/* Functions */
stock Float:GetVehicleSpeed(const vehicleid)
{
    if(!IsValidVehicle(vehicleid))
        return 0.0;

    new Float:velocityX = 0.0, 
        Float:velocityY = 0.0, 
        Float:velocityZ = 0.0;

    new Float:velocitySqroot = 0.0;
        
    GetVehicleVelocity(vehicleid, velocityX, velocityY, velocityZ);
    
    velocitySqroot = floatsqroot((velocityX * velocityX) + (velocityY * velocityY) + (velocityZ * velocityZ));

    return floatround(velocitySqroot * 100);
}

stock void:VehicleObject(const vehicleid)
{    
    if(!IsValidVehicle(vehicleid))
        return;

    g_VehicleObjectID[vehicleid] = CreateObject(VEHICLE_OBJECT_MODELID, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    SetObjectMaterial(g_VehicleObjectID[vehicleid], 2, 0, "none", "none", 0x00000000);

    AttachObjectToVehicle(g_VehicleObjectID[vehicleid], vehicleid, 0.0, 0.0, 6.62000, 0.0, 0.0, 0.0);
}

stock void:VehicleObjectDestroy(const vehicleid)
{
    if(!IsValidObject(g_VehicleObjectID[vehicleid]))
        return;
    
    DestroyObject(g_VehicleObjectID[vehicleid]);
    g_VehicleObjectID[vehicleid] = INVALID_OBJECT_ID;
}

stock void:VehicleTimerStop(const vehicleid)
{
    if(g_VehicleTimer[vehicleid] == Timer:-1)
        return;

    stop g_VehicleTimer[vehicleid];
    g_VehicleTimer[vehicleid] = Timer:-1;        
}

stock bool:VehicleJump(const vehicleid)
{   
    if(!IsValidVehicle(vehicleid))
        return false;

    new Float:speed = (GetVehicleSpeed(vehicleid) + 25);

    new Float:posX = 0.0, 
        Float:posY = 0.0, 
        Float:posZ = 0.0, 
        Float:angle = 0.0;

    new Float:velocityX = 0.0, 
        Float:velocityY = 0.0,
        Float:velocityZ = 0.0;

    GetVehiclePos(vehicleid, posX, posY, posZ);
    GetVehicleZAngle(vehicleid, angle);

    GetVehicleVelocity(vehicleid, velocityX, velocityY, velocityZ);
    
    angle = 360 - angle;

    new Float:sine = floatsin(angle, degrees),
        Float:cosine = floatcos(angle, degrees);

    velocityX = ((sine * (speed / 100)) + ((cosine * 0) + posX)) - posX;
    velocityY = ((cosine * (speed / 100)) + ((sine * 0) + posY)) - posY;
    
    return SetVehicleVelocity(vehicleid, velocityX, velocityY, VELOCITY_VALUE);
}

/* Callbacks */
timer CheckLandingTimer[TIMER_INTERVAL](vehicleid)
{
    new Float:posX = 0.0, 
        Float:posY = 0.0, 
        Float:posZ = 0.0;

    new Float:averageZ = 0.0;

    GetVehiclePos(vehicleid, posX, posY, posZ);

    MapAndreas_FindAverageZ(posX, posY, averageZ);

    if((posZ - averageZ) < INACCURACY_VALUE)
    {
        foreach(new i: Player)
        {
            if(GetPlayerVehicleID(i) != vehicleid)
                continue;

            if(GetPlayerState(i) != PLAYER_STATE_DRIVER)
                continue;

            SetPlayerGravity(i, g_Gravity);

            break;
        }
        VehicleObjectDestroy(vehicleid);

        VehicleTimerStop(vehicleid);
    }
}

public OnFilterScriptInit()
{
    g_Gravity = GetConsoleVarAsFloat("game.gravity");

    if(!g_Gravity)
        g_Gravity = GRAVITY_DEFAULT;

    MapAndreas_Init(MAP_ANDREAS_MODE_FULL);
}

public OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    new PLAYER_STATE:player_state = GetPlayerState(playerid);

    if(player_state != PLAYER_STATE_DRIVER)
        return true;

    new vehicleid = GetPlayerVehicleID(playerid);

    if(!IsValidVehicle(vehicleid))
        return true;

    new modelid = GetVehicleModel(vehicleid);

    if(modelid != VEHICLE_MODEL)
        return true;

    if(newkeys != KEY_CROUCH)
        return true;

    if(g_VehicleTimer[vehicleid] != Timer:-1 && g_VehicleObjectID[vehicleid] != INVALID_OBJECT_ID)
        return true;
    
    VehicleObject(vehicleid);

    new bool:ret = VehicleJump(vehicleid);
    if(ret)
    {
        SetPlayerGravity(playerid, GRAVITY_JUMP);

        g_VehicleTimer[vehicleid] = repeat CheckLandingTimer(vehicleid);
    }

    return true;
}

public OnVehicleDeath(vehicleid, killerid)
{
    VehicleObjectDestroy(vehicleid);   
        
    VehicleTimerStop(vehicleid);

    return true;
}

public OnVehicleSpawn(vehicleid)
{
    VehicleObjectDestroy(vehicleid);   
        
    VehicleTimerStop(vehicleid);

    return true;
}
