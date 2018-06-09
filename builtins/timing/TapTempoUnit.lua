-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local Comparator = require "Unit.ViewControl.Comparator"
local InputComparator = require "Unit.ViewControl.InputComparator"
local ModeSelect = require "Unit.MenuControl.ModeSelect"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local TapTempoUnit = Class{}
TapTempoUnit:include(Unit)

function TapTempoUnit:init(args)
  args.title = "Tap Tempo"
  args.mnemonic = "TT"
  Unit.init(self,args)
end

function TapTempoUnit:onLoadGraph(pUnit, channelCount)
  -- create objects
  local tap = self:createObject("TapTempo","tap")
  tap:setBaseTempo(120)
  local clock = self:createObject("ClockInSeconds","clock")
  local tapEdge = self:createObject("Comparator","tapEdge")
  local syncEdge = self:createObject("Comparator","syncEdge")
  local width = self:createObject("ParameterAdapter","width")
  local multiplier = self:createObject("ParameterAdapter","multiplier")
  local divider = self:createObject("ParameterAdapter","divider")

  -- connect objects
  connect(pUnit,"In1",tapEdge,"In")
  connect(tapEdge,"Out",tap,"In")
  connect(clock,"Out",pUnit,"Out1")
  connect(syncEdge,"Out",clock,"Sync")

  -- tie parameters
  tie(clock,"Period",tap,"Base Period")
  tie(clock,"Pulse Width",width,"Out")
  tie(clock,"Multiplier",multiplier,"Out")
  tie(clock,"Divider",divider,"Out")

  -- register exported ports
  self:addBranch("sync","Sync",syncEdge,"In")
  self:addBranch("width","Width",width,"In")
  self:addBranch("multiplier","Multiplier",multiplier,"In")
  self:addBranch("divider","Divider",divider,"In")

  if channelCount>1 then
    connect(self.objects.clock,"Out",pUnit,"Out2")
  end
end

function TapTempoUnit:setAny()
  local map = Encoder.getMap("[1,32]")
  self.controls.mult:setBiasMap(app.unitNone,map)
  self.controls.mult:setFaderMap(app.unitNone,map)
  self.controls.div:setBiasMap(app.unitNone,map)
  self.controls.div:setFaderMap(app.unitNone,map)
end

function TapTempoUnit:setRational()
  local map = Encoder.getMap("int[1,32]")
  self.controls.mult:setBiasMap(app.unitInteger,map)
  self.controls.mult:setFaderMap(app.unitInteger,map)
  self.controls.div:setBiasMap(app.unitInteger,map)
  self.controls.div:setFaderMap(app.unitInteger,map)
end

local menu = {"infoHeader","rename","load","save","rational"}

function TapTempoUnit:onLoadMenu(objects,controls)
  controls.rational = ModeSelect {
    description = "Allowed Mult/Div",
    option = objects.clock:getOption("Rational"),
    choices = {"any","rational only"},
    boolean = true,
    onUpdate = function(choice)
      if choice=="any" then
        self:setAny()
      else
        self:setRational()
      end
    end
  }
  return menu
end

function TapTempoUnit:deserialize(t)
  Unit.deserialize(self,t)
  local Serialization = require "Persist.Serialization"
  local rational = Serialization.get("objects/clock/options/Rational",t)
  if rational and rational==0 then
    self:setAny()
  end
end

local views = {
  expanded = {"tap","mult","div","sync","width"},
  collapsed = {},
}

function TapTempoUnit:onLoadViews(objects,controls)
  controls.tap = InputComparator {
    button = "tap",
    description = "Tap",
    unit = self,
    edge = objects.tapEdge,
  }

  controls.mult = GainBias {
    button = "mult",
    description = "Clock Multiplier",
    branch = self:getBranch("Multiplier"),
    gainbias = objects.multiplier,
    range = objects.multiplier,
    biasMap = Encoder.getMap("int[1,32]"),
    biasUnits = app.unitInteger,
    initialBias = 1
  }

  controls.div = GainBias {
    button = "div",
    description = "Clock Divider",
    branch = self:getBranch("Divider"),
    gainbias = objects.divider,
    range = objects.divider,
    biasMap = Encoder.getMap("int[1,32]"),
    biasUnits = app.unitInteger,
    initialBias = 1
  }

  controls.sync = Comparator {
    button = "sync",
    description = "Sync",
    branch = self:getBranch("Sync"),
    edge = objects.syncEdge,
  }

  controls.width = GainBias {
    button = "width",
    description = "Pulse Width",
    branch = self:getBranch("width"),
    gainbias = objects.width,
    range = objects.width,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 0.5
  }

  return views
end

return TapTempoUnit
