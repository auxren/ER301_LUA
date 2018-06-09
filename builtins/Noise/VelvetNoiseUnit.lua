-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local VelvetNoiseUnit = Class{}
VelvetNoiseUnit:include(Unit)

function VelvetNoiseUnit:init(args)
  args.title = "Velvet Noise"
  args.mnemonic = "VN"
  Unit.init(self,args)
end

function VelvetNoiseUnit:onLoadGraph(pUnit,channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end

  local rate = self:createObject("ParameterAdapter","rate")
  tie(self.objects.noise1,"Rate",rate,"Out")

  self:addBranch("rate","Rate",rate,"In")
end

function VelvetNoiseUnit:loadMonoGraph(pUnit)
  local noise1 = self:createObject("VelvetNoise","noise1")
  connect(noise1,"Out",pUnit,"Out1")
end

function VelvetNoiseUnit:loadStereoGraph(pUnit)
  local noise1 = self:createObject("VelvetNoise","noise1")
  local noise2 = self:createObject("VelvetNoise","noise2")
  connect(noise1,"Out",pUnit,"Out1")
  connect(noise2,"Out",pUnit,"Out2")
  tie(noise2,"Rate",noise1,"Rate")
end

local views = {
  expanded = {"rate"},
  collapsed = {},
}

function VelvetNoiseUnit:onLoadViews(objects,controls)
  controls.rate = GainBias {
    button = "rate",
    description = "Impulse Rate",
    branch = self:getBranch("Rate"),
    gainbias = objects.rate,
    range = objects.rate,
    biasMap = Encoder.getMap("oscFreq"),
    biasUnits = app.unitHertz,
    initialBias = 880,
    gainMap = Encoder.getMap("freqGain"),
    scaling = app.octaveScaling
  }
  return views
end

return VelvetNoiseUnit
