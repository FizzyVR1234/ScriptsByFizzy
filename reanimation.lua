local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local bindingActive = false
local justBoundKey = nil

-- ── Theme ─────────────────────────────────────────────────────────────────────
local TH = {
    cardBg = Color3.fromRGB(13, 13, 20),
    headerBg = Color3.fromRGB(26, 26, 34),
    dotColor = Color3.fromRGB(139, 139, 255),
    pillColor = Color3.fromRGB(139, 139, 255),
    divColor = Color3.fromRGB(100, 100, 220),
    iconBg = Color3.fromRGB(28, 28, 60),
    iconColor = Color3.fromRGB(139, 139, 255),
    titleColor = Color3.fromRGB(200, 200, 255),
    subColor = Color3.fromRGB(140, 140, 190),
    stroke = Color3.fromRGB(80, 80, 180),
    sepColor = Color3.fromRGB(40, 40, 65),
    toggleOn = Color3.fromRGB(110, 110, 240),
    toggleOff = Color3.fromRGB(50, 50, 80),
    btnBg = Color3.fromRGB(28, 28, 60),
    btnHover = Color3.fromRGB(50, 50, 100),
    dimText = Color3.fromRGB(100, 100, 160),
    closeBg = Color3.fromRGB(180, 50, 50),
    closeHover = Color3.fromRGB(220, 70, 70),
    minBg = Color3.fromRGB(40, 40, 70),
    minHover = Color3.fromRGB(60, 60, 100),
    trackBg = Color3.fromRGB(22, 22, 38),
    trackFill = Color3.fromRGB(110, 110, 240),
    thumbCol = Color3.fromRGB(200, 200, 255),
    stopRed = Color3.fromRGB(155, 38, 38),
    stopHover = Color3.fromRGB(195, 52, 52),
    starOn = Color3.fromRGB(255, 196, 50),
    starOff = Color3.fromRGB(55, 55, 80),
    tabOnBg = Color3.fromRGB(60, 60, 140),
    tabOffBg = Color3.fromRGB(28, 28, 55),
    tabOnTxt = Color3.fromRGB(220, 220, 255),
    tabOffTxt = Color3.fromRGB(80, 80, 130),
    listItem = Color3.fromRGB(18, 18, 30),
    listHov = Color3.fromRGB(32, 32, 60),
    playingRow = Color3.fromRGB(48, 48, 100),
    knobOuter = Color3.fromRGB(139, 139, 255),
    knobInner = Color3.fromRGB(200, 200, 255),
    toggleOnText = Color3.fromRGB(220, 220, 255),
    toggleOffText = Color3.fromRGB(100, 100, 160),
    resetBg = Color3.fromRGB(35, 35, 75),
    resetHover = Color3.fromRGB(55, 55, 110),
    addBtnBg = Color3.fromRGB(38, 38, 90),
    addBtnHover = Color3.fromRGB(58, 58, 130),
    formBg = Color3.fromRGB(16, 16, 28),
    delBg = Color3.fromRGB(100, 28, 28),
    delHover = Color3.fromRGB(155, 40, 40),
}

-- ══════════════════════════════════════════════════════════════════════════════
-- DAWLATUL CORE - FIXED REANIMATION LOGIC
-- ══════════════════════════════════════════════════════════════════════════════
local dawlatul = {
    services = { workspace = game:GetService("Workspace"), replicated = game:GetService("ReplicatedStorage") },
    flags = { reanimated = false },
    clones = {},
    real_chars = {},
    connections = { hb = nil, died = nil, rcr = nil, cr = nil, cd = nil, ccr = nil, anim_hb = nil },
    callbacks = { on_play = nil, on_stop = nil },
    speed = 1.0,
    animation = {
        cache = {},
        generation = 0,
        state = {
            is_playing = false,
            current_url = nil,
            keyframes = nil,
            total_duration = 0,
            elapsed_time = 0,
            loading = false,          -- FIXED: prevents overlapping loads
        },
        orig_c0s = {},
        joints = {},
    },
}

local API = {}

local function get_game_ragdoll_info(enable)
    local pid = game.PlaceId
    if pid == 15546218972 or pid == 6884319169 then
        return dawlatul.services.replicated:WaitForChild("event_rag"), {"Ball"}, false
    elseif pid == 5991163185 then
        return dawlatul.services.replicated.Remotes.Physics.Ragdoll, {}, false
    elseif pid == 5683833663 then
        return dawlatul.services.replicated:WaitForChild("LocalRagdollEvent"), {enable}, true
    end
    return nil, nil, false
end

local function set_transparency(model, t)
    if not model then return end
    for _, p in model:GetDescendants() do
        if p:IsA("BasePart") then p.Transparency = t end
    end
end

local function lp()
    return Players.LocalPlayer or "no player"
end

local function get_char(player)
    if typeof(player) ~= "Instance" or not player:IsA("Player") then return "bad player" end
    local c = player.Character
    if not c or not c.Parent then return "no char" end
    return c
end

local function clone_char(model)
    if typeof(model) ~= "Instance" then return "bad model" end
    model.Archivable = true
    local c = model:Clone()
    model.Archivable = false
    c.Name = "Reanimation"
    c.Parent = dawlatul.services.workspace
    c:WaitForChild("Animate").Disabled = true
    c.Humanoid.RequiresNeck = false
    c.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    local ff = c:FindFirstChildWhichIsA("ForceField")
    if ff then ff:Destroy() end
    return c
end

local function fire_remote(remote, is_local, ...)
    if typeof(remote) ~= "Instance" then return end
    if is_local then
        if remote:IsA("BindableEvent") then remote:Fire(...) end
    else
        if remote:IsA("RemoteEvent") then
            remote:FireServer(...)
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(...)
        end
    end
end

API.stop_animation = function()
    local st = dawlatul.animation.state
    if dawlatul.connections.anim_hb then
        dawlatul.connections.anim_hb:Disconnect()
        dawlatul.connections.anim_hb = nil
    end
    dawlatul.animation.generation = (dawlatul.animation.generation or 0) + 1

    local player = lp()
    if typeof(player) ~= "string" then
        local cc = API.get_clone(player)
        if cc then
            for motor, c0 in pairs(dawlatul.animation.orig_c0s) do
                if motor and motor.Parent then motor.C0 = c0 end
            end
            local cas = cc:FindFirstChild("Animate")
            if cas then cas.Enabled = true end
        end
    end

    table.clear(dawlatul.animation.orig_c0s)
    table.clear(dawlatul.animation.joints)

    dawlatul.animation.state = {
        is_playing = false,
        current_url = nil,
        keyframes = nil,
        total_duration = 0,
        elapsed_time = 0,
        loading = false,          -- FIXED
    }

    if dawlatul.callbacks.on_stop then pcall(dawlatul.callbacks.on_stop) end
end

local function freeze_all_guis(player)
    local pg = player:FindFirstChildWhichIsA("PlayerGui")
    if not pg then return {} end
    local snapshot = {}
    for _, g in pg:GetChildren() do
        if g:IsA("ScreenGui") then
            snapshot[g] = g.ResetOnSpawn
            g.ResetOnSpawn = false
        end
    end
    return snapshot
end

local function restore_all_guis(player, snapshot)
    local pg = player:FindFirstChildWhichIsA("PlayerGui")
    if not pg then return end
    for _, g in pg:GetChildren() do
        if g:IsA("ScreenGui") then
            if snapshot[g] ~= nil then
                g.ResetOnSpawn = snapshot[g]
            end
        end
    end
end

local function safe_set_character(player, newChar)
    local snapshot = freeze_all_guis(player)
    task.wait()
    local ok = pcall(function() player.Character = newChar end)
    task.wait()
    restore_all_guis(player, snapshot)
    return ok
end

API.reanimate = function(bool, remote, args)
    if bool ~= true and bool ~= false then return end
    local player = lp()
    if typeof(player) == "string" then return end
    local is_local = false
    if not remote then
        local gr, ga, gi = get_game_ragdoll_info(bool)
        if gr then remote = gr; args = ga; is_local = gi end
    end
    if bool then
        if dawlatul.flags.reanimated then return end
        local rc = get_char(player)
        if typeof(rc) == "string" then return end
        local rh = rc:FindFirstChild("Humanoid")
        local rhrp = rc:FindFirstChild("HumanoidRootPart")
        if not rh or not rhrp then return end
        dawlatul.real_chars[player] = rc
        local cl = clone_char(rc)
        if typeof(cl) == "string" then return end
        if not cl:FindFirstChild("Humanoid") then return end
        dawlatul.clones[player] = cl
        set_transparency(cl, 1)
        safe_set_character(player, cl)
        cl:WaitForChild("Animate").Disabled = true
        cl:WaitForChild("Animate").Disabled = false
        dawlatul.connections.hb = RunService.Heartbeat:Connect(function()
            if not rc or not rc.Parent or not cl or not cl.Parent then
                API.reanimate(false, remote, args)
                return
            end
            for _, p in rc:GetChildren() do
                local cp = cl:FindFirstChild(p.Name)
                if p:IsA("BasePart") and cp then
                    p.CFrame = cp.CFrame
                    p.Velocity = Vector3.new()
                end
            end
        end)
        local clHum = cl:FindFirstChildWhichIsA("Humanoid")
        local cam = dawlatul.services.workspace.CurrentCamera
        if clHum and cam then cam.CameraSubject = clHum end
        local clh = cl.Humanoid
        dawlatul.connections.died = rh.Died:Connect(function()
            API.reanimate(false, remote, args)
        end)
        dawlatul.connections.rcr = rc.ChildRemoved:Connect(function(ch)
            if ch == rh or ch == rhrp then API.reanimate(false, remote, args) end
        end)
        dawlatul.connections.ccr = cl.ChildRemoved:Connect(function(ch)
            if ch == clh then API.reanimate(false, remote, args) end
        end)
        dawlatul.connections.cd = clh.Died:Connect(function()
            local crh = rc and rc:FindFirstChild("Humanoid")
            if crh and crh.Health > 0 then
                crh.Health = 0
            else
                API.reanimate(false, remote, args)
            end
        end)
        dawlatul.connections.cr = player.CharacterRemoving:Connect(function(cbr)
            if cbr == rc then API.reanimate(false, remote, args) end
        end)
        if remote then fire_remote(remote, is_local, table.unpack(args or {})) end
        dawlatul.flags.reanimated = true
    else
        if not dawlatul.flags.reanimated then return end
        API.stop_animation()
        if remote then fire_remote(remote, is_local, table.unpack(args or {})) end
        for k, conn in pairs(dawlatul.connections) do
            if conn then conn:Disconnect(); dawlatul.connections[k] = nil end
        end
        local cl = dawlatul.clones[player]
        if cl and cl.Parent then cl:Destroy(); dawlatul.clones[player] = nil end
        local rc = dawlatul.real_chars[player]
        if rc and rc.Parent then
            set_transparency(rc, 0)
            local hrp = rc:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Transparency = 1 end
            local rcHum = rc:FindFirstChildWhichIsA("Humanoid")
            local cam = dawlatul.services.workspace.CurrentCamera
            if rcHum and cam then cam.CameraSubject = rcHum end
            safe_set_character(player, rc)
        end
        dawlatul.real_chars[player] = nil
        dawlatul.flags.reanimated = false
    end
end

local function loadKeyframes(url)
    if dawlatul.animation.cache[url] then return dawlatul.animation.cache[url], nil end
    local ok, resp = pcall(game.HttpGet, game, url)
    if not ok or type(resp) ~= "string" or resp == "" then
        return nil, "Fetch failed"
    end
    local fn, err = loadstring(resp)
    if not fn then return nil, "Parse error" end
    local ok2, res = pcall(fn)
    if not ok2 or type(res) ~= "table" then return nil, "Exec error" end
    local k = next(res)
    if not k then return nil, "Empty table" end
    local kfs = res[k]
    if type(kfs) ~= "table" or #kfs == 0 then return nil, "No keyframes" end
    dawlatul.animation.cache[url] = kfs
    return kfs, nil
end

-- FIXED play_animation with full loading protection
API.play_animation = function(url)
    if dawlatul.animation.state.loading then
        return -- silently ignore (prevents overlap)
    end

    if not dawlatul.flags.reanimated then return end
    local player = lp()
    if typeof(player) == "string" then return end
    local cc = API.get_clone(player)
    if not cc then return end

    if dawlatul.animation.state.is_playing and dawlatul.animation.state.current_url == url then
        API.stop_animation()
        return
    end

    API.stop_animation()

    dawlatul.animation.state.loading = true

    local hum = cc:FindFirstChildOfClass("Humanoid")
    if hum then
        for _, t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop() end
    end
    local cas = cc:FindFirstChild("Animate")
    if cas then cas.Enabled = false end

    local kfs, err = loadKeyframes(url)
    dawlatul.animation.state.loading = false

    if not kfs then
        warn("[Dawlatul] " .. tostring(err))
        return
    end

    local anim = dawlatul.animation
    table.clear(anim.joints)
    table.clear(anim.orig_c0s)
    for _, d in ipairs(cc:GetDescendants()) do
        if d:IsA("Motor6D") and d.Part1 then
            anim.joints[d.Part1.Name] = d
            anim.orig_c0s[d] = d.C0
        end
    end

    local dur = kfs[#kfs].Time
    if dur <= 0 then return end

    anim.state = {
        is_playing = true,
        current_url = url,
        keyframes = kfs,
        total_duration = dur,
        elapsed_time = 0,
        loading = false,
    }

    dawlatul.animation.generation = (dawlatul.animation.generation or 0) + 1
    local myGeneration = dawlatul.animation.generation

    if dawlatul.callbacks.on_play then pcall(dawlatul.callbacks.on_play, url) end

    dawlatul.connections.anim_hb = RunService.Heartbeat:Connect(function(dt)
        if dawlatul.animation.generation ~= myGeneration then return end
        if not anim.state.is_playing then return end
        local spd = dawlatul.speed
        if spd > 0 then
            anim.state.elapsed_time = (anim.state.elapsed_time + dt * spd) % anim.state.total_duration
        end
        local cf, nf
        local kf = anim.state.keyframes
        local et = anim.state.elapsed_time
        for i = 1, #kf - 1 do
            if et >= kf[i].Time and et < kf[i + 1].Time then
                cf = kf[i]; nf = kf[i + 1]; break
            end
        end
        if not cf then cf = kf[#kf]; nf = kf[1] end
        local fd = nf.Time - cf.Time
        if fd <= 0 then fd = anim.state.total_duration end
        local alpha = math.clamp(fd > 0 and (et - cf.Time) / fd or 0, 0, 1)
        for pn, pose in pairs(cf.Data) do
            local motor = anim.joints[pn]
            if motor and anim.orig_c0s[motor] then
                local np = nf.Data and nf.Data[pn]
                motor.C0 = anim.orig_c0s[motor] * (np and pose:Lerp(np, alpha) or pose)
            end
        end
    end)
end

API.set_speed = function(s)
    local n = tonumber(s) or 1.0
    dawlatul.speed = math.clamp(math.floor(n * 10 + 0.5) / 10, 0.0, 10.0)
end

API.on_animation_play = function(cb) if type(cb) == "function" then dawlatul.callbacks.on_play = cb end end
API.on_animation_stop = function(cb) if type(cb) == "function" then dawlatul.callbacks.on_stop = cb end end
API.is_animation_playing = function() return dawlatul.animation.state.is_playing, dawlatul.animation.state.current_url end
API.is_reanimated = function() return dawlatul.flags.reanimated end
API.get_clone = function(player)
    player = player or lp()
    if typeof(player) == "string" then return nil end
    return dawlatul.clones[player]
end

-- ── Animation Database (loaded from GitHub) ───────────────────────────────────
local EMOTE_LIST_URL = "https://raw.githubusercontent.com/FizzyVR1234/ScriptsByFizzy/refs/heads/main/emoteList.Lua"
local animDB = {}

local function loadAnimDB()
    local ok, resp = pcall(game.HttpGet, game, EMOTE_LIST_URL)
    if not ok or type(resp) ~= "string" or resp == "" then
        warn("[Dawlatul] Failed to load emote list from GitHub")
        return
    end
    local fn, err = loadstring(resp)
    if not fn then
        warn("[Dawlatul] Failed to parse emote list: " .. tostring(err))
        return
    end
    local ok2, res = pcall(fn)
    if not ok2 or type(res) ~= "table" then
        warn("[Dawlatul] Emote list returned invalid data")
        return
    end
    animDB = {}
    for name, url in pairs(res) do
        animDB[#animDB + 1] = { n = name, url = url, fav = false, tag = "default" }
    end
    table.sort(animDB, function(a, b) return a.n < b.n end)
end

loadAnimDB()

-- ── UI Constants ──────────────────────────────────────────────────────────────
local CARD_W = 310
local CARD_H = 648
local HEADER_H = 28
local ROW_H = 30
local LIST_H = ROW_H * 7 + 8
local DEFAULT_SPEED = 1.0
local SPEED_MIN = 0.0
local SPEED_MAX = 10.0
local curSpeed = DEFAULT_SPEED
local curAnimUrl = nil
local currentTab = "All"
local searchQuery = ""
local customCtr = 0
local lastAnimPlayTime = 0
local ANIM_COOLDOWN = 0.1
local FAV_FILE = "dawlatul_favorites.txt"
local KEYS_FILE = "dawlatul_keybinds.txt"
local CUSTOM_FILE = "dawlatul_custom.txt"
local PRESET_FILE = "dawlatul_presets.txt"

-- ── Persistence ───────────────────────────────────────────────────────────────
local function safeWrite(path, data)
    local ok, err = pcall(writefile, path, tostring(data))
    if not ok then warn("[Dawlatul] save failed: " .. tostring(err)) end
end
local function safeRead(path)
    if not pcall(function() return isfile(path) end) then return nil end
    local ok, data = pcall(readfile, path)
    return ok and data or nil
end
local function saveFavorites()
    local lines = {}
    for _, a in ipairs(animDB) do
        if a.fav then lines[#lines + 1] = a.n end
    end
    safeWrite(FAV_FILE, table.concat(lines, "\n"))
end
local function saveKeybinds()
    local lines = {}
    for _, a in ipairs(animDB) do
        if a._getKey and a._getKey() then
            lines[#lines + 1] = a.n .. "\t" .. a._getKey().Name
        end
    end
    safeWrite(KEYS_FILE, table.concat(lines, "\n"))
end
local function saveCustom()
    local lines = {}
    for _, a in ipairs(animDB) do
        if a.tag == "custom" then
            lines[#lines + 1] = a.n .. "|" .. a.url
        end
    end
    safeWrite(CUSTOM_FILE, table.concat(lines, "\n"))
end
local pendingKeybinds = {}
local function loadFavorites()
    local data = safeRead(FAV_FILE)
    if not data or data == "" then return end
    local favSet = {}
    for line in data:gmatch("[^\n]+") do
        favSet[line:match("^%s*(.-)%s*$")] = true
    end
    for _, a in ipairs(animDB) do
        if favSet[a.n] then a.fav = true end
    end
end
local function loadKeybinds()
    local data = safeRead(KEYS_FILE)
    if not data or data == "" then return end
    for line in data:gmatch("[^\n]+") do
        local name, keyName = line:match("^(.+)\t(.+)$")
        if name and keyName then pendingKeybinds[name] = keyName end
    end
end
local function loadCustom()
    local data = safeRead(CUSTOM_FILE)
    if not data or data == "" then return end
    for line in data:gmatch("[^\n]+") do
        local name, url = line:match("^(.+)|(.+)$")
        if name and url and url:sub(1, 10) ~= "__custom__" then
            local exists = false
            for _, a in ipairs(animDB) do
                if a.n == name then exists = true; break end
            end
            if not exists then
                animDB[#animDB + 1] = { n = name, url = url, fav = false, tag = "custom" }
            end
        end
    end
    table.sort(animDB, function(a, b) return a.n < b.n end)
end
local function applyPendingKeybinds()
    if not next(pendingKeybinds) then return end
    for _, a in ipairs(animDB) do
        local keyName = pendingKeybinds[a.n]
        if keyName and a._getKey then
            local kc = Enum.KeyCode[keyName]
            if kc and a._setKey then a._setKey(kc) end
        end
    end
end
local speedPresets = {
    { speed = 0, key = nil, _getKey = nil, _setKey = nil },
    { speed = 0, key = nil, _getKey = nil, _setKey = nil },
    { speed = 0, key = nil, _getKey = nil, _setKey = nil },
    { speed = 0, key = nil, _getKey = nil, _setKey = nil },
    { speed = 0, key = nil, _getKey = nil, _setKey = nil },
}
local savedActivePreset = nil
local function savePresets()
    local lines = {}
    lines[#lines + 1] = tostring(savedActivePreset or 0)
    for i, p in ipairs(speedPresets) do
        local keyName = p._getKey and p._getKey() and p._getKey().Name or ""
        lines[#lines + 1] = tostring(p.speed) .. "|" .. keyName
    end
    safeWrite(PRESET_FILE, table.concat(lines, "\n"))
end
local pendingPresetKeys = {}
local function loadPresets()
    local data = safeRead(PRESET_FILE)
    if not data or data == "" then return end
    local lines = {}
    for line in data:gmatch("[^\n]+") do lines[#lines + 1] = line end
    if #lines == 0 then return end
    local lineStart = 1
    local firstLine = lines[1]
    if not firstLine:find("|") then
        local ap = tonumber(firstLine)
        if ap and ap >= 1 and ap <= 5 then
            savedActivePreset = ap
        else
            savedActivePreset = nil
        end
        lineStart = 2
    end
    for idx = lineStart, #lines do
        local i = idx - lineStart + 1
        local line = lines[idx]
        local spd, keyName = line:match("^([^|]+)|(.*)$")
        if spd and speedPresets[i] then
            speedPresets[i].speed = math.clamp(tonumber(spd) or 0, 0, 10)
            if keyName and keyName ~= "" then pendingPresetKeys[i] = keyName end
        end
    end
end
loadAnimDB()      -- fetch list from GitHub first
loadFavorites()   -- then apply saved state
loadKeybinds()
loadCustom()
loadPresets()

-- ── GUI Setup ─────────────────────────────────────────────────────────────────
local old = CoreGui:FindFirstChild("DawlatulReanimUI")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "DawlatulReanimUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
gui.Parent = CoreGui

local DawlatulUI = {}
local _destroyed = false

local card = Instance.new("Frame")
card.Name = "Card"
card.Size = UDim2.new(0, CARD_W, 0, CARD_H)
card.AnchorPoint = Vector2.new(0, 0)
card.Position = UDim2.new(0.5, -CARD_W / 2, 0.5, -CARD_H / 2)
card.BackgroundColor3 = TH.cardBg
card.BorderSizePixel = 0
card.ZIndex = 10
card.Parent = gui
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
do
    local s = Instance.new("UIStroke")
    s.Color = TH.stroke
    s.Thickness = 1
    s.Transparency = 0.5
    s.Parent = card
end

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, HEADER_H)
header.BackgroundColor3 = TH.headerBg
header.BorderSizePixel = 0
header.ZIndex = 11
header.ClipsDescendants = true
header.Parent = card
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)
do
    local hf = Instance.new("Frame")
    hf.Size = UDim2.new(1, 0, 0.5, 0)
    hf.Position = UDim2.new(0, 0, 0.5, 0)
    hf.BackgroundColor3 = TH.headerBg
    hf.BorderSizePixel = 0
    hf.ZIndex = 11
    hf.Parent = header
end

local shimmer = Instance.new("Frame")
shimmer.Size = UDim2.new(0.4, 0, 1, 0)
shimmer.Position = UDim2.new(-0.5, 0, 0, 0)
shimmer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
shimmer.BorderSizePixel = 0
shimmer.ZIndex = 13
shimmer.Parent = header
do
    local g = Instance.new("UIGradient")
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.45, 0.88),
        NumberSequenceKeypoint.new(0.55, 0.88),
        NumberSequenceKeypoint.new(1, 1),
    })
    g.Parent = shimmer
end

local dotRing = Instance.new("Frame")
dotRing.Size = UDim2.new(0, 6, 0, 6)
dotRing.AnchorPoint = Vector2.new(0.5, 0.5)
dotRing.Position = UDim2.new(0, 15, 0.5, 0)
dotRing.BackgroundColor3 = TH.dotColor
dotRing.BackgroundTransparency = 0.5
dotRing.BorderSizePixel = 0
dotRing.ZIndex = 14
dotRing.Parent = header
Instance.new("UICorner", dotRing).CornerRadius = UDim.new(1, 0)

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 6, 0, 6)
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.new(0, 15, 0.5, 0)
dot.BackgroundColor3 = TH.dotColor
dot.BorderSizePixel = 0
dot.ZIndex = 15
dot.Parent = header
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local pill = Instance.new("TextLabel")
pill.Text = "DAWLATUL . REANIMATION"
pill.BackgroundTransparency = 1
pill.Size = UDim2.new(1, -70, 1, 0)
pill.Position = UDim2.new(0, 26, 0, 0)
pill.TextColor3 = TH.pillColor
pill.TextSize = 9
pill.Font = Enum.Font.GothamBold
pill.TextXAlignment = Enum.TextXAlignment.Left
pill.ZIndex = 15
pill.Parent = header

local BTN_W = 20
local BTN_H = 18
local BTN_Y = (HEADER_H - BTN_H) / 2

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, BTN_W, 0, BTN_H)
minBtn.Position = UDim2.new(1, -(BTN_W * 2 + 4 + 6), 0, BTN_Y)
minBtn.BackgroundColor3 = TH.minBg
minBtn.BorderSizePixel = 0
minBtn.Text = "-"
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 11
minBtn.TextColor3 = Color3.fromRGB(180, 180, 220)
minBtn.ZIndex = 16
minBtn.AutoButtonColor = false
minBtn.Parent = header
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 4)
minBtn.MouseEnter:Connect(function()
    TweenService:Create(minBtn, TweenInfo.new(0.12), { BackgroundColor3 = TH.minHover }):Play()
end)
minBtn.MouseLeave:Connect(function()
    TweenService:Create(minBtn, TweenInfo.new(0.12), { BackgroundColor3 = TH.minBg }):Play()
end)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, BTN_W, 0, BTN_H)
closeBtn.Position = UDim2.new(1, -(BTN_W + 6), 0, BTN_Y)
closeBtn.BackgroundColor3 = TH.closeBg
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 10
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.ZIndex = 16
closeBtn.AutoButtonColor = false
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.12), { BackgroundColor3 = TH.closeHover }):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.12), { BackgroundColor3 = TH.closeBg }):Play()
end)
closeBtn.MouseButton1Click:Connect(function() DawlatulUI.destroy() end)

do
    local dv = Instance.new("Frame")
    dv.Size = UDim2.new(1, 0, 0, 1)
    dv.Position = UDim2.new(0, 0, 0, HEADER_H)
    dv.BackgroundColor3 = TH.divColor
    dv.BackgroundTransparency = 0.4
    dv.BorderSizePixel = 0
    dv.ZIndex = 11
    dv.Parent = card
    local g = Instance.new("UIGradient")
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.7, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    g.Parent = dv
end

local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.Size = UDim2.new(1, 0, 1, -HEADER_H)
body.Position = UDim2.new(0, 0, 0, HEADER_H)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 0
body.ScrollingDirection = Enum.ScrollingDirection.Y
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.CanvasSize = UDim2.new(0, 0, 0, 0)
body.ScrollBarImageTransparency = 1
body.ElasticBehavior = Enum.ElasticBehavior.Never
body.ZIndex = 10
body.Parent = card
do
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, 0)
    l.Parent = body
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, 6)
    p.PaddingBottom = UDim.new(0, 10)
    p.Parent = body
end

local minimized = false
local MIN_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    minBtn.Text = minimized and "+" or "-"
    if minimized then
        TweenService:Create(card, MIN_TWEEN, { Size = UDim2.new(0, CARD_W, 0, HEADER_H) }):Play()
        task.delay(0.26, function() if minimized then body.Visible = false end end)
    else
        body.Visible = true
        TweenService:Create(card, MIN_TWEEN, { Size = UDim2.new(0, CARD_W, 0, CARD_H) }):Play()
    end
end)

-- ── UI Helper Functions ───────────────────────────────────────────────────────
local rowOrder = 0
local function nO() rowOrder = rowOrder + 1; return rowOrder end
local function mSt(p, tr, thick)
    local s = Instance.new("UIStroke")
    s.Color = TH.stroke
    s.Thickness = thick or 1
    s.Transparency = tr or 0.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
end
local function makeSep()
    local w = Instance.new("Frame")
    w.Size = UDim2.new(1, 0, 0, 10)
    w.BackgroundTransparency = 1
    w.BorderSizePixel = 0
    w.LayoutOrder = nO()
    w.Parent = body
    local s = Instance.new("Frame")
    s.Size = UDim2.new(1, -20, 0, 1)
    s.Position = UDim2.new(0, 10, 0, 5)
    s.BackgroundColor3 = TH.sepColor
    s.BorderSizePixel = 0
    s.ZIndex = 11
    s.Parent = w
end
local function makeSectionLabel(txt)
    local w = Instance.new("Frame")
    w.Size = UDim2.new(1, 0, 0, 20)
    w.BackgroundTransparency = 1
    w.BorderSizePixel = 0
    w.LayoutOrder = nO()
    w.Parent = body
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = TH.pillColor
    l.TextSize = 9
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 12
    l.Parent = w
end
local function makeHintLabel(txt)
    local w = Instance.new("Frame")
    w.Size = UDim2.new(1, 0, 0, 14)
    w.BackgroundTransparency = 1
    w.BorderSizePixel = 0
    w.LayoutOrder = nO()
    w.Parent = body
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = TH.dimText
    l.TextSize = 8
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 12
    l.Parent = w
end
local function makePanel(h)
    local w = Instance.new("Frame")
    w.Size = UDim2.new(1, 0, 0, h + 6)
    w.BackgroundTransparency = 1
    w.BorderSizePixel = 0
    w.LayoutOrder = nO()
    w.Parent = body
    local p = Instance.new("Frame")
    p.Size = UDim2.new(1, -20, 0, h)
    p.Position = UDim2.new(0, 10, 0, 3)
    p.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
    p.BackgroundTransparency = 0.05
    p.BorderSizePixel = 0
    p.ZIndex = 12
    p.Parent = w
    Instance.new("UICorner", p).CornerRadius = UDim.new(0, 8)
    mSt(p, 0.45)
    return p
end
local function makeKeybindBtn(parent, px, py, pw, ph, zi)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, pw, 0, ph)
    btn.Position = UDim2.new(0, px, 0, py)
    btn.BackgroundColor3 = TH.btnBg
    btn.Text = "[+]"
    btn.TextColor3 = TH.dimText
    btn.TextSize = 6
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.ZIndex = zi or 15
    btn.AutoButtonColor = false
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    mSt(btn, 0.6)
    local boundKey = nil
    local listening = false
    local function refresh()
        if boundKey then
            btn.BackgroundColor3 = TH.toggleOn
            btn.TextColor3 = Color3.fromRGB(220, 220, 255)
            btn.Text = boundKey.Name:sub(1, 4)
        else
            btn.BackgroundColor3 = TH.btnBg
            btn.TextColor3 = TH.dimText
            btn.Text = "[+]"
        end
    end
    btn.MouseEnter:Connect(function()
        if not listening then
            TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = boundKey and TH.toggleOn or TH.btnHover }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if not listening then
            TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = boundKey and TH.toggleOn or TH.btnBg }):Play()
        end
    end)
    btn.MouseButton1Click:Connect(function()
        if listening then return end
        if boundKey then
            boundKey = nil
            refresh()
            task.defer(saveKeybinds)
            return
        end
        listening = true
        bindingActive = true
        btn.Text = "..."
        btn.TextColor3 = TH.titleColor
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = TH.btnHover }):Play()
        local conn
        conn = UserInputService.InputBegan:Connect(function(inp, proc)
            if proc then return end
            if inp.UserInputType == Enum.UserInputType.Keyboard then
                boundKey = inp.KeyCode
                justBoundKey = inp.KeyCode
                listening = false
                bindingActive = false
                conn:Disconnect()
                refresh()
                task.defer(saveKeybinds)
            end
        end)
    end)
    local setter = function(kc) boundKey = kc; refresh() end
    return function() return boundKey end, setter
end

-- ── Title Row ─────────────────────────────────────────────────────────────────
local titleRowWrap = Instance.new("Frame")
titleRowWrap.Size = UDim2.new(1, 0, 0, 58)
titleRowWrap.BackgroundTransparency = 1
titleRowWrap.BorderSizePixel = 0
titleRowWrap.LayoutOrder = nO()
titleRowWrap.ZIndex = 11
titleRowWrap.Parent = body
local titleRow = Instance.new("Frame")
titleRow.Size = UDim2.new(1, -20, 0, 52)
titleRow.Position = UDim2.new(0, 10, 0, 3)
titleRow.BackgroundTransparency = 1
titleRow.BorderSizePixel = 0
titleRow.ZIndex = 11
titleRow.Parent = titleRowWrap
do
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.VerticalAlignment = Enum.VerticalAlignment.Center
    l.Padding = UDim.new(0, 10)
    l.Parent = titleRow
end
local iconBox = Instance.new("Frame")
iconBox.Size = UDim2.new(0, 40, 0, 40)
iconBox.BackgroundColor3 = TH.iconBg
iconBox.BorderSizePixel = 0
iconBox.ZIndex = 12
iconBox.Parent = titleRow
Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 9)
do
    local s = Instance.new("UIStroke")
    s.Color = TH.stroke
    s.Thickness = 1
    s.Transparency = 0.5
    s.Parent = iconBox
end
local iconLbl = Instance.new("TextLabel")
iconLbl.Text = "🤖"
iconLbl.Size = UDim2.new(1, 0, 1, 0)
iconLbl.BackgroundTransparency = 1
iconLbl.TextColor3 = TH.iconColor
iconLbl.TextScaled = true
iconLbl.Font = Enum.Font.GothamBold
iconLbl.ZIndex = 13
iconLbl.Parent = iconBox
local textBlock = Instance.new("Frame")
textBlock.Size = UDim2.new(1, -50, 1, 0)
textBlock.BackgroundTransparency = 1
textBlock.BorderSizePixel = 0
textBlock.ZIndex = 12
textBlock.Parent = titleRow
do
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Vertical
    l.VerticalAlignment = Enum.VerticalAlignment.Center
    l.Padding = UDim.new(0, 3)
    l.Parent = textBlock
end
local nameLbl = Instance.new("TextLabel")
nameLbl.Text = "Reanimation"
nameLbl.Size = UDim2.new(1, 0, 0, 17)
nameLbl.BackgroundTransparency = 1
nameLbl.TextColor3 = TH.titleColor
nameLbl.TextScaled = false
nameLbl.TextSize = 14
nameLbl.Font = Enum.Font.GothamBold
nameLbl.TextXAlignment = Enum.TextXAlignment.Left
nameLbl.ZIndex = 13
nameLbl.Parent = textBlock
local descLbl = Instance.new("TextLabel")
descLbl.Text = "Animate your character freely"
descLbl.Size = UDim2.new(1, 0, 0, 12)
descLbl.BackgroundTransparency = 1
descLbl.TextColor3 = TH.subColor
descLbl.TextScaled = false
descLbl.TextSize = 9
descLbl.Font = Enum.Font.Gotham
descLbl.TextXAlignment = Enum.TextXAlignment.Left
descLbl.ZIndex = 13
descLbl.Parent = textBlock

-- ── Reanimation Control ───────────────────────────────────────────────────────
makeSectionLabel("REANIMATION CONTROL")
local reanimBtn
do
    local panel = makePanel(36)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -68, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Enable Reanimation"
    lbl.TextColor3 = TH.titleColor
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 13
    lbl.Parent = panel
    reanimBtn = Instance.new("TextButton")
    reanimBtn.Size = UDim2.new(0, 52, 0, 24)
    reanimBtn.Position = UDim2.new(1, -60, 0.5, -12)
    reanimBtn.BackgroundColor3 = TH.toggleOff
    reanimBtn.Text = "OFF"
    reanimBtn.TextColor3 = TH.toggleOffText
    reanimBtn.TextSize = 9
    reanimBtn.Font = Enum.Font.GothamBold
    reanimBtn.BorderSizePixel = 0
    reanimBtn.ZIndex = 13
    reanimBtn.AutoButtonColor = false
    reanimBtn.Parent = panel
    Instance.new("UICorner", reanimBtn).CornerRadius = UDim.new(0, 5)
    mSt(reanimBtn, 0.5)
    reanimBtn.MouseEnter:Connect(function()
        TweenService:Create(reanimBtn, TweenInfo.new(0.12), {
            BackgroundColor3 = reanimBtn.Text == "ON"
                and Color3.fromRGB(130, 130, 255)
                or Color3.fromRGB(70, 70, 100),
        }):Play()
    end)
    reanimBtn.MouseLeave:Connect(function()
        TweenService:Create(reanimBtn, TweenInfo.new(0.12), {
            BackgroundColor3 = reanimBtn.Text == "ON" and TH.toggleOn or TH.toggleOff,
        }):Play()
    end)
end
local function syncReanimBtn()
    local on = API.is_reanimated()
    reanimBtn.BackgroundColor3 = on and TH.toggleOn or TH.toggleOff
    reanimBtn.Text = on and "ON" or "OFF"
    reanimBtn.TextColor3 = on and TH.toggleOnText or TH.toggleOffText
end
reanimBtn.MouseButton1Click:Connect(function()
    API.reanimate(not API.is_reanimated())
    syncReanimBtn()
end)

-- ── Now Playing ───────────────────────────────────────────────────────────────
local nowPlayLbl, playIcon
do
    local panel = makePanel(36)
    playIcon = Instance.new("TextLabel")
    playIcon.Size = UDim2.new(0, 20, 1, 0)
    playIcon.Position = UDim2.new(0, 8, 0, 0)
    playIcon.BackgroundTransparency = 1
    playIcon.Text = "▶"
    playIcon.TextColor3 = TH.subColor
    playIcon.TextSize = 10
    playIcon.Font = Enum.Font.GothamBold
    playIcon.ZIndex = 13
    playIcon.Parent = panel
    nowPlayLbl = Instance.new("TextLabel")
    nowPlayLbl.Size = UDim2.new(1, -88, 1, 0)
    nowPlayLbl.Position = UDim2.new(0, 30, 0, 0)
    nowPlayLbl.BackgroundTransparency = 1
    nowPlayLbl.Text = "No animation playing"
    nowPlayLbl.TextColor3 = TH.dimText
    nowPlayLbl.TextSize = 9
    nowPlayLbl.Font = Enum.Font.Gotham
    nowPlayLbl.TextXAlignment = Enum.TextXAlignment.Left
    nowPlayLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nowPlayLbl.ZIndex = 13
    nowPlayLbl.Parent = panel
    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0, 48, 0, 24)
    stopBtn.Position = UDim2.new(1, -54, 0.5, -12)
    stopBtn.BackgroundColor3 = TH.stopRed
    stopBtn.Text = "Stop"
    stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopBtn.TextSize = 9
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.BorderSizePixel = 0
    stopBtn.ZIndex = 13
    stopBtn.AutoButtonColor = false
    stopBtn.Parent = panel
    Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 5)
    mSt(stopBtn, 0.4)
    stopBtn.MouseEnter:Connect(function()
        TweenService:Create(stopBtn, TweenInfo.new(0.12), { BackgroundColor3 = TH.stopHover }):Play()
    end)
    stopBtn.MouseLeave:Connect(function()
        TweenService:Create(stopBtn, TweenInfo.new(0.12), { BackgroundColor3 = TH.stopRed }):Play()
    end)
    stopBtn.MouseButton1Click:Connect(function() API.stop_animation() end)
end

-- ── Speed Slider ──────────────────────────────────────────────────────────────
local speedValueLabel
local applySpeed
makeSectionLabel("SPEED")
do
    local PANEL_H = 54
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, PANEL_H + 6)
    wrap.BackgroundTransparency = 1
    wrap.BorderSizePixel = 0
    wrap.LayoutOrder = nO()
    wrap.Parent = body
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(1, -20, 0, PANEL_H)
    panel.Position = UDim2.new(0, 10, 0, 3)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
    panel.BackgroundTransparency = 0.05
    panel.BorderSizePixel = 0
    panel.ZIndex = 12
    panel.Parent = wrap
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
    mSt(panel, 0.45)
    local sLabel = Instance.new("TextLabel")
    sLabel.Size = UDim2.new(0, 80, 0, 20)
    sLabel.Position = UDim2.new(0, 10, 0, 7)
    sLabel.BackgroundTransparency = 1
    sLabel.Text = "⚡ Speed"
    sLabel.TextColor3 = TH.subColor
    sLabel.TextSize = 10
    sLabel.Font = Enum.Font.GothamBold
    sLabel.TextXAlignment = Enum.TextXAlignment.Left
    sLabel.ZIndex = 14
    sLabel.Parent = panel
    speedValueLabel = Instance.new("TextLabel")
    speedValueLabel.Size = UDim2.new(0, 44, 0, 18)
    speedValueLabel.Position = UDim2.new(1, -104, 0, 8)
    speedValueLabel.BackgroundTransparency = 1
    speedValueLabel.Text = "1.0x"
    speedValueLabel.TextColor3 = TH.titleColor
    speedValueLabel.TextSize = 10
    speedValueLabel.Font = Enum.Font.GothamBold
    speedValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    speedValueLabel.ZIndex = 14
    speedValueLabel.Parent = panel
    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(0, 46, 0, 18)
    resetBtn.Position = UDim2.new(1, -54, 0, 7)
    resetBtn.BackgroundColor3 = TH.resetBg
    resetBtn.Text = "Reset"
    resetBtn.TextColor3 = TH.subColor
    resetBtn.TextSize = 8
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.BorderSizePixel = 0
    resetBtn.ZIndex = 14
    resetBtn.AutoButtonColor = false
    resetBtn.Parent = panel
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 4)
    mSt(resetBtn, 0.55)
    resetBtn.MouseEnter:Connect(function()
        TweenService:Create(resetBtn, TweenInfo.new(0.12), { BackgroundColor3 = TH.resetHover, TextColor3 = TH.titleColor }):Play()
    end)
    resetBtn.MouseLeave:Connect(function()
        TweenService:Create(resetBtn, TweenInfo.new(0.12), { BackgroundColor3 = TH.resetBg, TextColor3 = TH.subColor }):Play()
    end)
    local TRK_X = 10
    local TRK_W = CARD_W - 20 - 20
    local TRK_H = 6
    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, TRK_W, 0, TRK_H)
    track.Position = UDim2.new(0, TRK_X, 0, 36)
    track.BackgroundColor3 = TH.trackBg
    track.BorderSizePixel = 0
    track.ZIndex = 13
    track.ClipsDescendants = false
    track.Parent = panel
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    do
        local ts = Instance.new("UIStroke")
        ts.Color = Color3.fromRGB(60, 60, 100)
        ts.Thickness = 1
        ts.Transparency = 0.5
        ts.Parent = track
    end
    local fillClip = Instance.new("Frame")
    fillClip.Size = UDim2.new(1, 0, 1, 0)
    fillClip.BackgroundTransparency = 1
    fillClip.ClipsDescendants = true
    fillClip.BorderSizePixel = 0
    fillClip.ZIndex = 14
    fillClip.Parent = track
    Instance.new("UICorner", fillClip).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0.1, 0, 1, 0)
    fill.BackgroundColor3 = TH.trackFill
    fill.BorderSizePixel = 0
    fill.ZIndex = 15
    fill.Parent = fillClip
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    do
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 160, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 200)),
        })
        g.Parent = fill
    end
    local initPct = 0.1
    local knobRing = Instance.new("Frame")
    knobRing.Size = UDim2.new(0, 16, 0, 16)
    knobRing.AnchorPoint = Vector2.new(0.5, 0.5)
    knobRing.Position = UDim2.new(initPct, 0, 0.5, 0)
    knobRing.BackgroundColor3 = TH.knobOuter
    knobRing.BackgroundTransparency = 0.5
    knobRing.BorderSizePixel = 0
    knobRing.ZIndex = 16
    knobRing.Parent = track
    Instance.new("UICorner", knobRing).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 10, 0, 10)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0.5, 0, 0.5, 0)
    knob.BackgroundColor3 = TH.knobInner
    knob.BorderSizePixel = 0
    knob.ZIndex = 17
    knob.Parent = knobRing
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local function s2a(s) return math.clamp((s - SPEED_MIN) / (SPEED_MAX - SPEED_MIN), 0, 1) end
    local function a2s(a) return math.floor((SPEED_MIN + a * (SPEED_MAX - SPEED_MIN)) * 10 + 0.5) / 10 end
    applySpeed = function(s, fromPreset)
        s = math.clamp(math.floor((tonumber(s) or DEFAULT_SPEED) * 10 + 0.5) / 10, SPEED_MIN, SPEED_MAX)
        curSpeed = s
        API.set_speed(s)
        local a = s2a(s)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knobRing.Position = UDim2.new(a, 0, 0.5, 0)
        speedValueLabel.Text = tostring(s) .. "x"
        if not fromPreset and _G._dawlatulPresetDeselect then
            _G._dawlatulPresetDeselect()
        end
    end
    applySpeed(DEFAULT_SPEED)
    resetBtn.MouseButton1Click:Connect(function() applySpeed(DEFAULT_SPEED) end)
    local dragging = false
    local function updateFromX(absX)
        local tL = track.AbsolutePosition.X
        local tW = track.AbsoluteSize.X
        applySpeed(a2s(math.clamp((absX - tL) / math.max(tW, 1), 0, 1)))
    end
    local dragBtn = Instance.new("TextButton")
    dragBtn.Size = UDim2.new(1, 0, 0, 22)
    dragBtn.Position = UDim2.new(0, 0, 0.5, -11)
    dragBtn.BackgroundTransparency = 1
    dragBtn.Text = ""
    dragBtn.ZIndex = 18
    dragBtn.Parent = track
    dragBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateFromX(inp.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromX(inp.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- ── Speed Presets ─────────────────────────────────────────────────────────────
do
    local PRESET_PANEL_H = 72
    local NUM_PRESETS = 5
    local INNER_PAD = 10
    local GAP = 5
    local PANEL_W = CARD_W - 20
    local CELL_W = math.floor((PANEL_W - INNER_PAD * 2 - GAP * (NUM_PRESETS - 1)) / NUM_PRESETS)
    makeSectionLabel("SPEED PRESETS")
    local pwrap = Instance.new("Frame")
    pwrap.Size = UDim2.new(1, 0, 0, PRESET_PANEL_H + 6)
    pwrap.BackgroundTransparency = 1
    pwrap.BorderSizePixel = 0
    pwrap.LayoutOrder = nO()
    pwrap.Parent = body
    local ppanel = Instance.new("Frame")
    ppanel.Size = UDim2.new(1, -20, 0, PRESET_PANEL_H)
    ppanel.Position = UDim2.new(0, 10, 0, 3)
    ppanel.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
    ppanel.BackgroundTransparency = 0.05
    ppanel.BorderSizePixel = 0
    ppanel.ZIndex = 12
    ppanel.Parent = pwrap
    Instance.new("UICorner", ppanel).CornerRadius = UDim.new(0, 8)
    mSt(ppanel, 0.45)
    local activePresetIdx = nil
    local presetBtns = {}
    local presetKbBtns = {}
    local function refreshPresetBtns()
        for idx, p in ipairs(speedPresets) do
            local btn = presetBtns[idx]
            local lb = p._labelTb
            if btn and lb then
                local isActive = activePresetIdx == idx
                local hasSpeed = p.speed > 0
                local labelTxt = hasSpeed and (tostring(p.speed) .. "x") or ("P" .. idx)
                lb.Text = labelTxt
                if isActive then
                    TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = TH.toggleOn }):Play()
                    TweenService:Create(lb, TweenInfo.new(0.12), { TextColor3 = Color3.fromRGB(220, 220, 255) }):Play()
                elseif hasSpeed then
                    TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = TH.btnBg }):Play()
                    TweenService:Create(lb, TweenInfo.new(0.12), { TextColor3 = TH.titleColor }):Play()
                else
                    TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(20, 20, 36) }):Play()
                    TweenService:Create(lb, TweenInfo.new(0.12), { TextColor3 = TH.dimText }):Play()
                end
            end
        end
    end
    for idx = 1, NUM_PRESETS do
        local p = speedPresets[idx]
        local cellX = INNER_PAD + (idx - 1) * (CELL_W + GAP)
        local btn = Instance.new("Frame")
        btn.Size = UDim2.new(0, CELL_W, 0, 28)
        btn.Position = UDim2.new(0, cellX, 0, 8)
        btn.BackgroundColor3 = Color3.fromRGB(20, 20, 36)
        btn.BorderSizePixel = 0
        btn.ZIndex = 14
        btn.Parent = ppanel
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        mSt(btn, 0.5)
        local labelTb = Instance.new("TextLabel")
        labelTb.Size = UDim2.new(1, 0, 1, 0)
        labelTb.Position = UDim2.new(0, 0, 0, 0)
        labelTb.BackgroundTransparency = 1
        labelTb.Text = "P" .. idx
        labelTb.TextColor3 = TH.dimText
        labelTb.TextSize = 8
        labelTb.Font = Enum.Font.GothamBold
        labelTb.ZIndex = 16
        labelTb.Parent = btn
        local editBox = Instance.new("TextBox")
        editBox.Size = UDim2.new(1, -4, 1, -4)
        editBox.Position = UDim2.new(0, 2, 0, 2)
        editBox.BackgroundColor3 = Color3.fromRGB(30, 30, 55)
        editBox.BackgroundTransparency = 0
        editBox.Text = ""
        editBox.PlaceholderText = "0.0"
        editBox.PlaceholderColor3 = TH.dimText
        editBox.TextColor3 = TH.titleColor
        editBox.TextSize = 8
        editBox.Font = Enum.Font.GothamBold
        editBox.TextXAlignment = Enum.TextXAlignment.Center
        editBox.BorderSizePixel = 0
        editBox.ZIndex = 17
        editBox.ClearTextOnFocus = true
        editBox.Visible = false
        editBox.Parent = btn
        Instance.new("UICorner", editBox).CornerRadius = UDim.new(0, 4)
        local hitBtn = Instance.new("TextButton")
        hitBtn.Size = UDim2.new(1, 0, 1, 0)
        hitBtn.BackgroundTransparency = 1
        hitBtn.Text = ""
        hitBtn.BorderSizePixel = 0
        hitBtn.ZIndex = 18
        hitBtn.AutoButtonColor = false
        hitBtn.Parent = btn
        presetBtns[idx] = btn
        speedPresets[idx]._labelTb = labelTb
        local lastClickTime = 0
        local editingPreset = false
        local function commitEdit()
            if not editingPreset then return end
            editingPreset = false
            editBox.Visible = false
            labelTb.Visible = true
            local val = tonumber(editBox.Text)
            if val then
                val = math.clamp(math.floor(val * 10 + 0.5) / 10, 0, SPEED_MAX)
                speedPresets[idx].speed = val
                task.defer(savePresets)
                refreshPresetBtns()
            end
        end
        local function startEdit()
            editingPreset = true
            local cur = speedPresets[idx].speed
            editBox.Text = cur > 0 and tostring(cur) or ""
            labelTb.Visible = false
            editBox.Visible = true
            editBox:CaptureFocus()
        end
        editBox.FocusLost:Connect(function(_enterPressed)
            commitEdit()
        end)
        hitBtn.MouseEnter:Connect(function()
            if activePresetIdx ~= idx then
                TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = TH.btnHover }):Play()
            end
        end)
        hitBtn.MouseLeave:Connect(function()
            if activePresetIdx ~= idx then
                local hasSpeed = speedPresets[idx].speed > 0
                TweenService:Create(btn, TweenInfo.new(0.1), {
                    BackgroundColor3 = hasSpeed and TH.btnBg or Color3.fromRGB(20, 20, 36),
                }):Play()
            end
        end)
        hitBtn.MouseButton1Click:Connect(function()
            local now = tick()
            local dt = now - lastClickTime
            lastClickTime = now
            if dt < 0.35 then
                startEdit()
                return
            end
            if activePresetIdx == idx then
                speedPresets[idx].speed = curSpeed
                savedActivePreset = idx
                task.defer(savePresets)
                refreshPresetBtns()
            else
                if speedPresets[idx].speed > 0 then
                    applySpeed(speedPresets[idx].speed, true)
                    activePresetIdx = idx
                    savedActivePreset = idx
                    refreshPresetBtns()
                else
                    speedPresets[idx].speed = curSpeed
                    activePresetIdx = idx
                    savedActivePreset = idx
                    task.defer(savePresets)
                    refreshPresetBtns()
                end
            end
        end)
        local kbBtn = Instance.new("TextButton")
        kbBtn.Size = UDim2.new(0, CELL_W, 0, 22)
        kbBtn.Position = UDim2.new(0, cellX, 0, 42)
        kbBtn.BackgroundColor3 = TH.btnBg
        kbBtn.Text = "[+]"
        kbBtn.TextColor3 = TH.dimText
        kbBtn.TextSize = 6
        kbBtn.Font = Enum.Font.GothamBold
        kbBtn.BorderSizePixel = 0
        kbBtn.ZIndex = 14
        kbBtn.AutoButtonColor = false
        kbBtn.Parent = ppanel
        Instance.new("UICorner", kbBtn).CornerRadius = UDim.new(0, 4)
        mSt(kbBtn, 0.6)
        presetKbBtns[idx] = kbBtn
        local boundKey = nil
        local listening = false
        local function kbRefresh()
            if boundKey then
                kbBtn.BackgroundColor3 = TH.toggleOn
                kbBtn.TextColor3 = Color3.fromRGB(220, 220, 255)
                kbBtn.Text = boundKey.Name:sub(1, 4)
            else
                kbBtn.BackgroundColor3 = TH.btnBg
                kbBtn.TextColor3 = TH.dimText
                kbBtn.Text = "[+]"
            end
        end
        local function getKey() return boundKey end
        local function setKey(kc) boundKey = kc; kbRefresh() end
        speedPresets[idx]._getKey = getKey
        speedPresets[idx]._setKey = setKey
        kbBtn.MouseEnter:Connect(function()
            if not listening then
                TweenService:Create(kbBtn, TweenInfo.new(0.1), { BackgroundColor3 = boundKey and TH.toggleOn or TH.btnHover }):Play()
            end
        end)
        kbBtn.MouseLeave:Connect(function()
            if not listening then
                TweenService:Create(kbBtn, TweenInfo.new(0.1), { BackgroundColor3 = boundKey and TH.toggleOn or TH.btnBg }):Play()
            end
        end)
        kbBtn.MouseButton1Click:Connect(function()
            if listening then return end
            if boundKey then
                boundKey = nil
                kbRefresh()
                task.defer(savePresets)
                return
            end
            listening = true
            bindingActive = true
            kbBtn.Text = "..."
            kbBtn.TextColor3 = TH.titleColor
            TweenService:Create(kbBtn, TweenInfo.new(0.1), { BackgroundColor3 = TH.btnHover }):Play()
            local conn
            conn = UserInputService.InputBegan:Connect(function(inp, proc)
                if proc then return end
                if inp.UserInputType == Enum.UserInputType.Keyboard then
                    boundKey = inp.KeyCode
                    justBoundKey = inp.KeyCode
                    listening = false
                    bindingActive = false
                    conn:Disconnect()
                    kbRefresh()
                    task.defer(savePresets)
                end
            end)
        end)
    end
    task.defer(function()
        for i, keyName in pairs(pendingPresetKeys) do
            local kc = Enum.KeyCode[keyName]
            if kc and speedPresets[i] and speedPresets[i]._setKey then
                speedPresets[i]._setKey(kc)
            end
        end
        if savedActivePreset and speedPresets[savedActivePreset] and speedPresets[savedActivePreset].speed > 0 then
            activePresetIdx = savedActivePreset
            applySpeed(speedPresets[savedActivePreset].speed, true)
        end
        refreshPresetBtns()
    end)
    _G._dawlatulPresetCheck = function(key)
        for idx, p in ipairs(speedPresets) do
            if p._getKey and p._getKey() == key then
                if p.speed > 0 then
                    applySpeed(p.speed, true)
                    activePresetIdx = idx
                    savedActivePreset = idx
                    task.defer(savePresets)
                    refreshPresetBtns()
                end
                return true
            end
        end
        return false
    end
    _G._dawlatulPresetDeselect = function()
        if activePresetIdx then
            activePresetIdx = nil
            savedActivePreset = nil
            task.defer(savePresets)
            refreshPresetBtns()
        end
    end
end
makeSep()

-- ── Tab Bar ───────────────────────────────────────────────────────────────────
local tabBtns = {}
do
    local w = Instance.new("Frame")
    w.Size = UDim2.new(1, 0, 0, 30)
    w.BackgroundTransparency = 1
    w.BorderSizePixel = 0
    w.LayoutOrder = nO()
    w.Parent = body
    local BG_W = CARD_W - 20
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, BG_W, 0, 26)
    bg.Position = UDim2.new(0, 10, 0, 2)
    bg.BackgroundColor3 = TH.btnBg
    bg.BorderSizePixel = 0
    bg.ZIndex = 12
    bg.Parent = w
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
    mSt(bg, 0.5)
    local INNER_PAD = 2
    local GAP = 2
    local NUM_TABS = 3
    local TAB_W = math.floor((BG_W - INNER_PAD * 2 - GAP * (NUM_TABS - 1)) / NUM_TABS)
    local TAB_H = 22
    local tl = Instance.new("UIListLayout")
    tl.FillDirection = Enum.FillDirection.Horizontal
    tl.VerticalAlignment = Enum.VerticalAlignment.Center
    tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tl.Padding = UDim.new(0, GAP)
    tl.Parent = bg
    local labels = { "🎬 All", "⭐ Favs", "✏️ Custom" }
    local labelKeys = { "All", "Favs", "Custom" }
    for idx, lbl in ipairs(labels) do
        local tb = Instance.new("TextButton")
        tb.Size = UDim2.new(0, TAB_W, 0, TAB_H)
        tb.BackgroundColor3 = TH.tabOffBg
        tb.Text = lbl
        tb.TextColor3 = TH.tabOffTxt
        tb.TextSize = 8
        tb.Font = Enum.Font.GothamBold
        tb.BorderSizePixel = 0
        tb.ZIndex = 13
        tb.AutoButtonColor = false
        tb.Parent = bg
        Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 5)
        local key = labelKeys[idx]
        tb.MouseEnter:Connect(function()
            if key ~= currentTab then
                TweenService:Create(tb, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(40, 40, 80) }):Play()
            end
        end)
        tb.MouseLeave:Connect(function()
            if key ~= currentTab then
                TweenService:Create(tb, TweenInfo.new(0.1), { BackgroundColor3 = TH.tabOffBg }):Play()
            end
        end)
        tabBtns[key] = tb
    end
end
makeHintLabel("Click [+] to bind key | Click bound key to unbind")

-- ── Search Box ────────────────────────────────────────────────────────────────
local searchBox
do
    local w = Instance.new("Frame")
    w.Size = UDim2.new(1, 0, 0, 30)
    w.BackgroundTransparency = 1
    w.BorderSizePixel = 0
    w.LayoutOrder = nO()
    w.Parent = body
    local sp = Instance.new("Frame")
    sp.Size = UDim2.new(1, -20, 0, 26)
    sp.Position = UDim2.new(0, 10, 0, 2)
    sp.BackgroundColor3 = TH.btnBg
    sp.BorderSizePixel = 0
    sp.ZIndex = 12
    sp.Parent = w
    Instance.new("UICorner", sp).CornerRadius = UDim.new(0, 6)
    mSt(sp, 0.5)
    local searchIcon = Instance.new("TextLabel")
    searchIcon.Size = UDim2.new(0, 16, 1, 0)
    searchIcon.Position = UDim2.new(0, 6, 0, 0)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Text = "🔍"
    searchIcon.TextColor3 = TH.dimText
    searchIcon.TextSize = 9
    searchIcon.Font = Enum.Font.Gotham
    searchIcon.ZIndex = 14
    searchIcon.Parent = sp
    local searchPlaceholder = Instance.new("TextLabel")
    searchPlaceholder.Size = UDim2.new(1, -26, 1, 0)
    searchPlaceholder.Position = UDim2.new(0, 24, 0, 0)
    searchPlaceholder.BackgroundTransparency = 1
    searchPlaceholder.Text = "Search animations..."
    searchPlaceholder.TextColor3 = TH.dimText
    searchPlaceholder.TextSize = 9
    searchPlaceholder.Font = Enum.Font.Gotham
    searchPlaceholder.TextXAlignment = Enum.TextXAlignment.Left
    searchPlaceholder.ZIndex = 14
    searchPlaceholder.Parent = sp
    searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -26, 1, -2)
    searchBox.Position = UDim2.new(0, 24, 0, 1)
    searchBox.BackgroundTransparency = 1
    searchBox.Text = ""
    searchBox.PlaceholderText = ""
    searchBox.PlaceholderColor3 = TH.dimText
    searchBox.TextColor3 = TH.titleColor
    searchBox.TextSize = 9
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.BorderSizePixel = 0
    searchBox.ClearTextOnFocus = false
    searchBox.ZIndex = 15
    searchBox.Parent = sp
    local function updateSearchUI()
        local focused = searchBox:IsFocused()
        local hasText = searchBox.Text ~= ""
        searchIcon.Visible = true
        searchPlaceholder.Visible = not focused and not hasText
    end
    searchBox.Focused:Connect(updateSearchUI)
    searchBox.FocusLost:Connect(updateSearchUI)
    searchBox:GetPropertyChangedSignal("Text"):Connect(updateSearchUI)
end

-- ── Animation List Area ───────────────────────────────────────────────────────
local listAreaWrap = Instance.new("Frame")
listAreaWrap.Size = UDim2.new(1, 0, 0, LIST_H + 4)
listAreaWrap.BackgroundTransparency = 1
listAreaWrap.BorderSizePixel = 0
listAreaWrap.LayoutOrder = nO()
listAreaWrap.Parent = body
local listOuter = Instance.new("Frame")
listOuter.Size = UDim2.new(1, -20, 0, LIST_H)
listOuter.Position = UDim2.new(0, 10, 0, 2)
listOuter.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
listOuter.BorderSizePixel = 0
listOuter.ZIndex = 12
listOuter.ClipsDescendants = true
listOuter.Parent = listAreaWrap
Instance.new("UICorner", listOuter).CornerRadius = UDim.new(0, 8)
mSt(listOuter, 0.5)
listOuter.MouseEnter:Connect(function() body.ScrollingEnabled = false end)
listOuter.MouseLeave:Connect(function() body.ScrollingEnabled = true end)
local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, 0, 1, 0)
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 3
listFrame.ScrollBarImageColor3 = TH.toggleOn
listFrame.ScrollBarImageTransparency = 0.3
listFrame.ElasticBehavior = Enum.ElasticBehavior.Never
listFrame.ZIndex = 13
listFrame.Parent = listOuter
do
    local ll = Instance.new("UIListLayout")
    ll.FillDirection = Enum.FillDirection.Vertical
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, 1)
    ll.Parent = listFrame
end
local emptyLbl = Instance.new("Frame")
emptyLbl.Size = UDim2.new(1, 0, 0, 36)
emptyLbl.BackgroundTransparency = 1
emptyLbl.ZIndex = 14
emptyLbl.LayoutOrder = 999999
emptyLbl.Visible = false
emptyLbl.Parent = listFrame
local emptyTxt = Instance.new("TextLabel")
emptyTxt.Size = UDim2.new(1, 0, 1, 0)
emptyTxt.BackgroundTransparency = 1
emptyTxt.TextColor3 = TH.dimText
emptyTxt.TextSize = 9
emptyTxt.Font = Enum.Font.Gotham
emptyTxt.ZIndex = 15
emptyTxt.Text = "No results"
emptyTxt.Parent = emptyLbl

-- Custom panel
local customPanel = Instance.new("ScrollingFrame")
customPanel.Size = UDim2.new(1, 0, 1, 0)
customPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
customPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
customPanel.BackgroundTransparency = 1
customPanel.BorderSizePixel = 0
customPanel.ScrollBarThickness = 3
customPanel.ScrollBarImageColor3 = TH.toggleOn
customPanel.ScrollBarImageTransparency = 0.3
customPanel.ElasticBehavior = Enum.ElasticBehavior.Never
customPanel.ZIndex = 13
customPanel.Visible = false
customPanel.Parent = listOuter
do
    local ll = Instance.new("UIListLayout")
    ll.FillDirection = Enum.FillDirection.Vertical
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, 1)
    ll.Parent = customPanel
end

-- Add animation header
local addHeaderRow = Instance.new("Frame")
addHeaderRow.Size = UDim2.new(1, 0, 0, 24)
addHeaderRow.BackgroundColor3 = TH.addBtnBg
addHeaderRow.BackgroundTransparency = 0
addHeaderRow.BorderSizePixel = 0
addHeaderRow.ZIndex = 14
addHeaderRow.LayoutOrder = 0
addHeaderRow.Parent = customPanel
Instance.new("UICorner", addHeaderRow).CornerRadius = UDim.new(0, 6)
do
    local s = Instance.new("UIStroke")
    s.Color = TH.toggleOn
    s.Thickness = 1
    s.Transparency = 0.6
    s.Parent = addHeaderRow
end
local addHeaderBtn = Instance.new("TextButton")
addHeaderBtn.Size = UDim2.new(1, 0, 1, 0)
addHeaderBtn.BackgroundTransparency = 1
addHeaderBtn.Text = "+ Add Animation"
addHeaderBtn.TextColor3 = TH.titleColor
addHeaderBtn.TextSize = 9
addHeaderBtn.Font = Enum.Font.GothamBold
addHeaderBtn.BorderSizePixel = 0
addHeaderBtn.ZIndex = 15
addHeaderBtn.AutoButtonColor = false
addHeaderBtn.Parent = addHeaderRow
addHeaderBtn.MouseEnter:Connect(function()
    TweenService:Create(addHeaderRow, TweenInfo.new(0.12), { BackgroundColor3 = TH.addBtnHover }):Play()
end)
addHeaderBtn.MouseLeave:Connect(function()
    TweenService:Create(addHeaderRow, TweenInfo.new(0.12), { BackgroundColor3 = TH.addBtnBg }):Play()
end)
addHeaderBtn.MouseButton1Down:Connect(function()
    TweenService:Create(addHeaderRow, TweenInfo.new(0.06), { BackgroundColor3 = TH.toggleOn }):Play()
end)
addHeaderBtn.MouseButton1Up:Connect(function()
    TweenService:Create(addHeaderRow, TweenInfo.new(0.1), { BackgroundColor3 = TH.addBtnHover }):Play()
end)

local FORM_H_CLOSED = 0
local FORM_H_OPEN = 192
local addFormWrap = Instance.new("Frame")
addFormWrap.Size = UDim2.new(1, 0, 0, FORM_H_CLOSED)
addFormWrap.BackgroundColor3 = TH.formBg
addFormWrap.BackgroundTransparency = 0.05
addFormWrap.BorderSizePixel = 0
addFormWrap.ClipsDescendants = true
addFormWrap.ZIndex = 13
addFormWrap.LayoutOrder = 1
addFormWrap.Parent = customPanel
do
    local s = Instance.new("UIStroke")
    s.Color = TH.stroke
    s.Thickness = 1
    s.Transparency = 0.5
    s.Parent = addFormWrap
end
local addFormInner = Instance.new("Frame")
addFormInner.Size = UDim2.new(1, 0, 0, FORM_H_OPEN)
addFormInner.BackgroundTransparency = 1
addFormInner.BorderSizePixel = 0
addFormInner.ZIndex = 14
addFormInner.Parent = addFormWrap
do
    local fl = Instance.new("UIListLayout")
    fl.FillDirection = Enum.FillDirection.Vertical
    fl.Padding = UDim.new(0, 4)
    fl.Parent = addFormInner
    local fp = Instance.new("UIPadding")
    fp.PaddingTop = UDim.new(0, 6)
    fp.PaddingBottom = UDim.new(0, 6)
    fp.PaddingLeft = UDim.new(0, 6)
    fp.PaddingRight = UDim.new(0, 6)
    fp.Parent = addFormInner
end
local cancelRow = Instance.new("Frame")
cancelRow.Size = UDim2.new(1, 0, 0, 18)
cancelRow.BackgroundTransparency = 1
cancelRow.BorderSizePixel = 0
cancelRow.ZIndex = 15
cancelRow.Parent = addFormInner
local cancelBtn = Instance.new("TextButton")
cancelBtn.Size = UDim2.new(0, 46, 0, 18)
cancelBtn.Position = UDim2.new(0, 0, 0, 0)
cancelBtn.BackgroundColor3 = TH.stopRed
cancelBtn.Text = "Cancel"
cancelBtn.TextColor3 = TH.subColor
cancelBtn.TextSize = 8
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.BorderSizePixel = 0
cancelBtn.ZIndex = 16
cancelBtn.AutoButtonColor = false
cancelBtn.Parent = cancelRow
Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 4)
mSt(cancelBtn, 0.55)
cancelBtn.MouseEnter:Connect(function()
    TweenService:Create(cancelBtn, TweenInfo.new(0.12), { BackgroundColor3 = TH.stopHover, TextColor3 = TH.titleColor }):Play()
end)
cancelBtn.MouseLeave:Connect(function()
    TweenService:Create(cancelBtn, TweenInfo.new(0.12), { BackgroundColor3 = TH.stopRed, TextColor3 = TH.subColor }):Play()
end)
cancelBtn.MouseButton1Down:Connect(function()
    TweenService:Create(cancelBtn, TweenInfo.new(0.06), { BackgroundColor3 = Color3.fromRGB(220, 70, 70) }):Play()
end)
cancelBtn.MouseButton1Up:Connect(function()
    TweenService:Create(cancelBtn, TweenInfo.new(0.1), { BackgroundColor3 = TH.stopHover }):Play()
end)
local nameIn = Instance.new("TextBox")
nameIn.Size = UDim2.new(1, 0, 0, 24)
nameIn.BackgroundColor3 = TH.btnBg
nameIn.PlaceholderText = "Animation name"
nameIn.PlaceholderColor3 = TH.dimText
nameIn.Text = ""
nameIn.TextColor3 = TH.titleColor
nameIn.TextSize = 9
nameIn.Font = Enum.Font.Gotham
nameIn.TextXAlignment = Enum.TextXAlignment.Left
nameIn.BorderSizePixel = 0
nameIn.ZIndex = 15
nameIn.Parent = addFormInner
Instance.new("UICorner", nameIn).CornerRadius = UDim.new(0, 5)
mSt(nameIn, 0.5)
do local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0, 6); p.Parent = nameIn end
local codeWrap = Instance.new("Frame")
codeWrap.Size = UDim2.new(1, 0, 0, 100)
codeWrap.BackgroundColor3 = TH.btnBg
codeWrap.BorderSizePixel = 0
codeWrap.ClipsDescendants = true
codeWrap.ZIndex = 15
codeWrap.Parent = addFormInner
Instance.new("UICorner", codeWrap).CornerRadius = UDim.new(0, 5)
mSt(codeWrap, 0.5)
local codeSF = Instance.new("ScrollingFrame")
codeSF.Size = UDim2.new(1, 0, 1, 0)
codeSF.CanvasSize = UDim2.new(0, 0, 0, 0)
codeSF.AutomaticCanvasSize = Enum.AutomaticSize.Y
codeSF.BackgroundTransparency = 1
codeSF.BorderSizePixel = 0
codeSF.ScrollBarThickness = 3
codeSF.ScrollBarImageColor3 = TH.toggleOn
codeSF.ScrollBarImageTransparency = 0.4
codeSF.ZIndex = 16
codeSF.ElasticBehavior = Enum.ElasticBehavior.Never
codeSF.Parent = codeWrap
do
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 6)
    p.PaddingTop = UDim.new(0, 4)
    p.PaddingRight = UDim.new(0, 4)
    p.Parent = codeSF
end
local codeIn = Instance.new("TextBox")
codeIn.Size = UDim2.new(1, 0, 0, 0)
codeIn.AutomaticSize = Enum.AutomaticSize.Y
codeIn.BackgroundTransparency = 1
codeIn.PlaceholderText = "Paste keyframe code here..."
codeIn.PlaceholderColor3 = TH.dimText
codeIn.Text = ""
codeIn.TextColor3 = TH.titleColor
codeIn.TextSize = 8
codeIn.Font = Enum.Font.Code
codeIn.TextXAlignment = Enum.TextXAlignment.Left
codeIn.TextYAlignment = Enum.TextYAlignment.Top
codeIn.MultiLine = true
codeIn.ClearTextOnFocus = false
codeIn.TextWrapped = true
codeIn.BorderSizePixel = 0
codeIn.ZIndex = 17
codeIn.Parent = codeSF
local confirmBtn = Instance.new("TextButton")
confirmBtn.Size = UDim2.new(1, 0, 0, 26)
confirmBtn.BackgroundColor3 = TH.toggleOn
confirmBtn.Text = "Confirm Add Animation"
confirmBtn.TextColor3 = Color3.fromRGB(220, 220, 255)
confirmBtn.TextSize = 9
confirmBtn.Font = Enum.Font.GothamBold
confirmBtn.BorderSizePixel = 0
confirmBtn.ZIndex = 15
confirmBtn.AutoButtonColor = false
confirmBtn.Parent = addFormInner
Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 5)
mSt(confirmBtn, 0.4)
confirmBtn.MouseEnter:Connect(function()
    TweenService:Create(confirmBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(140, 140, 255) }):Play()
end)
confirmBtn.MouseLeave:Connect(function()
    TweenService:Create(confirmBtn, TweenInfo.new(0.1), { BackgroundColor3 = TH.toggleOn }):Play()
end)
local formOpen = false
local FORM_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local emptyCustomLbl = Instance.new("Frame")
emptyCustomLbl.Size = UDim2.new(1, 0, 0, 36)
emptyCustomLbl.BackgroundTransparency = 1
emptyCustomLbl.ZIndex = 14
emptyCustomLbl.LayoutOrder = 999999
emptyCustomLbl.Visible = false
emptyCustomLbl.Parent = customPanel
local emptyCustomTxt = Instance.new("TextLabel")
emptyCustomTxt.Size = UDim2.new(1, 0, 1, 0)
emptyCustomTxt.BackgroundTransparency = 1
emptyCustomTxt.TextColor3 = TH.dimText
emptyCustomTxt.TextSize = 9
emptyCustomTxt.Font = Enum.Font.Gotham
emptyCustomTxt.ZIndex = 15
emptyCustomTxt.Text = "No custom animations yet"
emptyCustomTxt.Parent = emptyCustomLbl
local customRows = {}

-- ── Row Building & List Refresh ───────────────────────────────────────────────
local allRows = {}
local buildAllRows, refreshList
local function setFormOpen(open)
    formOpen = open
    local targetH = open and FORM_H_OPEN or FORM_H_CLOSED
    TweenService:Create(addFormWrap, FORM_TWEEN, { Size = UDim2.new(1, 0, 0, targetH) }):Play()
    if not open then
        nameIn.Text = ""
        codeIn.Text = ""
    end
    for _, e in ipairs(customRows) do
        e.frame.Visible = not open
    end
    emptyCustomLbl.Visible = not open and (#customRows == 0)
end
addHeaderBtn.MouseButton1Click:Connect(function() setFormOpen(not formOpen) end)
cancelBtn.MouseButton1Click:Connect(function() setFormOpen(false) end)
local function makeAnimRow(anim, i)
    local isCustom = anim.tag == "custom"
    local parent = isCustom and customPanel or listFrame
    local DEL_W = 14
    local DEL_GAP = 4
    local KB_W = 30
    local KB_GAP = 4
    local STAR_W = 20
    local STAR_X = 6
    local NAME_X = STAR_X + STAR_W + 4
    local KB_FROM_RIGHT = KB_W + (isCustom and (DEL_W + DEL_GAP + KB_GAP) or KB_GAP)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, ROW_H)
    row.BackgroundColor3 = TH.listItem
    row.BackgroundTransparency = 0.2
    row.BorderSizePixel = 0
    row.ZIndex = 14
    row.LayoutOrder = isCustom and (100 + i) or i
    row.Visible = isCustom and (not formOpen) or true
    row.Parent = parent
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 2, 0, ROW_H - 8)
    accent.Position = UDim2.new(0, 0, 0.5, -(ROW_H - 8) / 2)
    accent.BackgroundColor3 = TH.toggleOn
    accent.BackgroundTransparency = 0.6
    accent.BorderSizePixel = 0
    accent.ZIndex = 15
    accent.Parent = row
    Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)
    local star = Instance.new("TextButton")
    star.Size = UDim2.new(0, STAR_W, 0, STAR_W)
    star.Position = UDim2.new(0, STAR_X, 0.5, -STAR_W / 2)
    star.BackgroundTransparency = 1
    star.Text = anim.fav and "★" or "☆"
    star.TextColor3 = anim.fav and TH.starOn or TH.starOff
    star.TextSize = 15
    star.Font = Enum.Font.GothamBold
    star.BorderSizePixel = 0
    star.ZIndex = 17
    star.AutoButtonColor = false
    star.Parent = row
    star.MouseButton1Click:Connect(function()
        anim.fav = not anim.fav
        star.Text = anim.fav and "★" or "☆"
        TweenService:Create(star, TweenInfo.new(0.12), { TextColor3 = anim.fav and TH.starOn or TH.starOff }):Play()
        if currentTab == "Favs" then refreshList() end
        task.defer(saveFavorites)
    end)
    local lblRightPad = isCustom and -(KB_FROM_RIGHT + DEL_W + DEL_GAP + 2) or -(KB_FROM_RIGHT + 2)
    local nLbl = Instance.new("TextLabel")
    nLbl.Size = UDim2.new(1, lblRightPad, 1, 0)
    nLbl.Position = UDim2.new(0, NAME_X, 0, 0)
    nLbl.BackgroundTransparency = 1
    nLbl.Text = anim.n
    nLbl.TextColor3 = TH.titleColor
    nLbl.TextSize = 9
    nLbl.Font = Enum.Font.GothamBold
    nLbl.TextXAlignment = Enum.TextXAlignment.Left
    nLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nLbl.ZIndex = 15
    nLbl.Parent = row
    local ROW_W = CARD_W - 20
    local kbRightSpace = isCustom and (DEL_W + DEL_GAP + KB_GAP) or KB_GAP
    local kbAbsX = ROW_W - kbRightSpace - KB_W
    local kbAbsY = math.floor((ROW_H - (ROW_H - 10)) / 2)
    local getKey, setKey = makeKeybindBtn(row, kbAbsX, kbAbsY, KB_W, ROW_H - 10, 16)
    anim._getKey = getKey
    anim._setKey = setKey
    anim._row = row
    if isCustom then
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.new(0, DEL_W, 0, ROW_H)
        delBtn.Position = UDim2.new(1, -DEL_W - 2, 0, 0)
        delBtn.BackgroundTransparency = 1
        delBtn.Text = "x"
        delBtn.TextColor3 = Color3.fromRGB(200, 80, 80)
        delBtn.TextSize = 12
        delBtn.Font = Enum.Font.GothamBold
        delBtn.BorderSizePixel = 0
        delBtn.ZIndex = 17
        delBtn.AutoButtonColor = false
        delBtn.Parent = row
        delBtn.MouseEnter:Connect(function()
            TweenService:Create(delBtn, TweenInfo.new(0.1), { TextColor3 = Color3.fromRGB(255, 100, 100) }):Play()
        end)
        delBtn.MouseLeave:Connect(function()
            TweenService:Create(delBtn, TweenInfo.new(0.1), { TextColor3 = Color3.fromRGB(180, 80, 80) }):Play()
        end)
        delBtn.MouseButton1Click:Connect(function()
            if dawlatul.animation.state.current_url == anim.url then API.stop_animation() end
            dawlatul.animation.cache[anim.url] = nil
            for idx = #animDB, 1, -1 do
                if animDB[idx] == anim then table.remove(animDB, idx) end
            end
            for idx = #customRows, 1, -1 do
                if customRows[idx].anim == anim then table.remove(customRows, idx) end
            end
            row:Destroy()
            emptyCustomLbl.Visible = (#customRows == 0) and not formOpen
            task.defer(saveCustom)
        end)
    end
    local playRightEdge = isCustom and -(KB_FROM_RIGHT + DEL_W + DEL_GAP + 2) or -(KB_FROM_RIGHT + 2)
    local play = Instance.new("TextButton")
    play.Size = UDim2.new(1, playRightEdge, 1, 0)
    play.Position = UDim2.new(0, NAME_X, 0, 0)
    play.BackgroundTransparency = 1
    play.Text = ""
    play.BorderSizePixel = 0
    play.ZIndex = 14
    play.Parent = row
    play.MouseEnter:Connect(function()
        if curAnimUrl ~= anim.url then
            TweenService:Create(row, TweenInfo.new(0.1), { BackgroundColor3 = TH.listHov, BackgroundTransparency = 0 }):Play()
            TweenService:Create(accent,TweenInfo.new(0.1), { BackgroundTransparency = 0.2 }):Play()
            TweenService:Create(nLbl, TweenInfo.new(0.1), { TextColor3 = Color3.fromRGB(230, 230, 255) }):Play()
        end
    end)
    play.MouseLeave:Connect(function()
        local playing = curAnimUrl == anim.url
        TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = playing and TH.playingRow or TH.listItem, BackgroundTransparency = playing and 0 or 0.2 }):Play()
        TweenService:Create(accent,TweenInfo.new(0.12), { BackgroundTransparency = playing and 0 or 0.6 }):Play()
        TweenService:Create(nLbl, TweenInfo.new(0.12), { TextColor3 = playing and Color3.fromRGB(220, 220, 255) or TH.titleColor }):Play()
    end)
    play.MouseButton1Down:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.06), { BackgroundColor3 = TH.toggleOn, BackgroundTransparency = 0 }):Play()
        TweenService:Create(accent,TweenInfo.new(0.06), { BackgroundTransparency = 0 }):Play()
    end)
    play.MouseButton1Up:Connect(function()
        local playing = curAnimUrl == anim.url
        TweenService:Create(row, TweenInfo.new(0.15), { BackgroundColor3 = playing and TH.playingRow or TH.listHov, BackgroundTransparency = 0 }):Play()
    end)
    play.MouseButton1Click:Connect(function()
        local now = tick()
        if now - lastAnimPlayTime < ANIM_COOLDOWN then return end
        lastAnimPlayTime = now
        if anim.url ~= "" then task.spawn(function() API.play_animation(anim.url) end) end
    end)
    local entry = { frame = row, anim = anim, accent = accent, nLbl = nLbl }
    if isCustom then
        customRows[#customRows + 1] = entry
    else
        allRows[#allRows + 1] = entry
    end
    return entry
end
buildAllRows = function()
    for _, e in ipairs(allRows) do if e.frame and e.frame.Parent then e.frame:Destroy() end end
    for _, e in ipairs(customRows) do if e.frame and e.frame.Parent then e.frame:Destroy() end end
    allRows = {}
    customRows = {}
    for i, anim in ipairs(animDB) do
        makeAnimRow(anim, i)
    end
end
confirmBtn.MouseButton1Click:Connect(function()
    local nm = nameIn.Text:match("^%s*(.-)%s*$")
    local code = codeIn.Text:match("^%s*(.-)%s*$")
    if nm == "" then return end
    if code == "" then return end
    local fn, _parseErr = loadstring(code)
    if not fn then return end
    local ok, res = pcall(fn)
    if not ok then return end
    if type(res) ~= "table" then return end
    local fk = next(res)
    if not fk then return end
    local kfs = res[fk]
    if type(kfs) ~= "table" or #kfs == 0 then return end
    customCtr = customCtr + 1
    local fu = "__custom__" .. customCtr
    dawlatul.animation.cache[fu] = kfs
    local newAnim = { n = nm, url = fu, fav = false, tag = "custom" }
    animDB[#animDB + 1] = newAnim
    makeAnimRow(newAnim, #animDB)
    emptyCustomLbl.Visible = false
    task.delay(0.8, function() setFormOpen(false) end)
    refreshList()
    task.defer(saveCustom)
end)
refreshList = function()
    local isCustom = currentTab == "Custom"
    customPanel.Visible = isCustom
    listFrame.Visible = not isCustom
    if isCustom then
        for _, e in ipairs(customRows) do
            e.frame.Visible = not formOpen
        end
        emptyCustomLbl.Visible = not formOpen and (#customRows == 0)
        return
    end
    local q = searchQuery:lower()
    local any = false
    for _, e in ipairs(allRows) do
        local anim = e.anim
        local matchTab = currentTab == "All" or (currentTab == "Favs" and anim.fav)
        local matchQ = q == "" or anim.n:lower():find(q, 1, true)
        local show = matchTab and matchQ
        e.frame.Visible = show
        if show then any = true end
    end
    emptyLbl.Visible = not any
    emptyTxt.Text = (currentTab == "Favs") and "No favourites yet" or "No results"
end
local function switchTab(name)
    currentTab = name
    for lbl, tb in pairs(tabBtns) do
        local on = lbl == name
        TweenService:Create(tb, TweenInfo.new(0.12), {
            BackgroundColor3 = on and TH.tabOnBg or TH.tabOffBg,
            TextColor3 = on and TH.tabOnTxt or TH.tabOffTxt,
        }):Play()
    end
    refreshList()
end
for lbl, tb in pairs(tabBtns) do
    tb.MouseButton1Click:Connect(function() switchTab(lbl) end)
end
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchQuery = searchBox.Text
    refreshList()
end)

-- ── Animation Callbacks ───────────────────────────────────────────────────────
local function allRowsList()
    local combined = {}
    for _, e in ipairs(allRows) do combined[#combined + 1] = e end
    for _, e in ipairs(customRows) do combined[#combined + 1] = e end
    return combined
end
API.on_animation_play(function(url)
    for _, e in ipairs(allRowsList()) do
        local playing = e.anim.url == url
        local wasPlaying = e.anim.url == curAnimUrl
        if wasPlaying or playing then
            TweenService:Create(e.frame, TweenInfo.new(0.15), { BackgroundColor3 = playing and TH.playingRow or TH.listItem, BackgroundTransparency = playing and 0 or 0.2 }):Play()
            TweenService:Create(e.accent, TweenInfo.new(0.15), { BackgroundTransparency = playing and 0 or 0.6 }):Play()
            TweenService:Create(e.nLbl, TweenInfo.new(0.15), { TextColor3 = playing and Color3.fromRGB(220, 220, 255) or TH.titleColor }):Play()
        end
    end
    curAnimUrl = url
    local name = url
    for _, e in ipairs(allRowsList()) do
        if e.anim.url == url then name = e.anim.n; break end
    end
    playIcon.TextColor3 = TH.toggleOn
    nowPlayLbl.Text = name
    nowPlayLbl.TextColor3 = TH.titleColor
end)
API.on_animation_stop(function()
    for _, e in ipairs(allRowsList()) do
        if e.anim.url == curAnimUrl then
            TweenService:Create(e.frame, TweenInfo.new(0.15), { BackgroundColor3 = TH.listItem, BackgroundTransparency = 0.2 }):Play()
            TweenService:Create(e.accent, TweenInfo.new(0.15), { BackgroundTransparency = 0.6 }):Play()
            TweenService:Create(e.nLbl, TweenInfo.new(0.15), { TextColor3 = TH.titleColor }):Play()
        end
    end
    curAnimUrl = nil
    playIcon.TextColor3 = TH.subColor
    nowPlayLbl.Text = "No animation playing"
    nowPlayLbl.TextColor3 = TH.dimText
end)

buildAllRows()
applyPendingKeybinds()
switchTab("All")
syncReanimBtn()

-- ── Keybind Listener ──────────────────────────────────────────────────────────
local kbEnd = UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Keyboard then
        if justBoundKey and inp.KeyCode == justBoundKey then justBoundKey = nil end
    end
end)
local kbBeg = UserInputService.InputBegan:Connect(function(inp, gp)
    if gp or bindingActive then return end
    if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local key = inp.KeyCode
    if justBoundKey and key == justBoundKey then return end
    if _G._dawlatulPresetCheck and _G._dawlatulPresetCheck(key) then return end
    for _, anim in ipairs(animDB) do
        if anim._getKey and anim._getKey() == key then
            local now = tick()
            if now - lastAnimPlayTime < ANIM_COOLDOWN then return end
            lastAnimPlayTime = now
            if anim.url ~= "" then task.spawn(function() API.play_animation(anim.url) end) end
            return
        end
    end
end)

-- ── Drag to Move ──────────────────────────────────────────────────────────────
local drag = { active = false, sm = nil, sp = nil }
header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        drag.active = true
        drag.sm = inp.Position
        drag.sp = card.Position
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if drag.active and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local d = inp.Position - drag.sm
        card.Position = UDim2.new(drag.sp.X.Scale, drag.sp.X.Offset + d.X, drag.sp.Y.Scale, drag.sp.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag.active = false end
end)

-- ── Ambient Animation ─────────────────────────────────────────────────────────
local SHIM_CYCLE = 3.2
local gT = 0
local ambConn
ambConn = RunService.Heartbeat:Connect(function(dt)
    if not gui.Parent then ambConn:Disconnect(); return end
    gT = gT + dt
    local ringT = math.clamp((gT % 1.6) / 1.6, 0, 1)
    local et = ringT < 0.5 and 2 * ringT * ringT or 1 - ((-2 * ringT + 2) ^ 2) / 2
    local rs = math.round(6 + 8.4 * et)
    if dotRing and dotRing.Parent then
        dotRing.Size = UDim2.new(0, rs, 0, rs)
        dotRing.BackgroundTransparency = 0.5 + 0.5 * et
    end
    local sf = (gT % SHIM_CYCLE) / (SHIM_CYCLE * 0.55)
    shimmer.Position = sf <= 1
        and UDim2.new(-0.5 + 1.5 * (1 - (1 - sf) ^ 3), 0, 0, 0)
        or UDim2.new(1.1, 0, 0, 0)
    if math.floor(gT * 4) % 8 == 0 then syncReanimBtn() end
end)

-- ── Cleanup ───────────────────────────────────────────────────────────────────
local function fullCleanup()
    if kbBeg then pcall(function() kbBeg:Disconnect() end); kbBeg = nil end
    if kbEnd then pcall(function() kbEnd:Disconnect() end); kbEnd = nil end
    justBoundKey = nil
    bindingActive = false
end
function DawlatulUI.destroy()
    if _destroyed then return end
    _destroyed = true
    if gui then gui.Enabled = false end
    fullCleanup()
    if ambConn then ambConn:Disconnect(); ambConn = nil end
    if gui and gui.Parent then gui:Destroy() end
end
gui.AncestryChanged:Connect(function(_, newParent)
    if _destroyed then return end
    if not newParent then
        task.defer(function()
            if not _destroyed and gui and not gui.Parent then
                pcall(function() gui.Parent = CoreGui end)
            end
        end)
    end
end)
