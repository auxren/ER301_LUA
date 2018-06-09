-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local ClockBase = require "builtins.timing.ClockBase"
local GainBias = require "Unit.ViewControl.GainBias"
local InputComparator = require "Unit.ViewControl.InputComparator"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local ClockInBPM = Class{}
ClockInBPM:include(ClockBase)

function ClockInBPM:init(args)
  ClockBase.init(self,args)
end

function ClockInBPM:onLoadGraph(pUnit, channelCount)
  local clock = self:createObject("ClockInBPM","clock")
  ClockBase.loadBaseGraph(self, pUnit, channelCount, clock)
  local tempo = self:createObject("ParameterAdapter","tempo")
  tie(clock,"Tempo",tempo,"Out")
  self:addBranch("tempo","Tempo",tempo,"In")
end

local views = {
  expanded = {"sync","tempo","mult","div","width"},
  collapsed = {},
}

function ClockInBPM:onLoadViews(objects,controls)
  ClockBase.loadBaseView(self,objects,controls)

  controls.tempo = GainBias {
    button = "bpm",
    description = "Clock Tempo",
    branch = self:getBranch("Tempo"),
    gainbias = objects.tempo,
    range = objects.tempo,
    biasMap = Encoder.getMap("tempo"),
    biasUnits = app.unitNone,
    initialBias = 120
  }

  return views
end

return ClockInBPM
