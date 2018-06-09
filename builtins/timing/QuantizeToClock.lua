-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Comparator = require "Unit.ViewControl.Comparator"
local InputComparator = require "Unit.ViewControl.InputComparator"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local QuantizeToClock = Class{}
QuantizeToClock:include(Unit)

function QuantizeToClock:init(args)
  args.title = "Quantize to Clock"
  args.mnemonic = "QC"
  Unit.init(self,args)
end

function QuantizeToClock:onLoadGraph(pUnit, channelCount)
  local quantizer = self:createObject("QuantizeToClock","quantizer")
  local clockEdge = self:createObject("Comparator","clockEdge")
  clockEdge:setGateMode()
  local inputEdge = self:createObject("Comparator","inputEdge")
  inputEdge:setGateMode()

  -- connect objects
  connect(pUnit,"In1",inputEdge,"In")
  connect(inputEdge,"Out",quantizer,"In")
  connect(clockEdge,"Out",quantizer,"Clock")
  connect(quantizer,"Out",pUnit,"Out1")

  if channelCount > 1 then
    connect(quantizer,"Out",pUnit,"Out2")
  end

  self:addBranch("clock","Clock",clockEdge,"In")
end

local views = {
  expanded = {"input","clock"},
  collapsed = {},
}

function QuantizeToClock:onLoadViews(objects,controls)
  controls.input = InputComparator {
    button = "input",
    description = "Unit Input",
    unit = self,
    edge = objects.inputEdge,
    readoutUnits = app.unitHertz
  }

  controls.clock = Comparator {
    button = "clock",
    description = "Clock",
    branch = self:getBranch("Clock"),
    edge = objects.clockEdge,
  }

  return views
end

return QuantizeToClock
