-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local OffsetUnit = Class{}
OffsetUnit:include(Unit)

function OffsetUnit:init(args)
  args.title = "Offset"
  args.mnemonic = "Of"
  Unit.init(self,args)
end

-- creation/destruction states

function OffsetUnit:onLoadGraph(pUnit, channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function OffsetUnit:loadMonoGraph(pUnit)
  local sum = self:createObject("Sum","sum")
  local gainbias = self:createObject("GainBias","gainbias")
  local range = self:createObject("MinMax","range")

  connect(pUnit,"In1",sum,"Left")
  connect(gainbias,"Out",sum,"Right")
  connect(gainbias,"Out",range,"In")
  connect(sum,"Out",pUnit,"Out1")

  self:addBranch("offset","Offset",gainbias,"In")
end

function OffsetUnit:loadStereoGraph(pUnit)
  local sum1 = self:createObject("Sum","sum1")
  local gainbias1 = self:createObject("GainBias","gainbias1")
  local range1 = self:createObject("MinMax","range1")

  connect(pUnit,"In1",sum1,"Left")
  connect(gainbias1,"Out",sum1,"Right")
  connect(gainbias1,"Out",range1,"In")
  connect(sum1,"Out",pUnit,"Out1")

  self:addBranch("left","Left Offset",gainbias1,"In")

  local sum2 = self:createObject("Sum","sum2")
  local gainbias2 = self:createObject("GainBias","gainbias2")
  local range2 = self:createObject("MinMax","range2")

  connect(pUnit,"In1",sum2,"Left")
  connect(gainbias2,"Out",sum2,"Right")
  connect(gainbias2,"Out",range2,"In")
  connect(sum2,"Out",pUnit,"Out1")

  self:addBranch("right","Right Offset",gainbias2,"In")
end

function OffsetUnit:onLoadViews(objects,controls)
  local views = {
    collapsed = {},
  }

  if self.channelCount == 2 then

    controls.leftOffset = GainBias {
      button = "left",
      description = "Left Offset",
      branch = self:getBranch("Left Offset"),
      gainbias = objects.gainbias1,
      range = objects.range1,
      initialBias = 0.0,
    }

    controls.leftOffset = GainBias {
      button = "right",
      description = "Right Offset",
      branch = self:getBranch("Right Offset"),
      gainbias = objects.gainbias2,
      range = objects.range2,
      initialBias = 0.0,
    }

    views.expanded = {"leftOffset","rightOffset"}
  else

    controls.offset = GainBias {
      button = "amt",
      description = "Offset",
      branch = self:getBranch("Offset"),
      gainbias = objects.gainbias,
      range = objects.range,
      initialBias = 0.0,
    }

    views.expanded = {"offset"}
  end

  return views
end

function OffsetUnit:deserialize(t)
  Unit.deserialize(self,t)
  if self:getPresetVersion(t) < 1 then
    -- handle legacy preset (<v0.3.0)
    local Serialization = require "Persist.Serialization"
    local offset = Serialization.get("objects/offset/params/Offset",t)
    if self.channelCount==1 then
      if offset then
        app.log("%s:deserialize:legacy preset detected:setting offset to %s",self,offset)
        self.objects.gainbias:hardSet("Bias", offset)
      end
    elseif self.channelCount==2 then
      local offset1 = Serialization.get("objects/offset1/params/Offset",t)
      if offset1 then
        app.log("%s:deserialize:legacy preset detected:setting offset1 to %s",self,offset1)
        self.objects.gainbias1:hardSet("Bias", offset1)
      end
      local offset2 = Serialization.get("objects/offset2/params/Offset",t)
      if offset2 then
        app.log("%s:deserialize:legacy preset detected:setting offset2 to %s",self,offset2)
        self.objects.gainbias2:hardSet("Bias", offset2)
      end
    end
  end
end

return OffsetUnit
