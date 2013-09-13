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

class DMFFAHUD extends AOCFFAHUD;

// Team Member HUD Marker struct.
struct TeamMemberHUDMarkerInfo
{

    var GFxObject Obj;
    var DMFFAPawn AttachedPawn;

};

var bool ShowDuelTeamMembers;
var array<TeamMemberHUDMarkerInfo> DuelTeamMemberArray;

/* Overridden methods. */

exec function ShowTeamSelect(int ForceTeam)
{

    local DMFFAPlayerController PC;

    PC = DMFFAPlayerController(PlayerOwner);

    if (PC == none)
        return;

    if (!PC.bCanChangeClass || PC.ScriptBlockedInputs[EINBLOCK_TeamSelect])
        return;

    if (CharManager != none)
        return;

    PC.SetReady(false);
    CharManager = DMFFAGFx_CharacterSelManager(OpenGFxScene(CharManager, class'DMFFAGFx_CharacterSelManager',,,true, true, false));
    CharManager.StartMenu = 0;
    CharManager.Start();

}

exec function ShowClassSelect()
{

    local DMFFAPlayerController PC;

    PC = DMFFAPlayerController(PlayerOwner);

    if (PC == none)
        return;

    if (!PC.bCanChangeClass || PC.ScriptBlockedInputs[EINBLOCK_ClassSelect])
        return;

    if (CharManager != none)
        return;

    if (SelectedTeam < 0)
    {

        // Haven't selected a team yet.
        ShowTeamSelect(-1);
        return;

    }

    SelectedTeam = 2;
    PC.SetReady(false);
    CharManager = DMFFAGFx_CharacterSelManager(OpenGFxScene(CharManager, class'DMFFAGFx_CharacterSelManager',,,true, true, false));
    CharManager.StartMenu = 1;
    CharManager.Start();

}

exec function ShowWeaponSelect()
{

    local DMFFAPlayerController PC;

    PC = DMFFAPlayerController(PlayerOwner);

    if (PC == none)
        return;

    if (!PC.bCanChangeClass)
        return;

    if (CharManager != none)
        return;

    if (SelectedTeam < 0)
    {

        // Haven't selected a team yet.
        ShowTeamSelect(-1);
        return;

    }

    if (SelectedClass < 0)
    {

        // Haven't selected a class yet.
        ShowClassSelect();
        return;

    }

    SelectedTeam = 2;
    PC.SetReady(false);
    CharManager = DMFFAGFx_CharacterSelManager(OpenGFxScene(CharManager, class'DMFFAGFx_CharacterSelManager',,,true, true, false));
    CharManager.StartMenu = 2;
    CharManager.Start();

}

function DisplayMatchTime(int Time, bool Enabled)
{

    local string TimeString;

    if (!CheckCanUseSB())
        return;

    if (Time >= 0)
        TimeString = ParseTime(Time);

    else
        TimeString = Chr(8734); // Infinity.

    HUD.Scoreboard.UpdateTimerText(TimeString);

}

function ShowOverlay()
{

    local DynHUDMarkerInfo Inf;
    local AOCHUDMarker HUDMarker;
    local string AgathaText, MasonText;

    if (Overlay == none)
    {

        Overlay = DMFFAGFx_HUD_Overlay(OpenGFxScene(Overlay, class'DMFFAGFx_HUD_Overlay', false, false,,,false));
        Overlay.Start();

        // Notify Overlay of the world HUD Markers
        foreach WorldDynamicHUDMarkers(Inf)
        {

            HUDMarker = AOCHUDMarker(Inf.RelAct);

            if (HUDMarker != none)
            {

                if (!HUDMarker.bUseTextAsLocalizationKey)
                    Overlay.AddWorldHUDMarker(HUDMarker.FloatTextAgatha, HUDMarker.FloatTextMason, Inf.RelAct.bUseProgressBar, Inf.RelAct.fCurrentProgressValue, Inf.RelAct.fMaxValueProgress);

                else
                {

                    AgathaText = ((HUDMarker.FloatTextAgatha != "") ? Localize(HUDMarker.SectionName, HUDMarker.FloatTextAgatha, HUDMarker.PackageName) : "");
                    MasonText = ((HUDMarker.FloatTextMason != "") ? Localize(HUDMarker.SectionName, HUDMarker.FloatTextMason, HUDMarker.PackageName) : "");
                    Overlay.AddWorldHUDMarker(AgathaText, MasonText, Inf.RelAct.bUseProgressBar, Inf.RelAct.fCurrentProgressValue, Inf.RelAct.fMaxValueProgress);

                }

            }

            else
            {

                AgathaText = Localize("HudMarker", Inf.RelAct.sHUDMarkerAgathaText, "AOCMaps");
                MasonText = Localize("HudMarker", Inf.RelAct.sHUDMarkerMasonText, "AOCMaps");
                Overlay.AddWorldHUDMarker(AgathaText, MasonText, Inf.RelAct.bUseProgressBar, Inf.RelAct.fCurrentProgressValue, Inf.RelAct.fMaxValueProgress);

            }

        }

        foreach AmmoBoxMarkers(Inf)
        {

            Overlay.AddAmmoBoxMarker();

        }

    }

}

function AddTeamMemberMarkerToHUD(DMFFAPawn P)
{

    local TeamMemberHUDMarkerInfo NewMarker;

    if (Overlay == none)
        return;

    NewMarker = DMFFAGFx_HUD_Overlay(Overlay).CreateTeamMemberMarker(P);
    DuelTeamMemberArray.AddItem(NewMarker);

}

function UpdateDynamicHUDMarkers()
{

    super.UpdateDynamicHUDMarkers();

    if (Overlay != none)
        DMFFAGFx_HUD_Overlay(Overlay).UpdateAllTeamMemberHUDMarkers(bDrawMarkers && ShowDuelTeamMembers);

}

DefaultProperties
{

    HUDClass = class'DMFFAGFx_HUDManager'
    ShowDuelTeamMembers = true

}