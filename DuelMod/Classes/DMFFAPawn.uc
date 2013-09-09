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

class DMFFAPawn extends AOCPawn;

var EAOCFaction TeamForDuel;

replication
{

    if (bNetDirty && Role == ROLE_AUTHORITY)
        TeamForDuel;

}

// We will make sure the weapon state is active before destroying the pawn.

function ResetWeaponStateToActive()
{

    if (Weapon.GetStateName() != 'Active')
        Weapon.GotoState('Active');

    ClientResetWeaponStateToActive();

}

protected reliable client function ClientResetWeaponStateToActive()
{

    if (Weapon.GetStateName() != 'Active')
        Weapon.GotoState('Active');

}

protected reliable server function TeamDuelProcessZMenuVO(int index)
{

    local DMFFA G;

    G = DMFFA(WorldInfo.Game);

    if (!G.bGameStarted || G.bGameEnded || !G.bAllowTeamDuels) // Is Team Duels allowed?
        return;

    switch (index)
    {

        case 0:

            G.InvitePlayerToTeam(self);
            break;

        case 2:

            G.DisbandDuelTeam(self);
            break;

        default:
            break;

    }

}

protected reliable server function TeamDuelProcessXMenuVO(int index)
{

    local DMFFA G;

    G = DMFFA(WorldInfo.Game);

    if (!G.bGameStarted || G.bGameEnded || !G.bAllowTeamDuels) // Is Team Duels allowed?
        return;

    switch (index)
    {

        case 0:

            G.AcceptTeamInvitation(self);
            break;

        case 1:

            G.DeclineTeamInvitation(self);
            break;

        case 6:

            G.LeaveDuelTeam(self);
            break;

        default:
            break;

    }

}

/* Overridden methods. */

simulated event Tick(float DeltaTime)
{

    local DMFFAPlayerController LocalPC;

    super.Tick(DeltaTime);

    if (WorldInfo.NetMode == NM_Client)
    {

        LocalPC = DMFFAPlayerController(GetALocalPlayerController());

        if (LocalPC != none)
            LocalPC.AddTeamMemberMarkerToHUD(self);

    }

}

simulated function AOCSetCharacterClassFromInfo(class<AOCFamilyInfo> Info)
{

    super.AOCSetCharacterCLassFromInfo(Info);

    // Override Team Collision (bubble) for team duels.

    switch (TeamForDuel)
    {

        case EFAC_AGATHA:

            TeamCollisionID = 1;
            break;

        case EFAC_MASON:

            TeamCollisionID = 2;
            break;

        case EFAC_FFA:

            TeamCollisionID = 3;
            break;

        default:

            TeamCollisionID = 0;
            break;

    }

}

simulated function PlayZMenuVO(int index)
{

    local DMFFAPlayerController PC;
    local SoundCue voSound;

    if (WorldInfo.NetMode == NM_DedicatedServer)
        return;

    if (!VOSoundComp.IsPlaying() && Physics != PHYS_Falling && !bIsBurning)
    {

        PC = DMFFAPlayerController(Controller);

        if (PC != none) // Update target player as soon as voicechat is triggered.
            PC.UpdateTargetPlayerController();

        class<AOCPawnSoundGroup>(SoundGroupClass).static.getAOCZMenuVO(self, index, voSound);
        VOSoundComp.SoundCue = voSound;
        VOSoundComp.Play();

        if (Role < ROLE_Authority || WorldInfo.NetMode == NM_STANDALONE)
        {

            s_PlayVO(voSound);
            TeamDuelProcessZMenuVO(index);

        }

    }

    else
    {

        PlaySound(GenericCantDoSound, true);
        DMFFA(WorldInfo.Game).LocalizedPrivateMessage(PlayerController(Controller), 12);

    }

}

simulated function PlayXMenuVO(int index)
{

    local DMFFAPlayerController PC;
    local SoundCue voSound;

    if (WorldInfo.NetMode == NM_DedicatedServer)
        return;
        
    if (!VOSoundComp.IsPlaying() && Physics != PHYS_Falling && !bIsBurning)
    {

        PC = DMFFAPlayerController(Controller);

        if (PC != none) // Update target player as soon as voicechat is triggered.
            PC.UpdateTargetPlayerController();

        class<AOCPawnSoundGroup>(SoundGroupClass).static.getAOCXMenuVO(self, index, voSound);   
        VOSoundComp.SoundCue = voSound;
        VOSoundComp.Play();

        if (Role < ROLE_Authority || WorldInfo.NetMode == NM_STANDALONE)
        {

            s_PlayVO(voSound);
            TeamDuelProcessXMenuVO(index);

        }

    }

    else
    {

        PlaySound(GenericCantDoSound, true);
        DMFFA(WorldInfo.Game).LocalizedPrivateMessage(PlayerController(Controller), 12);

    }

}

simulated function PlayBattleCry(int BC)
{

    local DMFFAPlayerController PC;

    PC = DMFFAPlayerController(Controller);

    if (PC != none) // Update target player as soon as battlecry is triggered.
        PC.UpdateTargetPlayerController();

    super.PlayBattleCry(BC);

}

reliable server function ServerPlayBattleCry()
{

    super.ServerPlayBattleCry();

    DMFFA(WorldInfo.Game).SetDuel(self);

}

simulated function TakeFallingDamage()
{

    local DMFFA G;
    local DMFFAPlayerController PC;

    G = DMFFA(WorldInfo.Game);

    if (G != none && !G.bGameEnded) // Full fall damage once a player reaches GoalScore.
    {

        PC = DMFFAPlayerController(Controller);

        if (PC != none && !PC.DuelInfo.damageable) // No fall damage outside duel.
            return;

    }

    super.TakeFallingDamage();

}

/** This is what happens when we go to attack another pawn.
 *  Happens on the server.
 */

reliable server function AttackOtherPawn(HitInfo Info, string DamageString, optional bool bCheckParryOnly = false, optional bool bBoxParrySuccess, optional bool bHitShield = false, optional SwingTypeImpactSound LastHit = ESWINGSOUND_Slash, optional bool bQuickKick = false)
{

    local DMFFA G;
    local DMFFAPlayerController AttackerPC, VictimPC;
    local bool bParry, bPassiveBlock, bFlinch, bSpecialFlinch;
    local int i;
    local AOCPRI AttackerPRI, VictimPRI;
    local bool bSameTeam;
    local AOCWeaponAttachment AttackerWeaponAttachment, VictimWeaponAttachment;
    local AOCMeleeWeapon AttackerMeleeWeapon, InstigatorMeleeWeapon;
    local float ActualDamage, GenericDamage;
    local float Resistance;
    local AOCWeapon VictimWeapon;
    local float HitForceMag;
    local bool bOnFire;
    local IAOCAIListener AIList;

    G = DMFFA(WorldInfo.Game);
    AttackerPC = DMFFAPlayerController(Controller);
    VictimPC = DMFFAPlayerController(Info.HitActor.Controller);

    If (!G.bGameEnded && AttackerPC != none && VictimPC != none) // Damage enabled for everyone once a player reaches GoalScore.
    {

        // No damage outside duel.

        if (!VictimPC.DuelInfo.damageable)
            return;

        if (AttackerPC.DuelInfo.Challenge == none)
            return;

        if (!AttackerPC.CanAttackPlayer(VictimPC))
            return;

    }

    if (!PerformAttackSSSC(Info) && WorldInfo.NetMode != NM_Standalone)
        return;

    // Check if fists...fists can only blocks fists.
    if (AOCWeapon_Fists(Info.HitActor.Weapon) != none && class<AOCDmgType_Fists>(Info.DamageType) == none)
        bParry = false;

    else
    {

        bParry = (bBoxParrySuccess && 
                  (Info.HitActor.StateVariables.bIsParrying || Info.HitActor.StateVariables.bIsActiveShielding) &&
                  class<AOCDmgType_Generic>(Info.DamageType) == none &&
                  Info.DamageType != class'AOCDmgType_SiegeWeapon');

        if (bParry)
            DetectSuccessfulParry(Info, i, bCheckParryOnly, 0);

    }

    bPassiveBlock = false;
    AttackerPRI = AOCPRI(PlayerReplicationInfo);
    VictimPRI = AOCPRI(Info.HitActor.PlayerReplicationInfo);

    if (Info.DamageType.default.bIsProjectile)
    {

        AttackerPRI.NumHits += 1;

        if (bHitShield)
        {

            // Check for passive shield block.
            bParry = true;
            Info.HitDamage = 0.f;
            bPassiveBlock = !Info.HitActor.StateVariables.bIsActiveShielding;

        }

    }

    if (bCheckParryOnly)
        return;

    switch (AttackerPC.TeamForDuel)
    {

        case EFAC_AGATHA:
        case EFAC_MASON:

            bSameTeam = AttackerPC.TeamForDuel == VictimPC.TeamForDuel;
            break;

        default: // No team considerations if it's not a team duel.

            bSameTeam = false;
            break;

    }

    AttackerWeaponAttachment = AOCWeaponAttachment(CurrentWeaponAttachment);
    VictimWeaponAttachment = AOCWeaponAttachment(Info.HitActor.CurrentWeaponAttachment);

    // Play hit sound.

    AttackerWeaponAttachment.LastSwingType = LastHit;

    if (!bParry)
        Info.HitActor.OnActionFailed(EACT_Block);
      
    Info.HitSound = AttackerWeaponAttachment.PlayHitPawnSound(Info.HitActor, bParry);
    AttackerMeleeWeapon = AOCMeleeWeapon(Weapon);
    InstigatorMeleeWeapon = AOCMeleeWeapon(Info.Instigator.Weapon);
    
    if (InstigatorMeleeWeapon != none)
        InstigatorMeleeWeapon.bHitPawn = true;

    // Less damage for quick kick.
    if (bQuickKick)
        Info.HitDamage = 3.f;

    ActualDamage = Info.HitDamage;
    GenericDamage = Info.HitDamage * Info.DamageType.default.DamageType[EDMG_Generic];
    ActualDamage -= GenericDamage; // Generic damage is unaffected by resistances etc.

    if (ActualDamage > 0.f)
    {

        if (!Info.DamageType.default.bIsProjectile)
        {

            // Backstab damage for melee damage.
            if (!CheckOtherPawnFacingMe(Info.HitActor))
                ActualDamage *= PawnFamily.default.fBackstabModifier;

            ActualDamage *= Info.HitActor.PawnFamily.default.LocationModifiers[GetBoneLocation(Info.BoneName)];

        }

        else
        {

            // Make the other pawn take damage, the push back should be handled here too.
            // Damage = HitDamage * LocationModifier * Resistances

            if (Info.UsedWeapon == 0 && AOCWeapon_Crossbow(Weapon) != none)
                ActualDamage *= Info.HitActor.PawnFamily.default.CrossbowLocationModifiers[GetBoneLocation(Info.BoneName)];

            else
                ActualDamage *= Info.HitActor.PawnFamily.default.ProjectileLocationModifiers[GetBoneLocation(Info.BoneName)];

        }

        // Vanguard Aggression.
        ActualDamage *= PawnFamily.default.fComboAggressionBonus ** Info.HitCombo;
                                                                    
        Resistance = 0.f;
        
        for (i = 0; i < ArrayCount(Info.DamageType.default.DamageType); i++)
        {

            Resistance += Info.DamageType.default.DamageType[i] * Info.HitActor.PawnFamily.default.DamageResistances[i];

        }
        
        ActualDamage *= Resistance;

        if (bSameTeam)
            ActualDamage *= G.fTeamDamagePercent;

    }

    ActualDamage += GenericDamage;
        
    // Damage calculations should be done now; round it to nearest whole number.
    ActualDamage = float(Round(ActualDamage));

    bFlinch = false;
    VictimWeapon = AOCWeapon(Info.HitActor.Weapon);

    // Successful parry but stamina got too low!
    if (bParry && !bPassiveBlock && Info.HitActor.Stamina <= 0)
    {

        bFlinch = true;
        VictimWeapon.ActivateFlinch(true, Info.HitActor.GetHitDirection(Location), true, true, AOCWeapon(Weapon).bTwoHander);

    }

    // If the other pawn is currently attacking, we just conducted a counter-attack.
    if (Info.AttackType == Attack_Shove && !bParry && !Info.HitActor.StateVariables.bIsSprintAttack)
    {

        // Kick should activate flinch and take away 10 stamina.
        if (!bSameTeam)
        {

            bFlinch = true;
            VictimWeapon.ActivateFlinch(true, Info.HitActor.GetHitDirection(Location), true, (Info.HitActor.StateVariables.bIsActiveShielding && !bQuickKick), false);

        }

        Info.HitActor.ConsumeStamina(10);

        if (Info.HitActor.StateVariables.bIsActiveShielding && Info.HitActor.Stamina <= 0)
            Info.HitActor.ConsumeStamina(-30.f);

    }

    else if (Info.AttackType == Attack_Sprint && !bSameTeam)
    {

        bFlinch = true;
        VictimWeapon.ActivateFlinch(true, Info.HitActor.GetHitDirection(Location), true, false, AOCWeapon(Weapon).bTwoHander); // Sprint attack should daze.

    }

    else if ((Info.HitActor.StateVariables.bIsParrying || Info.HitActor.StateVariables.bIsActiveShielding) && !bSameTeam && !bParry)
    {

        bFlinch = true;
        bSpecialFlinch = class<AOCDmgType_Generic>(Info.DamageType) != none;
        VictimWeapon.ActivateFlinch(true, Info.HitActor.GetHitDirection(Location), bSpecialFlinch, bSpecialFlinch, AOCWeapon(Weapon).bTwoHander);

    }

    else if ((ActualDamage >= 80.0f || Info.HitActor.StateVariables.bIsSprinting || Info.HitActor.Weapon.IsInState('Deflect') ||
              Info.HitActor.Weapon.IsInState('Feint') || (Info.HitActor.Weapon.IsInState('Windup') && AOCRangeWeapon(Info.HitActor.Weapon) == none) ||
              Info.HitActor.Weapon.IsInState('Active') || Info.HitActor.Weapon.IsInState('Flinch') ||
              Info.HitActor.Weapon.IsInState('Transition') || Info.HitActor.StateVariables.bIsManualJumpDodge ||
              (Info.HitActor.Weapon.IsInState('Recovery') && VictimWeapon.GetFlinchAnimLength(true) >= WeaponAnimationTimeLeft())) && 
             !bParry && !bSameTeam && !Info.HitActor.StateVariables.bIsSprintAttack)
    {

        VictimWeapon.ActivateFlinch(true, Info.HitActor.GetHitDirection(Location), false, false, AOCWeapon(Weapon).bTwoHander);

    }

    else if (AOCWeapon_JavelinThrow(Info.HitActor.Weapon) != none && Info.HitActor.Weapon.IsInState('WeaponEquipping'))
    {

        VictimWeapon.ActivateFlinch(true, Info.HitActor.GetHitDirection(Location), false, false, AOCWeapon(Weapon).bTwoHander);

    }

    else if (!bParry && !bSameTeam) // Cause the other pawn to play the hit animation.
    {

        VictimWeapon.ActivateHitAnim(Info.HitActor.GetHitDirection(Location, false, true), bSameTeam);

    }

    if (ActualDamage > 0.f)
    {

        Info.HitActor.SetHitDebuff();
        Info.HitActor.LastAttackedBy = Info.Instigator;
        PauseHealthRegeneration();
        Info.HitActor.PauseHealthRegeneration();
        Info.HitActor.DisableSprint(true);	
        Info.HitActor.StartSprintRecovery();

        // Play a PING sound if we hit a player when shooting.
        if (Info.DamageType.default.bIsProjectile)
            PlayRangedHitSound();

        // Play sounds for everyone.
        if ((Info.HitActor.Health - ActualDamage) > 0.f)
            Info.HitActor.PlayHitSounds(ActualDamage, bFlinch);
        
        if (AttackerPC != none)
            AttackerPC.PC_SuccessfulHit();

        // Add to assist list if not in it already.
        if (!bSameTeam && Info.HitActor.ContributingDamagers.Find(AttackerPRI) == INDEX_NONE)
            Info.HitActor.ContributingDamagers.AddItem(AttackerPRI);

        Info.HitActor.LastPawnToHurtYou = Controller;

    }

    // Notify Pawn that we hit.
    if (AttackerMeleeWeapon != none && (Info.HitActor.Health - ActualDamage) > 0.f && Info.AttackType != Attack_Shove && Info.AttackType != Attack_Sprint && !bParry)
        AttackerMeleeWeapon.NotifyHitPawn();

    // Pass attack info to be replicated to the clients.

    Info.bParry = bParry;
    Info.DamageString = DamageString;

    if (!Info.DamageType.default.bIsProjectile)
    {

        if (Info.BoneName == 'b_Neck' && Info.DamageType.default.bCanDecap && Info.AttackType != Attack_Stab)
            Info.DamageString $= "3";

    }

    else
    {

        switch (Info.BoneName)
        {

            case 'b_Neck':
            case 'b_Head':

                Info.DamageString $= "4";

                if (AttackerPC != none)
                    AttackerPC.NotifyAchievementHeadshot();

                break;

            case 'b_spine_A':
            case 'b_spine_B':
            case 'b_spine_C':
            case 'b_spine_D':

                if (AttackerPC != none)
                    AttackerPC.NotifyCupidProgress();

                break;

        }

    }

    Info.HitActor.ReplicatedHitInfo = Info;
    Info.HitDamage = ActualDamage;

    // Manually do the replication if we're on the standalone.
    if (WorldInfo.NetMode == NM_Standalone)
        Info.HitActor.HandlePawnGetHit();

    Info.HitForce *= int(PawnState != ESTATE_PUSH && PawnState != ESTATE_BATTERING);
    Info.HitForce *= int(!bFlinch);
    HitForceMag = VSize(Info.HitForce);
    Info.HitForce.Z = 0.f;
    Info.HitForce = Normal(Info.HitForce) * HitForceMag;

    // Stat Tracking For Damage
    // TODO: Also sort by weapon

    if (AttackerPRI != none)
    {

        if (!bSameTeam)
            AttackerPRI.EnemyDamageDealt += ActualDamage;

        else
            AttackerPRI.TeamDamageDealt += ActualDamage;
        
        AttackerPRI.bForceNetUpdate = true;

    }

    if (VictimPRI != none)
    {

        VictimPRI.DamageTaken += ActualDamage;
        VictimPRI.bForceNetUpdate = true;

    }

    bOnFire = Info.HitActor.bIsBurning;
    Info.HitActor.TakeDamage(ActualDamage, ((Controller != none) ? Controller : CurrentSiegeWeapon.Controller), Info.HitLocation, Info.HitForce, Info.DamageType);

    if (AttackerPC != none && (Info.HitActor == none || Info.HitActor.Health <= 0) && WorldInfo.NetMode == NM_DedicatedServer)
    {

        // Make sure this wasn't a team kill.
        if (!bSameTeam)
        {

            if (AttackerPC.StatWrapper != none)
            {

                if (Info.UsedWeapon < 2)
                {

                    AttackerPC.StatWrapper.IncrementKillStats(((Info.UsedWeapon == 0) ? PrimaryWeapon : SecondaryWeapon), 
                                                              PawnFamily,
                                                              Info.HitActor.PawnFamily,
                                                              class<AOCWeapon>(VictimWeaponAttachment.WeaponClass));

                }

            }

            else
            {

                AttackerPRI.StatDebugMsg = "Attack Other Pawn -- StatWrapper Was None -- Reinitializing";
                AttackerPC.ServerInitStatWrapper();

            }

        }

        // Do another check for a headshot here.
        if (Info.BoneName == 'b_Neck' && !Info.DamageType.default.bIsProjectile && Info.DamageType.default.bCanDecap && Info.AttackType != Attack_Stab)
        {

            // Award rotisserie chef achievement on client.
            if (bOnFire)
                AttackerPC.UnlockRotisserieChef();

            // Notify decap.
            AttackerPC.NotifyAchievementDecap();

        }

        // Check if fists.
        if (class<AOCDmgType_Fists>(Info.DamageType) != none)
            AttackerPC.NotifyFistofFuryProgress();

    }

    foreach AICombatInterests(AIList)
    {

        AIList.NotifyPawnPerformSuccessfulAttack(self);

    }
    
    foreach Info.HitActor.AICombatInterests(AIList)
    {

        if (!bParry)
            AIList.NotifyPawnReceiveHit(Info.HitActor, self);

        else
            AIList.NotifyPawnSuccessBlock(Info.HitActor, self);

    }

}

// Pawn has died. Now activate any pawn death listeners.

function bool Died(Controller Killer, class<DamageType> DamageType, vector HitLocation)
{

    local DMFFAPlayerController PC;
    local AOCPRI MyPRI, KillerPRI, PRI;
    local int i;
    local AOCAmmoDrop Drop;

    PC = DMFFAPlayerController(Controller);

    if (PC != none && PC.bJustSuicided)
    {

        PC.bJustSuicided = false;
        Killer = (LastPawnToHurtYou != none) ? LastPawnToHurtYou : none;

    }

    else if (Killer == none && LastPawnToHurtYou != none)
        Killer = LastPawnToHurtYou;

    // Distribute assists points as necessary.

    MyPRI = AOCPRI(PlayerReplicationInfo);
    KillerPRI = (Killer != none) ? AOCPRI(Killer.PlayerReplicationInfo) : none;

    foreach ContributingDamagers(PRI)
    {

        if (PRI != MyPRI && PRI != KillerPRI)
        {

            PRI.NumAssists += 1;
            PRI.OwnerController.StatWrapper.IncrementAssistStat();

        }

    }

    // Spawn les ammos
    for (i = 0; i < MAXIMUM_STORED_PROJECTILE_TYPES; i++)
    {

        if (StruckByProjectiles[i].ProjectileOwner != none)
        {

            Drop = Spawn(class'AOCAmmoDrop', self,,Location, Rotation);
            Drop.AmmoOwner = StruckByProjectiles[i].ProjectileOwner;
            Drop.AmmoType = StruckByProjectiles[i].ProjectileType;
            Drop.AmmoToGive = StruckByProjectiles[i].ProjectileCount;
            Drop.bReady = true;
            StruckByProjectiles[i].ProjectileOwner = none;

        }

    }

    // Notify remote console
    if (Killer == none || Killer.Pawn == self)
        DMFFA(WorldInfo.Game).RemoteConsole.GameEvent_Suicide(PlayerReplicationInfo);

    else
        DMFFA(WorldInfo.Game).RemoteConsole.GameEvent_Kill(Killer.PlayerReplicationInfo, PlayerReplicationInfo, AOCWeapon(Killer.Pawn.Weapon));

    super(UTPawn).Died(Killer, DamageType, HitLocation);

    return true;

}

simulated function DisplayDefaultCustomizationInfoOnPawn()
{

    local int TeamID;
    local int CharacterID;
    local MaterialInstanceConstant MIC;
    local LinearColor LinCol;

    TeamID = TeamForDuel;
    CharacterID = CustomizationClass.static.GetDefaultCharacterID(TeamID, PawnFamily.default.ClassReference);
    SetCharacterAppearanceFromInfo(CustomizationClass.static.GetCharacterInfo(CharacterID));
    SetupHelmet(0, CharacterID);

    if (Worldinfo.NetMode == NM_DedicatedServer)
        return;

    if (bSupportsCustomization)
    {

        foreach MICArray(MIC)
        {

            MIC.SetTextureParameterValue('Emblem', CustomizationClass.static.GetEmblemTexture(0, TeamID, true));
            LinCol = CustomizationClass.static.ConvertEmblemColorIndexToLinearColor(0, TeamID);
            MIC.SetVectorParameterValue('EmblemColor1', LinCol);
            LinCol = CustomizationClass.static.ConvertEmblemColorIndexToLinearColor(0, TeamID);
            MIC.SetVectorParameterValue('EmblemColor2', LinCol);
            LinCol = CustomizationClass.static.ConvertEmblemColorIndexToLinearColor(0, TeamID);
            MIC.SetVectorParameterValue('EmblemColor3', LinCol);
            MIC.SetTextureParameterValue('Pattern', CustomizationClass.static.GetTabardTexture(0, CharacterID));
            LinCol = CustomizationClass.static.ConvertTabardColorIndexToLinearColor(0, TeamID, 0);
            MIC.SetVectorParameterValue('PatternColor1', LinCol);
            LinCol = CustomizationClass.static.ConvertTabardColorIndexToLinearColor(0, TeamID, 1);
            MIC.SetVectorParameterValue('PatternColor2', LinCol);
            LinCol = CustomizationClass.static.ConvertTabardColorIndexToLinearColor(0, TeamID, 2);
            MIC.SetVectorParameterValue('PatternColor3', LinCol);

        }

    }

}

simulated function DisplayCustomizationInfoOnPawn()
{

    /*
    * Sets Pawn's Mesh to display the new customization info (should happen AFTER pawn's familyinfo gets set).
    * Called on: All Clients.
    */

    local int TeamID;
    local class<AOCCharacterInfo> CharInfo;
    local MaterialInstanceConstant MIC;

    TeamID = TeamForDuel;

    if (PawnInfo.myCustomization.Character <= 0)
        PawnInfo.myCustomization.Character = CustomizationClass.static.GetDefaultCharacterID(TeamID, PawnFamily.default.ClassReference);

    CharInfo = CustomizationClass.static.GetCharacterInfo(PawnInfo.myCustomization.Character);

    if (PawnInfo.myCustomization.Character == -1 || CharInfo == none || !bSupportsCustomization)
        DisplayDefaultCustomizationInfoOnPawn();

    else
    {

        SetCharacterAppearanceFromInfo(CharInfo);

        // Intialize helemet here.
        SetupHelmet(PawnInfo.myCustomization.Helmet, PawnInfo.myCustomization.Character);

        if (Worldinfo.NetMode == NM_DedicatedServer)
            return;

        foreach MICArray(MIC)
        {
            // Set Emblem.
            if (PawnInfo.myCustomization.Emblem != -1)
            {

                MIC.SetTextureParameterValue('Emblem', CustomizationClass.static.GetEmblemTexture(PawnInfo.myCustomization.Emblem, TeamID, true));
                MIC.SetVectorParameterValue('EmblemColor1', PawnInfo.myCustomization.EmblemColor1);
                MIC.SetVectorParameterValue('EmblemColor2', PawnInfo.myCustomization.EmblemColor2);
                MIC.SetVectorParameterValue('EmblemColor3', PawnInfo.myCustomization.EmblemColor3);

            }

            else
                MIC.SetTextureParameterValue('Emblem', none);

            // Set Tabard.
            if (PawnInfo.myCustomization.Tabard != -1)
            {

                MIC.SetTextureParameterValue('Pattern', CustomizationClass.static.GetTabardTexture(PawnInfo.myCustomization.Tabard, PawnInfo.myCustomization.Character));
                MIC.SetVectorParameterValue('PatternColor1', PawnInfo.myCustomization.TabardColor1);
                MIC.SetVectorParameterValue('PatternColor2', PawnInfo.myCustomization.TabardColor2);
                MIC.SetVectorParameterValue('PatternColor3', PawnInfo.myCustomization.TabardColor3);

            }

            else
                MIC.SetTextureParameterValue('Pattern', none);

        }

        DisplayCustomizationInfoOnShield();

    }

}

simulated function DisplayCustomizationInfoOnShield()
{

    local int TeamID;
    local int MaterialIndex;
    local MaterialInstanceConstant ShieldMIC;
    local int i;
    local AOCInventoryAttachment InvAttachment;

    TeamID = TeamForDuel;
    MaterialIndex = (PawnFamily.default.FamilyFaction == EFAC_MASON) ? EFAC_MASON : 0;

    if (PawnInfo.myCustomization.Shield != 0)
    {

        if (ShieldClass.NewShield != none && ShieldMesh != none && ShieldClass.NewShield.default.CustomizationMaterial[MaterialIndex] != none)
        {

            ShieldMesh.SetMaterial(0, ShieldClass.NewShield.default.CustomizationMaterial[MaterialIndex]);
            ShieldMIC = ShieldMesh.CreateAndSetMaterialInstanceConstant(0);
            ActuallyCustomizeShield(ShieldMIC, TeamID);

            if (OverlayShieldMesh != none)
            {

                OverlayShieldMesh.SetMaterial(0, ShieldClass.NewShield.default.CustomizationMaterial[MaterialIndex]);
                ShieldMIC = OverlayShieldMesh.CreateAndSetMaterialInstanceConstant(0);
                ActuallyCustomizeShield(ShieldMIC, TeamID);

            }

        }
        
        for (i = 0; i < ArrayCount(CurrentAttachedItems); ++i)
        {

            InvAttachment = CurrentAttachedItems[i];

            if (InvAttachment.CustomizationMaterial != none)
            {

                InvAttachment.Mesh.SetMaterial(0, InvAttachment.CustomizationMaterial);
                ShieldMIC = InvAttachment.Mesh.CreateAndSetMaterialInstanceConstant(0);

                // Set Emblem.
                if (PawnInfo.myCustomization.Emblem != -1)
                {

                    ShieldMIC.SetTextureParameterValue('Emblem', CustomizationClass.static.GetEmblemTexture(PawnInfo.myCustomization.Emblem, TeamID, false));
                    ShieldMIC.SetVectorParameterValue('EmblemColor1', PawnInfo.myCustomization.EmblemColor1);
                    ShieldMIC.SetVectorParameterValue('EmblemColor2', PawnInfo.myCustomization.EmblemColor2);
                    ShieldMIC.SetVectorParameterValue('EmblemColor3', PawnInfo.myCustomization.EmblemColor3);

                }

                else
                    ShieldMIC.SetTextureParameterValue('Emblem', none);

                // Set Tabard.
                if (PawnInfo.myCustomization.Shield != -1)
                {

                    ShieldMIC.SetTextureParameterValue('Pattern', CustomizationClass.static.GetShieldPatternTexture(PawnInfo.myCustomization.Shield, PawnInfo.myCustomization.Character, InvAttachment.ShieldID));
                    ShieldMIC.SetVectorParameterValue('PatternColor1', PawnInfo.myCustomization.ShieldColor1);
                    ShieldMIC.SetVectorParameterValue('PatternColor2', PawnInfo.myCustomization.ShieldColor2);
                    ShieldMIC.SetVectorParameterValue('PatternColor3', PawnInfo.myCustomization.ShieldColor3);

                }

                else
                    ShieldMIC.SetTextureParameterValue('Pattern', none);

            }

        }

    }

    else
    {

        if (ShieldClass.NewShield != none && ShieldMesh != none && ShieldClass.NewShield.default.CustomizationMaterial[MaterialIndex] != none)
        {

            ShieldMesh.SetMaterial(0, ShieldClass.NewShield.default.PlainMaterial[MaterialIndex]);
            
            if (OverlayShieldMesh != none)
                OverlayShieldMesh.SetMaterial(0, ShieldClass.NewShield.default.PlainMaterial[MaterialIndex]);

        }

        for (i = 0; i < ArrayCount(CurrentAttachedItems); ++i)
        {

            InvAttachment = CurrentAttachedItems[i];

            if (InvAttachment.CustomizationMaterial != none)
                InvAttachment.Mesh.SetMaterial(0, InvAttachment.PlainMaterial);

        }

    }

}

DefaultProperties
{

    TeamForDuel = EFAC_FFA

}