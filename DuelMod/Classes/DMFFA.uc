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

class DMFFA extends AOCFFA;

`include(DuelMod/Include/DuelMod.uci)

/** Server operator customizable parameters **/
var globalconfig byte PrivateDuels;
var globalconfig bool bAllowTeamDuels;
var globalconfig int iMaxTeamSize;
var globalconfig bool bOnlySameTeamSizeDuels;
var globalconfig float fChallengeTimeout;
var globalconfig bool bMapVoteOnlyFromList;
/*********************/

var protected int NextReality;
var protected int DuelTeamID;
var protected string WinString;
var protectedwrite SoundCue DuelWinSound[2];

function int GetNextReality()
{

    return ((PrivateDuels == PRIVATE_DUEL_RESERVED) ? NextReality++ : NextReality);

}

function int GetNextDuelTeamID()
{

    return DuelTeamID++;

}

function BroadcastDuelMessageToPlayer(DMFFAPlayerController Target, string Message, optional string MessageColor = "#00FF00")
{

    Target.ReceiveChatMessage("", Message, Target.CurrentFamilyInfo.default.FamilyFaction, false, (MessageColor != ""), MessageColor);

}

function BroadcastMessageToDuelTeam(DMFFAPlayerController DuelTeamLeader, string Message)
{

    local DMFFAPlayerController PC;

    foreach DuelTeamLeader.DuelInfo.Team(PC)
    {

        BroadcastDuelMessageToPlayer(PC, Message);

    }

}

protected function IncreaseScoreForDuelTeam(DMFFAPlayerController DuelTeamLeader) // Called for every duel win.
{

    local DMFFAPlayerController PC;
    local int PlayerScore, TeamHighestScore;
    local PlayerReplicationInfo LeaderPRI;

    DuelTeamLeader.PlayerReplicationInfo.Score += 1.f;
    TeamHighestScore = Round(DuelTeamLeader.PlayerReplicationInfo.Score);
    DuelTeamLeader.PlayerReplicationInfo.bForceNetUpdate = true;

    foreach DuelTeamLeader.DuelInfo.Team(PC)
    {

        PC.PlayerReplicationInfo.Score += 1.f;
        PlayerScore = Round(PC.PlayerReplicationInfo.Score);

        if (PlayerScore > TeamHighestScore)
            TeamHighestScore = PlayerScore;

        PC.PlayerReplicationInfo.bForceNetUpdate = true;

    }

    if (TeamHighestScore > CurHighestScore) // Update highest score for the game.
    {

        CurHighestScore = TeamHighestScore;
        LeaderPRI = DuelTeamLeader.PlayerReplicationInfo;

        if (PrevHigh == none || PrevHigh != LeaderPRI)
        {

            PrevHigh = LeaderPRI;
            BroadcastSystemMessage(4, class'AOCSystemMessages'.static.CreateLocalizationdata("INVALIDDATA", DuelTeamLeader.GetDuelTeamName(), ""),,EFAC_ALL);

        }

        // Check score to see if player/team has won.
        if (GoalScore > 0 && TeamHighestScore >= GoalScore)
            InitEndGame(DuelTeamLeader);

    }

}

/* Duels. */

function ResetDuel(DMFFAPlayerController DuelTeamLeader)
{

    local DMFFAPlayerController PC;

    foreach DuelTeamLeader.DuelInfo.Team(PC)
    {

        PC.ResetDuelInfo();
        PC.SetTeamForDuel(EFAC_FFA);
        PC.SwitchDuelTeamToAgatha();

        if (DMFFAPawn(PC.Pawn) != none && PC.Pawn.IsAliveAndWell())
        {

            if (PC.RealityID > DEFAULT_REALITY)
                PC.SetReality(DEFAULT_REALITY); // Set reality back to default.

            LoadoutChangeSpawnPlayer(PC); // Generate a new pawn.

        }

        PC.SetTrappedBetweenRealities(false);
        PC.AllowedToSpawn = true;

    }

    DuelTeamLeader.ResetDuelInfo();
    DuelTeamLeader.SetTeamForDuel(EFAC_FFA);
    DuelTeamLeader.SwitchDuelTeamToAgatha();

    if (DMFFAPawn(DuelTeamLeader.Pawn) != none && DuelTeamLeader.Pawn.IsAliveAndWell())
    {

        if (DuelTeamLeader.RealityID > DEFAULT_REALITY)
            DuelteamLeader.SetReality(DEFAULT_REALITY); // Set reality back to default.

        LoadoutChangeSpawnPlayer(DuelTeamLeader); // Generate a new pawn.

    }

    DuelTeamLeader.SetTrappedBetweenRealities(false);
    DuelTeamLeader.AllowedToSpawn = true;

}

function SetDuel(DMFFAPawn Requester)
{

    local DMFFAPlayerController RequesterPC, ChallengePC;
    local int TeamForDuel;
    local int DuelReality;
    local float ctime;

    if (Requester == none)
        return;

    if (!bGameStarted || bGameEnded) // No new duels after a player reaches GoalScore.
        return;

    RequesterPC = DMFFAPlayerController(Requester.Controller);

    if (RequesterPC == none)
        return;

    if (RequesterPC.DuelInfo.Leader != none) // Only the team leader can challenge.
        return;

    if (RequesterPC.DuelInfo.status) // No challenges inside a duel.
        return;

    ChallengePC = RequesterPC.GetTargetPlayerController();

    if (ChallengePC == none)
        return;

    if (ChallengePC.DuelInfo.Leader != none) // Can only challenge team leaders.
        return;

    if (ChallengePC.DuelInfo.status) // Can only challenge players not dueling.
        return;

    if (RequesterPC.DuelInfo.Challenge == none || RequesterPC.DuelInfo.Challenge != ChallengePC) // New challenge.
    {

        if (ChallengePC.DuelInfo.Challenge == RequesterPC) // Both players point to each other. Begin Duel.
        {

            if (bOnlySameTeamSizeDuels && RequesterPC.DuelInfo.Team.Length != ChallengePC.DuelInfo.Team.Length)
            {

                BroadcastDuelMessageToPlayer(RequesterPC, "You cannot accept"@ChallengePC.GetDuelTeamName(true)@"challenge. Team size differs.");
                return;

            }

            if (!RequesterPC.IsDuelLeaderAlive() || !RequesterPC.IsDuelTeamAlive())
            {

                BroadcastDuelMessageToPlayer(RequesterPC, "Your team is not yet ready to duel.");
                return;

            }

            else if (!ChallengePC.IsDuelLeaderAlive() || !ChallengePC.IsDuelTeamAlive())
            {

                BroadcastDuelMessageToPlayer(RequesterPC, ChallengePC.GetDuelTeamName()@"is not yet ready to duel.");
                return;

            }

            BroadcastDuelMessageToPlayer(RequesterPC, "You've accepted"@ChallengePC.GetDuelTeamName(true)@"challenge!");
            BroadcastDuelMessageToPlayer(ChallengePC, RequesterPC.GetDuelTeamName()@"has accepted your challenge.");
            BroadcastMessageToDuelTeam(RequesterPC, RequesterPC.GetDuelTeamName()@"has accepted"@ChallengePC.GetDuelTeamName(true)@"challenge.");
            BroadcastMessageToDuelTeam(ChallengePC, RequesterPC.GetDuelTeamName()@"has accepted"@ChallengePC.GetDuelTeamName(true)@"challenge.");
            RequesterPC.SetInitialParametersForDuel();
            ChallengePC.SetInitialParametersForDuel();

            // Clear challenges from other players.
            RequesterPC.ClearAllDuelChallenges();
            ChallengePC.ClearAllDuelChallenges();
            RequesterPC.DuelInfo.Challenge = ChallengePC;
            ChallengePC.DuelInfo.Challenge = RequesterPC;

            if (RequesterPC.HasDuelTeam() || ChallengePC.HasDuelTeam()) // In a team duel, one team must go Mason.
            {

                TeamForDuel = Rand(2);
                RequesterPC.SetTeamForDuel(EAOCFaction(TeamForDuel));
                ChallengePC.SetTeamForDuel(EAOCFaction(TeamForDuel ^ EFAC_MASON));

            }

            RequesterPC.SetInitialParametersForDuelTeam();
            ChallengePC.SetInitialParametersForDuelTeam();

            switch (PrivateDuels)
            {

                case PRIVATE_DUEL_RESERVED:
                case PRIVATE_DUEL_SEMI_PUBLIC:

                    DuelReality = GetNextReality();
                    RequesterPC.InitDuel(true, DuelReality);
                    ChallengePC.InitDuel(true, DuelReality);
                    break;

                default:

                    RequesterPC.InitDuel(false);
                    ChallengePC.InitDuel(false);
                    break;

            }

        }

        else
        {

            ctime = WorldInfo.TimeSeconds;

            if (RequesterPC.DuelInfo.ChallengeTimeout > ctime)
                BroadcastDuelMessageToPlayer(RequesterPC, "You cannot challenge another player for"@`ParseTime(Round(RequesterPC.DuelInfo.ChallengeTimeout - ctime))$".");

            else if (bOnlySameTeamSizeDuels && RequesterPC.DuelInfo.Team.Length != ChallengePC.DuelInfo.Team.Length)
                BroadcastDuelMessageToPlayer(RequesterPC, "You cannot challenge"@ChallengePC.GetDuelTeamName()@"to a duel. Team size differs.");

            else
            {

                RequesterPC.DuelInfo.Challenge = ChallengePC;
                RequesterPC.DuelInfo.ChallengeTimeout = (ctime + fChallengeTimeout);
                BroadcastDuelMessageToPlayer(RequesterPC, "You've challenged"@ChallengePC.GetDuelTeamName()@"to a duel!");
                BroadcastDuelMessageToPlayer(ChallengePC, RequesterPC.GetDuelTeamName()@"has challenged you to a duel.");
                BroadcastMessageToDuelTeam(RequesterPC, RequesterPC.GetDuelTeamName()@"has challenged"@ChallengePC.GetDuelTeamName()@"to a duel.");
                BroadcastMessageToDuelTeam(ChallengePC, RequesterPC.GetDuelTeamName()@"has challenged"@ChallengePC.GetDuelTeamName()@"to a duel.");

            }

        }

    }

    else // Re-Battlecry to revoke your challenge.
    {

        RequesterPC.DuelInfo.Challenge = none;
        BroadcastDuelMessageToPlayer(RequesterPC, "You've revoked your challenge against"@ChallengePC.GetDuelTeamName()$"!");
        BroadcastDuelMessageToPlayer(ChallengePC, RequesterPC.GetDuelTeamName()@"no longer wants to duel you.");
        BroadcastMessageToDuelTeam(RequesterPC, RequesterPC.GetDuelTeamName()@"no longer wants to duel"@ChallengePC.GetDuelTeamName()$".");
        BroadcastMessageToDuelTeam(ChallengePC, RequesterPC.GetDuelTeamName()@"no longer wants to duel"@ChallengePC.GetDuelTeamName()$".");

    }

}

protected function CancelDuel(DMFFAPlayerController DuelTeamLeader)
{

    if (!DuelTeamLeader.DuelInfo.status)
        return;

    if (DuelTeamLeader.IsTimerActive('ResetDuelStatus'))
        DuelTeamLeader.ClearTimer('ResetDuelStatus');

    else
        DuelTeamLeader.EndDuel();

    ResetDuel(DuelTeamLeader);

}

protected function EndDuel(DMFFAPlayerController Winner, DMFFAPlayerController Loser)
{

    local SoundCue TeamWinSound;

    Winner.EndDuel();
    Loser.EndDuel();
    ResetDuel(Loser);

    switch (Winner.TeamForDuel)
    {

        case EFAC_AGATHA:
        case EFAC_MASON:

            TeamWinSound = DuelWinSound[Winner.TeamForDuel];
            break;

        default:

            TeamWinSound = DuelWinSound[Rand(ArrayCount(DuelWinSound))];
            break;

    }

    Winner.MakeDuelWinner(TeamWinSound);
    IncreaseScoreForDuelTeam(Winner);

}

/* End of Duels. */

/* Teams. */

function InvitePlayerToTeam(DMFFAPawn Requester)
{

    local DMFFAPlayerController RequesterPC, InvitedPC;

    if (Requester == none)
        return;

    RequesterPC = DMFFAPlayerController(Requester.Controller);

    if (RequesterPC == none)
        return;

    if (RequesterPC.DuelInfo.Leader != none) // Only leaders or players without a team can invite.
        return;

    if (RequesterPC.DuelInfo.status) // No invites if we are in a duel.
        return;

    InvitedPC = RequesterPC.GetTargetPlayerController();

    if (InvitedPC == none)
        return;

    if (InvitedPC.DuelInfo.status) // Is target player in a duel?
        return;

    if (InvitedPC.HasDuelTeam())
    {

        if (InvitedPC.DuelInfo.Leader != RequesterPC)
            BroadcastDuelMessageToPlayer(RequesterPC, InvitedPC.PlayerReplicationInfo.PlayerName@"is already in a team.");

        else
            BroadcastDuelMessageToPlayer(RequesterPC, InvitedPC.PlayerReplicationInfo.PlayerName@"is already in your team.");

    }

    else if (InvitedPC.DuelInfo.Invite != none)
    {

        if (InvitedPC.DuelInfo.Invite != RequesterPC)
            BroadcastDuelMessageToPlayer(RequesterPC, InvitedPC.PlayerReplicationInfo.PlayerName@"has already been invited to join another team.");

        else
            BroadcastDuelMessageToPlayer(RequesterPC, InvitedPC.PlayerReplicationInfo.PlayerName@"has already been invited to join your team.");

    }

    else if (iMaxTeamSize > 0 && RequesterPC.DuelInfo.Team.Length >= iMaxTeamSize)
        BroadcastDuelMessageToPlayer(RequesterPC, "Your team is full.");

    else
    {

        InvitedPC.DuelInfo.Invite = RequesterPC;
        BroadcastDuelMessageToPlayer(RequesterPC, "You've invited"@InvitedPC.PlayerReplicationInfo.PlayerName@"to your team!");
        BroadcastDuelMessageToPlayer(InvitedPC, RequesterPC.PlayerReplicationInfo.PlayerName@"has invited you to his/her team.");

    }

}

function AcceptTeamInvitation(DMFFAPawn Requester)
{

    local DMFFAPlayerController RequesterPC, LeaderPC;
    local DMFFAPRI LeaderPRI, PRI;
    local DMFFAPlayerController PC;

    if (Requester == none)
        return;

    RequesterPC = DMFFAPlayerController(Requester.Controller);

    if (RequesterPC == none)
        return;

    if (RequesterPC.DuelInfo.status) // No join-ins inside duel.
        return;

    if (RequesterPC.DuelInfo.Invite != none) // Do we have an invitation?
    {

        if (RequesterPC.DuelInfo.Invite.DuelInfo.Leader != none) // Just to be safe.
        {

            RequesterPC.DuelInfo.Invite = none;
            return;

        }

        if (RequesterPC.DuelInfo.Invite.DuelInfo.status) // Team leader is currently in a duel.
        {

            BroadcastDuelMessageToPlayer(RequesterPC, RequesterPC.DuelInfo.Invite.GetDuelTeamName()@"is currently in a duel. Wait for it to finish before joining.");
            return;

        }

        if (iMaxTeamSize > 0 && RequesterPC.DuelInfo.Invite.DuelInfo.Team.Length >= iMaxTeamSize)
        {

            /*
            Do not clear his/her invite. 
            If the team gets below it's maximum capacity he/she will be able to join without the need for reinvitation.
            */
            BroadcastDuelMessageToPlayer(RequesterPC, RequesterPC.DuelInfo.Invite.GetDuelTeamName()@"is full.");
            return;

        }

        LeaderPC = RequesterPC.DuelInfo.Invite;
        RequesterPC.DuelInfo.Invite = none;
        RequesterPC.DuelInfo.Leader = LeaderPC;
        RequesterPC.ClearDuelTeamInvites();
        RequesterPC.ResetDuelInfo();
        RequesterPC.ClearAllDuelChallenges();
        BroadcastDuelMessageToPlayer(LeaderPC, RequesterPC.PlayerReplicationInfo.PlayerName@"has joined your team!");
        LeaderPRI = DMFFAPRI(LeaderPC.PlayerReplicationInfo);
        LeaderPRI.DuelTeamSize++;

        if (LeaderPC.DuelInfo.Team.Length > 0)
        {

            foreach LeaderPC.DuelInfo.Team(PC)
            {

                BroadcastDuelMessageToPlayer(PC, RequesterPC.PlayerReplicationInfo.PlayerName@"has joined your team!");
                DMFFAPRI(PC.PlayerReplicationInfo).DuelTeamSize++;

            }

        }

        else
            LeaderPRI.DuelTeamID = GetNextDuelTeamID(); // The team was just created. Generate a new Duel Team ID.

        LeaderPC.DuelInfo.Team.AddItem(RequesterPC);
        LeaderPC.DuelInfo.Invite = none; // Any invites sent to the leader should be cleared once he/she gets a team.
        PRI = DMFFAPRI(RequesterPC.PlayerReplicationInfo);
        PRI.IsDuelLeader = false;
        PRI.DuelTeamID = LeaderPRI.DuelTeamID;
        PRI.DuelTeamSize = LeaderPRI.DuelTeamSize;
        BroadcastDuelMessageToPlayer(RequesterPC, "You've joined"@LeaderPC.PlayerReplicationInfo.PlayerName$"'s team.");

    }

}

function DeclineTeamInvitation(DMFFAPawn Requester)
{

    local DMFFAPlayerController RequesterPC;

    if (Requester == none)
        return;

    RequesterPC = DMFFAPlayerController(Requester.Controller);

    if (RequesterPC == none)
        return;

    if (RequesterPC.DuelInfo.status) // No declines inside duel.
        return;

    if (RequesterPC.DuelInfo.Invite != none) // Do we have an invitation?
    {

        if (RequesterPC.DuelInfo.Invite.DuelInfo.Leader != none) // Just to be safe.
        {

            RequesterPC.DuelInfo.Invite = none;
            return;

        }

        BroadcastDuelMessageToPlayer(RequesterPC, "You've declined"@RequesterPC.DuelInfo.Invite.PlayerReplicationInfo.PlayerName$"'s invite to join his/her team.");
        BroadcastDuelMessageToPlayer(RequesterPC.DuelInfo.Invite, RequesterPC.PlayerReplicationInfo.PlayerName@"has declined your invite to join your team.");
        RequesterPC.DuelInfo.Invite = none;

    }

}

function LeaveDuelTeam(DMFFAPawn Requester)
{

    local DMFFAPlayerController RequesterPC, LeaderPC, KickPC;
    local DMFFAPlayerController PC;

    if (Requester == none)
        return;

    RequesterPC = DMFFAPLayerController(Requester.Controller);

    if (RequesterPC == none)
        return;

    if (RequesterPC.DuelInfo.status) // No team leave/kick inside duel.
        return;

    if (!RequesterPC.HasDuelTeam()) // We have/are in no team.
        return;

    if (RequesterPC.DuelInfo.Leader != none) // We are not the team leader, so just leave.
    {

        LeaderPC = RequesterPC.DuelInfo.Leader;
        LeaderPC.DuelInfo.Team.RemoveItem(RequesterPC);
        BroadcastDuelMessageToPlayer(LeaderPC, RequesterPC.PlayerReplicationInfo.PlayerName@"has left your team!");

        if (LeaderPC.DuelInfo.Team.Length > 0)
        {

            DMFFAPRI(LeaderPC.PlayerReplicationInfo).DuelTeamSize--;

            foreach LeaderPC.DuelInfo.Team(PC)
            {

                BroadcastDuelMessageToPlayer(PC, RequesterPC.PlayerReplicationInfo.PlayerName@"has left your team!");
                DMFFAPRI(PC.PlayerReplicationInfo).DuelTeamSize--;

            }

        }

        else
        {

            BroadcastDuelMessageToPlayer(LeaderPC, "The team has been disbanded!");
            LeaderPC.ResetDuelTeamInfo();

        }

        BroadcastDuelMessageToPlayer(RequesterPC, "You've left"@LeaderPC.PlayerReplicationInfo.PlayerName$"'s team.");
        RequesterPC.ResetDuelTeamInfo();

    }

    else // We are the leader and we have a team. Kick whoever is targeted from our team.
    {

        KickPC = RequesterPC.GetTargetPlayerController();

        if (KickPC == none)
            return;

        if (!RequesterPC.IsPlayerInMyDuelTeam(KickPC)) // Is targeted player in our team?
            return;

        RequesterPC.DuelInfo.Team.RemoveItem(KickPC);
        BroadcastDuelMessageToPlayer(RequesterPC, "You've kicked"@KickPC.PlayerReplicationInfo.PlayerName@"from your team.");

        if (RequesterPC.DuelInfo.Team.Length > 0)
        {

            DMFFAPRI(RequesterPC.PlayerReplicationInfo).DuelTeamSize--;

            foreach RequesterPC.DuelInfo.Team(PC)
            {

                BroadcastDuelMessageToPlayer(PC, KickPC.PlayerReplicationInfo.PlayerName@"has been kicked from your team.");
                DMFFAPRI(PC.PlayerReplicationInfo).DuelTeamSize--;

            }

        }

        else
        {

            BroadcastDuelMessageToPlayer(RequesterPC, "The team has been disbanded!");
            RequesterPC.ResetDuelTeamInfo();

        }

        BroadcastDuelMessageToPlayer(KickPC, "You've been kicked from"@RequesterPC.PlayerReplicationInfo.PlayerName$"'s team.");
        KickPC.ResetDuelTeamInfo();

    }

}

function DisbandDuelTeam(DMFFAPawn Requester)
{

    local DMFFAPlayerController RequesterPC;
    local DMFFAPlayerController PC;

    if (Requester == none)
        return;

    RequesterPC = DMFFAPlayerController(Requester.Controller);

    if (RequesterPC == none)
        return;

    if (RequesterPC.DuelInfo.Leader != none) // Only the team leader can disband.
        return;

    if (RequesterPC.DuelInfo.status) // No team disbands inside duel.
        return;

    if (!RequesterPC.HasDuelTeam()) // We have no team to disband.
        return;

    RequesterPC.ClearDuelTeamInvites();

    foreach RequesterPC.DuelInfo.Team(PC)
    {

        BroadcastDuelMessageToPlayer(PC, RequesterPC.PlayerReplicationInfo.PlayerName@"has disbanded his/her team.");
        PC.ResetDuelTeamInfo();

    }

    BroadcastDuelMessageToPlayer(RequesterPC, "You've disbanded your team!");
    RequesterPC.ResetDuelTeamInfo();

}

protected function AutoLeaveDuelTeam(DMFFAPlayerController Deserter) // This method will be called when a team member disconnects or goes spectator.
{

    local DMFFAPlayerController LeaderPC;
    local DMFFAPlayerController PC;

    if (Deserter == none)
        return;

    LeaderPC = Deserter.DuelInfo.Leader;
    LeaderPC.DuelInfo.Team.RemoveItem(Deserter);
    BroadcastDuelMessageToPlayer(LeaderPC, Deserter.PlayerReplicationInfo.PlayerName@"has left your team!");

    if (LeaderPC.DuelInfo.Team.Length > 0)
    {

        DMFFAPRI(LeaderPC.PlayerReplicationInfo).DuelTeamSize--;

        foreach LeaderPC.DuelInfo.Team(PC)
        {

            BroadcastDuelMessageToPlayer(PC, Deserter.PlayerReplicationInfo.PlayerName@"has left your team!");
            DMFFAPRI(PC.PlayerReplicationInfo).DuelTeamSize--;

        }

    }

    else
    {

        BroadcastDuelMessageToPlayer(LeaderPC, "The team has been disbanded!");
        LeaderPC.ResetDuelTeamInfo();

    }

    Deserter.ResetDuelTeamInfo();

}

protected function AutoDisbandDuelTeam(DMFFAPlayerController Deserter) // This method will be called when the leader disconnects, goes spectator and at the EndGame.
{

    local DMFFAPlayerController PC;

    if (Deserter == none)
        return;

    Deserter.ClearDuelTeamInvites();

    foreach Deserter.DuelInfo.Team(PC)
    {

        BroadcastDuelMessageToPlayer(PC, Deserter.PlayerReplicationInfo.PlayerName@"'s team has been disbanded.");
        PC.ResetDuelTeamInfo();

    }

    BroadcastDuelMessageToPlayer(Deserter, "Your team has been disbanded!");
    Deserter.ResetDuelTeamInfo();

}

function DesertDuelTeam(DMFFAPlayerController Deserter) // This method will called when a player disconencts and goes spectator.
{

    if (Deserter == none)
        return;

    if (Deserter.HasDuelTeam()) // Do we have a team?
    {

        if (Deserter.DuelInfo.Leader != none) // Not a leader.
            AutoLeaveDuelTeam(Deserter);

        else // Leader.
        {

            if (Deserter.DuelInfo.status)
            {

                if (!Deserter.IsTimerActive('ResetDuelStatus')) // Give victory to opponent.
                    EndDuel(Deserter.DuelInfo.Challenge, Deserter);

                else // We already won the duel.
                    CancelDuel(Deserter);

            }

            AutoDisbandDuelTeam(Deserter);

        }

    }

    else
    {

        Deserter.ClearTimer('ResetDuelStatus');
        Deserter.ResetDuelTeamInfo();
        Deserter.ClearDuelTeamInvites();

    }

    Deserter.ResetDuelInfo();
    Deserter.SetTrappedBetweenRealities(false);
    Deserter.SetTeamForDuel(EFAC_FFA);
    Deserter.AllowedToSpawn = true;
    Deserter.InstantSpawn = true;

}

/* End of teams. */

protected function InitEndGame(DMFFAPlayerController DuelTeamLeader)
{

    if (bGameEnded)
        return;

    bAOCGameEnded = true;
    bGameEnded = true;
    TeamWinner = DuelTeamLeader.GetDuelTeamName();
    WinString = DuelTeamLeader.GetDuelTeamName(,true)@"has won!";
    EndGame(DuelTeamLeader.PlayerReplicationInfo, "GoalScore");

}

function string GetDuelInfo(DMFFAPlayerController PC)
{

    /* Query and format string for GetDuelInfo command. */

    local string DuelReportMessage;

    DuelReportMessage = "["$PC.PlayerReplicationInfo.PlayerName$"] In-Team:";

    if (PC.HasDuelTeam())
    {

        DuelReportMessage @= "Yes | Leader:";

        if (PC.DuelInfo.Leader == none)
            DuelReportMessage @= "Yes |";

        else
            DuelReportMessage @= PC.DuelInfo.Leader.PlayerReplicationInfo.PlayerName@"|";

        DuelReportMessage @= "Team size:"@PC.GetDuelLeader().DuelInfo.Team.Length@"|";

    }

    else
        DuelReportMessage @= "No |";

    DuelReportMessage @= "In-Duel:";

    if (PC.DuelInfo.status)
    {

        DuelReportMessage @= "Yes |";
        DuelReportMessage @= "Challenge:"@PC.DuelInfo.Challenge.GetDuelTeamName();

    }

    else
        DuelReportMessage @= "No";

    return DuelReportMessage;

}

function bool IsMapInList(string MapName)
{

    local string MapInList;

    foreach MapList(MapInList)
    {

        if (MapName ~= MapInList)
            return true;

    }

    return false;

}

/* Overridden methods. */

Auto State AOCPreRound
{

    /* No Pre Round for DMFFA. */

    function BeginState(Name PreviousStateName)
    {

        switch (PrivateDuels)
        {

            case PRIVATE_DUEL_RESERVED:
            case PRIVATE_DUEL_SEMI_PUBLIC:
            case PRIVATE_DUEL_PUBLIC:
                break;

            default:

                PrivateDuels = PRIVATE_DUEL_PUBLIC; // Bad config for Private Duels. Disable it.
                break;

        }

        StartRound();

    }

    function RequestTime(AOCPlayerController PC);

    function Timer();
    
    function float SpawnWait(AIController B)
    {

        return 0.f;

    }

}

function PreBeginPlay()
{

    /* Overridden to allow customization of team damage. */

    super(AOCGame).PreBeginPlay();

}

function StartRound()
{

    local DMFFAPlayerController PC;

    isFirstBlood = false;

    // No Timelimit for DMFFA.
    TimeLeft = -1;

    bAOCGameEnded = false;
    bGameEnded = false;
    bGameStarted = true;
    GameStartTime = WorldInfo.TimeSeconds;

    foreach WorldInfo.AllControllers(class'DMFFAPlayerController', PC)
    {

        PC.ResetDuelInfo();
        PC.ResetDuelTeamInfo();
        PC.SetTrappedBetweenRealities(false);
        PC.AllowedToSpawn = true;
        PC.InstantSpawn = true;
        PC.SetTeamForDuel(EFAC_FFA);

        if (PC.RealityID > DEFAULT_REALITY)
            PC.SetReality(DEFAULT_REALITY);

        PC.InitializeTimer(TimeLeft, true);
        PC.SetWaitingForPlayers(false);
        PC.WarmupUnfrozen();

    }

    // New spawn wave timer.
    ClearTimer('SpawnQueueTimer');
    SpawnQueueTimer();
    SetTimer(SpawnWaveInterval, true, 'SpawnQueueTimer');

    GoToState('AOCRoundInProgress');

}

State AOCRoundInProgress
{

    /* No timelimit for DMFFA. */

    function Timer()
    {

        super(UTTeamGame).Timer();

    }

}

function BroadcastMessage(PlayerController Sender, string Message, EAOCFaction DesignatedTeam, optional bool bSystemMessage = false, optional bool bUseCustomColor = false, optional string Col) // #XXXXXX color code.
{

    /* Overridden to allow team messages to only show to team members.
       Spectator team messages properly implemented aswell. */

    local DMFFAPlayerController SenderPC;
    local DMFFAPlayerController PC;
    local bool IsTeamMessage;

    SenderPC = DMFFAPlayerController(Sender);

    if (SenderPC != none)
    {

        RemoteConsole.GameEvent_BroadcastMessage(Sender.PlayerReplicationInfo, Message, DesignatedTeam);

        if (DesignatedTeam == EFAC_NONE)
        {

            if (SenderPC.IsVoluntarySpectator())
            {

                foreach WorldInfo.AllControllers(class'DMFFAPlayerController', PC)
                {

                    if (PC.IsVoluntarySpectator())
                    {

                        // Ignore messages from muted players.
                        if (!PC.IsPlayerMuted(Sender.PlayerReplicationInfo.UniqueId))
                            PC.ReceiveChatMessage(Sender.GetHumanReadableName(), Message, EFAC_NONE,,,,true);                        

                    }

                }

            }

            else
                SenderPC.ReceiveChatMessage("", Message, SenderPC.CurrentFamilyInfo.default.FamilyFaction);

            return;

        }

        IsTeamMessage = (DesignatedTeam != EFAC_ALL);

        foreach WorldInfo.AllControllers(class'DMFFAPlayerController', PC)
        {

            if (!IsTeamMessage || SenderPC.IsPlayerInMyDuelTeam(PC))
            {

                // Ignore messages from muted players.
                if (!PC.IsPlayerMuted(Sender.PlayerReplicationInfo.UniqueId))
                    PC.ReceiveChatMessage(Sender.GetHumanReadableName(), Message, SenderPC.CurrentFamilyInfo.default.FamilyFaction,,,,IsTeamMessage);

            }

        }

    }

    else if (bSystemMessage)
    {

        foreach WorldInfo.AllControllers(class'DMFFAPlayerController', PC)
        {

            if (DesignatedTeam == EFAC_ALL || DesignatedTeam == PC.CurrentFamilyInfo.default.FamilyFaction)
                PC.ReceiveChatMessage("", Message, DesignatedTeam,,bUseCustomColor, Col);

        }

    }

}

function bool ChangeTeam(Controller Other, int num, bool bNewTeam)
{

    local UTTeamInfo NewTeam;

    if (Other.IsA('PlayerController') && Other.PlayerReplicationInfo.bOnlySpectator)
        NewTeam = ObserverTeam;

    else
    {

        switch (num)
        {

            case EFAC_AGATHA:
            case EFAC_MASON:

                NewTeam = Teams[num];
                break;

            default:

                NewTeam = ObserverTeam;
                break;

        }

    }

    if (Other.PlayerReplicationInfo.Team != NewTeam)
        SetTeam(Other, NewTeam, bNewTeam);

    return true;

}

function Pawn SpawnDefaultPawnFor(Controller NewPlayer, NavigationPoint StartSpot)
{

    /* Override to ensure that NewPlayer is passed in as the Pawn's SpawnOwner, so that the pawn inherits its controller's RealityID.
       Also makes sure that the player is reset to the default reality. */

    local DMFFAPlayerController PC;
    local class<Pawn> DefaultPlayerClass;
    local Rotator StartRotation;
    local Pawn ResultPawn;

    if (PrivateDuels != PRIVATE_DUEL_PUBLIC)
    {

        PC = DMFFAPlayerController(NewPlayer);

        if (PC != none)
            PC.SetReality(DEFAULT_REALITY);

    }

    DefaultPlayerClass = GetDefaultPlayerClass(NewPlayer);

    // Don't allow pawn to be spawned with any pitch or roll.
    StartRotation.Yaw = StartSpot.Rotation.Yaw;

    ResultPawn = Spawn(DefaultPlayerClass, NewPlayer,,StartSpot.Location, StartRotation);
    
    return ResultPawn;

}

function bool AddPlayerToQueue(Controller PC, optional bool bSpawnNextTime = false)
{

    local DMFFAPlayerController MyPC;
    local QueueInfo Info, QI;

    MyPC = DMFFAPlayerController(PC);

    if (MyPC == none)
        return false;

    foreach SpawnQueue(QI)
    {

        if (QI.C == PC)
            return false;

    }

    foreach SpawnQueueReady(QI)
    {

        if (QI.C == PC)
            return false;

    }

    Info.C = PC;

    if (MyPC.InstantSpawn)
    {

        MyPC.InstantSpawn = false;
        Info.MinRespawnTime = 0.f;

    }

    else // Three seconds delay to allow the player to experience his own death animation.
        Info.MinRespawnTime = (WorldInfo.TimeSeconds + MinimumRespawnTime);

    SpawnQueue.AddItem(Info);

    return true;

}

function SpawnQueueTimer()
{

    /* Iterate through queue to spawn players.
       Instant respawn for DMFFA, unless duel is not finished for the team.
       Three seconds delay to allow the player to experience his own death animation. */

    local float ctime;
    local QueueInfo QI;
    local DMFFAPlayerController PC;
    local array<QueueInfo> RemovedQI;

    ctime = WorldInfo.TimeSeconds;

    foreach SpawnQueue(QI)
    {

        PC = DMFFAPlayerController(QI.C);

        if (PC == none)
            RemovedQI.AddItem(QI);

        else if (PC.AllowedToSpawn) // No respawn until the duel is over.
        {

            if (QI.MinRespawnTime <= ctime)
            {

                SpawnQueueReady.AddItem(QI);
                RemovedQI.AddItem(QI);

            }

        }

    }

    // Iterate through array to remove players from queue.

    foreach RemovedQI(QI)
    {

        SpawnQueue.RemoveItem(QI);

    }

}

function LoadoutChangeSpawnPlayer(Controller NewPlayer)
{

    local DMFFAPawn P;
    local DMFFAPlayerController PC;

    if (NewPlayer == none)
        return;

    P = DMFFAPawn(NewPlayer.Pawn);

    if (P == none)
        return;

    PC = DMFFAPlayerController(NewPlayer);

    if (PC != none)
        PC.ClientStartPawnSwapout();

    P.ResetWeaponStateToActive();

    super.LoadoutChangeSpawnPlayer(NewPlayer);

}

function Killed(Controller Killer, Controller KilledPlayer, Pawn KilledPawn, class<DamageType> damageType)
{

    local DMFFAPlayerController KilledPC;
    local DMFFAPlayerController MyDuelLeader, OpponentDuelLeader;

    super.Killed(Killer, KilledPlayer, KilledPawn, damageType);

    if (!bGameStarted || bGameEnded)
        return;

    KilledPC = DMFFAPlayerController(KilledPlayer);

    if (KilledPC == none) // Is Killed Player actually a player?
        return;

    if (KilledPC.DuelInfo.status) // Is Killed Player in a duel?
    {

        MyDuelLeader = KilledPC.GetDuelLeader();
        OpponentDuelLeader = KilledPC.DuelInfo.Challenge;

        if (KilledPC == MyDuelLeader && MyDuelLeader.TrappedBetweenRealities && !MyDuelLeader.IsTimerActive('ResetDuelStatus'))
        {

            // Leader died before the actual duel could begin.
            CancelDuel(MyDuelLeader);
            CancelDuel(OpponentDuelLeader);
            return;

        }

        if (!KilledPC.IsDuelLeaderDead() || !KilledPC.IsDuelTeamDead()) // Our team is not dead yet. No respawn.
            return;

        // Our team is dead. Prepare to end duel.

        if (MyDuelLeader.IsTimerActive('ResetDuelStatus')) // Duel is already in the ending process.
            return;

        EndDuel(OpponentDuelLeader, MyDuelLeader);

    }

    else if (KilledPC.DuelInfo.Leader == none)
    {

        KilledPC.ResetDuelInfo();
        KilledPC.ClearAllDuelChallenges(); // Reset all challenges.

    }

}

function ScoreKill(Controller Killer, Controller Other)
{

    local DMFFAPlayerController Attacker, Victim;

    Attacker = DMFFAPlayerController(Killer);
    Victim = DMFFAPlayerController(Other);

    if (Attacker == none || Victim == none || Attacker == Victim)
        return;

    if (Attacker.IsPlayerInMyDuelTeam(Victim)) // Teamkill.
        return;

    DMFFAPRI(Killer.PlayerReplicationInfo).NumKills++;

    if (!isFirstBlood)
    {

        isFirstBlood = true;
        BroadcastSystemMessage(3, class'AOCSystemMessages'.static.CreateLocalizationdata("INVALIDDATA", Killer.PlayerReplicationInfo.PlayerName, ""), 
                               class'AOCSystemMessages'.static.CreateLocalizationdata("INVALIDDATA", Other.PlayerReplicationInfo.PlayerName, ""), EFAC_ALL);

    }

}

function bool CanSpectate(PlayerController Viewer, PlayerReplicationInfo ViewTarget)
{

    /* Returns true if Viewer is allowed to spectate ViewTarget. */

    local DMFFAPlayerController ViewerPC, ViewTargetPC;

    ViewerPC = DMFFAPlayerController(Viewer);

    if (ViewerPC == none || ViewTarget == none)
        return false;

    ViewTargetPC = DMFFAPlayerController(ViewTarget.Owner);

    if (ViewTargetPC == none)
        return false;

    if (ViewTargetPC.IsVoluntarySpectator())
        return false;

    if (ViewerPC.IsVoluntarySpectator())
        return true;

    return ViewerPC.IsPlayerInMyDuelTeam(ViewTargetPC);

}

function EndGame(PlayerReplicationInfo Winner, string Reason) // EndGame for GoalScore
{

    local DMFFAPlayerController PC;

    if (IsTimerActive('NotifyEndGame') || IsTimerActive('ActualEndGame'))
        return;

    foreach WorldInfo.AllControllers(class'DMFFAPlayerController', PC)
    {

        // Cancel all duels in progress and disband teams.
        if (PC.DuelInfo.Leader == none && PC.PlayerReplicationInfo != Winner)
        {

            CancelDuel(PC);

            if (PC.HasDuelTeam())
                AutoDisbandDuelTeam(PC);

        }

    }

    foreach WorldInfo.AllControllers(class'DMFFAPlayerController', PC)
    {

        PC.PreEndGame(EFAC_FFA, "", WinString,,Winner);

    }

    SetTimer(NOTIFY_ENDGAME_TIME, false, 'NotifyEndGame');
    SetTimer(ACTUAL_ENDGAME_TIME, false, 'ActualEndGame');

}

function Logout(Controller Exiting)
{

    DesertDuelTeam(DMFFAPlayerController(Exiting));

    super.Logout(Exiting);

}

function InitiateVoteChangeMap(AOCPlayerController VoteInstigator, String MapName)
{

    /* Overridden to add support to bMapVoteOnlyFromList. */

    local int FailReasonPMCode;
    local int OptionStart;
    local DMFFAPlayerController PC;
    local DMFFAGRI GRI;
    
    if (!bEnableVoteChangeMap)
    {

        LocalizedPrivateMessage(VoteInstigator, iLocMapChangeVotesDisabled);
        return;

    }

    if (!IsAllowedToInitiateVote(VoteInstigator, FailReasonPMCode))
    {

        LocalizedPrivateMessage(VoteInstigator, FailReasonPMCode);
        return;

    }
    
    //Strip any map options (nice try!)

    OptionStart = InStr(MapName, "?");

    if (OptionStart != INDEX_NONE)
        MapName = Left(MapName, OptionStart);
    
    if (!MapExists(MapName) || !(Right(MapName, 2) ~= "_p") || Left(MapName, 6) ~= "AOCTUT" || (bMapVoteOnlyFromList && !IsMapInList(MapName)))
    {

        LocalizedPrivateMessage(VoteInstigator, iLocMapDoesntExist);
        return;

    }

    VoteMapName = MapName;
    VoteCategory = EVOTECAT_ChangeMap;
    BroadcastSystemMessage(iLocMapChangeVoteInitiated,
                           class'AOCSystemMessages'.static.CreateLocalizationdata("INVALIDDATA", VoteInstigator.PlayerReplicationInfo.PlayerName, ""),
                           class'AOCSystemMessages'.static.CreateLocalizationdata("INVALIDDATA", MapName, ""),
                           EFAC_ALL);
    
    foreach WorldInfo.AllControllers(class'DMFFAPlayerController', PC)
    {

        PC.BeginVote(EVOTECAT_ChangeMap, MapName, fVoteDurationSeconds);

    }

    GRI = DMFFAGRI(GameReplicationInfo);
    GRI.VotesNo = 0;
    GRI.VotesYes = 0;
    SetTimer(0.5f, true, 'CountVotes');
    fTimeVoteStarted = WorldInfo.TimeSeconds;
    SetTimer(fVoteDurationSeconds, false, 'EndChangeMapVote');
    InitiateNewVote(VoteInstigator);
    VoteInstigator.Vote = EVOTE_Yes;

}

DefaultProperties
{	

    PlayerControllerClass = class'DMFFAPlayerController'
    DefaultPawnClass = class'DMFFAPawn'
    GameReplicationInfoClass = class'DMFFAGRI'
    PlayerReplicationInfoClass = class'DMFFAPRI'
    HUDType = class'DMFFAHUD'
    MinimumRespawnTime = 3.f
    NextReality = 2
    DuelTeamID = 1
    DuelWinSound[EFAC_AGATHA] = SoundCue'A_Meta.obj_complete_agatha'
    DuelWinSound[EFAC_MASON] = SoundCue'A_Meta.obj_complete_mason'

}
