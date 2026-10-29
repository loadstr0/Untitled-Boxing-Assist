# Untitled Boxing Assist

Standalone Luau script using LumenUI, built for Untitled Boxing Game (place 13621938427) and the Real executor. Running the script does not require MCP or this chat.

## Run

Paste this into Real while in the game:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/loadstr0/Untitled-Boxing-Assist/main/UBGAssist.luau"))()
```

Open `UBGAssist.luau` in Real and execute it while in the game. LumenUI is fetched from `loadstr0/LumenUI` when the script starts, so an internet connection is required.

## Controls

- **Right Ctrl:** show or hide the menu. Assists pause while it is open.
- **F8:** stop all assists.
- The master switch starts off on every load.
- Settings persist through LumenUI's local configuration storage.

## Features

- Dodge and block chance sliders, reaction delay, and block duration.
- Auto boxing with punch interval and heavy-punch chance.
- Auto ultimate with configurable key and energy threshold.
- Opponent range and minimum stamina settings.
- Checks for combat state, assigned opponent, game focus, and text input.

## Validation and limitations

The script passed Real's static checker and its menu loaded without console errors. Live match behavior, attack detection, and timing still need validation. Dodge and block chances apply once per observed `Punching` transition; a multi-hit move may count as one attack. Input counts indicate attempts, not successful dodges or hits. Ultimate threshold 100 is a configurable default. Movement and aiming remain manual.

The script uses Real's native input functions and is not a Roblox Studio LocalScript. Compatibility with other executors has not been tested.
