functor
import
    Input
    OS
export
    portPlayer:StartPlayer
define
    InitRandomPosition
    IsValidPosition
    IsWater
    StartPlayer
    TreatStream
    UtilRandomInt
in
    fun {StartPlayer Color IdNum}
        Stream
        Port
    in
        {NewPort Stream Port}
        thread
            {TreatStream Stream id(id:IdNum color:Color name:playerTestController) false}
        end
        Port
    end
    
    fun {UtilRandomInt Min Max} 
        ({OS.rand} mod (Max - Min + 1)) + Min 
    end

    fun {IsWater Map pt(x:X y:Y) CurrX CurrY}
        case Map of (Value|Cs)|Rs then
            if CurrX < X then
                {IsWater Rs pt(x:X y:Y) CurrX+1 CurrY}
            elseif CurrY < Y then
                {IsWater Cs|Rs pt(x:X y:Y) CurrX CurrY+1}
            else Value == 0 end
        else false end
    end

    fun {IsValidPosition pt(x:X y:Y)}
        (X >= 1) andthen (Y >= 1) andthen (X =< 10) andthen (Y =< 10) andthen {IsWater Input.map pt(x:X y:Y) 1 1}
    end

    fun {InitRandomPosition}
        Position = pt(x:{UtilRandomInt 1 Input.nRow} y:{UtilRandomInt 1 Input.nColumn})
    in
        if {IsValidPosition Position} then Position
        else {InitRandomPosition} end
    end
    
    proc {TreatStream Stream IdPlayer IsDead}
		case Stream
            of nil then skip
            [] initPosition(?ID ?Position)|T then
                ID = IdPlayer
                Position = {InitRandomPosition}
                {TreatStream T IdPlayer IsDead}
            [] move(?ID ?Position ?Direction)|T then                
                ID = IdPlayer
                Position = pt(x:2 y:1)
                Direction = south
                {TreatStream T IdPlayer IsDead}
            [] chargeItem(?ID ?KindItem)|T then
                ID = IdPlayer
                KindItem = sonar
                {TreatStream T IdPlayer IsDead}
            [] fireItem(?ID ?KindFire)|T then
                ID = IdPlayer
                KindFire = sonar
                {TreatStream T IdPlayer IsDead}
            [] fireMine(?ID ?Mine)|T then
                ID = IdPlayer
                Mine = pt(x:1 y:1)
                {TreatStream T IdPlayer IsDead}
            [] isDead(?Answer)|T then
                Answer = IsDead
                {TreatStream T IdPlayer IsDead}
            [] sayMove(ID Direction)|T then
                {TreatStream T IdPlayer IsDead}
            [] saySurface(ID)|T then
                {TreatStream T IdPlayer IsDead}
            [] sayCharge(ID KindItem)|T then
                {TreatStream T IdPlayer IsDead}
            [] sayMinePlaced(ID)|T then
                {TreatStream T IdPlayer IsDead}
            [] sayMissileExplode(ID Position ?Message)|T then
                Message = sayDeath(IdPlayer)
                {TreatStream T IdPlayer true}
            [] sayMineExplode(ID Position ?Message)|T then
                Message = sayDeath(IdPlayer)
                {TreatStream T IdPlayer true}
            [] sayPassingDrone(Drone ?ID ?Answer)|T then
                ID = IdPlayer
                Answer = false
                {TreatStream T IdPlayer IsDead}
            [] sayAnswerDrone(Drone ID Answer)|T then
                {TreatStream T IdPlayer IsDead}
            [] sayPassingSonar(?ID ?Answer)|T then
                ID = IdPlayer
                Answer = pt(x:1 y:1)
                {TreatStream T IdPlayer IsDead}
            [] sayAnswerSonar(ID Answer)|T then
                {TreatStream T IdPlayer IsDead}
            [] sayDeath(ID)|T then
                {TreatStream T IdPlayer IsDead}
            [] sayDamageTaken(ID Damage LifeLeft)|T then
                {TreatStream T IdPlayer IsDead}
            [] _|T then
                {TreatStream T IdPlayer IsDead}
        end
    end
end
