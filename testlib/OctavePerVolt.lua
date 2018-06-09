-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"

local OctavePerVolt = Class{}
OctavePerVolt:include(Unit)

function OctavePerVolt:init(args)
  args.title = "Octave per Volt"
  args.mnemonic = "OV"
  Unit.init(self,args)
end

function OctavePerVolt:onLoadGraph(pUnit, channelCount)
  local negate = self:createObject("ConstantGain","negate")
  negate:hardSet("Gain",-1)
  local exp = self:createObject("VoltPerOctave","exp")
  local tune = self:createObject("ConstantOffset","tune")
  local p0 = self:createObject("ConstantGain","p0")
  p0:hardSet("Gain",0.005)

  connect(pUnit,"In1",tune,"In")
  connect(tune,"Out",negate,"In")
  connect(negate,"Out",exp,"In")
  connect(exp,"Out",p0,"In")
  connect(p0,"Out",pUnit,"Out1")
  if channelCount>1 then
    connect(p0,"Out",pUnit,"Out2")
  end
end

local views = {
  expanded = {"tune","p0"},
  collapsed = {},
}

function OctavePerVolt:onLoadViews(objects,controls)
  controls.tune = Fader {
    button = "tune",
    param = objects.tune:getParameter("Offset"),
    description = "Tune",
    map = Encoder.getMap("cents"),
    units = app.unitCents
  }

  controls.p0 = Fader {
    button = "p0",
    param = objects.p0:getParameter("Gain"),
    description = "Period",
    map = Encoder.getMap("unit"),
    units = app.unitSecs
  }


  return views
end

return OctavePerVolt
