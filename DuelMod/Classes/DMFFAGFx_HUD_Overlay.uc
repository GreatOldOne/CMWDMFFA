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

class DMFFAGFx_HUD_Overlay extends AOCGFx_HUD_Overlay
    DependsOn(DMFFAHUD);

`include(DuelMod/Include/DuelMod.uci)

/* Team Member HUD Marker. */

var ASColorTransform DuelLeaderColor;
var int TeamMemberHUDMarkerID;

function ClearTeamMemberHUDMarkers()
{

    local DMFFAHUD MyHUD;
    local ASValue asval;
    local array<ASValue> args;
    local TeamMemberHUDMarkerInfo Inf;

    MyHUD = DMFFAHUD(PlayerOwner.myHUD);

    if (MyHUD == none)
        return;

    asval.Type = AS_Null;
    args[0] = asval;

    foreach MyHUD.DuelTeamMemberArray(Inf)
    {

        Inf.Obj.Invoke("removeMovieClip", args);

    }

    MyHUD.DuelTeamMemberArray.Remove(0, MyHUD.DuelTeamMemberArray.Length);

}

function TeamMemberHUDMarkerInfo CreateTeamMemberMarker(DMFFAPawn P)
{

    local TeamMemberHUDMarkerInfo Inf;

    Inf.Obj = RootObject.AttachMovie("FriendMarker", "FriendMarker"$(TeamMemberHUDMarkerID++));

    if (DMFFAPRI(P.PlayerReplicationInfo).IsDuelLeader) // Team leaders will never change. We can set the special color here.
        Inf.Obj.GetObject("FriendText").SetColorTransform(DuelLeaderColor);

    Inf.AttachedPawn = P;

    return Inf;

}

function RemoveTeamMemberHUDMarkers(array<TeamMemberHUDMarkerInfo> RemoveMarkers)
{

    local DMFFAHUD MyHUD;
    local ASValue asval;
    local array<ASValue> args;
    local TeamMemberHUDMarkerInfo Inf;

    MyHUD = DMFFAHUD(PlayerOwner.myHUD);

    if (MyHUD == none)
        return;

    asval.Type = AS_Null;
    args[0] = asval;

    foreach RemoveMarkers(Inf)
    {

        Inf.Obj.Invoke("removeMovieClip", args);
        MyHUD.DuelTeamMemberArray.RemoveItem(Inf);

    }

}

function UpdateAllTeamMemberHUDMarkers(bool bShow)
{

    local DMFFAPlayerController PC;
    local int MyDuelTeamID;
    local DMFFAHUD MyHUD;
    local TeamMemberHUDMarkerInfo Inf;
    local DMFFAPRI PRI;
    local Vector Loc;
    local array<TeamMemberHUDMarkerInfo> RemoveMarkers;

    PC = DMFFAPlayerController(PlayerOwner);

    if (PC == none)
        return;

    MyDuelTeamID = DMFFAPRI(PC.PlayerReplicationInfo).DuelTeamID;
    MyHUD = DMFFAHUD(PC.myHUD);

    if (MyHUD == none)
        return;
    
    if (MyDuelTeamID == NO_DUEL_TEAM_ID) // Not in a team.
    {

        if (MyHUD.DuelTeamMemberArray.Length > 0) // No longer in a team, but we still have some markers left behind.
            ClearTeamMemberHUDMarkers();

        return;

    }

    foreach MyHUD.DuelTeamMemberArray(Inf)
    {

        // Second check in case the pawn updated status after it was placed in the array.
        if (Inf.AttachedPawn != none && Inf.AttachedPawn.IsAliveAndWell())
        {

            PRI = DMFFAPRI(Inf.AttachedPawn.PlayerReplicationInfo);

            if (PRI != none && PRI.DuelTeamID == MyDuelTeamID)
            {

                Inf.Obj.GetObject("FriendText").SetText(PRI.PlayerName);
                Loc = MyHUD.Canvas.Project(Inf.AttachedPawn.Location + Vect(0.f, 0.f, 80.f));
                Inf.Obj.SetFloat("_x", Loc.X);
                Inf.Obj.SetFloat("_y", Loc.Y);
                Inf.Obj.SetVisible(bShow && PC.CheckCanSeeObject(Inf.AttachedPawn, -1.f));
                continue;

            }

        }

        RemoveMarkers.AddItem(Inf);

    }

    if (RemoveMarkers.Length > 0)
        RemoveTeamMemberHUDMarkers(RemoveMarkers); // Disable any no longer desired markers.

}

DefaultProperties
{

    DuelLeaderColor = (multiply = (R = 0.f, G = 0.f, B = 0.f, A = 1.f), add = (R = 1.f, G = 0.4f, B = 0.f, A = 0.f))
    TeamMemberHUDMarkerID = 0

}