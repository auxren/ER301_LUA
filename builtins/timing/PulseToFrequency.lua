-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local InputComparator = require "Unit.ViewControl.InputComparator"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local PulseToFrequency = Class{}
PulseToFrequency:include(Unit)

function PulseToFrequency:init(args)
  args.title = "Pulse to Hertz"
  args.mnemonic = "PH"
  Unit.init(self,args)
end

function PulseToFrequency:onLoadGraph(pUnit, channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function PulseToFrequency:loadMonoGraph(pUnit)
  -- create objects
  local tap = self:createObject("TapTempo","tapL")
  local period = self:createObject("Constant","periodL")
  local edge = self:createObject("Comparator","edgeL")

  connect(pUnit,"In1",edge,"In")
  connect(edge,"Out",tap,"In")
  tie(period,"Value",tap,"Derived Frequency")
  connect(period,"Out",pUnit,"Out1")

  local multiplier = self:createObject("ParameterAdapter","multiplier")
  local divider = self:createObject("ParameterAdapter","divider")
  tie(tap,"Multiplier",multiplier,"Out")
  tie(tap,"Divider",divider,"Out")

  self:addBranch("multiplier","Multiplier",multiplier,"In")
  self:addBranch("divider","Divider",divider,"In")
end

function PulseToFrequency:loadStereoGraph(pUnit)
  local tapL = self:createObject("TapTempo","tapL")
  local periodL = self:createObject("Constant","periodL")
  local edgeL = self:createObject("Comparator","edgeL")

  local tapR = self:createObject("TapTempo","tapR")
  local periodR = self:createObject("Constant","periodR")
  local edgeR = self:createObject("Comparator","edgeR")

  local multiplier = self:createObject("ParameterAdapter","multiplier")
  local divider = self:createObject("ParameterAdapter","divider")
  tie(tapL,"Multiplier",multiplier,"Out")
  tie(tapL,"Divider",divider,"Out")
  tie(tapR,"Multiplier",multiplier,"Out")
  tie(tapR,"Divider",divider,"Out")

  connect(pUnit,"In1",edgeL,"In")
  connect(edgeL,"Out",tapL,"In")
  tie(periodL,"Value",tapL,"Derived Frequency")
  connect(periodL,"Out",pUnit,"Out1")

  connect(pUnit,"In2",edgeR,"In")
  connect(edgeR,"Out",tapR,"In")
  tie(periodR,"Value",tapR,"Derived Frequency")
  connect(periodR,"Out",pUnit,"Out2")

  self:addBranch("multiplier","Multiplier",multiplier,"In")
  self:addBranch("divider","Divider",divider,"In")
end

function PulseToFrequency:onLoadMenu(objects,controls)
  return {}
end

local views = {
  expanded = {"input","mult","div"},
  collapsed = {},
}

function PulseToFrequency:onLoadViews(objects,controls)
  controls.input = InputComparator {
    button = "input",
    description = "Unit Input",
    unit = self,
    edge = objects.edgeL,
  }

  controls.mult = GainBias {
    button = "mult",
    branch = self:getBranch("Multiplier"),
    description = "Clock Multiplier",
    gainbias = objects.multiplier,
    range = objects.multiplier,
    biasMap = Encoder.getMap("int[1,32]"),
    gainMap = Encoder.getMap("[-20,20]"),
    initialBias = 1,
    biasUnits = app.unitInteger
  }

  controls.div = GainBias {
    button = "div",
    branch = self:getBranch("Divider"),
    description = "Clock Divider",
    gainbias = objects.divider,
    range = objects.divider,
    biasMap = Encoder.getMap("int[1,32]"),
    gainMap = Encoder.getMap("[-20,20]"),
    initialBias = 1,
    biasUnits = app.unitInteger
  }
  return views
end

return PulseToFrequency
