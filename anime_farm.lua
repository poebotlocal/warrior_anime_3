print("[ProCloud] СТАРТ ИНИЦИАЛИЗАЦИЯ ЯДРА v10...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ==========================================
-- 🌐 НАСТРОЙКИ СЕТИ И ОБЛАКА
-- ==========================================
local apiUrl = "http://afkg.ru/config/api.php"
local syncUrl = "http://afkg.ru/config/sync.php"
local savedPoints, activeChain, activeChainName, activeChainIndex = {}, {}, nil, 1
local autoStartConfig = {} 

local reqFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
if not reqFunc then warn("[ProCloud] КРИТИЧЕСКИ: Экзекутор не поддерживает HTTP-запросы!") end

local vipSaveFile = "ProCloud_VIP_Save.txt"
local myBotName = player.Name
local isFollowing = false
local lastProcessedCommandId = 0

getgenv().spamSpace = false
getgenv().spamX = false
getgenv().antiAfkEnabled = false
getgenv().autoRejoinEnabled = false
getgenv().clickTpEnabled = false
getgenv().fleetFollowLeader = nil
getgenv().fleetFollowActive = false

local function req(action, name, body)
    if not reqFunc then return nil end
    local url = apiUrl .. "?action=" .. action
    if name then url = url .. "&name=" .. HttpService:UrlEncode(name) end
    local s, r = pcall(function()
        if body then return reqFunc({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(body)})
        else return reqFunc({Url = url, Method = "GET"}) end
    end)
    if s and r and r.StatusCode == 200 then return r.Body end
    return nil
end

local function savePointsData() req("save_points", nil, savedPoints) end

-- ==========================================
-- ВИЗУАЛИЗАЦИЯ И УПРАВЛЕНИЕ ПЕРСОНАЖЕМ
-- ==========================================
local vizFolder = Workspace:FindFirstChild("RouteVisualizer")
if vizFolder then vizFolder:Destroy() end
vizFolder = Instance.new("Folder", Workspace); vizFolder.Name = "RouteVisualizer"

local function drawRoute()
    vizFolder:ClearAllChildren()
    if not activeChain or #activeChain == 0 then return end
    local prevPart = nil
    for i, posData in ipairs(activeChain) do
        local part = Instance.new("Part")
        part.Size, part.Position = Vector3.new(1.2, 1.2, 1.2), Vector3.new(posData.X, posData.Y, posData.Z)
        part.Anchored, part.CanCollide, part.Material = true, false, Enum.Material.Neon
        part.Color = (i == activeChainIndex) and Color3.fromRGB(60, 255, 60) or Color3.fromRGB(60, 150, 255)
        part.Transparency, part.Parent = 0.4, vizFolder
        local bg = Instance.new("BillboardGui", part)
        bg.Size, bg.AlwaysOnTop, bg.StudsOffset = UDim2.new(0, 100, 0, 30), true, Vector3.new(0, 2, 0)
        local txt = Instance.new("TextLabel", bg)
        txt.Size, txt.BackgroundTransparency, txt.Text = UDim2.new(1,0,1,0), 1, "Шаг " .. i
        txt.TextColor3, txt.Font, txt.TextSize, txt.TextStrokeTransparency = Color3.new(1,1,1), Enum.Font.GothamBlack, 16, 0
        local att = Instance.new("Attachment", part)
        if prevPart then
            local beam = Instance.new("Beam", part)
            beam.Attachment0, beam.Attachment1 = prevPart:FindFirstChildOfClass("Attachment"), att
            beam.FaceCamera, beam.Width0, beam.Width1, beam.Color = true, 0.15, 0.15, ColorSequence.new(Color3.fromRGB(200, 200, 255))
        end
        prevPart = part
    end
end

local function teleportTo(x, y, z)
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
    end
end

local function pressKey(keyCode)
    VIM:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05); VIM:SendKeyEvent(false, keyCode, false, game)
end

local function sendFleetCommand(payload, btnElement, successColor, defaultColor, defaultText)
    if not reqFunc then return end
    btnElement.Text = "..."
    btnElement.BackgroundColor3 = Color3.fromRGB(200, 150, 60)
    task.spawn(function()
        local s, r = pcall(function()
            return reqFunc({
                Url = syncUrl .. "?action=send_cmd", Method = "POST",
                Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(payload)
            })
        end)
        if s and r and r.StatusCode == 200 then btnElement.BackgroundColor3 = successColor
        else btnElement.BackgroundColor3 = Color3.fromRGB(200, 60, 60) end
        task.wait(1)
        btnElement.Text = defaultText; btnElement.BackgroundColor3 = defaultColor
    end)
end

-- =====================================================================
-- ПОСТРОЕНИЕ ИНТЕРФЕЙСА
-- =====================================================================
local guiName = "ProCloud_Consolidated_V10"
local targetParent = player:WaitForChild("PlayerGui")
local sCore, coreRes = pcall(function() return game:GetService("CoreGui") end)
if sCore and coreRes then
    if pcall(function() local d = Instance.new("ScreenGui", coreRes); d:Destroy() end) then targetParent = coreRes end
end

if targetParent:FindFirstChild(guiName) then targetParent[guiName]:Destroy() end
local screenGui = Instance.new("ScreenGui", targetParent); screenGui.Name, screenGui.ResetOnSpawn = guiName, false

-- --- 1. ПЛАВАЮЩИЙ ТУЛБАР (СВЁРНУТЫЙ) ---
local minToolbar = Instance.new("Frame", screenGui)
minToolbar.Size, minToolbar.Position = UDim2.new(0, 345, 0, 45), UDim2.new(0.5, -172, 0.9, -60)
minToolbar.BackgroundColor3, minToolbar.Active, minToolbar.Draggable = Color3.fromRGB(30, 30, 35), true, true
minToolbar.Visible = false
Instance.new("UICorner", minToolbar).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", minToolbar).Color = Color3.fromRGB(60, 60, 70)

local minLayout = Instance.new("UIListLayout", minToolbar)
minLayout.FillDirection, minLayout.HorizontalAlignment, minLayout.VerticalAlignment = Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center; minLayout.Padding = UDim.new(0, 8)

local minBtnTpFleet = Instance.new("TextButton", minToolbar); minBtnTpFleet.Size, minBtnTpFleet.BackgroundColor3 = UDim2.new(0, 90, 0, 33), Color3.fromRGB(150, 60, 200); minBtnTpFleet.Text, minBtnTpFleet.TextColor3, minBtnTpFleet.Font, minBtnTpFleet.TextSize = "⚡ ТП ФЛОТ", Color3.new(1,1,1), Enum.Font.GothamBold, 11; Instance.new("UICorner", minBtnTpFleet).CornerRadius = UDim.new(0, 4)
local minBtnClickTP = Instance.new("TextButton", minToolbar); minBtnClickTP.Size, minBtnClickTP.BackgroundColor3 = UDim2.new(0, 115, 0, 33), Color3.fromRGB(200, 60, 60); minBtnClickTP.Text, minBtnClickTP.TextColor3, minBtnClickTP.Font, minBtnClickTP.TextSize = "🎯 ClickTP: ВЫКЛ", Color3.new(1,1,1), Enum.Font.GothamBold, 11; Instance.new("UICorner", minBtnClickTP).CornerRadius = UDim.new(0, 4)
local minBtnOpenFull = Instance.new("TextButton", minToolbar); minBtnOpenFull.Size, minBtnOpenFull.BackgroundColor3 = UDim2.new(0, 85, 0, 33), Color3.fromRGB(60, 120, 200); minBtnOpenFull.Text, minBtnOpenFull.TextColor3, minBtnOpenFull.Font, minBtnOpenFull.TextSize = "⚙️ МЕНЮ", Color3.new(1,1,1), Enum.Font.GothamBold, 11; Instance.new("UICorner", minBtnOpenFull).CornerRadius = UDim.new(0, 4)
local minBtnCloseAll = Instance.new("TextButton", minToolbar); minBtnCloseAll.Size, minBtnCloseAll.BackgroundColor3 = UDim2.new(0, 25, 0, 33), Color3.fromRGB(200, 60, 60); minBtnCloseAll.Text, minBtnCloseAll.TextColor3, minBtnCloseAll.Font, minBtnCloseAll.TextSize = "X", Color3.new(1,1,1), Enum.Font.GothamBold, 12; Instance.new("UICorner", minBtnCloseAll).CornerRadius = UDim.new(0, 4)

-- --- 2. ГЛАВНОЕ ОКНО ---
local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size, mainFrame.Position = UDim2.new(0, 580, 0, 430), UDim2.new(0.5, -290, 0.5, -215)
mainFrame.BackgroundColor3, mainFrame.Active, mainFrame.Draggable = Color3.fromRGB(25, 25, 25), true, true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local minBtn = Instance.new("TextButton", mainFrame); minBtn.Size, minBtn.Position, minBtn.BackgroundTransparency = UDim2.new(0, 40, 0, 30), UDim2.new(1, -80, 0, 0), 1; minBtn.Text, minBtn.TextColor3, minBtn.Font, minBtn.TextSize = "—", Color3.fromRGB(200, 200, 200), Enum.Font.GothamBold, 16
local closeBtn = Instance.new("TextButton", mainFrame); closeBtn.Size, closeBtn.Position, closeBtn.BackgroundTransparency = UDim2.new(0, 40, 0, 30), UDim2.new(1, -40, 0, 0), 1; closeBtn.Text, closeBtn.TextColor3, closeBtn.Font, closeBtn.TextSize = "X", Color3.fromRGB(255, 80, 80), Enum.Font.GothamBold, 16

minBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false; minToolbar.Visible = true end)
minBtnOpenFull.MouseButton1Click:Connect(function() minToolbar.Visible = false; mainFrame.Visible = true end)

local tabFrame = Instance.new("Frame", mainFrame); tabFrame.Size, tabFrame.Position, tabFrame.BackgroundTransparency = UDim2.new(1, -100, 0, 30), UDim2.new(0, 10, 0, 10), 1

local function createTabBtn(text, posX, width)
    local btn = Instance.new("TextButton", tabFrame); btn.Size, btn.Position, btn.BackgroundColor3 = UDim2.new(0, width, 1, 0), UDim2.new(0, posX, 0, 0), Color3.fromRGB(40, 40, 40); btn.Text, btn.TextColor3, btn.Font, btn.TextSize = text, Color3.fromRGB(200, 200, 200), Enum.Font.GothamBold, 12; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4); return btn
end

local btnTabMain   = createTabBtn("ГЛАВНАЯ",  0,   100)
local btnTabFleet  = createTabBtn("ФЛОТ",     105, 90)
local btnTabPoints = createTabBtn("ТОЧКИ",    200, 110)
local btnTabChains = createTabBtn("МАРШРУТЫ", 315, 115)

local contentFrame = Instance.new("Frame", mainFrame); contentFrame.Size, contentFrame.Position, contentFrame.BackgroundTransparency = UDim2.new(1, -20, 1, -60), UDim2.new(0, 10, 0, 50), 1

local pageMain   = Instance.new("Frame", contentFrame); pageMain.Size, pageMain.BackgroundTransparency = UDim2.new(1,0,1,0), 1
local pageFleet  = Instance.new("Frame", contentFrame); pageFleet.Size, pageFleet.BackgroundTransparency, pageFleet.Visible = UDim2.new(1,0,1,0), 1, false
local pagePoints = Instance.new("Frame", contentFrame); pagePoints.Size, pagePoints.BackgroundTransparency, pagePoints.Visible = UDim2.new(1,0,1,0), 1, false
local pageChains = Instance.new("Frame", contentFrame); pageChains.Size, pageChains.BackgroundTransparency, pageChains.Visible = UDim2.new(1,0,1,0), 1, false

local function switchTab(tabStr) pageMain.Visible = (tabStr=="Main"); pageFleet.Visible = (tabStr=="Fleet"); pagePoints.Visible = (tabStr=="Points"); pageChains.Visible = (tabStr=="Chains") end
btnTabMain.MouseButton1Click:Connect(function() switchTab("Main") end); btnTabFleet.MouseButton1Click:Connect(function() switchTab("Fleet") end); btnTabPoints.MouseButton1Click:Connect(function() switchTab("Points") end); btnTabChains.MouseButton1Click:Connect(function() switchTab("Chains") end)


-- =====================================================================
-- ВКЛАДКА 1: ГЛАВНАЯ
-- =====================================================================
local function createSettingRow(parent, yPos, labelText, defaultInput, btnText, useInput)
    local label = Instance.new("TextLabel", parent); label.Size, label.Position, label.BackgroundTransparency = UDim2.new(0, 150, 0, 30), UDim2.new(0, 10, 0, yPos), 1; label.Text, label.TextColor3, label.Font, label.TextSize, label.TextXAlignment = labelText, Color3.new(1,1,1), Enum.Font.GothamMedium, 13, Enum.TextXAlignment.Left
    local input = nil
    if useInput then
        input = Instance.new("TextBox", parent); input.Size, input.Position, input.BackgroundColor3 = UDim2.new(0, 60, 0, 30), UDim2.new(0, 170, 0, yPos), Color3.fromRGB(40,40,40); input.Text, input.TextColor3, input.Font, input.TextSize = tostring(defaultInput), Color3.new(1,1,1), Enum.Font.Gotham, 14; Instance.new("UICorner", input).CornerRadius = UDim.new(0, 4)
    end
    local btn = Instance.new("TextButton", parent); btn.Size, btn.Position, btn.BackgroundColor3 = UDim2.new(0, 100, 0, 30), UDim2.new(0, 240, 0, yPos), Color3.fromRGB(200, 60, 60); btn.Text, btn.TextColor3, btn.Font, btn.TextSize = btnText, Color3.new(1,1,1), Enum.Font.GothamBold, 12; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    return input, btn
end

local spaceDelay, spaceToggle = createSettingRow(pageMain, 0,   "Спам Пробел (сек):", 1, "ВЫКЛ", true)
local xDelay, xToggle         = createSettingRow(pageMain, 40,  "Спам 'X' (сек):",    1, "ВЫКЛ", true)
local _, afkToggle            = createSettingRow(pageMain, 80,  "Anti-AFK (Анти-кик):", nil, "ВЫКЛ", false)
local _, rejoinToggle         = createSettingRow(pageMain, 120, "Auto-Rejoin (Реконнект):", nil, "ВЫКЛ", false)
local _, mainClickTpBtn       = createSettingRow(pageMain, 160, "Click Teleport:", nil, "ВЫКЛ", false)

local function toggleSpaceMode(forceState, forceInterval)
    if forceState ~= nil then getgenv().spamSpace = forceState else getgenv().spamSpace = not getgenv().spamSpace end
    if forceInterval then spaceDelay.Text = tostring(forceInterval) end
    spaceToggle.BackgroundColor3 = getgenv().spamSpace and Color3.fromRGB(60, 170, 60) or Color3.fromRGB(200, 60, 60); spaceToggle.Text = getgenv().spamSpace and "ВКЛ" or "ВЫКЛ"

    if getgenv().spamSpace then
        task.spawn(function() while getgenv().spamSpace do pressKey(Enum.KeyCode.Space); task.wait(tonumber(spaceDelay.Text) or 1) end end)
    end
end
spaceToggle.MouseButton1Click:Connect(function() toggleSpaceMode() end)

xToggle.MouseButton1Click:Connect(function() getgenv().spamX = not getgenv().spamX; xToggle.BackgroundColor3, xToggle.Text = (getgenv().spamX and Color3.fromRGB(60, 170, 60) or Color3.fromRGB(200, 60, 60)), (getgenv().spamX and "ВКЛ" or "ВЫКЛ"); if getgenv().spamX then task.spawn(function() while getgenv().spamX do pressKey(Enum.KeyCode.X); task.wait(tonumber(xDelay.Text) or 1) end end) end end)

afkToggle.MouseButton1Click:Connect(function() getgenv().antiAfkEnabled = not getgenv().antiAfkEnabled; afkToggle.BackgroundColor3, afkToggle.Text = (getgenv().antiAfkEnabled and Color3.fromRGB(60, 170, 60) or Color3.fromRGB(200, 60, 60)), (getgenv().antiAfkEnabled and "ВКЛ" or "ВЫКЛ") end)
player.Idled:Connect(function() if getgenv().antiAfkEnabled then VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame); task.wait(1); VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame) end end)

rejoinToggle.MouseButton1Click:Connect(function() getgenv().autoRejoinEnabled = not getgenv().autoRejoinEnabled; rejoinToggle.BackgroundColor3, rejoinToggle.Text = (getgenv().autoRejoinEnabled and Color3.fromRGB(60, 170, 60) or Color3.fromRGB(200, 60, 60)), (getgenv().autoRejoinEnabled and "ВКЛ" or "ВЫКЛ") end)

local function syncClickTpState() local state = getgenv().clickTpEnabled; local bg = state and Color3.fromRGB(60, 170, 60) or Color3.fromRGB(200, 60, 60); minBtnClickTP.BackgroundColor3, minBtnClickTP.Text = bg, (state and "🎯 ClickTP: ВКЛ" or "🎯 ClickTP: ВЫКЛ"); mainClickTpBtn.BackgroundColor3, mainClickTpBtn.Text = bg, (state and "ВКЛ" or "ВЫКЛ") end
minBtnClickTP.MouseButton1Click:Connect(function() getgenv().clickTpEnabled = not getgenv().clickTpEnabled; syncClickTpState() end)
mainClickTpBtn.MouseButton1Click:Connect(function() getgenv().clickTpEnabled = not getgenv().clickTpEnabled; syncClickTpState() end)

local clickTpConn = mouse.Button1Down:Connect(function() if getgenv().clickTpEnabled then local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart"); if r and mouse.Hit then r.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)) end end end)

-- Server Hopper
local hopLabel = Instance.new("TextLabel", pageMain); hopLabel.Size, hopLabel.Position, hopLabel.BackgroundTransparency = UDim2.new(1, 0, 0, 20), UDim2.new(0, 10, 0, 205), 1; hopLabel.Text, hopLabel.TextColor3, hopLabel.Font, hopLabel.TextSize, hopLabel.TextXAlignment = "Прыжок по серверам (Server Hopper):", Color3.fromRGB(150, 150, 200), Enum.Font.GothamBold, 13, Enum.TextXAlignment.Left
local hopEmptyBtn = Instance.new("TextButton", pageMain); hopEmptyBtn.Size, hopEmptyBtn.Position, hopEmptyBtn.BackgroundColor3 = UDim2.new(0, 160, 0, 30), UDim2.new(0, 10, 0, 230), Color3.fromRGB(60, 120, 200); hopEmptyBtn.Text, hopEmptyBtn.TextColor3, hopEmptyBtn.Font, hopEmptyBtn.TextSize = "МЕНЕЕ ЗАГРУЖЕННЫЙ", Color3.new(1,1,1), Enum.Font.GothamBold, 11; Instance.new("UICorner", hopEmptyBtn).CornerRadius = UDim.new(0, 4)
local hopFullBtn = Instance.new("TextButton", pageMain); hopFullBtn.Size, hopFullBtn.Position, hopFullBtn.BackgroundColor3 = UDim2.new(0, 160, 0, 30), UDim2.new(0, 180, 0, 230), Color3.fromRGB(200, 100, 60); hopFullBtn.Text, hopFullBtn.TextColor3, hopFullBtn.Font, hopFullBtn.TextSize = "ПОЛНЫЙ (1 место)", Color3.new(1,1,1), Enum.Font.GothamBold, 11; Instance.new("UICorner", hopFullBtn).CornerRadius = UDim.new(0, 4)

local function serverHop(sortOrder) hopLabel.Text = "Ищем сервер..."; task.spawn(function() local url = "https://games.roproxy.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=" .. sortOrder .. "&limit=100"; local s, r = pcall(function() return reqFunc({Url = url, Method = "GET"}) end); if s and r and r.StatusCode == 200 then local data = HttpService:JSONDecode(r.Body); if data and data.data then for _, srv in ipairs(data.data) do if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then hopLabel.Text = "Телепортируемся..."; TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, player); return end end end end; hopLabel.Text = "Сервер не найден :(" end) end
hopEmptyBtn.MouseButton1Click:Connect(function() serverHop("Asc") end); hopFullBtn.MouseButton1Click:Connect(function() serverHop("Desc") end)


-- =====================================================================
-- ВКЛАДКА 2: ФЛОТ
-- =====================================================================
local fleetDescLcl = Instance.new("TextLabel", pageFleet); fleetDescLcl.Size, fleetDescLcl.Position, fleetDescLcl.BackgroundTransparency = UDim2.new(1, 0, 0, 30), UDim2.new(0, 10, 0, 10), 1; fleetDescLcl.Text, fleetDescLcl.TextColor3, fleetDescLcl.Font, fleetDescLcl.TextSize, fleetDescLcl.TextXAlignment = "Управление подключенными окнами через Web-API:", Color3.fromRGB(170, 170, 200), Enum.Font.GothamMedium, 13, Enum.TextXAlignment.Left
local mainBtnTpFleet = Instance.new("TextButton", pageFleet); mainBtnTpFleet.Size, mainBtnTpFleet.Position, mainBtnTpFleet.BackgroundColor3 = UDim2.new(0, 220, 0, 45), UDim2.new(0, 10, 0, 50), Color3.fromRGB(150, 60, 200); mainBtnTpFleet.Text, mainBtnTpFleet.TextColor3, mainBtnTpFleet.Font, mainBtnTpFleet.TextSize = "⚡ ТП ВЕСЬ ФЛОТ КО МНЕ", Color3.new(1,1,1), Enum.Font.GothamBold, 12; Instance.new("UICorner", mainBtnTpFleet).CornerRadius = UDim.new(0, 6)
local mainBtnFollow = Instance.new("TextButton", pageFleet); mainBtnFollow.Size, mainBtnFollow.Position, mainBtnFollow.BackgroundColor3 = UDim2.new(0, 220, 0, 45), UDim2.new(0, 245, 0, 50), Color3.fromRGB(60, 120, 200); mainBtnFollow.Text, mainBtnFollow.TextColor3, mainBtnFollow.Font, mainBtnFollow.TextSize = "🏃 ФЛОТ: БЕЖАТЬ ЗА МНОЙ", Color3.new(1,1,1), Enum.Font.GothamBold, 12; Instance.new("UICorner", mainBtnFollow).CornerRadius = UDim.new(0, 6)

local function executeFleetTpToMe(btnRef) local char = player.Character; if char and char:FindFirstChild("HumanoidRootPart") then local pos = char.HumanoidRootPart.Position; sendFleetCommand({type = "tp", targets = "All", leader = player.Name, x = pos.X, y = pos.Y, z = pos.Z}, btnRef, Color3.fromRGB(60, 170, 60), Color3.fromRGB(150, 60, 200), btnRef.Text) end end
minBtnTpFleet.MouseButton1Click:Connect(function() executeFleetTpToMe(minBtnTpFleet) end); mainBtnTpFleet.MouseButton1Click:Connect(function() executeFleetTpToMe(mainBtnTpFleet) end)
mainBtnFollow.MouseButton1Click:Connect(function() isFollowing = not isFollowing; sendFleetCommand({type = (isFollowing and "follow" or "stop_follow"), targets = "All", leader = player.Name}, mainBtnFollow, Color3.fromRGB(60, 170, 60), (isFollowing and Color3.fromRGB(200, 60, 60) or Color3.fromRGB(60, 120, 200)), (isFollowing and "🛑 СТОП ФОЛЛОВ" or "🏃 ФЛОТ: БЕЖАТЬ ЗА МНОЙ")) end)


-- =====================================================================
-- ВКЛАДКА 3: ТОЧКИ (С ГИБРИДНОЙ ПАНЕЛЬЮ АВТО-СТАРТА v10)
-- =====================================================================
local asTopContainer = Instance.new("Frame", pagePoints)
asTopContainer.Size, asTopContainer.Position, asTopContainer.BackgroundTransparency = UDim2.new(1, -10, 0, 32), UDim2.new(0, 0, 0, 0), 1
local asTopLayout = Instance.new("UIListLayout", asTopContainer)
asTopLayout.FillDirection, asTopLayout.HorizontalAlignment, asTopLayout.VerticalAlignment = Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center; asTopLayout.Padding = UDim.new(0, 5)

local asLabel = Instance.new("TextLabel", asTopContainer); asLabel.Size, asLabel.BackgroundTransparency = UDim2.new(0, 40, 0, 30), 1; asLabel.Text, asLabel.TextColor3, asLabel.Font, asLabel.TextSize = "Авто:", Color3.fromRGB(200, 200, 255), Enum.Font.GothamBold, 12
local asNickInput = Instance.new("TextBox", asTopContainer); asNickInput.Size, asNickInput.BackgroundColor3 = UDim2.new(0, 85, 0, 30), Color3.fromRGB(40,40,40); asNickInput.Text, asNickInput.TextColor3, asNickInput.Font, asNickInput.TextSize = player.Name, Color3.new(1,1,1), Enum.Font.Gotham, 11; Instance.new("UICorner", asNickInput).CornerRadius = UDim.new(0, 4)

local isDualMode = false
local asModeBtn = Instance.new("TextButton", asTopContainer)
asModeBtn.Size, asModeBtn.BackgroundColor3 = UDim2.new(0, 105, 0, 30), Color3.fromRGB(200, 110, 50)
asModeBtn.Text, asModeBtn.TextColor3, asModeBtn.Font, asModeBtn.TextSize = "Режим: 1 ТЧК", Color3.new(1,1,1), Enum.Font.GothamBold, 11
Instance.new("UICorner", asModeBtn).CornerRadius = UDim.new(0, 4)

local asP1Btn = Instance.new("TextButton", asTopContainer); asP1Btn.Size, asP1Btn.BackgroundColor3 = UDim2.new(0, 105, 0, 30), Color3.fromRGB(60, 120, 200); asP1Btn.Text, asP1Btn.TextColor3, asP1Btn.Font, asP1Btn.TextSize = "Точка 1...", Color3.new(1,1,1), Enum.Font.GothamBold, 11; Instance.new("UICorner", asP1Btn).CornerRadius = UDim.new(0, 4)
local asP2Btn = Instance.new("TextButton", asTopContainer); asP2Btn.Size, asP2Btn.BackgroundColor3 = UDim2.new(0, 105, 0, 30), Color3.fromRGB(120, 60, 200); asP2Btn.Text, asP2Btn.TextColor3, asP2Btn.Font, asP2Btn.TextSize = "Точка 2...", Color3.new(1,1,1), Enum.Font.GothamBold, 11; Instance.new("UICorner", asP2Btn).CornerRadius = UDim.new(0, 4); asP2Btn.Visible = false

local asSaveBtn = Instance.new("TextButton", asTopContainer); asSaveBtn.Size, asSaveBtn.BackgroundColor3 = UDim2.new(0, 80, 0, 30), Color3.fromRGB(60, 170, 60); asSaveBtn.Text, asSaveBtn.TextColor3, asSaveBtn.Font, asSaveBtn.TextSize = "БИНД", Color3.new(1,1,1), Enum.Font.GothamBold, 11; Instance.new("UICorner", asSaveBtn).CornerRadius = UDim.new(0, 4)

local asDropdown = Instance.new("ScrollingFrame", pagePoints)
asDropdown.Size, asDropdown.Position, asDropdown.BackgroundColor3 = UDim2.new(0, 180, 0, 130), UDim2.new(0, 235, 0, 35), Color3.fromRGB(35, 35, 35)
asDropdown.CanvasSize, asDropdown.ScrollBarThickness, asDropdown.Visible, asDropdown.ZIndex = UDim2.new(0,0,0,0), 4, false, 10
local asDropLayout = Instance.new("UIListLayout", asDropdown); asDropLayout.Padding = UDim.new(0, 2)

local activeTargetBtn = nil
local function populateAsDropdown(targetBtn)
    activeTargetBtn = targetBtn
    for _,v in pairs(asDropdown:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
    local c = 0
    for pName, _ in pairs(savedPoints) do
        c = c + 1
        local b = Instance.new("TextButton", asDropdown); b.Size, b.BackgroundColor3 = UDim2.new(1, -8, 0, 22), Color3.fromRGB(50,50,50); b.Text, b.TextColor3, b.Font, b.TextSize = pName, Color3.new(1,1,1), Enum.Font.Gotham, 11
        b.MouseButton1Click:Connect(function() if activeTargetBtn then activeTargetBtn.Text = pName end; asDropdown.Visible = false end)
    end
    asDropdown.CanvasSize = UDim2.new(0,0,0, c*24)
end

asModeBtn.MouseButton1Click:Connect(function()
    isDualMode = not isDualMode
    asP2Btn.Visible = isDualMode
    asModeBtn.Text = isDualMode and "Режим: 2 ТЧК" or "Режим: 1 ТЧК"
    asModeBtn.BackgroundColor3 = isDualMode and Color3.fromRGB(200, 50, 110) or Color3.fromRGB(200, 110, 50)
end)

asP1Btn.MouseButton1Click:Connect(function() asDropdown.Visible = true; asDropdown.Position = UDim2.new(0, asP1Btn.AbsolutePosition.X - mainFrame.AbsolutePosition.X, 0, 35); populateAsDropdown(asP1Btn) end)
asP2Btn.MouseButton1Click:Connect(function() asDropdown.Visible = true; asDropdown.Position = UDim2.new(0, asP2Btn.AbsolutePosition.X - mainFrame.AbsolutePosition.X, 0, 35); populateAsDropdown(asP2Btn) end)

asSaveBtn.MouseButton1Click:Connect(function()
    local n, pt1, pt2 = asNickInput.Text, asP1Btn.Text, asP2Btn.Text
    if n == "" or pt1 == "Точка 1..." or not savedPoints[pt1] then return end
    if isDualMode and (pt2 == "Точка 2..." or not savedPoints[pt2]) then return end

    local payload = { mode = (isDualMode and "dual" or "single"), p1 = pt1 }
    if isDualMode then payload.p2 = pt2 end

    autoStartConfig[n] = payload
    req("save_autostart", nil, autoStartConfig)

    asSaveBtn.Text = "ОК!"; task.wait(1); asSaveBtn.Text = "БИНД"
end)

-- --- СТАНДАРТНОЕ СОЗДАНИЕ ТОЧЕК (СДВИНУТО НА Y=45) ---
local ptNameInput = Instance.new("TextBox", pagePoints); ptNameInput.Size, ptNameInput.Position, ptNameInput.BackgroundColor3 = UDim2.new(0, 200, 0, 35), UDim2.new(0, 0, 0, 45), Color3.fromRGB(40, 40, 40); ptNameInput.Text, ptNameInput.PlaceholderText, ptNameInput.TextColor3 = "", "Название точки...", Color3.new(1,1,1); ptNameInput.Font, ptNameInput.TextSize = Enum.Font.Gotham, 14; Instance.new("UICorner", ptNameInput).CornerRadius = UDim.new(0, 4)
local ptSaveBtn = Instance.new("TextButton", pagePoints); ptSaveBtn.Size, ptSaveBtn.Position, ptSaveBtn.BackgroundColor3 = UDim2.new(0, 150, 0, 35), UDim2.new(0, 210, 0, 45), Color3.fromRGB(60, 170, 60); ptSaveBtn.Text, ptSaveBtn.TextColor3, ptSaveBtn.Font, ptSaveBtn.TextSize = "+ СОХРАНИТЬ", Color3.new(1,1,1), Enum.Font.GothamBold, 12; Instance.new("UICorner", ptSaveBtn).CornerRadius = UDim.new(0, 4)
local ptList = Instance.new("ScrollingFrame", pagePoints); ptList.Size, ptList.Position, ptList.BackgroundTransparency = UDim2.new(1, 0, 1, -90), UDim2.new(0, 0, 0, 90), 1; ptList.CanvasSize, ptList.ScrollBarThickness = UDim2.new(0, 0, 0, 0), 6; local ptLayout = Instance.new("UIListLayout", ptList); ptLayout.Padding = UDim.new(0, 5)

local function refreshPointsUI()
    for _, v in pairs(ptList:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
    local count = 0
    for name, pos in pairs(savedPoints) do
        count = count + 1
        local item = Instance.new("Frame", ptList); item.Size, item.BackgroundColor3 = UDim2.new(1, -15, 0, 35), Color3.fromRGB(40,40,40); Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)
        local lbl = Instance.new("TextLabel", item); lbl.Size, lbl.Position, lbl.BackgroundTransparency = UDim2.new(0, 200, 1, 0), UDim2.new(0, 10, 0, 0), 1; lbl.Text, lbl.TextColor3, lbl.Font, lbl.TextSize, lbl.TextXAlignment = name, Color3.new(1,1,1), Enum.Font.Gotham, 14, Enum.TextXAlignment.Left
        local tpBtn = Instance.new("TextButton", item); tpBtn.Size, tpBtn.Position, tpBtn.BackgroundColor3 = UDim2.new(0, 60, 0, 25), UDim2.new(1, -115, 0, 5), Color3.fromRGB(60, 120, 200); tpBtn.Text, tpBtn.TextColor3, tpBtn.Font, tpBtn.TextSize = "ТП", Color3.new(1,1,1), Enum.Font.GothamBold, 12; Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 4)
        local delBtn = Instance.new("TextButton", item); delBtn.Size, delBtn.Position, delBtn.BackgroundColor3 = UDim2.new(0, 40, 0, 25), UDim2.new(1, -45, 0, 5), Color3.fromRGB(200, 60, 60); delBtn.Text, delBtn.TextColor3, delBtn.Font, delBtn.TextSize = "X", Color3.new(1,1,1), Enum.Font.GothamBold, 12; Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 4)

        tpBtn.MouseButton1Click:Connect(function() teleportTo(pos.X, pos.Y, pos.Z) end)
        delBtn.MouseButton1Click:Connect(function() savedPoints[name] = nil; savePointsData(); refreshPointsUI() end)
    end
    ptList.CanvasSize = UDim2.new(0, 0, 0, count * 40)
end

ptSaveBtn.MouseButton1Click:Connect(function()
    local name = ptNameInput.Text; if name == "" then name = "Точка " .. tostring(math.random(100, 999)) end
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local p = player.Character.HumanoidRootPart.Position; savedPoints[name] = {X = p.X, Y = p.Y, Z = p.Z}; savePointsData(); ptNameInput.Text = ""; refreshPointsUI()
    end
end)


-- =====================================================================
-- ВКЛАДКА 4: МАРШРУТЫ
-- =====================================================================
local rListFrame = Instance.new("ScrollingFrame", pageChains); rListFrame.Size, rListFrame.Position, rListFrame.BackgroundTransparency = UDim2.new(0, 160, 1, -40), UDim2.new(0, 0, 0, 40), 1; rListFrame.CanvasSize, rListFrame.ScrollBarThickness = UDim2.new(0, 0, 0, 0), 4; local rListLayout = Instance.new("UIListLayout", rListFrame); rListLayout.Padding = UDim.new(0, 5)
local refreshListBtn = Instance.new("TextButton", pageChains); refreshListBtn.Size, refreshListBtn.Position, refreshListBtn.BackgroundColor3 = UDim2.new(0, 160, 0, 30), UDim2.new(0, 0, 0, 0), Color3.fromRGB(60, 120, 200); refreshListBtn.Text, refreshListBtn.TextColor3, refreshListBtn.Font, refreshListBtn.TextSize = "ОБНОВИТЬ СПИСОК", Color3.new(1,1,1), Enum.Font.GothamBold, 11; Instance.new("UICorner", refreshListBtn).CornerRadius = UDim.new(0, 4)

local editorFrame = Instance.new("Frame", pageChains); editorFrame.Size, editorFrame.Position, editorFrame.BackgroundTransparency = UDim2.new(1, -170, 1, 0), UDim2.new(0, 170, 0, 0), 1
local chStatusText = Instance.new("TextLabel", editorFrame); chStatusText.Size, chStatusText.Position, chStatusText.BackgroundTransparency = UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 0), 1; chStatusText.Text, chStatusText.TextColor3, chStatusText.Font, chStatusText.TextSize = "Выберите маршрут из списка", Color3.new(0.8,0.8,0.8), Enum.Font.GothamMedium, 14
local newChNameInput = Instance.new("TextBox", editorFrame); newChNameInput.Size, newChNameInput.Position, newChNameInput.BackgroundColor3 = UDim2.new(0, 180, 0, 30), UDim2.new(0, 0, 0, 25), Color3.fromRGB(40, 40, 40); newChNameInput.Text, newChNameInput.PlaceholderText, newChNameInput.TextColor3 = "", "Имя маршрута...", Color3.new(1,1,1); newChNameInput.Font, newChNameInput.TextSize = Enum.Font.Gotham, 12; Instance.new("UICorner", newChNameInput).CornerRadius = UDim.new(0, 4)
local createBtn = Instance.new("TextButton", editorFrame); createBtn.Size, createBtn.Position, createBtn.BackgroundColor3 = UDim2.new(0, 130, 0, 30), UDim2.new(0, 190, 0, 25), Color3.fromRGB(150, 100, 200); createBtn.Text, createBtn.TextColor3, createBtn.Font, createBtn.TextSize = "СОЗДАТЬ", Color3.new(1,1,1), Enum.Font.GothamBold, 12; Instance.new("UICorner", createBtn).CornerRadius = UDim.new(0, 4)
local chAddBtn = Instance.new("TextButton", editorFrame); chAddBtn.Size, chAddBtn.Position, chAddBtn.BackgroundColor3 = UDim2.new(1, 0, 0, 35), UDim2.new(0, 0, 0, 65), Color3.fromRGB(60, 170, 60); chAddBtn.Text, chAddBtn.TextColor3, chAddBtn.Font, chAddBtn.TextSize = "+ ДОБАВИТЬ ТОЧКУ СЮДА", Color3.new(1,1,1), Enum.Font.GothamBold, 12; Instance.new("UICorner", chAddBtn).CornerRadius = UDim.new(0, 4)
local chNextBtn = Instance.new("TextButton", editorFrame); chNextBtn.Size, chNextBtn.Position, chNextBtn.BackgroundColor3 = UDim2.new(1, 0, 0, 35), UDim2.new(0, 0, 0, 105), Color3.fromRGB(60, 120, 200); chNextBtn.Text, chNextBtn.TextColor3, chNextBtn.Font, chNextBtn.TextSize = "ТП -> СЛЕДУЮЩИЙ ШАГ", Color3.new(1,1,1), Enum.Font.GothamBold, 12; Instance.new("UICorner", chNextBtn).CornerRadius = UDim.new(0, 4)
local chainList = Instance.new("ScrollingFrame", editorFrame); chainList.Size, chainList.Position, chainList.BackgroundTransparency = UDim2.new(1, 0, 1, -150), UDim2.new(0, 0, 0, 150), 1; chainList.CanvasSize, chainList.ScrollBarThickness = UDim2.new(0, 0, 0, 0), 6; local chainLayout = Instance.new("UIListLayout", chainList); chainLayout.Padding = UDim.new(0, 5)

local function renderChainEditor()
    for _, v in pairs(chainList:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
    if not activeChainName then return end
    chStatusText.Text = string.format("Загружен: %s | Точек: %d", activeChainName, #activeChain); drawRoute()
    for i, pos in ipairs(activeChain) do
        local item = Instance.new("Frame", chainList); item.Size, item.BackgroundColor3 = UDim2.new(1, -15, 0, 35), Color3.fromRGB(40,40,40); Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)
        local lbl = Instance.new("TextLabel", item); lbl.Size, lbl.Position, lbl.BackgroundTransparency = UDim2.new(0, 150, 1, 0), UDim2.new(0, 10, 0, 0), 1; lbl.Text, lbl.TextColor3, lbl.Font, lbl.TextSize, lbl.TextXAlignment = "Шаг " .. i, Color3.new(1,1,1), Enum.Font.Gotham, 12, Enum.TextXAlignment.Left
        local tpBtn = Instance.new("TextButton", item); tpBtn.Size, tpBtn.Position, tpBtn.BackgroundColor3 = UDim2.new(0, 50, 0, 25), UDim2.new(1, -100, 0, 5), Color3.fromRGB(60, 120, 200); tpBtn.Text, tpBtn.TextColor3, tpBtn.Font, tpBtn.TextSize = "ТП", Color3.new(1,1,1), Enum.Font.GothamBold, 12; Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 4)
        local delBtn = Instance.new("TextButton", item); delBtn.Size, delBtn.Position, delBtn.BackgroundColor3 = UDim2.new(0, 40, 0, 25), UDim2.new(1, -45, 0, 5), Color3.fromRGB(200, 60, 60); delBtn.Text, delBtn.TextColor3, delBtn.Font, delBtn.TextSize = "X", Color3.new(1,1,1), Enum.Font.GothamBold, 12; Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 4)

        tpBtn.MouseButton1Click:Connect(function() teleportTo(pos.X, pos.Y, pos.Z); activeChainIndex = i; drawRoute() end)
        delBtn.MouseButton1Click:Connect(function() table.remove(activeChain, i); req("save_route", activeChainName, activeChain); renderChainEditor() end)
    end
    chainList.CanvasSize = UDim2.new(0, 0, 0, #activeChain * 40)
end

local function refreshRouteList()
    for _, v in pairs(rListFrame:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
    local res = req("list_routes")
    if res then
        local s, routes = pcall(function() return HttpService:JSONDecode(res) end)
        if s and type(routes) == "table" then
            for i, rName in ipairs(routes) do
                local btn = Instance.new("TextButton", rListFrame); btn.Size, btn.BackgroundColor3 = UDim2.new(1, -10, 0, 30), Color3.fromRGB(50,50,50); btn.Text, btn.TextColor3, btn.Font, btn.TextSize = rName, Color3.new(1,1,1), Enum.Font.Gotham, 12; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                btn.MouseButton1Click:Connect(function() local loaded = req("load_route", rName); if loaded then activeChain = HttpService:JSONDecode(loaded) or {}; activeChainName, activeChainIndex = rName, 1; renderChainEditor() end end)
            end
            rListFrame.CanvasSize = UDim2.new(0, 0, 0, #routes * 35)
        end
    end
end

refreshListBtn.MouseButton1Click:Connect(refreshRouteList)
createBtn.MouseButton1Click:Connect(function() local name = newChNameInput.Text; if name ~= "" then activeChainName, activeChain, activeChainIndex = name, {}, 1; req("save_route", activeChainName, activeChain); newChNameInput.Text = ""; refreshRouteList(); renderChainEditor() end end)
chAddBtn.MouseButton1Click:Connect(function() if activeChainName and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then local p = player.Character.HumanoidRootPart.Position; table.insert(activeChain, {X = p.X, Y = p.Y, Z = p.Z}); req("save_route", activeChainName, activeChain); renderChainEditor() end end)
chNextBtn.MouseButton1Click:Connect(function() if activeChainName and #activeChain > 0 then local pos = activeChain[activeChainIndex]; teleportTo(pos.X, pos.Y, pos.Z); activeChainIndex = activeChainIndex + 1; if activeChainIndex > #activeChain then activeChainIndex = 1 end; drawRoute() end end)


-- =====================================================================
-- 🌐 WEB-HUB (ПРИЕМ КОМАНД С СЕРВЕРА)
-- =====================================================================
task.spawn(function()
    while true do
        task.wait(1.5)
        if reqFunc then
            pcall(function()
                local res = reqFunc({Url = syncUrl .. "?action=ping&name=" .. HttpService:UrlEncode(myBotName), Method = "GET"})
                if res and res.StatusCode == 200 and res.Body ~= "" then
                    local data = HttpService:JSONDecode(res.Body)
                    if data.id and data.id ~= 0 and data.id ~= lastProcessedCommandId then
                        lastProcessedCommandId = data.id
                        local isForMe = false
                        if data.targets == "All" then isForMe = true elseif type(data.targets) == "table" then for _, tName in ipairs(data.targets) do if tName == myBotName then isForMe = true; break end end end

                        if isForMe then
                            if data.type == "tp" then if data.leader ~= myBotName then teleportTo(data.x, data.y, data.z) end
                            elseif data.type == "follow" then
                                if data.leader and data.leader ~= myBotName then
                                    getgenv().fleetFollowLeader = data.leader
                                    if not getgenv().fleetFollowActive then
                                        getgenv().fleetFollowActive = true
                                        task.spawn(function()
                                            while getgenv().fleetFollowActive and getgenv().fleetFollowLeader do
                                                local lPlr = Players:FindFirstChild(getgenv().fleetFollowLeader)
                                                local mHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                                                if lPlr and lPlr.Character and lPlr.Character:FindFirstChild("HumanoidRootPart") and mHum and mHum.Health > 0 then mHum:MoveTo(lPlr.Character.HumanoidRootPart.Position) end
                                                task.wait(0.3)
                                            end
                                            getgenv().fleetFollowActive = false
                                        end)
                                    end
                                end
                            elseif data.type == "stop_follow" then getgenv().fleetFollowLeader = nil; getgenv().fleetFollowActive = false end
                        end
                    end
                end
            end)
        end
    end
end)


-- =====================================================================
-- 🚀 ИНИЦИАЛИЗАЦИЯ И ЛОГИКА АВТО-СТАРТА v10 (С ЗАДЕРЖКОЙ 30с)
-- =====================================================================
task.spawn(function()
    local resPts = req("load_points")
    if resPts then pcall(function() savedPoints = HttpService:JSONDecode(resPts) or {} end) end
    refreshPointsUI()

    local resCfg = req("load_autostart")
    if resCfg then pcall(function() autoStartConfig = HttpService:JSONDecode(resCfg) or {} end) end

    local myNick = player.Name
    local bindData = autoStartConfig[myNick]

    if type(bindData) == "table" and bindData.p1 and savedPoints[bindData.p1] then
        print(string.format("[ProCloud] АВТО-СТАРТ НАЙДЕН ДЛЯ '%s'. Ожидание прогрузки мира (30 секунд)...", myNick))
        
        -- Физическая задержка старта сценария
        task.wait(30)
        print("[ProCloud] 30 секунд истекли. Запуск автоматики...")

        if bindData.mode == "dual" and bindData.p2 and savedPoints[bindData.p2] then
            -- === СЦЕНАРИЙ: 2 ТОЧКИ ===
            print("[ProCloud-Dual] Шаг 1: ТП на точку №1 (" .. bindData.p1 .. ")")
            local pt1 = savedPoints[bindData.p1]
            teleportTo(pt1.X, pt1.Y, pt1.Z)

            task.wait(5)
            print("[ProCloud-Dual] Шаг 2: Прошло 5 сек. Жмем 'Q'")
            pressKey(Enum.KeyCode.Q)

            task.wait(5)
            print("[ProCloud-Dual] Шаг 3: Прошло 5 сек. ТП на точку №2 (" .. bindData.p2 .. ")")
            local pt2 = savedPoints[bindData.p2]
            teleportTo(pt2.X, pt2.Y, pt2.Z)

            print("[ProCloud-Dual] Шаг 4: Жмем '1' и запускаем спаммер Пробела (60с)")
            pressKey(Enum.KeyCode.One)
            toggleSpaceMode(true, 60)

        else
            -- === СЦЕНАРИЙ: 1 ТОЧКА ===
            print("[ProCloud-Single] ТП на точку (" .. bindData.p1 .. ")")
            local pt = savedPoints[bindData.p1]
            teleportTo(pt.X, pt.Y, pt.Z)

            task.wait(5)
            print("[ProCloud-Single] Прошло 5 сек. Жмем '1' и запускаем спаммер Пробела (60с)")
            pressKey(Enum.KeyCode.One)
            toggleSpaceMode(true, 60)
        end
    else
        print("[ProCloud] Персонаж " .. myNick .. " не имеет привязки к авто-старту. Свободный режим.")
    end
end)

task.spawn(function() refreshRouteList() end)

local function totalKillScript()
    getgenv().spamSpace, getgenv().spamX = false, false
    getgenv().antiAfkEnabled, getgenv().autoRejoinEnabled = false, false
    getgenv().clickTpEnabled = false
    getgenv().fleetFollowLeader = nil; getgenv().fleetFollowActive = false
    if clickTpConn then clickTpConn:Disconnect() end
    if vizFolder then vizFolder:Destroy() end
    if screenGui then screenGui:Destroy() end
end

closeBtn.MouseButton1Click:Connect(totalKillScript)
minBtnCloseAll.MouseButton1Click:Connect(totalKillScript)
