# QuizBot v3

A modular Roblox chat bot for the **Volt** executor. Trivia engine, CFrame fly, Spotify control, Gemini TTS, and an admin command registry — each feature is its own file loaded at runtime, so the whole thing stays under Volt's 200 local-register limit no matter how big it gets.

---

## Run it

One line in your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Aegians/quizbot-v3/main/loader.lua"))()
```

`loader.lua` fetches every module from the same repo and wires them together through a shared `ctx` table.

---

## Repo layout

Every file lives at the **repo root** (that's what the loader's `BASE_URL` points at):

```
quizbot-v3/
├── loader.lua        Entry point: services, chat bypass, command registry, Gemini API, module loader
├── cmd_help.lua      /help, /stats, /setkey, /settoken, /prefix, /destroy
├── cmd_fly.lua       /fly, /unfly, /speed, /flyto, /follow, /unfollow, /tp, /noclip
├── cmd_admin.lua     /kick, /allow, /god, /reset, /bring, /players, /rejoin, /hop, /chat, /face, /addadmin
├── cmd_spotify.lua   /play, /queue, /devices, /pause, /skip, /prev, /np, /vol, /shuffle, /loop
├── cmd_tts.lua       /say, /announce, /voice, /stoptts, /cleartts
├── cmd_quiz.lua      /ask, /real, /gen, /memorize, /clearmem, /copyquiz, /jump
└── README.md
```

---

## First-time setup

1. **Run the loader** (one-liner above). A console window opens.
2. **Set your Gemini key:** `/setkey YOUR_GEMINI_API_KEY` — saved to a file, so you only do this once.
3. **Set your Spotify token** (optional, for music): `/settoken YOUR_OAUTH_TOKEN`
   - Get one from the Spotify console with the scopes `user-read-currently-playing`, `user-read-playback-state`, and `user-modify-playback-state`.
   - Requires **Spotify Premium**.
4. Type `/help` (console) or `!help` (in-game chat) for the full command list.

Commands work two ways: `!command` in Roblox chat, or `/command` in the executor console. Only users in the allowed list can run them — edit `allowedUsers` in `loader.lua` or use `/addadmin <name>`.

---

## Music through voice chat

The Spotify commands drive your **real Spotify app** through the Web API — the bot doesn't stream audio itself. To broadcast into Roblox VC:

1. Install a virtual audio device (VB-CABLE / VoiceMeeter).
2. Set Spotify's output to the virtual cable.
3. Set the virtual cable as your **microphone** in Roblox.
4. `!play <song>` → Spotify plays it → the cable feeds it into VC.

Requirements: Spotify Premium, an **active Spotify device** (the app open somewhere), and the `user-modify-playback-state` scope on your token. `/devices` lists what's available if playback won't start.

---

## Editing / adding modules

Because each module is loaded independently, you just edit the file in the repo and re-run the loader — no re-pasting a monolith.

**To add a new module:**

1. Create `cmd_yourfeature.lua` at the repo root. It receives `ctx` as its vararg:

   ```lua
   local ctx = ...

   ctx.registerCommand({
       aliases = { "hello", "hi" },
       args = "<name>",
       info = "Say hi to someone",
       category = "Fun",
       permission = "admin",      -- "admin" or "all"
       fn = function(args, player)
           ctx.BotChat("👋 Hi " .. args)
       end,
   })
   ```

2. Add its filename to the `modules` list in `loader.lua`:

   ```lua
   local modules = {
       "cmd_help.lua",
       "cmd_fly.lua",
       -- ...
       "cmd_yourfeature.lua",   -- <-- new
   }
   ```

3. Push and re-run. `/help` picks up the new commands automatically.

**What `ctx` gives you:** services (`ctx.Players`, `ctx.HttpService`, …), `ctx.Chat` / `ctx.BotChat` (RBXGeneral bypass), `ctx.geminiRequest`, `ctx.registerCommand`, shared helpers (`ctx.findPlayer`, `ctx.getHRP`, `ctx.facePlayer`, `ctx.getPlayerContext`), plus `ctx.settings`, `ctx.state`, and `ctx.stats`.

---

## Dev mode (local files)

While iterating, loading from GitHub means waiting on the ~5-minute raw CDN cache. To test against local files instead, open `loader.lua` and set:

```lua
local USE_LOCAL = true          -- read modules from disk instead of GitHub
local LOCAL_PATH = "quizbot_v3/" -- folder in your executor workspace
```

Drop all the module files in that workspace folder and run the loader. Flip `USE_LOCAL` back to `false` before pushing. (If you must test live from GitHub mid-edit, set `CACHE_BUST = true` to append a timestamp and skip the cache.)

---

## Config reference (`loader.lua`, top of file)

| Setting | Purpose |
|---|---|
| `BASE_URL` | Your repo's raw base URL (`.../<user>/<repo>/<branch>/`) |
| `USE_LOCAL` | `false` = GitHub, `true` = local workspace folder |
| `LOCAL_PATH` | Workspace folder used when `USE_LOCAL = true` |
| `CACHE_BUST` | Append a timestamp to GitHub URLs to skip the CDN cache |

Models used: `gemini-2.5-flash` (chat), `gemini-2.5-pro` (quiz generation), `gemini-2.5-flash-preview-tts` (voice). Change them in `ctx.settings` inside `loader.lua`.
