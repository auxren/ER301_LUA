-- GLOBALS: app, os, verboseLevel, connect, tie
local Class = require "Base.Class"
local Unit = require "Unit"
local ModeSelect = require "Unit.MenuControl.ModeSelect"
local GainBias = require "Unit.ViewControl.GainBias"
local InputComparator = require "Unit.ViewControl.InputComparator"
local Encoder = require "Encoder"

local ClockBase = Class{}
ClockBase:include(Unit)

function ClockBase:init(args)
  args.title = "Clock"
  args.mnemonic = "C"
  Unit.init(self,args)
end

function ClockBase:loadBaseGraph(pUnit, channelCount, clock)
  -- create objects
  local syncEdge = self:createObject("Comparator","syncEdge")
  local width = self:createObject("ParameterAdapter","width")
  local multiplier = self:createObject("ParameterAdapter","multiplier")
  local divider = self:createObject("ParameterAdapter","divider")

  -- connect objects
  connect(pUnit,"In1",syncEdge,"In")
  connect(clock,"Out",pUnit,"Out1")
  connect(syncEdge,"Out",clock,"Sync")

  -- tie parameters
  tie(clock,"Pulse Width",width,"Out")
  tie(clock,"Multiplier",multiplier,"Out")
  tie(clock,"Divider",divider,"Out")

  -- register exported ports
  self:addBranch("width","Width",width,"In")
  self:addBranch("multiplier","Multiplier",multiplier,"In")
  self:addBranch("divider","Divider",divider,"In")

  if channelCount>1 then
    connect(self.objects.clock,"Out",pUnit,"Out2")
  end
end


function ClockBase:loadBaseView(objects,controls)
  controls.sync = InputComparator {
    button = "sync",
    description = "Sync",
    unit = self,
    edge = objects.syncEdge,
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

end



function ClockBase:setAny()
  local map = Encoder.getMap("[1,32]")
  self.controls.mult:setBiasMap(app.unitNone,map)
  self.controls.mult:setFaderMap(app.unitNone,map)
  self.controls.div:setBiasMap(app.unitNone,map)
  self.controls.div:setFaderMap(app.unitNone,map)
end

function ClockBase:setRational()
  local map = Encoder.getMap("int[1,32]")
  self.controls.mult:setBiasMap(app.unitInteger,map)
  self.controls.mult:setFaderMap(app.unitInteger,map)
  self.controls.div:setBiasMap(app.unitInteger,map)
  self.controls.div:setFaderMap(app.unitInteger,map)
end

local menu = {"infoHeader","rename","load","save","rational"}

function ClockBase:onLoadMenu(objects,controls)
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

function ClockBase:deserialize(t)
  Unit.deserialize(self,t)
  local Serialization = require "Persist.Serialization"
  local rational = Serialization.get("objects/clock/options/Rational",t)
  if rational and rational==0 then
    self:setAny()
  end
end

return ClockBase
