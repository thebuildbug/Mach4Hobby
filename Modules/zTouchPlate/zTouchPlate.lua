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
    Z_TRAVEL_HEIGHT         = 25.4 + .125, -- How high to lift tool while probing X and Y (mm)
    Z_LIFT_HEIGHT           = 25.4 + .5,   -- How high to lift tool after script is complete (mm)	
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
local DATA = {}

local INST = mc.mcGetInstance()
local ACTION_BUTTON_TEXT = "Run"

-- Creates the zTouchPlate panel that this module implements.
function zTouchPlate.create()
	
	-- Create the main Frame and Panel if we're running in standalone mode.
	if (mcLuaPanelParent == nil) then
		UI.MainFrame = wx.wxFrame (wx.NULL, 
			                       wx.wxID_ANY, 
								   "Z-Touch Plate: Edge Finder Tool",
								   wx.wxDefaultPosition,
								   wx.wxSize(425,220), 
								   wx.wxDEFAULT_FRAME_STYLE+wx.wxTAB_TRAVERSAL )
		UI.m_MainPanel = wx.wxPanel( UI.MainFrame, 
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
		UI.EventHandler = UI.m_MainPanel:GetEventHandler()
	end -- if (mcLuaPanelParent == nil)
	
	loadWxWidgetComponentsForZTouchplatePanel()
	
	bindUIEvents()

	-- Show the panel just created
	if (mcLuaPanelParent == nil) then
		-- Standalone mode
		UI.MainFrame:SetSizer( UI.bSizerMainFrameOuter )
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
	if (buttonLabel == ACTION_BUTTON_TEXT) then
		runProbingProcedure()
	end
end

-----------------------------------------------------------------------------
-- Z-Touchplate Zeroing Logic
-----------------------------------------------------------------------------
function runProbingProcedure()
	-- Verify the machine is in ready state to proceed.
	if (mc.mcCntlGetState(INST) ~= mc.MC_STATE_IDLE) then
		wx.wxMessageBox("Machine must be in idle state to zero Axes.\nEnable or Stop Motion to continue.", "Z-TouchPlate")
		return
	end
	
	gatherUserInputData()
	
	if (not isUserInputDataValid()) then
		return
	end
	
	-- Show message box - useful for debugging user input
	--printUserData()
	
	-- Do the actual probing motions
	zeroAllAxes()
	
	-- Clear input data
	clearUserInputData()
end -- END: runProbingProcedure()


-- Performs the actual zeroing of the three axes.
-- Z-Axis is always zeroed. X and Y are done per user selection.
function zeroAllAxes()
	local curFeedRate =  mc.mcCntlGetFRO(INST) -- Get current feed rate so we can restore it later
	local constants = getConstants() -- either Metric or Imperial as selected by user
	
	executeGCode("G4 P1")
	executeGCode("F" .. constants.PROBE_FEED_RATE)
	
	-- Probe Z-Axis (always)
	local curZPos = mc.mcAxisGetPos(INST, mc.Z_AXIS)
	local newZPos = curZPos - constants.Z_PROBE_DISTANCE
	executeGCode(string.format("G31 Z%.4f", newZPos))
	mc.mcAxisSetPos(INST, mc.Z_AXIS, constants.TOUCH_PLATE_HEIGHT)
	
	-- Move back up to probe other axes
	executeGCode(string.format("G0 Z%.4f", constants.Z_TRAVEL_HEIGHT))
	
	-- Probe X-Axis (if requested)
	local toolRadius = DATA.toolDiameter / 2
	if (DATA.probeXAxis) then
		pauseBetweenAxesIfNeeded("X-Axis")
		local curXPos = mc.mcAxisGetPos(INST, mc.X_AXIS)
		local newXPos = curXPos + (constants.X_PROBE_DISTANCE * X_PROBE_DIRECTION[DATA.orientation])
		executeGCode(string.format("G31 X%.4f", newXPos))
		mc.mcAxisSetPos(INST, 
			            mc.X_AXIS, 
						(constants.TOUCH_PLATE_WIDTH - toolRadius) * X_PROBE_DIRECTION[DATA.orientation]
		)
		-- Center tool on the touchplate
        executeGCode(string.format("G0 X%.4f", (constants.TOUCH_PLATE_WIDTH/2) * X_PROBE_DIRECTION[DATA.orientation]))
	end
	
	-- Probe Y-Axis (if requested)
	if (DATA.probeYAxis) then
		pauseBetweenAxesIfNeeded("Y-Axis") 
		local curYPos = mc.mcAxisGetPos(INST, mc.Y_AXIS)
		local newYPos = curYPos + (constants.Y_PROBE_DISTANCE * Y_PROBE_DIRECTION[DATA.orientation])
		executeGCode(string.format("G31 Y%.4f", newYPos))
		mc.mcAxisSetPos(INST, 
			            mc.Y_AXIS, 
						(constants.TOUCH_PLATE_WIDTH - toolRadius) * Y_PROBE_DIRECTION[DATA.orientation]
		)
		-- Center tool on the touchplate
		executeGCode(string.format("G0 Y%.4f", (constants.TOUCH_PLATE_WIDTH/2) * Y_PROBE_DIRECTION[DATA.orientation]))
    end

	-- Lift Z-Axis and restore original feed rate
	executeGCode(string.format("G0 Z%.4f", constants.Z_LIFT_HEIGHT))
	executeGCode("F" .. curFeedRate)
	
	wx.wxMessageBox("Zeroing Sequence Complete.", "Z-TouchPlate")
end -- END autoZeroMachine()

function executeGCode(gCodeString)
	local rc = mc.mcCntlGcodeExecuteWait(INST, gCodeString)
	if rc ~= mc.MERROR_NOERROR then 
		return "gcode failed", false
	else
		return "success", true
	end
end

function pauseBetweenAxesIfNeeded(axisStr) 
	if (DATA.pauseBetweenAxes) then
	    wx.wxMessageBox("Align Tool Flutes for ".. axisStr .. " travel.\n\nPress OK to continue.", "Z-TouchPlate")
	end
end

-- Return constants based on user selection (metric or imperial)
function getConstants()
	local constants = nil
	if (DATA.unitOfMeasure == INCHES) then
		constants = IMPERIAL_CONSTANTS
	elseif (DATA.unitOfMeasure == MILLIMETERS) then
		constants = METRIC_CONSTANTS
	end
	return constants
end

-- Assemble the input data the user has entered.
function gatherUserInputData() 
	-- Axes to probe
	DATA.probeZAxis = true; -- Z-Axis is always probed
	if (UI.m_checkBoxXAxis:GetValue()) then
		DATA.probeXAxis = true
	else
		DATA.probeXAxis = false
	end
	if (UI.m_checkBoxYAxis:GetValue()) then
		DATA.probeYAxis = true
	else
		DATA.probeYAxis = false
	end
	
	-- Touch plate orientation
	DATA.orientation = UI.m_radioBoxOrient:GetSelection()
	
	-- Tool Diameter
	DATA.toolDiameter = tonumber(UI.m_textCtrlToolDiameter:GetValue())
	
	-- Unit of Measure
	if (UI.m_radioBtnMillimeters:GetValue()) then
		DATA.unitOfMeasure = MILLIMETERS
	else
		DATA.unitOfMeasure = INCHES
	end
	
	-- Pause Between Measures
	if (UI.m_checkBoxPauseBetweenAxes:GetValue()) then 
		DATA.pauseBetweenAxes = true
	else
		DATA.pauseBetweenAxes = false
	end
	
end -- END gatherUserInputData()


function isUserInputDataValid()
	
	-- ToolDiameter must be a valid number.
	if (DATA.toolDiameter== nil) then
		wx.wxMessageBox("Tool Diameter must be a valid number!", "Z-TouchPlate: Invalid Input")
		return false
	end
	
	-- ToolDiameter must greater than zero and less than the width 
	-- of the probing pad (handle both metric and imperial cases).
	local constants = getConstants()
	if (DATA.toolDiameter <= 0) then
		wx.wxMessageBox("Tool Diameter must be greater than zero!", "Z-TouchPlate: Invalid Input", wx.wxICON_ERROR)
		return false
	elseif (DATA.toolDiameter > constants.TOUCH_PLATE_PROBE_WIDTH) then
		wx.wxMessageBox("Tool Diameter cannot be greater than\nthe Touch Plate probing area!", "Z-TouchPlate: Invalid Input", wx.wxICON_ERROR)
		return false
	end
	-- All input is valid
	return true 
end -- END isUserInputDataValid()

function clearUserInputData()
	DATA.probeZAxis = nil
	DATA.probeXAxis = nil
	DATA.probeYAxis = nil
    DATA.orientation = nil
	DATA.toolDiameter = nil
	DATA.unitOfMeasure = nil
	DATA.pauseBetweenAxes = nil
end

-- Utility Method to help debug user input
function printUserData()
	local msg = "---------------------------------------------------\n" ..
	            "  Z-axis: \t" .. tostring(DATA.probeZAxis) .. "\n" ..
	            "  X-axis: \t" .. tostring(DATA.probeXAxis) .. "\n" ..
				"  Y-axis: \t" .. tostring(DATA.probeYAxis) .. "\n" ..
				"  Orient: \t" .. ORIENTATION[DATA.orientation] .. "\n" ..
				"Tool Dia: \t" .. DATA.toolDiameter .. "\n" ..
				"    Unit: \t" .. UNITS[DATA.unitOfMeasure] .. "\n" ..
				"   Pause: \t" .. tostring(DATA.pauseBetweenAxes) .. "\n" ..
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

	UI.bSizerMainFrameOuter = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.bSizerMainFrameInner = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.fgSizerMain = wx.wxFlexGridSizer( 2, 1, 0, 0 )
	UI.fgSizerMain:SetFlexibleDirection( wx.wxVERTICAL )
	UI.fgSizerMain:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.bSizerRowOne = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.gSizerThreeColumn = wx.wxGridSizer( 1, 3, 0, 0 )

	UI.sbSizerAxes = wx.wxStaticBoxSizer( wx.wxStaticBox( UI.m_MainPanel, wx.wxID_ANY, "Axes" ), wx.wxVERTICAL )

	UI.gSizerRadioAxes = wx.wxGridSizer( 3, 1, 0, 0 )
	
	UI.m_checkBoxZAxis = wx.wxCheckBox( UI.sbSizerAxes:GetStaticBox(), wx.wxID_ANY, "Z-Axis", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_checkBoxZAxis:SetValue(true)

	UI.gSizerRadioAxes:Add( UI.m_checkBoxZAxis, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_checkBoxXAxis = wx.wxCheckBox( UI.sbSizerAxes:GetStaticBox(), wx.wxID_ANY, "X-Axis", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizerRadioAxes:Add( UI.m_checkBoxXAxis, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_checkBoxYAxis = wx.wxCheckBox( UI.sbSizerAxes:GetStaticBox(), wx.wxID_ANY, "Y-Axis", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizerRadioAxes:Add( UI.m_checkBoxYAxis, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.sbSizerAxes:Add( UI.gSizerRadioAxes, 1, wx.wxEXPAND, 0 )


	UI.gSizerThreeColumn:Add( UI.sbSizerAxes, 1, wx.wxEXPAND, 0 )

	UI.gSizerOrinetation = wx.wxGridSizer( 4, 1, 0, 0 )
	
	UI.m_radioBoxOrientChoices = { "Left / Front", "Left / Rear", "Right / Front", "Right / Rear" }
	UI.m_radioBoxOrient = wx.wxRadioBox( UI.m_MainPanel, wx.wxID_ANY, "Orientation", wx.wxDefaultPosition, wx.wxSize( 125,-1 ), UI.m_radioBoxOrientChoices, 1, wx.wxRA_SPECIFY_COLS )
	UI.m_radioBoxOrient:SetSelection( 0 )
	UI.gSizerThreeColumn:Add( UI.m_radioBoxOrient, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 0 )

    UI.gSizerAction = wx.wxGridSizer( 2, 1, 20, 0 )

	UI.m_buttonRun = wx.wxButton( UI.m_MainPanel, wx.wxID_ANY, ACTION_BUTTON_TEXT, wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizerAction:Add( UI.m_buttonRun, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALIGN_TOP + wx.wxALL, 5 )

	UI.m_checkBoxPauseBetweenAxes = wx.wxCheckBox( UI.m_MainPanel, wx.wxID_ANY, "Pause Between Axes", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizerAction:Add( UI.m_checkBoxPauseBetweenAxes, 0, wx.wxALL, 5 )


	UI.gSizerThreeColumn:Add( UI.gSizerAction, 1, wx.wxALIGN_BOTTOM + wx.wxALIGN_RIGHT, 0 )


	UI.bSizerRowOne:Add( UI.gSizerThreeColumn, 1, wx.wxALL + wx.wxEXPAND, 0 )


	UI.fgSizerMain:Add( UI.bSizerRowOne, 1, wx.wxALIGN_CENTER_HORIZONTAL, 0 )

	UI.sbSizerRowTwo = wx.wxStaticBoxSizer( wx.wxStaticBox( UI.m_MainPanel, wx.wxID_ANY, "Tool Diameter" ), wx.wxVERTICAL )

	UI.bSizerRow2 = wx.wxBoxSizer( wx.wxHORIZONTAL )

	UI.m_staticTextToolDiameter = wx.wxStaticText( UI.sbSizerRowTwo:GetStaticBox(), wx.wxID_ANY, "Tool Diameter:", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextToolDiameter:Wrap( -1 )

	UI.bSizerRow2:Add( UI.m_staticTextToolDiameter, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 5 )

	UI.m_textCtrlToolDiameter = wx.wxTextCtrl( UI.sbSizerRowTwo:GetStaticBox(), wx.wxID_ANY, "0", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizerRow2:Add( UI.m_textCtrlToolDiameter, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 5 )

	UI.m_radioBtnInches = wx.wxRadioButton( UI.sbSizerRowTwo:GetStaticBox(), wx.wxID_ANY, "Inches", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizerRow2:Add( UI.m_radioBtnInches, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 5 )
	UI.m_radioBtnInches:SetValue(true)

	UI.m_radioBtnMillimeters = wx.wxRadioButton( UI.sbSizerRowTwo:GetStaticBox(), wx.wxID_ANY, "Millimeters", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizerRow2:Add( UI.m_radioBtnMillimeters, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 5 )


	UI.sbSizerRowTwo:Add( UI.bSizerRow2, 1, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALIGN_TOP, 0 )


	UI.fgSizerMain:Add( UI.sbSizerRowTwo, 1, wx.wxEXPAND, 5 )


	UI.m_MainPanel:SetSizer( UI.fgSizerMain )
	UI.m_MainPanel:Layout()
	UI.fgSizerMain:Fit( UI.m_MainPanel )
	UI.bSizerMainFrameInner:Add( UI.m_MainPanel, 1, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxEXPAND, 0 )


	UI.bSizerMainFrameOuter:Add( UI.bSizerMainFrameInner, 1, wx.wxALL + wx.wxEXPAND, 0 )

end -- END addWxWidgetComponents()

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