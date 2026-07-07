--[[
    QuizBot v3 Module: Quiz Game Engine
    Runs a live trivia quiz in chat: posts each question with lettered
    options, detects players' answers (by letter OR full text), awards
    points, and tracks a per-quiz leaderboard.

    Feeds off quizzes made by cmd_quiz.lua's /gen (stored in ctx.lastQuizData),
    or generates + runs one in a single command with /quiz <topic>.

    Registers: /startquiz, /quiz, /stopquiz, /skipq, /lb

    Answer detection (letter matching) ported from the v2 QuizBot engine.
]]
local ctx = ...

-- Vary shuffles across sessions
pcall(function() math.randomseed(tick() % 1 * 1e7 + tick()) end)

local letters = { "A", "B", "C", "D", "E", "F", "G", "H" }

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
    all = "all",
}

local function normalizeDifficultyWord(word)
    word = string.lower(tostring(word or ""))
    return difficultyAliases[word]
end

local function splitTopicDifficulty(args)
    args = tostring(args or ""):gsub("^%s+", ""):gsub("%s+$", "")

    local firstWord, rest = string.match(args, "^(%S+)%s+(.+)$")
    local leadingDifficulty = normalizeDifficultyWord(firstWord)
    if rest and leadingDifficulty then
        return rest, leadingDifficulty
    end

    local topic, lastWord = string.match(args, "^(.-)%s+(%S+)$")
    local trailingDifficulty = normalizeDifficultyWord(lastWord)
    if topic and topic ~= "" and trailingDifficulty then
        return topic, trailingDifficulty
    end

    return args, nil
end

----------------------------------------------------------------
-- Quiz State
----------------------------------------------------------------
local quizRunning = false
local currentQuestion = nil      -- { text, answers, rightAnswerIndex, timeout }
local questionAnsweredBy = nil    -- Player who answered current question correctly
local answeredThisQ = {}          -- Player.Name list who already guessed this question
local skipRequested = false
local quizPoints = {}             -- [DisplayName] = points

-- Keep quizRunning reflected on ctx so other modules/help can read it
ctx.state.quizRunning = false

----------------------------------------------------------------
-- Points / Leaderboard
----------------------------------------------------------------
local function addPoints(player, pts)
    local name = player.DisplayName
    quizPoints[name] = (quizPoints[name] or 0) + pts
end

local function addPointsByName(name, pts)
    if not name or name == "" then return false end
    pts = tonumber(pts)
    if not pts then return false end

    local player = ctx.findPlayer(name)
    local displayName = player and player.DisplayName or name
    quizPoints[displayName] = math.max((quizPoints[displayName] or 0) + pts, 0)
    return true, displayName, quizPoints[displayName]
end

local function resetPoints(name)
    if not name or name == "" then
        quizPoints = {}
        return true
    end

    local player = ctx.findPlayer(name)
    local displayName = player and player.DisplayName or name
    quizPoints[displayName] = nil
    return true, displayName
end

local function leaderboardString()
    local arr = {}
    for name, pts in pairs(quizPoints) do
        table.insert(arr, { name = name, pts = pts })
    end
    if #arr == 0 then
        return "No one scored this round."
    end
    table.sort(arr, function(a, b) return a.pts > b.pts end)

    local medals = { "🥇", "🥈", "🥉" }
    local lines = {}
    for i = 1, math.min(3, #arr) do
        local tag = medals[i] or (i .. ".")
        table.insert(lines, tag .. " " .. arr[i].name .. " - " .. arr[i].pts)
    end
    return table.concat(lines, "   ")
end

function ctx.addQuizPoints(name, pts)
    return addPointsByName(name, pts)
end

function ctx.resetQuizPoints(name)
    return resetPoints(name)
end

function ctx.getQuizLeaderboard()
    return leaderboardString()
end

----------------------------------------------------------------
-- Question Preparation
-- /gen format: { q = "Question", o = { correct, wrong1, wrong2, wrong3 } }
-- (first option is the correct one) -> shuffle so the answer moves around
----------------------------------------------------------------
local function prepareQuestion(q)
    local text = q.q or q.question or q.text or "?"
    local opts = q.o or q.options or q.answers or q.a
    if type(opts) ~= "table" or #opts < 2 then
        return nil
    end

    local correctText = opts[1]

    -- Copy + Fisher-Yates shuffle
    local shuffled = {}
    for _, v in ipairs(opts) do
        table.insert(shuffled, v)
    end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    local rightIdx = table.find(shuffled, correctText) or 1
    return {
        text = text,
        answers = shuffled,
        rightAnswerIndex = rightIdx,
        timeout = ctx.settings.questionTimeout or 15,
    }
end

----------------------------------------------------------------
-- Answer Detection (ported from v2 engine)
-- Matches either the full/substring answer text, or a single
-- letter (A/B/C/...) using careful patterns to avoid false hits.
----------------------------------------------------------------
local function escapePattern(s)
    return (s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function checkAnswer(message, player)
    if not quizRunning or not currentQuestion or questionAnsweredBy then return end
    if not message or message == "" then return end
    if table.find(answeredThisQ, player.Name) then return end

    local answers = currentQuestion.answers
    local rightIdx = currentQuestion.rightAnswerIndex
    local rightText = string.upper(answers[rightIdx])
    local rightLetter = letters[rightIdx]

    local content = string.upper(message)

    -- 1) Full or substring text answer
    local matchAnswer = nil
    local minLen = math.min(4, #rightText)
    if #content >= minLen then
        for _, v in ipairs(answers) do
            local vu = string.upper(v)
            if vu == content then
                matchAnswer = vu
                break
            elseif string.find(content, escapePattern(vu)) then
                if matchAnswer then return end -- ambiguous, ignore
                matchAnswer = vu
            end
        end
    end

    -- 2) Single-letter answer ("I think it's B", "b", "b)")
    local matchingLetter = nil
    if not matchAnswer then
        local maxLetter = letters[#answers]
        local patterns = {
            "%s([A-" .. maxLetter .. "])%s",  -- letter with spaces both sides
            "%s([B-" .. maxLetter .. "])$",   -- letter at end (A excluded: "it is a dog")
            "^([A-" .. maxLetter .. "])%s",   -- letter at start
            "^([A-" .. maxLetter .. "])$",    -- lone letter
        }
        local cleaned = content:gsub("[%).?!]", "")
        for i = 1, 4 do
            local m = cleaned:match(patterns[i])
            if m then
                if matchingLetter and matchingLetter ~= m then return end -- ambiguous
                matchingLetter = m
            end
        end
    end

    if not matchingLetter and not matchAnswer then return end

    -- Register this player as having guessed
    table.insert(answeredThisQ, player.Name)

    local correct = (matchingLetter == rightLetter) or (matchAnswer == rightText)
    if correct then
        -- First correct answer wins the question
        questionAnsweredBy = player
        addPoints(player, 10)
    end
end

----------------------------------------------------------------
-- Quiz Loop
----------------------------------------------------------------
local function awaitAnswer(timeout)
    local elapsed = 0
    while elapsed < timeout do
        if not quizRunning then return end
        if questionAnsweredBy then return end
        if skipRequested then
            skipRequested = false
            return
        end
        task.wait(0.25)
        elapsed += 0.25
    end
end

local function runQuiz(questions)
    if quizRunning then
        ctx.consoleWarn("A quiz is already running")
        return
    end
    if type(questions) ~= "table" or #questions == 0 then
        ctx.BotChat("❌ | No quiz to run. Generate one first with " .. ctx.settings.prefix .. "gen <topic>")
        return
    end

    quizRunning = true
    ctx.state.quizRunning = true
    quizPoints = {}

    ctx.BotChat("🚀 | Quiz starting! " .. #questions .. " questions. Answer in chat with the letter or the full answer.")
    task.wait(3)

    for i, raw in ipairs(questions) do
        if not quizRunning then break end

        local q = prepareQuestion(raw)
        if not q then
            -- malformed question, skip
            task.wait(1)
        else
            currentQuestion = q
            questionAnsweredBy = nil
            answeredThisQ = {}

            ctx.BotChat("❓ | Q" .. i .. "/" .. #questions .. ": " .. q.text)
            task.wait(0.6)

            local optLines = {}
            for idx, ans in ipairs(q.answers) do
                table.insert(optLines, letters[idx] .. ") " .. ans)
            end
            ctx.BotChat(table.concat(optLines, "   "))

            awaitAnswer(q.timeout)
            if not quizRunning then break end

            local answerText = letters[q.rightAnswerIndex] .. ") " .. q.answers[q.rightAnswerIndex]
            if questionAnsweredBy then
                ctx.BotChat("✅ | " .. questionAnsweredBy.DisplayName .. " got it! It was " .. answerText)
            else
                ctx.BotChat("⏰ | Time's up! It was " .. answerText)
            end

            currentQuestion = nil
            questionAnsweredBy = nil
            task.wait(4)
        end
    end

    task.wait(1)
    if quizRunning then
        ctx.BotChat("🏁 | Quiz over! " .. leaderboardString())
    end

    quizRunning = false
    ctx.state.quizRunning = false
    currentQuestion = nil
    questionAnsweredBy = nil
end

ctx.runQuiz = runQuiz

----------------------------------------------------------------
-- Chat listener for answers (separate from the command listener)
----------------------------------------------------------------
ctx.track(ctx.TextChatService.MessageReceived:Connect(function(textChatMessage)
    if not quizRunning then return end
    local source = textChatMessage.TextSource
    if not source then return end

    local player = ctx.Players:GetPlayerByUserId(source.UserId)
    if not player then return end
    if player == ctx.LocalPlayer then return end -- don't let the bot answer itself

    -- Ignore command messages (they start with the prefix)
    local msg = textChatMessage.Text
    if string.sub(msg, 1, #ctx.settings.prefix) == ctx.settings.prefix then return end

    pcall(checkAnswer, msg, player)
end))

----------------------------------------------------------------
-- Commands
----------------------------------------------------------------

-- /startquiz - run the last generated quiz (ctx.lastQuizData from /gen)
ctx.registerCommand({
    aliases = { "startquiz", "startai", "runquiz", "sq" },
    info = "Run the last generated quiz in chat",
    category = "Quiz",
    fn = function()
        if quizRunning then
            ctx.BotChat("⚠️ | A quiz is already running")
            return
        end
        if not ctx.lastQuizData then
            ctx.BotChat("❌ | No quiz generated yet. Use " .. ctx.settings.prefix .. "gen <topic> first")
            return
        end
        task.spawn(function() runQuiz(ctx.lastQuizData) end)
    end,
})

-- /quiz <topic> - generate AND run a quiz in one shot
ctx.registerCommand({
    aliases = { "quiz", "trivia" },
    args = "<topic> [easy|medium|hard]",
    info = "Run a category quiz or generate one on a topic",
    category = "Quiz",
    fn = function(args)
        if args == "" then
            ctx.BotChat("❌ | Usage: " .. ctx.settings.prefix .. "quiz <topic> [easy|medium|hard]")
            return
        end
        if quizRunning then
            ctx.BotChat("⚠️ | A quiz is already running")
            return
        end
        local topic, difficulty = splitTopicDifficulty(args)
        local categoryDifficulty = difficulty ~= "all" and difficulty or nil

        if ctx.getQuizCategoryQuestions then
            local questions, categoryName = ctx.getQuizCategoryQuestions(topic, categoryDifficulty)
            if questions and #questions > 0 then
                ctx.lastQuizData = questions
                local label = categoryName .. (difficulty and (" " .. difficulty) or "")
                ctx.BotChat("Loaded " .. label .. " (" .. #questions .. " questions). Starting...")
                task.spawn(function() runQuiz(questions) end)
                return
            elseif categoryName and difficulty then
                local levels = ctx.getQuizCategoryDifficulties and ctx.getQuizCategoryDifficulties(categoryName) or {}
                ctx.BotChat("No " .. difficulty .. " questions for " .. categoryName .. ". Try: " .. table.concat(levels, ", "))
                return
            end
        end

        if not ctx.settings.geminiApiKey then
            ctx.BotChat("❌ | No Gemini key set (use /setkey in console)")
            return
        end

        local difficultyText = (difficulty and difficulty ~= "all") and difficulty or "medium"
        ctx.BotChat("🤖 | Building a " .. difficultyText .. " quiz about " .. topic .. "...")

        local prompt = [[Generate exactly 5 trivia questions about "]] .. topic .. [[".
REQUIREMENTS:
1. Difficulty: ]] .. difficultyText .. [[.
2. Return ONLY valid JSON. No markdown. No explanation.
3. Format exactly: [{"q":"Question","o":["Correct","Wrong1","Wrong2","Wrong3"]}]
4. The first option in "o" must be the correct answer.
5. Keep each question under 80 characters. Use simple Roblox-chat-safe wording.]]

        task.spawn(function()
            local res = ctx.geminiRequest(prompt, ctx.settings.modelQuiz, nil, quizGenerationConfig)
            if not res and ctx.settings.modelQuiz ~= ctx.settings.modelChat then
                ctx.consoleWarn("Quiz model failed; retrying with " .. ctx.settings.modelChat)
                res = ctx.geminiRequest(prompt, ctx.settings.modelChat, nil, quizGenerationConfig)
            end
            if not res then
                ctx.BotChat("❌ | Quiz generation failed. Check console for Gemini API message.")
                return
            end
            local data = parseGeneratedQuiz(res)
            if data then
                ctx.lastQuizData = data
                runQuiz(data)
            else
                ctx.consoleWarn("Quiz parse failed. Raw Gemini output: " .. string.sub(res, 1, 500))
                ctx.BotChat("❌ | Couldn't parse the generated quiz")
            end
        end)
    end,
})

-- /stopquiz - stop the running quiz
ctx.registerCommand({
    aliases = { "stopquiz", "endquiz", "qstop" },
    info = "Stop the current quiz",
    category = "Quiz",
    fn = function()
        if not quizRunning then
            ctx.BotChat("❌ | No quiz is running")
            return
        end
        quizRunning = false
        ctx.state.quizRunning = false
        currentQuestion = nil
        questionAnsweredBy = nil
        ctx.BotChat("🛑 | Quiz stopped. " .. leaderboardString())
    end,
})

-- /skipq - skip the current question
ctx.registerCommand({
    aliases = { "skipq", "nextq", "qskip" },
    info = "Skip the current quiz question",
    category = "Quiz",
    fn = function()
        if not quizRunning then
            ctx.BotChat("❌ | No quiz is running")
            return
        end
        skipRequested = true
        ctx.BotChat("⏭️ | Skipping...")
    end,
})

-- /lb - show the current leaderboard
ctx.registerCommand({
    aliases = { "lb", "leaderboard", "scores" },
    info = "Show the current quiz leaderboard",
    category = "Quiz",
    fn = function()
        ctx.BotChat("📊 | " .. leaderboardString())
    end,
})

ctx.registerCommand({
    aliases = { "addpoints", "givepoints", "pointsadd" },
    args = "<player> <amount>",
    info = "Add quiz points to a player",
    category = "Quiz",
    fn = function(args)
        local name, amount = string.match(args or "", "^(.-)%s+(-?%d+)$")
        if not name or name == "" then
            ctx.consoleWarn("Usage: /addpoints <player> <amount>")
            return
        end
        local ok, displayName, total = addPointsByName(name, tonumber(amount))
        if ok then
            ctx.BotChat("Points: " .. displayName .. " now has " .. tostring(total))
        end
    end,
})

ctx.registerCommand({
    aliases = { "resetpoints", "clearpoints" },
    args = "[player]",
    info = "Reset quiz points for one player or everyone",
    category = "Quiz",
    fn = function(args)
        local ok, displayName = resetPoints(args)
        if ok and displayName then
            ctx.BotChat("Points cleared for " .. displayName)
        elseif ok then
            ctx.BotChat("All quiz points cleared")
        end
    end,
})

ctx.consoleLog("Quiz game engine ready (/quiz <topic>, /startquiz, /lb)")

