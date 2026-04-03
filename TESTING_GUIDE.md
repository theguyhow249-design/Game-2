# How to Test Your Game

## Quick Start (Solo Testing)

1. **Start the Game**
   - Run the game in Roblox Studio
   - Both the server and client will initialize
   - Check the Output console for startup validation messages

2. **Play a Mission**
   - Wait to spawn in the lobby
   - Find the VotePad (should be a pad you can stand on)
   - Stand on a different VotePad for each wave option (3 options total)
   - Stand on the DeployPad launch button
   - After 15-second intermission, watch the deployment cinematic
   - You should be teleported into the mission arena

3. **During Mission**
   - Waves of zombies will spawn (up to 5 waves)
   - Combat feedback (hit markers, damage numbers) should appear
   - After all waves, extraction pad appears
   - Stand on extraction pad to hold for ~3 seconds
   - Mission complete - see results screen

4. **Back in Lobby**
   - Check your token balance increased
   - Try again!

## Common Issues & Solutions

### Issue: Lobby Doesn't Load  
**Solution**: Check server console for StartupValidator warnings. May need to place DesignerLobby in workspace or let fallback generation create it.

### Issue: Deployment Cinematic Doesn't Play
**Solution**: Verify MissionCameraStartPath and MissionCameraEndPath are set (check in startup validator output).

### Issue: Players Don't Teleport to Mission
**Solution**: Verify MissionSpawnPath is set. Check that MissionStaging folder exists.

### Issue: Zombies Don't Spawn
**Solution**: Mission system might have errors. Check server console logs. Ensure MissionConfig is loaded.

### Issue: Combat Feedback Doesn't Show
**Solution**: FlowController might not be connected. Verify Remotes are set up correctly.

## Testing Checklist

- [ ] Server starts without errors
- [ ] Players can load and see lobby
- [ ] VotePads are interactive  
- [ ] DeployPad triggers deployment
- [ ] 15-second countdown appears
- [ ] Deployment cinematic plays (4 seconds)
- [ ] Players teleport to mission  
- [ ] Zombies spawn in waves
- [ ] Hit markers appear when shooting
- [ ] Damage numbers float up
- [ ] Waves complete and extraction pad appears
- [ ] Players can extract (hold on pad)
- [ ] Results screen shows with stats
- [ ] Tokens were awarded
- [ ] Players return to lobby

## Advanced Testing

### Test Multiplayer
1. Start game with multiple players
2. Have each player join the same squad
3. Deploy together
4. Verify they see each other during combat
5. Both must reach extraction pad to extract

### Test Progression
1. Complete a mission, note starting tokens
2. Check mission rewards in results screen
3. Verify tokens were added correctly
4. Check skill tree for XP gains

### Monitor Performance  
- Watch server CPU usage during mission
- Check if zombies pathfinding is smooth
- Note any lag spikes during wave transitions

## Debug Console Commands

If using admin service, try:
```
:admin() -- may unlock admin commands if implemented
```

Check server console output for any UnhandledPromise errors or warnings.

## Next Steps if All Tests Pass

1. Increase mission difficulty/waves
2. Add more zombie types
3. Implement squad size scaling  
4. Add boss zombies
5. Polish UI animations & sounds
6. Add tutorial/guided tours
7. Implement ranked/leaderboard system
8. Add cosmetics/cosmetic marketplace

## Getting Help

If you encounter issues:
1. Check GAME_STATUS.md for system completeness
2. Review server console startup validation output
3. Look for specific error messages in output
4. Check that all services are initializing (look for ":Start()" methods)
5. Verify workspace attributes are set (MissionSpawnPath, etc.)

Good luck testing! 🚀
