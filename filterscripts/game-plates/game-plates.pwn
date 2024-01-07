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
#define YSI_NO_VERSION_CHECK

#define YSI_YES_HEAP_MALLOC

// Coding
#include <YSI_Coding\y_timers>

// Data
#include <YSI_Data\y_iterate>

// Extra
#include <YSI_Extra\y_inline_timers>

// Visual
#include <YSI_Visual\y_commands>

/* Map */
#include <map>

/* Macros */
#define MAX_GAME_PLAYERS                        40
#define MIN_GAME_PLAYERS                        15

#define MAX_GAME_COUNT_PLATES_IN_LINE           20

#define MAX_GAME_INIT_TIME                      ((1000 * 60) * 60)
#define MAX_GAME_RECRUITMENT_TIME               ((1000 * 60) * 10)
#define MAX_GAME_TELEPORT_TIME                  15

#define TIME_UPDATE_PLATES                      (15 * 1000)       
#define TIME_UPDATE_PLATES_COEFFICIENT          375

#define OBJECT_MODELID                          19466
#define OBJECT_SHIFT_X                          1.920
#define OBJECT_SHIFT_Y                          2.230

#define COLOR_WHITE                             0xFFFFFFFF
#define COLOR_WHITE_HEX                         "{FFFFFF}"

#define COLOR_MESSAGE                           0x00CCFFFF
#define COLOR_MESSAGE_HEX                       "{00CCFF}"

/* Enums */
enum E_GAME 
{
    MAPZONE:E_GAME_ZONE,

    Float:E_GAME_POS_X,
    Float:E_GAME_POS_Y,
    Float:E_GAME_POS_Z,

    E_GAME_COUNT_LINE,

    bool:E_GAME_IS_START,

    Timer:E_GAME_RECRUITMENT_TIMER,
    bool:E_GAME_IS_START_RECRUITMENT
};

enum E_PLATE
{
    E_PLATE_OBJECTID,

    Float:E_PLATE_POS_X,
    Float:E_PLATE_POS_Y,
    Float:E_PLATE_POS_Z
};

enum E_GAME_PLAYER
{
    Timer:E_GAME_PLAYER_TIMER,

    Float:E_GAME_PLAYER_POS_X,
    Float:E_GAME_PLAYER_POS_Y,
    Float:E_GAME_PLAYER_POS_Z,
    Float:E_GAME_PLAYER_ANGLE,

    E_GAME_PLAYER_VIRTUAL_WORLD,
    E_GAME_PLAYER_INTERIOR_ID
};

enum 
{
    ENUMATOR_PLATE_UPDATE_STATE_NONE = 0,
    ENUMATOR_PLATE_UPDATE_STATE_MOVE_X,
    ENUMATOR_PLATE_UPDATE_STATE_MOVE_REVERSE_X,
    ENUMATOR_PLATE_UPDATE_STATE_MOVE_Z,
    ENUMATOR_PLATE_UPDATE_STATE_DESTROY,
    ENUMATOR_PLATE_UPDATE_COUNT = ENUMATOR_PLATE_UPDATE_STATE_DESTROY
};

/* Variables */
new g_Game[E_GAME];
new const g_GameDefault[E_GAME] = {
    INVALID_MAPZONE_ID,

    0.0, 0.0, 0.0,
    
    0,
    false, 

    Timer:-1,
    false
};

new g_Plates[MAX_GAME_PLAYERS][MAX_GAME_PLAYERS * MAX_GAME_COUNT_PLATES_IN_LINE][E_PLATE];
new const g_PlateDefault[E_PLATE] = {
    INVALID_OBJECT_ID,

    0.0, 0.0, 0.0
};

new g_PlayerGame[MAX_PLAYERS][E_GAME_PLAYER];
new const g_PlayerGameDefault[E_GAME_PLAYER] = {
    Timer:-1,
    0.0, 0.0, 0.0, 0.0,
    0, 0
};

new Iterator:gI_Members<MAX_GAME_PLAYERS>;

/* Timers */
timer OnGameInit[MAX_GAME_INIT_TIME]()
{
    StartGame(true);
}

timer OnGameRecruitmentStop[MAX_GAME_RECRUITMENT_TIME]()
{
    new count = Iter_Count(gI_Members);

    if(count < MIN_GAME_PLAYERS)
    {
        foreach(new i: gI_Members)
            Iter_Remove(gI_Members, i);
        
        SendClientMessageToAll(COLOR_MESSAGE, "~ [Game Plates]: "#COLOR_WHITE_HEX"Due to insufficient number of players, the game will not run!");

        g_Game = g_GameDefault;

        return true;
    }

    return true;
}

timer OnPlatesUpdate[TIME_UPDATE_PLATES]()
{
    new 
        line = 0,
        lineCount = g_Game[E_GAME_COUNT_LINE];

    new index = 0;

    line = RandomMinMax(0, lineCount),
    index = RandomMinMax(0, MAX_GAME_COUNT_PLATES_IN_LINE);

    new objectid = g_Plates[line][index][E_PLATE_OBJECTID];

    new counter = ENUMATOR_PLATE_UPDATE_STATE_NONE;

    inline Move() 
    {
        counter++;
        
        new Float:x = g_Plates[line][index][E_PLATE_POS_X],
            Float:y = g_Plates[line][index][E_PLATE_POS_Y],
            Float:z = g_Plates[line][index][E_PLATE_POS_Z];

        new Float:rotationX = 0.000;

        new Float:speed = 1.000;

        switch(counter) 
        {
            case ENUMATOR_PLATE_UPDATE_STATE_MOVE_X:
                rotationX = RandomFloatMinMax(2.550, 6.555);

            case ENUMATOR_PLATE_UPDATE_STATE_MOVE_REVERSE_X:
                rotationX = (RandomFloatMinMax(2.550, 6.555) * -1);
            
            case ENUMATOR_PLATE_UPDATE_STATE_MOVE_Z:
            {
                z -= 100.0;
                speed = 0.750;
            }

            case ENUMATOR_PLATE_UPDATE_STATE_DESTROY:
            {
                DestroyObject(objectid);
                g_Plates[line][index] = g_PlateDefault;
                return true;
            }
        }
        MoveObject(objectid, x, y, z, speed, rotationX);
    }
    Timer_CreateCallback(using inline Move, 0, 250, ENUMATOR_PLATE_UPDATE_COUNT);

    defer OnPlatesUpdate[lineCount * TIME_UPDATE_PLATES_COEFFICIENT]();

    return true;
}

timer OnPlayerUpdate[1000](playerid)
{
    new Float:x = 0.0, 
        Float:y = 0.0, 
        Float:z = 0.0;

    GetPlayerPos(playerid, x, y, z);

    if(z < g_Game[E_GAME_POS_Z])
        LostPlayerInGame(playerid);
}

/* Functions */
stock void:CreatePlates()
{
    new 
        line = 0,
        lineCount = g_Game[E_GAME_COUNT_LINE];
    
    while(line < lineCount) 
    {
        for(new index = 0; index != MAX_GAME_COUNT_PLATES_IN_LINE; index++) 
        {    
            if(line == 0 && index == 0) 
            {
                g_Plates[line][index][E_PLATE_POS_X] = g_Game[E_GAME_POS_X];
                g_Plates[line][index][E_PLATE_POS_Y] = g_Game[E_GAME_POS_Y];
                g_Plates[line][index][E_PLATE_POS_Z] = g_Game[E_GAME_POS_Z];

                goto object;
            }

            if(line > 0 && index == 0) 
            {
                g_Plates[line][index][E_PLATE_POS_X] = g_Plates[line - 1][0][E_PLATE_POS_X];
                g_Plates[line][index][E_PLATE_POS_Y] = g_Plates[line - 1][0][E_PLATE_POS_Y] + OBJECT_SHIFT_Y;
                g_Plates[line][index][E_PLATE_POS_Z] = g_Game[E_GAME_POS_Z];

                goto object;
            }
            g_Plates[line][index][E_PLATE_POS_X] = g_Plates[line][index - 1][E_PLATE_POS_X] + OBJECT_SHIFT_X;
            g_Plates[line][index][E_PLATE_POS_Y] = g_Plates[line][index - 1][E_PLATE_POS_Y];
            g_Plates[line][index][E_PLATE_POS_Z] = g_Game[E_GAME_POS_Z];

object:
            g_Plates[line][index][E_PLATE_OBJECTID] = CreateObject(OBJECT_MODELID, g_Plates[line][index][E_PLATE_POS_X], g_Plates[line][index][E_PLATE_POS_Y], g_Plates[line][index][E_PLATE_POS_Z], 0.0, 90.0, 0.0, 1000.0);
        }

        line++;
    }
}

stock void:DestroyPlates()
{
    new 
        line = 0,
        lineCount = g_Game[E_GAME_COUNT_LINE];

    while(line < lineCount) 
    {
        for(new index = 0; index != MAX_GAME_COUNT_PLATES_IN_LINE; index++) 
        {   
            new objectid = g_Plates[line][index][E_PLATE_OBJECTID];

            if(IsValidObject(objectid))
                DestroyObject(objectid);

            g_Plates[line][index] = g_PlateDefault;
        }
        line++;
    }
}

stock void:StartTeleportation(bool:is_preparing = false)
{
    if(is_preparing)
    {
        new counter = MAX_GAME_TELEPORT_TIME;

        inline Start() 
        {
            counter--;

            if(counter <= 0)
            {
                StartTeleportation();
                return;
            }

            foreach(new i: gI_Members)
                GameTextForPlayer(i, "~w~COUNTDOWN: ~r~%d~w~ seconds", 1000, 3, counter);
        }
        Timer_CreateCallback(using inline Start, 0, 1000, MAX_GAME_TELEPORT_TIME);
        return;
    }
    new 
        line = 0,
        lineCount = g_Game[E_GAME_COUNT_LINE];

    new index = 0;

    new Float:x = 0.0, 
        Float:y = 0.0, 
        Float:z = 0.0,
        Float:angle = 0.0;

    foreach(new i: gI_Members) 
    {
        line = RandomMinMax(0, lineCount),
        index = RandomMinMax(0, MAX_GAME_COUNT_PLATES_IN_LINE);

        GetPlayerPos(i, x, y, z);
        GetPlayerFacingAngle(i, angle);

        g_PlayerGame[i][E_GAME_PLAYER_POS_X] = x;
        g_PlayerGame[i][E_GAME_PLAYER_POS_Y] = y;
        g_PlayerGame[i][E_GAME_PLAYER_POS_Z] = z;
        g_PlayerGame[i][E_GAME_PLAYER_ANGLE] = angle;
        g_PlayerGame[i][E_GAME_PLAYER_VIRTUAL_WORLD] = GetPlayerVirtualWorld(i);
        g_PlayerGame[i][E_GAME_PLAYER_INTERIOR_ID] = GetPlayerInterior(i);
    
        g_PlayerGame[i][E_GAME_PLAYER_TIMER] = repeat OnPlayerUpdate(i);

        SetPlayerPos(i,
            g_Plates[line][index][E_PLATE_POS_X],
            g_Plates[line][index][E_PLATE_POS_Y],
            g_Plates[line][index][E_PLATE_POS_Z] + 0.4
        );
    }
    defer OnPlatesUpdate();
}

stock bool:StartGame(bool:is_preparing = false)
{
    if(is_preparing && (!g_Game[E_GAME_IS_START] && !g_Game[E_GAME_IS_START_RECRUITMENT]))
    {
        new string[MAX_MAPZONE_NAME];

        g_Game[E_GAME_POS_X] = RandomFloatMinMax(MIN_MAP_X, MAX_MAP_X);
        g_Game[E_GAME_POS_Y] = RandomFloatMinMax(MIN_MAP_Y, MAX_MAP_Y);
        g_Game[E_GAME_POS_Z] = RandomFloatMinMax(300.000, 400.000);

        g_Game[E_GAME_ZONE] = GetMapZoneAtPoint3D(g_Game[E_GAME_POS_X], g_Game[E_GAME_POS_Y], g_Game[E_GAME_POS_Z]);
        GetMapZoneName(g_Game[E_GAME_ZONE], string);

        SendClientMessageToAll(COLOR_MESSAGE, "~ [Game Plates]: "#COLOR_WHITE_HEX"A new game is being announced!");
        SendClientMessageToAll(COLOR_MESSAGE, "~ [Game Plates]: "#COLOR_WHITE_HEX"The game will take place in the sky! Above the area: \"%s\"!", string);
        SendClientMessageToAll(COLOR_MESSAGE, "~ [Game Plates]: "#COLOR_WHITE_HEX"To participate, use the command /plates.");

        g_Game[E_GAME_IS_START_RECRUITMENT] = true;

        g_Game[E_GAME_RECRUITMENT_TIMER] = defer OnGameRecruitmentStop();

        return true;
    }
    g_Game[E_GAME_IS_START_RECRUITMENT] = false;

    foreach(new i: gI_Members)
    {
        SendClientMessage(i, COLOR_MESSAGE, "~ [Game Plates]: "#COLOR_WHITE_HEX"Members recruitment is complete!");
        SendClientMessage(i, COLOR_MESSAGE, "~ [Game Plates]: "#COLOR_WHITE_HEX"You will be teleported in "#MAX_GAME_TELEPORT_TIME" seconds!");
    }
    CreatePlates();
    
    StartTeleportation(true);

    g_Game[E_GAME_IS_START] = true;

    return true;
}

stock void:PlayerTeleportation(playerid)
{
    SetPlayerPos(playerid,
        g_PlayerGame[playerid][E_GAME_PLAYER_POS_X],
        g_PlayerGame[playerid][E_GAME_PLAYER_POS_Y],
        g_PlayerGame[playerid][E_GAME_PLAYER_POS_Z]
    );
    SetPlayerFacingAngle(playerid, g_PlayerGame[playerid][E_GAME_PLAYER_ANGLE]);

    SetPlayerVirtualWorld(playerid, g_PlayerGame[playerid][E_GAME_PLAYER_VIRTUAL_WORLD]);
    SetPlayerInterior(playerid, g_PlayerGame[playerid][E_GAME_PLAYER_INTERIOR_ID]);
}

stock void:LostPlayerInGame(playerid, bool:is_player_disconnect = false)
{
    if(!Iter_Contains(gI_Members, playerid))
        return;

    if(g_PlayerGame[playerid][E_GAME_PLAYER_TIMER] != Timer:-1)
        stop g_PlayerGame[playerid][E_GAME_PLAYER_TIMER];

    Iter_Remove(gI_Members, playerid);

    if(!is_player_disconnect)
        PlayerTeleportation(playerid);

    g_PlayerGame[playerid] = g_PlayerGameDefault;

    if(Iter_Count(gI_Members) <= 1)
    {
        new winnerid = Iter_Last(gI_Members);
        Iter_Remove(gI_Members, winnerid);

        if(!IsPlayerConnected(winnerid))
            return;

        if(g_PlayerGame[winnerid][E_GAME_PLAYER_TIMER] != Timer:-1)
            stop g_PlayerGame[winnerid][E_GAME_PLAYER_TIMER];

        SendClientMessage(winnerid, COLOR_MESSAGE, "~ [Game Plates]: "#COLOR_WHITE_HEX"Congratulations, you have won the game!");

        PlayerTeleportation(winnerid);

        DestroyPlates();

        g_PlayerGame[winnerid] = g_PlayerGameDefault;

        g_Game = g_GameDefault;
    }
    else
        g_Game[E_GAME_COUNT_LINE]--;
}

/* Commands */
YCMD:plates(playerid, params[], help) 
{
    if(g_Game[E_GAME_IS_START])
        return SendClientMessage(playerid, COLOR_MESSAGE, "~ [Game Plates]: "#COLOR_WHITE_HEX"Game is now runned!");

    if(!g_Game[E_GAME_IS_START_RECRUITMENT])
        return SendClientMessage(playerid, COLOR_MESSAGE, "~ [Game Plates]: "#COLOR_WHITE_HEX"Recruiting for the game is now closed!");

    if(Iter_Contains(gI_Members, playerid))
        return SendClientMessage(playerid, COLOR_MESSAGE, "~ [Game Plates]: "#COLOR_WHITE_HEX"You're already a member!");

    new index = Iter_Free(gI_Members);

    if(index == INVALID_ITERATOR_SLOT)
        return SendClientMessage(playerid, COLOR_MESSAGE, "~ [Game Plates]: "#COLOR_WHITE_HEX"The maximum number of participants has already been recruited!");

    SendClientMessage(playerid, COLOR_MESSAGE, "~ [Game Plates]: "#COLOR_WHITE_HEX"You have successfully signed up for the game, expect it to start!");

    Iter_Add(gI_Members, playerid);

    new count = Iter_Count(gI_Members);
    if(count >= 1)
    {
        stop g_Game[E_GAME_RECRUITMENT_TIMER];

        g_Game[E_GAME_COUNT_LINE] = count;

        StartGame();
    }
    
    return true;
}

/* Callbacks */
public OnPlayerCommandText(playerid, cmdtext[]) 
{
}

public OnPlayerDeath(playerid, killerid, WEAPON:reason)
{
    LostPlayerInGame(playerid);
}

public OnPlayerSpawn(playerid)
{
    LostPlayerInGame(playerid);
}

public OnPlayerDisconnect(playerid, reason)
{
    LostPlayerInGame(playerid, true);
}

public OnFilterScriptInit()
{
    defer OnGameInit();
}