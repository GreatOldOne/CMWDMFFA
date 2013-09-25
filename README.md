# Chivalry Medieval Warfare: FFA Duel Mod #
===========================================

This mod brings a dynamic "pick your opponent" duel system into Chivalry Medieval Warfare FFA game mode, similar to Jedi Academy's FFA duel system.

## Features ##

- [x] Battlecry-based challenge system.
- [x] Map timer disabled.
- [x] Instant respawn, unless in a team duel.
- [x] Instant loadout swap.
- [x] Throwables disabled (server side check to prevent memory address patching at the client side).
- [x] Spectator support.
- [x] Players can't damage nor attack other players, unless it's their duel challenge.
- [x] Fall damage disabled outside duel.
- [x] Health, stamina and ammo replenishment before and after the duel (by swapping pawns).
- [x] Private Duels.
- [x] Team Duels.
- [x] Goal Score as a mean to end the map.
- [x] Team chat to Duel Team chat.
- [x] HUD modifications.
- [x] VoteChangeMap allowing the admin to set only specific maps (from the maplist) for voting.
- [x] GetDuelInfo command.

#### Dueling ####

The dueling system is pretty straight forward.  
To challenge a player to a duel, you must target him/her and battlecry. He/she must do the same to accept your challenge.  
You can revoke your challenge by battlecrying on the same opponent for a second time, but only before the duel starts.

Once a duel is set, there will be two countdowns:

1. Initializing Duel/Switching Reality
2. Prepare to fight

For this stage to begin, both teams must be alive.  
It's also important to note that in a team duel, one team goes Agatha and the other one goes Mason.

If one of the leaders die during the first countdown, the duel will be cancelled and neither team scores.

Once the duel has begun, you can damage your opponent.  
You will not be able to respawn until the duel is over (in the case of a team duel).

If a leader disconnects or goes spectator during a duel, the opposing team automatically wins.

Once an entire team is dead, the duel is over.

#### Spectator ####

Similar to other game modes, with a few basic changes.  
If you are not a voluntary spectator, you can only spectate your own duel team (when dueling).  
As a voluntary spectator you will automatically follow your view target across realities, and going back to free look mode will bring you back to the general non-dueling reality.

#### Private Duels ####

This feature was based on Jedi Academy's Ghost duels.

There are three possible values for Private Duels (set by the server admin):

* [0] This value disables Private Duels.
* [1] This value means there will be two different realities. One for dueling and another one for non-dueling.
* [2] This value means there will be a non-dueling reality and every duel will take place in a completely new and reserved reality.

###### What are realities? ######

Consider them a virtual zone, or a parallel universe. A player in reality x cannot interact with nor see a player in reality y.  
This mechanism improves performace, aswell as provide privacy to players during duel.  
It's highly recommended to have Private Duels set to 2 for a Team Duels enabled server.

#### Team Duels ####

Team Duels functions just like a mini, dynamic LTS (Last Team Standing) mode.

Team Duels uses voice chat commands to build and manage duel teams.

* Voice chat/Follow me (as duel team leader): Invites a player to your team.
* Voice chat/Yes (while not in a team and invited): Accepts a team invitation and join said team.
* Voice chat/No (while not in a team and invited): Declines a team invitation.
* Voice chat/Sorry (while in a team): As the duel team leader, targeting a player in your team and executing this command will kick said player from your team. However, executing this command as a non-duel team leader will cause you to leave your current team.
* Voice chat/Retreat (as duel team leader): Disbands your duel team.

Only the team leader can challenge others or accept challenges.

Going spectator or disconnecting as the team leader will automatically disband you team. Doing the same as a team member will make you automatically leave your current team.

#### Goal Score ####

Goal Score is the only way for a map to end, besides manual map changing (voting, admin, etc).  
A Goal Score of 0 means the map will never end on its own.

A player will earn +1 score for each duel he/she wins, regardless of team size.  
Every member of a team will earn +1 score for his team's victory, even if the player died during duel.

#### Duel Team Chat ####

Team chat was changed to allow duel teams to communicate between themselves.  
Spectators can also use team chat to communicate between voluntary spectators.

#### HUD Modifications ####

Some elements of the HUD were changed to provide better feedback to players.

* Steam Friends to Team Members HUD Markers (leader is displayed in orange).
* Team Selection: Play / Spectate buttons displaying number of players.
* Scoreboard: Timer to infinity symbol.
* Scoreboard: Team names and ordering to "Not Dueling" and "Dueling".
* Scoreboard: Team scores to number of duel teams (duelable players).
* Scoreboard: Class icon to King icon for players leading a duel team.
* Scoreboard: Different colors for player names when in a team:
  * Blue: Your leader.
  * Dark green: Another team leader.
  * Cyan: Member of your team.
  * Green: Member of another team.
* Scoreboard: Objective score to Team Size.
* Scoreboard: Accuracy ratio to Acurracy ratio percentage.
* Scoreboard: Objective box will also display the team's highest score.

#### GetDuelInfo ####

This command can retrieve basic duel information about a player such as, team status, team size, duel status, etc.

You can either target a player or type his name (or part of it) and execute the command.

## Installing (Cooked) ##

#### Client ####

Simply put DuelMod directory into UDKGame/CookedSDK.

#### Server ####

For a server running without the dedicated server tool, do the same as you did for the client.  
For a server running through the dedicated server tool, instead of UDKGame/CookedSDK, put DuelMod directory into chivalry_ded_server/UDKGame/CookedPCServer.

For a server running without the dedicated server tool, open My Documents/My Games/Chivalry Medieval Warfare Beta/UDKGame/Config/UDKGame.ini.  
For a server running through the dedicated server tool, open chivalry_ded_server/UDKGame/Config/PCServer-UDKGame.ini.  
Replace every GameType="AOC.AOCFFA" with GameType="DuelMod.DMFFA" within every DefaultMapPrefixes.

For a server running through the dedicated server tool, open chivalry_ded_server/UDKGame/Config/PCServer-UDKEngine.ini.  
On [Engine.ScriptPackages] add NativePackages=DuelMod.

Run the server for the first time with a FFA map on the command line to generate its configuration.

###### Configuration Variables ######

* PrivateDuels = 0/1/2
* bAllowTeamDuels = True/False
* iMaxTeamSize = Maximum number of members a duel team can have (leader doesn't count), 0 = infinite
* bOnlySameTeamSizeDuels = True/False
* fChallengeTimeout = Time a player must wait before challenging another player (prevents spam)
* bMapVoteOnlyFromList = True/False

## Compiling and Cooking ##

If you intend to compile and cook this project yourself, do the following:

1. Clone the repository to your computer.
2. Put DuelMod directory into Development/Src.
3. Edit UDKGame/Config/UDKSDK.ini and change ModPackages to ModPackages=DuelMod.
4. Run: Binaries\Win64\UDK.exe make
5. Once compiled, create a dummy map or use one of the existing ones in UDKGame/ContentSDK/ExampleMaps.
6. Open it with the editor: Binaries\Win64\UDK.exe editor
7. Go to View -> World Properties.
8. On Game Type set a supported game type to DMFFA, save and close.
9. Now cook: Binaries\Win64\UDK.exe CookPackages -log -nohomedir -platform=PC -SDKPackage=DuelMod [DummyMap] -multilanguagecook=int
10. Once cooked, go to UDKGame/CookedSDK/DuelMod and delete everything but DuelMod.u.
11. It's now ready for deployment.

## Dependencies ##

1. Chivalry: Medieval Warfare Beta

## Contributing or using this code base ##

If you want to contribute to the project or use it for your own, do the following:

1. [Fork](https://github.com/GreatOldOne/CMWDMFFA/fork) the project on GitHub.
2. Create a new branch for your changes.
3. Make sure everything is properly tested and organized.
4. Send a [pull request](https://help.github.com/articles/creating-a-pull-request) to GreatOldOne/CMWDMFFA.

Steps 2, 3 and 4 are only required if you intend to contribute to this project.

## Maintainers ##

* Cthulhu

## Links ##

* [Official Thread](http://www.tornbanner.com/forums/viewtopic.php?f=51&t=16263)
* [Steam Group](http://steamcommunity.com/groups/CMWDMFFA)
