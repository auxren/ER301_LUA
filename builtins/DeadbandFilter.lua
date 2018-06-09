-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local DeadbandFilter = Class{}
DeadbandFilter:include(Unit)

function DeadbandFilter:init(args)
  args.title = "Deadband Filter"
  args.mnemonic = "DF"
  Unit.init(self,args)
end

function DeadbandFilter:onLoadGraph(pUnit,channelCount)
  local filterL = self:createObject("DeadbandFilter","filterL")
  connect(pUnit,"In1",filterL,"In")
  connect(filterL,"Out",pUnit,"Out1")

  if channelCount==2 then
    local filterR = self:createObject("DeadbandFilter","filterR")
    connect(pUnit,"In2",filterR,"In")
    connect(filterR,"Out",pUnit,"Out2")
    tie(filterR,"Threshold",filterL,"Threshold")
  end

  local threshold = self:createObject("ParameterAdapter","threshold")
  tie(filterL,"Threshold",threshold,"Out")

  self:addBranch("threshold","Threshold",threshold,"In")
end

local views = {
  expanded = {"threshold"},
  collapsed = {},
}

function DeadbandFilter:onLoadViews(objects,controls)

  controls.threshold = GainBias {
    button = "thresh",
    description = "Threshold",
    branch = self:getBranch("Threshold"),
    gainbias = objects.threshold,
    range = objects.threshold,
    biasMap = Encoder.getMap("[-1,1]"),
    biasUnits = app.unitNone,
    initialBias = 0.1,
  }

  return views
end

return DeadbandFilter
