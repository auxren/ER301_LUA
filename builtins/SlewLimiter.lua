-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local ModeSelect = require "Unit.ViewControl.ModeSelect"
local OutputScope = require "Unit.ViewControl.OutputScope"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local SlewLimiter = Class{}
SlewLimiter:include(Unit)

function SlewLimiter:init(args)
  args.title = "Slew Limiter"
  args.mnemonic = "SL"
  Unit.init(self,args)
end

-- creation/destruction states

function SlewLimiter:onLoadGraph(pUnit,channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function SlewLimiter:loadMonoGraph(pUnit)
  local slew = self:createObject("SlewLimiter","slew1")
  local time = self:createObject("ParameterAdapter","time")

  connect(pUnit,"In1",slew,"In")
  connect(slew,"Out",pUnit,"Out1")

  tie(slew,"Time",time,"Out")

  self:addBranch("time","Time",time,"In")
end

function SlewLimiter:loadStereoGraph(pUnit)
  local slew1 = self:createObject("SlewLimiter","slew1")
  local slew2 = self:createObject("SlewLimiter","slew2")
  local time = self:createObject("ParameterAdapter","time")

  connect(pUnit,"In1",slew1,"In")
  connect(pUnit,"In2",slew2,"In")
  connect(slew1,"Out",pUnit,"Out1")
  connect(slew2,"Out",pUnit,"Out2")

  tie(slew1,"Time",time,"Out")
  tie(slew2,"Time",time,"Out")
  tie(slew2,"Direction",slew1,"Direction")

  self:addBranch("time","Time",time,"In")
end

local views = {
  expanded = {"time","dir"},
  collapsed = {},
  time = {"scope","time"},
  dir = {"scope","dir"},
}

function SlewLimiter:onLoadViews(objects,controls)
  controls.scope = OutputScope {
    monitor = self,
    width = 4*ply,
  }

  controls.time = GainBias {
    button = "time",
    branch = self:getBranch("Time"),
    description = "Slew Time",
    gainbias = objects.time,
    range = objects.time,
    biasMap = Encoder.getMap("slewTimes"),
    biasUnits = app.unitSecs,
    initialBias = 1.0,
    scaling = app.octaveScaling,
    gainMap = Encoder.getMap("gain"),
  }

  controls.dir = ModeSelect {
    button = "o",
    description = "Mode",
    option = objects.slew1:getOption("Direction"),
    choices = {"up","both","down"}
  }

  return views
end

return SlewLimiter
