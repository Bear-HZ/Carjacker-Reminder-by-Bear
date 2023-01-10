-----------------------------------------------------
-- INFO
-----------------------------------------------------


script_name("Carjacker Reminder by Bear")
script_author("Bear")
script_version("1.0.0-beta")
local script_version = "1.0.0-beta-2"


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

local textSize = 1.2 -- Adjust text size here

local pulseFrequency = 60 -- in seconds

local pulseCount = 2 -- how many times the textdraw pulses each time the above amount of time has passed

local pulseDuration = 1000 -- the time taken (in milliseconds) for the textdraw to pilse once (by switching appearance twice)

local game_resX, game_resY

local isCommandResponseAwaited = false

local isCarjackerGameTextIntercepted = false

local isCommandAttemptRedundant = false

local hasCharacterLoginOccured = false

local isSellingAvailable = false

local isKCPRequested = false


-----------------------------------------------------
-- API-SPECIFIC FUNCTIONS
-----------------------------------------------------


function sampev.onDisplayGameText(_, _, gameText)
	if string.find(sampGetCurrentServerName(), "Horizon Roleplay") then
		if gameText == "~w~Car Selling ~n~~r~Drop the car at the Crane" then
			hasCharacterLoginOccured = true
			
			if isCommandResponseAwaited then
				isCarjackerGameTextIntercepted = true
				return false
			end
		end
	end
end

function sampev.onServerMessage(_, msg_text)
	if string.find(sampGetCurrentServerName(), "Horizon Roleplay") then
		-- (Vehicle delivery done) "You sold a car for $600, your reload time is 12 minutes."
		if msg_text:sub(1, 20) == "You sold a car for $" then
			isSellingAvailable = false
			hasCharacterLoginOccured = true
		
		-- (Checkpoint already exists) "Please ensure that your current checkpoint is destroyed first (you either have material packages, or another existing checkpoint)."
		elseif string.sub(msg_text, 1, 56) == "Please ensure that your current checkpoint is destroyed " then
			hasCharacterLoginOccured = true
			
			if isCommandResponseAwaited then
				isCommandAttemptRedundant = true
				return false
			end
		
		-- (Cooldown ongoing)
		elseif msg_text == "   You have already dropped a car, wait until your reload time is over!" then
			hasCharacterLoginOccured = true
			
			if isCommandResponseAwaited then
				isCommandResponseAwaited = false
				return false
			end
		
		-- (Checkpoint killed)
		elseif msg_text == "All current checkpoints, trackers and accepted fares have been reset." then
			hasCharacterLoginOccured = true
			
			if isKCPRequested then
				isKCPRequested = false
				return false
			end
		
		-- (Character login) "Welcome to Horizon Roleplay, ..."
		elseif string.sub(msg_text, 1, 29) == "Welcome to Horizon Roleplay, " then
			hasCharacterLoginOccured = true
		
		end
	end
end



-----------------------------------------------------
-- LOCALLY DECLARED FUNCTIONS
-----------------------------------------------------


local function createReminderTextdraw()
	local window_resX, window_resY = getScreenResolution()
	game_resX, game_resY = convertWindowScreenCoordsToGameScreenCoords(window_resX, window_resY)
	
	sampTextdrawCreate(517, reminderMessage, game_resX / 2, game_resY * 0.94)
	sampTextdrawSetStyle(517, 1)
	sampTextdrawSetAlign(517, 2)
	sampTextdrawSetLetterSizeAndColor(517, textSize / 4, textSize, 0xFFFFFFFF)
	sampTextdrawSetOutlineColor(517, 1, 0xFF000000)
	sampTextdrawSetBoxColorAndSize(517, 1, 0xFF000000, 0, game_resY * textSize * #reminderMessage / 90)
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
	
	sampAddChatMessage("--- {AAAAFF}Carjacker Reminder v" .. script_version .. " {FFFFFF}by Bear | Use {AAAAFF}/cjr {FFFFFF}to Toggle Reminder", -1)
	
	sampRegisterChatCommand("cjr", cmd_cjr)
	
	---------------------
	-- ADDITIONAL THREADS
	---------------------
	
	--- Stopping command submission and reminder if the server disconnects
	lua_thread.create(function()
		while true do
			if not string.find(sampGetCurrentServerName(), "Horizon Roleplay") then
				hasCharacterLoginOccured = false
				isSellingAvailable = false
				isCommandResponseAwaited = false
			end
			
			wait(100)
		end
	end)
	
	-- Minute-long recurring timer for pulse triggering
	local isPulseTimerOver
	lua_thread.create(function()
		while true do
			while isSellingAvailable and config_table.Options.isReminderEnabled do
				isPulseTimerOver = false
				--local pulseCooldown = (pulseFrequency * 1000) - 500
				wait((pulseFrequency * 1000) - 500)
				isPulseTimerOver = true
				wait(500) -- Allowing enough time for the variable to be caught in its true state
			end
		
		wait(1000)
		end
	end)
	
	------------------------
	-- MAIN THREAD CONTINUED
	------------------------
	
	while true do
		while true do
			repeat wait(100) until hasCharacterLoginOccured and config_table.Options.isReminderEnabled
			
			isCommandResponseAwaited = true
			isCarjackerGameTextIntercepted = false
			isCommandAttemptRedundant = false
			
			sampSendChat("/sellcar")
			
			while isCommandResponseAwaited do
				if isCarjackerGameTextIntercepted then
					
					isKCPRequested = true
					sampSendChat("/kcp")
					
					isCommandResponseAwaited = false
					break
				end
				
				if isCommandAttemptRedundant then
					isCommandResponseAwaited = false
					break
				end
				
				wait(10)
			end
			
			if isCarjackerGameTextIntercepted or isCommandAttemptRedundant then
				isSellingAvailable = true
				
				repeat wait(100) until isSellingAvailable and config_table.Options.isReminderEnabled
				
				-- Start the reminder
				createReminderTextdraw()
				
				while isSellingAvailable and config_table.Options.isReminderEnabled do
					-- Pulsing routine
					if isPulseTimerOver then
						for i = pulseCount, 1, -1 do
							wait(pulseDuration / 2)
							
							if isSellingAvailable and config_table.Options.isReminderEnabled then
								sampTextdrawSetBoxColorAndSize(517, 1, 0xFFFFFFFF, 0, game_resY * textSize * #reminderMessage / 90)
								sampTextdrawSetLetterSizeAndColor(517, textSize / 4, textSize, 0xFF000000)
								sampTextdrawSetOutlineColor(517, 1, 0xFFFFFFFF)
							else break
							end
							
							wait(pulseDuration / 2)
							
							if isSellingAvailable and config_table.Options.isReminderEnabled then
								sampTextdrawSetBoxColorAndSize(517, 1, 0xFF000000, 0, game_resY * textSize * #reminderMessage / 90)
								sampTextdrawSetLetterSizeAndColor(517, textSize / 4, textSize, 0xFFFFFFFF)
								sampTextdrawSetOutlineColor(517, 1, 0xFF000000)
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
		
		wait(0)
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