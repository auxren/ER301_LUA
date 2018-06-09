-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local ClockBase = require "builtins.timing.ClockBase"
local GainBias = require "Unit.ViewControl.GainBias"
local InputComparator = require "Unit.ViewControl.InputComparator"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local ClockInSeconds = Class{}
ClockInSeconds:include(ClockBase)

function ClockInSeconds:init(args)
  ClockBase.init(self,args)
end

function ClockInSeconds:onLoadGraph(pUnit, channelCount)
  local clock = self:createObject("ClockInSeconds","clock")
  ClockBase.loadBaseGraph(self, pUnit, channelCount, clock)
  local period = self:createObject("ParameterAdapter","period")
  tie(clock,"Period",period,"Out")
  self:addBranch("period","Period",period,"In")
end

local views = {
  expanded = {"sync","period","mult","div","width"},
  collapsed = {},
}

function ClockInSeconds:onLoadViews(objects,controls)
  ClockBase.loadBaseView(self,objects,controls)

  controls.period = GainBias {
    button = "period",
    description = "Clock Period",
    branch = self:getBranch("Period"),
    gainbias = objects.period,
    range = objects.period,
    biasMap = Encoder.getMap("[0,10]"),
    biasUnits = app.unitSecs,
    initialBias = 0.5
  }

  return views
end

return ClockInSeconds
