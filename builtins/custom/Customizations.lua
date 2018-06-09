-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Encoder = require "Encoder"
local Source = require "Chain.Source"
local GainBias = require "Unit.ViewControl.GainBias"
local Comparator = require "Unit.ViewControl.Comparator"
local PitchControl = require "Unit.ViewControl.PitchControl"

local function createGate(unit,id,description)
  local object = unit:createObject("Comparator")
  object:setGateMode()
  local source = Source(id,object:getOutput("Out"))
  local branch = unit:addBranch(id,id,object,"In")
  local control = Comparator {
    button = id,
    description = description,
    branch = branch,
    edge = object
  }
  return control,source,branch,{object:name()}
end

local function createToggle(unit,id,description)
  local object = unit:createObject("Comparator",id.."_edge")
  object:setToggleMode()
  local source = Source(id,object:getOutput("Out"))
  local branch = unit:addBranch(id,id,object,"In")
  local control = Comparator {
    button = id,
    description = description,
    branch = branch,
    edge = object
  }
  return control,source,branch
end

local function createTrigger(unit,id,description)
  local object = unit:createObject("Comparator",id.."_edge")
  object:setTriggerMode()
  local source = Source(id,object:getOutput("Out"))
  local branch = unit:addBranch(id,id,object,"In")
  local control = Comparator {
    button = id,
    description = description,
    branch = branch,
    edge = object
  }
  return control,source,branch
end

local function createLinear(unit,id,description)
  local object = unit:createObject("GainBias",id.."_gainbias")
  local range = unit:createObject("MinMax",id.."_range")
  connect(object,"Out",range,"In")
  local branch = unit:addBranch(id,id,object,"In")
  local source = Source(id,object:getOutput("Out"))
  local control = GainBias {
    button = id,
    description = description,
    branch = branch,
    gainbias = object,
    range = range,
    -- same as Linear VCA
    biasMap = Encoder.getMap("[-5,5]"),
    biasUnits = app.unitNone,
    initialBias = 0.0,
    gainMap = Encoder.getMap("gain"),
  }
  return control,source,branch
end

local function createDecibel(unit,id,description)
  local object = unit:createObject("GainBias",id.."_gainbias")
  local range = unit:createObject("MinMax",id.."_range")
  connect(object,"Out",range,"In")
  local branch = unit:addBranch(id,id,object,"In")
  local source = Source(id,object:getOutput("Out"))
  local control = GainBias {
    button = id,
    description = description,
    branch = branch,
    gainbias = object,
    range = range,
    -- same as EQ3
    biasMap = Encoder.getMap("volume"),
    biasUnits = app.unitDecibels,
    gainMap = Encoder.getMap("[-10,10]"),
    initialBias = 1.0
  }
  return control,source,branch
end

local function createPitch(unit,id,description)
  local tune = unit:createObject("ConstantOffset",id.."_tune")
  local range = unit:createObject("MinMax",id.."_range")
  connect(tune,"Out",range,"In")
  local branch = unit:addBranch(id,id,tune,"In")
  local source = Source(id,tune:getOutput("Out"))
  local control = PitchControl {
    button = id,
    description = description,
    branch = branch,
    offset = tune,
    range = range,
  }
  return control,source,branch
end

local descriptors = {
  {
    description = "Linear",
    prefix = "lin",
    aliases = {"linear","Ax+B"},
    create = createLinear,
  },
  {
    description = "Decibel",
    prefix = "dB",
    aliases = {"decibel","dB(Ax+B)"},
    create = createDecibel,
  },
  {
    description = "Pitch",
    prefix = "V/oct",
    aliases = {"pitch","V/oct"},
    create = createPitch,
  },
  {
    description = "Gate",
    prefix = "gate",
    aliases = {"gate","Gate"},
    create = createGate,
  },
  {
    description = "Toggle",
    prefix = "sw",
    aliases = {"toggle"},
    create = createToggle,
  },
  {
    description = "Trigger",
    prefix = "trig",
    aliases = {"trigger"},
    create = createTrigger,
  },
}

-- hash aliases
local aliases = {}
for i,czd in ipairs(descriptors) do
  czd.type = czd.aliases[1]
  for j,alias in ipairs(czd.aliases) do
    aliases[alias] = czd
  end
end

local function lookup(type)
    return aliases[type]
end

return {
  lookup = lookup,
  descriptors = descriptors
}
