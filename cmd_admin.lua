--[[
    QuizBot v3 Module: Admin Commands
    Player management, character manipulation, server utilities.
    Registers: /kick, /allow, /god, /reset, /bring, /players, /rejoin, /hop
]]
local ctx = ...

-- Use shared helpers from ctx (defined in loader)
local findPlayer = ctx.findPlayer
local getHRP = ctx.getHRP

local function getHumanoid()
    local char = ctx.LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function addUnique(list, value)
    for _, item in ipairs(list) do
        if item == value then return false end
    end
    table.insert(list, value)
    return true
end

local rigMorph = {
    originalCharacter = nil,
    activeModel = nil,
}

local function setCameraToCharacter(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and workspace.CurrentCamera then
        workspace.CurrentCamera.CameraSubject = hum
    end
end

local function switchRig(rigName)
    local rigType = rigName == "R6" and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
    local oldChar = ctx.LocalPlayer.Character
    local oldHRP = oldChar and oldChar:FindFirstChild("HumanoidRootPart")
    local oldCFrame = oldHRP and oldHRP.CFrame or CFrame.new(0, 5, 0)

    if not rigMorph.originalCharacter and oldChar ~= rigMorph.activeModel then
        rigMorph.originalCharacter = oldChar
    end

    local okDesc, desc = pcall(function()
        return ctx.Players:GetHumanoidDescriptionFromUserId(ctx.LocalPlayer.UserId)
    end)
    if not okDesc or not desc then
        ctx.BotChat("Could not get your avatar description")
        return
    end

    local okModel, model = pcall(function()
        return ctx.Players:CreateHumanoidModelFromDescription(desc, rigType)
    end)
    if not okModel or not model then
        ctx.BotChat("This game blocked the " .. rigName .. " morph")
        return
    end

    model.Name = ctx.LocalPlayer.Name .. "_" .. rigName
    model.Parent = workspace

    local root = model:FindFirstChild("HumanoidRootPart")
    if root then
        model.PrimaryPart = root
        model:PivotTo(oldCFrame)
    end

    if rigMorph.activeModel and rigMorph.activeModel ~= model then
        pcall(function() rigMorph.activeModel:Destroy() end)
    end
    if oldChar and oldChar ~= rigMorph.activeModel and oldChar.Parent then
        pcall(function() oldChar.Parent = nil end)
    end

    rigMorph.activeModel = model
    ctx.LocalPlayer.Character = model
    setCameraToCharacter(model)
    ctx.BotChat("Switched to " .. rigName .. " morph")
end

local function restoreRigMorph()
    local original = rigMorph.originalCharacter
    if not original then
        ctx.BotChat("No original character saved")
        return
    end

    local current = ctx.LocalPlayer.Character
    local currentHRP = current and current:FindFirstChild("HumanoidRootPart")
    local currentCFrame = currentHRP and currentHRP.CFrame or CFrame.new(0, 5, 0)

    if not original.Parent then
        original.Parent = workspace
    end
    local root = original:FindFirstChild("HumanoidRootPart")
    if root then
        original:PivotTo(currentCFrame)
    end

    ctx.LocalPlayer.Character = original
    setCameraToCharacter(original)

    if rigMorph.activeModel and rigMorph.activeModel.Parent then
        pcall(function() rigMorph.activeModel:Destroy() end)
    end
    rigMorph.activeModel = nil
    rigMorph.originalCharacter = nil
    ctx.BotChat("Original character restored")
end

----------------------------------------------------------------
-- Register Commands
----------------------------------------------------------------

-- /kick (block from quiz interactions)
ctx.registerCommand({
    aliases = {"kick", "block"},
    args = "<player>",
    info = "Block player from quiz interactions",
    category = "Admin",
    fn = function(args)
        if args == "" then return end
        local target = findPlayer(args)
        if target then
            -- Add to blocked list in ctx
            ctx.blockedPlayers = ctx.blockedPlayers or {}
            addUnique(ctx.blockedPlayers, target.Name)
            ctx.BotChat("🚫 | " .. target.DisplayName .. " blocked")
        else
            ctx.BotChat("❌ | Player not found: " .. args)
        end
    end,
})

-- /allow (whitelist for quiz)
ctx.registerCommand({
    aliases = {"allow", "unblock", "whitelist"},
    args = "<player>",
    info = "Unblock/whitelist a player",
    category = "Admin",
    fn = function(args)
        if args == "" then return end
        ctx.blockedPlayers = ctx.blockedPlayers or {}
        local target = findPlayer(args)
        local name = target and target.Name or args
        for i, n in ipairs(ctx.blockedPlayers) do
            if n == name then
                table.remove(ctx.blockedPlayers, i)
                ctx.BotChat("✅ | " .. name .. " unblocked")
                return
            end
        end
        ctx.BotChat("ℹ️ | " .. name .. " was not blocked")
    end,
})

ctx.registerCommand({
    aliases = {"blocked", "blocklist"},
    info = "Show blocked quiz participants",
    category = "Admin",
    fn = function()
        ctx.blockedPlayers = ctx.blockedPlayers or {}
        if #ctx.blockedPlayers == 0 then
            ctx.BotChat("No blocked players")
            return
        end
        ctx.BotChat("Blocked: " .. table.concat(ctx.blockedPlayers, ", "))
    end,
})

ctx.registerCommand({
    aliases = {"clearblocks", "unblockall"},
    info = "Clear blocked quiz participants",
    category = "Admin",
    fn = function()
        ctx.blockedPlayers = {}
        ctx.BotChat("Block list cleared")
    end,
})

-- /god - Infinite health
ctx.registerCommand({
    aliases = {"god", "godmode"},
    info = "Toggle god mode (infinite health)",
    category = "Admin",
    fn = function()
        local char = ctx.LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end

        if hum.MaxHealth == math.huge then
            hum.MaxHealth = 100
            hum.Health = 100
            ctx.BotChat("💔 | God mode OFF")
        else
            hum.MaxHealth = math.huge
            hum.Health = math.huge
            ctx.BotChat("💖 | God mode ON")
        end
    end,
})

-- /reset - Reset character
ctx.registerCommand({
    aliases = {"reset", "die", "respawn"},
    info = "Reset your character",
    category = "Admin",
    fn = function()
        local char = ctx.LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 0 end
        end
    end,
})

ctx.registerCommand({
    aliases = {"ws", "walkspeed"},
    args = "<speed>",
    info = "Set local walk speed",
    category = "Admin",
    fn = function(args)
        local value = tonumber(args)
        local hum = getHumanoid()
        if not value or not hum then
            ctx.consoleWarn("Usage: /ws <speed>")
            return
        end
        hum.WalkSpeed = value
        ctx.BotChat("WalkSpeed: " .. tostring(value))
    end,
})

ctx.registerCommand({
    aliases = {"jp", "jumppower"},
    args = "<power>",
    info = "Set local jump power",
    category = "Admin",
    fn = function(args)
        local value = tonumber(args)
        local hum = getHumanoid()
        if not value or not hum then
            ctx.consoleWarn("Usage: /jp <power>")
            return
        end
        hum.UseJumpPower = true
        hum.JumpPower = value
        ctx.BotChat("JumpPower: " .. tostring(value))
    end,
})

ctx.registerCommand({
    aliases = {"gravity", "grav"},
    args = "<number>",
    info = "Set workspace gravity",
    category = "Admin",
    fn = function(args)
        local value = tonumber(args)
        if not value then
            ctx.consoleWarn("Usage: /gravity <number>")
            return
        end
        workspace.Gravity = value
        ctx.BotChat("Gravity: " .. tostring(value))
    end,
})

ctx.registerCommand({
    aliases = {"sit"},
    info = "Sit your character",
    category = "Admin",
    fn = function()
        local hum = getHumanoid()
        if hum then hum.Sit = true end
    end,
})

ctx.registerCommand({
    aliases = {"unsit", "stand"},
    info = "Stand your character",
    category = "Admin",
    fn = function()
        local hum = getHumanoid()
        if hum then
            hum.Sit = false
            hum.PlatformStand = false
        end
    end,
})

ctx.registerCommand({
    aliases = {"jump"},
    info = "Make your character jump",
    category = "Admin",
    fn = function()
        local hum = getHumanoid()
        if hum then hum.Jump = true end
    end,
})

ctx.registerCommand({
    aliases = {"r6", "tor6"},
    info = "Switch to a local R6 avatar morph",
    category = "Admin",
    fn = function()
        switchRig("R6")
    end,
})

ctx.registerCommand({
    aliases = {"r15", "tor15"},
    info = "Switch to a local R15 avatar morph",
    category = "Admin",
    fn = function()
        switchRig("R15")
    end,
})

ctx.registerCommand({
    aliases = {"unmorph", "restoremorph"},
    info = "Restore your original character after r6/r15",
    category = "Admin",
    fn = function()
        restoreRigMorph()
    end,
})

-- /bring - Teleport a player to you (if network owner)
ctx.registerCommand({
    aliases = {"bring"},
    args = "<player>",
    info = "Attempt to bring player to you",
    category = "Admin",
    fn = function(args)
        if args == "" then return end
        local target = findPlayer(args)
        if not target or not target.Character then
            ctx.BotChat("❌ | Player not found")
            return
        end
        local myHRP = getHRP()
        local theirHRP = target.Character:FindFirstChild("HumanoidRootPart")
        if myHRP and theirHRP then
            -- This only works if we have network ownership
            pcall(function()
                theirHRP.CFrame = myHRP.CFrame + myHRP.CFrame.LookVector * 5
            end)
            ctx.BotChat("📍 | Attempted to bring " .. target.DisplayName)
        end
    end,
})

-- /players - List all players
ctx.registerCommand({
    aliases = {"players", "plist", "who"},
    info = "List all players in server",
    category = "Admin",
    fn = function()
        local list = {}
        for _, p in ipairs(ctx.Players:GetPlayers()) do
            table.insert(list, p.DisplayName .. " (@" .. p.Name .. ")")
        end
        rconsoleprint("\n=== Players (" .. #list .. ") ===\n")
        for i, name in ipairs(list) do
            rconsoleprint("  " .. i .. ". " .. name .. "\n")
        end
        rconsoleprint("========================\n\n")
        ctx.BotChat("👥 | " .. #list .. " players in server")
    end,
})

-- /rejoin - Rejoin current server
ctx.registerCommand({
    aliases = {"rejoin", "rj"},
    info = "Rejoin the current server",
    category = "Admin",
    fn = function()
        ctx.BotChat("🔄 | Rejoining...")
        task.wait(1)
        local ts = game:GetService("TeleportService")
        ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, ctx.LocalPlayer)
    end,
})

-- /hop - Server hop
ctx.registerCommand({
    aliases = {"hop", "serverhop"},
    info = "Hop to a different server",
    category = "Admin",
    fn = function()
        ctx.consoleLog("Fetching servers...")
        local ok, servers = pcall(function()
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
                .. "/servers/Public?sortOrder=Asc&limit=25"
            local response = request({ Url = url, Method = "GET" })
            return ctx.HttpService:JSONDecode(response.Body)
        end)

        if not ok or not servers or not servers.data then
            ctx.BotChat("❌ | Failed to fetch servers")
            return
        end

        local candidates = {}
        for _, server in ipairs(servers.data) do
            if server.playing and server.playing > 1
            and server.playing < server.maxPlayers
            and server.id ~= game.JobId then
                table.insert(candidates, server)
            end
        end

        if #candidates == 0 then
            ctx.BotChat("❌ | No suitable servers found")
            return
        end

        local target = candidates[math.random(1, #candidates)]
        ctx.BotChat("🌐 | Hopping to server (" .. target.playing .. " players)...")

        -- Queue restart if available
        if queueonteleport then
            pcall(function() queueonteleport(ctx.loaderScript) end)
        end

        task.wait(1)
        game:GetService("TeleportService"):TeleportToPlaceInstance(
            game.PlaceId, target.id, ctx.LocalPlayer
        )
    end,
})

-- /chat - Send a message as the bot
ctx.registerCommand({
    aliases = {"chat", "say_chat", "msg"},
    args = "<message>",
    info = "Send a chat message",
    category = "Admin",
    fn = function(args)
        if args == "" then return end
        ctx.Chat(args)
    end,
})

-- /face - Face a player
ctx.registerCommand({
    aliases = {"face", "lookat"},
    args = "<player>",
    info = "Face toward a player",
    category = "Admin",
    fn = function(args)
        if args == "" then return end
        local target = findPlayer(args)
        if not target or not target.Character then
            ctx.BotChat("❌ | Player not found")
            return
        end
        local myHRP = getHRP()
        local theirHRP = target.Character:FindFirstChild("HumanoidRootPart")
        if myHRP and theirHRP then
            local lookPos = Vector3.new(theirHRP.Position.X, myHRP.Position.Y, theirHRP.Position.Z)
            myHRP.CFrame = CFrame.lookAt(myHRP.Position, lookPos)
            ctx.BotChat("👀 | Facing " .. target.DisplayName)
        end
    end,
})

ctx.registerCommand({
    aliases = {"view", "spectate", "watch"},
    args = "<player>",
    info = "Set camera to watch a player",
    category = "Admin",
    fn = function(args)
        local target = findPlayer(args)
        if not target or not target.Character then
            ctx.BotChat("Player not found")
            return
        end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum and workspace.CurrentCamera then
            workspace.CurrentCamera.CameraSubject = hum
            ctx.BotChat("Viewing " .. target.DisplayName)
        end
    end,
})

ctx.registerCommand({
    aliases = {"unview", "unspectate"},
    info = "Return camera to your character",
    category = "Admin",
    fn = function()
        local hum = getHumanoid()
        if hum and workspace.CurrentCamera then
            workspace.CurrentCamera.CameraSubject = hum
            ctx.BotChat("Camera restored")
        end
    end,
})

ctx.registerCommand({
    aliases = {"pos", "coords", "position"},
    info = "Print current position",
    category = "Admin",
    fn = function()
        local hrp = getHRP()
        if not hrp then return end
        local p = hrp.Position
        local text = string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z)
        rconsoleprint("Position: " .. text .. "\n")
        ctx.BotChat("Position: " .. text)
    end,
})

ctx.registerCommand({
    aliases = {"copypos", "copycoords"},
    info = "Copy current position to clipboard",
    category = "Admin",
    fn = function()
        local hrp = getHRP()
        if not hrp then return end
        local p = hrp.Position
        local text = string.format("CFrame.new(%f, %f, %f)", p.X, p.Y, p.Z)
        if setclipboard then
            setclipboard(text)
            ctx.BotChat("Position copied")
        else
            rconsoleprint(text .. "\n")
        end
    end,
})

-- /addadmin - Add allowed user
ctx.registerCommand({
    aliases = {"addadmin", "adduser"},
    args = "<username>",
    info = "Add a user to the allowed list",
    category = "Admin",
    fn = function(args)
        if args == "" then return end
        addUnique(ctx.settings.allowedUsers, args)
        ctx.BotChat("✅ | Added " .. args .. " to admin list")
    end,
})

ctx.registerCommand({
    aliases = {"removeadmin", "deladmin", "unadmin"},
    args = "<username>",
    info = "Remove a user from the allowed list",
    category = "Admin",
    fn = function(args)
        if args == "" then return end
        for i, name in ipairs(ctx.settings.allowedUsers) do
            if string.lower(name) == string.lower(args) then
                table.remove(ctx.settings.allowedUsers, i)
                ctx.BotChat("Removed " .. name .. " from admin list")
                return
            end
        end
        ctx.BotChat(args .. " is not in the admin list")
    end,
})

ctx.registerCommand({
    aliases = {"admins", "allowed"},
    info = "List allowed admins",
    category = "Admin",
    fn = function()
        ctx.BotChat("Admins: " .. table.concat(ctx.settings.allowedUsers, ", "))
    end,
})
