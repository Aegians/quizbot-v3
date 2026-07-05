--[[
    QuizBot v3 Module: CFrame Fly System
    Registers: /fly, /unfly, /speed, /flyto, /follow, /unfollow, /tp, /noclip
]]
local ctx = ...

local flyConnection = nil
local followThread = nil
local noclipConnection = nil

local flyActive = false
local noclipActive = false
local stopFollow = nil

-- Use shared helpers from ctx (defined in loader)
local getHRP = ctx.getHRP
local getHumanoid = ctx.getHumanoid
local findPlayer = ctx.findPlayer

----------------------------------------------------------------
-- Fly Engine
-- Updates HRP.CFrame every frame based on held keys
----------------------------------------------------------------
local function startFly()
    if flyActive then return end
    flyActive = true
    ctx.state.flying = true

    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then
        ctx.consoleWarn("No character to fly")
        flyActive = false
        ctx.state.flying = false
        return
    end

    -- Disable default gravity
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.Name = "QuizBotFlyVel"
    bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVel.Velocity = Vector3.new(0, 0, 0)
    bodyVel.Parent = hrp

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "QuizBotFlyGyro"
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.D = 100
    bodyGyro.P = 10000
    bodyGyro.Parent = hrp

    hum.PlatformStand = true

    flyConnection = ctx.RunService.RenderStepped:Connect(function()
        if not flyActive then return end

        local hrp2 = getHRP()
        if not hrp2 then return end
        local cam = workspace.CurrentCamera

        local speed = ctx.settings.flySpeed
        local moveDir = Vector3.new(0, 0, 0)

        -- WASD + Space/Shift for vertical
        if ctx.UIS:IsKeyDown(Enum.KeyCode.W) then
            moveDir += cam.CFrame.LookVector
        end
        if ctx.UIS:IsKeyDown(Enum.KeyCode.S) then
            moveDir -= cam.CFrame.LookVector
        end
        if ctx.UIS:IsKeyDown(Enum.KeyCode.A) then
            moveDir -= cam.CFrame.RightVector
        end
        if ctx.UIS:IsKeyDown(Enum.KeyCode.D) then
            moveDir += cam.CFrame.RightVector
        end
        if ctx.UIS:IsKeyDown(Enum.KeyCode.Space) then
            moveDir += Vector3.new(0, 1, 0)
        end
        if ctx.UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDir -= Vector3.new(0, 1, 0)
        end

        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit * speed
        end

        bodyVel.Velocity = moveDir
        bodyGyro.CFrame = cam.CFrame
    end)

    ctx.track(flyConnection)
    ctx.consoleLog("Fly enabled (speed: " .. ctx.settings.flySpeed .. ")")
end

local function stopFly()
    if not flyActive then return end
    flyActive = false
    ctx.state.flying = false

    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end

    local hrp = getHRP()
    local hum = getHumanoid()
    if hrp then
        local bv = hrp:FindFirstChild("QuizBotFlyVel")
        local bg = hrp:FindFirstChild("QuizBotFlyGyro")
        if bv then bv:Destroy() end
        if bg then bg:Destroy() end
    end
    if hum then
        hum.PlatformStand = false
    end

    ctx.consoleLog("Fly disabled")
end

----------------------------------------------------------------
-- Follow System (ground-based)
----------------------------------------------------------------
local function startFollow(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end

    stopFly()
    stopFollow()

    ctx.state.following = true
    ctx.state.followTarget = targetPlayer

    followThread = task.spawn(function()
        while ctx.state.following do
            local hrp = getHRP()
            local hum = getHumanoid()
            local targetChar = targetPlayer.Character
            if hrp and hum and targetChar then
                local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
                if targetHRP then
                    local offset = targetHRP.CFrame.LookVector * -4
                    local goal = targetHRP.Position + offset
                    local dist = (goal - hrp.Position).Magnitude

                    if hum.Sit then hum.Sit = false end
                    if hum.PlatformStand then hum.PlatformStand = false end

                    if dist > 6 then
                        hum:MoveTo(goal)
                    else
                        hum:Move(Vector3.new(0, 0, 0), false)
                    end
                end
            end
            task.wait(0.25)
        end
    end)
end

stopFollow = function()
    ctx.state.following = false
    ctx.state.followTarget = nil
    local hum = getHumanoid()
    if hum then
        hum:Move(Vector3.new(0, 0, 0), false)
    end
    if followThread then
        pcall(function() task.cancel(followThread) end)
        followThread = nil
    end
end

----------------------------------------------------------------
-- Noclip
----------------------------------------------------------------
local function startNoclip()
    if noclipActive then return end
    noclipActive = true
    
    noclipConnection = ctx.RunService.Stepped:Connect(function()
        local char = ctx.LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
    
    ctx.track(noclipConnection)
    ctx.consoleLog("Noclip enabled")
end

local function stopNoclip()
    if not noclipActive then return end
    noclipActive = false
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    ctx.consoleLog("Noclip disabled")
end

----------------------------------------------------------------
-- Register Commands
----------------------------------------------------------------

ctx.registerCommand({
    aliases = {"fly", "f"},
    args = "[speed]",
    info = "Toggle CFrame fly",
    category = "Movement",
    fn = function(args)
        if args ~= "" then
            local speed = tonumber(args)
            if speed then ctx.settings.flySpeed = speed end
        end
        if flyActive then
            stopFollow()
            stopFly()
            ctx.BotChat("🛬 | Fly disabled")
        else
            startFly()
            ctx.BotChat("🛫 | Fly enabled (speed: " .. ctx.settings.flySpeed .. ")")
        end
    end,
})

ctx.registerCommand({
    aliases = {"unfly", "land"},
    info = "Disable fly",
    category = "Movement",
    fn = function()
        stopFollow()
        stopFly()
        ctx.BotChat("🛬 | Landed")
    end,
})

ctx.registerCommand({
    aliases = {"speed", "flyspeed", "fs"},
    args = "<number>",
    info = "Set fly speed",
    category = "Movement",
    fn = function(args)
        local speed = tonumber(args)
        if not speed then
            ctx.consoleWarn("Usage: /speed <number>")
            return
        end
        ctx.settings.flySpeed = speed
        ctx.consoleLog("Fly speed: " .. speed)
        ctx.BotChat("⚡ | Speed: " .. speed)
    end,
})

ctx.registerCommand({
    aliases = {"flyto", "goto", "fgoto"},
    args = "<player>",
    info = "Fly to a player",
    category = "Movement",
    fn = function(args)
        if args == "" then
            ctx.consoleWarn("Usage: /flyto <player>")
            return
        end
        local target = findPlayer(args)
        if not target then
            ctx.BotChat("❌ | Player not found: " .. args)
            return
        end
        if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            ctx.BotChat("❌ | Target has no character")
            return
        end

        if not flyActive then startFly() end

        local hrp = getHRP()
        local targetPos = target.Character.HumanoidRootPart.Position + Vector3.new(0, 5, 0)
        if hrp then
            hrp.CFrame = CFrame.new(targetPos)
            ctx.BotChat("✈️ | Flew to " .. target.DisplayName)
        end
    end,
})

ctx.registerCommand({
    aliases = {"follow", "fol"},
    args = "<player>",
    info = "Follow a player on foot",
    category = "Movement",
    fn = function(args)
        if ctx.state.following then
            stopFollow()
            ctx.BotChat("🛑 | Stopped following")
            return
        end
        if args == "" then
            ctx.consoleWarn("Usage: /follow <player>")
            return
        end
        local target = findPlayer(args)
        if not target then
            ctx.BotChat("❌ | Player not found: " .. args)
            return
        end
        startFollow(target)
        ctx.BotChat("👣 | Following " .. target.DisplayName)
    end,
})

ctx.registerCommand({
    aliases = {"unfollow", "stopfollow"},
    info = "Stop following",
    category = "Movement",
    fn = function()
        stopFollow()
        ctx.BotChat("🛑 | Stopped following")
    end,
})

ctx.registerCommand({
    aliases = {"tp", "teleport", "to"},
    args = "<player>",
    info = "Instant teleport to player (no fly)",
    category = "Movement",
    fn = function(args)
        if args == "" then
            ctx.consoleWarn("Usage: /tp <player>")
            return
        end
        local target = findPlayer(args)
        if not target or not target.Character then
            ctx.BotChat("❌ | Player not found")
            return
        end
        local hrp = getHRP()
        local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp and targetHRP then
            hrp.CFrame = targetHRP.CFrame + Vector3.new(0, 3, 0)
            ctx.BotChat("📍 | Teleported to " .. target.DisplayName)
        end
    end,
})

ctx.registerCommand({
    aliases = {"noclip", "nc"},
    info = "Toggle noclip (walk through walls)",
    category = "Movement",
    fn = function()
        if noclipActive then
            stopNoclip()
            ctx.BotChat("🧱 | Noclip disabled")
        else
            startNoclip()
            ctx.BotChat("👻 | Noclip enabled")
        end
    end,
})

-- Re-enable fly/follow on respawn
-- Capture the state BEFORE stopping (stopFly/stopFollow clear the flags).
ctx.track(ctx.LocalPlayer.CharacterAdded:Connect(function(char)
    local wasFlying = flyActive
    local wasFollowing = ctx.state.following
    local prevTarget = ctx.state.followTarget

    if not wasFlying and not wasFollowing then return end

    -- Old body movers died with the old character; clear our state cleanly
    stopFollow()
    if wasFlying then stopFly() end

    -- Wait for the new character to be ready (humanoid must exist)
    char:WaitForChild("Humanoid", 10)
    char:WaitForChild("HumanoidRootPart", 10)
    task.wait(0.5)

    if wasFlying then startFly() end

    -- Resume follow if it was active and the target is still in-game
    if wasFollowing and prevTarget and prevTarget.Parent then
        startFollow(prevTarget)
    end
end))
