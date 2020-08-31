functor
import
	PlayerBasicAI
	Player45BasicAI
	Player45AdvancedAI
export
	playerGenerator:PlayerGenerator
define
	System
	PlayerGenerator
in
	fun {PlayerGenerator Kind Color IdNum}
		case Kind
			of player45BasicAI then
				{Player45BasicAI.portPlayer Color IdNum}
			[] player45AdvancedAI then
				{Player45AdvancedAI.portPlayer Color IdNum}
			[] playerBasicAI then
				{PlayerBasicAI.portPlayer Color IdNum}
			[] playerTestController then
				{playerTestController.portPlayer Color IdNum}
		end
	end
end
