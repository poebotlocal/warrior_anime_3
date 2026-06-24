local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")


local player = Players.LocalPlayer
local getGuiParent = pcall(function() return CoreGui end) and CoreGui or player:WaitForChild("PlayerGui")


local guiName = "ProAbsoluteReaper_V7_Dome"
if getGuiParent:FindFirstChild(guiName) then getGuiParent[guiName]:Destroy() end


local screenGui = Instance.new("ScreenGui", getGuiParent)
screenGui.Name = guiName


-- Главная панель (расширена под пульт зоны)
local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 240, 0, 135)
mainFrame.Position = UDim2.new(0.5, -120, 0, 15)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
mainFrame.Active = true
mainFrame.Draggable = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 6)


-- Шапка
local titleLbl = Instance.new("TextLabel", mainFrame)
titleLbl.Size = UDim2.new(1, -35, 0, 20)
titleLbl.Position = UDim2.new(0, 10, 0, 4)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "АБСОЛЮТ v7: ГЕО-КУПОЛ"
titleLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 11
titleLbl.TextXAlignment = Enum.TextXAlignment.Left


-- Кнопка полного уничтожения
local killBtn = Instance.new("TextButton", mainFrame)
killBtn.Size = UDim2.new(0, 28, 0, 22)
killBtn.Position = UDim2.new(1, -32, 0, 4)
killBtn.BackgroundColor3 = Color3.fromRGB(100, 30, 30)
killBtn.Text = "✖"
killBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
killBtn.Font = Enum.Font.GothamBold
killBtn.TextSize = 13
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 4)


-- Кнопка АВТОФАРМ
local toggleBtn = Instance.new("TextButton", mainFrame)
toggleBtn.Size = UDim2.new(1, -16, 0, 28)
toggleBtn.Position = UDim2.new(0, 8, 0, 28)
toggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
toggleBtn.Text = "ФАРМ: ВЫКЛ"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 12
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 4)


-- Кнопка ПРИВЯЗКИ ЗОНЫ
local zoneBtn = Instance.new("TextButton", mainFrame)
zoneBtn.Size = UDim2.new(1, -16, 0, 22)
zoneBtn.Position = UDim2.new(0, 8, 0, 60)
zoneBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
zoneBtn.Text = "📍 ЗОНА: ВЕЗДЕ (OFF)"
zoneBtn.TextColor3 = Color3.new(1, 1, 1)
zoneBtn.Font = Enum.Font.GothamBold
zoneBtn.TextSize = 10
Instance.new("UICorner", zoneBtn).CornerRadius = UDim.new(0, 4)


-- ПАНЕЛЬ НАСТРОЙКИ РАДИУСА
local radMinusBtn = Instance.new("TextButton", mainFrame)
radMinusBtn.Size = UDim2.new(0, 35, 0, 20)
radMinusBtn.Position = UDim2.new(0, 8, 0, 86)
radMinusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
radMinusBtn.Text = "➖"
radMinusBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", radMinusBtn).CornerRadius = UDim.new(0, 4)


local radLbl = Instance.new("TextLabel", mainFrame)
radLbl.Size = UDim2.new(1, -86, 0, 20)
radLbl.Position = UDim2.new(0, 43, 0, 86)
radLbl.BackgroundTransparency = 1
radLbl.Text = "Радиус: 45м"
radLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
radLbl.Font = Enum.Font.GothamMedium
radLbl.TextSize = 11


local radPlusBtn = Instance.new("TextButton", mainFrame)
radPlusBtn.Size = UDim2.new(0, 35, 0, 20)
radPlusBtn.Position = UDim2.new(1, -43, 0, 86)
radPlusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
radPlusBtn.Text = "➕"
radPlusBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", radPlusBtn).CornerRadius = UDim.new(0, 4)


-- Статус
local statusLbl = Instance.new("TextLabel", mainFrame)
statusLbl.Size = UDim2.new(1, -16, 0, 18)
statusLbl.Position = UDim2.new(0, 8, 0, 110)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Статус: Ожидание команд..."
statusLbl.TextColor3 = Color3.fromRGB(140, 140, 140)
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 11




-- ==========================================
-- 🧠 ЛОГИКА ГЕО-КУПОЛА
-- ==========================================
local isFarming = false
local scriptRunning = true
local currentTarget = nil


local zoneAnchored = false
local zoneCenter = Vector3.zero
local zoneRadius = 45 -- Радиус по умолчанию
local visualRingPart = nil


-- Функция отрисовки 3D-круга на земле
local function updateVisualRing()
    if not zoneAnchored then
        if visualRingPart then visualRingPart:Destroy(); visualRingPart = nil end
        return
    end


    if not visualRingPart or not visualRingPart.Parent then
        visualRingPart = Instance.new("Part")
        visualRingPart.Name = "AbsoluteDomeVisualizer"
        visualRingPart.Shape = Enum.PartType.Cylinder
        visualRingPart.Material = Enum.Material.ForceField -- Анимированная сетка!
        visualRingPart.Color = Color3.fromRGB(0, 255, 128) -- Неоновый зеленый
        visualRingPart.Transparency = 0.6
        visualRingPart.Anchored = true
        visualRingPart.CanCollide = false
        visualRingPart.CanTouch = false
        visualRingPart.CanQuery = false
        visualRingPart.CastShadow = false
        visualRingPart.Massless = true
        visualRingPart.Parent = Workspace
    end


    -- Магия Роблокса: чтобы блин лег на землю, его ось X должна смотреть вертикально вверх
    visualRingPart.Size = Vector3.new(0.4, zoneRadius * 2, zoneRadius * 2)
    visualRingPart.CFrame = CFrame.new(zoneCenter) * CFrame.Angles(0, 0, math.rad(90))
end


-- 2D РАСЧЕТ РАССТОЯНИЯ (Без учета высоты Y!)
local function getFlatDistance(pos1, pos2)
    return math.sqrt((pos1.X - pos2.X)^2 + (pos1.Z - pos2.Z)^2)
end


local function getEnemiesFolder()
    local w = Workspace:FindFirstChild("World")
    return w and w:FindFirstChild("Enemies")
end


local function isTrueAlive(mob)
    if not mob or not mob.Parent then return false end
    if mob:GetAttribute("dead") == true then return false end
    if not mob:FindFirstChild("HumanoidRootPart") then return false end
    return true
end


local function getBestTarget()
    local folder = getEnemiesFolder()
    if not folder then return nil, false end


    local char = player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil, false end
    local myPos = myRoot.Position


    local bosses, regulars = {}, {}


    for _, mob in ipairs(folder:GetChildren()) do
        if isTrueAlive(mob) then
            local root = mob:FindFirstChild("HumanoidRootPart")
           
            -- ПРОВЕРКА ГЕО-ЗАБОРА:
            if zoneAnchored then
                local distFromAnchor = getFlatDistance(zoneCenter, root.Position)
                if distFromAnchor > zoneRadius then
                    continue -- Моб за пределами нашего круга! Игнорируем.
                end
            end


            local dist = (myPos - root.Position).Magnitude
            local isBoss = (mob:FindFirstChild("armor") == nil)


            if isBoss then table.insert(bosses, {m = mob, d = dist})
            else table.insert(regulars, {m = mob, d = dist}) end
        end
    end


    local function sortDist(a, b) return a.d < b.d end


    if #bosses > 0 then table.sort(bosses, sortDist); return bosses[1].m, true end
    if #regulars > 0 then table.sort(regulars, sortDist); return regulars[1].m, false end


    return nil, false
end


-- ГЛАВНЫЙ ПОТОК
task.spawn(function()
    while scriptRunning do
        task.wait(0.01)
        if not isFarming then continue end


        local char = player.Character
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        if not myRoot then continue end


        -- 1. Валидация текущей цели
        if currentTarget then
            if not isTrueAlive(currentTarget) then
                currentTarget = nil
            elseif zoneAnchored then
                -- Если пользователь во время фарма сузил зону кнопкой "➖" и моб выпал за забор:
                local mobRoot = currentTarget:FindFirstChild("HumanoidRootPart")
                if mobRoot and getFlatDistance(zoneCenter, mobRoot.Position) > zoneRadius then
                    currentTarget = nil
                end
            end
        end


        -- 2. Поиск
        local newTarget, bossOnMap = getBestTarget()


        if not currentTarget then
            currentTarget = newTarget
        elseif currentTarget and currentTarget:FindFirstChild("armor") ~= nil and bossOnMap then
            currentTarget = newTarget
        end


        -- 3. Атака
        if currentTarget then
            local mobRoot = currentTarget:FindFirstChild("HumanoidRootPart")
            local isBoss = (currentTarget:FindFirstChild("armor") == nil)


            if mobRoot then
                local dist = math.floor((myRoot.Position - mobRoot.Position).Magnitude)
                statusLbl.Text = string.format("%s -> %dm", (isBoss and "👑 БОСС" or "⚔️ Моб"), dist)
                statusLbl.TextColor3 = isBoss and Color3.fromRGB(255, 180, 40) or Color3.fromRGB(120, 255, 120)


                local behind = mobRoot.CFrame * CFrame.new(0, 0, 2.8)
                myRoot.CFrame = CFrame.lookAt(behind.Position, mobRoot.Position)
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
            end
        else
            statusLbl.Text = zoneAnchored and "⏳ Внутри зоны нет живых..." or "⏳ Ждем респавна на карте..."
            statusLbl.TextColor3 = Color3.fromRGB(140, 140, 160)
        end
    end
end)


-- ИНТЕРФЕЙСНЫЕ СВЯЗКИ


toggleBtn.MouseButton1Click:Connect(function()
    isFarming = not isFarming
    if isFarming then
        toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 50)
        toggleBtn.Text = "ФАРМ: ВКЛ"
    else
        toggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        toggleBtn.Text = "ФАРМ: ВЫКЛ"
        statusLbl.Text = "Пауза"
        currentTarget = nil
    end
end)


zoneBtn.MouseButton1Click:Connect(function()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end


    zoneAnchored = not zoneAnchored


    if zoneAnchored then
        -- Бросаем якорь строго под ноги персонажу
        zoneCenter = Vector3.new(root.Position.X, root.Position.Y - 2.5, root.Position.Z)
        zoneBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 180)
        zoneBtn.Text = "📍 ЗОНА: ЗАФИКСИРОВАНА"
    else
        zoneBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        zoneBtn.Text = "📍 ЗОНА: ВЕЗДЕ (OFF)"
    end
    updateVisualRing()
end)


radMinusBtn.MouseButton1Click:Connect(function()
    zoneRadius = math.max(10, zoneRadius - 5) -- Меньше 10 метров не сужаем
    radLbl.Text = "Радиус: " .. zoneRadius .. "м"
    updateVisualRing()
end)


radPlusBtn.MouseButton1Click:Connect(function()
    zoneRadius = math.min(350, zoneRadius + 5) -- Ограничитель в 350м
    radLbl.Text = "Радиус: " .. zoneRadius .. "м"
    updateVisualRing()
end)


killBtn.MouseButton1Click:Connect(function()
    scriptRunning = false
    isFarming = false
    zoneAnchored = false
    updateVisualRing()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
    end
    screenGui:Destroy()
end)
