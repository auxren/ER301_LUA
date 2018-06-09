-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local ply = app.SECTION_PLY

local WhiteNoiseUnit = Class{}
WhiteNoiseUnit:include(Unit)

function WhiteNoiseUnit:init(args)
  args.title = "White Noise"
  args.mnemonic = "WN"
  Unit.init(self,args)
end

function WhiteNoiseUnit:onLoadGraph(pUnit,channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function WhiteNoiseUnit:loadMonoGraph(pUnit)
  local noise1 = self:createObject("WhiteNoise","noise1")
  connect(noise1,"Out",pUnit,"Out1")
end

function WhiteNoiseUnit:loadStereoGraph(pUnit)
  local noise1 = self:createObject("WhiteNoise","noise1")
  local noise2 = self:createObject("WhiteNoise","noise2")
  connect(noise1,"Out",pUnit,"Out1")
  connect(noise2,"Out",pUnit,"Out2")
end

return WhiteNoiseUnit
