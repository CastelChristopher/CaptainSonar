functor
import
    Input
    OS
    System
export
    portPlayer:StartPlayer
define
    % functions (utils)
    UtilRandomInt
    MapRecord
    IsValidPosition
    IsWater
    IsPositionAlreadyVisited
    RandomDirection
    GetRandomBoundedPosition
    ManhattanDistance
    % functions
    TreatStream
    StartPlayer
    GetRandomPosition
    Move
    ChargeItem
    FireItem
    FireMine
    HandleExplosion
    IsDetectedByDrone
    GenerateSonarOutput
in
    fun {StartPlayer Color IdNum}
        Stream
        Port
    in
        {NewPort Stream Port}
        thread
            %            Stream MyID VisitedPositions MyDirection CanDive Charges PlacedMines
            {TreatStream Stream id(id:IdNum color:Color name:player45BasicAI) nil surface true charges(mine:0 missile:0 drone:0 sonar:0) nil Input.maxDamage}
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

    fun {GetRandomPosition}
        NewRandomPosition = pt(x:{UtilRandomInt 1 Input.nRow} y:{UtilRandomInt 1 Input.nColumn})
    in
        if {IsValidPosition NewRandomPosition} then
            NewRandomPosition
        else
            {GetRandomPosition}
        end
    end

    fun {GetRandomBoundedPosition MyPosition Min Max}
        NewRandomPositionX
        NewRandomPositionY
        RandomPosition
        R
    in
        NewRandomPositionX = {UtilRandomInt 0 Max}
        if (NewRandomPositionX < Min) then
            NewRandomPositionY = {UtilRandomInt Min-NewRandomPositionX Max-NewRandomPositionX}
        else
            NewRandomPositionY = {UtilRandomInt 0 Max-NewRandomPositionX}
        end

        case {UtilRandomInt 1 4}
            of 1 then RandomPosition = pt(x:(MyPosition.x + NewRandomPositionX) y:(MyPosition.y + NewRandomPositionY))
            [] 2 then RandomPosition = pt(x:(MyPosition.x + NewRandomPositionX) y:(MyPosition.y - NewRandomPositionY))
            [] 3 then RandomPosition = pt(x:(MyPosition.x - NewRandomPositionX) y:(MyPosition.y + NewRandomPositionY))
            [] 4 then RandomPosition = pt(x:(MyPosition.x - NewRandomPositionX) y:(MyPosition.y - NewRandomPositionY))
        end

        % {System.show getRandomBoundedPosition(RandomPosition)}

        if {IsValidPosition RandomPosition} then
            RandomPosition
        else
            {GetRandomBoundedPosition MyPosition Min Max}
        end
    end

    fun {IsPositionAlreadyVisited Positions Position}
        case Positions
            of pt(x:X y:Y)|OtherPositions then
                if X == Position.x andthen Y == Position.y then
                    true
                else
                    {IsPositionAlreadyVisited OtherPositions Position}
                end
            [] nil then false
        end
    end

    fun {RandomDirection}
        Rand = {UtilRandomInt 1 5}
        Directions = [east north south west surface]
        fun {LoopRandomDirection Directions A}
            case Directions
                of CurrentDirection|OtherDirections then
                    if Rand == A then CurrentDirection
                    else {LoopRandomDirection OtherDirections A+1} end
            end
        end
    in
        {LoopRandomDirection Directions 1}
    end

    proc {Move InitialPosition VisitedPositions CanDive ?Position ?Direction}
        RandomNewDirection RandomNewPosition
    in
        if {Not CanDive} then
            Position = InitialPosition
            Direction = surface
        else IsSuitablePosition in
            RandomNewDirection = {RandomDirection}
            case RandomNewDirection
                of east then
                    RandomNewPosition = pt(x:InitialPosition.x y:(InitialPosition.y + 1))
                [] north then
                    RandomNewPosition = pt(x:(InitialPosition.x - 1) y:InitialPosition.y)
                [] south then
                    RandomNewPosition = pt(x:(InitialPosition.x + 1) y:InitialPosition.y)
                [] west then
                    RandomNewPosition = pt(x:InitialPosition.x y:(InitialPosition.y - 1))
                [] surface then
                    RandomNewPosition = InitialPosition
            end
            IsSuitablePosition = ({Not {IsPositionAlreadyVisited VisitedPositions RandomNewPosition}} andthen {IsValidPosition RandomNewPosition})
            if RandomNewDirection == surface orelse IsSuitablePosition then
                Position = RandomNewPosition
                Direction = RandomNewDirection
            else
                {Move InitialPosition VisitedPositions CanDive Position Direction}
            end
        end
    end

    proc {MapRecord RecordIn RecordOut F}
        A = {Record.arity RecordIn}
        proc {Loop L}
            case L
                of nil then skip
                [] H|T then
                    RecordOut.H = {F H RecordIn.H}
                    {Loop T}
            end
        end
    in
        RecordOut = {Record.make {Record.label RecordIn} A}
        {Loop A}
    end

    proc {ChargeItem Charges ?CreatedItem ?UpdatedCharges}
        Items = [mine missile drone sonar]
        proc {Loop Items Rand A}
            case Items
                of Item|OtherItems then
                    if Rand == A then
                        if Charges.Item < Input.Item then
                            {MapRecord
                                Charges
                                UpdatedCharges
                                fun {$ ItemLabel Charge}
                                    if ItemLabel == Item then Charge+1 else Charge end
                                end
                            }
                            if UpdatedCharges.Item >= Input.Item then
                                CreatedItem = Item
                            else
                                CreatedItem = null
                            end
                        else
                            % TODO : what if all items are fully charged ?
                            {Loop Items {UtilRandomInt 1 4} 1}
                        end
                    else
                        {Loop OtherItems Rand A+1}
                    end
                [] nil then
                    CreatedItem = null
            end
        end
    in
        % TODO : loop over fields
        if Charges.mine >= Input.mine andthen Charges.missile >= Input.missile andthen Charges.drone >= Input.drone andthen Charges.sonar >= Input.sonar then
            CreatedItem = null
            UpdatedCharges = Charges
        else
            {Loop Items {UtilRandomInt 1 4} 1}
        end
    end

    proc {FireItem Charges MyPosition ?KindFire ?UpdatedCharges}
        AllItems = [mine missile drone sonar]
        fun {GetAllValidItems Items}
            % {System.show 'GetAllValidItems'}
            case Items
                of Item|OtherItems then
                    if Charges.Item >= Input.Item then
                        Item|{GetAllValidItems OtherItems}
                    else
                        {GetAllValidItems OtherItems}
                    end
                [] nil then
                    nil
            end
        end
        fun {GetItem ChargedItems N}
            % {System.show 'GetItem'}
            if N == 1 then
                ChargedItems.1
            else
                {GetItem ChargedItems.2 N-1}
            end
        end
        ChargedItems
        NumberChargedItems
        ChosenItem
    in
        ChargedItems = {GetAllValidItems AllItems}
        NumberChargedItems = {List.length ChargedItems}
        if NumberChargedItems == 0 then
            UpdatedCharges = Charges
            KindFire = null
        else
            ChosenItem = {GetItem ChargedItems {UtilRandomInt 1 NumberChargedItems}}
            case ChosenItem
                of mine then
                    KindFire = mine({GetRandomBoundedPosition MyPosition Input.minDistanceMine Input.maxDistanceMine})
                [] missile then
                    KindFire = missile({GetRandomBoundedPosition MyPosition Input.minDistanceMissile Input.maxDistanceMissile})
                [] drone then
                    if {UtilRandomInt 1 2} == 1 then
                        KindFire = drone(row {UtilRandomInt 1 Input.nRow})
                    else
                        KindFire = drone(column {UtilRandomInt 1 Input.nColumn})
                    end
                [] sonar then
                    KindFire = sonar
                else
                    KindFire = null
            end
            {MapRecord
                Charges
                UpdatedCharges
                fun {$ ItemLabel Charge}
                    if ItemLabel == ChosenItem then 0 else Charge end
                end
            }
        end
    end

    fun {FireMine PlacedMines MyPosition}
        RandomMine
        Length
    in
        Length = {List.length PlacedMines}
        if Length == 0 then null
        else
            RandomMine = {List.nth PlacedMines {UtilRandomInt 1 Length}}
            if RandomMine == MyPosition then
                {FireMine {List.subtract PlacedMines RandomMine} MyPosition}
            else
                RandomMine
            end
        end
    end

    fun {ManhattanDistance P1 P2}
        {Number.abs (P1.x - P2.x)} + {Number.abs (P1.y - P2.y)}
    end

    fun {HandleExplosion ExplosionPosition MyID MyPosition Life}
        DistanceFromExplosion
        Damage
        LifeLeft
    in
        DistanceFromExplosion = {ManhattanDistance ExplosionPosition MyPosition}
        if DistanceFromExplosion >= 2 then
            null
        else
            Damage = 2 - DistanceFromExplosion
            LifeLeft = Life - Damage
            if LifeLeft =< 0 then
                sayDeath(MyID)
            else
                sayDamageTaken(MyID Damage LifeLeft)
            end
        end
    end

    fun {IsDetectedByDrone Drone Position}
        case Drone
            of drone(row X) then
                X == Position.x
            [] drone(column Y) then
                Y == Position.y
            [] _ then
                {System.show '[Player][IsDetectedByDrone] drone could not be matched : '#_}
        end
    end

    fun {GenerateSonarOutput Position}
        Row
        Col
        Output = pt(x:Row y:Col)
        IsColFake = ({UtilRandomInt 1 2} == 1)
    in
        if IsColFake then
            Row = Position.x
            Col = ((Position.y + (Input.nColumn div 2)) mod Input.nColumn) + 1
        else
            Row = ((Position.x + (Input.nRow div 2)) mod Input.nRow) + 1
            Col = Position.y
        end
        Output
    end

    % Charges = charges(mine:<int> missile:<int> drone:<int> sonar:<int>)
    proc {TreatStream Stream MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
		case Stream
            of nil then skip
            [] initPosition(?ID ?Position)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][initPosition]')}
                ID = MyID
                Position = {GetRandomPosition}
                {TreatStream T MyID Position|nil MyDirection true Charges PlacedMines Life}
            [] move(?ID ?Position ?Direction)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][move]')}
                if Life =< 0 then
                    ID = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                else
                    ID = MyID
                    {Move VisitedPositions.1 VisitedPositions CanDive Position Direction}
                    % {System.show randomRealPosition(Position)}
                    if Direction == surface then
                        {TreatStream T MyID Position|nil Direction false Charges PlacedMines Life}
                    else
                        {TreatStream T MyID Position|VisitedPositions Direction CanDive Charges PlacedMines Life}
                    end
                end
            [] dive|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][dive]')}
                {TreatStream T MyID VisitedPositions MyDirection true Charges PlacedMines Life}
            [] chargeItem(?ID ?KindItem)|T then UpdatedCharges in % OK
                % {System.show treat_stream('[Player ('#MyID#')][chargeItem]')}
                if Life =< 0 then
                    ID = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                else
                    ID = MyID
                    {ChargeItem Charges KindItem UpdatedCharges}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive UpdatedCharges PlacedMines Life}
                end
            [] fireItem(?ID ?KindFire)|T then UpdatedCharges in % OK
                % {System.show treat_stream('[Player ('#MyID#')][fireItem]')}
                if Life =< 0 then
                    ID = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                else
                    ID = MyID
                    {FireItem Charges VisitedPositions.1 KindFire UpdatedCharges}
                    case KindFire of mine(Position) then
                        {TreatStream T MyID VisitedPositions MyDirection CanDive UpdatedCharges Position|PlacedMines Life}
                    else
                        {TreatStream T MyID VisitedPositions MyDirection CanDive UpdatedCharges PlacedMines Life}
                    end
                end
            [] fireMine(?ID ?Mine)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][fireMine]')}
                if Life =< 0 then
                    ID = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                else
                    ID = MyID
                    Mine = {FireMine PlacedMines VisitedPositions.1}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges {List.subtract PlacedMines Mine} Life}
                end
            [] isDead(?Answer)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][isDead]')}
                if Life =< 0 then
                    Answer = true
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                else
                    Answer = false
                    {TreatStream T MyID VisitedPositions MyDirection true Charges PlacedMines Life}
                end
            [] sayMove(ID Direction)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayMove]')}
                {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
            [] saySurface(ID)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][saySurface]')}
                {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
            [] sayCharge(ID KindItem)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayCharge]')}
                {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
            [] sayMinePlaced(ID)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayMinePlaced]')}
                {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
            [] sayMissileExplode(ID Position ?Message)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayMissileExplode]')}
                if Life =< 0 then
                    Message = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                else
                    Message = {HandleExplosion Position MyID VisitedPositions.1 Life}
                    case Message
                        of sayDeath(MyID) then
                            {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines 0}
                        [] sayDamageTaken(MyID Damage LifeLeft) then
                            {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines LifeLeft}
                        else % null
                            {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                    end
                end
            [] sayMineExplode(ID Position ?Message)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayMineExplode]')}
                if Life =< 0 then
                    Message = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                else
                    Message = {HandleExplosion Position MyID VisitedPositions.1 Life}
                    case Message
                        of sayDeath(MyID) then
                            {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines 0}
                        [] sayDamageTaken(MyID Damage LifeLeft) then
                            {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines LifeLeft}
                        else % null
                            {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                    end
                end
            [] sayPassingDrone(Drone ?ID ?Answer)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')[sayPassingDrone]')}
                if Life =< 0 then
                    ID = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                else
                    ID = MyID
                    Answer = {IsDetectedByDrone Drone VisitedPositions.1}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                end
            [] sayAnswerDrone(Drone ID Answer)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayAnswerDrone]')}
                {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
            [] sayPassingSonar(?ID ?Answer)|T then
                % {System.show treat_stream('[Player ('#MyID#')][sayPassingSonar')} %] OK
                if Life =< 0 then
                    ID = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                else
                    ID = MyID
                    Answer = {GenerateSonarOutput VisitedPositions.1}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
                end
            [] sayAnswerSonar(ID Answer)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayAnswerSonar]')}
                {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
            [] sayDeath(ID)|T then
                % {System.show treat_stream('[Player ('#MyID#')][sayDeath')} %] OK
                {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
            [] sayDamageTaken(ID Damage LifeLeft)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayDamageTaken]')}
                {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
            [] _|T then
                {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life}
        end
    end
end
