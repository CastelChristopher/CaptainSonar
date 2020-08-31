functor
import
    OS
    System
    Input
    GUI
    PlayerManager
define
    % functions (utils)
    UtilRandomInt
    Think
    % functions
    InitPlayers
    InitPosPlayers
    BroadcastMessage
    BroadcastExplosion
    BroadcastDrone
    BroadcastSonar
    FireItem
    ChargeItem
    FireMine
    CheckWinner
    PlayersLoopTurn
    SimultaneousPlayerLoop
    GameLoopTurns
    GameLoopSimultaneous
    % variables
    GUIPort = {GUI.portWindow}
    PlayerTuples % player(port:<Port> id:<id> surface_rnds:<Int> position:<position> direction:<direction>)
    Winner
in
    % functions (utils)
    % --------------------

    fun {UtilRandomInt Min Max}
        ({OS.rand} mod (Max - Min + 1)) + Min
    end

    proc {Think}
        {Delay {UtilRandomInt Input.thinkMin Input.thinkMax}}
    end

    % functions
    % --------------------

    fun {InitPlayers Players Colors IdNum}
        if IdNum > Input.nbPlayer then
            nil
        else
            case Players|Colors
                of (Kind|T1)|(Color|T2) then
                    {PlayerManager.playerGenerator Kind Color IdNum}|{InitPlayers T1 T2 (IdNum + 1)}
                [] nil|nil then nil
            end
        end
    end

    proc {InitPosPlayers Players ?PlayerTuples}
        % {System.show '[Main] {InitPosPlayers Players ?PlayerTuples}'}
        case Players
            of PlayerPort|OtherPorts then ID Pos NewPlayer OtherPlayers in
                {Send PlayerPort initPosition(ID Pos)}
                {Send GUIPort initPlayer(ID Pos)}
                NewPlayer = player(port:PlayerPort id:ID surface_rnds:0 position:Pos direction:surface)
                PlayerTuples = NewPlayer|OtherPlayers
                {InitPosPlayers OtherPorts OtherPlayers}
            [] nil then
                PlayerTuples = nil
        end
    end

    % checks if 1 submarine alive
    fun {CheckWinner PlayerTuples DeadPlayers Winner}
        % {System.show '[Main] {CheckWinner PlayerTuples DeadPlayers Winner}'}
        case PlayerTuples
            of Player|OtherPlayers then IsDead in
                {Send Player.port isDead(IsDead)}
                if IsDead then
                    {CheckWinner OtherPlayers (DeadPlayers + 1) Winner}
                else
                    {CheckWinner OtherPlayers DeadPlayers Player.id.name}
                end
            [] nil then
                if DeadPlayers == (Input.nbPlayer - 1) then
                    Winner
                elseif DeadPlayers == Input.nbPlayer then
                    'All submarines are dead'
                else
                    null
                end
        end
    end

    proc {BroadcastMessage Message}
        for Player in PlayerTuples do
            {Send Player.port Message}
        end
    end

    % toBroadcast ::= messageType(ID Position Message)
    proc {BroadcastExplosion PlayerTuples ToBroadcast}
        % {System.show '[Main] {BroadcastExplosion PlayerTuples '#ToBroadcast#'}'}
        case PlayerTuples
            of Player|OtherPlayers then Answer in
                case ToBroadcast
                    of sayMineExplode(ID Position ?Message) then
                        {Send Player.port sayMineExplode(ID Position Answer)}
                    [] sayMissileExplode(ID Position ?Message) then
                        {Send Player.port sayMissileExplode(ID Position Answer)}
                    else {System.show '[Main] broadcast explosion invalid message'}
                end
                if Answer \= null then
                    {BroadcastMessage Answer}
                    case Answer
                        of sayDamageTaken(Id Damage LifeLeft) then
                            {Send GUIPort lifeUpdate(Id LifeLeft)}
                        [] sayDeath(Id) then
                            {Send GUIPort lifeUpdate(Id 0)}
                            {Send GUIPort removePlayer(Id)}
                        else {System.show '[Main] undefined MessageExplosion'} % bugs checker
                    end
                end
                {BroadcastExplosion OtherPlayers ToBroadcast}
            [] nil then skip
        end
    end

    % message ::= messageType(Drone ID Answer)
    proc {BroadcastDrone PlayerTuples Message}
        PlayerID
        PlayerAnswer
    in
        % {System.show '[Main] {BroadcastDrone PlayerTuples '#Message#'}'}
        case PlayerTuples
            of Player|OtherPlayers then
                case Message
                    of sayPassingDrone(KindFire ?AnswerID ?Answer) then
                        {Send Player.port sayPassingDrone(KindFire ?PlayerID ?PlayerAnswer)}
                    else {System.show '[Main] broadcast drone invalid message'}
                end
                if PlayerID \= null then
                    {BroadcastMessage sayAnswerDrone(Message.1 PlayerID PlayerAnswer)}
                end
                {BroadcastDrone OtherPlayers Message}
            [] nil then
                skip
        end
    end

    % message ::= messageType(ID Answer)
    proc {BroadcastSonar PlayerTuples Message}
        PlayerID
        PlayerAnswer
    in
        % {System.show '[Main] {BroadcastSonar PlayerTuples '#Message#'}'}
        case PlayerTuples
            of Player|OtherPlayers then
                case Message
                    of sayPassingSonar(?ID ?Answer) then
                        {Send Player.port sayPassingSonar(?PlayerID ?PlayerAnswer)}
                    else {System.show '[Main] broadcast sonar invalid message'}
                end
                if PlayerID \= null then
                    {BroadcastMessage sayAnswerSonar(PlayerID PlayerAnswer)}
                end
                {BroadcastSonar OtherPlayers Message}
            [] nil then skip
        end
    end

    proc {FireItem Player}
        ID
        KindFire
    in
        % {System.show '[Main] {FireItem ID Player}'}
        {Send Player.port fireItem(ID KindFire)}
        if ID \= null then
            Message
            Answer
            AnswerID
        in
            case KindFire
                of mine(PositionMine) then
                    {BroadcastMessage sayMinePlaced(ID)}
                    {Send GUIPort putMine(ID PositionMine)}
                [] missile(PositionMissile) then
                    {Send GUIPort explosion(ID PositionMissile)}
                    {BroadcastExplosion PlayerTuples sayMissileExplode(ID PositionMissile ?Message)}
                [] drone(row Row) then
                    {BroadcastDrone PlayerTuples sayPassingDrone(KindFire ?AnswerID ?Answer)}
                    {Send GUIPort drone(ID drone(row Row))}
                [] drone(column Col) then
                    {BroadcastDrone PlayerTuples sayPassingDrone(KindFire ?AnswerID ?Answer)}
                    {Send GUIPort drone(ID drone(row Col))}
                [] sonar then
                    {BroadcastSonar PlayerTuples sayPassingSonar(?AnswerID ?Answer)}
                    {Send GUIPort sonar(ID)}
                [] null then
                    skip
                else {System.show '[Main] undefined KindFire'}
            end
        end
    end

    proc {ChargeItem Player}
        ID
        KindItem
    in
        % {System.show '[Main] {ChargeItem ID Player}'}
        {Send Player.port chargeItem(ID KindItem)}
        if ID \= null then
            if KindItem \= null then
                {BroadcastMessage sayCharge(ID KindItem)}
            end
        end
    end

    proc {FireMine Player}
        ID
        PositionMine
    in
        % {System.show '[Main] {FireMine ID Player}'}
        {Send Player.port fireMine(?ID ?PositionMine)}
        if ID \= null then
            if PositionMine \= null then Message in
                {Send GUIPort explosion(ID PositionMine)}
                {Send GUIPort removeMine(ID PositionMine)}
                {BroadcastExplosion PlayerTuples sayMineExplode(ID PositionMine ?Message)}
            end
        end
    end

    fun {PlayersLoopTurn Players CurrentRound}
        case Players
            of Player|OtherPlayers then IsDead in
                {Send Player.port isDead(IsDead)}
                if {Not IsDead} then
                    if (CurrentRound == 1) orelse (Player.surface_rnds >= Input.turnSurface) then  % point 2
                        ID Position Direction
                    in
                        {Send Player.port dive}
                        {Send Player.port move(ID Position Direction)} % point 3
                        if Direction == surface then
                            % point 4 Direction surface
                            {BroadcastMessage saySurface(ID)}
                            {Send GUIPort surface(ID)}
                            player(port:Player.port id:ID surface_rnds:1 position:Position direction:Direction)|{PlayersLoopTurn OtherPlayers CurrentRound} % next player
                        else
                            % point 5 MovePlayer Broadcast
                            {BroadcastMessage sayMove(ID Direction)}
                            if Direction == surface then {Send GUIPort surface(ID)} end
                            {Send GUIPort movePlayer(ID Position)}
                            {ChargeItem Player} % point 6
                            {FireItem Player}   % point 7
                            % suicide check
                            local IsDead in
                                {Send Player.port isDead(IsDead)}
                                if {Not IsDead} then
                                    {FireMine Player} % point 8
                                end
                            end
                            % point 9 next player
                            player(port:Player.port id:ID surface_rnds:Player.surface_rnds position:Position direction:Direction)|{PlayersLoopTurn OtherPlayers CurrentRound}
                        end
                    else % next player
                        player(port:Player.port id:Player.id surface_rnds:Player.surface_rnds+1 position:Player.position direction:surface)|{PlayersLoopTurn OtherPlayers CurrentRound}
                    end
                else
                    {PlayersLoopTurn OtherPlayers CurrentRound}
                end
            [] nil then nil
        end
    end

    proc {SimultaneousPlayerLoop GameLoopPort Player CurrentRound}
        IsRunning IsDead ID Position Direction
    in
        {Send GameLoopPort isRunning(IsRunning)}
        if IsRunning then
            % {System.show '[Main][SimultaneousPlayerLoop] player: '#Player.id.id#' Round: '#CurrentRound}
            {Send Player.port isDead(IsDead)}
            if {Not IsDead} then
                if (CurrentRound == 1) then
                    {Send Player.port dive} % point 1
                end
                {Think} % point 2
                {Send Player.port move(ID Position Direction)} % point 3
                if ID \= null then
                    if Direction == surface then
                        % point 4 Direction surface
                        {BroadcastMessage saySurface(ID)}
                        {Send GUIPort surface(ID)}
                        {Delay (Input.turnSurface * 1000)}
                        {Send Player.port dive} % point 1
                        {SimultaneousPlayerLoop GameLoopPort player(port:Player.port id:ID surface_rnds:~1 position:Position direction:Direction) (CurrentRound+1)}
                    else IsDead in
                        % point 5 MovePlayer Broadcast
                        {BroadcastMessage sayMove(ID Direction)}
                        if Direction == surface then {Send GUIPort surface(ID)} end
                        {Send GUIPort movePlayer(ID Position)}
                        {Think}             % point 6
                        {ChargeItem Player} % point 7
                        {Think}             % point 8
                        {FireItem Player}   % point 9
                        % suicide check (in case the player used a missile on themself..)
                        {Send Player.port isDead(IsDead)}
                        if {Not IsDead} then
                            {Think}
                            {FireMine Player} % point 9
                        end
                        % point 10
                        {SimultaneousPlayerLoop GameLoopPort player(port:Player.port id:ID surface_rnds:~1 position:Position direction:Direction) (CurrentRound+1)}
                    end
                else
                    {Send GameLoopPort dead(Player.id)}
                end
            else
                % {System.show '[Main][SimultaneousPlayerLoop] player: '#Player.id.name#' is DEAD'}
                {Send GameLoopPort dead(Player.id)}
            end
        end
    end

    fun {GameLoopTurns Players CurrentRound}
        TmpWinner
    in
        % {System.show '[Main] Round : '#CurrentRound}
        TmpWinner = {CheckWinner PlayerTuples 0 null}
        if TmpWinner == null then UpdatedPlayers in
            UpdatedPlayers = {PlayersLoopTurn Players CurrentRound}
            {GameLoopTurns UpdatedPlayers (CurrentRound + 1)}
        else
            TmpWinner
        end
    end

    fun {GameLoopSimultaneous Players}
        GameLoopStream
        GameLoopPort = {NewPort GameLoopStream}
        fun {Loop Stream AlivePlayers Winner}
            case Stream
                of isRunning(Answer)|T then
                    % {System.show isRunning}
                    if AlivePlayers =< 1 then
                        Answer = false
                        Winner
                    else
                        Answer = true
                        {Loop T AlivePlayers Winner}
                    end
                [] dead(PlayerID)|T then Winner in
                    if (AlivePlayers-1) =< 1 then
                        Winner = {CheckWinner PlayerTuples 0 null}
                    end
                    {Loop T (AlivePlayers-1) Winner}
                [] _|T then
                    {Loop T AlivePlayers Winner}
            end
        end
    in
        for Player in Players do
            thread
                {SimultaneousPlayerLoop GameLoopPort Player 1}
            end
        end
        {Loop GameLoopStream {List.length Players} _}
    end

    % Execution

    {Send GUIPort buildWindow}
    {InitPosPlayers {InitPlayers Input.players Input.colors 1} PlayerTuples}

    if Input.isTurnByTurn then
        Winner = {GameLoopTurns PlayerTuples 1}
    else
        Winner = {GameLoopSimultaneous PlayerTuples}
    end

    {System.show Winner}
end
