-- GLOBALS: app, connect, tie

-- The Class module implements basic OOP functionality
local Class = require "Base.Class"
-- The base class for all units
local Unit = require "Unit"
-- A graphical control for the unit menu
local ModeSelect = require "Unit.MenuControl.ModeSelect"
-- A graphical control for comparator objects on the unit input
local InputComparator = require "Unit.ViewControl.InputComparator"
-- A graphical control for gainbias objects
local GainBias = require "Unit.ViewControl.GainBias"
-- A graphical control for comparator objects
local Comparator = require "Unit.ViewControl.Comparator"
-- Needed to get access to the pre-defined encoder maps
local Encoder = require "Encoder"

-- Create an empty class definition for the Countdown unit
local Countdown = Class{}
-- Use inclusion to effectively inherit from the Unit class
Countdown:include(Unit)

-- The constructor
function Countdown:init(args)
  -- This is the default title shown in the unit header.
  args.title = "Count- down"
  -- This is the 2 letter abbreviation for this unit.
  args.mnemonic = "Cd"
  -- Optionally, set a version number unique to this unit.
  args.version = 1
  -- Make sure to call the parent class constructor also.
  Unit.init(self,args)
end

-- This method will be called during unit instantiation. Create the DSP graph here.
-- pUnit : an object containing the unit's input and output ports.
-- channelCount: used to determine if we are building a mono or stereo version of this unit.
function Countdown:onLoadGraph(pUnit,channelCount)
  -- The createObject method is used to instantiate and name DSP objects.

  -- Create a Comparator object for digitizing the incoming signal into triggers.
  local input = self:createObject("Comparator","input")
  -- A comparator has trigger, gate and toggle output modes.  Configure the comparator to output triggers.
  input:setTriggerMode()

  -- Create a Counter object, turn off wrapping and set its initial parameter values.
  local counter = self:createObject("Counter","counter")
  counter:optionSet("Wrap",app.YesNoChoices.no)
  counter:hardSet("Gain",1)
  counter:hardSet("Step Size",-1)
  counter:hardSet("Start",0)

  -- Here we connect the output of the 'input' comparator to the input of the 'counter' object.
  connect(input,"Out",counter,"In")

  -- Since a comparator only fires when the threshold is exceeded from below, let's negate the output of the counter.
  local negate = self:createObject("ConstantGain","negate")
  negate:hardSet("Gain",-1)
  connect(counter,"Out",negate,"In")

  -- Create another Comparator object for the output.
  local output = self:createObject("Comparator","output")
  output:setTriggerMode()
  output:hardSet("Threshold",-0.5)
  connect(negate,"Out",output,"In")

  -- And yet another Comparator object for the reset control.
  local reset = self:createObject("Comparator","reset")
  reset:setTriggerMode()
  connect(reset,"Out",counter,"Reset")

  -- We need an external control for setting what value to start counting from.
  local start = self:createObject("ParameterAdapter","start")
  --Give it an initial value, otherwise it will be zero.
  start:hardSet("Bias",4)

  -- Unlike audio-rate signals, parameters are tied together like this slave parameter to master parameter.  Think of it as an assignment.
  -- Note: We need to use the counter's Finish parameter because our step size is negative.
  tie(counter,"Finish",start,"Out")

  -- Register sub-chains (internally called branches) for modulation.
  self:addBranch("start","Start",start,"In")
  self:addBranch("reset","Reset",reset,"In")

  -- Finally, connect the output of the 'output' Comparator to the unit output(s).
  connect(output,"Out",pUnit,"Out1")
  if channelCount > 1 then
    connect(output,"Out",pUnit,"Out2")
  end

  -- Force a reset to occur, so that the counter is ready to go.
  reset:simulateRisingEdge()
  reset:simulateFallingEdge()
end

-- Describe the layout of the menu in terms of its controls.
local menu = {
  "infoHeader","rename","load","save",
  "wrap",
  "rate"
}

-- Here we create each control for the menu.
function Countdown:onLoadMenu(objects,controls)
  controls.wrap = ModeSelect {
    description = "Wrap?",
    option = objects.counter:getOption("Wrap"),
    choices = {"yes","no"}
  }

  controls.rate = ModeSelect {
    description = "Process Rate",
    option = objects.counter:getOption("Processing Rate"),
    choices = {"frame","sample"}
  }

  return menu
end

-- Describe the layout of unit expanded and collapsed views in terms of its controls.
local views = {
  expanded = {"input","count","reset"},
  collapsed = {},
}

-- Here we create each control for the unit.
function Countdown:onLoadViews(objects,controls)

  -- An InputComparator control wraps a comparator object (passed into the edge argument).
  controls.input = InputComparator {
    button = "input",
    description = "Unit Input",
    unit = self,
    edge = objects.inut,
  }

  -- A GainBias control wraps any object with a Bias and Gain parameter.
  controls.count = GainBias {
    button = "count",
    description = "Count",
    branch = self:getBranch("Start"),
    gainbias = objects.start,
    range = objects.start,
    biasMap = Encoder.getMap("int[1,256]"),
    biasUnits = app.unitInteger,
  }

  -- A Comparator control wraps a comparator object (passed into the edge parameter).
  controls.reset = Comparator {
    button = "reset",
    description = "Reset Counter",
    branch = self:getBranch("Reset"),
    edge = objects.reset,
    param = objects.counter:getParameter("Value"),
    readoutUnits = app.unitInteger
  }

  return views
end

-- Don't forget to return the unit class definition
return Countdown
