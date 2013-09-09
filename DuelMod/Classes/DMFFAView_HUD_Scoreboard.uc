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

class DMFFAView_HUD_Scoreboard extends AOCView_HUD_Scoreboard;

`include (DuelMod/Include/DuelMod.uci)

struct DuelTeamHighlight
{

    var string Leader;
    var string Player;

};

var DuelTeamHighlight SelfTeamHighlight;
var DuelTeamHighlight OtherTeamHighlight;

function SetPlayerNameOnScoreboard(DMFFAPRI PlayerPRI, GFxObject PlayerObj, optional bool IsSelectedPlayer = false)
{

    local DMFFAPRI MyPRI;
    local string PlayerHighlight;
    local DuelTeamHighlight DuelTeamHighlights;

    if (Manager == none || Manager.PlayerOwner == none)
        return;

    MyPRI = DMFFAPRI(Manager.PlayerOwner.PlayerReplicationInfo);

    if (MyPRI == none)
        return;

    if (IsSelectedPlayer)
    {

        PlayerHighlight = (PlayerPRI == MyPRI) ? SelfHighlight : OtherHighlight;
        PlayerObj.SetString("this_name", "<font color=\""$PlayerHighlight$"\">"$PlayerPRI.GetPlayerNameForMarkup()$"</font>");

    }

    else if (PlayerPRI.DuelTeamID != NO_DUEL_TEAM_ID)
    {

        DuelTeamHighlights = (PlayerPRI.DuelTeamID == MyPRI.DuelTeamID) ? SelfTeamHighlight : OtherTeamHighlight;
        PlayerHighlight = (PlayerPRI.IsDuelLeader) ? DuelTeamHighlights.Leader : DuelTeamHighlights.Player;
        PlayerObj.SetString("this_name", "<font color=\""$PlayerHighlight$"\">"$PlayerPRI.GetPlayerNameForMarkup()$"</font>");

    }

    else
        PlayerObj.SetString("this_name", PlayerPRI.GetPlayerNameForMarkup());

}

/* Overriden methods. */

function HandleLocalization(name WidgetName, GFxObject Widget)
{

    switch(WidgetName)
    {

        case('LocationText'):
        case('LastObjectiveText'):
        case('NextObjectiveText'):
        case('CurrentObjectiveText'):
        case('ObjectiveStatusText'):
        case('OverallProgressText'):
        case('ScoreText'):
        case('KillsText'):
        case('DeathsText'):
        case('AssistText'):
        case('KDRatioText'):
        case('AccuracyText'):
        case('DamageDealtText'):
        case('DamageTakenText'):
        case('presstoenablemouselabel'):

            Widget.SetText(Localize("Scoreboard", string(WidgetName), "AOCUI"));
            break;

        case('AgathaKnights'):

            Widget.SetText("Not Dueling");
            break;

        case('MasonOrder'):

            Widget.SetText("Dueling");
            break;

        case('ObjectivesPointsText'):

            Widget.SetText("Team Size");
            break;

        case('NameText1'):
        case('NameText2'):

            Widget.SetText(Localize("Scoreboard", "Name", "AOCUI"));
            break;

        case('ClassText1'):
        case('ClassText2'):

            Widget.SetText(Localize("Scoreboard", "Class", "AOCUI"));
            break;

        case('ScoreText1'):
        case('ScoreText2'):

            Widget.SetText(Localize("Scoreboard", "Score", "AOCUI"));
            break;

        case('PingText1'):
        case('PingText2'):

            Widget.SetText(Localize("Scoreboard", "Ping", "AOCUI"));
            break;

        case('StatusText1'):
        case('StatusText2'):

            Widget.SetText(Localize("Scoreboard", "Status", "AOCUI"));
            break;

        case('RankText1'):
        case('RankText2'):

            Widget.SetText(Localize("Scoreboard", "Rank", "AOCUI"));
            break;

    }

}

function HandleClickNameOnList(GFxClikWidget.EventData Params)
{

    local DMFFAPlayerController PC;
    local DMFFAHUD MyHUD;
    local int i;
    local PlayerReplicationInfo TmpPRI;
    local DMFFAPRI CastedPRI;

    PC = DMFFAPlayerController(Manager.PlayerOwner);

    if (PC == none)
        return;

    MyHUD = DMFFAHUD(PC.myHUD);

    if (MyHUD == none)
        return;

    i = 0;

    switch (Params.target.GetString("_name"))
    {

        case "agatha_list":

            SelectedOverrideMason = INDEX_NONE;
            SelectedOverrideAgatha = Clamp(Params.index, 0, AgathaPlayerCount-1);

            foreach MyHUD.AllPRI(TmpPRI)
            {

                CastedPRI = DMFFAPRI(TmpPRI);

                if (CastedPRI != none)
                {

                    if (!CastedPRI.DuelStatus)
                    {

                        if (SelectedOverrideAgatha == i)
                        {

                            MyHUD.SelectedPRI = TmpPRI;
                            break;

                        }

                        i++;

                    }

                }

            }

            break;

        case "mason_list":

            SelectedOverrideAgatha = INDEX_NONE;
            SelectedOverrideMason = Clamp(Params.index, 0, MasonPlayerCount-1);

            foreach MyHUD.AllPRI(TmpPRI)
            {

                CastedPRI = DMFFAPRI(TmpPRI);

                if (CastedPRI != none)
                {

                    if (CastedPRI.DuelStatus)
                    {

                        if (SelectedOverrideMason == i)
                        {

                            MyHUD.SelectedPRI = TmpPRI;
                            break;

                        }

                        i++;

                    }

                }

            }

            break;

    }

    // We have extra player options tab open -- set mute texts as necessary.
    if (PC.AllMutePlayerList.Find('Uid', MyHUD.SelectedPRI.UniqueId.Uid) != INDEX_NONE)
        MuteButton.SetString("label", Localize("Scoreboard", "UnMute", "AOCUI"));

    else
        MuteButton.SetString("label", Localize("Scoreboard", "Mute", "AOCUI"));

    if (DMFFAPRI(MyHUD.SelectedPRI).bIsAdminMuted)
        AdminMuteButton.SetString("label", Localize("Scoreboard", "AdminUnMute", "AOCUI"));

    else
        AdminMuteButton.SetString("label", Localize("Scoreboard", "AdminMute", "AOCUI"));

}
   
// Initialize Values.
function GrabCurrentUpdatedValues(optional bool bInitialView = true)
{

    local DMFFAPlayerController PC;
    local DMFFAHUD MyHUD;
    local DMFFAPRI MyPRI, PlayerPRI, SelectedPRI;
    local int AgathaPlayerScore, MasonPlayerScore;
    local array<int> AgathaDuelTeams, MasonDuelTeams;
    local GFxObject AgathaDataProvider, MasonDataProvider;
    local PlayerReplicationInfo TmpPRI;
    local GFxObject PlayerObj;
    local DMFFAGRI CurGRI;

    PC = DMFFAPlayerController(Manager.PlayerOwner);

    if (PC == none)
        return;

    MyHUD = DMFFAHUD(PC.myHUD);

    if (MyHUD == none)
        return;

    MyPRI = DMFFAPRI(PC.PlayerReplicationInfo);

    if (MyPRI == none)
        return;

    MyHUD.AllPRI = PC.WorldInfo.GRI.PRIArray;

    if (PC.WorldInfo.NetMode != NM_Standalone)
        ServerName.SetText(PC.WorldInfo.GRI.ServerName);

    else
        ServerName.SetText(PC.GetURLMap());

    if (bInitialView)
        PC.ClientRequestSyncTimer();

    // Update Timer - Grab Time From PlayerController.
    PC.ForceUpdateTimerToHUD();

    AgathaPlayerCount = 0;
    AgathaPlayerScore = 0;
    MasonPlayerCount = 0;
    MasonPlayerScore = 0;

    // Grab Team Count and Team Scores by going through all the PRIs.
    // Also grab player name, score, class, ping while we're at it.

    AgathaDataProvider = Outer.CreateArray();
    MasonDataProvider = Outer.CreateArray();

    // Sort our copy of AllPRI based on player's score.
    MyHUD.AllPRI.Sort(PRISort);

    foreach MyHUD.AllPRI(TmpPRI)
    {

        PlayerPRI = DMFFAPRI(TmpPRI);

        if (PlayerPRI == none)
            continue;

        if (PlayerPRI.bOnlySpectator || !PlayerPRI.bDisplayOnScoreboard || PlayerPRI.ToBeClass.default.FamilyFaction == EFAC_NONE)
            continue;

        PlayerObj = CreateObject("Object");

        if (PlayerPRI.CurrentHealth <= 0)
            PlayerObj.SetString("doa", "D");

        else
            PlayerObj.SetString("doa", "");

        if (PlayerPRI.IsDuelLeader && PlayerPRI.DuelTeamSize > 1)
            PlayerObj.SetString("this_class", "R"); // King icon for duel team leader.

        else
        {

            switch (PlayerPRI.ToBeClass.default.ClassReference)
            {

                case ECLASS_Archer:

                    PlayerObj.SetString("this_class", "A");
                    break;

                case ECLASS_Knight:

                    PlayerObj.SetString("this_class", "K");
                    break;

                case ECLASS_ManAtArms:

                    PlayerObj.SetString("this_class", "M");
                    break;

                case ECLASS_Vanguard:

                    PlayerObj.SetString("this_class", "V");
                    break;

                case ECLASS_King:

                    PlayerObj.SetString("this_class", "R");
                    break;

                default:
                    break;

            }

        }

        PlayerObj.SetString("rank", string(PlayerPRI.MyRank));

        if (PlayerPRI == MyPRI || PC.AllMutePlayerList.Find('Uid', PlayerPRI.UniqueId.Uid) == INDEX_NONE)
            PlayerObj.SetString("mute", "O");

        else
            PlayerObj.SetString("mute", "P");

        PlayerObj.SetString("score", string(Round(PlayerPRI.Score)));
        PlayerObj.SetString("kill", string(PlayerPRI.NumKills));
        PlayerObj.SetString("death", string(PlayerPRI.Deaths));
        PlayerObj.SetString("ping", string(Round(PlayerPRI.Ping * 4.f)));

        if (!PlayerPRI.DuelStatus)
        {

            if (TmpPRI == MyHUD.SelectedPRI)
            {

                SelectedPRI = PlayerPRI;
                SetPlayerNameOnScoreboard(PlayerPRI, PlayerObj, true);

                // Select.
                AgathaList.SetFloat("selectedIndex", AgathaPlayerCount);
                MasonList.SetFloat("selectedIndex", INDEX_NONE);

            }

            else
                SetPlayerNameOnScoreboard(PlayerPRI, PlayerObj);

            AgathaDataProvider.SetElementObject(AgathaPlayerCount++, PlayerObj);

            if (PlayerPRI.DuelTeamID == NO_DUEL_TEAM_ID) // Players with no team adds +1 to duel team count.
                AgathaPlayerScore++;

            else if (AgathaDuelTeams.Find(PlayerPRI.DuelTeamID) == INDEX_NONE)
                AgathaDuelTeams.AddItem(PlayerPRI.DuelTeamID); // Add every unique duel team ID.

        }

        else
        {

            if (TmpPRI == MyHUD.SelectedPRI)
            {

                SelectedPRI = PlayerPRI;
                SetPlayerNameOnScoreboard(PlayerPRI, PlayerObj, true);

                // Select.
                AgathaList.SetFloat("selectedIndex", INDEX_NONE);
                MasonList.SetFloat("selectedIndex", MasonPlayerCount);

            }

            else
                SetPlayerNameOnScoreboard(PlayerPRI, PlayerObj);

            MasonDataProvider.SetElementObject(MasonPlayerCount++, PlayerObj);

            if (PlayerPRI.DuelTeamID == NO_DUEL_TEAM_ID) // Players with no team adds +1 to duel team count.
                MasonPlayerScore++;

            else if (MasonDuelTeams.Find(PlayerPRI.DuelTeamID) == INDEX_NONE)
                MasonDuelTeams.AddItem(PlayerPRI.DuelTeamID); // Add every unique duel team ID.


        }

    }

    AgathaCount.SetText(Repl(Localize("Common", "NumPlayers", "AOCUI"), "{NUM}", string(AgathaPlayerCount), false));
    AgathaScore.SetText(string(AgathaPlayerScore + AgathaDuelTeams.Length));
    MasonCount.SetText(Repl(Localize("Common", "NumPlayers", "AOCUI"), "{NUM}", string(MasonPlayerCount), false));
    MasonScore.SetText(string(MasonPlayerScore + MasonDuelTeams.Length));
    AgathaList.SetObject("dataProvider", AgathaDataProvider);
    MasonList.SetObject("dataProvider", MasonDataProvider);

    // Get Individual Player Stats.

    PlayerTeamImage.SetString("source", "");
    PlayerName.SetText(SelectedPRI.PlayerName);
    PlayerScore.SetText(string(Round(SelectedPRI.Score)));
    PlayerKills.SetText(string(SelectedPRI.NumKills));
    PlayerAssists.SetText(string(SelectedPRI.NumAssists));
    PlayerDeaths.SetText(string(SelectedPRI.Deaths));
    PlayerObjScore.SetText(string(SelectedPRI.DuelTeamSize));

    if (SelectedPRI.NumAttacks > 0)
        PlayerAcc.SetText(string((SelectedPRI.NumHits * 100.f) / SelectedPRI.NumAttacks));

    else
        PlayerAcc.SetText("INF");

    if (SelectedPRI.Deaths > 0)
        PlayerKdRatio.SetText(string(float(SelectedPRI.NumKills)/SelectedPRI.Deaths));

    else
        PlayerKdRatio.SetText("INF");

    PlayerDamageDealt.SetText(string(SelectedPRI.EnemyDamageDealt + SelectedPRI.TeamDamageDealt));
    PlayerDamageTaken.SetText(string(SelectedPRI.DamageTaken));

    // Get Current Objective Information.

    CurGRI = DMFFAGRI(PC.WorldInfo.GRI);
    GeneralLastObj.SetVisible(false);
    GeneralNextObj.SetVisible(false);
    CurObjImg.SetString("source", CurGRI.RetrieveObjectiveImg(EFAC_FFA));
    CurrentTaskName.SetText(CurGRI.RetrieveObjectiveName(EFAC_FFA));
    CurObjName.SetText(CurGRI.RetrieveObjectiveName(EFAC_FFA));
    CurrentObjDescription.SetText(CurGRI.RetrieveObjectiveDescription(EFAC_FFA));
    CurrentObjStatusBar.SetFloat("value", CurGRI.RetrieveObjectiveCompletionPercentage());
    CurrentObjStatusText.SetString("htmlText", CurGRI.RetrieveObjectiveStatusText(EFAC_FFA));
    
}

DefaultProperties
{

    SelfTeamHighlight = (Leader = "#0000FF", Player = "#00FFFF") // Same team highlights.
    OtherTeamHighlight = (Leader = "#006600", Player = "#00FF99") // Not in same team highlights.

}