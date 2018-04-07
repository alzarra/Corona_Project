
local composer = require( "composer" )

local scene = composer.newScene()

-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------

local physics = require( "physics" )
physics.start()
physics.setGravity( 0, 0 )

-- Configure image sheet
local sheetOptions =
{
    frames =
    {
        {   -- 1) asteroid 1
            x = 0,
            y = 0,
            width = 102,
            height = 85
        },
        {   -- 2) asteroid 2
            x = 0,
            y = 85,
            width = 90,
            height = 83
        },
        {   -- 3) asteroid 3
            x = 0,
            y = 168,
            width = 100,
            height = 97
        },
        {   -- 4) ship
            x = 0,
            y = 265,
            width = 98,
            height = 79
        },
        {   -- 5) laser
            x = 98,
            y = 265,
            width = 14,
            height = 40
        },
    },
}
local objectSheet = graphics.newImageSheet( "gameObjects.png", sheetOptions )

-- Initialize variables
local lives = 3
local score = 0
local died = false

local asteroidsTable = {}

local ship
local gameLoopTimer
local livesText
local scoreText

local backGroup
local mainGroup
local uiGroup

local explosionSound
local fireSound
local musicTrack


local function updateText()
	livesText.text = "Lives: " .. lives
	scoreText.text = "Score: " .. score
end


local function createAsteroid()

	local newAsteroid
	ofs = math.random(3)
	
	-- Asteroid type 1, white
	if ( ofs == 1 ) then
		newAsteroid = display.newImageRect( mainGroup, objectSheet, 1, 102, 85 )
		table.insert( asteroidsTable, newAsteroid )
		physics.addBody( newAsteroid, "dynamic", { radius=40, bounce=0.8 } )
		newAsteroid.hp = 1
		newAsteroid.myName = "asteroid1"
	-- Asteroid type 2, red
	elseif ( ofs == 2 ) then
		newAsteroid = display.newImageRect( mainGroup, objectSheet, 2, 102, 85 )
		table.insert( asteroidsTable, newAsteroid )
		physics.addBody( newAsteroid, "dynamic", { radius=40, bounce=0.8 } )
		newAsteroid.hp = 2
		newAsteroid.myName = "asteroid2"
	-- Asteroid type 3, brown
	elseif ( ofs == 3 ) then
		newAsteroid = display.newImageRect( mainGroup, objectSheet, 3, 102, 85 )
		table.insert( asteroidsTable, newAsteroid )
		physics.addBody( newAsteroid, "dynamic", { radius=40, bounce=0.8 } )
		newAsteroid.hp = 3
		newAsteroid.myName = "asteroid3"
	end
	

	
	local whereFrom = math.random( 3 )

	if ( whereFrom == 1 ) then
		-- From the left
		newAsteroid.x = -60
		newAsteroid.y = math.random( 500 )
		newAsteroid:setLinearVelocity( math.random( 40,120 ), math.random( 20,60 ) )
	elseif ( whereFrom == 2 ) then
		-- From the top
		newAsteroid.x = math.random( display.contentWidth )
		newAsteroid.y = -60
		newAsteroid:setLinearVelocity( math.random( -40,40 ), math.random( 40,120 ) )
	elseif ( whereFrom == 3 ) then
		-- From the right
		newAsteroid.x = display.contentWidth + 60
		newAsteroid.y = math.random( 500 )
		newAsteroid:setLinearVelocity( math.random( -120,-40 ), math.random( 20,60 ) )
	end

	newAsteroid:applyTorque( math.random( -6,6 ) )
end


local function fireLaser()

	-- Play fire sound!
	audio.play( fireSound )

	local newLaser = display.newImageRect( mainGroup, objectSheet, 5, 14, 40 )
	physics.addBody( newLaser, "dynamic", { isSensor=true } )
	newLaser.isBullet = true
	newLaser.myName = "laser"

	newLaser.x = ship.x
	newLaser.y = ship.y
	newLaser:toBack()

	transition.to( newLaser, { y=-40, time=500,
		onComplete = function() display.remove( newLaser ) end
	} )
end


local function dragShip( event )

	local ship = event.target
	local phase = event.phase

	if ( "began" == phase ) then
		-- Set touch focus on the ship
		display.currentStage:setFocus( ship )
		-- Store initial offset position
		ship.touchOffsetX = event.x - ship.x
		ship.touchOffsetX = event.y - ship.y


	elseif ( "moved" == phase ) then
		-- Move the ship to the new touch position
		ship.x = event.x - ship.touchOffsetX
		ship.y = event.y - ship.touchOffsetX
		

	elseif ( "ended" == phase or "cancelled" == phase ) then
		-- Release touch focus on the ship
		display.currentStage:setFocus( nil )
	end

	return true  -- Prevents touch propagation to underlying objects
end

	

local function gameLoop()

	-- Create new asteroid
	createAsteroid()

	-- Remove asteroids which have drifted off screen
	for i = #asteroidsTable, 1, -1 do
		local thisAsteroid = asteroidsTable[i]

		if ( thisAsteroid.x < -100 or
			 thisAsteroid.x > display.contentWidth + 100 or
			 thisAsteroid.y < -100 or
			 thisAsteroid.y > display.contentHeight + 100 )
		then
			display.remove( thisAsteroid )
			table.remove( asteroidsTable, i )
		end
	end
end


local function restoreShip()

	ship.isBodyActive = false
	ship.x = display.contentCenterX
	ship.y = display.contentHeight - 100

	-- Fade in the ship
	transition.to( ship, { alpha=1, time=4000,
		onComplete = function()
			ship.isBodyActive = true
			died = false
		end
	} )
end


local function endGame()
	composer.setVariable( "finalScore", score )
	composer.gotoScene( "highscores", { time=800, effect="crossFade" } )

end


local function onCollision( event )

	if ( event.phase == "began" ) then

		local obj1 = event.object1
		local obj2 = event.object2
		
		--Shooting Asteroid type 1, white
		if ( ( obj1.myName == "laser" and obj2.myName == "asteroid1" ) or
			 ( obj1.myName == "asteroid1" and obj2.myName == "laser" ) )
		then
			--Reduces Asteroid HP and removes laser
			obj2.hp = obj2.hp - 1
			display.remove( obj1 )
			
			if ( obj2.hp == 0) then
				--Updates score and removes asteroid
				score = score + 100
				scoreText.text = "Score: " .. score
				display.remove( obj2 )

				-- Play explosion sound!
				audio.play( explosionSound )

				for i = #asteroidsTable, 1, -1 do
					if ( asteroidsTable[i] == obj1 or asteroidsTable[i] == obj2 ) then
						table.remove( asteroidsTable, i )
						break
					end
				end
			end

		--Shooting Asteroid type 2, red
		elseif ( ( obj1.myName == "laser" and obj2.myName == "asteroid2" ) or
			 ( obj1.myName == "asteroid2" and obj2.myName == "laser" ) )
		then
			--Reduces Asteroid HP and removes laser
			obj2.hp = obj2.hp - 1
			display.remove( obj1 )
			
			if ( obj2.hp == 0) then
				--Updates score and removes asteroid
				score = score + 200
				scoreText.text = "Score: " .. score
				display.remove( obj2 )

				-- Play explosion sound!
				audio.play( explosionSound )

				for i = #asteroidsTable, 1, -1 do
					if ( asteroidsTable[i] == obj1 or asteroidsTable[i] == obj2 ) then
						table.remove( asteroidsTable, i )
						break
					end
				end
			end
			
		--Shooting Asteroid type 3, brown
		elseif ( ( obj1.myName == "laser" and obj2.myName == "asteroid3" ) or
			 ( obj1.myName == "asteroid3" and obj2.myName == "laser" ) )
		then
			--Reduces Asteroid HP and removes laser
			obj2.hp = obj2.hp - 1
			display.remove( obj1 )
			
			if ( obj2.hp == 0) then
				--Updates score and removes asteroid
				score = score + 300
				scoreText.text = "Score: " .. score
				display.remove( obj2 )

				-- Play explosion sound!
				audio.play( explosionSound )

				for i = #asteroidsTable, 1, -1 do
					if ( asteroidsTable[i] == obj1 or asteroidsTable[i] == obj2 ) then
						table.remove( asteroidsTable, i )
						break
					end
				end
			end

		--Ship collision with asteroid
		elseif ( ( obj1.myName == "ship" and obj2.myName == "asteroid1" ) or
				 ( obj1.myName == "asteroid1" and obj2.myName == "ship" ) or
				 ( obj1.myName == "ship" and obj2.myName == "asteroid2" ) or
				 ( obj1.myName == "asteroid2" and obj2.myName == "ship" ) or 
				 ( obj1.myName == "ship" and obj2.myName == "asteroid3" ) or
				 ( obj1.myName == "asteroid3" and obj2.myName == "ship" ) )
		then
			if ( died == false ) then
				died = true

				-- Play explosion sound!
				audio.play( explosionSound )

				-- Update lives
				lives = lives - 1
				livesText.text = "Lives: " .. lives

				if ( lives == 0 ) then
					display.remove( ship )
					timer.performWithDelay( 2000, endGame )
				else
					ship.alpha = 0
					timer.performWithDelay( 1000, restoreShip )
				end
			end
		end
	end
end


-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )

	local sceneGroup = self.view
	-- Code here runs when the scene is first created but has not yet appeared on screen

	physics.pause()  -- Temporarily pause the physics engine

	-- Set up display groups
	backGroup = display.newGroup()  -- Display group for the background image
	sceneGroup:insert( backGroup )  -- Insert into the scene's view group

	mainGroup = display.newGroup()  -- Display group for the ship, asteroids, lasers, etc.
	sceneGroup:insert( mainGroup )  -- Insert into the scene's view group

	uiGroup = display.newGroup()    -- Display group for UI objects like the score
	sceneGroup:insert( uiGroup )    -- Insert into the scene's view group
	
	
	
	-- Set Variables
	_W = display.contentWidth; -- Get the width of the screen
	_H = display.contentHeight; -- Get the height of the screen
	--print (_H);
	scrollSpeed = 2; -- Set Scroll Speed of background
	-- Load the background
	-- Add First Background
	local bg1 = display.newImageRect(backGroup, "bg1.png", 768, 1024)
	bg1.x = _W*0.5; bg1.y = _H/2;
 
	-- Add Second Background
	local bg2 = display.newImageRect(backGroup, "bg1.png", 768, 1024)
	bg2.x = _W*0.5; bg2.y = bg1.y+1024;
	 
	-- Add Third Background
	local bg3 = display.newImageRect(backGroup, "bg1.png", 768, 1024)
	bg3.x = _W*0.5; bg3.y = bg2.y+1024;

	local function move(event) 
	 -- move backgrounds to the left by scrollSpeed, default is 2
	 if(lives == 0) then return end
	 bg1.y = bg1.y + scrollSpeed;
	 bg2.y = bg2.y + scrollSpeed;
	 bg3.y = bg3.y + scrollSpeed;
	 
	 -- Set up listeners so when backgrounds hits a certain point off the screen,
	 -- move the background to the right off screen
	 if (bg1.y + bg1.contentWidth) > 2304 then
	  bg1:translate( 0, -2224 )
	 end
	 if (bg2.y + bg2.contentWidth) > 2304 then
	  bg2:translate( 0, -2224 )
	 end
	 if (bg3.y + bg3.contentWidth) > 2304 then
	  bg3:translate( 0, -2224 )
	 end
	end

	-- Create a runtime event to move backgrounds
	Runtime:addEventListener( "enterFrame", move )
	
	
	
	
	
	
	
	ship = display.newImageRect( mainGroup, objectSheet, 4, 98, 79 )
	ship.x = display.contentCenterX
	ship.y = display.contentHeight - 100
	physics.addBody( ship, { radius=30, isSensor=true } )
	ship.myName = "ship"

	-- Display lives and score
	livesText = display.newText( uiGroup, "Lives: " .. lives, 200, 80, native.systemFont, 36 )
	scoreText = display.newText( uiGroup, "Score: " .. score, 400, 80, native.systemFont, 36 )

	ship:addEventListener( "tap", fireLaser )
	ship:addEventListener( "touch", dragShip )

	explosionSound = audio.loadSound( "audio/explosion.mp3" )
	fireSound = audio.loadSound( "audio/fire.mp3" )
	musicTrack = audio.loadStream( "audio/80s-Space-Game_Looping.mp3" )
end


-- show()
function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is still off screen (but is about to come on screen)

	elseif ( phase == "did" ) then
		-- Code here runs when the scene is entirely on screen
		physics.start()
		Runtime:addEventListener( "collision", onCollision )
		gameLoopTimer = timer.performWithDelay( 500, gameLoop, 0 )
		-- Start the music!
		audio.play( musicTrack, { channel=1, loops=-1 } )
	end
end


-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)
		timer.cancel( gameLoopTimer )

	elseif ( phase == "did" ) then
		-- Code here runs immediately after the scene goes entirely off screen
		Runtime:removeEventListener( "collision", onCollision )
		physics.pause()
		-- Stop the music!
		audio.stop( 1 )
		composer.removeScene( "game" )
	end
end


-- destroy()
function scene:destroy( event )

	local sceneGroup = self.view
	-- Code here runs prior to the removal of scene's view
	-- Dispose audio!
	audio.dispose( explosionSound )
	audio.dispose( fireSound )
	audio.dispose( musicTrack )
end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene
