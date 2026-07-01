--[[
    QuizBot v3 Module: Help & Utility Commands
    Registers: /help, /stats, /setkey, /settoken, /setspotifyauth, /destroy
]]
local ctx = ...

-- /help - List all commands grouped by category
ctx.registerCommand({
    aliases = {"help", "h", "cmds", "commands"},
    info = "List all commands",
    category = "Utility",
    permission = "admin",
    fn = function()
        rconsoleprint("\n========== QUIZBOT v" .. ctx.VERSION .. " COMMANDS ==========\n\n")
        
        local categories = {}
        local catOrder = {}
        
        for _, cmd in ipairs(ctx.getCommands()) do
            local cat = cmd.category or "Misc"
            if not categories[cat] then
                categories[cat] = {}
                table.insert(catOrder, cat)
            end
            table.insert(categories[cat], cmd)
        end
        
        for _, cat in ipairs(catOrder) do
            rconsoleprint("  [" .. cat .. "]\n")
            for _, cmd in ipairs(categories[cat]) do
                local names = table.concat(cmd.aliases, ", ")
                local args = cmd.args and (" " .. cmd.args) or ""
                rconsoleprint("    " .. names .. args .. " - " .. cmd.info .. "\n")
            end
            rconsoleprint("\n")
        end
        
        rconsoleprint("==========================================\n\n")
    end,
})

-- /stats - Session statistics
ctx.registerCommand({
    aliases = {"stats", "status"},
    info = "Show session statistics",
    category = "Utility",
    permission = "admin",
    fn = function()
        local uptime = tick() - ctx.startTime
        local hours = math.floor(uptime / 3600)
        local mins = math.floor((uptime % 3600) / 60)
        local secs = math.floor(uptime % 60)
        
        rconsoleprint("\n========== SESSION STATS ==========\n")
        rconsoleprint("  Uptime:       " .. string.format("%02d:%02d:%02d", hours, mins, secs) .. "\n")
        rconsoleprint("  Commands Run: " .. ctx.stats.commandsRun .. "\n")
        rconsoleprint("  Messages:     " .. ctx.stats.messagesSent .. "\n")
        rconsoleprint("  AI Requests:  " .. ctx.stats.aiRequests .. "\n")
        rconsoleprint("  Tokens:       " .. ctx.stats.tokensTotal .. " (In: " .. ctx.stats.tokensInput .. " | Out: " .. ctx.stats.tokensOutput .. ")\n")
        rconsoleprint("  Players:      " .. #ctx.Players:GetPlayers() .. "\n")
        rconsoleprint("  PlaceId:      " .. game.PlaceId .. "\n")
        rconsoleprint("===================================\n\n")
        
        ctx.BotChat("📊 | Uptime: " .. string.format("%02d:%02d:%02d", hours, mins, secs)
            .. " | Cmds: " .. ctx.stats.commandsRun
            .. " | AI: " .. ctx.stats.aiRequests
            .. " | Tokens: " .. ctx.stats.tokensTotal)
    end,
})

-- /setkey - Set Gemini API key (console-only to avoid leaking in chat)
ctx.registerCommand({
    aliases = {"setkey", "geminikey", "apikey"},
    args = "<key>",
    info = "Set Gemini API key (console only, saved to file)",
    category = "Utility",
    permission = "admin",
    consoleOnly = true,
    fn = function(args)
        if args == "" then
            ctx.consoleWarn("Usage: /setkey <your-api-key>")
            return
        end
        ctx.saveGeminiKey(args)
        ctx.consoleLog("Gemini API key saved!")
        ctx.notify("API Key Set", "Gemini key saved to file")
    end,
})

-- /settoken - Set Spotify token (console-only to avoid leaking in chat)
ctx.registerCommand({
    aliases = {"settoken", "spotifytoken", "stoken"},
    args = "<token>",
    info = "Set Spotify OAuth token (console only, saved to file)",
    category = "Utility",
    permission = "admin",
    consoleOnly = true,
    fn = function(args)
        if args == "" then
            ctx.consoleWarn("Usage: /settoken <spotify-oauth-token>")
            ctx.consoleWarn("Get one at: https://developer.spotify.com/console/get-users-currently-playing-track")
            return
        end
        ctx.saveSpotifyToken(args)
        ctx.consoleLog("Spotify token saved!")
        ctx.notify("Token Set", "Spotify token saved to file")
    end,
})

-- /setspotifyauth - Set Spotify refresh credentials (console-only)
ctx.registerCommand({
    aliases = {"setspotifyauth", "spotifyauth", "setsauth"},
    args = "<client_id> <client_secret> <refresh_token>",
    info = "Set Spotify refresh auth (console only, saved to file)",
    category = "Utility",
    permission = "admin",
    consoleOnly = true,
    fn = function(args)
        local clientId, clientSecret, refreshToken = string.match(args, "^(%S+)%s+(%S+)%s+(%S+)$")
        if not clientId or not clientSecret or not refreshToken then
            ctx.consoleWarn("Usage: /setspotifyauth <client_id> <client_secret> <refresh_token>")
            ctx.consoleWarn("Use this for long-lived Spotify auth; /settoken still accepts short-lived BQ access tokens.")
            return
        end

        ctx.saveSpotifyAuth(clientId, clientSecret, refreshToken)
        ctx.settings.spotifyToken = nil
        ctx.settings.spotifyTokenExpiresAt = nil
        ctx.consoleLog("Spotify refresh auth saved! The next music command will refresh the access token.")
        ctx.notify("Spotify Auth Set", "Refresh auth saved to file")
    end,
})

-- /prefix - Change command prefix
ctx.registerCommand({
    aliases = {"prefix"},
    args = "<char>",
    info = "Change chat command prefix (default: !)",
    category = "Utility",
    permission = "admin",
    fn = function(args)
        if args == "" or #args > 3 then
            ctx.consoleWarn("Usage: /prefix <char> (1-3 characters)")
            return
        end
        ctx.settings.prefix = args
        ctx.consoleLog("Prefix changed to: " .. args)
        ctx.BotChat("⚙️ | Prefix set to: " .. args)
    end,
})

-- /destroy - Kill the script
ctx.registerCommand({
    aliases = {"destroy", "kill", "exit"},
    info = "Destroy QuizBot and cleanup",
    category = "Utility",
    permission = "admin",
    fn = function()
        ctx.consoleLog("Destroying QuizBot...")
        ctx.BotChat("👋 | QuizBot shutting down")
        
        -- Disconnect all connections
        for _, conn in ipairs(ctx.connections) do
            pcall(function() conn:Disconnect() end)
        end
        
        getgenv().QUIZBOT_V3_RUNNING = nil
        task.wait(1)
        rconsolehide()
    end,
})
