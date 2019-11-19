-- For ZeroBrane debugging.
package.path = package.path .. ";./ZeroBraneStudio/lualibs/mobdebug/?.lua;"

-- For installed modules support.
package.path = package.path .. ";./Modules/?.lua;"
package.cpath = package.cpath .. ";./Modules/?.dll;"

-- PMC genearated module load code.
package.path = package.path .. ";./Pmc/?.lua;"
package.path = package.path .. ";./Pmc/?.luac;"


-- PMC genearated module load code.
function Mach_Cycle_Pmc()
end

-- Screen load script (Global)
pageId = 0
screenId = 0
testcount = 0
machState = 0
machStateOld = -1
machEnabled = 0
machWasEnabled = 0
inst = mc.mcGetInstance()

Tframe = nil --TouchFrame handle

--mobdebug = require('mobdebug')
--mobdebug.onexit = mobdebug.done
--mobdebug.start()

---------------------------------------------------------------
-- Signal Library
---------------------------------------------------------------
SigLib = {
[mc.OSIG_MACHINE_ENABLED] = function (state)
	if (state == 1) then
		VfdFaultCheck();
	end
    machEnabled = state;
    ButtonEnable()
end,

[mc.ISIG_INPUT0] = function (state)
    
end,

[mc.ISIG_INPUT1] = function (state)
   -- if (state == 1) then   
--        CycleStart()
--    --else
--        --mc.mcCntlFeedHold (0)
--    end

end,

[mc.ISIG_INPUT8] = function (state)
    VfdFaultCheck();
end,

[mc.OSIG_JOG_CONT] = function (state)
    if( state == 1) then 
       scr.SetProperty('labJogMode', 'Label', 'Continuous');
       scr.SetProperty('txtJogInc', 'Bg Color', '#C0C0C0');--Light Grey
       scr.SetProperty('txtJogInc', 'Fg Color', '#808080');--Dark Grey
    end
end,

[mc.OSIG_JOG_INC] = function (state)
    if( state == 1) then
        scr.SetProperty('labJogMode', 'Label', 'Incremental');
        scr.SetProperty('txtJogInc', 'Bg Color', '#FFFFFF');--White    
        scr.SetProperty('txtJogInc', 'Fg Color', '#000000');--Black
   end
end,

[mc.OSIG_JOG_MPG] = function (state)
    if( state == 1) then
        scr.SetProperty('labJogMode', 'Label', '');
        scr.SetProperty('txtJogInc', 'Bg Color', '#C0C0C0');--Light Grey
        scr.SetProperty('txtJogInc', 'Fg Color', '#808080');--Dark Grey
        --add the bits to grey jog buttons becasue buttons can't be MPGs
    end
end


----M6 messagebox
--[mc.OSIG_TOOL_CHANGE] = function (state)
--    local selectedtool = mc.mcToolGetSelected(inst)
--	local currenttool = mc.mcToolGetCurrent(inst)
--	
--	if (selectedtool ~= currenttool) then
--        if( state == 1) then
--            mm.ToolChangeMsg("A tool change has been requested via M6. Change your tool then press Cycle Start to continue!", "Tool Change Active!")
--        end
--    end
--end
}

---------------------------------------------------------------
-- Keyboard Inputs Toggle() function. Updated 5-16-16
---------------------------------------------------------------
function KeyboardInputsToggle()
	local iReg = mc.mcIoGetHandle (inst, "Keyboard/Enable")
    local iReg2 = mc.mcIoGetHandle (inst, "Keyboard/EnableKeyboardJog")
	
	if (iReg ~= nil) and (iReg2 ~= nil) then
        local val = mc.mcIoGetState(iReg);
		if (val == 1) then
            mc.mcIoSetState(iReg, 0);
            mc.mcIoSetState(iReg2, 0);
			scr.SetProperty('btnKeyboardJog', 'Bg Color', '');
            scr.SetProperty('btnKeyboardJog', 'Label', 'Keyboard\nInputs Enable');
		else
            mc.mcIoSetState(iReg, 1);
            mc.mcIoSetState(iReg2, 1);
            scr.SetProperty('btnKeyboardJog', 'Bg Color', '#00FF00');
            scr.SetProperty('btnKeyboardJog', 'Label', 'Keyboard\nInputs Disable');
        end
	end
end

---------------------------------------------------------------
-- Remember Position function.
---------------------------------------------------------------
function RememberPosition()
    local pos = mc.mcAxisGetMachinePos(inst, 0) -- Get current X (0) Machine Coordinates
    mc.mcProfileWriteString(inst, "RememberPos", "X", string.format (pos)) --Create a register and write the machine coordinates to it
    local pos = mc.mcAxisGetMachinePos(inst, 1) -- Get current Y (1) Machine Coordinates
    mc.mcProfileWriteString(inst, "RememberPos", "Y", string.format (pos)) --Create a register and write the machine coordinates to it
    local pos = mc.mcAxisGetMachinePos(inst, 2) -- Get current Z (2) Machine Coordinates
    mc.mcProfileWriteString(inst, "RememberPos", "Z", string.format (pos)) --Create a register and write the machine coordinates to it
end

---------------------------------------------------------------
-- Return to Position function.
---------------------------------------------------------------
function ReturnToPosition()
    local xval = mc.mcProfileGetString(inst, "RememberPos", "X", "NotFound") -- Get the register Value
    local yval = mc.mcProfileGetString(inst, "RememberPos", "Y", "NotFound") -- Get the register Value
    local zval = mc.mcProfileGetString(inst, "RememberPos", "Z", "NotFound") -- Get the register Value
    
    if(xval == "NotFound")then -- check to see if the register is found
        wx.wxMessageBox('Register xval does not exist.\nYou must remember a postion before you can return to it.'); -- If the register does not exist tell us in a message box
    elseif (yval == "NotFound")then -- check to see if the register is found
        wx.wxMessageBox('Register yval does not exist.\nYou must remember a postion before you can return to it.'); -- If the register does not exist tell us in a message box
    elseif (zval == "NotFound")then -- check to see if the register is found
        wx.wxMessageBox('Register zval does not exist.\nYou must remember a postion before you can return to it.'); -- If the register does not exist tell us in a message box
    else
        mc.mcCntlMdiExecute(inst, "G00 G53 Z0.0000 \n G00 G53 X" .. xval .. "\n G00 G53 Y" .. yval .. "\n G00 G53 Z" .. zval)
    end
end

---------------------------------------------------------------
-- Spin CW function.
---------------------------------------------------------------
function SpinCW()
    local sigh = mc.mcSignalGetHandle(inst, mc.OSIG_SPINDLEON);
    local sigState = mc.mcSignalGetState(sigh);
    
    if (sigState == 1) then 
        mc.mcSpindleSetDirection(inst, 0);
    else 
        mc.mcSpindleSetDirection(inst, 1);
    end
end

---------------------------------------------------------------
-- Spin CCW function.
---------------------------------------------------------------
function SpinCCW()
    local sigh = mc.mcSignalGetHandle(inst, mc.OSIG_SPINDLEON);
    local sigState = mc.mcSignalGetState(sigh);
    
    if (sigState == 1) then 
        mc.mcSpindleSetDirection(inst, 0);
    else 
        mc.mcSpindleSetDirection(inst, -1);
    end
end

---------------------------------------------------------------
-- Open Docs function.
---------------------------------------------------------------
function OpenDocs()
    local major, minor = wx.wxGetOsVersion()
    local dir = mc.mcCntlGetMachDir(inst);
    local cmd = "explorer.exe /open," .. dir .. "\\Docs\\"
    if(minor <= 5) then -- Xp we don't need the /open
        cmd = "explorer.exe ," .. dir .. "\\Docs\\"
    end
    wx.wxExecute(cmd);
end

---------------------------------------------------------------
-- Cycle Stop function.
---------------------------------------------------------------
function CycleStop()
    mc.mcCntlCycleStop(inst);
    mc.mcSpindleSetDirection(inst, 0);
    mc.mcCntlSetLastError(inst, "Cycle Stopped");
end

---------------------------------------------------------------
-- Button Jog Mode Toggle() function.
---------------------------------------------------------------
function ButtonJogModeToggle()
    local cont = mc.mcSignalGetHandle(inst, mc.OSIG_JOG_CONT);
    local jogcont = mc.mcSignalGetState(cont)
    local inc = mc.mcSignalGetHandle(inst, mc.OSIG_JOG_INC);
    local joginc = mc.mcSignalGetState(inc)
    local mpg = mc.mcSignalGetHandle(inst, mc.OSIG_JOG_MPG);
    local jogmpg = mc.mcSignalGetState(mpg)
    
    if (jogcont == 1) then
        mc.mcSignalSetState(cont, 0)
        mc.mcSignalSetState(inc, 1)
        mc.mcSignalSetState(mpg, 0)        
    else
        mc.mcSignalSetState(cont, 1)
        mc.mcSignalSetState(inc, 0)
        mc.mcSignalSetState(mpg, 0)
    end

end

---------------------------------------------------------------
-- Ref All Home() function.
---------------------------------------------------------------
function RefAllHome()
    mc.mcAxisDerefAll(inst)  --Just to turn off all ref leds
    mc.mcAxisHomeAll(inst)
    coroutine.yield() --yield coroutine so we can do the following after motion stops
    ----See ref all home button and plc script for coroutine.create and coroutine.resume
    wx.wxMessageBox('Referencing is complete')
end

---------------------------------------------------------------
-- Go To Work Zero() function.
---------------------------------------------------------------
function GoToWorkZero()
    mc.mcCntlMdiExecute(inst, "G00 X0 Y0 A0")--Without Z moves
    --mc.mcCntlMdiExecute(inst, "G00 G53 Z0\nG00 X0 Y0 A0\nG00 Z0")--With Z moves
end

---------------------------------------------------------------
-- Cycle Start() function.
---------------------------------------------------------------
function CycleStart()
    local rc;
    local tab, rc = scr.GetProperty("MainTabs", "Current Tab")
    local tabG_Mdione, rc = scr.GetProperty("nbGCodeMDI1", "Current Tab")
    local tabG_Mditwo, rc = scr.GetProperty("nbGCodeMDI2", "Current Tab")
    
    --See if we have to do an MDI command and if so, which one
    if ((tonumber(tab) == 0 and tonumber(tabG_Mdione) == 1) or (tonumber(tab) == 2 and tonumber(tabG_Mditwo) == 1 )) then
        local state = mc.mcCntlGetState(inst);
        if (state == mc.MC_STATE_MRUN_MACROH) then 
            mc.mcCntlCycleStart(inst);
            --mc.mcCntlSetLastError(inst, "Do Cycle Start");
        else 
            if (tonumber(tab) == 0) then  
                scr.ExecMdi('mdi1');
                --mc.mcCntlSetLastError(inst, "Do MDI 1");
            else 
                scr.ExecMdi('mdi2');
                --mc.mcCntlSetLastError(inst, "Do MDI 2");
            end
        end
    elseif tonumber(tab) > 2 then --No G Code or MDI panel is displayed so Do Nothing
        --mc.mcCntlSetLastError(inst, "Nothing to Start");
    else --Do CycleStart
        --mc.mcCntlSetLastError(inst, "Do Cycle Start");
        mc.mcCntlCycleStart(inst);       
    end
end

-------------------------------------------------------
--  Seconds to time Added 5-9-16
-------------------------------------------------------
--Converts decimal seconds to an HH:MM:SS.xx format
function SecondsToTime(seconds)
	if seconds == 0 then
		return "00:00:00.00"
	else
		local hours = string.format("%02.f", math.floor(seconds/3600))
		local mins = string.format("%02.f", math.floor((seconds/60) - (hours*60)))
		local secs = string.format("%04.2f",(seconds - (hours*3600) - (mins*60)))
		return hours .. ":" .. mins .. ":" .. secs
	end
end


---------------------------------------------------------------
-- Check VFD for faults
-- The VFD continuously pulls PMDX-424's input pin #8 to ground
-- when the VFD is in 'No Fault' state. When a fault is reported
-- input pin #8 will loose continuity with ground and thus cause
-- the pin to go from state 1 to state 0. Mach4 should enter EStop
-- when this occurs.
---------------------------------------------------------------
function VfdFaultCheck()
	local handleI8 = mc.mcSignalGetHandle(inst, mc.ISIG_INPUT8);
	local stateI8 = mc.mcSignalGetState(handleI8);
	if (stateI8 ~= 1) then
		mc.mcCntlEStop(inst);
		mc.mcCntlSetLastError(inst, 'VFD reported a fault.');
	end
end
---------------------------------------------------------------
-- Set Button Jog Mode to Cont.
---------------------------------------------------------------
local cont = mc.mcSignalGetHandle(inst, mc.OSIG_JOG_CONT);
local jogcont = mc.mcSignalGetState(cont)
mc.mcSignalSetState(cont, 1)

---------------------------------------------------------------
--Timer panel example
---------------------------------------------------------------
TimerPanel = wx.wxPanel (wx.NULL, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 0,0 ) )
timer = wx.wxTimer(TimerPanel)
TimerPanel:Connect(wx.wxEVT_TIMER,
function (event)
    wx.wxMessageBox("Hello")
    timer:Stop()
end)

---------------------------------------------------------------
-- Load modules
---------------------------------------------------------------
--local inst = mc.mcGetInstance()
local profile = mc.mcProfileGetName(inst)
local machDir = mc.mcCntlGetMachDir(inst)
local paths = machDir .. "/Profiles/" .. profile .. "/Modules/?.lua" --Default location to look for modules with lua extensions
local cpaths = machDir .. "/Profiles/" .. profile .. "/Modules/?.dll" --Default location to look for modules with dll extensions

--Add additional paths locations to look in here
paths = paths .. ";" .. machDir .. "/Profiles/" .. profile .. "/Modules/?.mcs" --Lets also look here for modules with mcs extensions
paths = paths .. ";" .. machDir .. "/Modules/?.lua" --Lets add a location to look for modules with lua extensions
paths = paths .. ";" .. machDir .. "/Modules/?.mcs" --Lets add a location to look for modules with mcs extensions

--Check package.path to see if we need to add a ;
local MyS = package.path
local s = string.find(MyS, "%;") --Find the first ;

if (s ~=1) then --package.path does not begin with a ;
	paths = paths .. ";" --Add a ;
end

package.path = paths .. package.path --Do this only after you have built the string including all locations to look in

--Add additional cpaths locations to look in here
cpaths = cpaths ..  ";" .. machDir .. "/Modules/?.dll" --Lets add a location to look for modules with dll extensions

--Check package.cpath to see if we need to add a ;
MyS = package.cpath
s = string.find(MyS, "%;") --Find the first ;

if (s ~=1) then --package.path does not begin with a ;
	cpaths = cpaths .. ";" --Add a ;
end

package.cpath = cpaths .. package.cpath --Do this only after you have built the string including all locations to look in

--Master module
package.loaded.mcMasterModule = nil
mm = require "mcMasterModule"

--Probing module
package.loaded.Probing = nil
prb = require "mcProbing"
--mc.mcCntlSetLastError(inst, "Probe Version " .. prb.Version());

--AutoTool module
--package.loaded.AutoTool = nil
--at = require "mcAutoTool"

--ErrorCheck module Added 11-4-16
package.loaded.mcErrorCheck = nil
mcErrorCheck = require "mcErrorCheck"

---------------------------------------------------------------
-- Get fixtue offset pound variables function Updated 5-16-16
---------------------------------------------------------------
function GetFixOffsetVars()
    local FixOffset = mc.mcCntlGetPoundVar(inst, mc.SV_MOD_GROUP_14)
    local Pval = mc.mcCntlGetPoundVar(inst, mc.SV_BUFP)
    local FixNum, whole, frac

    if (FixOffset ~= 54.1) then --G54 through G59
        whole, frac = math.modf (FixOffset)
        FixNum = (whole - 53) 
        PoundVarX = ((mc.SV_FIXTURES_START - mc.SV_FIXTURES_INC) + (FixNum * mc.SV_FIXTURES_INC))
        CurrentFixture = string.format('G' .. tostring(FixOffset)) 
    else --G54.1 P1 through G54.1 P100
        FixNum = (Pval + 6)
        CurrentFixture = string.format('G54.1 P' .. tostring(Pval))
        if (Pval > 0) and (Pval < 51) then -- G54.1 P1 through G54.1 P50
            PoundVarX = ((mc.SV_FIXTURE_EXPAND - mc.SV_FIXTURES_INC) + (Pval * mc.SV_FIXTURES_INC))
        elseif (Pval > 50) and (Pval < 101) then -- G54.1 P51 through G54.1 P100
            PoundVarX = ((mc.SV_FIXTURE_EXPAND2 - mc.SV_FIXTURES_INC) + (Pval * mc.SV_FIXTURES_INC))	
        end
    end
PoundVarY = (PoundVarX + 1)
PoundVarZ = (PoundVarX + 2)
return PoundVarX, PoundVarY, PoundVarZ, FixNum, CurrentFixture
--PoundVar(Axis) returns the pound variable for the current fixture for that axis (not the pound variables value).
--CurretnFixture returned as a string (examples G54, G59, G54.1 P12).
--FixNum returns a simple number (1-106) for current fixture (examples G54 = 1, G59 = 6, G54.1 P1 = 7, etc).
end

---------------------------------------------------------------
-- Button Enable function Updated 11-8-2015
---------------------------------------------------------------
function ButtonEnable() --This function enables or disables buttons associated with an axis if the axis is enabled or disabled.

    AxisTable = {
        [0] = 'X',
        [1] = 'Y',
        [2] = 'Z',
        [3] = 'A',
        [4] = 'B',
        [5] = 'C'}
        
    for Num, Axis in pairs (AxisTable) do -- for each paired Num (key) and Axis (value) in the Axis table
        local rc = mc.mcAxisIsEnabled(inst,(Num)) -- find out if the axis is enabled, returns a 1 or 0
        scr.SetProperty((string.format ('btnPos' .. Axis)), 'Enabled', tostring(rc)); --Turn the jog positive button on or off
        scr.SetProperty((string.format ('btnNeg' .. Axis)), 'Enabled', tostring(rc)); --Turn the jog negative button on or off
        scr.SetProperty((string.format ('btnZero' .. Axis)), 'Enabled', tostring(rc)); --Turn the zero axis button on or off
        scr.SetProperty((string.format ('btnRef' .. Axis)), 'Enabled', tostring(rc)); --Turn the reference button on or off
    end
    
end

ButtonEnable()

-- PLC script
function Mach_PLC_Script()
    local inst = mc.mcGetInstance()
    local rc = 0;
    testcount = testcount + 1
    machState, rc = mc.mcCntlGetState(inst);
    local inCycle = mc.mcCntlIsInCycle(inst);
    
    -------------------------------------------------------
    --  Coroutine resume
    -------------------------------------------------------
    if (wait ~= nil) and (machState == 0) then --wait exist and state == idle
    	local state = coroutine.status(wait)
        if state == "suspended" then --wait is suspended
            coroutine.resume(wait)
        end
    end
    
    -------------------------------------------------------
    --  Cycle time label update
    -------------------------------------------------------
    --Requires a static text box named "CycleTime" on the screen
    if (machEnabled == 1) then
    	local cycletime = mc.mcCntlGetRunTime(inst, time)
    	scr.SetProperty("CycleTime", "Label", SecondsToTime(cycletime))
    end
    
    -------------------------------------------------------
    --  Set Height Offset Led
    -------------------------------------------------------
    local HOState = mc.mcCntlGetPoundVar(inst, 4008)
    if (HOState == 49) then
        scr.SetProperty("ledHOffset", "Value", "0")
    else
        scr.SetProperty("ledHOffset", "Value", "1")
    end
    
    -------------------------------------------------------
    --  Set Spindle Ratio DRO
    -------------------------------------------------------
    local spinmotormax = scr.GetProperty('droSpinMotorMax', 'Value');    
    local rangemax = scr.GetProperty('droRangeMax', 'Value');    
    local ratio = (rangemax / spinmotormax);    
    scr.SetProperty('droRatio', 'Value', tostring(ratio));
    
    -------------------------------------------------------
    --  Set Feedback Ratio DRO Updated 5-30-16
    -------------------------------------------------------
    local range, rc = mc.mcSpindleGetCurrentRange(inst)
    local fbratio, rc = mc.mcSpindleGetFeedbackRatio(inst, range)
    scr.SetProperty('droFeedbackRatio', 'Value', tostring(fbratio))
    
    -------------------------------------------------------
    --  PLC First Run
    -------------------------------------------------------
    if (testcount == 1) then --Set Keyboard input startup state
        local iReg = mc.mcIoGetHandle (inst, "Keyboard/Enable")
        mc.mcIoSetState(iReg, 1) --Set register to 1 to ensure KeyboardInputsToggle function will do a disable.
        KeyboardInputsToggle()
        
        --scr.SetProperty('btnCycleStart', 'Label', 'Cycle Start\nGcode')
        prb.LoadSettings()
    
    	---------------------------------------------------------------
    	-- Set Persistent DROs.
    	---------------------------------------------------------------
    
        DROTable = {
    	[1000] = "droJogRate", 
    	[1001] = "droSurfXPos", 
    	[1002] = "droSurfYPos", 
    	[1003] = "droSurfZPos",
        [1004] = "droInCornerX",
        [1005] = "droInCornerY",
        [1006] = "droInCornerSpaceX",
        [1007] = "droInCornerSpaceY",
        [1008] = "droOutCornerX",
        [1009] = "droOutCornerY",
        [1010] = "droOutCornerSpaceX",
        [1011] = "droOutCornerSpaceY",
        [1012] = "droInCenterWidth",
        [1013] = "droOutCenterWidth",
        [1014] = "droOutCenterAppr",
        [1015] = "droOutCenterZ",
        [1016] = "droBoreDiam",
        [1017] = "droBossDiam",
        [1018] = "droBossApproach",
        [1019] = "droBossZ",
        [1020] = "droAngleXpos",
        [1021] = "droAngleYInc",
        [1022] = "droAngleXCenterX",
        [1023] = "droAngleXCenterY",
        [1024] = "droAngleYpos",
        [1025] = "droAngleXInc",
        [1026] = "droAngleYCenterX",
        [1027] = "droAngleYCenterY",
        [1028] = "droCalZ",
        [1029] = "droGageX",
        [1030] = "droGageY",
        [1031] = "droGageZ",
        [1032] = "droGageSafeZ",
        [1033] = "droGageDiameter",
        [1034] = "droEdgeFinder",
        [1035] = "droGageBlock",
        [1036] = "droGageBlockT"
        }
    	
    	-- ******************************************************************************************* --
    	--  _   _   _  __          __             _____    _   _   _____   _   _    _____   _   _   _  --
    	-- | | | | | | \ \        / /     /\     |  __ \  | \ | | |_   _| | \ | |  / ____| | | | | | | --
    	-- | | | | | |  \ \  /\  / /     /  \    | |__) | |  \| |   | |   |  \| | | |  __  | | | | | | --
    	-- | | | | | |   \ \/  \/ /     / /\ \   |  _  /  | . ` |   | |   | . ` | | | |_ | | | | | | | --
    	-- |_| |_| |_|    \  /\  /     / ____ \  | | \ \  | |\  |  _| |_  | |\  | | |__| | |_| |_| |_| --
    	-- (_) (_) (_)     \/  \/     /_/    \_\ |_|  \_\ |_| \_| |_____| |_| \_|  \_____| (_) (_) (_) --
    	--                                                                                             --
    	-- The following is a loop. As a rule of thumb loops should be avoided in the PLC Script.      --
    	-- However, this loop only runs during the first run of the PLC script so it is acceptable.    --
    	-- ******************************************************************************************* --                                                          
    
        for name,number in pairs (DROTable) do -- for each paired name (key) and number (value) in the DRO table
            local droName = (DROTable[name]) -- make the variable named droName equal the name from the table above
            --wx.wxMessageBox (droName)
            local val = mc.mcProfileGetString(inst, "PersistentDROs", (droName), "NotFound") -- Get the Value from the profile ini
            if(val ~= "NotFound")then -- If the value is not equal to NotFound
                scr.SetProperty((droName), "Value", val) -- Set the dros value to the value from the profile ini
            end -- End the If statement
        end -- End the For loop
        ---------------------------------------------------
    
    end
    -------------------------------------------------------
    
    --if mc.mcSignalGetState (mc.mcSignalGetHandle (inst, mc.ISIG_INPUT63)) == 1 then
    --    -- mcSignalWait(inst, ISIG_INPUT63, WAIT_MODE_Low, 0)
    --    mc.mcCntlFeedHold (inst)
    --else
    --    --  Do something else
    --end
    
    --This is the last thing we do.  So keep it at the end of the script!
    machStateOld = machState;
    machWasEnabled = machEnabled;
    
end

-- Signal script
function Mach_Signal_Script(sig, state)
    if SigLib[sig] ~= nil then
        SigLib[sig](state);
    end
end

-- Timer script
-- 'timer' contains the timer number that fired the script.
function Mach_Timer_Script(timer)
    
end

-- Screen unload script
function Mach_Screen_Unload_Script()
    --Screen unload
    if (Tframe ~= nil) then
    
    	Tframe:Close()
        Tframe:Destroy()
    
    end
    
    --inst = mc.mcGetInstance()
    --
    --if (Tframe ~= nil) then 
    --    Tframe:Close()
    --    Tframe:Destroy()
    --end
    
end

function btnCycleStart_Left_Up_Script(...)
    CycleStart()
    
end
function btnStop_Left_Up_Script(...)
    CycleStop()
    --local inst = mc.mcGetInstance();
    --mc.mcCntlCycleStop(inst);
    --mc.mcSpindleSetDirection(inst, 0);
    --mc.mcCntlSetLastError("Cycle Stopped");
    
    --if not idle loop
    --mc.mcCntlMdiExecute ("G01 G53 Z0.000");
    
    --local inst = mc.mcGetInstance()
    --mc.mcCntlMdiExecute(inst, "G00 G53 Z0\nG00 X0 Y0 A0\nG00 Z0")
    
end
function btnReset_Left_Up_Script(...)
    local inst = mc.mcGetInstance()
    mc.mcCntlReset(inst)
    mc.mcSpindleSetDirection(inst, 0)
    mc.mcCntlSetLastError(inst, '')
end
function btnHelpDocs_Left_Up_Script(...)
    OpenDocs()
    --local inst = mc.mcGetInstance()
    --local dir = mc.mcCntlGetMachDir(inst);
    --wx.wxExecute("explorer.exe /open," .. dir .. "\\Docs\\");
    
end
function btnNewestAddition_Clicked_Script(...)
    if (inst == nil) then
        inst = mc.mcGetInstance()
    end
    MachDirectory = mc.mcCntlGetMachDir(inst)
    Profile = mc.mcProfileGetName(inst)
    ScriptDirectory = MachDirectory .. "\\Modules\\AddOns\\FontEngraving\\"
    
    package.path = ScriptDirectory .. "?.lua"
    package.loaded.mcFPanel = nil
    f = require "mcFPanel"
    
    f.Panel()
end
function btnDispLeft_Left_Up_Script(...)
    -- Left
    local inst = mc.mcGetInstance();
    local rc = scr.SetProperty("toolpath1", "View", "2")
    local rc = scr.SetProperty("toolpath2", "View", "2")
    local rc = scr.SetProperty("toolpath3", "View", "2")
    local rc = scr.SetProperty("toolpath4", "View", "2")
    local rc = scr.SetProperty("toolpath5", "View", "2")
    
end
function btnDispISO_Left_Up_Script(...)
    -- ISO
    local inst = mc.mcGetInstance();
    local rc = scr.SetProperty("toolpath1", "View", "4")
    local rc = scr.SetProperty("toolpath2", "View", "4")
    local rc = scr.SetProperty("toolpath3", "View", "4")
    local rc = scr.SetProperty("toolpath4", "View", "4")
    local rc = scr.SetProperty("toolpath5", "View", "4")
end
function btnDispTop_Left_Up_Script(...)
    --Top
    local inst = mc.mcGetInstance();
    local rc = scr.SetProperty("toolpath1", "View", "0")
    local rc = scr.SetProperty("toolpath2", "View", "0")
    local rc = scr.SetProperty("toolpath3", "View", "0")
    local rc = scr.SetProperty("toolpath4", "View", "0")
    local rc = scr.SetProperty("toolpath5", "View", "0")
end
function btnDispBottom_Left_Up_Script(...)
    -- Bottom
    local inst = mc.mcGetInstance();
    local rc = scr.SetProperty("toolpath1", "View", "1")
    local rc = scr.SetProperty("toolpath2", "View", "1")
    local rc = scr.SetProperty("toolpath3", "View", "1")
    local rc = scr.SetProperty("toolpath4", "View", "1")
    local rc = scr.SetProperty("toolpath5", "View", "1")
end
function btnDispRight_Left_Up_Script(...)
    -- Right
    local inst = mc.mcGetInstance();
    local rc = scr.SetProperty("toolpath1", "View", "3")
    local rc = scr.SetProperty("toolpath2", "View", "3")
    local rc = scr.SetProperty("toolpath3", "View", "3")
    local rc = scr.SetProperty("toolpath4", "View", "3")
    local rc = scr.SetProperty("toolpath5", "View", "3")
end
function btnToggleJogMode_Left_Up_Script(...)
    ButtonJogModeToggle()
end
function btnKeyboardJog_Left_Up_Script(...)
    KeyboardInputsToggle()
end
function droJogRate_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    local val = scr.GetProperty("droJogRate", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droJogRate", string.format (val)) --Create a register and write the machine coordinates to it
end
function tabPositionsExtens_On_Enter_Script(...)
    local rc;
    local tabG_Mdi, rc = scr.GetProperty("nbGCodeMDI1", "Current Tab")
    
    --See if we have to do an MDI command
    if (tonumber(tabG_Mdi) == 1 ) then
        scr.SetProperty('btnCycleStart', 'Label', 'Cycle Start\nMDI');
    else
        scr.SetProperty('btnCycleStart', 'Label', 'Cycle Start\nGcode');
    end
end
function btnRefAll_Left_Up_Script(...)
    --RefAllHome()
    wait = coroutine.create (RefAllHome) --Run the RefAllHome function as a coroutine named wait.
    --See RefAllHome function in screen load script for coroutine.yield and PLC script for coroutine.resume
end
function btnDerefAll_Left_Up_Script(...)
    local inst = mc.mcGetInstance();
    mc.mcAxisDerefAll(inst);
end
function btnGotoZero_Left_Up_Script(...)
    GoToWorkZero()
    --local inst = mc.mcGetInstance()
    --mc.mcCntlMdiExecute(inst, "G00 G53 Z0\nG00 X0 Y0 A0\nG00 Z0")
    
end
function nbGCodeInput1_On_Enter_Script(...)
     scr.SetProperty('btnCycleStart', 'Label', 'Cycle Start\nGcode');
end
function nbMDIInput1_On_Enter_Script(...)
    scr.SetProperty('btnCycleStart', 'Label', 'Cycle Start\nMDI');
end
function tabToolPath_On_Enter_Script(...)
     scr.SetProperty('btnCycleStart', 'Label', 'Cycle Start\nGcode');
end
function tabDiag_On_Enter_Script(...)
    local rc;
    local tabG_Mdi, rc = scr.GetProperty("nbGCodeMDI2", "Current Tab")
    
    --See if we have to do an MDI command
    if (tonumber(tabG_Mdi) == 1 ) then
        scr.SetProperty('btnCycleStart', 'Label', 'Cycle Start\nMDI');
    else
        scr.SetProperty('btnCycleStart', 'Label', 'Cycle Start\nGcode');
    end
end
function btnRefAllDiag_Left_Up_Script(...)
    --RefAllHome()
    wait = coroutine.create (RefAllHome) --Run the RefAllHome function as a coroutine named wait.
    --See RefAllHome function in screen load script for coroutine.yield and PLC script for coroutine.resume
end
function btnRefX_Left_Up_Script(...)
    --local inst = mc.mcGetInstance ()
    --mc.mcCntlGcodeExecuteWait(inst, 'M07')
    --mc.mcAxisHome(inst, 0)
    --repeat
    --wx.wxMilliSleep(200)
    --local homing, rc= mc.mcAxisIsHoming(inst, 0)
    --until homing == 0
    --mc.mcCntlGcodeExecuteWait(inst, 'M09')
    
end
function nbGCodeInput2_On_Enter_Script(...)
     scr.SetProperty('btnCycleStart', 'Label', 'Cycle Start\nGcode');
end
function nbMDIInput2_On_Enter_Script(...)
    scr.SetProperty('btnCycleStart', 'Label', 'Cycle Start\nMDI');
end
function droSurfYPos_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droSurfYPos", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droSurfYPos", string.format (val)) --Create a register and write the machine coordinates to it
    
end
function btnSurfY_Clicked_Script(...)
    --Single Surface Measure Y button
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local ypos = scr.GetProperty("droSurfYPos", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.SingleSurfY (ypos, work)
end
function btnSurfYHelp_Clicked_Script(...)
    prb.SingleSurfHelp()
    
end
function droSurfZPos_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droSurfZPos", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droSurfZPos", string.format (val)) --Create a register and write to it
end
function btnSurfZ_Clicked_Script(...)
    --Single Surface Measure Z button
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local zpos = scr.GetProperty("droSurfZPos", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.SingleSurfZ (zpos, work)
end
function btnSurfZHelp_Clicked_Script(...)
    prb.SingleSurfHelp()
    
end
function droSurfXPos_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droSurfXPos", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droSurfXPos", string.format (val)) --Create a register and write the machine coordinates to it
    
end
function btnSurfX_Clicked_Script(...)
    --Single Surface Measure X button
    --PRIVATE
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    --Probing module
    package.loaded.Probing = nil
    
    local prb = require "mcProbing"
    
    local xpos = scr.GetProperty("droSurfXPos", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.SingleSurfX (xpos, work)
end
function btnSurfXHelp_Clicked_Script(...)
    prb.SingleSurfHelp()
    
end
function droInCornerX_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droInCornerX", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droInCornerX", string.format (val)) --Create a register and write to it
end
function droInCornerY_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droInCornerY", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droInCornerY", string.format (val)) --Create a register and write to it
end
function droInCornerSpaceX_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droInCornerSpaceX", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droInCornerSpaceX", string.format (val)) --Create a register and write to it
end
function droInCornerSpaceY_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droInCornerSpaceY", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droInCornerSpaceY", string.format (val)) --Create a register and write to it
end
function btnInCorner_Clicked_Script(...)
    --Corners inner measure button
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local xpos = scr.GetProperty("droInCornerX", "Value")
    local ypos = scr.GetProperty("droInCornerY", "Value")
    local xinc = scr.GetProperty("droInCornerSpaceY", "Value")
    local yinc = scr.GetProperty("droInCornerSpaceX", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.InternalCorner (xpos, ypos, xinc, yinc, work)
end
function btnInCornerHelp_Clicked_Script(...)
    prb.InsideCornerHelp()
    
end
function droOutCornerX_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droOutCornerX", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droOutCornerX", string.format (val)) --Create a register and write to it
end
function droOutCornerY_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droOutCornerY", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droOutCornerY", string.format (val)) --Create a register and write to it
end
function droOutCornerSpaceX_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droOutCornerSpaceX", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droOutCornerSpaceX", string.format (val)) --Create a register and write to it
end
function droOutCornerSpaceY_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droOutCornerSpaceY", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droOutCornerSpaceY", string.format (val)) --Create a register and write to it
end
function btnOutCorner_Clicked_Script(...)
    -- Outside corner Measure
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local xpos = scr.GetProperty("droOutCornerX", "Value")
    local ypos = scr.GetProperty("droOutCornerY", "Value")
    local xinc = scr.GetProperty("droOutCornerSpaceY", "Value")
    local yinc = scr.GetProperty("droOutCornerSpaceX", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.ExternalCorner (xpos, ypos, xinc, yinc, work)
    
end
function btnOutCornerHelp_Clicked_Script(...)
    prb.OutsideCornerHelp()
    
end
function droInCenterWidth_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droInCenterWidth", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droInCenterWidth", string.format (val)) --Create a register and write to it
end
function btnInCenterX_Clicked_Script(...)
    -- Inside X centering
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local width = scr.GetProperty("droInCenterWidth", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.InsideCenteringX (width, work)
end
function btnInCenterY_Clicked_Script(...)
    -- Inside Y centering
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local width = scr.GetProperty("droInCenterWidth", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.InsideCenteringY (width, work)
end
function btnInCenterHelp_Clicked_Script(...)
    prb.InsideCenteringHelp()
    
end
function droOutCenterWidth_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droOutCenterWidth", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droOutCenterWidth", string.format (val)) --Create a register and write to it
end
function droOutCenterAppr_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droOutCenterAppr", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droOutCenterAppr", string.format (val)) --Create a register and write to it
end
function droOutCenterZ_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droOutCenterZ", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droOutCenterZ", string.format (val)) --Create a register and write to it
end
function btnOutCenterX_Clicked_Script(...)
    -- Outside X centering
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local width = scr.GetProperty("droOutCenterWidth", "Value")
    local approach = scr.GetProperty("droOutCenterAppr", "Value")
    local zpos = scr.GetProperty("droOutCenterZ", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.OutsideCenteringX (width, approach, zpos, work)
end
function btnOutCenterY_Clicked_Script(...)
    -- Outside Y centering
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local width = scr.GetProperty("droOutCenterWidth", "Value")
    local approach = scr.GetProperty("droOutCenterAppr", "Value")
    local zpos = scr.GetProperty("droOutCenterZ", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.OutsideCenteringY (width, approach, zpos, work)
end
function btnOutCenterHelp_Clicked_Script(...)
    prb.OutsideCenteringHelp()
    
end
function droBoreDiam_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droBoreDiam", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droBoreDiam", string.format (val)) --Create a register and write to it
end
function btnBore_Clicked_Script(...)
    -- Bore Dia Measure
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local diam = scr.GetProperty("droBoreDiam", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.Bore (diam, work)
    
end
function btnInCornerHelp_1__Clicked_Script(...)
    prb.BoreHelp()
    
end
function droBossDiam_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droBossDiam", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droBossDiam", string.format (val)) --Create a register and write to it
end
function droBossApproach_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droBossApproach", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droBossApproach", string.format (val)) --Create a register and write to it
end
function droBossZ_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droBossZ", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droBossZ", string.format (val)) --Create a register and write to it
end
function btnBoss_Clicked_Script(...)
    -- Boss Diam Measure
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local diam = scr.GetProperty("droBossDiam", "Value")
    local approach = scr.GetProperty("droBossApproach", "Value")
    local zpos = scr.GetProperty("droBossZ", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.Boss (diam, approach, zpos, work)
end
function btnInCornerHelp_2__Clicked_Script(...)
    prb.BossHelp()
    
end
function droAngleXpos_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droAngleXpos", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droAngleXpos", string.format (val)) --Create a register and write to it
end
function droAngleYInc_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droAngleYInc", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droAngleYInc", string.format (val)) --Create a register and write to it
end
function droAngleXCenterX_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droAngleXCenterX", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droAngleXCenterX", string.format (val)) --Create a register and write to it
end
function droAngleXCenterY_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droAngleXCenterY", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droAngleXCenterY", string.format (val)) --Create a register and write to it
end
function btnAngleX_Clicked_Script(...)
    --Single Angle X
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
     
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local pos = scr.GetProperty("droAngleXpos", "Value")
    local inc = scr.GetProperty("droAngleYInc", "Value")
    local xcntr = scr.GetProperty("droAngleXCenterX", "Value")
    local ycntr = scr.GetProperty("droAngleXCenterY", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.SingleAngleX (pos, inc, xcntr, ycntr, work)
end
function btnAngleXHelp_Clicked_Script(...)
    prb.SingleAngleHelp()
    
end
function droAngleYpos_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droAngleYpos", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droAngleYpos", string.format (val)) --Create a register and write to it
end
function droAngleXInc_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droAngleXInc", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droAngleXInc", string.format (val)) --Create a register and write to it
end
function droAngleYCenterX_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droAngleYCenterX", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droAngleYCenterX", string.format (val)) --Create a register and write to it
end
function droAngleYCenterY_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droAngleYCenterY", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droAngleYCenterY", string.format (val)) --Create a register and write to it
end
function btnAngleY_Clicked_Script(...)
    --Single angle Y
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local pos = scr.GetProperty("droAngleYpos", "Value")
    local inc = scr.GetProperty("droAngleXInc", "Value")
    local xcntr = scr.GetProperty("droAngleXCenterX", "Value")
    local ycntr = scr.GetProperty("droAngleXCenterY", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.SingleAngleY (pos, inc, xcntr, ycntr, work)
end
function btnAngleYHelp_Clicked_Script(...)
    prb.SingleAngleHelp()
    
end
function droCalZ_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droCalZ", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droCalZ", string.format (val)) --Create a register and write to it
end
function btnProbeCalZ_Clicked_Script(...)
    --Calibrate Z
    
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local zpos = scr.GetProperty("droCalZ", "Value")
    
    prb.LengthCal (zpos)
end
function btnCalZHelp_Clicked_Script(...)
    prb.LengthCalHelp()
end
function droGageX_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droGageX", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droGageX", string.format (val)) --Create a register and write to it
end
function droGageY_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droGageY", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droGageY", string.format (val)) --Create a register and write to it
end
function droGageZ_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droGageZ", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droGageZ", string.format (val)) --Create a register and write to it
end
function droGageSafeZ_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droGageSafeZ", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droGageSafeZ", string.format (val)) --Create a register and write to it
end
function droGageDiameter_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droGageDiameter", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droGageDiameter", string.format (val)) --Create a register and write to it
end
function btnProbeCalXY_Clicked_Script(...)
    --Calibrate XY Offset
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local xpos = scr.GetProperty("droGageX", "Value")
    local ypos = scr.GetProperty("droGageY", "Value")
    local diam = scr.GetProperty("droGageDiameter", "Value")
    local zpos = scr.GetProperty("droGageZ", "Value")
    local safez = scr.GetProperty("droGageSafeZ", "Value")
    
    prb.XYOffsetCal (xpos, ypos, diam, zpos , safez) 
end
function btnProbeCalRad_Clicked_Script(...)
    --Calibrate Radius
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local xpos = scr.GetProperty("droGageX", "Value")
    local ypos = scr.GetProperty("droGageY", "Value")
    local zpos = scr.GetProperty("droGageZ", "Value")
    local diam = scr.GetProperty("droGageDiameter", "Value")
    local safez = scr.GetProperty("droGageSafeZ", "Value")
    
    prb.RadiusCal (xpos, ypos, diam, zpos, safez)
end
function btnXYRadHelp__Clicked_Script(...)
    prb.XYRadCalHelp()
end
function droPrbOffNum_On_Modify_Script(...)
    local val = scr.GetProperty("droPrbOffNum", "Value")
    mc.mcProfileWriteString(inst, "ProbingSettings", "OffsetNum", tostring(val))
    mc.mcCntlSetLastError(inst, "Probe: Offset number updated")
end
function droPrbGcode_On_Modify_Script(...)
    local val = scr.GetProperty("droPrbGcode", "Value")
    mc.mcProfileWriteString(inst, "ProbingSettings", "GCode", tostring(val))
    mc.mcCntlSetLastError(inst, "Probe: G code updated")
end
function droSlowFeed_On_Modify_Script(...)
    local val = scr.GetProperty("droSlowFeed", "Value")
    mc.mcProfileWriteString(inst, "ProbingSettings", "SlowFeed", tostring(val))
    mc.mcCntlSetLastError(inst, "Probe: Slow measure feedrate updated")
end
function droFastFeed_On_Modify_Script(...)
    local val = scr.GetProperty("droFastFeed", "Value")
    mc.mcProfileWriteString(inst, "ProbingSettings", "FastFeed", tostring(val))
    mc.mcCntlSetLastError(inst, "Probe: Fast find feedrate updated")
end
function droBackOff_On_Modify_Script(...)
    local val = scr.GetProperty("droBackOff", "Value")
    mc.mcProfileWriteString(inst, "ProbingSettings", "BackOff", tostring(val))
    mc.mcCntlSetLastError(inst, "Probe: Retract amount updated")
end
function droOverShoot_On_Modify_Script(...)
    local val = scr.GetProperty("droOverShoot", "Value")
    mc.mcProfileWriteString(inst, "ProbingSettings", "OverShoot", tostring(val))
    mc.mcCntlSetLastError(inst, "Probe: Overshoot amount")
end
function droPrbInPos_On_Modify_Script(...)
    local val = scr.GetProperty("droPrbInPos", "Value")
    mc.mcProfileWriteString(inst, "ProbingSettings", "InPosZone", tostring(val))
    mc.mcCntlSetLastError(inst, "Probe: In position tolerance updated")
end
function btnPrbSettingsHelp_Clicked_Script(...)
    prb.SettingsHelp()
end
function btnMeasType_Clicked_Script(...)
    --Set probing measurment type
    
    local inst = mc.mcGetInstance()
    local MeasureOnlyLED = scr.GetProperty("ledMeasOnly", "Value")
    
    if (MeasureOnlyLED == "1") then
        scr.SetProperty("ledMeasOnly", "Value", "0")
        scr.SetProperty("ledSetWork", "Value", "1")
    else
        scr.SetProperty("ledMeasOnly", "Value", "1")
        scr.SetProperty("ledSetWork", "Value", "0")
    end
end
function btnResultsHelp_Clicked_Script(...)
    prb.ResultsHelp()
end
function tabOffsets_On_Enter_Script(...)
    local FixOffset = mc.mcCntlGetPoundVar(inst, 4014)
    FixOffset = 53 + (FixOffset * 10)
    local Fixture = 54
    
    while (Fixture <= 59) do
        local state = "0"
        if (Fixture == FixOffset) then
            state = "1"
        end
        scr.SetProperty(string.format("tbtnG%.0f", Fixture), "Button State", state)
        Fixture = Fixture + 1
    end
    
end
function droEdgeFinder_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droEdgeFinder", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droEdgeFinder", string.format (val)) --Create a register and write to it
    
    --local val = scr.GetProperty("droEdgeFinder", "Value")
    --mc.mcProfileWriteString(inst, "OffsetsSettings", "EdgeFinder", tostring(val))
    --mc.mcCntlSetLastError(inst, "Offsets: Edge finder diameter updated")
    
end
function btnYTop_Clicked_Script(...)
    -- Touch Y positive button
    ---------------------------------------------------------------
    -- Load modules
    ---------------------------------------------------------------
    
    --    local inst = mc.mcGetInstance()
    --    local profile = mc.mcProfileGetName(inst)
    --    local path = mc.mcCntlGetMachDir(inst)
    --    package.path = path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;" .. path .. "\\Modules\\?.lua;"
    --    --TouchOff module
    --    package.loaded.mcTouchOff = nil
    --    
    --    local touch = require "mcTouchOff"
    --    
    --    touch.TouchYPos () -- Run the TouchYPositive function from the mcTouchOff module
    
    
    --Touch Y+ button
    local inst = mc.mcGetInstance()
    local EdgeFinder = scr.GetProperty("droEdgeFinder", "Value")
    EdgeFinder = tonumber(EdgeFinder)
    local YPos = mc.mcAxisGetMachinePos(inst, mc.Y_AXIS)
    XVar, YVar, ZVar = GetFixOffsetVars()
    local OffsetVal = YPos - (EdgeFinder/2)
    mc.mcCntlSetPoundVar(inst, YVar, OffsetVal)
    mc.mcCntlSetLastError(inst, string.format("Y Offset Set: %.4f", OffsetVal))
    
end
function btnXLeft_Clicked_Script(...)
    --Touch X- button
    ---------------------------------------------------------------
    -- Load modules
    ---------------------------------------------------------------
    --    local inst = mc.mcGetInstance()
    --    local profile = mc.mcProfileGetName(inst)
    --    local path = mc.mcCntlGetMachDir(inst)
    --    package.path = path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;" .. path .. "\\Modules\\?.lua;"
    --    --TouchOff module
    --    package.loaded.mcTouchOff = nil
    --    
    --    local touch = require "mcTouchOff"
    --    
    --    touch.TouchXNeg () -- Run the TouchXNegative function from the mcTouchOff module
    
    
    --Touch X- button
    
    local inst = mc.mcGetInstance()
    local EdgeFinder = scr.GetProperty("droEdgeFinder", "Value")
    EdgeFinder = tonumber(EdgeFinder)
    local XPos = mc.mcAxisGetMachinePos(inst, mc.X_AXIS)
    XVar, YVar, ZVar = GetFixOffsetVars()
    local OffsetVal = XPos + (EdgeFinder/2)
    mc.mcCntlSetPoundVar(inst, XVar, OffsetVal)
    mc.mcCntlSetLastError(inst, string.format("X Offset Set: %.4f", OffsetVal))
    
end
function btnYBottom_Clicked_Script(...)
    -- Touch Y negative button
    ---------------------------------------------------------------
    -- Load modules
    ---------------------------------------------------------------
    --    local inst = mc.mcGetInstance()
    --    local profile = mc.mcProfileGetName(inst)
    --    local path = mc.mcCntlGetMachDir(inst)
    --    package.path = path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;" .. path .. "\\Modules\\?.lua;"
    --    --TouchOff module
    --    package.loaded.mcTouchOff = nil
    --    
    --    local touch = require "mcTouchOff"
    --    
    --    touch.TouchYNeg () -- Run the TouchYNegative function from the mcTouchOff module
    
    
    --Touch Y- button
    			  
    local inst = mc.mcGetInstance()
    local EdgeFinder = scr.GetProperty("droEdgeFinder", "Value")
    EdgeFinder = tonumber(EdgeFinder)
    local YPos = mc.mcAxisGetMachinePos(inst, mc.Y_AXIS)
    XVar, YVar, ZVar = GetFixOffsetVars()
    local OffsetVal = YPos + (EdgeFinder/2)
    mc.mcCntlSetPoundVar(inst, YVar, OffsetVal)
    mc.mcCntlSetLastError(inst, string.format("Y Offset Set: %.4f", OffsetVal))
    
    
end
function btnXRight_Clicked_Script(...)
    --Touch X+ button
    ---------------------------------------------------------------
    -- Load modules
    ---------------------------------------------------------------
    --    local inst = mc.mcGetInstance()
    --    local profile = mc.mcProfileGetName(inst)
    --    local path = mc.mcCntlGetMachDir(inst)
    --    package.path = path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;" .. path .. "\\Modules\\?.lua;"
    --    --TouchOff module
    --    package.loaded.mcTouchOff = nil
    --    
    --    local touch = require "mcTouchOff"
    --    
    --    touch.TouchXPos () -- Run the TouchXPosotive function from the mcTouchOff module
    
    
    --Touch X+ button
    
    local inst = mc.mcGetInstance()
    local EdgeFinder = scr.GetProperty("droEdgeFinder", "Value")
    EdgeFinder = tonumber(EdgeFinder)
    local XPos = mc.mcAxisGetMachinePos(inst, mc.X_AXIS)
    XVar, YVar, ZVar = GetFixOffsetVars()
    local OffsetVal = XPos - (EdgeFinder/2)
    mc.mcCntlSetPoundVar(inst, XVar, OffsetVal)
    mc.mcCntlSetLastError(inst, string.format("X Offset Set: %.4f", OffsetVal))
    
end
function btnSetCenter_Clicked_Script(...)
    --Set Center button
    
    local XPos = mc.mcAxisGetMachinePos(inst, mc.X_AXIS)
    local YPos = mc.mcAxisGetMachinePos(inst, mc.Y_AXIS)
    XVar, YVar, ZVar = GetFixOffsetVars()
    mc.mcCntlSetPoundVar(inst, XVar, XPos)
    mc.mcCntlSetPoundVar(inst, YVar, YPos)
    mc.mcCntlSetLastError(inst, string.format("X Offset Set: %.4f | Y Offset Set: %.4f", XPos, YPos))
    
end
function tbtnG59_Down_Script(...)
    local set = 59
    mc.mcCntlMdiExecute(inst, string.format("G%.0f", set))
    local button = 54
    while (button <= 59) do
        if (button ~= set) then
            scr.SetProperty(string.format("tbtnG%.0f", button), "Button State", "0")
        end
        button = button + 1
    end
    mc.mcCntlSetLastError(inst, string.format("Fixture Offset Set: G%.0f", set))
end
function tbtnG54_Down_Script(...)
    local set = 54
    mc.mcCntlMdiExecute(inst, string.format("G%.0f", set))
    local button = 54
    while (button <= 59) do
        if (button ~= set) then
            scr.SetProperty(string.format("tbtnG%.0f", button), "Button State", "0")
        end
        button = button + 1
    end
    mc.mcCntlSetLastError(inst, string.format("Fixture Offset Set: G%.0f", set))
end
function tbtnG55_Down_Script(...)
    local set = 55
    mc.mcCntlMdiExecute(inst, string.format("G%.0f", set))
    local button = 54
    while (button <= 59) do
        if (button ~= set) then
            scr.SetProperty(string.format("tbtnG%.0f", button), "Button State", "0")
        end
        button = button + 1
    end
    mc.mcCntlSetLastError(inst, string.format("Fixture Offset Set: G%.0f", set))
end
function tbtnG56_Down_Script(...)
    local set = 56
    mc.mcCntlMdiExecute(inst, string.format("G%.0f", set))
    local button = 54
    while (button <= 59) do
        if (button ~= set) then
            scr.SetProperty(string.format("tbtnG%.0f", button), "Button State", "0")
        end
        button = button + 1
    end
    mc.mcCntlSetLastError(inst, string.format("Fixture Offset Set: G%.0f", set))
end
function tbtnG57_Down_Script(...)
    local set = 57
    mc.mcCntlMdiExecute(inst, string.format("G%.0f", set))
    local button = 54
    while (button <= 59) do
        if (button ~= set) then
            scr.SetProperty(string.format("tbtnG%.0f", button), "Button State", "0")
        end
        button = button + 1
    end
    mc.mcCntlSetLastError(inst, string.format("Fixture Offset Set: G%.0f", set))
end
function tbtnG58_Down_Script(...)
    local set = 58
    mc.mcCntlMdiExecute(inst, string.format("G%.0f", set))
    local button = 54
    while (button <= 59) do
        if (button ~= set) then
            scr.SetProperty(string.format("tbtnG%.0f", button), "Button State", "0")
        end
        button = button + 1
    end
    mc.mcCntlSetLastError(inst, string.format("Fixture Offset Set: G%.0f", set))
end
function droGageBlock_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droGageBlock", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droGageBlock", string.format (val)) --Create a register and write to it
    
    --local val = scr.GetProperty("droGageBlock", "Value")
    --mc.mcProfileWriteString(inst, "OffsetsSettings", "GageBlock", tostring(val))
    --mc.mcCntlSetLastError(inst, "Offsets: Fixture Z Gage block updated")
    
end
function btnSetZ_Clicked_Script(...)
    -- Set Z button
    ---------------------------------------------------------------
    -- Load modules
    ---------------------------------------------------------------
    --    local inst = mc.mcGetInstance()
    --    local profile = mc.mcProfileGetName(inst)
    --    local path = mc.mcCntlGetMachDir(inst)
    --    package.path = path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;" .. path .. "\\Modules\\?.lua;"
    --    --TouchOff module
    --    package.loaded.mcTouchOff = nil
    --    
    --    local touch = require "mcTouchOff"
    --    
    --    touch.TouchZNeg()
    
    
    --Set Z button
    
    local inst = mc.mcGetInstance()			  
    local GageBlock = scr.GetProperty("droGageBlock", "Value")
    local CurTool = mc.mcToolGetCurrent(inst) --Current Tool Num
    local CurH = mc.mcCntlGetPoundVar(inst, 2032) --Current Selected H Offset
    local CurHVal = mc.mcCntlGetPoundVar(inst, 2035) --Value of Current H Offset
    local OffsetState = mc.mcCntlGetPoundVar(inst, 4008) --Current Height Offset State
    if (OffsetState == 49) then
        CurHVal = 0
    end
    GageBlock = tonumber(GageBlock)
    local ZPos = mc.mcAxisGetMachinePos(inst, mc.Z_AXIS)
    XVar, YVar, ZVar = GetFixOffsetVars()
    local OffsetVal = ZPos - GageBlock - CurHVal
    mc.mcCntlSetPoundVar(inst, ZVar, OffsetVal)
    mc.mcCntlSetLastError(inst, string.format("Z Offset Set: %.4f", OffsetVal))
    
    
end
function btnHOActivate_Clicked_Script(...)
    --Toggle height offset button
    			
    local HOState = mc.mcCntlGetPoundVar(inst, 4008)
    if (HOState == 49) then
        mc.mcCntlMdiExecute(inst, "G43")
    else
        mc.mcCntlMdiExecute(inst, "G49")
    end
    
end
function btnSetZ_1__Clicked_Script(...)
    --Set Tool button
    
    local inst = mc.mcGetInstance()			  
    local GageBlock = scr.GetProperty("droGageBlockT", "Value")
    local CurTool = mc.mcToolGetCurrent(inst) --Current Tool Num
    local OffsetState = mc.mcCntlGetPoundVar(inst, 4008) --Current Height Offset State
    mc.mcCntlGcodeExecuteWait(inst, "G49")
    GageBlock = tonumber(GageBlock)
    local ZPos = mc.mcAxisGetPos(inst, mc.Z_AXIS)
    local OffsetVal = ZPos - GageBlock
    mc.mcToolSetData(inst, mc.MTOOL_MILL_HEIGHT, CurTool, OffsetVal)
    mc.mcCntlSetLastError(inst, string.format("Tool %.0f Height Offset Set: %.4f", CurTool, OffsetVal))
    if (OffsetState ~= 49) then
        mc.mcCntlMdiExecute(inst, string.format("G%.1f", OffsetState))
    end
    
end
function droGageBlockT_On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    
    local val = scr.GetProperty("droGageBlockT", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droGageBlockT", string.format (val)) --Create a register and write to it
    
    --local val = scr.GetProperty("droGageBlockT", "Value")
    --mc.mcProfileWriteString(inst, "OffsetsSettings", "GageBlockT", tostring(val))
    --mc.mcCntlSetLastError(inst, "Offsets: Tool Offset Gage block updated")
    
end
function btnRemember_Left_Up_Script(...)
    --Remember Position
    
    --One way
    -- local inst = mc.mcGetInstance() -- Get the instance of Mach4
    -- local xset = mc.mcAxisGetMachinePos(inst, 0) -- Get current Machine Coordinates
    -- local yset = mc.mcAxisGetMachinePos(inst, 1) -- Get current Machine Coordinates
    -- local zset = mc.mcAxisGetMachinePos(inst, 2) -- Get current Machine Coordinates
    -- xval = tostring(xset)
    -- yval = tostring(yset)
    -- zval = tostring(zset)
    -- mc.mcProfileWriteString(inst, "RememberPos", "XRemem", xval) --Create a register and write the machine coordinates to it
    -- mc.mcProfileWriteString(inst, "RememberPos", "YRemem", yval) --Create a register and write the machine coordinates to it
    -- mc.mcProfileWriteString(inst, "RememberPos", "ZRemem", zval) --Create a register and write the machine coordinates to it
    
    --Or another way
    -- local inst = mc.mcGetInstance() -- Get the instance of Mach4
    -- local pos = mc.mcAxisGetMachinePos(inst, 0) -- Get current X Machine Coordinates
    -- pos = tostring(pos)
    -- mc.mcProfileWriteString(inst, "RememberPos", "X", pos) --Create a register and write the machine coordinates to it
    -- local pos = mc.mcAxisGetMachinePos(inst, 1) -- Get current Y Machine Coordinates
    -- pos = tostring(pos)
    -- mc.mcProfileWriteString(inst, "RememberPos", "Y", pos) --Create a register and write the machine coordinates to it
    -- local pos = mc.mcAxisGetMachinePos(inst, 2) -- Get current Z Machine Coordinates
    -- pos = tostring(pos)
    -- mc.mcProfileWriteString(inst, "RememberPos", "Z", pos) --Create a register and write the machine coordinates to it
    
    --Yet another way
    --wx.wxMessageBox('Are you sure you want to set the return position to the current location?\nIf not you should probalby cancel now.');
    --local inst = mc.mcGetInstance() -- Get the instance of Mach4
    --local pos = mc.mcAxisGetMachinePos(inst, 0) -- Get current X (0) Machine Coordinates
    --mc.mcProfileWriteString(inst, "RememberPos", "X", string.format (pos)) --Create a register and write the machine coordinates to it
    --local pos = mc.mcAxisGetMachinePos(inst, 1) -- Get current Y (1) Machine Coordinates
    --mc.mcProfileWriteString(inst, "RememberPos", "Y", string.format (pos)) --Create a register and write the machine coordinates to it
    --local pos = mc.mcAxisGetMachinePos(inst, 2) -- Get current Z (2) Machine Coordinates
    --mc.mcProfileWriteString(inst, "RememberPos", "Z", string.format (pos)) --Create a register and write the machine coordinates to it
    
    --Yup, you guessed it, another way.
    RememberPosition() -- This runs the Remember Position Function that is in the screenload script.
end
function btnReturn_Left_Up_Script(...)
    -- Return To Position
    --local inst = mc.mcGetInstance() -- Get the instance of Mach4
    --local xrememval = mc.mcProfileGetString(inst, "RememberPos", "XRemem", "NotFound") -- Get the register Value
    --local yrememval = mc.mcProfileGetString(inst, "RememberPos", "YRemem", "NotFound") -- Get the register Value
    --local zrememval = mc.mcProfileGetString(inst, "RememberPos", "ZRemem", "NotFound") -- Get the register Value
    --mc.mcCntlMdiExecute(inst, "G00 G53 Z0.0000 \n G00 G53 X" .. xrememval .. "\n G00 G53 Y" .. yrememval .. "\n G00 G53 Z" .. zrememval)
    
    
    --Or another way
    -- local inst = mc.mcGetInstance() -- Get the instance of Mach4
    -- local xval = mc.mcProfileGetString(inst, "RememberPos", "X", "NotFound") -- Get the register Value
    -- local yval = mc.mcProfileGetString(inst, "RememberPos", "Y", "NotFound") -- Get the register Value
    -- local zval = mc.mcProfileGetString(inst, "RememberPos", "Z", "NotFound") -- Get the register Value
    -- mc.mcCntlMdiExecute(inst, "G00 G53 Z0.0000 \n G00 G53 X" .. xval .. "\n G00 G53 Y" .. yval .. "\n G00 G53 Z" .. zval)
    
    --Or another way with added checks to see if the registers exist so we can avoid errors
    --local inst = mc.mcGetInstance() -- Get the instance of Mach4
    --local xval = mc.mcProfileGetString(inst, "RememberPos", "X", "NotFound") -- Get the register Value
    --local yval = mc.mcProfileGetString(inst, "RememberPos", "Y", "NotFound") -- Get the register Value
    --local zval = mc.mcProfileGetString(inst, "RememberPos", "Z", "NotFound") -- Get the register Value
    --if(xval == "NotFound")then -- check to see if the register is found
    --	wx.wxMessageBox('Register xval does not exist.\nYou must remember a postion before you can return to it.'); -- If the register does not exist tell us in a message box
    --elseif (yval == "NotFound")then -- check to see if the register is found
    --	wx.wxMessageBox('Register yval does not exist.\nYou must remember a postion before you can return to it.'); -- If the register does not exist tell us in a message box
    --elseif (zval == "NotFound")then -- check to see if the register is found
    --	wx.wxMessageBox('Register zval does not exist.\nYou must remember a postion before you can return to it.'); -- If the register does not exist tell us in a message box
    --else
    --	mc.mcCntlMdiExecute(inst, "G00 G53 Z0.0000 \n G00 G53 X" .. xval .. "\n G00 G53 Y" .. yval .. "\n G00 G53 Z" .. zval)
    --end
    
    --Yup, you guessed it, another way.
    ReturnToPosition() -- This runs the Return to Position Function that is in the screenload script.
    
end
function btn_114__Left_Up_Script(...)
    --Touch Button script
    if (Tframe == nil) then
    
        --TouchOff module
        package.loaded.mcTouchOff = nil
    	mcTouchOff = require "mcTouchOff"
        
    	Tframe = mcTouchOff.Dialog()
    else
    	Tframe:Show()
    	Tframe:Raise()
    end
    
    ----Touch Button script
    --inst = mc.mcGetInstance()
    --
    --if (Tframe == nil) then
    --
    --    local profile = mc.mcProfileGetName(inst)
    --    local path = mc.mcCntlGetMachDir(inst)
    --    
    --    package.path = path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;" .. path .. "\\Modules\\?.lua;" 
    --    --package.path = path .. "\\Profiles\\" .. profile .. "\\Modules\\?.mcc;" .. path .. "\\Modules\\?.mcc;" 
    --
    --    --TouchOff module
    --    package.loaded.mcTouchOff = nil
    --    tou = require "mcTouchOff"
    --    
    --    Tframe = tou.Dialog()
    --else
    --    Tframe:Show()
    --	Tframe:Raise()
    --end
    
    
    
    
    
    
    
end
function btnFROMax_Left_Up_Script(...)
    local maxval = scr.GetProperty('slideFRO', 'Max Value')
    scr.SetProperty('slideFRO', 'Value', tostring(maxval));
end
function btnFROUp_Left_Up_Script(...)
    local val = scr.GetProperty('slideFRO', 'Value');
    val = tonumber(val) + 10;
    local maxval = scr.GetProperty('slideFRO', 'Max Value')
    if (tonumber(val) >= tonumber(maxval)) then
     val = maxval;
    end
    scr.SetProperty('slideFRO', 'Value', tostring(val));
end
function btnFRO100_Left_Up_Script(...)
    scr.SetProperty('slideFRO', 'Value', tostring(100));
end
function btnFROMin_Left_Up_Script(...)
    --scr.SetProperty('slideFRO', 'Value', tostring(0));
    local minval = scr.GetProperty('slideFRO', 'Min Value')
    scr.SetProperty('slideFRO', 'Value', tostring(minval));
end
function btnFRODn_Left_Up_Script(...)
    --local val = scr.GetProperty('slideFRO', 'Value');
    --val = tonumber(val) - 10;
    --if (val < 0 ) then
    --    val =0;
    --end
    --scr.SetProperty('slideFRO', 'Value', tostring(val));
    -- Down
    local val = scr.GetProperty('slideFRO', 'Value');
    val = tonumber(val) - 10;
    local minval = scr.GetProperty('slideFRO', 'Min Value')
    if (tonumber(val) <= tonumber(minval)) then
     val = minval;
    end
    scr.SetProperty('slideFRO', 'Value', tostring(val));
end
function btnSROMax_Left_Up_Script(...)
    --Max
    local maxval = scr.GetProperty('slideSRO', 'Max Value')
    scr.SetProperty('slideSRO', 'Value', tostring(maxval));
end
function btnSROUp_Left_Up_Script(...)
    -- Up
    local val = scr.GetProperty('slideSRO', 'Value');
    val = tonumber(val) + 10;
    local maxval = scr.GetProperty('slideSRO', 'Max Value')
    if (tonumber(val) >= tonumber(maxval)) then
     val = maxval;
    end
    scr.SetProperty('slideSRO', 'Value', tostring(val));
end
function btnSRO100_Left_Up_Script(...)
    -- 100
    scr.SetProperty('slideSRO', 'Value', tostring(100));
end
function btnSROMin_Left_Up_Script(...)
    -- Min
    local minval = scr.GetProperty('slideSRO', 'Min Value')
    scr.SetProperty('slideSRO', 'Value', tostring(minval));
end
function btnSRODn_Left_Up_Script(...)
    -- Down
    local val = scr.GetProperty('slideSRO', 'Value');
    val = tonumber(val) - 10;
    local minval = scr.GetProperty('slideSRO', 'Min Value')
    if (tonumber(val) <= tonumber(minval)) then
     val = minval;
    end
    scr.SetProperty('slideSRO', 'Value', tostring(val));
end
function btnSpindleCW_Left_Up_Script(...)
    SpinCW()
    --local inst = mc.mcGetInstance();
    --local sigh = mc.mcSignalGetHandle(inst, mc.OSIG_SPINDLEON);
    --local sigState = mc.mcSignalGetState(sigh);
    --if (sigState == 1) then 
    --    mc.mcSpindleSetDirection(inst, 0);
    --else 
    --    mc.mcSpindleSetDirection(inst, 1);
    --end
    
    
end
function btnSpindleCCW_Left_Up_Script(...)
    SpinCCW()
    --local inst = mc.mcGetInstance();
    --local sigh = mc.mcSignalGetHandle(inst, mc.OSIG_SPINDLEON);
    --local sigState = mc.mcSignalGetState(sigh);
    --if (sigState == 1) then 
    --    mc.mcSpindleSetDirection(inst, 0);
    --else 
    --    mc.mcSpindleSetDirection(inst, -1);
    --end
    
end
function btnRROMax_Left_Up_Script(...)
    --Max
    local maxval = scr.GetProperty('slideRRO', 'Max Value')
    scr.SetProperty('slideRRO', 'Value', tostring(maxval));
end
function btnRROUp_Left_Up_Script(...)
    -- Up
    local val = scr.GetProperty('slideRRO', 'Value');
    val = tonumber(val) + 10;
    local maxval = scr.GetProperty('slideRRO', 'Max Value')
    if (tonumber(val) >= tonumber(maxval)) then
     val = maxval;
    end
    scr.SetProperty('slideRRO', 'Value', tostring(val));
end
function btnRRO50_Left_Up_Script(...)
    -- 50
    scr.SetProperty('slideRRO', 'Value', tostring(50));
end
function btnRROMin_Left_Up_Script(...)
    -- Min
    local minval = scr.GetProperty('slideRRO', 'Min Value')
    scr.SetProperty('slideRRO', 'Value', tostring(minval));
end
function btnRRODn_Left_Up_Script(...)
    -- Down
    local val = scr.GetProperty('slideRRO', 'Value');
    val = tonumber(val) - 10;
    local minval = scr.GetProperty('slideRRO', 'Min Value')
    if (tonumber(val) <= tonumber(minval)) then
     val = minval;
    end
    scr.SetProperty('slideRRO', 'Value', tostring(val));
end
