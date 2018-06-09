-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local GainBias = require "Unit.ViewControl.GainBias"
local PitchControl = require "Unit.ViewControl.PitchControl"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local LadderHPFUnit = Class{}
LadderHPFUnit:include(Unit)

function LadderHPFUnit:init(args)
  args.title = "Ladder HPF"
  args.mnemonic = "HF"
  Unit.init(self,args)
end

-- creation/destruction states

function LadderHPFUnit:onLoadGraph(pUnit,channelCount)
  local filter
  if channelCount==2 then
    filter = self:createObject("StereoLadderHPF","filter")
    connect(pUnit,"In1",filter,"Left In")
    connect(filter,"Left Out",pUnit,"Out1")
    connect(pUnit,"In2",filter,"Right In")
    connect(filter,"Right Out",pUnit,"Out2")
  else
    -- Using a stereo filter here is actually cheaper!
    -- mono 80k ticks, stereo 36k ticks
    filter = self:createObject("StereoLadderHPF","filter")
    connect(pUnit,"In1",filter,"Left In")
    connect(filter,"Left Out",pUnit,"Out1")
  end

  local tune = self:createObject("ConstantOffset","tune")
  local tuneRange = self:createObject("MinMax","tuneRange")

  local f0 = self:createObject("GainBias","f0")
  local f0Range = self:createObject("MinMax","f0Range")

  local res = self:createObject("GainBias","res")
  local resRange = self:createObject("MinMax","resRange")

  local clipper = self:createObject("Clipper","clipper")
  clipper:setMaximum(0.999)
  clipper:setMinimum(0)

  connect(tune,"Out",filter,"V/Oct")
  connect(tune,"Out",tuneRange,"In")

  connect(f0,"Out",filter,"Fundamental")
  connect(f0,"Out",f0Range,"In")


  connect(res, "Out",clipper,"In")
  connect(clipper,"Out",filter,"Resonance")
  connect(clipper,"Out",resRange,"In")

  self:addBranch("V/oct","V/Oct",tune,"In")
  self:addBranch("Q","Resonance",res,"In")
  self:addBranch("f0","Fundamental",f0,"In")
end

local views = {
  expanded = {"tune","freq","resonance"},
  collapsed = {},
}

function LadderHPFUnit:onLoadViews(objects,controls)

  controls.tune = PitchControl {
    button = "V/oct",
    branch = self:getBranch("V/Oct"),
    description = "V/oct",
    offset = objects.tune,
    range = objects.tuneRange
  }

  controls.freq = GainBias {
    button = "f0",
    branch = self:getBranch("Fundamental"),
    description = "Fundamental",
    gainbias = objects.f0,
    range = objects.f0Range,
    biasMap = Encoder.getMap("filterFreq"),
    biasUnits = app.unitHertz,
    initialBias = 440,
    gainMap = Encoder.getMap("freqGain"),
    scaling = app.octaveScaling
  }

  controls.resonance = GainBias {
    button = "Q",
    branch = self:getBranch("Resonance"),
    description = "Resonance",
    gainbias = objects.res,
    range = objects.resRange,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 0.25,
    gainMap = Encoder.getMap("[-10,10]")
  }

  return views
end

return LadderHPFUnit
