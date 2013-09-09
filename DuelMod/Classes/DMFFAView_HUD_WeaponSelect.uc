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

class DMFFAView_HUD_WeaponSelect extends AOCView_HUD_WeaponSelect;

function UpdateLocks()
{

    /* Check to see if we need to lock any weapons based on selected weapon change (primary). */

    local DMFFAPlayerController PC;
    local bool IsBetaApp;
    local bool bFindLock;
    local SWeaponChoiceInfo Tmp;
    local int i;
    local bool TmpDisable;
    local GFxObject Unlock, UnlockProgress;
    local array< class<AOCWeapon> > AllForceTert;

    PC = DMFFAPlayerController(Manager.PlayerOwner);

    if (PC == none)
        return;

    IsBetaApp = class'AOCSteamworksUtil'.static.IsBetaApp();
    bFindLock = false;

    // Set default lock/unlocked first.

    foreach PrimWeaps(Tmp, i)
    {

        if (IsBetaApp)
            Tmp.UnlockExpLevel = 0;

        TmpDisable = (!Tmp.bEnabledDefault || PC.StatWrapper.CacheAllExpValues[Tmp.CheckLimitExpGroup] < Tmp.UnlockExpLevel);
        PrimarySelectWidgets[i].Obj.SetVisible(true);
        PrimarySelectWidgets[i].Obj.SetBool("disabled", TmpDisable);
        PrimarySelectWidgets[i].bEnabled = !TmpDisable;
        Unlock = PrimarySelectWidgets[i].Obj.GetObject("unlock");

        if (TmpDisable)
        {

            Unlock.GotoAndStop("locked");
            UnlockProgress = Unlock.GetObject("progress");

            if (!bFindLock)
            {

                Unlock.GetObject("num").SetText(string(int(Tmp.UnlockExpLevel - PC.StatWrapper.CacheAllExpValues[Tmp.CheckLimitExpGroup])));
                UnlockProgress.SetFloat("minimum", PrimWeaps[i-1].UnlockExpLevel);
                UnlockProgress.SetFloat("maximum", Tmp.UnlockExpLevel);
                UnlockProgress.SetFloat("value", PC.StatWrapper.CacheAllExpValues[Tmp.CheckLimitExpGroup]);
                bFindLock = true;

            }

            else
            {

                Unlock.GetObject("num").SetText("");
                UnlockProgress.SetFloat("minimum", 0.f);
                UnlockProgress.SetFloat("maximum", 1.f);
                UnlockProgress.SetFloat("value", 0.f);

            }

        }

        else
        {

            bFindLock = false;
            Unlock.GotoAndStop("unlocked");

        }

    }

    for (i = i+1; i < 12; i++)
    {

        PrimarySelectWidgets[i].Obj.SetVisible(false);
        PrimarySelectWidgets[i].Obj.SetBool("disabled", true);
        PrimarySelectWidgets[i].bEnabled = false;

    }

    bFindLock = false;

    foreach SecWeaps(Tmp, i)
    {

        if (IsBetaApp)
            Tmp.UnlockExpLevel = 0;

        TmpDisable = (!Tmp.bEnabledDefault || PC.StatWrapper.CacheAllExpValues[Tmp.CheckLimitExpGroup] < Tmp.UnlockExpLevel);
        SecondarySelectWidgets[i].Obj.SetVisible(true);
        SecondarySelectWidgets[i].Obj.SetBool("disabled", TmpDisable);
        SecondarySelectWidgets[i].bEnabled = !TmpDisable;
        Unlock = SecondarySelectWidgets[i].Obj.GetObject("unlock");

        if (TmpDisable)
        {

            Unlock.GotoAndStop("locked");
            UnlockProgress = Unlock.GetObject("progress");

            if (!bFindLock)
            {

                Unlock.GetObject("num").SetText(string(int(Tmp.UnlockExpLevel - PC.StatWrapper.CacheAllExpValues[Tmp.CheckLimitExpGroup])));
                UnlockProgress.SetFloat("minimum", SecWeaps[i-1].UnlockExpLevel);
                UnlockProgress.SetFloat("maximum", Tmp.UnlockExpLevel);
                UnlockProgress.SetFloat("value", PC.StatWrapper.CacheAllExpValues[Tmp.CheckLimitExpGroup]);
                bFindLock = true;

            }

            else
            {

                Unlock.GetObject("num").SetText("");
                UnlockProgress.SetFloat("minimum", 0.f);
                UnlockProgress.SetFloat("maximum", 1.f);
                UnlockProgress.SetFloat("value", 0.f);
                
            }

        }

        else
        {

            bFindLock = false;
            Unlock.GotoAndStop("unlocked");

        }

    }

    for (i = i+1; i < 6; i++)
    {

        SecondarySelectWidgets[i].Obj.SetVisible(false);
        SecondarySelectWidgets[i].Obj.SetBool("disabled", true);
        SecondarySelectWidgets[i].bEnabled = false;

    }

    // Analyze forced weapons for currently selected primary (just tertiaries for the primary weapons).
    AllForceTert = PrimWeaps[SelectedPrimary].CForceTertiary;

    foreach TertWeaps(Tmp, i)
    {

        TertiarySelectWidgets[i].Obj.SetVisible(true);
        TertiarySelectWidgets[i].Obj.GetObject("unlock").GotoAndStop("unlocked");

        if (AllForceTert.Length > 0)
            TmpDisable = AllForceTert.Find(Tmp.CWeapon) == INDEX_NONE;

        else
            // Throwables disabled for DMFFA.
            TmpDisable = (!Tmp.bEnabledDefault || class<AOCThrowableWeapon>(Tmp.CWeapon) != none);

        TertiarySelectWidgets[i].Obj.SetBool("disabled", TmpDisable);
        TertiarySelectWidgets[i].bEnabled = !TmpDisable;

        if (TmpDisable)
            TertiarySelectWidgets[i].Obj.SetString("label", "");

        else
            TertiarySelectWidgets[i].Obj.SetString("label", Tmp.CWeapon.default.WeaponFontSymbol);

    }

    for (i = i+1; i < 7; i++)
    {

        TertiarySelectWidgets[i].Obj.SetVisible(false);
        TertiarySelectWidgets[i].Obj.SetBool("disabled", true);
        TertiarySelectWidgets[i].bEnabled = false;

    }

    // Check SelectedTertiary and modify if necessary.
    if (!TertiarySelectWidgets[SelectedTertiary].bEnabled)
    {

        // Modify accordingly to become the first available tertiary weapon.
        foreach TertWeaps(Tmp, SelectedTertiary)
        {
     
            if (TertiarySelectWidgets[SelectedTertiary].bEnabled)
                break;

        }

    }

}

function SelectRandomLoadout()
{

    /* Picks random loadout. */

    local array<int> AvailableWeapons;
    local int i;

    // Make list of primaries that are available and choose one randomly.

    for (i = 0; i < 12; i++)
    {

        if (PrimarySelectWidgets[i].bEnabled)
            AvailableWeapons.AddItem(i);

    }

    SelectedPrimary = AvailableWeapons[Rand(AvailableWeapons.Length)];
    AvailableWeapons.Remove(0, AvailableWeapons.Length);

    // Do the same for secondaries.

    for (i = 0; i < 6; i++)
    {

        if (SecondarySelectWidgets[i].bEnabled)
            AvailableWeapons.AddItem(i);

    }

    SelectedSecondary = AvailableWeapons[Rand(AvailableWeapons.Length)];
    AvailableWeapons.Remove(0, AvailableWeapons.Length);

    // And for tertiaries! but update locks.

    UpdateLocks();

    for (i = 0; i < 7; i++)
    {

        if (TertiarySelectWidgets[i].bEnabled)
            AvailableWeapons.AddItem(i);

    }

    if (AvailableWeapons.Length > 0)
        SelectedTertiary = AvailableWeapons[Rand(AvailableWeapons.Length)];

}

function UpdateBottomBar()
{

    /* Update bottom bar information. */

    // Get Primary.
    PrimaryImage.SetString("source", "img://"$PrimWeaps[SelectedPrimary].CWeapon.default.WeaponSmallPortrait);
    PrimaryText.SetText(PrimWeaps[SelectedPrimary].CWeapon.default.WeaponName);

    // Get Secondary.
    SecondaryImage.SetString("source", "img://"$SecWeaps[SelectedSecondary].CWeapon.default.WeaponSmallPortrait);
    SecondaryText.SetText(SecWeaps[SelectedSecondary].CWeapon.default.WeaponName);

    // Get Tertiary.
    if (TertiarySelectWidgets[SelectedTertiary].bEnabled)
    {

        SpecialImage.SetString("source", "img://"$TertWeaps[SelectedTertiary].CWeapon.default.WeaponSmallPortrait);
        SpecialText.SetText(TertWeaps[SelectedTertiary].CWeapon.default.WeaponName);

    }

    else
    {

        SpecialImage.SetString("source", "");
        SpecialText.SetText("");

    }

}

function JoinGame()
{

    local DMFFAPlayerController PC;

    PC = DMFFAPlayerController(Manager.PlayerOwner);

    if (PC == none)
        return;

    PC.AOCWeaponSelectMenu = none;
    PC.SetWeapons(PrimWeaps[SelectedPrimary].CWeapon, 
                  PrimWeaps[SelectedPrimary].CWeapon.default.AlternativeMode,
                  SecWeaps[SelectedSecondary].CWeapon, 
                  TertWeaps[SelectedTertiary].CWeapon);
    PC.ServerRequestSetNewClass(FamInfo);
    PC.FinishedChoosingLoadout();
    DMFFAHUD(PC.myHUD).EarlyExitSelection(PrimWeaps[SelectedPrimary].CWeapon, SecWeaps[SelectedSecondary].CWeapon, true);
    PC.SetReady(true);

}