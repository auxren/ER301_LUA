-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local OutputScope = require "Unit.ViewControl.OutputScope"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local EnvelopeFollowerUnit = Class{}
EnvelopeFollowerUnit:include(Unit)

function EnvelopeFollowerUnit:init(args)
  args.title = "Envelope Follower"
  args.mnemonic = "EF"
  Unit.init(self,args)
end

-- creation/destruction states

function EnvelopeFollowerUnit:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function EnvelopeFollowerUnit:loadMonoGraph(pUnit)
  -- create objects
  local env = self:createObject("EnvelopeFollower","env")
  local attack = self:createObject("ParameterAdapter","attack")
  local release = self:createObject("ParameterAdapter","release")

  -- connect objects
  connect(pUnit,"In1",env,"In")
  connect(env,"Out",pUnit,"Out1")

  tie(env,"Attack Time",attack,"Out")
  self:addBranch("attack","Attack",attack,"In")
  tie(env,"Release Time",release,"Out")
  self:addBranch("release","Release",release,"In")
end

function EnvelopeFollowerUnit:loadStereoGraph(pUnit)
  -- create objects
  local env1 = self:createObject("EnvelopeFollower","env1")
  local env2 = self:createObject("EnvelopeFollower","env2")
  local attack = self:createObject("ParameterAdapter","attack")
  local release = self:createObject("ParameterAdapter","release")

  -- connect objects
  connect(pUnit,"In1",env1,"In")
  connect(env1,"Out",pUnit,"Out1")

  connect(pUnit,"In2",env2,"In")
  connect(env2,"Out",pUnit,"Out2")

  tie(env1,"Attack Time",attack,"Out")
  tie(env2,"Attack Time",attack,"Out")
  self:addBranch("attack","Attack",attack,"In")
  tie(env1,"Release Time",release,"Out")
  tie(env2,"Release Time",release,"Out")
  self:addBranch("release","Release",release,"In")
end

local views = {
  expanded = {"attack","release"},
  collapsed = {},
  attack = {"scope","attack"},
  release = {"scope","release"},
}

function EnvelopeFollowerUnit:onLoadViews(objects,controls)

  controls.scope = OutputScope {
    monitor = self,
    width = 4*ply,
  }

  controls.attack = GainBias {
    button = "attack",
    description = "Attack Time",
    branch = self:getBranch("Attack"),
    gainbias = objects.attack,
    range = objects.attack,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitSecs,
    initialBias = 0.001
  }

  controls.release = GainBias {
    button = "release",
    description = "Release Time",
    branch = self:getBranch("Release"),
    gainbias = objects.release,
    range = objects.release,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitSecs,
    initialBias = 0.010
  }

  return views
end

return EnvelopeFollowerUnit
