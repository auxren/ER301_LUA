-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local ModeSelect = require "Unit.ViewControl.ModeSelect"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local RectifierUnit = Class{}
RectifierUnit:include(Unit)

function RectifierUnit:init(args)
  args.title = "Rectify"
  args.mnemonic = "Ry"
  Unit.init(self,args)
end

-- creation/destruction states

function RectifierUnit:onLoadGraph(pUnit, channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function RectifierUnit:loadMonoGraph(pUnit)
  -- create objects
  local rectify = self:createObject("Rectify","rectify")
  -- connect inputs/outputs
  connect(pUnit,"In1",rectify,"In")
  connect(rectify,"Out",pUnit,"Out1")
end

function RectifierUnit:loadStereoGraph(pUnit)
  -- create objects
  local rectify1 = self:createObject("Rectify","rectify1")
  local rectify2 = self:createObject("Rectify","rectify2")
  -- connect inputs/outputs
  connect(pUnit,"In1",rectify1,"In")
  connect(pUnit,"In2",rectify2,"In")
  connect(rectify1,"Out",pUnit,"Out1")
  connect(rectify2,"Out",pUnit,"Out2")

  tie(rectify2,"Type",rectify1,"Type")
  self.objects.rectify = self.objects.rectify1
end

local views = {
  expanded = {"type"},
  collapsed = {},
}

function RectifierUnit:onLoadViews(objects,controls)
  controls.type = ModeSelect {
    button = "o",
    description = "Type",
    option = objects.rectify:getOption("Type"),
    choices = {"positive half","negative half","full"}
  }

  return views
end

return RectifierUnit
