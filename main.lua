local love = require("love")

-- Game states
local GameState = {
    PLAYING = "playing",
    PAUSED = "paused",
    GAME_OVER = "game_over",
    UPGRADE_MENU = "upgrade_menu"
}

function love.load()
    love.window.setTitle("Cat Paw Ball Game")

    -- Load assets
    background = love.graphics.newImage("assets/background.jpg")
    pawImage = love.graphics.newImage("assets/paw.png")

    -- Screen setup
    screenWidth, screenHeight = love.graphics.getDimensions()
    bgScaleX = screenWidth / background:getWidth()
    bgScaleY = screenHeight / background:getHeight()

    -- Initialize game state
    gameState = GameState.PLAYING
    
    -- Ball properties
    ball = { x = screenWidth / 2, y = screenHeight / 3, radius = 15, speedX = 200, speedY = 200 }

    -- Paw properties
    pawWidth = pawImage:getWidth() * 0.5
    pawHeight = pawImage:getHeight() * 0.5
    leftPaw = { x = screenWidth / 4 - pawWidth / 2, y = screenHeight - 100, width = pawWidth, height = pawHeight }
    rightPaw = { x = 3 * screenWidth / 4 - pawWidth / 2, y = screenHeight - 100, width = pawWidth, height = pawHeight }

    -- Score and currency
    score = 0
    money = loadMoney()
    bestScore = loadBestScore()

    -- Ball modifiers
    speedMultiplier = 1.0
    isGolden = false
    goldenTimer = 0
    goldenDuration = 10
    goldenChance = 0.05 -- 5% base chance

    -- Load upgrades with balanced initial costs
    upgrades = loadUpgrades() or {
        goldenChance = { level = 0, cost = 25, maxLevel = 10, increment = 15 },  -- Starts cheap, +15 per level
        ballSpeed = { level = 0, cost = 20, maxLevel = 10, increment = 10 },     -- Easiest to get, +10 per level
        pawSpeed = { level = 0, cost = 30, maxLevel = 10, increment = 20 },      -- Medium price, +20 per level
        moneyMultiplier = { level = 0, cost = 50, maxLevel = 5, increment = 40 } -- Most expensive, +40 per level
    }
end

function love.update(dt)
    if gameState == GameState.PLAYING then
        updateGame(dt)
    end
end

function updateGame(dt)
    -- Update golden ball timer
    if isGolden then
        goldenTimer = goldenTimer - dt
        if goldenTimer <= 0 then
            isGolden = false
        end
    end

    -- Calculate actual speeds based on upgrades
    local currentBallSpeedMultiplier = speedMultiplier * (1 - (upgrades.ballSpeed.level * 0.01))
    local pawSpeedMultiplier = 1 + (upgrades.pawSpeed.level * 0.01)
    local baseSpeed = 300 * pawSpeedMultiplier

    -- Ball movement
    ball.x = ball.x + ball.speedX * dt * currentBallSpeedMultiplier
    ball.y = ball.y + ball.speedY * dt * currentBallSpeedMultiplier

    -- Ball bouncing off walls
    if ball.x - ball.radius < 0 or ball.x + ball.radius > screenWidth then
        ball.speedX = -ball.speedX
    end
    if ball.y - ball.radius < 0 then
        ball.speedY = -ball.speedY
    end

    -- Paw controls with upgraded speed
    if love.keyboard.isDown("a") then
        leftPaw.x = math.max(0, leftPaw.x - baseSpeed * dt)
    elseif love.keyboard.isDown("d") then
        leftPaw.x = math.min(screenWidth - leftPaw.width, leftPaw.x + baseSpeed * dt)
    end

    if love.keyboard.isDown("left") then
        rightPaw.x = math.max(0, rightPaw.x - baseSpeed * dt)
    elseif love.keyboard.isDown("right") then
        rightPaw.x = math.min(screenWidth - rightPaw.width, rightPaw.x + baseSpeed * dt)
    end

    -- Ball collision with paws
    if checkCollision(ball, leftPaw) or checkCollision(ball, rightPaw) then
        ball.speedY = -ball.speedY
        ball.y = ball.y - ball.radius

        speedMultiplier = speedMultiplier * 1.0001

        -- Check for golden ball with upgraded chance
        local currentGoldenChance = 0.05 + (upgrades.goldenChance.level * 0.05)
        if math.random() < currentGoldenChance then
            isGolden = true
            goldenTimer = goldenDuration
        end

        -- Calculate money earned with multiplier
        local baseAmount = isGolden and 4 or 2
        local moneyMultiplier = 1 + (upgrades.moneyMultiplier.level * 0.5) -- +50% per level
        local earnedMoney = math.floor(baseAmount * moneyMultiplier)
        
        money = money + earnedMoney
        score = score + 1

        if score > bestScore then
            bestScore = score
            saveBestScore(bestScore)
        end
        saveMoney(money)
    end

    -- Game over condition
    if ball.y > screenHeight then
        gameState = GameState.GAME_OVER
        saveBestScore(bestScore)
        saveMoney(money)
        saveUpgrades(upgrades)
    end
end

function love.keypressed(key)
    if key == "escape" then
        if gameState == GameState.PLAYING then
            gameState = GameState.PAUSED
        elseif gameState == GameState.PAUSED then
            gameState = GameState.PLAYING
        end
    elseif key == "u" then
        if gameState == GameState.PLAYING then
            gameState = GameState.UPGRADE_MENU
        elseif gameState == GameState.UPGRADE_MENU then
            gameState = GameState.PLAYING
        end
    elseif key == "return" and gameState == GameState.GAME_OVER then
        love.load()
        gameState = GameState.PLAYING
    end
end

function love.draw()
    -- Draw background and game elements
    love.graphics.draw(background, 0, 0, 0, bgScaleX, bgScaleY)
    love.graphics.draw(pawImage, leftPaw.x, leftPaw.y, 0, 0.5, 0.5)
    love.graphics.draw(pawImage, rightPaw.x, rightPaw.y, 0, 0.5, 0.5)

    -- Draw ball
    if isGolden then
        love.graphics.setColor(1, 0.84, 0)
    else
        love.graphics.setColor(1, 1, 1)
    end
    love.graphics.circle("fill", ball.x, ball.y, ball.radius)
    love.graphics.setColor(1, 1, 1)

    -- Draw UI
    drawUI()

    -- Draw state-specific screens
    if gameState == GameState.PAUSED then
        drawPauseScreen()
    elseif gameState == GameState.GAME_OVER then
        drawGameOverScreen()
    elseif gameState == GameState.UPGRADE_MENU then
        drawUpgradeMenu()
    end
end

function drawUI()
    -- Draw basic stats
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 5, 5, 200, 100)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Score: " .. score, 10, 10)
    love.graphics.print("Best Score: " .. bestScore, 10, 30)
    love.graphics.print("Money: $" .. money, 10, 50)
    if isGolden then
        love.graphics.print("Golden Ball Active!", 10, 70)
    end
end

function drawPauseScreen()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("GAME PAUSED\nPress ESC to resume\nPress U for upgrades", 0, screenHeight/2 - 40, screenWidth, "center")
end

function drawGameOverScreen()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("GAME OVER\nFinal Score: " .. score .. "\nBest Score: " .. bestScore .. "\nPress ENTER to restart", 0, screenHeight/2 - 60, screenWidth, "center")
end

function drawUpgradeMenu()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    love.graphics.setColor(1, 1, 1)
    
    local menuWidth = 400
    local menuX = (screenWidth - menuWidth) / 2
    local startY = 100
    
    love.graphics.printf("UPGRADES (Press U to return)", 0, startY, screenWidth, "center")
    love.graphics.printf("Current Money: $" .. money, 0, startY + 40, screenWidth, "center")
    
    -- Draw upgrade options with detailed information
    drawUpgradeOption("Golden Ball Chance", upgrades.goldenChance, startY + 100, "+5% chance", "Next level: " .. (0.05 + upgrades.goldenChance.level * 0.05) * 100 .. "%")
    drawUpgradeOption("Ball Speed Reduction", upgrades.ballSpeed, startY + 160, "-1% speed", "Current reduction: " .. (upgrades.ballSpeed.level) .. "%")
    drawUpgradeOption("Paw Speed", upgrades.pawSpeed, startY + 220, "+1% speed", "Current boost: +" .. (upgrades.pawSpeed.level) .. "%")
    drawUpgradeOption("Money Multiplier", upgrades.moneyMultiplier, startY + 280, "+50% money", "Current: x" .. string.format("%.1f", (1 + upgrades.moneyMultiplier.level * 0.5)))
end

function drawUpgradeOption(name, upgrade, y, effect, currentEffect)
    local text = string.format("%s (Level %d/%d)\nCost: $%d %s\n%s", 
        name, upgrade.level, upgrade.maxLevel, upgrade.cost, effect, currentEffect)
    love.graphics.printf(text, 0, y, screenWidth, "center")
end

function love.mousepressed(x, y, button)
    if gameState == GameState.UPGRADE_MENU and button == 1 then
        handleUpgradeClick(x, y)
    end
end

function handleUpgradeClick(x, y)
    local startY = 100
    
    if y >= startY + 100 and y < startY + 140 then
        purchaseUpgrade("goldenChance")
    elseif y >= startY + 160 and y < startY + 200 then
        purchaseUpgrade("ballSpeed")
    elseif y >= startY + 220 and y < startY + 260 then
        purchaseUpgrade("pawSpeed")
    elseif y >= startY + 280 and y < startY + 320 then
        purchaseUpgrade("moneyMultiplier")
    end
end

function purchaseUpgrade(type)
    local upgrade = upgrades[type]
    if upgrade.level < upgrade.maxLevel and money >= upgrade.cost then
        money = money - upgrade.cost
        upgrade.level = upgrade.level + 1
        upgrade.cost = upgrade.cost + upgrade.increment
        saveMoney(money)
        saveUpgrades(upgrades)
    end
end

function saveUpgrades(upgrades)
    local path = love.filesystem.getAppdataDirectory() .. "/CatGame/upgrades.txt"
    love.filesystem.createDirectory("CatGame")
    local serialized = ""
    for name, upgrade in pairs(upgrades) do
        serialized = serialized .. string.format("%s:%d:%d:%d:%d\n", 
            name, upgrade.level, upgrade.cost, upgrade.maxLevel, upgrade.increment)
    end
    love.filesystem.write(path, serialized)
end

function loadUpgrades()
    local path = love.filesystem.getAppdataDirectory() .. "/CatGame/upgrades.txt"
    if love.filesystem.getInfo(path) then
        local content = love.filesystem.read(path)
        local upgrades = {}
        for line in content:gmatch("[^\r\n]+") do
            local name, level, cost, maxLevel, increment = line:match("([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)")
            upgrades[name] = {
                level = tonumber(level),
                cost = tonumber(cost),
                maxLevel = tonumber(maxLevel),
                increment = tonumber(increment)
            }
        end
        return upgrades
    end
    return nil
end

function saveMoney(money)
    local path = love.filesystem.getAppdataDirectory() .. "/CatGame/money.txt"
    love.filesystem.createDirectory("CatGame")
    love.filesystem.write(path, tostring(money))
end

function loadMoney()
    local path = love.filesystem.getAppdataDirectory() .. "/CatGame/money.txt"
    if love.filesystem.getInfo(path) then
        local file = love.filesystem.read(path)
        return tonumber(file) or 0
    end
    return 0
end

function loadBestScore()
    local path = love.filesystem.getAppdataDirectory() .. "/CatGame/best_score.txt"
    if love.filesystem.getInfo(path) then
        local file = love.filesystem.read(path)
        return tonumber(file) or 0
    end
    return 0
end

function saveBestScore(score)
    local path = love.filesystem.getAppdataDirectory() .. "/CatGame/best_score.txt"
    love.filesystem.createDirectory("CatGame")
    love.filesystem.write(path, tostring(score))
end

function checkCollision(ball, paw)
    local ballLeft = ball.x - ball.radius
    local ballRight = ball.x + ball.radius
    local ballTop = ball.y - ball.radius
    local ballBottom = ball.y + ball.radius

    local pawLeft = paw.x
    local pawRight = paw.x + paw.width
    local pawTop = paw.y
    local pawBottom = paw.y + paw.height

    return ballRight > pawLeft and ballLeft < pawRight and
           ballBottom > pawTop and ballTop < pawBottom
end