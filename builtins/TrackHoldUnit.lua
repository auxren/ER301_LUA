-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Comparator = require "Unit.ViewControl.Comparator"
local ModeSelect = require "Unit.ViewControl.ModeSelect"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local TrackHoldUnit = Class{}
TrackHoldUnit:include(Unit)

function TrackHoldUnit:init(args)
  args.title = "Track & Hold"
  args.mnemonic = "TH"
  Unit.init(self,args)
end

-- creation/destruction states

function TrackHoldUnit:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function TrackHoldUnit:loadMonoGraph(pUnit)
  local holdL = self:createObject("TrackAndHold","holdL")
  local edge = self:createObject("Comparator","edge")
  edge:setGateMode()

  connect(edge,"Out",holdL,"Track")
  connect(pUnit,"In1",holdL,"In")
  connect(holdL,"Out",pUnit,"Out1")

  -- register exported ports
  self:addBranch("gate","Gate",edge,"In")
end

function TrackHoldUnit:loadStereoGraph(pUnit)
  local holdL = self:createObject("TrackAndHold","holdL")
  local holdR = self:createObject("TrackAndHold","holdR")
  local edge = self:createObject("Comparator","edge")
  edge:setGateMode()

  connect(edge,"Out",holdL,"Track")
  connect(edge,"Out",holdR,"Track")

  connect(pUnit,"In1",holdL,"In")
  connect(holdL,"Out",pUnit,"Out1")

  connect(pUnit,"In2",holdR,"In")
  connect(holdR,"Out",pUnit,"Out2")

  -- register exported ports
  self:addBranch("gate","Gate",edge,"In")

  tie(holdR,"Flavor",holdL,"Flavor")
end

local views = {
  menu = {"rename","load","save"},
  expanded = {"gate","type"},
  collapsed = {},
}

function TrackHoldUnit:onLoadViews(objects,controls)
  controls.gate = Comparator {
    button = "gate",
    branch = self:getBranch("Gate"),
    description = "Gate",
    edge = objects.edge,
  }

  controls.type = ModeSelect {
    button = "o",
    description = "Type",
    option = objects.holdL:getOption("Flavor"),
    choices = {"high","low","minmax"}
  }

  return views
end

return TrackHoldUnit
