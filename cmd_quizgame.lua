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
        timeout = 15,
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
    args = "<topic>",
    info = "Generate and immediately run a quiz on a topic",
    category = "Quiz",
    fn = function(args)
        if args == "" then
            ctx.BotChat("❌ | Usage: " .. ctx.settings.prefix .. "quiz <topic>")
            return
        end
        if quizRunning then
            ctx.BotChat("⚠️ | A quiz is already running")
            return
        end
        if not ctx.settings.geminiApiKey then
            ctx.BotChat("❌ | No Gemini key set (use /setkey in console)")
            return
        end

        ctx.BotChat("🤖 | Building a quiz about " .. args .. "...")

        local prompt = [[Generate 5 trivia questions about "]] .. args .. [[".
REQUIREMENTS:
1. Difficulty: challenging but fair.
2. Format: a JSON array of objects [{"q":"Question","o":["Correct","Wrong1","Wrong2","Wrong3"]}].
3. The FIRST option in "o" must be the correct answer.
4. Keep each question under 80 characters. Use simple words to avoid chat filtering.
5. Output raw JSON only. No markdown, no code fences.]]

        task.spawn(function()
            local res = ctx.geminiRequest(prompt, ctx.settings.modelQuiz)
            if not res and ctx.settings.modelQuiz ~= ctx.settings.modelChat then
                ctx.consoleWarn("Quiz model failed; retrying with " .. ctx.settings.modelChat)
                res = ctx.geminiRequest(prompt, ctx.settings.modelChat)
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

ctx.consoleLog("Quiz game engine ready (/quiz <topic>, /startquiz, /lb)")

