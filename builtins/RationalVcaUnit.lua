-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local RationalVcaUnit = Class{}
RationalVcaUnit:include(Unit)

function RationalVcaUnit:init(args)
  args.title = "Rational VCA"
  args.mnemonic = "LV"
  Unit.init(self,args)
end

-- creation/destruction states

function RationalVcaUnit:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function RationalVcaUnit:loadMonoGraph(pUnit)
  -- create objects
  local vca = self:createObject("RationalMultiply","vca",true)
  local numerator = self:createObject("GainBias","numerator")
  local numeratorRange = self:createObject("MinMax","numeratorRange")
  local divisor = self:createObject("GainBias","divisor")
  local divisorRange = self:createObject("MinMax","divisorRange")

  connect(numerator,"Out",numeratorRange,"In")
  connect(numerator,"Out",vca,"Numerator")
  connect(divisor,"Out",divisorRange,"In")
  connect(divisor,"Out",vca,"Divisor")

  connect(pUnit,"In1",vca,"In")
  connect(vca,"Out",pUnit,"Out1")

  self:addBranch("num","Numerator",numerator,"In")
  self:addBranch("div","Divisor",divisor,"In")
end

function RationalVcaUnit:loadStereoGraph(pUnit)
  local vca1 = self:createObject("RationalMultiply","vca1",true)
  local vca2 = self:createObject("RationalMultiply","vca2",true)

  local numeratorL = self:createObject("GainBias","numeratorL")
  local numeratorRangeL = self:createObject("MinMax","numeratorRangeL")
  local divisorL = self:createObject("GainBias","divisorL")
  local divisorRangeL = self:createObject("MinMax","divisorRangeL")

  local numeratorR = self:createObject("GainBias","numeratorR")
  local numeratorRangeR = self:createObject("MinMax","numeratorRangeR")
  local divisorR = self:createObject("GainBias","divisorR")
  local divisorRangeR = self:createObject("MinMax","divisorRangeR")

  connect(numeratorL,"Out",numeratorRangeL,"In")
  connect(numeratorL,"Out",vca1,"Numerator")
  connect(divisorL,"Out",divisorRangeL,"In")
  connect(divisorL,"Out",vca1,"Divisor")

  connect(numeratorR,"Out",numeratorRangeR,"In")
  connect(numeratorR,"Out",vca2,"Numerator")
  connect(divisorR,"Out",divisorRangeR,"In")
  connect(divisorR,"Out",vca2,"Divisor")

  connect(pUnit,"In1",vca1,"In")
  connect(pUnit,"In2",vca2,"In")
  connect(vca1,"Out",pUnit,"Out1")
  connect(vca2,"Out",pUnit,"Out2")

  self:addBranch("num(L)","Left Numerator",numeratorL,"In")
  self:addBranch("div(L)","Left Divisor",divisorL,"In")
  self:addBranch("num(R)","Right Numerator",numeratorR,"In")
  self:addBranch("div(R)","Right Divisor",divisorR,"In")
end

function RationalVcaUnit:onLoadViews(objects,controls)
  local views = {
    collapsed = {},
  }

  if self.channelCount==2 then
    views.expanded = {"leftNum","leftDiv","rightNum","rightDiv"}

    controls.leftNum = GainBias {
      button = "num(L)",
      branch = self:getBranch("Left Numerator"),
      description = "Left Numerator",
      gainbias = objects.numeratorL,
      range = objects.numeratorRangeL,
      biasMap = Encoder.getMap("int[0,32]"),
      gainMap = Encoder.getMap("[-20,20]"),
      initialBias = 1,
      biasUnits = app.unitInteger
    }

    controls.leftDiv = GainBias {
      button = "div(L)",
      branch = self:getBranch("Left Divisor"),
      description = "Left Divisor",
      gainbias = objects.divisorL,
      range = objects.divisorRangeL,
      biasMap = Encoder.getMap("int[1,32]"),
      gainMap = Encoder.getMap("[-20,20]"),
      initialBias = 1,
      biasUnits = app.unitInteger
    }

    controls.rightNum = GainBias {
      button = "num(R)",
      branch = self:getBranch("Right Numerator"),
      description = "Right Numerator",
      gainbias = objects.numeratorR,
      range = objects.numeratorRangeR,
      biasMap = Encoder.getMap("int[0,32]"),
      gainMap = Encoder.getMap("[-20,20]"),
      initialBias = 1,
      biasUnits = app.unitInteger
    }

    controls.rightDiv = GainBias {
      button = "div(R)",
      branch = self:getBranch("Right Divisor"),
      description = "Right Divisor",
      gainbias = objects.divisorR,
      range = objects.divisorRangeR,
      biasMap = Encoder.getMap("int[1,32]"),
      gainMap = Encoder.getMap("[-20,20]"),
      initialBias = 1,
      biasUnits = app.unitInteger
    }
  else
    views.expanded = {"num","div"}

    controls.num = GainBias {
      button = "num",
      branch = self:getBranch("Numerator"),
      description = "Numerator",
      gainbias = objects.numerator,
      range = objects.numeratorRange,
      biasMap = Encoder.getMap("int[0,32]"),
      gainMap = Encoder.getMap("[-20,20]"),
      initialBias = 1,
      biasUnits = app.unitInteger
    }

    controls.div = GainBias {
      button = "div",
      branch = self:getBranch("Divisor"),
      description = "Divisor",
      gainbias = objects.divisor,
      range = objects.divisorRange,
      biasMap = Encoder.getMap("int[1,32]"),
      gainMap = Encoder.getMap("[-20,20]"),
      initialBias = 1,
      biasUnits = app.unitInteger
    }
  end

  return views
end

return RationalVcaUnit
