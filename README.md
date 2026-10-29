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
- Version 3 loads the requested preset with the master switch on and menu hidden. F8 stops it.
- Settings persist through LumenUI's local configuration storage.

## Features

- Dodge and block chance sliders, reaction delay, and block duration.
- One punch attempt per detected recovery/stun opening, with facing and guard checks, configurable range, and heavy-punch chance. No idle timer punching.
- Auto ultimate during an opening, with configurable key and energy threshold.
- Opponent range and minimum stamina settings.
- Checks for combat state, assigned opponent, game focus, and text input.

## Validation and limitations

Version 3 uses the game's existing `TryBlock`/`TryUnblock` and `TryDash` controls instead of simulated defensive keystrokes. A live test observed guard raising and releasing, and a separate test observed a dash. These checks do not establish that every incoming attack will be blocked or dodged.

The requested preset is saved separately as `preset-v3`: 85% dodge, 100% block selection fallback, 40 ms reaction, 350 ms block hold, 20% minimum guard, punish on, 400 ms minimum punish interval, 5.5 stud punch range, 0% heavy attacks, ultimate off (threshold 100), 9 stud opponent range, 25% minimum stamina. Defense respects the game's existing control validation. The displayed dash/block keys reflect bindings; direct defensive calls do not simulate those keys.

## Local fight recording

While running, version 3 writes JSON logs to Real's executor workspace under `UBGAssist/Fights/`. These are event logs, not video. They record opponent names/styles, attack timestamps, state changes, action choices/attempts, health, stamina, guard energy, and reasons assists pause. Server guard starts and observed dashes have separate counters from attempts. Logs save every five seconds and on clean unload, retaining at most 10,000 events per session file. No logs are uploaded to GitHub and no automatic tuning is performed. Use **Save fight log now** before analysis or closing the game; abrupt termination can lose the last few seconds.

## Earlier validation

Version 2 fixes attack detection: live observation confirmed that `Punching` contains a numeric timestamp, not the boolean `true`. Each distinct timestamp produces one defense decision. Attack-end recovery is a heuristic and is not a guarantee that a punish will land. A multi-hit move may count as one attack.

The script passes Real's static checker. Seven simulated decision checks passed, covering numeric detection, dodge/block dispatch, no repeated decision for the same attack, no idle punching, and one punish per opening. Live attack timestamps were observed, but successful defensive inputs and match outcomes still require validation. Input counts indicate attempts, not successful dodges or hits. Ultimate threshold 100 is a configurable default. Movement and aiming remain manual.

The script uses Real's native input functions and is not a Roblox Studio LocalScript. Compatibility with other executors has not been tested.
