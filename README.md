# Mach4Hobby - CNC Machine Configuration Repository
This is a repository for the Mach4 configurations used to control a 4ft x 4ft woodworking CNC mill.
The project directory contains a `.gitignore` file that excludes all the following file types
* Windows Executables (.exe)
* Dynamic Link Libraries (.dll)
* Icon Files (.ico)
* Compiled Lua Scripts (.mcc)
* Binary data files (.dat)

The following subdiretories are also excluded as they serve no purpose under version control
```
/CrashReports
/Docs
/GcodeFiles
/Lang
/Licenses
/LuaExamples
/Modules<All except desired>
/Plugins
/Profiles/<All except desired>
/Pmc
/Subroutines
/Screens/<All except desired>
/Wizards
/ZeroBraneStudio
```

## Avid CNC Z-Touch Plate UI Module
This branch contains a module named `/Mach4Hobby/Modules/zTouchPlate.lua`. 
This module implements a UI panel that will allow the user to auto zero the work coordinates of a part
using the Z touch plate manufactured by *_cncrouterparts.com_* (a.k.a Avid CNC). This is an attempt to 
port the 'Auto Zero Tool' created by CNC Router Parts for Mach3 for use in Mach4.

### Z-TouchPlate Module Installation Instructions
Complete the following steps to add the Z-Touch Plate UI to your Mach4 instance.
* Create the following directory `/Mach4Hobby/Modules/zTouchPlate` to your Mach4 instance.
* Cut/Paste or Download the `zTouchPlate.lua` file from this repository and place it in the directory you just created
* Create a new panel within the Mach4 screen editor in which you want to add the UI.
* Create a script for the panel you just created by 
  * Selecting the newly created panel within the screen editor.
  * Click the `Event` icon in the `Properties` window, followed by the elipsis (`...`) on the 'script' property.
  * The ZeroBrane Studio script editor should open.
* Copy the following code into the empty script.
  ```
  local inst = mc.mcGetInstance()
  
  -- Load the zTouchPlate module
  local profile = mc.mcProfileGetName(inst)
  local path = mc.mcCntlGetMachDir(inst)
  package.path = path .. "\\Modules\\zTouchPlate\\?.lua;"
  package.loaded.zTouchPlate = nil
  local ztp = require "zTouchPlate"
  
  -- Load UI and code to implement this panel
  ztp.create()
  ```
 * Save the new script by clicking the save button.
 * Close the ZeroBrane Studio editor.
 * Exit edit mode by un-clicking the menu item `Operator->Edit Screen`
