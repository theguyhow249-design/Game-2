# Lobby Source Of Truth

The only valid workspace lobby source for this project is:

- `src/workspace/right lobby.rbxm`

Rojo maps that file to:

- `Workspace["right lobby"]`

Rules:

- Do not add `DesignerLobby` back.
- Do not create a second lobby asset and expect it to sync automatically.
- Do not edit an unmapped lobby copy and assume it will appear in game.
- If the lobby is changed in Studio, export/update `src/workspace/right lobby.rbxm`.
- Rojo sync updates the local Studio session only. Publish from Studio to push changes to the actual Roblox place.

Current project mapping lives in:

- `default.project.json`
