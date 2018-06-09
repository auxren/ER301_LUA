local Class = require "Base.Class"
local BasePlayer = require "builtins.Player.BasePlayer"

local NativeSpeedPlayerUnit = Class{}
NativeSpeedPlayerUnit:include(BasePlayer)


function NativeSpeedPlayerUnit:init(args)
  args.title = "Native Player"
  args.mnemonic = "NP"
  args.enableVariableSpeed = false
  BasePlayer.init(self,args)
end

return NativeSpeedPlayerUnit
