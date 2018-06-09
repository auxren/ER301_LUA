-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local EQ3Unit = Class{}
EQ3Unit:include(Unit)

function EQ3Unit:init(args)
  args.title = "EQ3"
  args.mnemonic = "EQ"
  Unit.init(self,args)
end

-- creation/destruction states

function EQ3Unit:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function EQ3Unit:loadMonoGraph(pUnit)
  local equalizer = self:createObject("Equalizer3","equalizer")
  connect(pUnit,"In1",equalizer,"In")
  connect(equalizer,"Out",pUnit,"Out1")

  local lowGain = self:createObject("GainBias","lowGain")
  local lowGainRange = self:createObject("MinMax","lowGainRange")

  local midGain = self:createObject("GainBias","midGain")
  local midGainRange = self:createObject("MinMax","midGainRange")

  local highGain = self:createObject("GainBias","highGain")
  local highGainRange = self:createObject("MinMax","highGainRange")

  connect(lowGain,"Out",equalizer,"Low Gain")
  connect(lowGain,"Out",lowGainRange,"In")

  connect(midGain,"Out",equalizer,"Mid Gain")
  connect(midGain,"Out",midGainRange,"In")

  connect(highGain,"Out",equalizer,"High Gain")
  connect(highGain,"Out",highGainRange,"In")

  self:addBranch("low(dB)","Low Gain",lowGain,"In")
  self:addBranch("mid(dB)","Mid Gain",midGain,"In")
  self:addBranch("high(dB)","High Gain",highGain,"In")
end

function EQ3Unit:loadStereoGraph(pUnit)
  local equalizer1 = self:createObject("Equalizer3","equalizer1")
  connect(pUnit,"In1",equalizer1,"In")
  connect(equalizer1,"Out",pUnit,"Out1")

  local equalizer2 = self:createObject("Equalizer3","equalizer2")
  connect(pUnit,"In2",equalizer2,"In")
  connect(equalizer2,"Out",pUnit,"Out2")

  local lowGain = self:createObject("GainBias","lowGain")
  local lowGainRange = self:createObject("MinMax","lowGainRange")

  local midGain = self:createObject("GainBias","midGain")
  local midGainRange = self:createObject("MinMax","midGainRange")

  local highGain = self:createObject("GainBias","highGain")
  local highGainRange = self:createObject("MinMax","highGainRange")

  connect(lowGain,"Out",equalizer1,"Low Gain")
  connect(lowGain,"Out",equalizer2,"Low Gain")
  connect(lowGain,"Out",lowGainRange,"In")

  connect(midGain,"Out",equalizer1,"Mid Gain")
  connect(midGain,"Out",equalizer2,"Mid Gain")
  connect(midGain,"Out",midGainRange,"In")

  connect(highGain,"Out",equalizer1,"High Gain")
  connect(highGain,"Out",equalizer2,"High Gain")
  connect(highGain,"Out",highGainRange,"In")

  self:addBranch("low(dB)","Low Gain",lowGain,"In")
  self:addBranch("mid(dB)","Mid Gain",midGain,"In")
  self:addBranch("high(dB)","High Gain",highGain,"In")

  tie(equalizer2,"Low Freq",equalizer1,"Low Freq")
  tie(equalizer2,"High Freq",equalizer1,"High Freq")
  -- alias
  self.objects.equalizer = self.objects.equalizer1
end

local views = {
  expanded = {"lowGain","midGain","highGain","lowFreq","highFreq"},
  collapsed = {},
}

function EQ3Unit:onLoadViews(objects,controls)

  controls.lowGain = GainBias {
    button = "low(dB)",
    branch = self:getBranch("Low Gain"),
    description = "Low Gain",
    gainbias = objects.lowGain,
    range = objects.lowGainRange,
    biasMap = Encoder.getMap("volume"),
    biasUnits = app.unitDecibels,
    gainMap = Encoder.getMap("[-10,10]"),
    initialBias = 1.0
  }

  controls.midGain = GainBias {
    button = "mid(dB)",
    branch = self:getBranch("Mid Gain"),
    description = "Mid Gain",
    gainbias = objects.midGain,
    range = objects.midGainRange,
    biasMap = Encoder.getMap("volume"),
    biasUnits = app.unitDecibels,
    gainMap = Encoder.getMap("[-10,10]"),
    initialBias = 1.0
  }

  controls.highGain = GainBias {
    button = "high(dB)",
    branch = self:getBranch("High Gain"),
    description = "High Gain",
    gainbias = objects.highGain,
    range = objects.highGainRange,
    biasMap = Encoder.getMap("volume"),
    biasUnits = app.unitDecibels,
    gainMap = Encoder.getMap("[-10,10]"),
    initialBias = 1.0
  }

  controls.lowFreq = Fader {
    button = "low(Hz)",
    description = "Low Freq",
    param = objects.equalizer:getParameter("Low Freq"),
    monitor = self,
    map = Encoder.getMap("filterFreq"),
    units = app.unitHertz,
    scaling = app.octaveScaling
  }

  controls.highFreq = Fader {
    button = "high(Hz)",
    description = "High Freq",
    param = objects.equalizer:getParameter("High Freq"),
    monitor = self,
    map = Encoder.getMap("filterFreq"),
    units = app.unitHertz,
    scaling = app.octaveScaling
  }

  return views
end

return EQ3Unit
