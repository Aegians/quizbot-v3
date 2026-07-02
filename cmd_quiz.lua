--[[
    QuizBot v3 Module: Quiz Commands
    AI-powered quiz generation, ask questions, real-world Q&A.
    Registers: /gen, /ask, /real, /memorize
    
    NOTE: The full quiz engine (categories, scoring, leaderboard)
    will be ported from the v2 codebase as a separate module.
    This module covers the AI-powered commands.
]]
local ctx = ...

local MEMORY_FILE = "quizbot_memory.txt"

----------------------------------------------------------------
-- Memory System
----------------------------------------------------------------
local function addMemory(fact)
    if not appendfile then
        ctx.consoleWarn("appendfile not available")
        return
    end
    appendfile(MEMORY_FILE, "- " .. fact .. "\n")
    ctx.BotChat("🧠 | Memorized.")
end

local function getMemory()
    if isfile and isfile(MEMORY_FILE) then
        local mem = readfile(MEMORY_FILE)
        if #mem > 5 then return "MEMORIES:\n" .. mem end
    end
    return ""
end

----------------------------------------------------------------
-- Shared helpers (from loader ctx)
----------------------------------------------------------------
local getPlayerContext = ctx.getPlayerContext
local facePlayer = ctx.facePlayer

local function parseGeneratedQuiz(raw)
    if not raw then return nil end
    local cleaned = raw:gsub("```json", ""):gsub("```", "")
    local json = cleaned:match("%b[]") or cleaned
    local ok, data = pcall(function()
        return ctx.HttpService:JSONDecode(json)
    end)
    if not ok or type(data) ~= "table" or #data == 0 then
        return nil
    end

    for _, item in ipairs(data) do
        local text = item.q or item.question or item.text
        local opts = item.o or item.options or item.answers
        if type(text) ~= "string" or type(opts) ~= "table" or #opts < 2 then
            return nil
        end
        item.q = text
        item.o = opts
    end

    return data
end

----------------------------------------------------------------
-- Register Commands
----------------------------------------------------------------

-- /ask - Ask AI about the game/context
ctx.registerCommand({
    aliases = {"ask"},
    args = "<question>",
    info = "Ask AI a game-context question",
    category = "AI",
    fn = function(args, player)
        if args == "" then return end
        if ctx.state.generationCooldown then return end
        ctx.state.generationCooldown = true

        local senderName = player and player.DisplayName or "Console"
        ctx.BotChat("🎮 | Thinking...")
        facePlayer(senderName)

        local context = getPlayerContext()
        local memory = getMemory()
        local prompt = "You are a helpful Roblox assistant. " .. memory
            .. " " .. context
            .. ". User: " .. senderName
            .. ". Q: " .. args
            .. ". Keep it fun, concise, under 100 words."

        local answer = ctx.geminiRequest(prompt)
        if answer then
            ctx.BotChat("💡 | " .. answer)
            -- Optional: speak the answer via TTS
            if ctx.playTTS and ctx.state.ttsEnabled then
                task.spawn(function() ctx.playTTS(answer) end)
            end
        end
        ctx.state.generationCooldown = false
    end,
})

-- /real - Ask AI a real-world question
ctx.registerCommand({
    aliases = {"real", "question", "q"},
    args = "<question>",
    info = "Ask AI a factual/real-world question",
    category = "AI",
    fn = function(args, player)
        if args == "" then return end
        if ctx.state.generationCooldown then return end
        ctx.state.generationCooldown = true

        local senderName = player and player.DisplayName or "Console"
        ctx.BotChat("🧠 | Analyzing...")
        facePlayer(senderName)

        local prompt = "You are a smart AI. User: " .. senderName
            .. ". Q: " .. args
            .. ". Give a factual answer. Keep it under 100 words."

        local answer = ctx.geminiRequest(prompt)
        if answer then
            ctx.BotChat("📚 | " .. answer)
        end
        ctx.state.generationCooldown = false
    end,
})

-- /gen - Generate AI quiz
ctx.registerCommand({
    aliases = {"gen", "generate", "aiquiz"},
    args = "<topic>",
    info = "Generate an AI quiz on a topic",
    category = "AI",
    fn = function(args)
        if args == "" then
            ctx.consoleWarn("Usage: /gen <topic>")
            return
        end
        if ctx.state.generationCooldown then return end
        ctx.state.generationCooldown = true

        ctx.BotChat("🤖 | Generating quiz: " .. args .. "...")

        local prompt = [[Generate 5 trivia questions about "]] .. args .. [[". 
REQUIREMENTS:
1. Difficulty: Challenging but fair.
2. Format: Array of objects [{"q":"Question","o":["Correct","Wrong1","Wrong2","Wrong3"]}]. JSON ONLY.
3. Keep questions under 80 characters. Avoid complex words to prevent Roblox filtering.
4. No markdown, just raw JSON.]]

        local res = ctx.geminiRequest(prompt, ctx.settings.modelQuiz)
        if not res and ctx.settings.modelQuiz ~= ctx.settings.modelChat then
            ctx.consoleWarn("Quiz model failed; retrying with " .. ctx.settings.modelChat)
            res = ctx.geminiRequest(prompt, ctx.settings.modelChat)
        end
        if res then
            local data = parseGeneratedQuiz(res)
            if data then
                ctx.lastQuizData = data
                ctx.BotChat("✅ | Quiz generated: " .. args .. " (" .. #data .. " questions)")
                ctx.consoleLog("Quiz stored. Use /startquiz to run it in chat.")
            else
                ctx.BotChat("❌ | Failed to parse quiz data")
            end
        end
        ctx.state.generationCooldown = false
    end,
})

-- /memorize - Store a fact in memory
ctx.registerCommand({
    aliases = {"memorize", "remember", "mem"},
    args = "<fact>",
    info = "Memorize a fact for AI context",
    category = "AI",
    fn = function(args)
        if args == "" then return end
        addMemory(args)
    end,
})

-- /clearmem - Clear memory file
ctx.registerCommand({
    aliases = {"clearmem", "forgetall"},
    info = "Clear all memorized facts",
    category = "AI",
    fn = function()
        if writefile then
            writefile(MEMORY_FILE, "")
            ctx.BotChat("🧹 | Memory cleared")
        end
    end,
})

-- /copyquiz - Copy last generated quiz to clipboard
ctx.registerCommand({
    aliases = {"copyquiz", "cq"},
    info = "Copy last AI quiz data to clipboard",
    category = "AI",
    fn = function()
        if ctx.lastQuizData and setclipboard then
            setclipboard(ctx.HttpService:JSONEncode(ctx.lastQuizData))
            ctx.BotChat("📋 | Quiz data copied to clipboard!")
        else
            ctx.BotChat("❌ | No quiz data available")
        end
    end,
})

-- /jump - Make bot jump
ctx.registerCommand({
    aliases = {"jump", "j"},
    info = "Make the bot jump",
    category = "Admin",
    fn = function()
        if keypress then
            keypress(0x20)
            task.wait(0.1)
            keyrelease(0x20)
        end
    end,
})

