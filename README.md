# Zombie Survival Game - Development Guide

## Project Overview
This is a Roblox zombie survival game with squad-based missions, combat progression, and an in-depth service architecture.

**Status**: Core systems implemented ✅ | Ready for testing & polish

## Getting Started

### Building with Rojo
```bash
rojo build -o "game 2.rbxlx"
```

### Running with Rojo
```bash
rojo serve
```

For more help: [Rojo Documentation](https://rojo.space/docs)

## Game Documentation

📖 **[GAME_STATUS.md](GAME_STATUS.md)**
- Complete overview of all game systems
- What's working vs what needs work
- Architecture explanation

🧪 **[TESTING_GUIDE.md](TESTING_GUIDE.md)**
- How to test the game
- Common issues & solutions
- Feature checklist

🛣️ **[DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md)**
- Planned features prioritized
- Time estimates for each feature
- Quick wins to implement next

## Quick Start

1. **Open in Studio** - Load the .rbxlx file
2. **Start Rojo Server** - `rojo serve` in terminal
3. **Play in Studio** - Run the game
4. **Check Console** - Look for startup validation messages
5. **Follow Testing Guide** - Test the full game loop

## Project Structure

```
game 2/
├─ client/
│  ├─ init.client.luau ........... Client entry point
│  └─ Controllers/
│     ├─ FlowController.luau .....  Main UI & flow logic
│     ├─ CinematicController.luau . Deployment cinematic
│     └─ Remotes.luau ............ Remote connections
│
├─ server/
│  ├─ init.server.luau ........... Server startup (startup validation added!)
│  ├─ LobbyWorld.luau ............ Lobby generation & setup
│  ├─ DeploymentRuntime.luau ..... Mission deployment handler (improved!)
│  ├─ ServerSystems.luau ......... Service initialization  
│  ├─ StartupValidator.luau ...... System health check (NEW!)
│  └─ Services/
│     ├─ FlowService.luau ........ Game phases & deployment (improved!)
│     ├─ MissionService.luau ..... Mission gameplay & logic
│     ├─ InstanceDeploymentService.luau
│     └─ [13 other services...]
│
├─ shared/
│  ├─ Contracts.luau ............ Data structures
│  ├─ RemoteNames.luau ......... Remote event names
│  └─ [Config files...]
│
└─ docs/
   ├─ README.md (this file)
   ├─ GAME_STATUS.md
   ├─ TESTING_GUIDE.md
   └─ DEVELOPMENT_ROADMAP.md
```

## What's Working

| Feature | Status | Notes |
|---------|--------|-------|
| Lobby system | ✅ | Procedural generation with fallback |
| Mission selection | ✅ | Vote on mission variants |
| Deployment | ✅ | Intermission + cinematic fly-in |
| Combat | ✅ | Multiple waves, zombie AI |
| Feedback | ✅ | Hit markers, damage numbers, sounds |
| Extraction | ✅ | Hold-to-extract mechanic |
| Results | ✅ | Stats, rewards, XP breakdown |
| Progression | ✅ | Tokens, XP, skill tree |
| Squads | ✅ | Create, join, squad progression |

## Recent Improvements

✨ **Enhanced Robustness**
- FlowService now validates camera paths before deployment
- DeploymentRuntime handles mission startup failures gracefully
- Better error messages for debugging

✨ **Startup Validation**
- Automatic system health checks on server start
- Clear warnings if setup is incomplete  
- Helps identify configuration issues

✨ **Better Logging**
- Initialization messages show startup progress
- Easier to diagnose problems
- Clear success/failure indicators

## Quick Reference

### Test the Game
See [TESTING_GUIDE.md](TESTING_GUIDE.md) for detailed steps

### Understand Systems
See [GAME_STATUS.md](GAME_STATUS.md) for complete architecture

### Plan Next Features
See [DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md) for roadmap

### Check Console
Look for **[Server]**, **[StartupValidator]**, and **[DeploymentRuntime]** messages

## Next Steps

1. **Follow [TESTING_GUIDE.md](TESTING_GUIDE.md)** - Test the core game loop
2. **Fix any issues** - Check console for warnings
3. **Add audio** - High-impact improvement (music, sounds)
4. **Polish UI** - Animations, clear feedback
5. **Balance difficulty** - Tweak zombie spawning, rewards
6. **Review [DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md)** - Plan next features

## Key Systems

### Game Loop
1. Player joins → spawns in lobby
2. Squad votes on mission (3 options)
3. Squad deploys (15s intermission)
4. Deployment cinematic (4s fly-in)
5. Mission gameplay (combat + waves)
6. Extraction (hold on pad)
7. Results screen (stats + rewards)
8. Return to lobby

### Services
- **FlowService** - Phase management, deployment
- **MissionService** - Wave spawning, combat, extraction
- **SquadService** - Squad management, membership
- **TokenService** - Currency economy
- **RewardService** - Rewards, daily tasks
- **InventoryService** - Player loadouts, cosmetics
- **SkillTreeService** - Progression system

### Remotes
- **DeployStateChanged** - Deployment status updates
- **CombatFeedback** - Hit markers, damage, kills
- **Notification** - Results screens, messages
- **FlowChanged** - Game phase updates

## Troubleshooting

**Lobby doesn't load?**
→ Check startup validator output. May need to create DesignerLobby or check LobbyWorldConfig.

**No deployment cinematic?**
→ Verify MissionCameraStartPath and MissionCameraEndPath are set (check console).

**Players don't teleport?**
→ Check MissionSpawnPath is set. Verify MissionStaging folder exists.

**Combat feedback missing?**
→ Check Remotes folder in ReplicatedStorage. Verify FlowController is running.

See [TESTING_GUIDE.md](TESTING_GUIDE.md) for more troubleshooting.

## Development Notes

- All services use dependency injection pattern (passed in context)
- Client-server communication via RemoteEvents/RemoteFunctions
- Mission state machine: Lobby → Intermission → Deployment → Mission → Extraction → Results → Lobby
- Zombie spawning respects squad size/difficulty scaling
- Rewards scale based on mission difficulty

## Performance Tips

- Limit wave sizes based on client FPS
- Use LOD (level of detail) for distant zombies
- Cache pathfinding results for zombie AI
- Clean up mission instances after extraction

## Contributing

When adding features:
1. Follow the service pattern for organization
2. Use proper dependency injection
3. Add remote event names to RemoteNames.luau
4. Update DEVELOPMENT_ROADMAP.md with progress
5. Test full game loop after changes

## License & Credits

Project uses Rojo for development. Built for Roblox platform.

---

**Last Updated**: 2026-03-29
**Status**: Phase 1 Complete ✅ | Phase 2 (Polish) Starting
**Documentation**: See docs/ folder for detailed guides
