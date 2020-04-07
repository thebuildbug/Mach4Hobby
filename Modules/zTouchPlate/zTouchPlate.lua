-----------------------------------------------------------------------------
-- Name:        Z-Touch Plate Tool
-- Author:      The Build Bug
-- Modified by:
-- Created:     11/25/2019
-- Copyright:   (c) TheBuildBug. All rights reserved.
-- Licence:     GNU license - This header can not be removed 
-- Description: This panel is intended to be used with a Z-axis touch plate
--              made by CNC Router Parts (a.k.a Avid CNC). It is intended to
--              provide code to allow you to use the touch plate to define
--              work coordinates for X, Y, and Z axes using the touch plate
--              as designed.
-----------------------------------------------------------------------------
-- Table that encapsulates this module
local zTouchPlate = {}

-----------------------------------------------------------------------------
-- Z Touch Plate Constants - Should NOT need updating unless dimensions change.
-- Duplicated for both Metric and Imperial. Obviously, if you change a value
-- for one, do the conversion, and change the corresponding value to match.
-----------------------------------------------------------------------------
local IMPERIAL_CONSTANTS = {
	TOUCH_PLATE_HEIGHT      = 1,        -- Z Touchplate is 1" (25.4mm) tall
	TOUCH_PLATE_WIDTH       = 2.205,    -- Z Touchplate is 2.205" (56mm) wide
	TOUCH_PLATE_PROBE_WIDTH = 2,        -- Z Touchplate has 2" (50.8mm) square probing area
	Z_TRAVEL_HEIGHT         = 1 + .125, -- How high to lift tool while probing X and Y (inches)
	Z_LIFT_HEIGHT           = 1 + .5,   -- How high to lift tool after script is complete (inches)	
	PROBE_FEED_RATE         = 10,       -- Inches Per Minute (anything from 5-12 will likely work well)
	X_PROBE_DISTANCE        = 2,        -- How long to probe the X-Axis (inches)
	Y_PROBE_DISTANCE        = 2 ,       -- How long to probe the Y-Axis (inches)
	Z_PROBE_DISTANCE        = 2         -- How long to probe the Z-Axis (inches)
}

local METRIC_CONSTANTS = {
	TOUCH_PLATE_HEIGHT      = 25.4,        -- Z Touchplate is 25.4mm (1") tall
	TOUCH_PLATE_WIDTH       = 56,          -- Z Touchplate is 56mm (2.205") wide
	TOUCH_PLATE_PROBE_WIDTH = 50.8,        -- Z Touchplate has 50.8mm (2") square probing area
	Z_TRAVEL_HEIGHT         = 25.4 + 3.175,-- How high to lift tool while probing X and Y (mm)
	Z_LIFT_HEIGHT           = 25.4 + 12.7, -- How high to lift tool after script is complete (mm)	
	PROBE_FEED_RATE         = 254,         -- Inches Per Minute (anything from 254-305 will likely work well)
	X_PROBE_DISTANCE        = 50.8,        -- Distance to probe the X-Axis (mm)
	Y_PROBE_DISTANCE        = 50.8,        -- Distance to probe the Y-Axis (mm)
	Z_PROBE_DISTANCE        = 50.8         -- Distance to probe the Z-Axis (mm)
}

-- Maps the Touchplate Orientation option names with their
-- position indexes in the wxRadioBox UI widget that the
-- user selects. These represent the physical orientation
-- the touchplate is placed onto the workpiece.
local ORIENTATION = {
	[0] = "LEFT FRONT",
	[1] = "LEFT REAR",
	[2] = "RIGHT FRONT",
	[3] = "RIGHT REAR" 
}
			
-- Maps the position indexes (0-3) of selected orientation to
-- the direction the probe should move on the X-Axis
-- for each orientation option. The indexes must match the
-- ids from the wxRadioBox and the ORIENTATION variable above.
local X_PROBE_DIRECTION = {
	[0] =  1, -- LEFT FRONT
	[1] =  1, -- LEFT REAR
	[2] = -1, -- RIGHT FRONT
	[3] = -1  -- RIGHT REAR
}

-- Maps the position indexes (0-3) of selected orientation to
-- the direction the probe should move on the Y-Axis
-- for each orientation option. The indexes must match the
-- ids from the wxRadioBox and the ORIENTATION variable above.
local Y_PROBE_DIRECTION = {
	[0] =  1, -- LEFT FRONT
	[1] = -1, -- LEFT REAR
	[2] = -1, -- RIGHT FRONT
	[3] =  1  -- RIGHT REAR
}

-- Unit of Measure.
-- These need to match the indexes from the wxRadioButton.
local INCHES = 0
local MILLIMETERS = 1
-- Lookup for unit of measure names
local UNITS = {[INCHES]      = "INCHES",
			   [MILLIMETERS] = "MILLIMETERS"}

-- Table to hold all UI elements
local UI = {}

-- Table to hold user input data
local userInputData = {}

local INST = mc.mcGetInstance()
local RUN_BUTTON_TEXT = "Run"
local CANCEL_BUTTON_TEXT = "Cancel"
local CLEAR_STATUS_BUTTON_TEXT = "Clear"

-- Current machine feedrate so we can restore it
local curFeedRate = nil

-- Creates the zTouchPlate panel that this module implements.
function zTouchPlate.create()
	
	-- Create the main Frame and Panel if we're running in standalone mode.
	if (mcLuaPanelParent == nil) then
		UI.MainFrame = wx.wxFrame(wx.NULL, 
								  wx.wxID_ANY, 
								  "Z-Touch Plate: Edge Finder Tool",
								  wx.wxDefaultPosition,
								  wx.wxSize(-1,-1), 
								  wx.wxDEFAULT_FRAME_STYLE+wx.wxTAB_TRAVERSAL )
		UI.m_MainPanel = wx.wxPanel(UI.MainFrame, 
									wx.wxID_ANY, 
									wx.wxDefaultPosition, 
									wx.wxDefaultSize, 
									wx.wxTAB_TRAVERSAL )
		UI.MainFrame:SetSizeHints( wx.wxDefaultSize, wx.wxDefaultSize )
		UI.EventHandler = UI.MainFrame:GetEventHandler()
	else
		-- The parent already exists (we're running within the
		-- Mach4 parent screen) so just get the parent attributes
		UI.m_MainPanel = mcLuaPanelParent
		local window = UI.m_MainPanel:GetParent()
		local wsize = window:GetSize()
		UI.m_MainPanel:SetSize(wsize)
	end
	
	loadWxWidgetComponentsForZTouchplatePanel()
	
	bindUIEvents()

	-- Show the panel just created
	if (mcLuaPanelParent == nil) then
		-- Standalone mode
		UI.MainFrame:SetSizer( UI.bSizerMain )
		UI.MainFrame:Layout()
		UI.MainFrame:Centre( wx.wxBOTH )
        UI.m_MainPanel:Fit()
        UI.MainFrame:Fit()
        UI.MainFrame:Show(true)
    else
		-- Running within Mach4 screen
        local window = UI.m_MainPanel:GetParent()
        window:Connect(wx.wxID_ANY, 
					   wx.wxEVT_SIZE,
					   function(event)
						   local wsize = event:GetSize()
						   UI.m_MainPanel:SetSize(wsize)
						   UI.m_MainPanel:FitInside()
						   event:Skip()
					   end)
    end
end -- END zTouchPlate.create()

-----------------------------------------------------------------------------
-- Event Handlers
-----------------------------------------------------------------------------
-- Bind functions to the various UI events triggered by the user interacting
-- with the wxWidget UI components.
function bindUIEvents()
	
	-- Register the resumeZTouchPlateCoroutine() function as a callback
	-- for the UI event named wxEVT_UPDATE_UI which should be called by the
	-- GUI chunk whenever the GUI is 'idle'
	myMainFrame = wx.wxGetApp()
	myMainFrame:Connect(wx.wxEVT_UPDATE_UI, 
						   function(event)
								resumeZTouchPlateCoroutine()
								event:Skip()
						   end
	)
	
	-- Axis CheckBoxes
	UI.m_MainPanel:Connect(wx.wxID_ANY,
						   wx.wxID_ANY,
						   wx.wxEVT_COMMAND_CHECKBOX_CLICKED,
						   function(event)
								handleCheckBoxClicked(event)
						   end)
	-- Button Click
	UI.m_MainPanel:Connect(wx.wxID_ANY,
						   wx.wxID_ANY,
						   wx.wxEVT_COMMAND_BUTTON_CLICKED,
						   function(event)
								handleButtonClicked(event)
						   end)
end

-- Handle CheckBoxClicked events for entire panel
function handleCheckBoxClicked(event)
	local checkBox = event:GetEventObject():DynamicCast("wxCheckBox")
	local checkBoxLabel = checkBox:GetLabel()
	if (checkBoxLabel == "Z-Axis") then
		checkBox:SetValue(true) -- DO NOT ALLOW Z-Axis to be un-selected
	end
end

-- Handle ButtonClicked events for entire panel
function handleButtonClicked(event)
	local button = event:GetEventObject():DynamicCast("wxButton")
	local buttonLabel = button:GetLabel()
	if (buttonLabel == RUN_BUTTON_TEXT) then
		local fnSuccess, fnError = pcall(runProbingProcedure)
		if (fnSuccess ~= true) then
			appendStatus("Unexpected Error: ".. fnError)
			exitRunProbingProcedure(false)
		end
	elseif (buttonLabel == CANCEL_BUTTON_TEXT) then
		cancelProbingProcedure()
	elseif (buttonLabel == CLEAR_STATUS_BUTTON_TEXT) then
		clearStatus()
	end
end

-- Appends the given string to the status bar text widget
--
-- @param msg - string containing message to write to status text widget
-- @param addNewline - (optional default=True) boolean indicating whether to add a newline char
function appendStatus(msg, addNewline) 
	if (addNewline == nil) then
		addNewline = true
	end
	if (addNewline) then
		UI.m_textCtrlStatusLine:AppendText(msg.."\n")
	else 
		UI.m_textCtrlStatusLine:AppendText(msg.." ")
	end
end

function cancelProbingProcedure()
	-- Kill the coroutine by setting a debug hook.
	debug.sethook(zTouchPlateCoroutine, 
				  function()
						error("Probing Canceled by user.")
				  end, "l")
	-- NOTE: Known issue: PMDX-424 does not seem to exit "PROBE" mode successfully by the following command
	mc.mcMotionSetProbeComplete(INST)
	mc.mcCntlCycleStop(INST)
end

function clearStatus() 
	UI.m_textCtrlStatusLine:Clear()
end

-----------------------------------------------------------------------------
-- Z-TouchPlate Probing Logic
-----------------------------------------------------------------------------
function runProbingProcedure()

	-- Verify the machine is enabled
	local isEnabled = mc.mcSignalGetState(mc.mcSignalGetHandle(INST, mc.OSIG_MACHINE_ENABLED))
	if (isEnabled ~= 1) then
		wx.wxMessageBox("Machine must be enabled to zero axes.\n\nEnable motion and try again.", "Z-TouchPlate")
		appendStatus("Error: Mach4 not enabled.")
		return
	end
	
	-- Verify the machine is in ready state to proceed.
	if (mc.mcCntlGetState(INST) ~= mc.MC_STATE_IDLE) then
		wx.wxMessageBox("Machine must be in idle state to zero Axes.\nEnable or Stop Motion to continue.", "Z-TouchPlate")
		appendStatus("Error: Mach4 not in idle state.")
		return
	end
	
	gatherUserInputData()
	
	if (not isUserInputDataValid()) then
		return
	end
	
	-- Show message box - useful for debugging user input
	--printUserData()
	
	-- Store the current feed rate so we can restore it later
	curFeedRate =  mc.mcCntlGetFRO(INST)
	
    -- Perform the probing procedure by running
	-- the zeroAllAxes function as a coroutine.
	--
	-- NOTE: This only creates the coroutine. The coroutine is
	--       executed when coroutine.resume(zTouchPlateCoroutine)
	--       is called by the wxWidget wxEVT_UPDATE_UI event 
	--       callback function resumeZTouchPlateCoroutine() below.
    zTouchPlateCoroutine = coroutine.create(zeroAllAxes)
	
end -- END: runProbingProcedure()


-- Performs the actual zeroing of the three axes.
-- Z-Axis is always zeroed. X and Y are done per user selection.
function zeroAllAxes()
	UI.m_buttonRun:Enable(false)
	appendStatus("<START>")
	
	-- Select which constants to use (Metric/Imperial) based on user input
	local constants = getConstants()
	
    -- Set the probing feedrate
	feedrateGcode = "F"..constants.PROBE_FEED_RATE
	appendStatus("[Set Feedrate]: "..feedrateGcode, false)
	mc.mcCntlGcodeExecuteWait(INST, feedrateGcode)
	appendStatus(" (SUCCESS)") -- If we've made to this line, the gcode cmd must have succeeded

	-- Probe Z-Axis (always)
	local curZPos = mc.mcAxisGetPos(INST, mc.Z_AXIS)
	local newZPos = curZPos - constants.Z_PROBE_DISTANCE
	executeGCode(string.format("G31 Z%.4f", newZPos),"Probe Z-axis")
	verifyTouchplateStrike()  -- Make sure the probe actually struck the touchplate
	appendStatus("(SUCCESS)") 

	-- Set work coordinate of Z-axis 
	mc.mcAxisSetPos(INST, mc.Z_AXIS, constants.TOUCH_PLATE_HEIGHT)
	
	-- Move back up to probe other axes
	executeGCode(string.format("G0 Z%.4f", constants.Z_TRAVEL_HEIGHT),"Retract")
	appendStatus("(SUCCESS)")
	
	-- Probe X-Axis (if requested)
	local toolRadius = userInputData.toolDiameter / 2
	if (userInputData.probeXAxis) then
		pauseBetweenAxesIfNeeded("X-Axis", userInputData)
		local curXPos = mc.mcAxisGetPos(INST, mc.X_AXIS)
		local newXPos = curXPos + (constants.X_PROBE_DISTANCE * X_PROBE_DIRECTION[userInputData.orientation])
		executeGCode(string.format("G31 X%.4f", newXPos), "Probe X-axis")
		verifyTouchplateStrike()
		appendStatus("(SUCCESS)")

		mc.mcAxisSetPos(INST, 
			            mc.X_AXIS, 
						(constants.TOUCH_PLATE_WIDTH - toolRadius) * X_PROBE_DIRECTION[userInputData.orientation]
		)
		-- Center tool on the touchplate
        executeGCode(string.format("G0 X%.4f", (constants.TOUCH_PLATE_WIDTH/2) * X_PROBE_DIRECTION[userInputData.orientation]), "Center Tool")
		appendStatus("(SUCCESS)")
	end
	
	-- Probe Y-Axis (if requested)
	if (userInputData.probeYAxis) then
		pauseBetweenAxesIfNeeded("Y-Axis", userInputData) 
		local curYPos = mc.mcAxisGetPos(INST, mc.Y_AXIS)
		local newYPos = curYPos + (constants.Y_PROBE_DISTANCE * Y_PROBE_DIRECTION[userInputData.orientation])
		executeGCode(string.format("G31 Y%.4f", newYPos), "Probe Y-axis")
		verifyTouchplateStrike()
		appendStatus("(SUCCESS)")
		mc.mcAxisSetPos(INST, 
			            mc.Y_AXIS, 
						(constants.TOUCH_PLATE_WIDTH - toolRadius) * Y_PROBE_DIRECTION[userInputData.orientation]
		)
		-- Center tool on the touchplate
		executeGCode(string.format("G0 Y%.4f", (constants.TOUCH_PLATE_WIDTH/2) * Y_PROBE_DIRECTION[userInputData.orientation]), "Center Tool")
		appendStatus("(SUCCESS)")
    end

	-- Lift Z-Axis to the specified lift height
	executeGCode(string.format("G0 Z%.4f", constants.Z_LIFT_HEIGHT), "Retract")
	appendStatus("(SUCCESS)")
	
end -- END zeroAllAxes()

-- Submits gcode for execution by Mach4
--
-- @param - gCodeString - string containing the gcode to execute
-- @param - descr - string description that documents the gcode command
--                  used in status message on success/failure of gcode.
function executeGCode(gCodeString, descr)
	appendStatus("["..descr.."]: "..gCodeString, false)
	mc.mcCntlGcodeExecute(INST, gCodeString)
	coroutine.yield()
end

function verifyTouchplateStrike()
	if (mc.mcCntlProbeGetStrikeStatus(INST) ~= 1) then
		error("Probe never touched.")
	end
end

function restoreFeedrate()
	local resetGcode = "F"..curFeedRate
	appendStatus("[Reset Feedrate]: "..resetGcode.." (SUCCESS)")
	mc.mcCntlGcodeExecute(INST, resetGcode)
end

-- Intended to be triggered by GUI code chunk to allow DROs to update
-- when probing motion is underway. This function resumes the suspended 
-- zeroAllAxes() coroutine when appropriate or kills the coroutine by 
-- nulling out its reference. This method is also responsible for exiting
-- the runProbingProcedure gracefully i.e. re-enabling the 'Run' button,
-- outputting failure status messages as needed.
function resumeZTouchPlateCoroutine()
    
	-- Return quickly if the coroutine does not exist.
	if (zTouchPlateCoroutine == nil) then
		return
	end
	
	-- Get the current status of the coroutine (suspended, running, or dead)
	crStatus = coroutine.status(zTouchPlateCoroutine)
	
	if (crStatus == "dead") then
		exitRunProbingProcedure()
	elseif (crStatus == "suspended") then
		-- Only proceed if Mach4 is in 'Idle' state
		if (mc.mcCntlGetState(INST) == 0) then
			local crRetCode, errMsg = coroutine.resume(zTouchPlateCoroutine)
			if (crRetCode ~= true)  then
				appendStatus("(FAILURE):"..errMsg)
				mc.mcCntlSetLastError(INST, "[zTouchPlate]: "..errMsg)
				exitRunProbingProcedure(false)
			end
		end
	end
end


function exitRunProbingProcedure(exitClean)
	if (exitClean == nil) then
		exitClean = true
	end
	
	-- Kill the coroutine
	zTouchPlateCoroutine = nil
	
	-- Reset Feedrate to whatever it was before
	restoreFeedrate()

	appendStatus("<END>")
	if (exitClean) then
		wx.wxMessageBox("Zeroing Sequence Complete.", "Z-TouchPlate")
	end
	
	UI.m_buttonRun:Enable(true)
end


function pauseBetweenAxesIfNeeded(axisStr, userInputData) 
	if (userInputData.pauseBetweenAxes) then
		appendStatus("[Paused]: "..axisStr)
	    wx.wxMessageBox("Align Tool Flutes for ".. axisStr .. " travel.\n\nPress OK to continue.", "Z-TouchPlate")
	end
end

-- Return constants based on user selection (metric or imperial)
function getConstants()
	local constants = nil
	if (userInputData.unitOfMeasure == INCHES) then
		constants = IMPERIAL_CONSTANTS
	elseif (userInputData.unitOfMeasure == MILLIMETERS) then
		constants = METRIC_CONSTANTS
	end
	return constants
end

-- Assemble the input data the user has entered.
function gatherUserInputData() 
	-- Clear the stored data from a previous run
	clearStoredUserInputData()
	
	-- Axes to probe
	userInputData.probeZAxis = true; -- Z-Axis is always probed
	if (UI.m_checkBoxXAxis:GetValue()) then
		userInputData.probeXAxis = true
	else
		userInputData.probeXAxis = false
	end
	if (UI.m_checkBoxYAxis:GetValue()) then
		userInputData.probeYAxis = true
	else
		userInputData.probeYAxis = false
	end
	
	-- Touch plate orientation
	userInputData.orientation = UI.m_radioBoxOrient:GetSelection()
	
	-- Tool Diameter
	userInputData.toolDiameter = tonumber(UI.m_textCtrlToolDiameter:GetValue())
	
	-- Unit of Measure
	if (UI.m_radioBtnMillimeters:GetValue()) then
		userInputData.unitOfMeasure = MILLIMETERS
	else
		userInputData.unitOfMeasure = INCHES
	end
	
	-- Pause Between Measures
	if (UI.m_checkBoxPauseBetweenAxes:GetValue()) then 
		userInputData.pauseBetweenAxes = true
	else
		userInputData.pauseBetweenAxes = false
	end
	
end -- END gatherUserInputData()


function isUserInputDataValid()
	
	-- ToolDiameter must be a valid number.
	if (userInputData.toolDiameter== nil) then
		wx.wxMessageBox("Tool Diameter must be a valid number!", "Z-TouchPlate: Invalid Input")
		return false
	end
	
	-- ToolDiameter must greater than zero and less than the width 
	-- of the probing pad (handle both metric and imperial cases).
	local constants = getConstants()
	if (userInputData.toolDiameter <= 0) then
		wx.wxMessageBox("Tool Diameter must be greater than zero!", "Z-TouchPlate: Invalid Input", wx.wxICON_ERROR)
		return false
	elseif (userInputData.toolDiameter > constants.TOUCH_PLATE_PROBE_WIDTH) then
		wx.wxMessageBox("Tool Diameter cannot be greater than\nthe Touch Plate probing area!", "Z-TouchPlate: Invalid Input", wx.wxICON_ERROR)
		return false
	end
	-- All input is valid
	return true 
end -- END isUserInputDataValid()

function clearStoredUserInputData()
	userInputData.probeZAxis = nil
	userInputData.probeXAxis = nil
	userInputData.probeYAxis = nil
    userInputData.orientation = nil
	userInputData.toolDiameter = nil
	userInputData.unitOfMeasure = nil
	userInputData.pauseBetweenAxes = nil
end

-- Utility Method to help debug user input
function printUserData()
	local msg = "---------------------------------------------------\n" ..
				"  Z-axis: \t" .. tostring(userInputData.probeZAxis) .. "\n" ..
				"  X-axis: \t" .. tostring(userInputData.probeXAxis) .. "\n" ..
				"  Y-axis: \t" .. tostring(userInputData.probeYAxis) .. "\n" ..
				"  Orient: \t" .. ORIENTATION[userInputData.orientation] .. "\n" ..
				"Tool Dia: \t" .. userInputData.toolDiameter .. "\n" ..
				"    Unit: \t" .. UNITS[userInputData.unitOfMeasure] .. "\n" ..
				"   Pause: \t" .. tostring(userInputData.pauseBetweenAxes) .. "\n" ..
				"---------------------------------------------------\n"
	wx.wxMessageBox(msg,"Z-TouchPlate: Debug Info",wx.wxICON_EXCLAMATION)
end

-----------------------------------------------------------------------------
-- wxWidgets UI Components
-----------------------------------------------------------------------------
--   The code within this function was generated using wxFormBuilder
--   and slightly modified to allow us to run the code both within
--   Mach4 and standalone/debug within ZeroBrane Studio. The only 
--   difference is that standalone/debug requires us to create the
--   parent frame (which is done above in the Main() function).
function loadWxWidgetComponentsForZTouchplatePanel()
	
	UI.bSizerMain = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.bSizerInner = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.fgSizerMain = wx.wxFlexGridSizer( 2, 1, 0, 0 )
	UI.fgSizerMain:SetFlexibleDirection( wx.wxVERTICAL )
	UI.fgSizerMain:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.bSizerRowOne = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.gSizerThreeColumn = wx.wxGridSizer( 1, 4, 0, 0 )

	UI.sbSizerAxes = wx.wxStaticBoxSizer( wx.wxStaticBox( UI.m_MainPanel, wx.wxID_ANY, "Axes" ), wx.wxVERTICAL )

	UI.gSizerRadioAxes = wx.wxGridSizer( 3, 1, 0, 0 )

	UI.m_checkBoxZAxis = wx.wxCheckBox( UI.sbSizerAxes:GetStaticBox(), wx.wxID_ANY, "Z-Axis", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_checkBoxZAxis:SetValue(true)
	UI.m_checkBoxZAxis:Enable(false)

	UI.gSizerRadioAxes:Add( UI.m_checkBoxZAxis, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_checkBoxXAxis = wx.wxCheckBox( UI.sbSizerAxes:GetStaticBox(), wx.wxID_ANY, "X-Axis", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizerRadioAxes:Add( UI.m_checkBoxXAxis, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_checkBoxYAxis = wx.wxCheckBox( UI.sbSizerAxes:GetStaticBox(), wx.wxID_ANY, "Y-Axis", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizerRadioAxes:Add( UI.m_checkBoxYAxis, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )


	UI.sbSizerAxes:Add( UI.gSizerRadioAxes, 1, wx.wxALIGN_CENTER_HORIZONTAL, 0 )


	UI.gSizerThreeColumn:Add( UI.sbSizerAxes, 1, wx.wxEXPAND, 0 )

	UI.m_radioBoxOrientChoices = { "Left / Front", "Left / Rear", "Right / Front", "Right / Rear" }
	UI.m_radioBoxOrient = wx.wxRadioBox( UI.m_MainPanel, wx.wxID_ANY, "Orientation", wx.wxDefaultPosition, wx.wxSize( 125,-1 ), UI.m_radioBoxOrientChoices, 1, wx.wxRA_SPECIFY_COLS )
	UI.m_radioBoxOrient:SetSelection(0)
	UI.gSizerThreeColumn:Add( UI.m_radioBoxOrient, 0, wx.wxALIGN_CENTER_HORIZONTAL, 0 )

	UI.sbSizerRowTwo = wx.wxStaticBoxSizer( wx.wxStaticBox( UI.m_MainPanel, wx.wxID_ANY, "Tool Diameter" ), wx.wxVERTICAL )

	UI.bSizerRow2 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_textCtrlToolDiameter = wx.wxTextCtrl( UI.sbSizerRowTwo:GetStaticBox(), wx.wxID_ANY, "0", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizerRow2:Add( UI.m_textCtrlToolDiameter, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 5 )

	UI.m_radioBtnInches = wx.wxRadioButton( UI.sbSizerRowTwo:GetStaticBox(), wx.wxID_ANY, "Inches", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_radioBtnInches:SetValue(true)
	UI.bSizerRow2:Add( UI.m_radioBtnInches, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 5 )

	UI.m_radioBtnMillimeters = wx.wxRadioButton( UI.sbSizerRowTwo:GetStaticBox(), wx.wxID_ANY, "Millimeters", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizerRow2:Add( UI.m_radioBtnMillimeters, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 5 )


	UI.sbSizerRowTwo:Add( UI.bSizerRow2, 1, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALIGN_TOP, 0 )


	UI.gSizerThreeColumn:Add( UI.sbSizerRowTwo, 1, wx.wxEXPAND, 5 )

	UI.gSizerAction = wx.wxGridSizer( 2, 1, 5, 0 )

	UI.m_buttonRun = wx.wxButton( UI.m_MainPanel, wx.wxID_ANY, RUN_BUTTON_TEXT, wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizerAction:Add( UI.m_buttonRun, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxTOP, 10 )

	UI.m_buttonCancel = wx.wxButton( UI.m_MainPanel, wx.wxID_ANY, CANCEL_BUTTON_TEXT, wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizerAction:Add( UI.m_buttonCancel, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxLEFT, 0 )

	UI.m_checkBoxPauseBetweenAxes = wx.wxCheckBox( UI.m_MainPanel, wx.wxID_ANY, "Pause Between Axes", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizerAction:Add( UI.m_checkBoxPauseBetweenAxes, 0, wx.wxALL, 5 )


	UI.gSizerThreeColumn:Add( UI.gSizerAction, 1, 0, 0 )


	UI.bSizerRowOne:Add( UI.gSizerThreeColumn, 1, wx.wxALL + wx.wxEXPAND, 0 )


	UI.fgSizerMain:Add( UI.bSizerRowOne, 1, wx.wxALIGN_CENTER_HORIZONTAL, 0 )

	UI.sbSizerRowThree = wx.wxStaticBoxSizer( wx.wxStaticBox( UI.m_MainPanel, wx.wxID_ANY, "Status" ), wx.wxHORIZONTAL )

	UI.m_textCtrlStatusLine = wx.wxTextCtrl( UI.sbSizerRowThree:GetStaticBox(), wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 460,80 ), wx.wxTE_MULTILINE + wx.wxTE_READONLY )

	UI.sbSizerRowThree:Add( UI.m_textCtrlStatusLine, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_buttonClear = wx.wxButton( UI.sbSizerRowThree:GetStaticBox(), wx.wxID_ANY, CLEAR_STATUS_BUTTON_TEXT, wx.wxPoint( -1,-1 ), wx.wxSize( 50,-1 ), 0 )
	UI.m_buttonClear:SetToolTip( "Click to clear the text in the status line." )

	UI.sbSizerRowThree:Add( UI.m_buttonClear, 0, wx.wxALIGN_BOTTOM + wx.wxBOTTOM, 5 )


	UI.fgSizerMain:Add( UI.sbSizerRowThree, 1, wx.wxEXPAND, 5 )


	UI.bSizerInner:Add( UI.fgSizerMain, 1, wx.wxEXPAND, 5 )

	UI.m_MainPanel:SetSizer( UI.bSizerInner )
	UI.m_MainPanel:Layout()
	UI.bSizerInner:Fit( UI.m_MainPanel )
	UI.bSizerMain:Add( UI.m_MainPanel, 1, wx.wxEXPAND, 5 )

end -- END loadWxWidgetComponentsForZTouchplatePanel()

-----------------------------------------------------------------------------
-- To RUN / DEBUG this module within ZeroBrane Studio, un-comment the 
-- following two lines. Remember to comment them out again when running 
-- within Mach4 or "you're gunna have a bad time!!"
--
-- TODO - Find a better way to do this.
-----------------------------------------------------------------------------
--zTouchPlate.create()
--wx.wxGetApp():MainLoop()

-- Return the module wrapper
return zTouchPlate