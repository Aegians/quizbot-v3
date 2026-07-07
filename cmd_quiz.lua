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

local quizGenerationConfig = {
    maxOutputTokens = 1200,
    temperature = 0.4,
    responseMimeType = "application/json",
    responseSchema = {
        type = "ARRAY",
        items = {
            type = "OBJECT",
            properties = {
                q = { type = "STRING" },
                o = {
                    type = "ARRAY",
                    items = { type = "STRING" },
                    minItems = 4,
                    maxItems = 4,
                },
            },
            required = { "q", "o" },
        },
    },
}

local function parseGeneratedQuiz(raw)
    if ctx.parseGeneratedQuiz then
        return ctx.parseGeneratedQuiz(raw)
    end
    if not raw then return nil end
    local cleaned = raw:gsub("```json", ""):gsub("```", "")
    local json = cleaned:match("%b[]") or cleaned
    local ok, data = pcall(function()
        return ctx.HttpService:JSONDecode(json)
    end)
    if not ok or type(data) ~= "table" then
        return nil
    end
    data = data.questions or data.quiz or data.items or data
    if type(data) ~= "table" or #data == 0 then
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

local difficultyAliases = {
    e = "easy",
    ez = "easy",
    easy = "easy",
    m = "medium",
    med = "medium",
    medium = "medium",
    h = "hard",
    hard = "hard",
}

local function normalizeDifficultyWord(word)
    word = string.lower(tostring(word or ""))
    return difficultyAliases[word]
end

local function splitTopicDifficulty(args)
    args = tostring(args or ""):gsub("^%s+", ""):gsub("%s+$", "")

    local topic, lastWord = string.match(args, "^(.-)%s+(%S+)$")
    local difficulty = normalizeDifficultyWord(lastWord)
    if topic and topic ~= "" and difficulty then
        return topic, difficulty
    end

    return args, nil
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

        local topic, difficulty = splitTopicDifficulty(args)
        local difficultyText = difficulty or "medium"

        ctx.BotChat("🤖 | Generating " .. difficultyText .. " quiz: " .. topic .. "...")

        local prompt = [[Generate exactly 5 trivia questions about "]] .. topic .. [[". 
REQUIREMENTS:
1. Difficulty: ]] .. difficultyText .. [[.
2. Return ONLY valid JSON. No markdown. No explanation.
3. Format exactly: [{"q":"Question","o":["Correct","Wrong1","Wrong2","Wrong3"]}]
4. The first option in "o" must be the correct answer.
5. Keep each question under 80 characters. Use simple Roblox-chat-safe wording.]]

        local res = ctx.geminiRequest(prompt, ctx.settings.modelQuiz, nil, quizGenerationConfig)
        if not res and ctx.settings.modelQuiz ~= ctx.settings.modelChat then
            ctx.consoleWarn("Quiz model failed; retrying with " .. ctx.settings.modelChat)
            res = ctx.geminiRequest(prompt, ctx.settings.modelChat, nil, quizGenerationConfig)
        end
        if res then
            local data = parseGeneratedQuiz(res)
            if data then
                ctx.lastQuizData = data
                ctx.BotChat("✅ | Quiz generated: " .. topic .. " " .. difficultyText .. " (" .. #data .. " questions)")
                ctx.consoleLog("Quiz stored. Use /startquiz to run it in chat.")
            else
                ctx.consoleWarn("Quiz parse failed. Raw Gemini output: " .. string.sub(res, 1, 500))
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

