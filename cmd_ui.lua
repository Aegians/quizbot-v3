--[[
    QuizBot v3 Module: Rayfield UI
    Reintroduces the original quizbot-style UI, wired to the v3 modules.
]]
local ctx = ...

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local selectedCategory = nil
local selectedDifficulty = "all"
local aiTopic = ""
local selectedVoice = "Aoede"
local selectedTtsMode = "bridge"
local spotifyQuery = ""
local targetPlayerName = ""
local pointsAmount = 10

local function runConsole(command)
    ctx.runCommand("/" .. command, ctx.LocalPlayer, "console")
end

local function getCategoryNames()
    local names = {}
    local _, order = nil, nil
    if ctx.getQuizCategories then
        _, order = ctx.getQuizCategories()
    end
    if order then
        for _, name in ipairs(order) do
            table.insert(names, name)
        end
    end
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    if #names == 0 then
        table.insert(names, "No categories loaded")
    end
    return names
end

local function getDifficultyOptions(categoryName)
    if ctx.getQuizCategoryDifficulties and categoryName then
        local options = ctx.getQuizCategoryDifficulties(categoryName)
        if #options > 0 then return options end
    end
    return { "all", "easy", "medium", "hard" }
end

local function getPlayerNames()
    local names = {}
    for _, player in ipairs(ctx.Players:GetPlayers()) do
        table.insert(names, player.DisplayName .. " (@" .. player.Name .. ")")
    end
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    if #names == 0 then table.insert(names, "No players") end
    return names
end

local function parsePlayerOption(option)
    local value = type(option) == "table" and option[1] or option
    if not value then return "" end
    return string.match(value, "@([^)]+)") or value
end

local function startSelectedCategory()
    if not selectedCategory or selectedCategory == "No categories loaded" then
        notify("Invalid category", "Select a category first")
        return
    end

    local command = "start " .. selectedCategory
    if selectedDifficulty and selectedDifficulty ~= "all" then
        command = command .. " " .. selectedDifficulty
    end
    runConsole(command)
end

local function notify(title, text)
    if ctx.notify then
        ctx.notify(title, text, 4)
    else
        ctx.consoleLog(title .. ": " .. text)
    end
end

local function loadRayfield()
    if setgenv then
        pcall(function()
            getgenv().DISABLE_RAYFIELD_REQUESTS = true
            getgenv().rayfieldCached = true
        end)
    end

    local ok, library = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Damian-11/Rayfield/stable/source.lua"))()
    end)
    if not ok or not library then
        ctx.consoleErr("UI failed to load Rayfield: " .. tostring(library))
        return nil
    end
    return library
end

local library = loadRayfield()
if not library then return end

local window = library:CreateWindow({
    Name = "QuizBot v" .. tostring(ctx.VERSION),
    LoadingTitle = "Loading QuizBot...",
    LoadingSubtitle = "v3 modular UI",
    ShowText = "quizbot",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
})

local function toggleUI(_actionName, inputState)
    if inputState == Enum.UserInputState.Begin then
        library:SetVisibility(not library:IsVisible())
    end
end

if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
    ContextActionService:BindAction("QuizBotToggleUI", toggleUI, true)
end

local mainTab = window:CreateTab("Main", 74002778429106)
mainTab:CreateSection("Category Selection")

local categoryLabel = mainTab:CreateLabel("Selected category: None")
local categoryDropdown
local difficultyDropdown

mainTab:CreateInput({
    Name = "Category",
    PlaceholderText = "Type a category name",
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        if ctx.findQuizCategory then
            local found = ctx.findQuizCategory(value)
            if found then
                selectedCategory = found
                selectedDifficulty = "all"
                categoryLabel:Set("Selected category: " .. found)
                if categoryDropdown then
                    categoryDropdown:Set({ found })
                end
                if difficultyDropdown then
                    difficultyDropdown:Refresh(getDifficultyOptions(found))
                    difficultyDropdown:Set({ "all" })
                end
            end
        end
    end,
})

categoryDropdown = mainTab:CreateDropdown({
    Name = "Category",
    Options = getCategoryNames(),
    CurrentOption = { "Select a category" },
    Callback = function(option)
        selectedCategory = type(option) == "table" and option[1] or option
        if selectedCategory and selectedCategory ~= "No categories loaded" then
            selectedDifficulty = "all"
            categoryLabel:Set("Selected category: " .. selectedCategory)
            if difficultyDropdown then
                difficultyDropdown:Refresh(getDifficultyOptions(selectedCategory))
                difficultyDropdown:Set({ "all" })
            end
        end
    end,
})

difficultyDropdown = mainTab:CreateDropdown({
    Name = "Difficulty",
    Options = { "all", "easy", "medium", "hard" },
    CurrentOption = { "all" },
    Callback = function(option)
        selectedDifficulty = type(option) == "table" and option[1] or option
    end,
})

mainTab:CreateButton({
    Name = "Refresh category list",
    Callback = function()
        categoryDropdown:Refresh(getCategoryNames())
        if difficultyDropdown then
            difficultyDropdown:Refresh(getDifficultyOptions(selectedCategory))
        end
        notify("Categories", "Category list refreshed")
    end,
})

mainTab:CreateButton({
    Name = "Send category list in chat",
    Callback = function()
        runConsole("categories")
    end,
})

mainTab:CreateSection("AI Quiz Generator")
mainTab:CreateInput({
    Name = "Topic",
    PlaceholderText = "Example: Roblox, Minecraft, music",
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        aiTopic = value or ""
    end,
})

mainTab:CreateButton({
    Name = "Generate quiz",
    Callback = function()
        if aiTopic == "" then
            notify("Invalid topic", "Enter a topic first")
            return
        end
        runConsole("gen " .. aiTopic)
    end,
})

mainTab:CreateButton({
    Name = "Generate and start quiz",
    Callback = function()
        if aiTopic == "" then
            notify("Invalid topic", "Enter a topic first")
            return
        end
        runConsole("quiz " .. aiTopic)
    end,
})

mainTab:CreateSection("Quiz Controls")
mainTab:CreateButton({
    Name = "Start selected category",
    Callback = function()
        startSelectedCategory()
    end,
})

mainTab:CreateButton({
    Name = "Play random category",
    Callback = function()
        local names = getCategoryNames()
        if #names == 0 or names[1] == "No categories loaded" then
            notify("Categories", "No categories loaded")
            return
        end
        selectedCategory = names[math.random(1, #names)]
        selectedDifficulty = "all"
        categoryLabel:Set("Selected category: " .. selectedCategory)
        if categoryDropdown then categoryDropdown:Set({ selectedCategory }) end
        if difficultyDropdown then
            difficultyDropdown:Refresh(getDifficultyOptions(selectedCategory))
            difficultyDropdown:Set({ "all" })
        end
        startSelectedCategory()
    end,
})

mainTab:CreateButton({
    Name = "Start generated quiz",
    Callback = function()
        runConsole("startquiz")
    end,
})

mainTab:CreateButton({
    Name = "Skip current question",
    Callback = function()
        runConsole("skipq")
    end,
})

mainTab:CreateButton({
    Name = "Stop quiz",
    Callback = function()
        runConsole("stopquiz")
    end,
})

mainTab:CreateButton({
    Name = "Show leaderboard",
    Callback = function()
        runConsole("lb")
    end,
})

local leaderboardTab = window:CreateTab("Leaderboard", 97885193604839)
leaderboardTab:CreateSection("Current Quiz Leaderboard")
leaderboardTab:CreateButton({
    Name = "Send leaderboard in chat",
    Callback = function()
        runConsole("lb")
    end,
})

leaderboardTab:CreateButton({
    Name = "Copy leaderboard",
    Callback = function()
        local text = ctx.getQuizLeaderboard and ctx.getQuizLeaderboard() or "No leaderboard available"
        if setclipboard then
            setclipboard(text)
            notify("Leaderboard", "Copied to clipboard")
        else
            ctx.consoleLog("Leaderboard: " .. text)
        end
    end,
})

leaderboardTab:CreateButton({
    Name = "Reset all points",
    Callback = function()
        if ctx.resetQuizPoints then
            ctx.resetQuizPoints()
            ctx.BotChat("All quiz points cleared")
        else
            runConsole("resetpoints")
        end
    end,
})

local playerTab = window:CreateTab("Player Controls", 100068360107422)
playerTab:CreateSection("Select Target")
local targetLabel = playerTab:CreateLabel("Target: None")
local playerDropdown

playerTab:CreateInput({
    Name = "Target",
    PlaceholderText = "Type player name",
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        targetPlayerName = value or ""
        local player = ctx.findPlayer(targetPlayerName)
        if player then
            targetPlayerName = player.Name
            targetLabel:Set("Target: " .. player.DisplayName .. " (@" .. player.Name .. ")")
            if playerDropdown then
                playerDropdown:Set({ player.DisplayName .. " (@" .. player.Name .. ")" })
            end
        end
    end,
})

playerDropdown = playerTab:CreateDropdown({
    Name = "Player",
    Options = getPlayerNames(),
    CurrentOption = { "Select a player" },
    Callback = function(option)
        targetPlayerName = parsePlayerOption(option)
        local player = ctx.findPlayer(targetPlayerName)
        if player then
            targetLabel:Set("Target: " .. player.DisplayName .. " (@" .. player.Name .. ")")
        else
            targetLabel:Set("Target: " .. targetPlayerName)
        end
    end,
})

playerTab:CreateButton({
    Name = "Refresh player list",
    Callback = function()
        playerDropdown:Refresh(getPlayerNames())
        notify("Players", "Player list refreshed")
    end,
})

playerTab:CreateSection("Modify Points")
playerTab:CreateInput({
    Name = "Amount of points",
    PlaceholderText = tostring(pointsAmount),
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        pointsAmount = tonumber(value) or pointsAmount
    end,
})

playerTab:CreateButton({
    Name = "Add points",
    Callback = function()
        if targetPlayerName == "" then
            notify("Target", "Select a target first")
            return
        end
        local ok, displayName, total = ctx.addQuizPoints(targetPlayerName, pointsAmount)
        if ok then
            ctx.BotChat("Points: " .. displayName .. " now has " .. tostring(total))
        end
    end,
})

playerTab:CreateButton({
    Name = "Remove points",
    Callback = function()
        if targetPlayerName == "" then
            notify("Target", "Select a target first")
            return
        end
        local ok, displayName, total = ctx.addQuizPoints(targetPlayerName, -math.abs(pointsAmount))
        if ok then
            ctx.BotChat("Points: " .. displayName .. " now has " .. tostring(total))
        end
    end,
})

playerTab:CreateButton({
    Name = "Reset target points",
    Callback = function()
        if targetPlayerName == "" then
            notify("Target", "Select a target first")
            return
        end
        local ok, displayName = ctx.resetQuizPoints(targetPlayerName)
        if ok then
            ctx.BotChat("Points cleared for " .. tostring(displayName or targetPlayerName))
        end
    end,
})

local spotifyTab = window:CreateTab("Spotify", 98757033223339)
spotifyTab:CreateSection("Playback")
spotifyTab:CreateInput({
    Name = "Song",
    PlaceholderText = "Song name",
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        spotifyQuery = value or ""
    end,
})

spotifyTab:CreateButton({
    Name = "Play song",
    Callback = function()
        if spotifyQuery ~= "" then runConsole("play " .. spotifyQuery) end
    end,
})

spotifyTab:CreateButton({
    Name = "Queue song",
    Callback = function()
        if spotifyQuery ~= "" then runConsole("queue " .. spotifyQuery) end
    end,
})

spotifyTab:CreateButton({ Name = "Pause", Callback = function() runConsole("pause") end })
spotifyTab:CreateButton({ Name = "Skip", Callback = function() runConsole("skip") end })
spotifyTab:CreateButton({ Name = "Start vote skip", Callback = function() runConsole("vskip") end })
spotifyTab:CreateButton({ Name = "Now playing", Callback = function() runConsole("np") end })
spotifyTab:CreateButton({ Name = "Devices", Callback = function() runConsole("devices") end })

local voiceTab = window:CreateTab("Voice", 110736384827503)
voiceTab:CreateSection("TTS")
voiceTab:CreateDropdown({
    Name = "Voice",
    Options = { "Aoede", "Leda", "Zephyr", "Despina", "Sulafat", "Kore", "Puck", "Charon", "Fenrir", "Orus" },
    CurrentOption = { selectedVoice },
    Callback = function(option)
        selectedVoice = type(option) == "table" and option[1] or option
        if selectedVoice then
            runConsole("voice " .. selectedVoice)
        end
    end,
})

voiceTab:CreateDropdown({
    Name = "TTS mode",
    Options = { "bridge", "local", "both" },
    CurrentOption = { selectedTtsMode },
    Callback = function(option)
        selectedTtsMode = type(option) == "table" and option[1] or option
        if selectedTtsMode then
            runConsole("ttsmode " .. selectedTtsMode)
        end
    end,
})

local ttsText = ""
voiceTab:CreateInput({
    Name = "Say",
    PlaceholderText = "Text to speak",
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        ttsText = value or ""
    end,
})

voiceTab:CreateButton({
    Name = "Speak",
    Callback = function()
        if ttsText ~= "" then runConsole("say " .. ttsText) end
    end,
})

voiceTab:CreateButton({ Name = "Stop TTS", Callback = function() runConsole("stoptts") end })

local settingsTab = window:CreateTab("Settings", 112502172419483)
settingsTab:CreateSection("Bot")
local statsLabel = settingsTab:CreateLabel("Commands: 0 | AI: 0 | Tokens: 0")

settingsTab:CreateButton({
    Name = "Refresh stats label",
    Callback = function()
        statsLabel:Set("Commands: " .. tostring(ctx.stats.commandsRun)
            .. " | AI: " .. tostring(ctx.stats.aiRequests)
            .. " | Tokens: " .. tostring(ctx.stats.tokensTotal)
            .. " | Messages: " .. tostring(ctx.stats.messagesSent))
    end,
})

settingsTab:CreateInput({
    Name = "Question timeout",
    PlaceholderText = tostring(ctx.settings.questionTimeout or 15),
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        local seconds = tonumber(value)
        if seconds and seconds >= 3 then
            ctx.settings.questionTimeout = seconds
            notify("Settings", "Question timeout set to " .. tostring(seconds) .. "s")
        end
    end,
})

settingsTab:CreateToggle({
    Name = "Speak AI answers with TTS",
    CurrentValue = ctx.state.ttsEnabled,
    Callback = function(value)
        ctx.state.ttsEnabled = value
    end,
})

settingsTab:CreateButton({
    Name = "Show commands",
    Callback = function()
        runConsole("help")
    end,
})

settingsTab:CreateButton({
    Name = "Session stats",
    Callback = function()
        runConsole("stats")
    end,
})

settingsTab:CreateButton({
    Name = "Destroy bot",
    Callback = function()
        ContextActionService:UnbindAction("QuizBotToggleUI")
        if library.Destroy then
            pcall(function() library:Destroy() end)
        end
        runConsole("destroy")
    end,
})

ctx.consoleLog("Rayfield UI loaded")
