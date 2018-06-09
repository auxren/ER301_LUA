-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Comparator = require "Unit.ViewControl.Comparator"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local SampleHoldUnit = Class{}
SampleHoldUnit:include(Unit)

function SampleHoldUnit:init(args)
  args.title = "Sample & Hold"
  args.mnemonic = "SH"
  Unit.init(self,args)
end

-- creation/destruction states

function SampleHoldUnit:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function SampleHoldUnit:loadMonoGraph(pUnit)
  local hold = self:createObject("TrackAndHold","hold")
  local edge = self:createObject("Comparator","edge")
  edge:setTriggerMode()

  connect(edge,"Out",hold,"Track")
  connect(pUnit,"In1",hold,"In")
  connect(hold,"Out",pUnit,"Out1")

  -- register exported ports
  self:addBranch("trig","Trigger",edge,"In")
end

function SampleHoldUnit:loadStereoGraph(pUnit)
  local holdL = self:createObject("TrackAndHold","holdL")
  local holdR = self:createObject("TrackAndHold","holdR")
  local edge = self:createObject("Comparator","edge")
  edge:setTriggerMode()

  connect(edge,"Out",holdL,"Track")
  connect(edge,"Out",holdR,"Track")

  connect(pUnit,"In1",holdL,"In")
  connect(holdL,"Out",pUnit,"Out1")

  connect(pUnit,"In2",holdR,"In")
  connect(holdR,"Out",pUnit,"Out2")

  -- register exported ports
  self:addBranch("trig","Trigger",edge,"In")
end

local views = {
  expanded = {"trigger"},
  collapsed = {},
}

function SampleHoldUnit:onLoadViews(objects,controls)
  controls.trigger = Comparator {
    button = "trig",
    branch = self:getBranch("Trigger"),
    description = "Trigger",
    edge = objects.edge,
  }

  return views
end

return SampleHoldUnit
