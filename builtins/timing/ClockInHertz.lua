-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local ClockBase = require "builtins.timing.ClockBase"
local GainBias = require "Unit.ViewControl.GainBias"
local InputComparator = require "Unit.ViewControl.InputComparator"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local ClockInHertz = Class{}
ClockInHertz:include(ClockBase)

function ClockInHertz:init(args)
  ClockBase.init(self,args)
end

function ClockInHertz:onLoadGraph(pUnit, channelCount)
  local clock = self:createObject("ClockInHertz","clock")
  ClockBase.loadBaseGraph(self, pUnit, channelCount, clock)
  local freq = self:createObject("ParameterAdapter","freq")
  tie(clock,"Frequency",freq,"Out")
  self:addBranch("freq","Freq",freq,"In")
end

local views = {
  expanded = {"sync","freq","mult","div","width"},
  collapsed = {},
}

function ClockInHertz:onLoadViews(objects,controls)
  ClockBase.loadBaseView(self,objects,controls)

  controls.freq = GainBias {
    button = "freq",
    description = "Clock Frequency",
    branch = self:getBranch("Freq"),
    gainbias = objects.freq,
    range = objects.freq,
    biasMap = Encoder.getMap("clockFreq"),
    biasUnits = app.unitHertz,
    scaling = app.octaveScaling,
    initialBias = 2
  }

  return views
end

return ClockInHertz
