-- GLOBALS: app, connect
local Class = require "Base.Class"
local Unit = require "Unit"
local PitchControl = require "Unit.ViewControl.PitchControl"
local GainBias = require "Unit.ViewControl.GainBias"
local Comparator = require "Unit.ViewControl.Comparator"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local FMOperator = Class{}
FMOperator:include(Unit)

function FMOperator:init(args)
  args.title = "FM Op"
  args.mnemonic = "FM"
  args.version = 2
  Unit.init(self,args)
end

function FMOperator:onLoadGraph(pUnit,channelCount)
  local carrier = self:createObject("SineOscillator","carrier")
  local modulator = self:createObject("SineOscillator","modulator")
  local rational = self:createObject("RationalMultiply","rational",true)
  local multiply = self:createObject("Multiply","multiply")
  local tune = self:createObject("ConstantOffset","tune")
  local tuneRange = self:createObject("MinMax","tuneRange")
  local f0 = self:createObject("GainBias","f0")
  local f0Range = self:createObject("MinMax","f0Range")
  local vca = self:createObject("Multiply","vca")
  local level = self:createObject("GainBias","level")
  local levelRange = self:createObject("MinMax","levelRange")
  local num = self:createObject("GainBias","num")
  local numRange = self:createObject("MinMax","numRange")
  local den = self:createObject("GainBias","den")
  local denRange = self:createObject("MinMax","denRange")
  local index = self:createObject("GainBias","index")
  local indexRange = self:createObject("MinMax","indexRange")

  connect(tune,"Out",tuneRange,"In")
  connect(tune,"Out",carrier,"V/Oct")

  connect(f0,"Out",carrier,"Fundamental")
  connect(f0,"Out",f0Range,"In")

  connect(f0,"Out",rational,"In")
  connect(rational,"Out",modulator,"Fundamental")
  connect(num,"Out",rational,"Numerator")
  connect(num,"Out",numRange,"In")
  connect(den,"Out",rational,"Divisor")
  connect(den,"Out",denRange,"In")

  connect(index,"Out",multiply,"Left")
  connect(index,"Out",indexRange,"In")
  connect(modulator,"Out",multiply,"Right")
  connect(multiply,"Out",carrier,"Phase")

  connect(level,"Out",levelRange,"In")
  connect(level,"Out",vca,"Left")

  connect(carrier,"Out",vca,"Right")
  connect(vca,"Out",pUnit,"Out1")

  self:addBranch("level","Level",level,"In")
  self:addBranch("V/oct","V/Oct",tune,"In")
  self:addBranch("index","Index",index,"In")
  self:addBranch("f0","Fundamental",f0,"In")
  self:addBranch("num","Numerator",num,"In")
  self:addBranch("den","Denominator",den,"In")

  if channelCount > 1 then
    connect(self.objects.vca,"Out",pUnit,"Out2")
  end
end

local views = {
  expanded = {"tune","freq","num","den","index","level"},
  collapsed = {},
}

function FMOperator:onLoadViews(objects,controls)
  controls.tune = PitchControl {
    button = "V/oct",
    branch = self:getBranch("V/Oct"),
    description = "V/oct",
    offset = objects.tune,
    range = objects.tuneRange
  }

  controls.freq = GainBias {
    button = "f0",
    description = "Fundamental",
    branch = self:getBranch("Fundamental"),
    gainbias = objects.f0,
    range = objects.f0Range,
    biasMap = Encoder.getMap("oscFreq"),
    biasUnits = app.unitHertz,
    initialBias = 27.5,
    gainMap = Encoder.getMap("freqGain"),
    scaling = app.octaveScaling
  }

  controls.num = GainBias {
    button = "num",
    description = "Numerator",
    branch = self:getBranch("Numerator"),
    gainbias = objects.num,
    range = objects.numRange,
    biasMap = Encoder.getMap("int[1,32]"),
    biasUnits = app.unitInteger,
    initialBias = 1
  }

  controls.den = GainBias {
    button = "den",
    description = "Denominator",
    branch = self:getBranch("Denominator"),
    gainbias = objects.den,
    range = objects.denRange,
    biasMap = Encoder.getMap("int[1,32]"),
    biasUnits = app.unitInteger,
    initialBias = 1
  }

  controls.index = GainBias {
    button = "index",
    description = "Index",
    branch = self:getBranch("Index"),
    gainbias = objects.index,
    range = objects.indexRange,
    initialBias = 0.1,
  }

  controls.level = GainBias {
    button = "level",
    description = "Level",
    branch = self:getBranch("Level"),
    gainbias = objects.level,
    range = objects.levelRange,
    initialBias = 0.5,
  }

  return views
end

return FMOperator
