-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local ply = app.SECTION_PLY

local PinkNoiseUnit = Class{}
PinkNoiseUnit:include(Unit)

function PinkNoiseUnit:init(args)
  args.title = "Pink Noise"
  args.mnemonic = "PN"
  Unit.init(self,args)
end

-- creation/destruction states

function PinkNoiseUnit:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function PinkNoiseUnit:loadMonoGraph(pUnit)
  local noise1 = self:createObject("PinkNoise","noise1")
  connect(noise1,"Out",pUnit,"Out1")
end

function PinkNoiseUnit:loadStereoGraph(pUnit)
  local noise1 = self:createObject("PinkNoise","noise1")
  local noise2 = self:createObject("PinkNoise","noise2")
  connect(noise1,"Out",pUnit,"Out1")
  connect(noise2,"Out",pUnit,"Out2")
end

return PinkNoiseUnit
