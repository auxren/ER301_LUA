-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local GainBias = require "Unit.ViewControl.GainBias"
local InputComparator = require "Unit.ViewControl.InputComparator"
local OutputScope = require "Unit.ViewControl.OutputScope"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local SineEnvelopeUnit = Class{}
SineEnvelopeUnit:include(Unit)

function SineEnvelopeUnit:init(args)
  args.title = "Skewed Sine Env"
  args.mnemonic = "En"
  Unit.init(self,args)
end

function SineEnvelopeUnit:onLoadGraph(pUnit, channelCount)
  local trig = self:createObject("Comparator","trig")
  trig:setTriggerMode()
  local env = self:createObject("SkewedSineEnvelope","env")
  local level = self:createObject("GainBias","level")
  local skew = self:createObject("ParameterAdapter","skew")
  local duration = self:createObject("ParameterAdapter","duration")
  local levelRange = self:createObject("MinMax","levelRange")

  connect(pUnit,"In1",trig,"In")
  connect(trig,"Out",env,"Trigger")
  connect(env,"Out",pUnit,"Out1")

  connect(level,"Out",env,"Level")
  connect(level,"Out",levelRange,"In")
  tie(env,"Duration",duration,"Out")
  tie(env,"Skew",skew,"Out")

  -- register destinations
  self:addBranch("level","Level",level,"In")
  self:addBranch("skew","Skew",skew,"In")
  self:addBranch("dur","Duration",duration,"In")

  if channelCount > 1 then
    connect(env,"Out",pUnit,"Out2")
  end
end

local views = {
  expanded = {"input","duration","skew","level"},
  collapsed = {},
  input = {"scope","input"},
  skew = {"scope","skew"},
  duration = {"scope","duration"},
  level = {"scope","level"},
}

function SineEnvelopeUnit:onLoadViews(objects,controls)

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

  controls.duration = GainBias {
    button = "dur",
    description = "Duration",
    branch = self:getBranch("Duration"),
    gainbias = objects.duration,
    range = objects.duration,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitSecs,
    initialBias = 0.1,
  }

  controls.skew = GainBias {
    button = "skew",
    description = "Skew",
    branch = self:getBranch("Skew"),
    gainbias = objects.skew,
    range = objects.skew,
    biasMap = Encoder.getMap("default"),
    biasUnits = app.unitNone,
    initialBias = -0.5
  }

  controls.level = GainBias {
    button = "level",
    branch = self:getBranch("Level"),
    description = "Level",
    gainbias = objects.level,
    range = objects.levelRange,
    biasMap = Encoder.getMap("default"),
    biasUnits = app.unitNone,
    initialBias = 1.0
  }

  return views
end

return SineEnvelopeUnit
