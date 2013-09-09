/*
** Copyright (c) 2013, Cthulhu / Cthulhu@GBITnet.com.br
** All rights reserved.
**
** Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are met:
**
** 1. Redistributions of source code must retain the above copyright notice, this
**    list of conditions and the following disclaimer.
** 2. Redistributions in binary form must reproduce the above copyright notice,
**    this list of conditions and the following disclaimer in the documentation
**    and/or other materials provided with the distribution.
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
** ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
** WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
** DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
** ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
** (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
** LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
** ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
** SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

class DMFFAGRI extends AOCFFAGRI;

`include(DuelMod/Include/DuelMod.uci)

struct DuelLeaderInfo
{

    var int DuelTeamID;
    var DMFFAPRI PRI;

};

// Objective Info.

simulated function float RetrieveObjectiveCompletionPercentage()
{

    return 0.f;

}

simulated function string RetrieveObjectiveName(EAOCFaction Faction)
{

    return "FFA Duel Mode";

}

simulated function string RetrieveObjectiveDescription(EAOCFaction Faction)
{

    return "Use BATTLECRY to challenge a player to a duel";

}

simulated function string RetrieveObjectiveStatusText(EAOCFaction Faction)
{

    // Display 
    // - Name of person with highest score: Highest Score (if available)
    // - Team Score: Team Highest Score (if available)
    // - Your Score: Local player score

    local DMFFAPlayerController PC;
    local DMFFAPRI MyPRI, PRI, LeaderPRI, MaxPRI;
    local PlayerReplicationInfo Inf;
    local DuelLeaderInfo DuelLeader;
    local array<DuelLeaderInfo> DuelLeaders;
    local array<DMFFAPRI> DuelPlayers;
    local int PlayerScore, MaxScore, MaxTeamScore, MyScore;
    local string MaxScoreName;
    local string Text;

    PC = DMFFAPlayerController(GetALocalPlayerController());

    if (PC == none)
        return "";

    MyPRI = DMFFAPRI(PC.PlayerReplicationInfo);

    // Separate players from leaders first.

    foreach PRIArray(Inf)
    {

        PRI = DMFFAPRI(Inf);

        if (PRI.IsDuelLeader)
        {

            DuelLeader.DuelTeamID = PRI.DuelTeamID;
            DuelLeader.PRI = PRI;
            DuelLeaders.AddItem(DuelLeader);

        }

        else
            DuelPlayers.AddItem(PRI);

    }

    // Process leaders first.

    MaxScore = 0;
    MaxTeamScore = 0;

    foreach DuelLeaders(DuelLeader)
    {

        PlayerScore = Round(DuelLeader.PRI.Score);

        if (PlayerScore > MaxScore)
        {

            MaxScore = PlayerScore;
            MaxPRI = DuelLeader.PRI;

        }

        if (DuelLeader.DuelTeamID != NO_DUEL_TEAM_ID && DuelLeader.DuelTeamID == MyPRI.DuelTeamID) // Get highest score within the team.
        {

            if (PlayerScore > MaxTeamScore)
                MaxTeamScore = PlayerScore;

        }

    }

    // Now process regular players.

    foreach DuelPlayers(PRI)
    {

        PlayerScore = Round(PRI.Score);

        if (PlayerScore > MaxScore)
        {

            MaxScore = PlayerScore;
            MaxPRI = PRI;

        }

        if (PRI.DuelTeamID == MyPRI.DuelTeamID) // Get highest score within the team.
        {

            if (PlayerScore > MaxTeamScore)
                MaxTeamScore = PlayerScore;

        }

    }

    // Set the player/team name with the highest score. Search for a leader if necessary.

    if (MaxScore > 0)
    {

        if (!MaxPRI.IsDuelLeader)
            LeaderPRI = DuelLeaders[DuelLeaders.Find('DuelTeamID', MaxPRI.DuelTeamID)].PRI;

        else
            LeaderPRI = MaxPRI;

        MaxScoreName = LeaderPRI.GetPlayerNameForMarkup();

        if (LeaderPRI.DuelTeamSize > 1)
            MaxScoreName $= "'s team";

        Text = MaxScoreName$":"@MaxScore$"\n";

    }

    else
        Text = "";

    if (MaxTeamScore > 0)
        Text $= "Team Score:"@MaxTeamScore$"\n";

    MyScore = Round(MyPRI.Score);
    Text $= "Your Score:"@MyScore;

    return Text;

}