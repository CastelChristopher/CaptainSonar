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
    GetRandomBoundPosition
    ManhattanDistance
    ShuffleList
    HasChargedMissile
    FilterOpponentsPosition
    AmIGoingToBeHurt
    PredicateBothUnknown
    PredicateAtLeastUnknown
    PredicateBothUncertain
    PredicateAtLeastOneUncertain
    PredicateBothCertain
    UpdateOpponentsIntel
    % functions
    TreatStream
    StartPlayer
    GetInitPosition
    Move
    ChargeItem
    FireItem
    FireMine
    HandleExplosion
    IsDetectedByDrone
    GenerateSonarOutput
    MoveCloser
    MoveFarther
    FindValidAdjacentMoves
    FindClosestOpponents
    FindOpponentWithID
    FindBestMove
    ValidAdjacentMoves
    SayMoveUpdateIntel
    InsertIfNotExist
    RemoveIfExist
    SayDroneUpdateIntel
    SaySonarUpdateIntel

    fun {StartPlayer Color IdNum}
        Stream
        Port
    in
        {NewPort Stream Port}
        thread
            %            Stream MyID VisitedPositions MyDirection CanDive Charges PlacedMines DeadOpponents
            {TreatStream Stream id(id:IdNum color:Color name:player45AdvancedAI) nil surface true charges(mine:0 missile:0 drone:0 sonar:0) nil Input.maxDamage nil nil}
        end
        Port
    end

    % Returns a random integer between min and max included
    fun {UtilRandomInt Min Max}
        ({OS.rand} mod (Max - Min + 1)) + Min
    end

    % Returns true if the position if a water square
    fun {IsWater Map pt(x:X y:Y) CurrX CurrY}
        case Map of (Value|Cs)|Rs then
            if CurrX < X then
                {IsWater Rs pt(x:X y:Y) CurrX+1 CurrY}
            elseif CurrY < Y then
                {IsWater Cs|Rs pt(x:X y:Y) CurrX CurrY+1}
            else Value == 0 end
        else false end
    end

    % Returns true if the position is water square and is not out of the map
    fun {IsValidPosition pt(x:X y:Y)}
        (X >= 1) andthen (Y >= 1) andthen (X =< 10) andthen (Y =< 10) andthen {IsWater Input.map pt(x:X y:Y) 1 1}
    end

    % Returns a position whose distance from MyPosition is between Min and Max included
    fun {GetRandomBoundPosition MyPosition Min Max}
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

        if {IsValidPosition RandomPosition} then
            RandomPosition
        else
            {GetRandomBoundPosition MyPosition Min Max}
        end
    end

    % Returns true if Positions contains Position
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

    % Returns a shuffled version of the list L
    fun {ShuffleList L}
        Length
    in
        Length = {List.length L}
        if Length == 1 then
            L.1|nil
        else Element in
            Element = {List.nth L {UtilRandomInt 1 Length}}
            Element|{ShuffleList {List.subtract L Element}}
        end
    end

    % Applies the function F on each element of RecordIn and binds the resulting record to RecordOut
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

    % Returns the Manhattan distance between position P1 and position P2
    fun {ManhattanDistance P1 P2}
        {Number.abs (P1.x - P2.x)} + {Number.abs (P1.y - P2.y)}
    end

    % Returns the first valid Position pt(x y) starting from the (1,1) coordinate
    % Possible positions are evaluated in the row -> column order
    fun {GetInitPosition}
        fun {Loop X Y}
            Position = pt(x:X y:Y)
        in
            if {IsValidPosition Position} then
                Position
            else
                if X =< Input.nRow then
                    {Loop X+1 Y}
                else
                    {Loop 1 Y+1}
                end
            end
        end
    in
        {Loop 1 1}
    end

    % Returs a list of all valid next moves (i.e. position + direction tuples)
    % These positions are adjacent to the current player position
    fun {FindValidAdjacentMoves InitialPosition VisitedPositions}
        PossibleMoves = [
            mv(dir:south pt:pt(x:(InitialPosition.x + 1) y:InitialPosition.y))
            mv(dir:north pt:pt(x:(InitialPosition.x - 1) y:InitialPosition.y))
            mv(dir:east pt:pt(x:(InitialPosition.x) y:(InitialPosition.y + 1)))
            mv(dir:west pt:pt(x:(InitialPosition.x) y:(InitialPosition.y - 1)))
        ]
        fun {FindValidAdjacentMovesLoop InitialPosition VisitedPositions PossibleMoves}
            case PossibleMoves
                of PossibleMove|Others then
                    if ({Not {IsPositionAlreadyVisited VisitedPositions PossibleMove.pt}} andthen {IsValidPosition PossibleMove.pt}) then
                        PossibleMove|{FindValidAdjacentMovesLoop InitialPosition VisitedPositions Others}
                    else
                        {FindValidAdjacentMovesLoop InitialPosition VisitedPositions Others}
                    end
                [] nil then
                    nil
            end
        end
    in
        {FindValidAdjacentMovesLoop InitialPosition VisitedPositions PossibleMoves}
    end

    % Returns true if the missile weapon is charged
    fun {HasChargedMissile Charges}
        Charges.missile >= Input.missile
    end

    % Finds the closest opponents
    % The function returns null if there are not enough information to find a closest opponent
    fun {FindClosestOpponents InitialPosition OpponentsIntel}
        fun {FindClosestOpponentsLoop Opponents MinDistance ClosestOpponentFound}
            case Opponents
                of opponent(id:ID pt:pt(x:X y:Y))|Others then
                    if X == unknown orelse Y == unknown orelse X < 0 orelse Y < 0 then
                        {FindClosestOpponentsLoop Others MinDistance ClosestOpponentFound}
                    else PossibleMinDistance in
                        PossibleMinDistance = {ManhattanDistance InitialPosition pt(x:X y:Y)}
                        if PossibleMinDistance =< MinDistance then
                            {FindClosestOpponentsLoop Others PossibleMinDistance opponent(id:ID pt:pt(x:X y:Y))}
                        else
                            {FindClosestOpponentsLoop Others MinDistance ClosestOpponentFound}
                        end
                    end
                [] nil then
                    ClosestOpponentFound
                else
                    {System.show error('FindClosestOpponentsLoop' MinDistance ClosestOpponentFound)}
            end
        end
    in
        {FindClosestOpponentsLoop OpponentsIntel Input.nRow*Input.nColumn null}
    end

    % Binds Position and Direction to the smallest distance between ValidAdjacentMoves.pt and ClosestPoint pt(x:X y:Y)
    % ValidAdjacentMoves must be a non empty list
    proc {MoveCloser ClosestPoint ValidAdjacentMoves ?Position ?Direction}
        proc {MoveCloserLoop Moves MinDistance BestMove}
            case Moves
                of Move|Others then PossibleMinDistance in
                    PossibleMinDistance = {ManhattanDistance Move.pt ClosestPoint}
                    if PossibleMinDistance =< MinDistance then
                        {MoveCloserLoop Others PossibleMinDistance Move}
                    else
                        {MoveCloserLoop Others MinDistance BestMove}
                    end
                [] nil then
                    Position = BestMove.pt
                    Direction = BestMove.dir
                else
                    {System.show error('MoveCloserLoop' Moves MinDistance BestMove)}
            end
        end
    in
        {MoveCloserLoop ValidAdjacentMoves Input.nRow*Input.nColumn ValidAdjacentMoves.1}
    end

    % Binds Position and Direction to the highest distance between ValidAdjacentMoves.pt and ClosestPoint pt(x:X y:Y)
    % ValidAdjacentMoves must be a non empty list
    proc {MoveFarther ClosestPoint ValidAdjacentMoves ?Position ?Direction}
        proc {MoveFartherLoop Moves MaxDistance BestMove}
            case Moves
                of Move|Others then PossibleMaxDistance in
                    PossibleMaxDistance = {ManhattanDistance Move.pt ClosestPoint}
                    if PossibleMaxDistance >= MaxDistance then
                        {MoveFartherLoop Others PossibleMaxDistance Move}
                    else
                        {MoveFartherLoop Others MaxDistance BestMove}
                    end
                [] nil then
                    Position = BestMove.pt
                    Direction = BestMove.dir
                else
                    {System.show error('MoveFartherLoop' Moves MaxDistance BestMove)}
            end
        end
    in
        {MoveFartherLoop ValidAdjacentMoves ~1 ValidAdjacentMoves.1}
    end

    % The ship moves closer to the closest opponent if he has a missile charged, otherwise he moves farther from him
    % If several opponents are at an equal distance, he chooses the last evaluated one
    proc {FindBestMove InitialPosition OpponentsIntel ValidAdjacentMoves Charges ?Position ?Direction}
        ClosestOpponent
    in
        ClosestOpponent = {FindClosestOpponents InitialPosition OpponentsIntel} % opponent(id:ID pt:pt(x:X y:Y))
        if ClosestOpponent == null then RandomMove in
            RandomMove = {List.nth ValidAdjacentMoves {UtilRandomInt 1 {List.length ValidAdjacentMoves}}}
            Position = RandomMove.pt
            Direction = RandomMove.dir
        else Distance in
            Distance = {ManhattanDistance ClosestOpponent.pt InitialPosition}
            if ({HasChargedMissile Charges} orelse Distance >= Input.maxDistanceMissile) andthen Distance > (Input.minDistanceMissile + 1) then
                {MoveCloser ClosestOpponent.pt ValidAdjacentMoves ?Position ?Direction}
            else
                {MoveFarther ClosestOpponent.pt ValidAdjacentMoves ?Position ?Direction}
            end
        end
    end

    % Binds Position to a unvisited position
    % Moves to the surface only if required or neccessary
    proc {Move InitialPosition VisitedPositions CanDive OpponentsIntel Charges ?Position ?Direction}
        ValidAdjacentMoves
    in
        ValidAdjacentMoves = {FindValidAdjacentMoves InitialPosition VisitedPositions}
        if {Not CanDive} orelse {List.length ValidAdjacentMoves} == 0 then
            Position = InitialPosition
            Direction = surface
        else
            {FindBestMove InitialPosition OpponentsIntel ValidAdjacentMoves Charges ?Position ?Direction}
        end
    end

    % Predicates used to filter OpponentsIntel
    fun {PredicateBothUnknown X Y}
        X == unknown andthen Y == unknown
    end

    fun {PredicateAtLeastUnknown X Y}
        X == unknown orelse Y == unknown
    end

    fun {PredicateBothUncertain X Y}
        X \= unknown andthen Y \= unknown andthen X < 0 andthen Y < 0
    end

    fun {PredicateAtLeastOneUncertain X Y}
         (X \= unknown andthen X < 0) orelse (Y \= unknown andthen Y < 0)
    end

    fun {PredicateBothCertain X Y}
        X \= unknown andthen X > 0 andthen Y \= unknown andthen Y > 0
    end

    % Returns the list of the opponents that have a valid position under the predicate P
    fun {FilterOpponentsPosition OpponentsIntel P}
        case OpponentsIntel
            of opponent(id:ID pt:pt(x:X y:Y))|Others then
                if {P X Y} then
                    opponent(id:ID pt:pt(x:X y:Y))|{FilterOpponentsPosition Others P}
                else
                    {FilterOpponentsPosition Others P}
                end
            [] nil then
                nil
            else
                {System.show error('FilterOpponentsPosition' OpponentsIntel)}
        end
    end

    % Charges an item
    % Binds CreatedItem to the newly charged item
    % Charges are updated: the chosen item will have one more charge. This resulting charges tuple is bound to UpdatedCharges
    % If all items are already charged then ChargedItem is bound to null
    proc {ChargeItem Charges MyPosition OpponentsIntel ?CreatedItem ?UpdatedCharges}
        PreferencesOrder = [sonar drone missile mine]

        % Returns a list containing the items not fully charged yet
        fun {ItemsToCharge PossibleItems}
            case PossibleItems
                of PossibleItem|Others then
                    if Charges.PossibleItem < Input.PossibleItem then
                        PossibleItem|{ItemsToCharge Others}
                    else
                        {ItemsToCharge Others}
                    end
                [] nil then
                    nil
            end
        end

        % Returns true if all items are already charged, false otherwise
        fun {IsAllItemsAlreadyCharged}
            Charges.mine >= Input.mine andthen Charges.missile >= Input.missile andthen Charges.drone >= Input.drone andthen Charges.sonar >= Input.sonar
        end

        % Finds an item to charge
        % The chosen item depends on the information available:
        %       -> At least one coordinate is unknown (both x and y for each opponent) then the charge goes to the sonar
        %       -> At least one position is uncertain (both x or y are uncertain) then the charge goes to the drone
        %       -> At least one coordinate is uncertain (either x or y is uncertain) then the charge randomly goes to the sonar or the drone
        % If the chosen item is already charged then the next one in the list above is chosen instead
        fun {FindItemToCharge UnchargedItems}
            NumberAtLeastOneUnknownPosition
            NumberBothUncertainPositions % e.g. after a sonar detection alone
            NumberAtLeastOneUncertainPositions % e.g. sonar detection followed by a drone detection
            ClosestOpponent
        in
            NumberAtLeastOneUnknownPosition = {List.length {FilterOpponentsPosition OpponentsIntel PredicateAtLeastUnknown}}
            NumberBothUncertainPositions = {List.length {FilterOpponentsPosition OpponentsIntel PredicateBothUncertain}}
            NumberAtLeastOneUncertainPositions = {List.length {FilterOpponentsPosition OpponentsIntel PredicateAtLeastOneUncertain}}

            if {List.length OpponentsIntel} == 0 then
                if {List.member sonar UnchargedItems} then
                    sonar
                elseif {List.member drone UnchargedItems} then
                    drone
                else
                    null
                end
            elseif {List.member sonar UnchargedItems} andthen NumberAtLeastOneUnknownPosition > 0 then % at least one position with at least one unknown coordinate
                sonar
            elseif {List.member drone UnchargedItems} andthen NumberBothUncertainPositions > 0 then % at least one position with two uncertain coordinates
                drone
            elseif ({List.member sonar UnchargedItems} orelse {List.member drone UnchargedItems}) andthen NumberAtLeastOneUncertainPositions > 0 then % at least one position has only one uncertain uncertain coordinates
                if {Not {List.member sonar UnchargedItems}} then
                    drone
                elseif {Not {List.member drone UnchargedItems}} then
                    sonar
                else
                    if {UtilRandomInt 1 3} == 1 then
                        drone
                    else
                        sonar
                    end
                end
            elseif {List.member missile UnchargedItems} andthen {List.member mine UnchargedItems} then % at this point, all positions are known
                if {UtilRandomInt 1 4} == 1 then % either charge a missile or a mine (but prefer to charge a missile)
                    mine
                else
                    missile
                end
            elseif {List.member mine UnchargedItems} then
                mine
            elseif {List.member missile UnchargedItems} then
                missile
            else
                null
            end
        end
    in
        if {IsAllItemsAlreadyCharged} then
            CreatedItem = null
            UpdatedCharges = Charges
        else UnchargedItems ItemToCharge UpdatedCharge in
            UnchargedItems = {ItemsToCharge PreferencesOrder}
            ItemToCharge = {FindItemToCharge UnchargedItems}
            UpdatedCharge = Charges.ItemToCharge + 1
            if (UpdatedCharge) >= Input.ItemToCharge then % item fully charged
                CreatedItem = ItemToCharge
            else % item not fully charged
                CreatedItem = null
            end
            {MapRecord Charges UpdatedCharges fun {$ ItemLabel Charge} if ItemLabel == ItemToCharge then UpdatedCharge else Charge end end} % Updates charges
        end
    end

    % Returns true if the explosion would hurt the missile sender
    fun {AmIGoingToBeHurt MyPosition ExplosionLocation}
        {ManhattanDistance MyPosition ExplosionLocation} < 2
    end

    % Binds KindFire to a fully charged item and sets its charge to 0 in UpdatedCharges
    % Binds KindFire to null and UpdatedCharges to Charges if there is no charged item
    % This function assumes that items are charged in a smart way, which means if one is charged then it should be fired as soon as possible
    % If several items are charged, then the preferred order is as follows: mine missile drone sonar
    % If a missile can't reach any target, then a mine is placed, if possible
    proc {FireItem Charges MyPosition VisitedPositions OpponentsIntel ?KindFire ?UpdatedCharges}
        PreferredItemsOrder = [mine missile drone sonar]

        % Gets a list of all loaded weapon
        fun {GetAllValidItems Items}
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

        % Retrieves the Nth items of ChargedItems
        fun {GetItem ChargedItems N}
            if N == 1 then
                ChargedItems.1
            else
                {GetItem ChargedItems.2 N-1}
            end
        end

        % Returns a mine placed on a previous visited square
        % If not possible, choose random bound position
        fun {MineEmplacement}
            ClosestOpponent
            % Finds the valid position with the minimal distance
            fun {MinDist Positions}
                case Positions
                    of Position|Others then
                        if {ManhattanDistance Position MyPosition} == Input.minDistanceMine then
                            Position
                        else
                            {MinDist Others}
                        end
                    [] nil then
                        null
                end
            end
        in
            ClosestOpponent = {FindClosestOpponents MyPosition OpponentsIntel}
            if ClosestOpponent == null then
                null
            else MinPosition in
                MinPosition = {MinDist VisitedPositions}
                if MinPosition == null then % choose a random one
                    mine({GetRandomBoundPosition MyPosition Input.minDistanceMine Input.maxDistanceMine})
                else
                    mine(MinPosition)
                end
            end
        end

        % Returns a missile that aims at the closest reacheable opponent
        % Returns null if no reacheable opponent is found
        fun {MissileEmplacement}
            % Returns true if the missile can reach the given location
            fun {IsReacheable Location}
                {ManhattanDistance MyPosition Location} >= Input.minDistanceMissile andthen {ManhattanDistance MyPosition Location} =< Input.maxDistanceMissile
            end

            ClosestOpponent
        in
            ClosestOpponent = {FindClosestOpponents MyPosition OpponentsIntel}
            if ClosestOpponent == null then
                null
            elseif {IsReacheable ClosestOpponent.pt} andthen {Not {AmIGoingToBeHurt MyPosition ClosestOpponent.pt}} then
                missile(ClosestOpponent.pt)
            else % out of reach opponent
                null
            end
        end

        % The drone is used to validate uncertain coordinates
        fun {DroneEmplacement}
            OpponentsBothCoordinatesUncertain
        in
            OpponentsBothCoordinatesUncertain = {FilterOpponentsPosition OpponentsIntel PredicateBothUncertain}
            if {List.length OpponentsBothCoordinatesUncertain} == 0 then % no position (both coordinates) to validate
                null
            else
                drone(row {Number.abs OpponentsBothCoordinatesUncertain.1.pt.x}) % validate x coordinate by default
            end
        end

        ChargedItemsSortedByPreferences
        NumberChargedItems
        FavItem
        ChosenItem
    in
        ChargedItemsSortedByPreferences = {GetAllValidItems PreferredItemsOrder}
        NumberChargedItems = {List.length ChargedItemsSortedByPreferences}

        if NumberChargedItems == 0 then
            UpdatedCharges = Charges
            KindFire = null
        else
            FavItem = ChargedItemsSortedByPreferences.1 % choose the first item
            case FavItem
                of missile then PossibleKindFire in
                    PossibleKindFire = {MissileEmplacement}
                    if PossibleKindFire == null andthen {List.member mine ChargedItemsSortedByPreferences} then
                        KindFire = {MineEmplacement}
                        ChosenItem = mine
                    elseif PossibleKindFire \= null then
                        KindFire = PossibleKindFire
                        ChosenItem = missile
                    else
                        KindFire = null
                    end
                [] mine then
                    KindFire = {MineEmplacement}
                    ChosenItem = mine
                [] drone then PossibleKindFire in
                    PossibleKindFire = {DroneEmplacement}
                    if PossibleKindFire == null andthen {List.member sonar ChargedItemsSortedByPreferences} then
                        KindFire = sonar
                        ChosenItem = sonar
                    elseif PossibleKindFire \= null then
                        KindFire = PossibleKindFire
                        ChosenItem = drone
                    else
                        KindFire = null
                    end
                [] sonar then
                    KindFire = sonar
                    ChosenItem = sonar
                else
                    KindFire = null
            end
            % Sets the chosen item charges to 0
            if KindFire \= null then
                {MapRecord Charges UpdatedCharges fun {$ ItemLabel Charge} if ItemLabel == ChosenItem then 0 else Charge end end}
            else
                UpdatedCharges = Charges
            end
        end
    end

    % Returns the mine to be fired
    % The function returns null if:
    %       -> There is no placed mine available
    %       -> It is unsure that the mine would touch a opponent
    %       -> The mine explosion would damage our ship aswell
    fun {FireMine PlacedMines MyPosition OpponentsIntel}
        % Returns a mine position that matches an opponent position and won't damage our ship aswell
        fun {FindValidPosition Opponents}
            case Opponents
                of Opponent|Others then
                    if {List.member Opponent.pt PlacedMines} andthen {Not {AmIGoingToBeHurt MyPosition Opponent.pt}} then
                        Opponent.pt
                    else
                        {FindValidPosition Others}
                    end
                [] nil then
                    null
            end
        end

        RandomMine
        Length
    in
        Length = {List.length PlacedMines}
        if Length == 0 then % no mine available
            null
        else
            {FindValidPosition OpponentsIntel}
        end
    end

    % Handle an explosion, returns null if out of range.
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

    % Returns the pponent with the ID "IDToFind"
    % Returns null if the opponnent in not found
    fun {FindOpponentWithID IDToFind OpponentsIntel}
        case OpponentsIntel
            of opponent(id:ID pt:pt(x:X y:Y))|Others then
                if ID.id == IDToFind.id then
                    opponent(id:ID pt:pt(x:X y:Y))
                else
                    {FindOpponentWithID IDToFind Others}
                end
            [] nil then
                null
        end
    end

    % Returns an updated version of OpponentsIntel
    fun {InsertIfNotExist ID OpponentsIntel DeadOpponents}
       if {FindOpponentWithID ID OpponentsIntel} == null andthen {FindOpponentWithID ID DeadOpponents} == null then
            opponent(id:ID pt:pt(x:unknown y:unknown))|OpponentsIntel
        else
            OpponentsIntel
        end
    end

    % Returns an updated version of OpponentsIntel without the opponent with the matching ID
    proc {RemoveIfExist IDToRemove OpponentsIntel ?UpdatedOpponentsIntel ?OpponentRemoved}
        % Returns a list without the opponent ID
        proc {RemoveIfExistLoop Opponents ?NewUpdatedOpponentsIntel ?NewOpponentRemoved}
            case Opponents
                of opponent(id:ID pt:pt(x:X y:Y))|Others then
                    if ID.id == IDToRemove.id then
                        NewOpponentRemoved = opponent(id:ID pt:pt(x:X y:Y))
                        NewUpdatedOpponentsIntel = Others
                    else Tail in
                        NewUpdatedOpponentsIntel = opponent(id:ID pt:pt(x:X y:Y))|Tail
                        {RemoveIfExistLoop Others Tail NewOpponentRemoved}
                    end
                [] nil then
                    NewUpdatedOpponentsIntel = nil
                    NewOpponentRemoved = null
            end
        end
    in
        {RemoveIfExistLoop OpponentsIntel UpdatedOpponentsIntel OpponentRemoved}
    end

    % Replaces OpponentToUpdate with UpdatedOpponent in OpponentsIntel and returns the resulting list
    fun {UpdateOpponentsIntel OpponentToUpdate UpdatedOpponent OpponentsIntel}
        case OpponentsIntel
            of opponent(id:ID pt:pt(x:X y:Y))|Others then
                if ID.id == OpponentToUpdate.id.id then
                    UpdatedOpponent|Others
                else
                    opponent(id:ID pt:pt(x:X y:Y))|{UpdateOpponentsIntel OpponentToUpdate UpdatedOpponent Others}
                end
            [] nil then
                nil
        end
    end

    % Returns an update version of OpponentsIntel accordingly to the direction broadcasted by the opponent ID
    % east  -> y + 1
    % north -> x - 1
    % south -> x + 1
    % west  -> y - 1
    fun {SayMoveUpdateIntel ID Direction OpponentsIntel DeadOpponents}
        fun {UpdatedOpponentDirection}
            UpdatedX
            UpdatedY
        in
            case Direction
                of east andthen OpponentToUpdate.pt.y \= unknown then
                    UpdatedX = OpponentToUpdate.pt.x
                    if OpponentToUpdate.pt.y > 0 then
                        UpdatedY = OpponentToUpdate.pt.y + 1
                    else
                        UpdatedY = OpponentToUpdate.pt.y - 1
                    end
                [] west andthen OpponentToUpdate.pt.y \= unknown then
                    UpdatedX = OpponentToUpdate.pt.x
                    if OpponentToUpdate.pt.y > 0 then
                        UpdatedY = OpponentToUpdate.pt.y - 1
                    else
                        UpdatedY = OpponentToUpdate.pt.y + 1
                    end
                [] south andthen OpponentToUpdate.pt.x \= unknown then
                    UpdatedY = OpponentToUpdate.pt.y
                    if OpponentToUpdate.pt.x > 0 then
                        UpdatedX = OpponentToUpdate.pt.x + 1
                    else
                        UpdatedX = OpponentToUpdate.pt.x - 1
                    end
                [] north andthen OpponentToUpdate.pt.x \= unknown then
                    UpdatedY = OpponentToUpdate.pt.y
                    if OpponentToUpdate.pt.x > 0 then
                        UpdatedX = OpponentToUpdate.pt.x - 1
                    else
                        UpdatedX = OpponentToUpdate.pt.x + 1
                    end
                else
                    UpdatedX = OpponentToUpdate.pt.x
                    UpdatedY = OpponentToUpdate.pt.y
            end

            if UpdatedY \= unknown andthen ({Number.abs UpdatedY} > Input.nColumn orelse UpdatedY == 0) then % out of range -> invalid Y
                if UpdatedX \= unknown then
                    opponent(id:ID pt:pt(x:{Number.abs UpdatedX} y:unknown))
                else
                    opponent(id:ID pt:pt(x:unknown y:unknown))
                end
            elseif UpdatedX \= unknown andthen ({Number.abs UpdatedX} > Input.nRow orelse UpdatedX == 0) then % out of range -> invalid X
                if UpdatedY \= unknown then
                    opponent(id:ID pt:pt(x:unknown y:{Number.abs UpdatedY}))
                else
                    opponent(id:ID pt:pt(x:unknown y:unknown))
                end
            else
                opponent(id:ID pt:pt(x:UpdatedX y:UpdatedY))
            end
        end

        OpponentToUpdate
    in
        OpponentToUpdate = {FindOpponentWithID ID OpponentsIntel}
        if {FindOpponentWithID ID DeadOpponents} \= null then
            OpponentsIntel
        elseif OpponentToUpdate == null then % doesn't exist
            opponent(id:ID pt:pt(x:unknown y:unknown))|OpponentsIntel
        else UpdatedOpponent in
            UpdatedOpponent = {UpdatedOpponentDirection}
            if UpdatedOpponent == null then
                OpponentsIntel
            else UpdatedOpponentsIntel in
                {UpdateOpponentsIntel OpponentToUpdate UpdatedOpponent OpponentsIntel}
            end
        end
    end

    % Returns true if same row than the drone (or column if it is a "column" drone), returns false otherwise
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

    % Returns our position with one missleading coordinate
    % The strategy followed is to give one of our coordinate and one certain X or Y of an opponent
    fun {GenerateSonarOutput Position OpponentsIntel}
        % Binds XorY to a (un)certain x or y and RowOrCol to row (if x) or col (if y)
        % Binds null if no (un)certain x or y is found
        proc {FindCertainXorY Opponents ?XorY ?RowOrCol}
            case Opponents
                of Opponent|Others then
                    if Opponent.pt.x \= unknown then
                        XorY = {Number.abs Opponent.pt.x}
                        RowOrCol = row
                    elseif Opponent.pt.y \= unknown then
                        XorY = {Number.abs Opponent.pt.y}
                        RowOrCol = column
                    else
                        {FindCertainXorY Others XorY RowOrCol}
                    end
                [] nil then
                    XorY = null
                    RowOrCol = null
            end
        end

        XorY
        RowOrCol
    in
        {FindCertainXorY OpponentsIntel XorY RowOrCol}
        if {UtilRandomInt 1 3} == 1 orelse XorY == null then Row Col in % no certain coordinate is found, give a random one
            if ({UtilRandomInt 1 2} == 1) then
                Row = Position.x
                Col = ((Position.y + (Input.nColumn div 2)) mod Input.nColumn) + 1
            else
                Row = ((Position.x + (Input.nRow div 2)) mod Input.nRow) + 1
                Col = Position.y
            end
            pt(x:Row y:Col)
        else % certain coordinate is found
            if RowOrCol == row then % x coordinate found
                pt(x:XorY y:Position.y)
            else
                pt(x:Position.x y:XorY)
            end
        end
    end

    % Returns an updated OpponentsIntel if the submarine ID is detected by a drone
    % Its row or column is confirmed when detected
    fun {SayDroneUpdateIntel Drone ID IsDetected OpponentsIntel DeadOpponents}
        UpdatedOpponentsIntel = {InsertIfNotExist ID OpponentsIntel DeadOpponents}
        OpponentToUpdate = {FindOpponentWithID ID OpponentsIntel}
        UpdatedX
        UpdatedY
        UpdatedOpponent = opponent(id:ID pt:pt(x:UpdatedX y:UpdatedY))
    in
        if OpponentToUpdate \= null andthen IsDetected then
            case Drone
                of drone(row X) then
                    UpdatedX = X
                    UpdatedY = OpponentToUpdate.pt.y
                [] drone(column Y) then
                    UpdatedX = OpponentToUpdate.pt.x
                    UpdatedY = Y
                else
                    UpdatedX = OpponentToUpdate.pt.x
                    UpdatedY = OpponentToUpdate.pt.y
            end
            {UpdateOpponentsIntel OpponentToUpdate UpdatedOpponent OpponentsIntel} % returns the updated OpponentsIntel
        elseif OpponentToUpdate \= null then % unvalidate uncertain coordinates that have not been detected
            case Drone
                of drone(row X) then
                    if OpponentToUpdate.pt.x \= unknown andthen X == {Number.abs OpponentToUpdate.pt.x} then
                        UpdatedX = unknown
                    else
                        UpdatedX = OpponentToUpdate.pt.x
                    end
                    UpdatedY = OpponentToUpdate.pt.y
                [] drone(column Y) then
                    if OpponentToUpdate.pt.y \= unknown andthen Y == {Number.abs OpponentToUpdate.pt.y} then
                        UpdatedY = unknown
                    else
                        UpdatedY = OpponentToUpdate.pt.y
                    end
                    UpdatedX = OpponentToUpdate.pt.x
                else
                    UpdatedX = OpponentToUpdate.pt.x
                    UpdatedY = OpponentToUpdate.pt.y
            end
            {UpdateOpponentsIntel OpponentToUpdate UpdatedOpponent OpponentsIntel} % returns the updated OpponentsIntel
        else
            OpponentsIntel
        end
    end

    % Returns an updated OpponentsIntel
    % Unknown positions are know uncertain
    fun {SaySonarUpdateIntel ID Answer OpponentsIntel DeadOpponents}
        fun {UpdatePosition OpponentPosition}
            if {PredicateBothCertain OpponentPosition.x OpponentPosition.y} then % pt(x:>0 y:>0)
                OpponentPosition
            elseif {PredicateBothUnknown OpponentPosition.x OpponentPosition.y} then % pt(x:unknown y:unknown)
                pt(x:~Answer.x y:~Answer.y)
            elseif {PredicateAtLeastUnknown OpponentPosition.x OpponentPosition.y} andthen OpponentPosition.x == unknown then % pt(x:unknown y:"number")
                pt(x:~Answer.x y:OpponentPosition.y)
            elseif {PredicateAtLeastUnknown OpponentPosition.x OpponentPosition.y} andthen OpponentPosition.y == unknown then % pt(x:"number" y:unknown)
                pt(x:OpponentPosition.x y:~Answer.y)
            elseif {PredicateBothUncertain OpponentPosition.x OpponentPosition.y} then % pt(x:<0 y:<0)
                pt(x:~Answer.x y:~Answer.y)
            elseif OpponentPosition.x < 0 then % pt(x:"uncertain" y:"certain")
                if Answer.y \= OpponentPosition.y then % y is the false one
                    pt(x:Answer.x y:OpponentPosition.y) % thus x can be confirmed
                else
                    pt(x:~Answer.x y:OpponentPosition.y)
                end
            elseif OpponentPosition.y < 0 then % pt(x:"certain" y:"uncertain")
                if Answer.x \= OpponentPosition.x then % x is the false one
                    pt(x:OpponentPosition.x y:Answer.y) % thus y can be confirmed
                else
                    pt(x:OpponentPosition.x y:~Answer.y)
                end
            else % pt(x:"number" y:"number")
                OpponentPosition
            end
        end

        UpdatedOpponentsIntel = {InsertIfNotExist ID OpponentsIntel DeadOpponents}
        OpponentToUpdate = {FindOpponentWithID ID OpponentsIntel}
        UpdatedPt
    in
        if OpponentToUpdate \= null then
            UpdatedPt = {UpdatePosition OpponentToUpdate.pt}
            {UpdateOpponentsIntel OpponentToUpdate opponent(id:ID pt:UpdatedPt) OpponentsIntel} % returns the updated OpponentsIntel
        else
            OpponentsIntel
        end
    end

    % Charges = charges(mine:<int> missile:<int> drone:<int> sonar:<int>)
    proc {TreatStream Stream MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
		case Stream
            of nil then skip
            [] initPosition(?ID ?Position)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][initPosition]')}
                ID = MyID
                Position = {GetInitPosition}
                {TreatStream T MyID Position|nil MyDirection true Charges PlacedMines Life OpponentsIntel DeadOpponents}
            [] move(?ID ?Position ?Direction)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][move]')}
                if Life =< 0 then
                    ID = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else
                    ID = MyID
                    {Move VisitedPositions.1 VisitedPositions CanDive OpponentsIntel Charges Position Direction}
                    if Direction == surface then
                        {TreatStream T MyID Position|nil Direction false Charges PlacedMines Life OpponentsIntel DeadOpponents}
                    else
                        {TreatStream T MyID Position|VisitedPositions Direction CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                    end
                end
            [] dive|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][dive]')}
                {TreatStream T MyID VisitedPositions MyDirection true Charges PlacedMines Life OpponentsIntel DeadOpponents}
            [] chargeItem(?ID ?KindItem)|T then UpdatedCharges in % OK
                % {System.show treat_stream('[Player ('#MyID#')][chargeItem]')}
                if Life =< 0 then
                    ID = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else
                    ID = MyID
                    {ChargeItem Charges VisitedPositions.1 OpponentsIntel KindItem UpdatedCharges}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive UpdatedCharges PlacedMines Life OpponentsIntel DeadOpponents}
                end
            [] fireItem(?ID ?KindFire)|T then UpdatedCharges in % OK
                % {System.show treat_stream('[Player ('#MyID#')][fireItem]')}
                if Life =< 0 then
                    ID = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else
                    ID = MyID
                    {FireItem Charges VisitedPositions.1 VisitedPositions OpponentsIntel KindFire UpdatedCharges}
                    case KindFire
                        of mine(Position) then
                            {TreatStream T MyID VisitedPositions MyDirection CanDive UpdatedCharges Position|PlacedMines Life OpponentsIntel DeadOpponents}
                        else
                            {TreatStream T MyID VisitedPositions MyDirection CanDive UpdatedCharges PlacedMines Life OpponentsIntel DeadOpponents}
                    end
                end
            [] fireMine(?ID ?Mine)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][fireMine]')}
                if Life =< 0 then
                    ID = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else
                    ID = MyID
                    Mine = {FireMine PlacedMines VisitedPositions.1 OpponentsIntel}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges {List.subtract PlacedMines Mine} Life OpponentsIntel DeadOpponents}
                end
            [] isDead(?Answer)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][isDead]')}
                if Life =< 0 then
                    Answer = true
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else
                    Answer = false
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                end
            [] sayMove(ID Direction)|T then UpdatedOpponentsIntel in % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayMove]')}
                if ID == null orelse Life =< 0 orelse ID.id == MyID.id then
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else UpdatedOpponentsIntel in
                    UpdatedOpponentsIntel = {SayMoveUpdateIntel ID Direction OpponentsIntel DeadOpponents}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life UpdatedOpponentsIntel DeadOpponents}
                end
            [] saySurface(ID)|T then UpdatedOpponentsIntel in % OK
                % {System.show treat_stream('[Player ('#MyID#')][saySurface]')}
                if ID == null orelse Life =< 0 orelse ID.id == MyID.id then
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else UpdatedOpponentsIntel in
                    UpdatedOpponentsIntel = {InsertIfNotExist ID OpponentsIntel DeadOpponents}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life UpdatedOpponentsIntel DeadOpponents}
                end
            [] sayCharge(ID KindItem)|T then UpdatedOpponentsIntel in % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayCharge]')}
                if ID == null orelse Life =< 0 orelse ID.id == MyID.id then
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else UpdatedOpponentsIntel in
                    UpdatedOpponentsIntel = {InsertIfNotExist ID OpponentsIntel DeadOpponents}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life UpdatedOpponentsIntel DeadOpponents}
                end
            [] sayMinePlaced(ID)|T then UpdatedOpponentsIntel in % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayMinePlaced]')}
                if ID == null orelse Life =< 0 orelse ID.id == MyID.id then
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else UpdatedOpponentsIntel in
                    UpdatedOpponentsIntel = {InsertIfNotExist ID OpponentsIntel DeadOpponents}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life UpdatedOpponentsIntel DeadOpponents}
                end
            [] sayMissileExplode(ID Position ?Message)|T then UpdatedOpponentsIntel in % OK
                % {System.show treat_stream('[Player ('#MyID#') ][sayMissileExplode]' ID Position ?Message)}
                if Life =< 0 then
                    Message = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else
                    if ID == null orelse ID.id == MyID.id then
                        UpdatedOpponentsIntel = OpponentsIntel
                    else
                        UpdatedOpponentsIntel = {InsertIfNotExist ID OpponentsIntel DeadOpponents}
                    end
                    Message = {HandleExplosion Position MyID VisitedPositions.1 Life}
                    case Message
                        of sayDeath(MyID) then
                            {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines 0 UpdatedOpponentsIntel DeadOpponents}
                        [] sayDamageTaken(MyID Damage LifeLeft) then
                            {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines LifeLeft UpdatedOpponentsIntel DeadOpponents}
                        else
                            {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life UpdatedOpponentsIntel DeadOpponents}
                    end
                end
            [] sayMineExplode(ID Position ?Message)|T then UpdatedOpponentsIntel in % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayMineExplode]')}
                if Life =< 0 then
                    Message = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life UpdatedOpponentsIntel DeadOpponents}
                else
                    if ID == null orelse ID.id == MyID.id then
                        UpdatedOpponentsIntel = OpponentsIntel
                    else
                        UpdatedOpponentsIntel = {InsertIfNotExist ID OpponentsIntel DeadOpponents}
                    end
                    Message = {HandleExplosion Position MyID VisitedPositions.1 Life}
                    case Message
                        of sayDeath(MyID) then
                            {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines 0 UpdatedOpponentsIntel DeadOpponents}
                        [] sayDamageTaken(MyID Damage LifeLeft) then
                            {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines LifeLeft UpdatedOpponentsIntel DeadOpponents}
                        else % null
                            {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life UpdatedOpponentsIntel DeadOpponents}
                    end
                end
            [] sayPassingDrone(Drone ?ID ?Answer)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')[sayPassingDrone]' ID MyID)}
                if Life =< 0 then
                    ID = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else
                    ID = MyID
                    Answer = {IsDetectedByDrone Drone VisitedPositions.1}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                end
            [] sayAnswerDrone(Drone ID Answer)|T then  % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayAnswerDrone]')}
                if ID == null orelse Life =< 0 orelse ID.id == MyID.id then
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else UpdatedOpponentsIntel in
                    UpdatedOpponentsIntel = {SayDroneUpdateIntel Drone ID Answer OpponentsIntel DeadOpponents}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life UpdatedOpponentsIntel DeadOpponents}
                end
            [] sayPassingSonar(?ID ?Answer)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayPassingSonar]')}
                if Life =< 0 then
                    ID = null
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else
                    ID = MyID
                    Answer = {GenerateSonarOutput VisitedPositions.1 OpponentsIntel}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                end
            [] sayAnswerSonar(ID Answer)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayAnswerSonar]')}
                if Life =< 0 orelse ID.id == MyID.id then
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else UpdatedOpponentsIntel in
                    UpdatedOpponentsIntel = {SaySonarUpdateIntel ID Answer OpponentsIntel DeadOpponents}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life UpdatedOpponentsIntel DeadOpponents}
                end
            [] sayDeath(ID)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayDeath]')} % OK
                if Life =< 0 orelse ID.id == MyID.id then
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else UpdatedOpponentsIntel OpponentRemoved in
                    {RemoveIfExist ID OpponentsIntel UpdatedOpponentsIntel OpponentRemoved}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life UpdatedOpponentsIntel OpponentRemoved|DeadOpponents}
                end
            [] sayDamageTaken(ID Damage LifeLeft)|T then % OK
                % {System.show treat_stream('[Player ('#MyID#')][sayDamageTaken]')}
                if Life =< 0 orelse ID.id == MyID.id then
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
                else UpdatedOpponentsIntel in
                    UpdatedOpponentsIntel = {InsertIfNotExist ID OpponentsIntel DeadOpponents}
                    {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life UpdatedOpponentsIntel DeadOpponents}
                end
            [] _|T then % OK
                {TreatStream T MyID VisitedPositions MyDirection CanDive Charges PlacedMines Life OpponentsIntel DeadOpponents}
        end
    end
end
