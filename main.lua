local love = require("love")
local json = require("json") -- Assuming a JSON library is available

-- Game states
local GameState = {
    MAIN_MENU = "main_menu",
    PLAYING = "playing",
    PAUSED = "paused",
    GAME_OVER = "game_over",
    UPGRADE_MENU = "upgrade_menu"
}

local font

function love.load()
    love.window.setTitle("Cat Paw Ball Game")

    -- Initialize font
    font = love.graphics.newFont(14)
    love.graphics.setFont(font)

    -- Initialize default values for score, bestScore, money, and speedMultiplier
    score = 0
    bestScore = 0
    money = 0
    speedMultiplier = 1  -- Default value for speedMultiplier

    -- Load assets
    background = love.graphics.newImage("assets/background.jpg")
    pawImage = love.graphics.newImage("assets/paw.png")

    -- Screen setup
    screenWidth, screenHeight = love.graphics.getDimensions()
    bgScaleX = screenWidth / background:getWidth()
    bgScaleY = screenHeight / background:getHeight()

    -- Initialize game state
    gameState = GameState.MAIN_MENU

    -- Load saved game data
    loadGameData()

    -- Ball properties (ensure it's initialized with default values)
    ball = ball or { 
        x = screenWidth / 2, 
        y = screenHeight / 3, 
        radius = 15,  -- Set default radius here
        speedX = 200, 
        speedY = 200 
    }

    -- Paw properties (ensure paw objects are initialized)
    pawWidth = pawImage:getWidth() * 0.5
    pawHeight = pawImage:getHeight() * 0.5
    leftPaw = leftPaw or { x = screenWidth / 4 - pawWidth / 2, y = screenHeight - 100, width = pawWidth, height = pawHeight }
    rightPaw = rightPaw or { x = 3 * screenWidth / 4 - pawWidth / 2, y = screenHeight - 100, width = pawWidth, height = pawHeight }

    -- Load upgrades with balanced initial costs
    upgrades = upgrades or {
        goldenChance = { level = 0, cost = 25, maxLevel = 10, increment = 15 },
        ballSpeed = { level = 0, cost = 20, maxLevel = 10, increment = 10 },
        pawSpeed = { level = 0, cost = 30, maxLevel = 10, increment = 20 },
        moneyMultiplier = { level = 0, cost = 50, maxLevel = 5, increment = 40 }
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
        local moneyMultiplier = 1 + (upgrades.moneyMultiplier.level * 0.5)
        local earnedMoney = math.floor(baseAmount * moneyMultiplier)
        
        money = money + earnedMoney
        score = score + 1

        if score > bestScore then
            bestScore = score
            saveGameData()
        end
        saveGameData()
    end

    -- Game over condition
    if ball.y > screenHeight then
        gameState = GameState.GAME_OVER
        saveGameData()
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
    elseif key == "return" and gameState == GameState.MAIN_MENU then
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
    elseif gameState == GameState.MAIN_MENU then
        drawMainMenu()
    end
end

function drawMainMenu()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Cat Paw Ball Game\nPress Enter to Start\nPress ESC to Quit", 0, screenHeight / 2 - 40, screenWidth, "center")
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

-- Function to handle collisions
function checkCollision(ball, paw)
    return ball.x + ball.radius > paw.x and ball.x - ball.radius < paw.x + paw.width and
           ball.y + ball.radius > paw.y and ball.y - ball.radius < paw.y + paw.height
end

function drawPauseScreen()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Game Paused\nPress ESC to Resume", 0, screenHeight / 2 - 40, screenWidth, "center")
end

function drawGameOverScreen()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Game Over\nPress Enter to Restart", 0, screenHeight / 2 - 40, screenWidth, "center")
end

function drawUpgradeMenu()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Upgrade Menu\nPress ESC to Go Back", 0, screenHeight / 2 - 80, screenWidth, "center")
    -- Drawing upgrades
    local yPosition = screenHeight / 2
    for upgrade, data in pairs(upgrades) do
        love.graphics.print(upgrade .. " Level: " .. data.level .. " Cost: $" .. data.cost, 10, yPosition)
        yPosition = yPosition + 20
    end
end

-- Saving and loading data
function saveGameData()
    local gameData = {
        ball = { x = ball.x, y = ball.y, speedX = ball.speedX, speedY = ball.speedY },
        leftPaw = leftPaw,
        rightPaw = rightPaw,
        upgrades = upgrades,
        score = score,
        bestScore = bestScore,
        money = money
    }
    local gameDataJSON = json.encode(gameData)
    love.filesystem.write("gameData.json", gameDataJSON)
end

function loadGameData()
    if love.filesystem.exists("gameData.json") then
        local gameDataJSON = love.filesystem.read("gameData.json")
        local gameData = json.decode(gameDataJSON)
        if gameData then
            ball = gameData.ball or ball
            leftPaw = gameData.leftPaw or leftPaw
            rightPaw = gameData.rightPaw or rightPaw
            upgrades = gameData.upgrades or upgrades
            score = gameData.score or score
            bestScore = gameData.bestScore or bestScore
            money = gameData.money or money
        end
    end
end
