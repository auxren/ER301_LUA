-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local GainBias = require "Unit.ViewControl.GainBias"
local InputComparator = require "Unit.ViewControl.InputComparator"
local OutputScope = require "Unit.ViewControl.OutputScope"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local ADSRUnit = Class{}
ADSRUnit:include(Unit)

function ADSRUnit:init(args)
  args.title = "ADSR"
  args.mnemonic = "En"
  Unit.init(self,args)
end

-- creation/destruction states

function ADSRUnit:onLoadGraph(pUnit, channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function ADSRUnit:loadMonoGraph(pUnit)
  -- create objects
  local gate = self:createObject("Comparator","gate")
  gate:setGateMode()
  local adsr = self:createObject("ADSR","adsr")
  local attack = self:createObject("GainBias","attack")
  local decay = self:createObject("GainBias","decay")
  local sustain = self:createObject("GainBias","sustain")
  local release = self:createObject("GainBias","release")
  local attackRange = self:createObject("MinMax","attackRange")
  local decayRange = self:createObject("MinMax","decayRange")
  local sustainRange = self:createObject("MinMax","sustainRange")
  local releaseRange = self:createObject("MinMax","releaseRange")

  connect(pUnit,"In1",gate,"In")
  connect(gate,"Out",adsr,"Gate")
  connect(adsr,"Out",pUnit,"Out1")

  connect(attack,"Out",adsr,"Attack")
  connect(decay,"Out",adsr,"Decay")
  connect(sustain,"Out",adsr,"Sustain")
  connect(release,"Out",adsr,"Release")

  connect(attack,"Out",attackRange,"In")
  connect(decay,"Out",decayRange,"In")
  connect(sustain,"Out",sustainRange,"In")
  connect(release,"Out",releaseRange,"In")

  -- register destinations
  self:addBranch("att","Attack",attack,"In")
  self:addBranch("dec","Decay",decay,"In")
  self:addBranch("sus","Sustain",sustain,"In")
  self:addBranch("rel","Release",release,"In")
end

function ADSRUnit:loadStereoGraph(pUnit)
  self:loadMonoGraph(pUnit)
  connect(self.objects.adsr,"Out",pUnit,"Out2")
end


local views = {
  expanded = {"input","attack","decay","sustain","release"},
  collapsed = {},
  input = {"scope","input"},
  attack = {"scope","attack"},
  decay = {"scope","decay"},
  sustain = {"scope","sustain"},
  release = {"scope","release"},
}

function ADSRUnit:onLoadViews(objects,controls)

  controls.scope = OutputScope {
    monitor = self,
    width = 4*ply,
  }

  controls.input = InputComparator {
    button = "input",
    description = "Unit Input",
    unit = self,
    edge = objects.gate,
  }

  controls.attack = GainBias {
    button = "A",
    branch = self:getBranch("Attack"),
    description = "Attack",
    gainbias = objects.attack,
    range = objects.attackRange,
    biasMap = Encoder.getMap("ADSR"),
    biasUnits = app.unitSecs,
    initialBias = 0.050
  }

  controls.decay = GainBias {
    button = "D",
    branch = self:getBranch("Decay"),
    description = "Decay",
    gainbias = objects.decay,
    range = objects.decayRange,
    biasMap = Encoder.getMap("ADSR"),
    biasUnits = app.unitSecs,
    initialBias = 0.050
  }

  controls.sustain = GainBias {
    button = "S",
    branch = self:getBranch("Sustain"),
    description = "Sustain",
    gainbias = objects.sustain,
    range = objects.sustainRange,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 1
  }

  controls.release = GainBias {
    button = "R",
    branch = self:getBranch("Release"),
    description = "Release",
    gainbias = objects.release,
    range = objects.releaseRange,
    biasMap = Encoder.getMap("ADSR"),
    biasUnits = app.unitSecs,
    initialBias = 0.100
  }

  return views
end

return ADSRUnit
