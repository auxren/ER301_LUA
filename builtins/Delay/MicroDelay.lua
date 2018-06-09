-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local MicroDelay = Class{}
MicroDelay:include(Unit)

function MicroDelay:init(args)
  args.title = "uDelay"
  args.mnemonic = "uD"
  Unit.init(self,args)
end

-- creation/destruction states

function MicroDelay:onLoadGraph(pUnit,channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function MicroDelay:loadMonoGraph(pUnit)
  -- create objects
  local delayL = self:createObject("MicroDelay","delayL",0.1)
  -- connect objects
  connect(pUnit,"In1",delayL,"In")
  connect(delayL,"Out",pUnit,"Out1")
end

function MicroDelay:loadStereoGraph(pUnit)
  -- create objects
  local delayL = self:createObject("MicroDelay","delayL",0.1)
  local delayR = self:createObject("MicroDelay","delayR",0.1)
  -- connect objects
  connect(pUnit,"In1",delayL,"In")
  connect(pUnit,"In2",delayR,"In")
  connect(delayL,"Out",pUnit,"Out1")
  connect(delayR,"Out",pUnit,"Out2")
  tie(delayR,"Delay",delayL,"Delay")
end

local views ={
  expanded = {"delay"},
  collapsed = {},
}

function MicroDelay:onLoadViews(objects,controls)
  controls.delay = Fader {
    button = "delay",
    description = "Delay",
    param = objects.delayL:getParameter("Delay"),
    monitor = self,
    map = Encoder.getMap("[0,0.1]"),
    units = app.unitSecs
  }

  return views
end

return MicroDelay
