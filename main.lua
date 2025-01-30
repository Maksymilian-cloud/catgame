-- Load required libraries
local love = require("love")

function love.load()
    love.window.setTitle("Cat Paw Ball Game")

    -- Load assets
    background = love.graphics.newImage("assets/background.jpg") -- background.jpg instead of .png
    pawImage = love.graphics.newImage("assets/paw.png")

    -- Resize background to fit screen
    screenWidth, screenHeight = love.graphics.getDimensions()
    bgScaleX = screenWidth / background:getWidth()
    bgScaleY = screenHeight / background:getHeight()

    -- Ball properties
    ball = { x = screenWidth / 2, y = screenHeight / 3, radius = 15, speedX = 200, speedY = 200 }

    -- Paw properties (50% smaller paws, positioned correctly)
    pawWidth = pawImage:getWidth() * 0.5
    pawHeight = pawImage:getHeight() * 0.5

    leftPaw = { x = screenWidth / 4 - pawWidth / 2, y = screenHeight - 100, width = pawWidth, height = pawHeight }
    rightPaw = { x = 3 * screenWidth / 4 - pawWidth / 2, y = screenHeight - 100, width = pawWidth, height = pawHeight }

    -- Score tracking
    score = 0
    bestScore = loadBestScore()

    -- Ball speed increase multiplier
    speedMultiplier = 1.0
end

function love.update(dt)
    -- Ball movement
    ball.x = ball.x + ball.speedX * dt * speedMultiplier
    ball.y = ball.y + ball.speedY * dt * speedMultiplier

    -- Ball bouncing off walls
    if ball.x - ball.radius < 0 or ball.x + ball.radius > love.graphics.getWidth() then
        ball.speedX = -ball.speedX
    end
    if ball.y - ball.radius < 0 then
        ball.speedY = -ball.speedY
    end

    -- Left Paw Controls (A & D)
    if love.keyboard.isDown("a") then
        leftPaw.x = math.max(0, leftPaw.x - 300 * dt)
    elseif love.keyboard.isDown("d") then
        leftPaw.x = math.min(screenWidth - leftPaw.width, leftPaw.x + 300 * dt)
    end

    -- Right Paw Controls (Left & Right Arrow)
    if love.keyboard.isDown("left") then
        rightPaw.x = math.max(0, rightPaw.x - 300 * dt)
    elseif love.keyboard.isDown("right") then
        rightPaw.x = math.min(screenWidth - rightPaw.width, rightPaw.x + 300 * dt)
    end

    -- Ball collision with paws
    if checkCollision(ball, leftPaw) or checkCollision(ball, rightPaw) then
        ball.speedY = -ball.speedY
        ball.y = ball.y - ball.radius -- Slightly adjust position after collision to avoid bouncing in the air
        
        -- Increase speed slightly and update score
        speedMultiplier = speedMultiplier * 1.0001
        score = score + 1
        if score > bestScore then
            bestScore = score
            saveBestScore(bestScore)
        end
    end

    -- Ball falls off the screen (Game Over)
    if ball.y > love.graphics.getHeight() then
        -- Game over, reset the game
        saveBestScore(bestScore) -- Save best score
        love.load() -- Restart game
    end
end

function love.draw()
    love.graphics.draw(background, 0, 0, 0, bgScaleX, bgScaleY) -- Draw resized background
    love.graphics.draw(pawImage, leftPaw.x, leftPaw.y, 0, 0.5, 0.5) -- Draw left paw (50% smaller)
    love.graphics.draw(pawImage, rightPaw.x, rightPaw.y, 0, 0.5, 0.5) -- Draw right paw (50% smaller)
    love.graphics.circle("fill", ball.x, ball.y, ball.radius) -- Draw ball

    -- Draw score
    love.graphics.setColor(1, 1, 1) -- Reset color to white
    love.graphics.print("Score: " .. score, 10, 10)
    love.graphics.print("Best Score: " .. bestScore, 10, 30)
end

-- Collision detection
function checkCollision(ball, paw)
    local ballLeft = ball.x - ball.radius
    local ballRight = ball.x + ball.radius
    local ballTop = ball.y - ball.radius
    local ballBottom = ball.y + ball.radius

    local pawLeft = paw.x
    local pawRight = paw.x + paw.width
    local pawTop = paw.y
    local pawBottom = paw.y + paw.height

    -- Check if ball is overlapping with paw
    return ballRight > pawLeft and ballLeft < pawRight and
           ballBottom > pawTop and ballTop < pawBottom
end

-- Load best score from file
function loadBestScore()
    local path = love.filesystem.getAppdataDirectory() .. "/CatGame/best_score.txt"
    local bestScore = 0
    if love.filesystem.getInfo(path) then
        local file = love.filesystem.read(path)
        bestScore = tonumber(file) or 0
    end
    return bestScore
end

-- Save best score to file
function saveBestScore(score)
    local path = love.filesystem.getAppdataDirectory() .. "/CatGame/best_score.txt"
    love.filesystem.createDirectory("CatGame") -- Ensure the directory exists
    love.filesystem.write(path, tostring(score))
end
