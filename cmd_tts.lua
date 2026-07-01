--[[
    QuizBot v3 Module: Gemini TTS (Text-to-Speech)
    Uses Gemini 2.5 Flash TTS with the existing API key.
    Generates audio, saves locally, plays via getcustomasset.
    
    Registers: /say, /voice, /tts, /announce
]]
local ctx = ...

local HttpService = ctx.HttpService

-- TTS cache folder
local TTS_FOLDER = "quizbot_tts_cache"
if makefolder and not isfolder(TTS_FOLDER) then
    makefolder(TTS_FOLDER)
end

-- Available voices
local VOICES = {
    "Kore", "Puck", "Charon", "Fenrir", "Aoede",
    "Leda", "Orus", "Zephyr", "Enceladus", "Callirrhoe",
    "Autonoe", "Iapetus", "Umbriel", "Algieba", "Despina",
    "Erinome", "Algenib", "Rasalgethi", "Laomedeia", "Achernar",
    "Alnilam", "Schedar", "Gacrux", "Pulcherrima", "Achird",
    "Zubenelgenubi", "Vindemiatrix", "Sadachbia", "Sadaltager", "Sulafat",
}
local currentVoice = "Kore"
local currentSound = nil

----------------------------------------------------------------
-- Base64 Decode
-- Prefer the executor's native decoder (fast). Fall back to a
-- pure-Lua decoder only if none exists.
----------------------------------------------------------------
local function decodeBase64(data)
    -- Native paths (Volt / common executors)
    if crypt and crypt.base64 and crypt.base64.decode then
        return crypt.base64.decode(data)
    end
    if crypt and crypt.base64decode then
        return crypt.base64decode(data)
    end
    if base64 and base64.decode then
        return base64.decode(data)
    end
    if base64_decode then
        return base64_decode(data)
    end

    -- Pure-Lua fallback (byte-based, avoids per-bit string building)
    local b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}
    for i = 1, #b64 do
        lookup[b64:sub(i, i)] = i - 1
    end

    data = data:gsub("[^" .. b64 .. "=]", "")
    local out = {}
    local i = 1
    while i <= #data do
        local c1 = lookup[data:sub(i, i)] or 0
        local c2 = lookup[data:sub(i + 1, i + 1)] or 0
        local c3 = lookup[data:sub(i + 2, i + 2)]
        local c4 = lookup[data:sub(i + 3, i + 3)]

        local n = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
        local byte1 = math.floor(n / 65536) % 256
        local byte2 = math.floor(n / 256) % 256
        local byte3 = n % 256

        out[#out + 1] = string.char(byte1)
        if data:sub(i + 2, i + 2) ~= "=" and c3 then
            out[#out + 1] = string.char(byte2)
        end
        if data:sub(i + 3, i + 3) ~= "=" and c4 then
            out[#out + 1] = string.char(byte3)
        end
        i = i + 4
    end
    return table.concat(out)
end

----------------------------------------------------------------
-- WAV Header
-- Gemini TTS returns RAW PCM (signed 16-bit LE, mono), NOT a
-- playable file. getcustomasset needs a real container, so we
-- prepend a 44-byte RIFF/WAVE header before writing.
----------------------------------------------------------------
local function le(value, bytes)
    -- Encode `value` as `bytes`-wide little-endian string
    local out = {}
    for _ = 1, bytes do
        out[#out + 1] = string.char(value % 256)
        value = math.floor(value / 256)
    end
    return table.concat(out)
end

local function pcmToWav(pcmData, sampleRate, channels, bitsPerSample)
    sampleRate    = sampleRate or 24000
    channels      = channels or 1
    bitsPerSample = bitsPerSample or 16

    local byteRate   = math.floor(sampleRate * channels * (bitsPerSample / 8))
    local blockAlign = math.floor(channels * (bitsPerSample / 8))
    local dataSize   = #pcmData

    local header = table.concat({
        "RIFF",
        le(36 + dataSize, 4),   -- ChunkSize
        "WAVE",
        "fmt ",
        le(16, 4),              -- Subchunk1Size (PCM)
        le(1, 2),               -- AudioFormat (1 = PCM)
        le(channels, 2),
        le(sampleRate, 4),
        le(byteRate, 4),
        le(blockAlign, 2),
        le(bitsPerSample, 2),
        "data",
        le(dataSize, 4),        -- Subchunk2Size
    })

    return header .. pcmData
end

-- Pull the sample rate out of a mime like "audio/L16;codec=pcm;rate=24000"
local function parseSampleRate(mimeType)
    if not mimeType then return 24000 end
    local rate = string.match(mimeType, "rate=(%d+)")
    return rate and tonumber(rate) or 24000
end

local function looksLikeBase64Audio(value)
    return type(value) == "string"
        and #value > 100
        and string.match(value, "^[A-Za-z0-9+/=\r\n]+$") ~= nil
end

local function findAudioData(value, depth)
    if type(value) ~= "table" or (depth or 0) > 8 then
        return nil, nil
    end

    local direct = value.output_audio or value.outputAudio or value.inlineData or value.inline_data
        or value.audio or value.audioData or value.audio_data
    if type(direct) == "table" then
        local data = direct.data or direct.bytes or direct.audio or direct.audioData or direct.audio_data
        if looksLikeBase64Audio(data) then
            return data, direct.mime_type or direct.mimeType or direct.mime or direct.media_type or direct.mediaType
        end
    end

    if looksLikeBase64Audio(value.data) then
        local mimeType = value.mime_type or value.mimeType or value.mime or value.media_type or value.mediaType
        if mimeType and string.find(string.lower(mimeType), "audio") then
            return value.data, mimeType
        end
    end

    for _, child in pairs(value) do
        local data, mimeType = findAudioData(child, (depth or 0) + 1)
        if data then return data, mimeType end
    end

    return nil, nil
end

local function tableKeys(value)
    if type(value) ~= "table" then return "not a table" end
    local keys = {}
    for key in pairs(value) do
        table.insert(keys, tostring(key))
    end
    table.sort(keys)
    return table.concat(keys, ", ")
end

----------------------------------------------------------------
-- Gemini TTS API
-- Uses the Interactions endpoint with audio response
----------------------------------------------------------------
local function generateSpeech(text, voice)
    if not ctx.settings.geminiApiKey then
        ctx.consoleWarn("No Gemini API key for TTS")
        return nil
    end

    voice = voice or currentVoice
    local model = ctx.settings.modelTTS

    local url = "https://generativelanguage.googleapis.com/v1beta/interactions"

    local payload = {
        model = model,
        input = text,
        response_format = {
            type = "audio",
        },
        generation_config = {
            speech_config = {
                {
                    voice = voice,
                },
            }
        },
    }

    ctx.consoleLog("TTS generating: '" .. text:sub(1, 50) .. "...' (voice: " .. voice .. ")")
    ctx.stats.aiRequests += 1

    local ok, response = pcall(function()
        return request({
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["x-goog-api-key"] = ctx.settings.geminiApiKey,
                ["Api-Revision"] = "2026-05-20",
            },
            Body = HttpService:JSONEncode(payload),
        })
    end)

    if not ok then
        ctx.consoleErr("TTS request failed: " .. tostring(response))
        return nil
    end

    if response.StatusCode == 200 then
        local data = HttpService:JSONDecode(response.Body)

        -- Track tokens
        if data.usageMetadata then
            ctx.stats.tokensTotal += (data.usageMetadata.totalTokenCount or 0)
            ctx.stats.tokensInput += (data.usageMetadata.promptTokenCount or 0)
            ctx.stats.tokensOutput += (data.usageMetadata.candidatesTokenCount or 0)
        end

        -- Extract audio data (base64 encoded). Raw REST responses can use
        -- snake_case, camelCase, or nested event-like shapes depending on API revision.
        local audioData, mimeType = findAudioData(data)

        if audioData then
            return audioData, mimeType
        else
            ctx.consoleWarn("TTS: No audio data in response")
            ctx.consoleWarn("TTS response keys: " .. tableKeys(data))
            if data.output then
                ctx.consoleWarn("TTS output keys: " .. tableKeys(data.output))
            end
            if data.response then
                ctx.consoleWarn("TTS response.response keys: " .. tableKeys(data.response))
            end
            return nil
        end
    else
        ctx.consoleErr("TTS API error: " .. tostring(response.StatusCode))
        if response.Body and #response.Body > 0 then
            local okBody, data = pcall(function()
                return HttpService:JSONDecode(response.Body)
            end)
            if okBody and data and data.error then
                ctx.consoleErr("TTS API message: " .. tostring(data.error.message or data.error.status or "unknown"))
            end
        end
        return nil
    end
end

----------------------------------------------------------------
-- Playback
-- Decodes base64 audio, saves to file, plays via getcustomasset
----------------------------------------------------------------
local function playTTS(text, voice)
    if not getcustomasset then
        ctx.consoleWarn("TTS: getcustomasset not available")
        return false
    end

    local audioBase64, mimeType = generateSpeech(text, voice)
    if not audioBase64 then return false end

    -- Decode base64 -> raw bytes
    local ok, audioBytes = pcall(decodeBase64, audioBase64)
    if not ok or not audioBytes or #audioBytes == 0 then
        ctx.consoleErr("TTS: Failed to decode audio")
        return false
    end

    -- Gemini TTS returns raw PCM (audio/L16;codec=pcm;rate=NNNNN).
    -- Wrap it in a WAV container so getcustomasset can load it.
    -- If the API ever returns an already-containered format, use as-is.
    local filename, fileData
    local isRawPCM = (not mimeType)
        or string.find(mimeType, "L16")
        or string.find(mimeType, "pcm")

    if isRawPCM then
        local sampleRate = parseSampleRate(mimeType)   -- usually 24000
        fileData = pcmToWav(audioBytes, sampleRate, 1, 16)
        filename = TTS_FOLDER .. "/tts_" .. tostring(tick()):gsub("%.", "") .. ".wav"
    else
        -- Already a playable container (mp3/ogg/wav)
        local ext = ".wav"
        if string.find(mimeType, "mp3") or string.find(mimeType, "mpeg") then ext = ".mp3"
        elseif string.find(mimeType, "ogg") then ext = ".ogg"
        end
        fileData = audioBytes
        filename = TTS_FOLDER .. "/tts_" .. tostring(tick()):gsub("%.", "") .. ext
    end

    writefile(filename, fileData)

    -- Play via getcustomasset
    local assetOk, assetUrl = pcall(getcustomasset, filename)
    if not assetOk or not assetUrl then
        ctx.consoleErr("TTS: getcustomasset failed")
        pcall(function() delfile(filename) end)
        return false
    end

    -- Stop previous TTS if playing
    if currentSound and currentSound.Parent then
        currentSound:Stop()
        currentSound:Destroy()
    end

    local sound = Instance.new("Sound")
    sound.SoundId = assetUrl
    sound.Volume = 1
    sound.Parent = workspace
    sound:Play()
    currentSound = sound

    -- Cleanup after playback
    task.spawn(function()
        sound.Ended:Wait()
        sound:Destroy()
        pcall(function() delfile(filename) end)
    end)

    ctx.consoleLog("TTS playing: " .. filename)
    return true
end

----------------------------------------------------------------
-- Register Commands
----------------------------------------------------------------

ctx.registerCommand({
    aliases = {"say", "speak", "tts"},
    args = "<text>",
    info = "Speak text using Gemini TTS (local audio)",
    category = "Voice",
    fn = function(args)
        if args == "" then
            ctx.consoleWarn("Usage: /say <text to speak>")
            return
        end
        ctx.BotChat("🔊 | Speaking...")
        local ok = playTTS(args)
        if not ok then
            ctx.BotChat("❌ | TTS failed")
        end
    end,
})

ctx.registerCommand({
    aliases = {"announce", "ann"},
    args = "<text>",
    info = "Announce in chat AND speak via TTS",
    category = "Voice",
    fn = function(args)
        if args == "" then return end
        ctx.BotChat("📢 | " .. args)
        playTTS(args)
    end,
})

ctx.registerCommand({
    aliases = {"voice", "setvoice"},
    args = "[voice_name]",
    info = "Set TTS voice (Kore, Puck, Charon, etc.)",
    category = "Voice",
    fn = function(args)
        if args == "" then
            ctx.BotChat("🎙️ | Current: " .. currentVoice .. " | Available: " .. table.concat(VOICES, ", "))
            return
        end
        -- Find matching voice (case insensitive)
        local found = nil
        for _, v in ipairs(VOICES) do
            if string.lower(v) == string.lower(args) then
                found = v
                break
            end
        end
        if found then
            currentVoice = found
            ctx.BotChat("🎙️ | Voice set to: " .. found)
            playTTS("Hello! This voice is ready.")
        else
            ctx.BotChat("❌ | Unknown voice. Available: " .. table.concat(VOICES, ", "))
        end
    end,
})

ctx.registerCommand({
    aliases = {"stoptts", "shutup", "quiet"},
    info = "Stop current TTS playback",
    category = "Voice",
    fn = function()
        if currentSound and currentSound.Parent then
            currentSound:Stop()
            currentSound:Destroy()
            currentSound = nil
            ctx.BotChat("🔇 | TTS stopped")
        end
    end,
})

ctx.registerCommand({
    aliases = {"cleartts", "ttscache"},
    info = "Clear TTS audio cache",
    category = "Voice",
    fn = function()
        if isfolder(TTS_FOLDER) then
            pcall(function()
                for _, file in ipairs(listfiles(TTS_FOLDER)) do
                    delfile(file)
                end
            end)
            ctx.BotChat("🧹 | TTS cache cleared")
        end
    end,
})

-- Expose TTS for other modules
ctx.playTTS = playTTS
