-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local FixedHPFUnit = Class{}
FixedHPFUnit:include(Unit)

function FixedHPFUnit:init(args)
  args.title = "Fixed HPF"
  args.mnemonic = "HF"
  Unit.init(self,args)
end

-- creation/destruction states

function FixedHPFUnit:onLoadGraph(pUnit,channelCount)
  local filter
  if channelCount==2 then
    filter = self:createObject("StereoFixedHPF","filter")
    connect(pUnit,"In1",filter,"Left In")
    connect(filter,"Left Out",pUnit,"Out1")
    connect(pUnit,"In2",filter,"Right In")
    connect(filter,"Right Out",pUnit,"Out2")
  else
    -- Using a stereo filter here is actually cheaper!
    -- mono 80k ticks, stereo 36k ticks
    filter = self:createObject("StereoFixedHPF","filter")
    connect(pUnit,"In1",filter,"Left In")
    connect(filter,"Left Out",pUnit,"Out1")
  end
end

local views = {
  expanded = {"freq"},
  collapsed = {},
}

function FixedHPFUnit:onLoadViews(objects,controls)

  controls.freq = Fader {
    button = "freq",
    description = "Cutoff Freq",
    param = objects.filter:getParameter("Cutoff"),
    monitor = self,
    map = Encoder.getMap("filterFreq"),
    units = app.unitHertz,
    scaling = app.octaveScaling
  }

  return views
end

return FixedHPFUnit
