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

class DMFFAView_HUD_TeamSelect extends AOCView_HUD_TeamSelect;

// Number of Teams.
var int PlayingTeamSize;
var int SpectatorTeamSize;

// Playing/Spectator Team Count.
var GFxClikWidget PlayingCount;
var GFxClikWidget SpectatorCount;

// Play and Spectator Buttons (Images).
var GFxObject PlayButton;
var GFxObject SpectatorButton;

/** 
 *  Process the initialization of views and other items here.
 */
event bool WidgetInitialized(name WidgetName, name WidgetPath, GFxObject Widget)
{
  
    local bool bResult;

    bResult = false;

    switch (WidgetName)
    {

        case ('JoinSpectators'):

            SpectateButton = GFxClikWidget(Widget);
            SpectateButton.SetVisible(false);
            AllWidgets.AddItem(Widget);
            bResult = true;
            break;

        case ('AgathaSelect'):

            InitializeCallbackHandler(GFxClikWidget(Widget));
            AllWidgets.AddItem(Widget);
            bResult = true;
            break;

        case ('MasonSelect'):

            InitializeCallbackHandler(GFxClikWidget(Widget));
            AllWidgets.AddItem(Widget);
            bResult = true;
            break;

        case ('RandomSelect'):

            RandomButton = GFxClikWidget(Widget);
            RandomButton.SetVisible(false);
            AllWidgets.AddItem(Widget);
            bResult = true;
            break;

        case ('ExitButton'):

            Widget.SetString("label", Localize("Common", "Return", "AOCUI"));
            ReturnButton = GFxClikWidget(Widget);
            InitializeCallbackHandler(ReturnButton);
            AllWidgets.AddItem(Widget);
            bResult = true;
            break;

        case ('agatha_number'):

            PlayingCount = GFxClikWidget(Widget);
            PlayingCount.SetText(string(PlayingTeamSize));
            AllWidgets.AddItem(Widget);
            CountTeamSize();
            bResult = true;
            break;

        case ('mason_number'):

            SpectatorCount = GFxClikWidget(Widget);
            SpectatorCount.SetText(string(SpectatorTeamSize));
            AllWidgets.AddItem(Widget);
            CountTeamSize();
            bResult = true;
            break;

        case ('agatha_task'):

            AgathaTask = GFxClikWidget(Widget);
            AgathaTask.SetVisible(false);
            AllWidgets.AddItem(Widget);
            bResult = true;
            break;

        case ('mason_task'):

            MasonTask = GFxClikWidget(Widget);
            MasonTask.SetVisible(false);
            AllWidgets.AddItem(Widget);
            bResult = true;
            break;

        case ('AgathaKnights'):

            Widget.SetText("Play");
            break;

        case ('MasonOrder'):

            Widget.SetText("Spectate");
            break;

        case ('AgathaDescriptionBody'):
        case ('MasonDescriptionBody'):

            Widget.SetText(Localize("Common", string(WidgetName), "AOCUI"));
            break;

        case ('AgathaDescriptionTitle'):

            Widget.SetText(Localize("Common", "AgathaKnights", "AOCUI"));
            break;

        case ('MasonDescriptionTitle'):

            Widget.SetText(Localize("Common", "MasonOrder", "AOCUI"));
            break;

        default:

            AllWidgets.AddItem(Widget);
            break;

    }

    if (!bResult)
        bResult = super(AOCGFxView).WidgetInitialized(WidgetName, WidgetPath, Widget);

    return bResult;

}

/* Called when CLIK_press event fired. */
function OnClickHandler(GFxClikWidget.EventData Params)
{

    local DMFFAPlayerController PC;
    local DMFFAHUD MyHUD;

    PC = DMFFAPlayerController(Manager.PlayerOwner);

    if (PC == none)
        return;

    MyHUD = DMFFAHUD(PC.myHUD);

    if (MyHUD == none)
        return;

    Manager.TimeElapsedSinceUpdate = 0.f;

    switch (Params.target.GetString("_name"))
    {

        case "AgathaSelect":

            MyHUD.SelectedTeam = 2;
            Manager.LoadViewByName("ClassSelect");
            break;

        case "MasonSelect":

            // Join Spectator Team - We can end class selection now.
            MyHUD.SelectedTeam = -1;
            PC.JoinSpectatorTeam();
            MyHUD.EarlyExitSelection();
            PC.LeaveTempTeam(true);
            break;

        case "ExitButton":

            OnEscapeKeyPress();
            break;

    }

}

// Update Information
function UpdateInformation()
{

    CountTeamSize();
    PlayingCount.SetText(Repl(Localize("Common", "NumPlayers", "AOCUI"), "{NUM}", string(PlayingTeamSize), false));
    SpectatorCount.SetText(Repl(Localize("Common", "NumPlayers", "AOCUI"), "{NUM}", string(SpectatorTeamSize), false));

}

function PerformPostOnTop()
{

    PlayButton = GetObject("container").GetObject("bg").GetObject("agatha_select");
    SpectatorButton =  GetObject("container").GetObject("bg").GetObject("mason_select");
    PlayButton.GetObject("fullsymbol").SetVisible(false);
    SpectatorButton.GetObject("fullsymbol").SetVisible(false);

}

function CountTeamSize()
{

    local PlayerReplicationInfo PRI;
    local DMFFAPRI PlayerPRI;

    if (Manager.PlayerOwner == none)
        return;

    PlayingTeamSize = 0;
    SpectatorTeamSize = 0;

    foreach Manager.PlayerOwner.WorldInfo.GRI.PRIArray(PRI)
    {

        PlayerPRI = DMFFAPRI(PRI);

        if (PlayerPRI.bIsVoluntarySpectator)
            SpectatorTeamSize++;

        else if (PlayerPRI.bDisplayOnScoreboard && !PlayerPRI.bOnlySpectator && PlayerPRI.ToBeClass.default.FamilyFaction != EFAC_NONE)
            PlayingTeamSize++;

    }

}

DefaultProperties
{

    PlayingTeamSize = -1
    SpectatorTeamSize = -1

}