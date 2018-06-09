-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local ModeSelect = require "Unit.MenuControl.ModeSelect"
local Fader = require "Unit.ViewControl.Fader"
local GainBias = require "Unit.ViewControl.GainBias"
local Comparator = require "Unit.ViewControl.Comparator"
local InputComparator = require "Unit.ViewControl.InputComparator"
local OutputScope = require "Unit.ViewControl.OutputScope"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local CounterUnit = Class{}
CounterUnit:include(Unit)

function CounterUnit:init(args)
  args.title = "Counter"
  args.mnemonic = "C"
  Unit.init(self,args)
end

function CounterUnit:onLoadGraph(pUnit, channelCount)
  -- create objects
  local trig = self:createObject("Comparator","trig")
  trig:setTriggerMode()
  local reset = self:createObject("Comparator","reset")
  reset:setTriggerMode()
  local counter = self:createObject("Counter","counter")
  local start = self:createObject("ParameterAdapter","start")
  local finish = self:createObject("ParameterAdapter","finish")
  local step = self:createObject("ParameterAdapter","step")
  local gain = self:createObject("ParameterAdapter","gain")

  connect(pUnit,"In1",trig,"In")
  connect(trig,"Out",counter,"In")
  connect(counter,"Out",pUnit,"Out1")
  connect(reset,"Out",counter,"Reset")

  tie(counter,"Step Size",step,"Out")
  tie(counter,"Start",start,"Out")
  tie(counter,"Finish",finish,"Out")
  tie(counter,"Gain",gain,"Out")

  self:addBranch("reset","Reset",reset,"In")
  self:addBranch("step","Step",step,"In")
  self:addBranch("start","Start",start,"In")
  self:addBranch("finish","Finish",finish,"In")
  self:addBranch("gain","Gain",gain,"In")

  if channelCount > 1 then
    connect(counter,"Out",pUnit,"Out2")
  end

  reset:simulateRisingEdge()
  reset:simulateFallingEdge()
end

local menu = {
  "infoHeader","rename","load","save",
  "wrap",
  "rate"
}

function CounterUnit:onLoadMenu(objects,controls)
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


local views = {
  expanded = {"input","reset","start","step","finish","gain"},
  collapsed = {},
  input = {"scope","input"},
  reset = {"scope","reset"},
  start = {"scope","start"},
  step = {"scope","step"},
  finish = {"scope","finish"},
  gain = {"scope","gain"},
}

function CounterUnit:onLoadViews(objects,controls)

  controls.scope = OutputScope {
    monitor = self,
    width = 4*ply,
  }

  controls.input = InputComparator {
    button = "input",
    description = "Unit Input",
    unit = self,
    edge = objects.trig,
  }

  controls.reset = Comparator {
    button = "reset",
    description = "Reset To Start",
    branch = self:getBranch("Reset"),
    edge = objects.reset,
    param = objects.counter:getParameter("Value"),
    readoutUnits = app.unitInteger
  }

  controls.start = GainBias {
    button = "start",
    description = "Start",
    branch = self:getBranch("Start"),
    gainbias = objects.start,
    range = objects.start,
    biasMap = Encoder.getMap("int[0,256]"),
    biasUnits = app.unitInteger,
    initialBias = 0,
  }

  controls.step = GainBias {
    button = "step",
    description = "Step Size",
    branch = self:getBranch("Step"),
    gainbias = objects.step,
    range = objects.step,
    biasMap = Encoder.getMap("int[-32,32]"),
    biasUnits = app.unitInteger,
    initialBias = 1,
  }

  controls.finish = GainBias {
    button = "finish",
    description = "Finish",
    branch = self:getBranch("Finish"),
    gainbias = objects.finish,
    range = objects.finish,
    biasMap = Encoder.getMap("int[1,256]"),
    biasUnits = app.unitInteger,
    initialBias = 16,
  }

  controls.gain = GainBias {
    button = "gain",
    branch = self:getBranch("Gain"),
    description = "Output Gain",
    gainbias = objects.gain,
    range = objects.gain,
    biasMap = Encoder.getMap("gain"),
    biasUnits = app.unitNone,
    initialBias = 1.0
  }

  return views
end

return CounterUnit
