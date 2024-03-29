-----------------------------------------------------
-- INFO
-----------------------------------------------------


script_name("Carjacker Reminder by Bear")
script_author("Bear")
script_version("1.0.6")


-----------------------------------------------------
-- HEADERS & CONFIG
-----------------------------------------------------


local sampev = require "lib.samp.events"
local inicfg = require "inicfg"

local config_dir_path = getWorkingDirectory() .. "\\config\\"
if not doesDirectoryExist(config_dir_path) then createDirectory(config_dir_path) end

local config_file_path = config_dir_path .. "Carjacker Reminder by Bear.ini"

config_dir_path = nil

local config_table

if doesFileExist(config_file_path) then
	config_table = inicfg.load(nil, config_file_path)
else
	local new_config = io.open(config_file_path, "w")
	new_config:close()
	new_config = nil
	
	config_table = {Options = {isReminderEnabled = true}}

	if not inicfg.save(config_table, config_file_path) then
		sampAddChatMessage("---- {AAAAFF}Carjacker Reminder: {FFFFFF}Config file creation failed - contact the developer for help.", -1)
	end
end


-----------------------------------------------------
-- GLOBAL VARIABLES
-----------------------------------------------------


local reminderMessage = "/SELLCAR" -- Use "\t" for spaces; using regular spaces creates line changes

local textSize = 0.75 -- Adjust text size here

local pulseFrequency = 60 -- in seconds

local pulseCount = 2 -- how many times the textdraw pulses each time the above amount of time has passed

local pulseDuration = 1000 -- the time taken (in milliseconds) for the textdraw to pilse once (by switching appearance twice)

local game_resX, game_resY

local isCommandResponseAwaited, isCarjackerGameTextIntercepted, isCommandAttemptRedundant = false, false, false
local isSellingAvailable, isKCPRequested = false, false
local hasFirstCharacterLoginOccured, hasNonfirstCharacterLoginOccured = false, false
local isPlayerMuted = false


-----------------------------------------------------
-- API-SPECIFIC FUNCTIONS
-----------------------------------------------------


function sampev.onDisplayGameText(_, _, gameText)
	if string.find(sampGetCurrentServerName(), "Horizon Roleplay") then
		if gameText == "~w~Car Selling ~n~~r~Drop the car at the Crane" then
			hasFirstCharacterLoginOccured = true
			
			if isCommandResponseAwaited then
				isCarjackerGameTextIntercepted = true
				return false -- Prevents the "CAR SELLING" banner text from forming only if /sellcar is entered by the mod
			end
		end
	end
end

function sampev.onSetCheckpoint(checkpointPosition, checkpointRadius)
	if
		isCommandResponseAwaited
		and math.floor(checkpointPosition.x) == 2695
		and math.floor(checkpointPosition.y) == -2226
		and math.floor(checkpointPosition.z) == 13
		and math.floor(checkpointRadius) == 8
	then
		-- Prevents the checkpoint from forming server-side only if /sellcar is entered by the mod
		isKCPRequested = true
		sampSendChat("/kcp")
		
		-- Prevents the checkpoint from forming client-side only if /sellcar is entered by the mod
		return false
	end
end

function sampev.onServerMessage(_, msg_text)
	if string.find(sampGetCurrentServerName(), "Horizon Roleplay") then
		-- (Vehicle delivery done) "You sold a car for $600, your reload time is 12 minutes."
		if msg_text:sub(1, 20) == "You sold a car for $" then
			hasFirstCharacterLoginOccured = true
			isCarjackerGameTextIntercepted = false
			isSellingAvailable = false
		
		-- (Checkpoint already exists) "Please ensure that your current checkpoint is destroyed first (you either have material packages, or another existing checkpoint)."
		elseif string.sub(msg_text, 1, 56) == "Please ensure that your current checkpoint is destroyed " then
			hasFirstCharacterLoginOccured = true
			
			if isCommandResponseAwaited then
				isCommandAttemptRedundant = true
				isCommandResponseAwaited = false
				return false
			end
		
		-- (Cooldown ongoing)
		elseif msg_text:sub(1, 51) == "You have already dropped off a car - you must wait " then
			hasFirstCharacterLoginOccured = true
			
			if isCommandResponseAwaited then
				isCommandResponseAwaited = false
				return false
			end
		
		-- (Failure to test due to something like being in the middle of getting spawned inside an interior, like when you log in)
		elseif msg_text == "You can't do this right now." then
			hasFirstCharacterLoginOccured = true
			
			if isCommandResponseAwaited then
				isCommandResponseAwaited = false
				return false
			end
		
		-- (Checkpoint killed)
		elseif msg_text == "All current checkpoints, trackers and accepted fares have been reset." then
			hasFirstCharacterLoginOccured = true
			
			if isKCPRequested then
				isKCPRequested = false
				return false
			end
		
		-- (Character login) "Welcome to Horizon Roleplay, ..."
		elseif string.sub(msg_text, 1, 29) == "Welcome to Horizon Roleplay, " then
			hasFirstCharacterLoginOccured = true
			hasNonfirstCharacterLoginOccured = true
			
			-- Stopping command submission and reminder, and resetting some variables, if the server disconnects
			isCarjackerGameTextIntercepted = false
			isCommandAttemptRedundant = false
			isSellingAvailable = false
			isCommandResponseAwaited = false
			isKCPRequested = false
		
		-- (Player muted from spamming CMDs) "You have been muted automatically for spamming. Please ..."
		elseif string.sub(msg_text, 1, 48) == "You have been muted automatically for spamming. " then
			isPlayerMuted = true
			hasFirstCharacterLoginOccured = true
			
			if isCommandResponseAwaited then
				isCommandResponseAwaited = false
				return false
			end
		
		end
	end
end



-----------------------------------------------------
-- LOCALLY DECLARED FUNCTIONS
-----------------------------------------------------


local function createReminderTextdraw()
	local window_resX, window_resY = getScreenResolution()
	game_resX, game_resY = convertWindowScreenCoordsToGameScreenCoords(window_resX, window_resY)
	
	sampTextdrawCreate(517, reminderMessage, game_resX / 2, game_resY * 0.96)
	sampTextdrawSetStyle(517, 2)
	sampTextdrawSetAlign(517, 2)
	sampTextdrawSetLetterSizeAndColor(517, textSize / 4, textSize, 0xFFFFFFFF)
	sampTextdrawSetBoxColorAndSize(517, 1, 0x50000000, 0, game_resY * textSize * #reminderMessage / 70)
end


-----------------------------------------------------
-- MAIN
-----------------------------------------------------


function main()
	---------------
	-- INITIALIZING
	---------------
	
	repeat wait(50) until isSampAvailable()
	repeat wait(50) until string.find(sampGetCurrentServerName(), "Horizon Roleplay")
	
	sampTextdrawDelete(517) -- Removes any existing textdraws with the same ID
	
	sampAddChatMessage("--- {AAAAFF}Carjacker Reminder v" .. script.this.version .. " {FFFFFF}by Bear | Use {AAAAFF}/cjr {FFFFFF}to toggle reminder", -1)
	
	sampRegisterChatCommand("cjr", cmd_cjr)
	
	---------------------
	-- ADDITIONAL THREADS
	---------------------
	
	-- Recurring timer for pulse triggering, determined in length by pulse frequency
	local isPulseTimerOver
	lua_thread.create(function()
		while true do
			while isSellingAvailable and config_table.Options.isReminderEnabled do
				isPulseTimerOver = false
				
				-- Cooldown between pulses
				wait((pulseFrequency * 1000) - 500)
				
				isPulseTimerOver = true
				wait(500) -- Allowing enough time for the variable to be caught in its true state
			end
		
		wait(100)
		end
	end)
	
	-- An extra thread that initiates a 13-second spam cooldown
	lua_thread.create(function()
		while true do
			wait(200)
			if isPlayerMuted then wait(13000) isPlayerMuted = false end
		end
	end)
	
	------------------------
	-- MAIN THREAD CONTINUED
	------------------------
	
	repeat wait(100) until hasFirstCharacterLoginOccured -- Detecting the first login
	wait(100)
	hasNonfirstCharacterLoginOccured = false
	
	while true do
		::start::
		repeat wait(100) until config_table.Options.isReminderEnabled
		
		isCommandResponseAwaited = true
		isCarjackerGameTextIntercepted = false
		isCommandAttemptRedundant = false
		
		while isPlayerMuted do wait(0) end
		sampSendChat("/sellcar")
		
		while isCommandResponseAwaited do
			if isCarjackerGameTextIntercepted then
				wait(500)
				
				isCommandResponseAwaited = false
				
				if isCarjackerGameTextIntercepted then
					break
				else
					goto start
				end
			end
			
			wait(0)
		end
		
		-- If the player is reconnected, this if statement restarts the testing process quicker, skipping the 10-second pause
		if hasNonfirstCharacterLoginOccured then
			hasNonfirstCharacterLoginOccured = false
			goto start
		end
		
		if isCarjackerGameTextIntercepted or isCommandAttemptRedundant then
			isSellingAvailable = true
			
			-- Loop if the reminder is disabled by the player
			while isSellingAvailable and not config_table.Options.isReminderEnabled do wait(100) end
			
			-- In case the loop was exited due to reconnection
			if hasNonfirstCharacterLoginOccured then
				hasNonfirstCharacterLoginOccured = false
				goto start
			end
			
			-- Start the reminder
			createReminderTextdraw()
			
			while isSellingAvailable and config_table.Options.isReminderEnabled do
				-- Pulsing routine
				if isPulseTimerOver then
					for i = pulseCount, 1, -1 do
						wait(pulseDuration / 2)
						
						if isSellingAvailable and config_table.Options.isReminderEnabled then
							sampTextdrawSetBoxColorAndSize(517, 1, 0x50FFFFFF, 0, game_resY * textSize * #reminderMessage / 70)
							sampTextdrawSetLetterSizeAndColor(517, textSize / 4, textSize, 0xFF000000)
						else break
						end
						
						wait(pulseDuration / 2)
						
						if isSellingAvailable and config_table.Options.isReminderEnabled then
							sampTextdrawSetBoxColorAndSize(517, 1, 0x50000000, 0, game_resY * textSize * #reminderMessage / 70)
							sampTextdrawSetLetterSizeAndColor(517, textSize / 4, textSize, 0xFFFFFFFF)
						else break
						end
					end
				end
				
				wait(100)
			end
			
			sampTextdrawDelete(517)
			
		else
			wait(10000)
		
		end
	end
end


-----------------------------------------------------
-- COMMAND-SPECIFIC FUNCTIONS
-----------------------------------------------------


function cmd_cjr()
	if config_table.Options.isReminderEnabled then
		config_table.Options.isReminderEnabled = false
		if inicfg.save(config_table, config_file_path) then
			sampAddChatMessage("--- {AAAAFF}Carjacker Reminder: {FFFFFF}Off", -1)
		else
			sampAddChatMessage("--- {AAAAFF}Carjacker Reminder: {FFFFFF}Reminder toggle in config failed - contact the developer for help.", -1)
		end
	else
		config_table.Options.isReminderEnabled = true
		if inicfg.save(config_table, config_file_path) then
			sampAddChatMessage("--- {AAAAFF}Carjacker Reminder: {FFFFFF}On", -1)
		else
			sampAddChatMessage("--- {AAAAFF}Carjacker Reminder: {FFFFFF}Reminder toggle in config failed - contact the developer for help.", -1)
		end
	end
end
