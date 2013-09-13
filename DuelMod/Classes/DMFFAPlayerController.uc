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

class DMFFAPlayerController extends AOCFFAPlayerController;

`include(DuelMod/Include/DuelMod.uci)

struct Duel
{

    var bool status;
    var bool damageable;
    var DMFFAPlayerController Challenge;
    var float ChallengeTimeout;
    var DMFFAPlayerController Leader;
    var DMFFAPlayerController Invite;
    var array<DMFFAPlayerController> Team;

    StructDefaultProperties
    {

        status = false;
        damageable = false;
        Challenge = none;
        ChallengeTimeout = 0.f;
        Leader = none;
        Invite = none;

    }

};

var bool AllowedToSpawn;
var bool InstantSpawn;
var bool TrappedBetweenRealities;
var EAOCFaction TeamForDuel;
var Duel DuelInfo;
var protected float TargetPlayerScalar;
var protected DMFFAPlayerController TargetPlayerController;
var protected float InitDuelCountdown;
var protected float DuelCountdown;
var protected int DuelCountdownTimeLeft;
var protected string DuelCountdownString;
var protected int DuelReality;
var protected float ResetPlayerAfterDuelIn;
var protectedwrite SoundCue DuelGetReadySoundCue;
var protectedwrite SoundCue DuelFightSoundCue;

/* Targeting. */

function DMFFAPlayerController GetTargetPlayerController()
{

    return TargetPlayerController;

}

protected reliable server function SetTargetPlayerController(PlayerReplicationInfo PRI)
{

    TargetPlayerController = (PRI != none) ? DMFFAPlayerController(PRI.Owner) : none;

}

simulated function UpdateTargetPlayerController()
{

    local Vector Start, End;
    local Rotator Rot;
    local DMFFAPawn P;
    local Vector Loc, Norm;
    local PlayerReplicationInfo PRI;

    GetPlayerViewPoint(Start, Rot);
    End = Start + Vector(Rot) * TargetPlayerScalar;

    foreach TraceActors(class'DMFFAPawn', P, Loc, Norm, End, Start)
    {

        if (P.IsAliveAndWell())
        {

            PRI = P.PlayerReplicationInfo;
            break;

        }

    }

    SetTargetPlayerController(PRI);

}

/* End of targeting. */

exec function GetDuelInfo(optional string PlayerName)
{

    if (PlayerName == "")
        UpdateTargetPlayerController();

    S_GetDuelInfo(PlayerName);

}

protected unreliable server function S_GetDuelInfo(optional string PlayerName)
{

    /* Broadcast target's duel info to player. */

    local DMFFAPlayerController PC;
    local DMFFAPlayerController TargetPC;
    local DMFFA G;

    if (PlayerName != "")
    {

        foreach WorldInfo.AllControllers(class'DMFFAPlayerController', PC)
        {

            if (PC.PlayerReplicationInfo.PlayerName ~= PlayerName)
            {

                TargetPC = PC;
                break;

            }

        }

        if (TargetPC == none) // Let's try to find a player name containing this substring.
        {

            PlayerName = Locs(PlayerName);

            foreach WorldInfo.AllControllers(class'DMFFAPlayerController', PC)
            {

                if (InStr(Locs(PC.PlayerReplicationInfo.PlayerName), PlayerName) != INDEX_NONE)
                {

                    TargetPC = PC;
                    break;

                }

            }

        }

    }

    else
        TargetPC = GetTargetPlayerController();

    if (TargetPC == none)
        return;

    G = DMFFA(WorldInfo.Game);
    G.BroadcastDuelMessageToPlayer(self, G.GetDuelInfo(TargetPC), "#FF9900");

}

function bool CanAttackPlayer(DMFFAPlayerController Victim)
{

    if (DuelInfo.Challenge != Victim)
    {

        if (Victim.DuelInfo.Leader != none && DuelInfo.Challenge == Victim.DuelInfo.Leader) // We have his/her leader as our challenge.
            return true;

        else
            return IsPlayerInMyDuelTeam(Victim); // Friendly-fire.
        
    }

    return true;

}

/* Duels. */

function ResetDuelInfo()
{

    DuelInfo.status = false;
    DMFFAPRI(PlayerReplicationInfo).DuelStatus = false;
    DuelInfo.damageable = false;
    DuelInfo.Challenge = none;
    DuelInfo.ChallengeTimeout = 0.f;

}

protected function ResetDuelStatus()
{

    DMFFA(WorldInfo.Game).ResetDuel(self);

}

protected function SetDuelDamageable()
{

    local DMFFAPlayerController PC;

    foreach DuelInfo.Team(PC)
    {

        PC.DuelInfo.damageable = true;

    }

    DuelInfo.damageable = true;

}

function SetTrappedBetweenRealities(bool status)
{

    TrappedBetweenRealities = status;
    ClientSetTrappedBetweenRealities(status);

}

protected reliable client function ClientSetTrappedBetweenRealities(bool status)
{

    TrappedBetweenRealities = status;

}

function SetTeamForDuel(EAOCFaction NewTeam)
{

    TeamForDuel = NewTeam;
    ClientSetTeamForDuel(NewTeam);

}

protected reliable client function ClientSetTeamForDuel(EAOCFaction NewTeam)
{

    TeamForDuel = NewTeam;

}

function ClearAllDuelChallenges()
{

    local DMFFAPlayerController PC;

    foreach Worldinfo.AllControllers(class'DMFFAPlayerController', PC)
    {

        if (PC.DuelInfo.Challenge == self)
            PC.DuelInfo.Challenge = none;

    }

}

function SetInitialParametersForDuel()
{

    SetTrappedBetweenRealities(true);
    ClearTimer('S_Suicide');
    ClearTimer('S_DoF10');
    AllowedToSpawn = false;
    DuelInfo.status = true;
    DMFFAPRI(PlayerReplicationInfo).DuelStatus = true;

}

function InitDuel(bool bSwitchReality, optional int NextReality = 0)
{

    local DMFFAPlayerController PC;

    DuelReality = NextReality;

    foreach DuelInfo.Team(PC)
    {

        PC.ClientInitDuel(bSwitchReality);
        PC.WarmupFrozen(InitDuelCountdown);

    }

    ClientInitDuel(bSwitchReality);
    WarmupFrozen(InitDuelCountdown);

    if (bSwitchReality)
        SetTimer(InitDuelCountdown, false, 'SwitchReality');

    else
        SetTimer(InitDuelCountdown, false, 'PreBeginDuel');

}

reliable client function ClientInitDuel(bool bSwitchReality)
{

    DuelCountdownString = (bSwitchReality) ? "Switching to duel reality in..." : "Initializing duel in...";
    DuelCountdownTimeLeft = Round(InitDuelCountdown - 1);

}

protected function SwitchReality() // Only called if we do switch realities for duels.
{

    local DMFFAPlayerController PC;

    foreach DuelInfo.Team(PC)
    {

        PC.WarmupUnfrozen();
        PC.SetReality(DuelReality); // Set our new reality for the team.

    }

    WarmupUnfrozen();
    SetReality(DuelReality); // Set our new reality.
    BeginDuel();

}

protected function PreBeginDuel() // Only called if we do not switch realities for duels.
{

    local DMFFAPlayerController PC;

    foreach DuelInfo.Team(PC)
    {

        PC.WarmupUnfrozen();

    }

    WarmupUnfrozen();
    BeginDuel();

}

protected function BeginDuel()
{

    local string MyDuelTeamNameColor, OpponentDuelTeamNameColor;
    local string MyDuelTeamName, OpponentDuelTeamName;
    local DMFFA G;
    local DMFFAPlayerController PC;

    switch (TeamForDuel)
    {

        case EFAC_AGATHA:

            SwitchDuelTeamToAgatha();
            MyDuelTeamNameColor = "#0000FF"; // Blue.
            OpponentDuelTeamNameColor = "#FF0000"; // Red.
            break;

        case EFAC_MASON:

            SwitchDuelTeamToMason();
            MyDuelTeamNameColor = "#FF0000"; // Red.
            OpponentDuelTeamNameColor = "#0000FF"; // Blue.
            break;

        default:

            MyDuelTeamNameColor = "";
            OpponentDuelTeamNameColor = "";
            break;

    }

    MyDuelTeamName = GetDuelTeamName(,true);
    OpponentDuelTeamName = DuelInfo.Challenge.GetDuelTeamName(,true);
    G = DMFFA(WorldInfo.Game);
    G.LoadoutChangeSpawnPlayer(self); // Generate a new pawn for our leader.
    SetTrappedBetweenRealities(false);
    ClientBeginDuel(MyDuelTeamName, OpponentDuelTeamName, MyDuelTeamNameColor, OpponentDuelTeamNameColor);
    WarmupFrozen(DuelCountdown);

    foreach DuelInfo.Team(PC)
    {

        switch (PC.TeamForDuel)
        {

            case EFAC_AGATHA:

                PC.SwitchDuelTeamToAgatha();
                break;

            case EFAC_MASON:

                PC.SwitchDuelTeamToMason();
                break;

            default:
                break;

        }

        if (DMFFAPawn(PC.Pawn) != none && PC.Pawn.IsAliveAndWell())
        {

            G.LoadoutChangeSpawnPlayer(PC); // Generate new pawns for our team.
            PC.ClientBeginDuel(MyDuelTeamName, OpponentDuelTeamName, MyDuelTeamNameColor, OpponentDuelTeamNameColor);
            PC.WarmupFrozen(DuelCountdown);

        }

        PC.SetTrappedBetweenRealities(false);

    }

    SetTimer(DuelCountdown, false, 'RequestEndDuelCountdown');

}

reliable client function ClientBeginDuel(string MyDuelTeamName, string OpponentDuelTeamName, optional string MyDuelTeamNameColor, optional string OpponentDuelTeamNameColor)
{

    if (MyDuelTeamNameColor != "")
        MyDuelTeamName = "<font color=\""$MyDuelTeamNameColor$"\">"$MyDuelTeamName$"</font>";

    DuelCountdownString = MyDuelTeamName;
    DuelCountdownString $= "<br />vs.<br />";

    if (OpponentDuelTeamNameColor != "")
        OpponentDuelTeamName = "<font color=\""$OpponentDuelTeamNameColor$"\">"$OpponentDuelTeamName$"</font>";

    DuelCountdownString $= OpponentDuelTeamName;
    DuelCountdownTimeLeft = Round(DuelCountdown - 1);
    PlaySound(DuelGetReadySoundCue, true);

}

protected function RequestEndDuelCountdown()
{

    local DMFFAPlayerController PC;

    WarmupUnfrozen();
    EndWarmupCounter();

    foreach DuelInfo.Team(PC)
    {

        PC.WarmupUnfrozen();
        PC.EndWarmupCounter();

    }

    SetTimer(0.75f, false, 'SetDuelDamageable');

}

reliable client function EndWarmupCounter()
{

    ClearHeader();
    ReceiveLocalizedHeaderText("FIGHT!", 2.f);
    PlaySound(DuelFightSoundCue, true);

}

function EndDuel()
{

    local DMFFAPlayerController PC;

    ClearTimer('PreBeginDuel');
    ClearTimer('SwitchReality');
    ClearTimer('RequestEndDuelCountdown');
    ClearTimer('SetDuelDamageable');
    WarmupUnfrozen();
    ClientEndDuel();

    foreach DuelInfo.Team(PC)
    {

        PC.WarmupUnfrozen();
        PC.ClientEndDuel();

    }

}

reliable client function ClientEndDuel()
{

    ClearHeader();

}

function MakeDuelWinner(SoundCue TeamWinSound)
{

    local DMFFAPlayerController PC;

    SetTrappedBetweenRealities(true);
    ClearTimer('S_Suicide');
    ClearTimer('S_DoF10');
    PlayLocalCustomSound(TeamWinSound);

    foreach DuelInfo.Team(PC)
    {

        PC.SetTrappedBetweenRealities(true);
        PC.ClearTimer('S_Suicide');
        PC.ClearTimer('S_DoF10');
        PC.PlayLocalCustomSound(TeamWinSound);

    }

    SetTimer(ResetPlayerAfterDuelIn, false, 'ResetDuelStatus');

}

/* End of Duels. */

/* Teams. */

function ResetDuelTeamInfo()
{

    local DMFFAPRI PRI;

    DuelInfo.Leader = none;
    DuelInfo.Invite = none;
    DuelInfo.Team.Remove(0, DuelInfo.Team.Length);
    PRI = DMFFAPRI(PlayerReplicationInfo);
    PRI.DuelTeamID = NO_DUEL_TEAM_ID;
    PRI.DuelTeamSize = 1;
    PRI.IsDuelLeader = true;

}

function SetInitialParametersForDuelTeam()
{

    local DMFFAPlayerController PC;

    foreach DuelInfo.Team(PC)
    {

        PC.SetTrappedBetweenRealities(true);
        PC.ClearTimer('S_Suicide');
        PC.ClearTimer('S_DoF10');
        PC.AllowedToSpawn = false;
        PC.DuelInfo.status = true;
        DMFFAPRI(PC.PlayerReplicationInfo).DuelStatus = true;
        PC.DuelInfo.Challenge = DuelInfo.Challenge;
        PC.SetTeamForDuel(TeamForDuel);

    }

}

function bool HasDuelTeam()
{

    return (DuelInfo.Leader != none || DuelInfo.Team.Length > 0);

}

function DMFFAPlayerController GetDuelLeader()
{

    return ((DuelInfo.Leader == none) ? self : DuelInfo.Leader);

}

function string GetDuelTeamName(optional bool Apostrophes = false, optional bool ForMarkup = false) // Ladies and gentlemen, behold the result of OCD.
{

    local string DuelTeamName;

    DuelTeamName = (ForMarkup) ? GetDuelLeader().PlayerReplicationInfo.GetPlayerNameForMarkup() : GetDuelLeader().PlayerReplicationInfo.PlayerName;

    if (HasDuelTeam())
    {

        if (!Apostrophes)
            DuelTeamName $= "'s";

        DuelTeamName @= "team";

    }

    if (Apostrophes)
        DuelTeamName $= "'s";

    return DuelTeamName;

}

function bool IsPlayerInMyDuelTeam(DMFFAPlayerController PC)
{

    local DMFFAPlayerController DuelTeamLeader;

    DuelTeamLeader = GetDuelLeader();

    return (DuelTeamLeader == PC || PC.DuelInfo.Leader == DuelTeamLeader);

}

function ClearDuelTeamInvites()
{

    /* Cancel any already sent invites. */

    local DMFFAPlayerController PC;

    foreach WorldInfo.AllControllers(class'DMFFAPlayerController', PC)
    {

        if (PC.DuelInfo.Invite == self)
            PC.DuelInfo.Invite = none;

    }

}

function SwitchDuelTeamToAgatha()
{

    local class<AOCFamilyInfo> NewFamilyInfo;

    if (CurrentFamilyInfo == none || CurrentFamilyInfo == class'AOCFamilyInfo_None')
        return;

    switch (CurrentFamilyInfo.default.ClassReference)
    {

        case ECLASS_Archer:

            NewFamilyInfo = class'AOCFamilyInfo_Agatha_Archer';
            break;

        case ECLASS_Knight:

            NewFamilyInfo = class'AOCFamilyInfo_Agatha_Knight';
            break;

        case ECLASS_ManAtArms:

            NewFamilyInfo = class'AOCFamilyInfo_Agatha_ManAtArms';
            break;

        case ECLASS_Vanguard:

            NewFamilyInfo = class'AOCFamilyInfo_Agatha_Vanguard';
            break;

        default:

            return;
            break;

    }

    SetNewClass(NewFamilyInfo,,true);

}

function SwitchDuelTeamToMason()
{

    local class<AOCFamilyInfo> NewFamilyInfo;

    if (CurrentFamilyInfo == none || CurrentFamilyInfo == class'AOCFamilyInfo_None')
        return;

    switch (CurrentFamilyInfo.default.ClassReference)
    {

        case ECLASS_Archer:

            NewFamilyInfo = class'AOCFamilyInfo_Mason_Archer';
            break;

        case ECLASS_Knight:

            NewFamilyInfo = class'AOCFamilyInfo_Mason_Knight';
            break;

        case ECLASS_ManAtArms:

            NewFamilyInfo = class'AOCFamilyInfo_Mason_ManAtArms';
            break;

        case ECLASS_Vanguard:

            NewFamilyInfo = class'AOCFamilyInfo_Mason_Vanguard';
            break;

        default:

            return;
            break;

    }

    SetNewClass(NewFamilyInfo,,true);

}

function bool IsDuelLeaderAlive()
{

    local DMFFAPlayerController DuelTeamLeader;

    DuelTeamLeader = GetDuelLeader();

    return (DMFFAPawn(DuelTeamLeader.Pawn) != none && DuelTeamLeader.Pawn.IsAliveAndWell());

}

function bool IsDuelLeaderDead()
{

    local DMFFAPlayerController DuelTeamLeader;

    DuelTeamLeader = GetDuelLeader();

    return (DMFFAPawn(DuelTeamLeader.Pawn) == none || !DuelTeamLeader.Pawn.IsAliveAndWell());

}

function bool IsDuelTeamAlive()
{

    local array<DMFFAPlayerController> DuelTeam;
    local DMFFAPlayerController PC;

    DuelTeam = GetDuelLeader().DuelInfo.Team;

    foreach DuelTeam(PC)
    {

        if (DMFFAPawn(PC.Pawn) == none || !PC.Pawn.IsAliveAndWell())
            return false;

    }

    return true;

}

function bool IsDuelTeamDead()
{

    local array<DMFFAPlayerController> DuelTeam;
    local DMFFAPlayerController PC;

    DuelTeam = GetDuelLeader().DuelInfo.Team;

    foreach DuelTeam(PC)
    {

        if (DMFFAPawn(PC.Pawn) != none && PC.Pawn.IsAliveAndWell())
            return false;

    }

    return true;

}

/* End of Teams. */

/* Spectator. */

function ResetReality()
{

    if (DMFFA(WorldInfo.Game).PrivateDuels != PRIVATE_DUEL_PUBLIC)
        SetReality(DEFAULT_REALITY); // Set reality back to default.

}

function UpdateSpectatorReality(DMFFAPlayerController PC); // No-op if player is not spectating.

state Spectating
{

    unreliable server function ServerViewSelf(optional ViewTargetTransitionParams TransitionParams)
    {

        super(UTPlayerController).ServerViewSelf(TransitionParams);

        // Reset Reality back to 1 for FreeLook camera.
        if (ViewTarget != none && IsVoluntarySpectator())
            ResetReality();

        ClientSetViewTarget(ViewTarget);

    }

    function UpdateSpectatorReality(DMFFAPlayerController PC)
    {

        local DMFFAPawn P;
        local DMFFAPlayerController ViewTargetPC;

        if (!IsVoluntarySpectator())
            return;

        if (ViewTarget != none)
        {

            P = DMFFAPawn(ViewTarget);
            ViewTargetPC = (P == none) ? DMFFAPlayerController(ViewTarget) : DMFFAPlayerController(P.Controller);

            if (ViewTargetPC != none && ViewTargetPC == PC)
                SetReality(PC.RealityID);

        }

    }

}

protected function ClearForceSwitchToObserver()
{

    ClearTimer('ForceSwitchToObserver');
    ClientClearForceSwitchToObserver();

}

protected reliable client function ClientClearForceSwitchToObserver()
{

    ClearTimer('ForceSwitchToObserver');

}

/* Team Member HUD Marker. */

function AddTeamMemberMarkerToHUD(DMFFAPawn P)
{

    local int MyDuelTeamID;
    local DMFFAPRI PRI;
    local DMFFAHUD ClientHUD;

    MyDuelTeamID = DMFFAPRI(PlayerReplicationInfo).DuelTeamID;

    if (MyDuelTeamID == NO_DUEL_TEAM_ID) // Not in a team. Don't bother creating new markers.
        return;

    if (P.IsAliveAndWell() && DMFFAPlayerController(P.Controller) != self) // We don't want to add ourselves, do we?
    {

        PRI = DMFFAPRI(P.PlayerReplicationInfo);

        if (PRI == none || PRI.DuelTeamID != MyDuelTeamID) // Not in the same team.
            return;

        ClientHUD = DMFFAHUD(myHUD);

        if (ClientHUD == none)
            return;

        if (ClientHUD.DuelTeamMemberArray.Find('AttachedPawn', P) == INDEX_NONE)
            ClientHUD.AddTeamMemberMarkerToHUD(P);

    }

}

/* Overridden methods. */

exec function ToggleHUDMarkers()
{

    /* Overridden to replace Steam Friends with Team Members Overlay. */

    local DMFFAHUD ClientHUD;

    if (!ScriptBlockedInputs[EINBLOCK_ToggleHUDMarkers])
    {

        iToggleHUDState = ((iToggleHUDState + 1) % 3);
        ClientHUD = DMFFAHUD(myHUD);

        if (ClientHUD == none)
            return;

        switch (iToggleHUDState)
        {

            case 0:

                ClientHUD.bDrawMarkers = false;
                ClientHUD.ShowDuelTeamMembers = false;
                break;

            case 1:

                ClientHUD.bDrawMarkers = true;
                ClientHUD.ShowDuelTeamMembers = false;
                break;

            default:

                ClientHUD.bDrawMarkers = true;
                ClientHUD.ShowDuelTeamMembers = true;
                break;

        }
        
    }

}

exec function SwitchTeam(); // No-op for DMFFA.
exec function ChangeTeam(optional string TeamName); // No-op for DMFFA.
exec function AdminChangeTeam(String PlayerName); // No-op for DMFFA.

exec function Suicide()
{

    if (!TrappedBetweenRealities && GetTimerCount('S_Suicide') == -1.f)
    {

        S_SendF10Message();
        SetTimer(suicideDelay, false, 'S_Suicide');

    }

}

exec function DoF10()
{

    if (!TrappedBetweenRealities && !ScriptBlockedInputs[EINBLOCK_F10] && Pawn != none && Pawn.Health > 0 && GetTimerCount('S_DoF10') == -1.f)
    {

        S_SendF10Message();
        SetTimer(suicideDelay, false, 'S_DoF10');

    }

}

reliable server function S_Suicide()
{

    local DMFFAPawn P;

    bJustSuicided =  true;
    P = DMFFAPawn(Pawn);
    P.ReplicatedHitInfo.DamageString = "5";
    P.ReplicatedHitInfo.DamageType = class'AOCDmgType_Swing';
    Pawn.TakeDamage(500.0f, none, Vect(0.f, 0.f, 0.f), Vect(0.f, 0.f, 0.f), class'AOCDmgType_Swing');

}

reliable server function S_DoF10()
{

    local DMFFAPawn P;

    P = DMFFAPawn(Pawn);
    P.ReplicatedHitInfo.DamageString = "M";
    P.ReplicatedHitInfo.bBreakAllBones = true;
    Pawn.TakeDamage(500.0f, none, Vect(0.f, 0.f, 0.f), Vect(0.f, 0.f, 0.f), class'AOCDmgType_Generic');

}

reliable client function ShowDefaultGameHeader()
{

    local DMFFAGRI GRI;
    local string ObjName, ObjDesc;

    GRI = DMFFAGRI(Worldinfo.GRI);

    if (GRI == none)
    {

        SetTimer(0.1f, false, 'ShowDefaultGameHeader');
        return;

    }

    ObjName = GRI.RetrieveObjectiveName(EFAC_FFA);
    ObjDesc = GRI.RetrieveObjectiveDescription(EFAC_FFA);
    ReceiveLocalizedHeaderText("<font color=\"#FFCC00\">"$ObjName$"</font>\n<font color=\"#B1D1FF\">"$ObjDesc$"</font>");

}

function SetReality(int NewRealityID, optional bool bForce)
{

    local DMFFAPlayerController PC;

    if (NewRealityID == RealityID)
        return;

    if (Worldinfo.NetMode == NM_Standalone)
        return;
    
    RealityID = NewRealityID;
    ClientSetReality(NewRealityID);

    if (!IsInState('Spectating') && !IsInState('SpecialSpectating')) // Tell all our spectators to switch reality with us.
    {

        foreach WorldInfo.AllControllers(class'DMFFAPlayerController', PC)
        {

            PC.UpdateSpectatorReality(self);

        }

    }

}

reliable client function ClientSetReality(int NewRealityID)
{

    // Set RealityID to NewRealityID (for rendering; setting client's RealityID will not affect the server or collision and so won't make haxing possible).
    RealityID = NewRealityID;
    class'Engine'.static.GetEngine().CurrentRealityID = NewRealityID;

}

simulated function UpdateWarmupCounter()
{

    if (!bIsWarmupFrozen)
        return;
    
    if (DuelCountdownTimeLeft >= 0)
    {

        ClearHeader();
        ReceiveLocalizedHeaderText(DuelCountdownString$"<br />"$(DuelCountdownTimeLeft--), 0.f);

    }

}

reliable client function ClientStartPawnSwapout()
{

    bPawnSwappingOut = true;

}

function EndPawnSwapout()
{

    bPawnSwappingOut = false;
    ClientEndPawnSwapout();

}

protected reliable client function ClientEndPawnSwapout()
{

    bPawnSwappingOut = false;

}

reliable server function GenericSwitchToObs(bool bSwitch, optional bool bUserChoice = false, optional bool bSpecialObserverMode = false)
{

    local DMFFAPRI PRI;
    local Vehicle DrivenVehicle;
    local DMFFAPawn P;
    local bool bOldVolSpecValue;

    PRI = DMFFAPRI(PlayerReplicationInfo);

    if (PRI == none)
        return;

    if (bSwitch)
    {

        // Kill pawn and don't respawn.

        iObserving = 1 + int(bUserChoice);
        
        if (bUserChoice)
        {

            ClearForceSwitchToObserver();
            SavedFamilyInfo = CurrentFamilyInfo;
            CurrentFamilyInfo = default.CurrentFamilyInfo;
            PRI.ToBeClass = class'DMFFAPRI'.default.ToBeClass;

        }

        DrivenVehicle = Vehicle(Pawn);

        if (DrivenVehicle != none)
            DrivenVehicle.DriverLeave(true);

        P = DMFFAPawn(Pawn);

        if (P != none && P.IsAliveAndWell())
            P.Died(self, class'AOCDmgType_Generic', vect(0.f, 0.f, 0.f));
        
        if (!bSpecialObserverMode)
        {

            ClientGotoState('Spectating');	
            ServerSpectate();

        }

        else
        {

            ClientGotoState('SpecialSpectating');	
            ServerSpecialSpectate();

        }

        if (bUserChoice)
        {

            DMFFA(WorldInfo.Game).DesertDuelTeam(self); // We want to kill the pawn first before deserting.
            ResetReality();

        }

    }

    else
    {

        if (SavedFamilyInfo != none && SavedFamilyInfo != class'AOCFamilyInfo_None')
        {

            // If we have not switched to a new class already.
            if (PRI.ToBeClass == class'AOCFamilyInfo_None')
            {

                CurrentFamilyInfo = SavedFamilyInfo;
                PRI.ToBeClass = SavedFamilyInfo;

            }

        }

        iObserving = 0;
        DMFFA(WorldInfo.Game).RestartPlayer(self);

    }

    bOldVolSpecValue = PRI.bIsVoluntarySpectator;
    PRI.bIsVoluntarySpectator = (bSwitch && bUserChoice);
    PlayerReplicationInfo.bNetDirty = (PlayerReplicationInfo.bNetDirty || bOldVolSpecValue != PRI.bIsVoluntarySpectator);

}

function bool AreWeaponsValidForCurrentFamilyInfo()
{

    local bool bFound;
    local SWeaponChoiceInfo WeaponChoiceInfo;
    local int i;
    local SWeaponChoiceInfo PrimaryWeaponChoiceInfo;
    local class<AOCWeapon> CWeapon;
    
    if (CurrentFamilyInfo == none)
        return false;
    
    // Kings and standalone don't play by the same rules.
    if (Worldinfo.NetMode == NM_Standalone || class<AOCFamilyInfo_Agatha_King>(CurrentFamilyInfo) != none || class<AOCFamilyInfo_Mason_King>(CurrentFamilyInfo) != none)
        return true;
    
    bFound = false;

    foreach CurrentFamilyInfo.default.NewPrimaryWeapons(WeaponChoiceInfo, i)
    {

        if (WeaponChoiceInfo.CWeapon == PrimaryWeapon)
        {

            PrimaryWeaponChoiceInfo = CurrentFamilyInfo.default.NewPrimaryWeapons[i];
            bFound = true;
            break;

        }

    }

    if (!bFound)
        return false;
    
    bFound = false;

    foreach CurrentFamilyInfo.default.NewSecondaryWeapons(WeaponChoiceInfo)
    {

        if (WeaponChoiceInfo.CWeapon == SecondaryWeapon)
        {

            bFound = true;
            break;

        }

    }

    if (!bFound)
    {

        foreach PrimaryWeaponChoiceInfo.CForceSecondary(CWeapon)
        {

            if (CWeapon == SecondaryWeapon)
            {

                bFound = true;
                break;

            }

        }

        if (!bFound)
            return false;

    }

    if (TertiaryWeapon != class'AOCWeapon_None') // Make sure we can set no tertiary weapons.
    {
    
        bFound = false;

        foreach CurrentFamilyInfo.default.NewTertiaryWeapons(WeaponChoiceInfo)
        {

            if (WeaponChoiceInfo.CWeapon == TertiaryWeapon)
            {

                bFound = true;
                break;

            }

            else if (class<AOCWeapon_Shield>(WeaponChoiceInfo.CWeapon) != none && class<AOCWeapon_Shield>(TertiaryWeapon) != none 
                     && class<AOCWeapon_Shield>(TertiaryWeapon).default.Shield == class<AOCWeapon_Shield>(WeaponChoiceInfo.CWeapon).default.Shield)
            {

                bFound = true;
                break;

            }

        }

        if (!bFound)
        {

            foreach PrimaryWeaponChoiceInfo.CForceTertiary(CWeapon)
            {

                if (CWeapon == TertiaryWeapon)
                {

                    bFound = true;
                    break;

                }

                else if (class<AOCWeapon_Shield>(CWeapon) != none && class<AOCWeapon_Shield>(TertiaryWeapon) != none 
                         && class<AOCWeapon_Shield>(TertiaryWeapon).default.Shield == class<AOCWeapon_Shield>(CWeapon).default.Shield)
                {

                    bFound = true;
                    break;

                }

            }

            if (!bFound)
                return false;

        }

    }
    
    return true;

}

reliable server function SetWeapons(class<AOCWeapon> prim, class<AOCWeapon> altprim, class<AOCWeapon> sec, class<AOCWeapon> tert)
{

    PrimaryWeapon = prim;
    AltPrimaryWeapon = altprim;
    SecondaryWeapon = sec;

    if (tert == none || class<AOCThrowableWeapon>(tert) != none)
        /* Cute... Trying to patch a memory address at the client side and attempting to use a throwable weapon.
           This could also happen when no tertiary weapon is available (Vanguard). */
        TertiaryWeapon = class'AOCWeapon_None';

    else
        TertiaryWeapon = tert;

    PlayerReplicationInfo.bReadyToPlay = true;

}

reliable server function FinishedChoosingLoadout()
{

    local DMFFA G;

    // Make sure we're no longer in observer mode.
    if (iObserving == 2)
        SwitchToObserverMode(0);

    SavedFamilyInfo = DMFFAPRI(PlayerReplicationInfo).ToBeClass;

    if (DMFFAPawn(Pawn) == none || !Pawn.IsAliveAndWell())
        return;

    G = DMFFA(WorldInfo.Game);

    if (!DuelInfo.status && !G.bGameEnded) // Allow instant loadout swap if we are not in a duel.
        G.LoadoutChangeSpawnPlayer(self);

}

function PreEndGame(EAOCFaction WinningTeam, string MapURL, string WinString, optional int WinningTeamSize = 0, optional PlayerReplicationInfo WinnerPRI = none)
{

    StatWrapper.PerformGameEndFlush(WinningTeam, MapEnumFromURL(MapURL), 0);
    ClientPreEndGame(WinString, (GetDuelLeader().PlayerReplicationInfo == WinnerPRI));

}

reliable client function ClientPreEndGame(string WinString, bool bWinner)
{

    if (bWinner)
        PlaySound(GameCompletionStingers.Complete[Rand(2)], true);

    else
        PlaySound(GameCompletionStingers.Failure[Rand(2)], true);

    ClearTimer('MapTimerCallback');
    Pawn.ZeroMovementVariables();
    bIsGameEnded = true;
    bIsWinner = bWinner;
    CurrentMemTimer = ACTUAL_ENDGAME_TIME;
    ClearHeader();
    ReceiveLocalizedHeaderText(WinString, ACTUAL_ENDGAME_TIME);

}

function bool CustomizationInfoIsValid()
{

    local int TeamID;

    TeamID = TeamForDuel;

    return class'AOCCustomization'.static.AreCustomizationChoicesValidFor(CustomizationInfo, TeamID, CurrentFamilyInfo.default.ClassReference, PlayerReplicationInfo);

}

reliable client function ClientUpdateCustomizationInfo(EAOCFaction Faction, EAOCClass ClassReference)
{

    ServerUpdateCustomizationInfo(CustomizationClass.static.LocalGetCustomizationChoices(Faction, ClassReference));
    CheckForDevCustomizations(Faction, ClassReference);

}

reliable client function ClientUpdateCurrentCustomizationInfo()
{

    CheckForDevCustomizations(TeamForDuel, CurrentFamilyInfo.default.ClassReference);
    ServerUpdateCurrentCustomizationInfo(CustomizationClass.static.LocalGetCustomizationChoices(TeamForDuel, CurrentFamilyInfo.default.ClassReference), TeamForDuel, CurrentFamilyInfo.default.ClassReference);

}

reliable server function ServerUpdateCurrentCustomizationInfo(SCustomizationChoice NewCustomization, EAOCFaction Faction, EAOCClass ClassReference)
{

    if (Faction == TeamForDuel && ClassReference == CurrentFamilyInfo.default.ClassReference)
        ServerUpdateCustomizationInfo(NewCustomization);

}

function ChangeToNewTeam()
{

    ServerChangeTeam(TeamForDuel);
    PreviousFamilyInfo = CurrentFamilyInfo;

}

reliable server function ServerChangeTeam(int N)
{

    LastTimeTeamChanged = Worldinfo.TimeSeconds;
    DMFFA(WorldInfo.Game).ChangeTeam(self, N, true);

    if (bGettingReady)
        PlayerReplicationInfo.bNetDirty = true;

}

function SetNewClass(class<AOCFamilyInfo> InputFamily, optional bool bNegPoints = true, optional bool bForceSwitch = false, optional SCustomizationChoice CustomizationChoices)
{

    if (DuelInfo.status && !bForceSwitch) // Not allowed to change classes during duel.
        return;

    if (CustomizationChoices.Character == -1 || CurrentFamilyInfo != InputFamily)
    {

        bWaitingForCustomizationInfo = true;
        ClientUpdateCustomizationInfo(TeamForDuel, InputFamily.default.ClassReference);

    }

    else
    {

        bWaitingForCustomizationInfo = false;
        CustomizationInfo = CustomizationChoices;

    }

    if (CurrentFamilyInfo != InputFamily)
    {

        CurrentFamilyInfo = InputFamily;
        ClientSetNewClass(InputFamily);
        DMFFAPRI(PlayerReplicationInfo).ToBeClass = InputFamily;

        if (!bForceSwitch)
            DMFFA(WorldInfo.Game).LocalizedPrivateMessage(self, 11,
                                                          class'AOCSystemMessages'.static.CreateLocalizationdata("INVALIDDATA", "", ""),
                                                          class'AOCSystemMessages'.static.CreateLocalizationdata("INVALIDDATA", InputFamily.default.FamilyID, ""));

    }

}

protected reliable client function ClientSetNewClass(class<AOCFamilyInfo> InputFamily)
{

    CurrentFamilyInfo = InputFamily;

}

function ChangeToNewClass()
{

    local int TeamID;
    local bool bIsCustomizationInfoValid;
    local DMFFAPawn P;

    TeamID = TeamForDuel;

    if (!AreWeaponsValidForCurrentFamilyInfo())
        FindFirstAvailableLoadoutForCurrentFamilyInfo();

    bIsCustomizationInfoValid = CustomizationClass.static.AreCustomizationChoicesValidFor(CustomizationInfo, TeamID, CurrentFamilyInfo.default.ClassReference, PlayerReplicationInfo);
    P = DMFFAPawn(Pawn);

    if (bIsCustomizationInfoValid)
        P.PawnInfo.myCustomization = CustomizationInfo;

    else
    {

        P.PawnInfo.myCustomization.TabardColor1 = CustomizationClass.static.GetDefaultTabardColor(TeamID, 0);
        P.PawnInfo.myCustomization.TabardColor2 = CustomizationClass.static.GetDefaultTabardColor(TeamID, 1);
        P.PawnInfo.myCustomization.TabardColor3 = CustomizationClass.static.GetDefaultTabardColor(TeamID, 2);
        P.PawnInfo.myCustomization.EmblemColor1 = CustomizationClass.static.GetDefaultEmblemColor(TeamID, 0);
        P.PawnInfo.myCustomization.EmblemColor2 = CustomizationClass.static.GetDefaultEmblemColor(TeamID, 1);
        P.PawnInfo.myCustomization.EmblemColor3 = CustomizationClass.static.GetDefaultEmblemColor(TeamID, 2);
        P.PawnInfo.myCustomization.ShieldColor1 = CustomizationClass.static.GetDefaultShieldPatternColor(TeamID, 0);
        P.PawnInfo.myCustomization.ShieldColor2 = CustomizationClass.static.GetDefaultShieldPatternColor(TeamID, 1);
        P.PawnInfo.myCustomization.ShieldColor3 = CustomizationClass.static.GetDefaultShieldPatternColor(TeamID, 2);

    }

    P.TeamForDuel = TeamForDuel;
    P.PawnInfo.myFamily = CurrentFamilyInfo;
    P.PawnInfo.myPrimary = PrimaryWeapon;
    P.PawnInfo.myAlternatePrimary = AltPrimaryWeapon;
    P.PawnInfo.mySecondary = SecondaryWeapon;
    P.PawnInfo.myTertiary = TertiaryWeapon;
    DMFFAPRI(Pawn.PlayerReplicationInfo).MyFamilyInfo = CurrentFamilyInfo;
    P.ReplicatedEvent('PawnInfo');

}

/* We don't care for steam friends. We want to show team members instead.
   All no-op for DMFFA. */

function ChangeShowSteamFriends(bool bShow);
reliable server function S_ChangeShowSteamFriends(bool bShow);
reliable client function C_ShowSteamFriendsAcknowledge();
reliable server function S_AddNewFriendForMarker(UniqueNetId ID);
function AddFriendMarkerToHUD(AOCPawn FriendPawn);

DefaultProperties
{

    AllowedToSpawn = true
    InstantSpawn = true
    TrappedBetweenRealities = false
    TeamForDuel = EFAC_FFA
    TargetPlayerScalar = 635.f
    InitDuelCountdown = 4.f
    DuelCountdown = 4.f
    ResetPlayerAfterDuelIn = 5.f
    DuelGetReadySoundCue = SoundCue'A_Meta.Duel_Ready'
    DuelFightSoundCue = SoundCue'A_Meta.Duel_Fight'

}
