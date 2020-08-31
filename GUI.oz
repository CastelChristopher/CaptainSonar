functor
import
	System
	OS
	QTk at 'x-oz://system/wp/QTk.ozf'
	Input
export
	portWindow:StartWindow
define

%%%% Additional settings %%%%
	AudioPlayerPortObject
 	AudioPlayer % port
	PlaySound
	LoopSound
	PlayGameMusic
	KillAllSounds
	PlayEndGameSound
	PlayExplosionSound
	PlayDroneSound
	PlaySonarSound
	PlaySurfaceSound

	ColorConverter

% settings
	SoundEnabled = false
	SoundEffectsVolume = 50.0	% [0.0, 100.0]
	MusicVolume = 25.0			% [0.0, 100.0]
% assets configuration
	PathToAssets = "./assets"
	PathToSprites =   PathToAssets#"/sprites"
	PathToSounds =    PathToAssets#"/sounds"

% sprites
	PathToMineSprite =            PathToSprites#"/mine.gif"
	PathToExplosion1Sprite =      PathToSprites#"/explosion_1.gif"
	PathToExplosion2Sprite =      PathToSprites#"/explosion_2.gif"
	PathToExplosion3Sprite =      PathToSprites#"/explosion_3.gif"
	PathToExplosion4Sprite =      PathToSprites#"/explosion_4.gif"
	PathToIslandSprite =          PathToSprites#"/island.gif"
	PathToWaterSprite =           PathToSprites#"/water.gif"
	PathToSubmarineUnderSprite =  PathToSprites#"/submarine_under.gif"
	PathToSubmarineAboveSprite =  PathToSprites#"/submarine_above.gif"

% sounds
	PathToMainGameLoopMusic =  	PathToSounds#"/main_music_loop.mp3"
	PathToEndGameSound =		PathToSounds#"/end_game.mp3"
	PathToExplosionSound =  	PathToSounds#"/explosion.mp3"
	PathToDroneSound =      	PathToSounds#"/drone.mp3"
	PathToSonarSound =      	PathToSounds#"/sonar.mp3"
	PathToSurfaceSound =    	PathToSounds#"/surface.mp3"

%%%% Additional settings %%%%

	StartWindow
	TreatStream

	BuildWindow

	Label
	Squares
	PathToIslandSprite = PathToIslandSprite
	PathToWaterSprite = PathToWaterSprite
	SubmarineAboveImage = {QTk.newImage photo(file:PathToSubmarineAboveSprite)}
	SubmarineUnderImage = {QTk.newImage photo(file:PathToSubmarineUnderSprite)}
	MineImage = {QTk.newImage photo(file:PathToMineSprite)}
	Explosion1Image = {QTk.newImage photo(file:PathToExplosion1Sprite)}
	Explosion2Image = {QTk.newImage photo(file:PathToExplosion2Sprite)}
	Explosion3Image = {QTk.newImage photo(file:PathToExplosion3Sprite)}
	Explosion4Image = {QTk.newImage photo(file:PathToExplosion4Sprite)}
	DrawMap

	AnimateSprites
	AnimateExplosion

	StateModification

	RemoveItem
	RemovePath
	RemovePlayer

	Map = Input.map
	NRow = Input.nRow
	NColumn = Input.nColumn

	DrawSubmarine
	MoveSubmarine
	SurfaceSubmarine
	DrawMine
	RemoveMine
	DrawPath

	UpdateLife
in
%%%%% Utils

	fun {ColorConverter Color}
		case Color
			of red then
				c(255 0 0)
			[] blue then
				c(0 0 255)
			[] green then
				c(0 255 0)
			[] yellow then
				c(255 255 0)
			[] white then
				c(255 255 255)
			[] black then
				c(0 0 0)
			else
				Color
		end
	end

%%%%% Build the initial window and set it up (call only once)
	fun{BuildWindow}
		Grid GridScore Toolbar GameGrid ScoreGrid Window
	in
		Toolbar=lr(glue:we tbbutton(text:"Quit" glue:w action:toplevel#close))
		GameGrid=grid(handle:Grid height:500 width:500)
		ScoreGrid=grid(handle:GridScore height:100 width:500 pady:10)
		Window={QTk.build td(Toolbar GameGrid ScoreGrid)}

		{Window show}

		% configure rows and set headers
		{Grid rowconfigure(1 minsize:50 weight:0 pad:5)}
		for N in 1..NRow do
			{Grid rowconfigure(N+1 minsize:50 weight:0 pad:5)}
			{Grid configure({Label N} row:N+1 column:1 sticky:wesn)}
		end
		% configure columns and set headers
		{Grid columnconfigure(1 minsize:50 weight:0 pad:5)}
		for N in 1..NColumn do
			{Grid columnconfigure(N+1 minsize:50 weight:0 pad:5)}
			{Grid configure({Label N} row:1 column:N+1 sticky:wesn)}
		end
		% configure scoreboard
		{GridScore rowconfigure(1 minsize:50 weight:0 pad:5)}
		for N in 1..(Input.nbPlayer) do
			{GridScore columnconfigure(N minsize:50 weight:0 pad:5)}
		end

		{DrawMap Grid}

		handle(grid:Grid score:GridScore)
	end

%%%%% Squares of water and island

	Squares = square(
		0:label(width:1 height:1 image:{QTk.newImage photo(file:PathToWaterSprite)})
		1:label(width:1 height:1 image:{QTk.newImage photo(file:PathToIslandSprite)})
	)

	% 0:label(text:"" width:1 height:1 bg:c(102 102 255)) % water
	% 1:label(text:"" borderwidth:5 relief:raised width:1 height:1 bg:c(153 76 0)) % island

%%%%% Labels for rows and columns
	fun{Label V}
		label(text:V borderwidth:5 relief:raised bg:c(50 50 50) ipadx:5 ipady:5)
	end

%%%%% Function to draw the map
	proc{DrawMap Grid}
		proc{DrawColumn Column M N}
			case Column
			of nil then skip
			[] T|End then
				{Grid configure(Squares.T row:M+1 column:N+1 sticky:wesn)}
				{DrawColumn End M N+1}
			end
		end
		proc{DrawRow Row M}
			case Row
			of nil then skip
			[] T|End then
				{DrawColumn T M 1}
				{DrawRow End M+1}
			end
		end
	in
		{DrawRow Map 1}
	end

%%%%% Sprite animation
	proc {AnimateSprites Grid Position Sprites Time}
		NumberOfSprites = {Record.width Sprites}
		TimePerSprite = Time div NumberOfSprites
		proc {Loop Sprites SpriteNum}
			if SpriteNum >= NumberOfSprites then
				skip
			else SpriteHandle in
				SpriteHandle = Sprites.SpriteNum.handle
				{Grid.grid configure(Sprites.SpriteNum row:Position.x+1 column:Position.y+1 sticky:wesn)}
				{SpriteHandle 'raise'()}
				{Delay TimePerSprite}
				{Grid.grid forget(SpriteHandle)}
				{Loop Sprites (SpriteNum+1)}
			end
		end
	in
		thread {Loop Sprites 0} end
	end

	proc {AnimateExplosion Grid Position}
		Sprites = sprites(
			0:label(handle:_ width:1 height:1 image:Explosion1Image)
			1:label(handle:_ width:1 height:1 image:Explosion2Image)
			2:label(handle:_ width:1 height:1 image:Explosion3Image)
			3:label(handle:_ width:1 height:1 image:Explosion4Image)
		)
	in
		{AnimateSprites
			Grid
			Position
			Sprites
			Input.guiDelay}
	end

%%%%% Init the submarine
	fun{DrawSubmarine Grid ID Position}
		X Y Id Name
		Color ColorRGB DarkColor DarkerColor DarkAmount=50 DarkerAmount=75
		HandlePath
		% Submarine
		HandleSub
		LabelSub
		% Score
		HandleScoreName
		HandleScoreText
		LabelScoreName
		LabelScoreText
		Out
	in
		pt(x:X y:Y) = Position
		id(id:Id color:Color name:Name) = ID
		ColorRGB = {ColorConverter Color}
		% making dark color by "DarkAmount"
		DarkColor = c(
			{Value.max (ColorRGB.1 - DarkAmount) 0}
			{Value.max (ColorRGB.2 - DarkAmount) 0}
			{Value.max (ColorRGB.3 - DarkAmount) 0}
		)
		% making darker color by "DarkerAmount"
		DarkerColor = c(
			{Value.max (ColorRGB.1 - DarkerAmount) 0}
			{Value.max (ColorRGB.2 - DarkerAmount) 0}
			{Value.max (ColorRGB.3 - DarkerAmount) 0}
		)

		HandlePath = {DrawPath Grid DarkerColor X Y}
		{HandlePath 'raise'()}

% submarine
		LabelSub = td(handle:HandleSub label(image:SubmarineUnderImage width:40 height:40) bg:Color width:50 height:50)
		{Grid.grid configure(LabelSub row:X+1 column:Y+1 sticky:wesn)}
		{HandleSub 'raise'()}
% score
		LabelScoreName = label(text:ID.name handle:HandleScoreName bg:DarkColor ipadx:5 ipady:5 relief:solid)
		LabelScoreText = label(text:'HP: '#Input.maxDamage handle:HandleScoreText bg:DarkerColor ipadx:5 ipady:5 relief:solid)
		{Grid.score configure(LabelScoreName row:1 column:Id sticky:wesn padx:10)}
		{Grid.score configure(LabelScoreText row:2 column:Id sticky:wesn padx:10)}

		guiPlayer(id:ID score:HandleScoreText submarine:HandleSub mines:nil path:HandlePath|nil position:Position darkColor:DarkColor darkerColor:DarkerColor)
	end

	fun{MoveSubmarine Position}
		fun{$ Grid State}
			ID HandleScore Handle Mine Path NewPath X Y DarkColor DarkerColor
			NewSubHandle LabelSub
		in
			guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path position:_ darkColor:DarkColor darkerColor:DarkerColor) = State
			pt(x:X y:Y) = Position
			NewPath = {DrawPath Grid DarkerColor X Y}
			{Grid.grid remove(Handle)}
			LabelSub = td(handle:NewSubHandle label(image:SubmarineUnderImage width:40 height:40) bg:DarkerColor width:50 height:50)
			{Grid.grid configure(LabelSub row:X+1 column:Y+1 sticky:wesn)}
			{NewPath 'raise'()}
			{NewSubHandle 'raise'()}
			guiPlayer(id:ID score:HandleScore submarine:NewSubHandle mines:Mine path:NewPath|Path position:Position darkColor:DarkColor darkerColor:DarkerColor)
		end
	end

	fun{SurfaceSubmarine ID}
		fun{$ Grid State}
			ID HandleScore Handle Mine Path NewPath X Y Position DarkColor DarkerColor
			NewSubHandle LabelSub
		in
			guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path position:Position darkColor:DarkColor darkerColor:DarkerColor) = State
			% removing path
			for H in Path.2 do
				{RemoveItem Grid H}
			end
			% switching submarine sprite
			pt(x:X y:Y) = Position
			{Grid.grid remove(Handle)}
			LabelSub = td(handle:NewSubHandle label(image:SubmarineAboveImage width:40 height:40) bg:ID.color width:50 height:50)
			{Grid.grid configure(LabelSub row:X+1 column:Y+1 sticky:wesn)}
			{NewSubHandle 'raise'()}
			guiPlayer(id:ID score:HandleScore submarine:NewSubHandle mines:Mine path:Path.1|nil position:Position darkColor:DarkColor darkerColor:DarkerColor)
		end
	end

	fun{DrawMine Position}
		fun{$ Grid State}
			ID HandleScore Handle Mine Path LabelMine LabelMineFlag HandleMineImage HandleMineFlag X Y DarkColor DarkerColor
			in
			guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path position:_ darkColor:DarkColor darkerColor:DarkerColor) = State
			pt(x:X y:Y) = Position
			LabelMine = label(handle:HandleMineImage image:MineImage width:40 height:40)
			LabelMineFlag = td(handle:HandleMineFlag bg:ID.color width:5 height:5)
			{Grid.grid configure(LabelMine row:X+1 column:Y+1)}
			{Grid.grid configure(LabelMineFlag row:X+1 column:Y+1)}
			{HandleMineImage 'raise'()}
			{HandleMineFlag 'raise'()}
			{Handle 'raise'()}
			guiPlayer(id:ID score:HandleScore submarine:Handle mines:mine(HandleMineImage HandleMineFlag Position)|Mine path:Path position:Position darkColor:DarkColor darkerColor:DarkerColor)
		end
	end

	local
		fun{RmMine Grid Position List}
			case List
			of nil then nil
			[] H|T then
				if (H.3 == Position) then
					{RemoveItem Grid H.1} % mine image
					{RemoveItem Grid H.2} % mine flag
					T
				else
					H|{RmMine Grid Position T}
				end
			end
		end
	in
		fun{RemoveMine Position}
			fun{$ Grid State}
				ID HandleScore Handle Mine Path NewMine DarkColor DarkerColor
				in
				guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path position:_ darkColor:DarkColor darkerColor:DarkerColor) = State
				NewMine = {RmMine Grid Position Mine}
				guiPlayer(id:ID score:HandleScore submarine:Handle mines:NewMine path:Path position:Position darkColor:DarkColor darkerColor:DarkerColor)
			end
		end
	end

	fun{DrawPath Grid Color X Y}
		Handle LabelPath
	in
		LabelPath = td(handle:Handle bg:Color width:5 height:5)
		{Grid.grid configure(LabelPath row:X+1 column:Y+1)}
		Handle
	end

	proc{RemoveItem Grid Handle}
		{Grid.grid forget(Handle)}
	end


	fun{RemovePath Grid State}
		ID HandleScore Handle Mine Path Position DarkColor DarkerColor
	in
		guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path position:Position darkColor:DarkColor darkerColor:DarkerColor) = State
		for H in Path.2 do
	 		{RemoveItem Grid H}
		end
		guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path.1|nil position:Position darkColor:DarkColor darkerColor:DarkerColor)
	end

	fun{UpdateLife Life}
		fun{$ Grid State}
			HandleScore
			in
			guiPlayer(id:_ score:HandleScore submarine:_ mines:_ path:_ position:_ darkColor:_ darkerColor:_) = State
			{HandleScore set('HP: '#Life)}
	 		State
		end
	end

	fun{RemovePlayer Grid WantedID State}
		case State
		of nil then nil
		[] guiPlayer(id:ID score:HandleScore submarine:Handle mines:M path:P position:_ darkColor:_ darkerColor:_)|Next then
			if (ID == WantedID) then
				{HandleScore set(dead)}
				for H in P do
			 		{RemoveItem Grid H}
				end
				for H in M do
			 		{RemoveItem Grid H.1} % mine image
			 		{RemoveItem Grid H.2} % mine flag
				end
				{RemoveItem Grid Handle}
				Next
			else
				State.1|{RemovePlayer Grid WantedID Next}
			end
		end
	end

	fun{StateModification Grid WantedID State Fun}
		case State
		of nil then nil
		[] guiPlayer(id:ID score:_ submarine:_ mines:_ path:_ position:_ darkColor:_ darkerColor:_)|Next then
			if (ID == WantedID) then
				{Fun Grid State.1}|Next
			else
				State.1|{StateModification Grid WantedID Next Fun}
			end
		end
	end

%%%%%%%%%%%%%%%% Sound effect %%%%%%%%%%%%%%%%

	proc {PlaySound FilePath}
		% 32768 max scale factor
		VolumeScale = 32768.0 * (SoundEffectsVolume / 100.0)
		Player = 'wscript .\\scripts\\play_sound_background.vbs'
		Cmd = Player#' '#VolumeScale#' '#FilePath
		ExitCode
	in
		if {Not SoundEnabled} then
			skip
		else
			thread
				{OS.system Cmd ExitCode}
				% {System.show '[PlaySound] Cmd: '#Cmd#' ExitCode:'#ExitCode}
			end
		end
	end

	proc {LoopSound FilePath}
		% 32768 max scale factor
		VolumeScale = 32768.0 * (MusicVolume / 100.0)
		Player = 'wscript .\\scripts\\loop_sound_background.vbs'
		Cmd = Player#' '#VolumeScale#' '#FilePath
		ExitCode
	in
		if {Not SoundEnabled} then
			skip
		else
			thread
				{OS.system Cmd ExitCode}
				% {System.show '[PlaySound] Cmd: '#Cmd#' ExitCode:'#ExitCode}
			end
		end
	end

	proc {PlayGameMusic}		{Send AudioPlayer startGameMusic} end
	proc {KillAllSounds}		{Send AudioPlayer killAllSounds} end

	proc {PlayEndGameSound}		{Send AudioPlayer play(PathToEndGameSound)} end
	proc {PlayExplosionSound}	{Send AudioPlayer play(PathToExplosionSound)} end
	proc {PlayDroneSound}		{Send AudioPlayer play(PathToDroneSound)} end
	proc {PlaySonarSound}		{Send AudioPlayer play(PathToSonarSound)} end
	proc {PlaySurfaceSound}		{Send AudioPlayer play(PathToSurfaceSound)} end

	fun {AudioPlayerPortObject}
		Stream
		Port
		proc {Loop Stream SoundEnabled}
				case Stream
					of play(FilePath)|T then
						if SoundEnabled then
							{PlaySound FilePath}
						end
						{Loop T SoundEnabled}
					[] startGameMusic|T then
						if SoundEnabled then
							{LoopSound PathToMainGameLoopMusic}
						end
						{Loop T SoundEnabled}
					[] killAllSounds|T then
							ExitCode
					in
						if SoundEnabled then
							{OS.system 'wscript .\\scripts\\kill_audioplayer_process.vbs' ExitCode}
						end
						{Loop T SoundEnabled}
					[] _|T then
						{Loop T SoundEnabled}
				end
		end
	in
		if {Not SoundEnabled} then
			{System.show 'Sound effects are muted'}
		end
		{NewPort Stream Port}
		thread
			{Loop Stream SoundEnabled}
		end
		Port
	end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	fun{StartWindow}
		Stream
		Port
	in
		{NewPort Stream Port}
		AudioPlayer = {AudioPlayerPortObject}
		thread
			{PlayGameMusic}
			{TreatStream Stream nil nil}
		end
		Port
	end

	proc{TreatStream Stream Grid State}
		{Delay Input.guiDelay}
		case Stream
		of nil then skip
		[] buildWindow|T then NewGrid in
			NewGrid = {BuildWindow}
			{TreatStream T NewGrid State}
		[] initPlayer(ID Position)|T then NewState in
			if ID == null then
				{TreatStream T Grid State}
			else
				NewState = {DrawSubmarine Grid ID Position}
				{TreatStream T Grid NewState|State}
			end
		[] movePlayer(ID Position)|T then
			if ID == null then
				{TreatStream T Grid State}
			else
				{TreatStream T Grid {StateModification Grid ID State {MoveSubmarine Position}}}
			end
		[] lifeUpdate(ID Life)|T then
			if ID == null then
				{TreatStream T Grid State}
			else
				{TreatStream T Grid {StateModification Grid ID State {UpdateLife Life}}}
			end
		[] putMine(ID Position)|T then
			if ID == null then
				{TreatStream T Grid State}
			else
				{TreatStream T Grid {StateModification Grid ID State {DrawMine Position}}}
			end
		[] removeMine(ID Position)|T then
			if ID == null then
				{TreatStream T Grid State}
			else
				{TreatStream T Grid {StateModification Grid ID State {RemoveMine Position}}}
			end
		[] surface(ID)|T then
			if ID == null then
				{TreatStream T Grid State}
			else
				{PlaySurfaceSound}
				{TreatStream T Grid {StateModification Grid ID State {SurfaceSubmarine ID}}}
			end
		[] removePlayer(ID)|T then
			if ID == null then
				{TreatStream T Grid State}
			else UpdatedState in
				UpdatedState = {RemovePlayer Grid ID State}
				% 0 or 1 player remaining
				if UpdatedState == nil orelse UpdatedState.2 == nil then
					{KillAllSounds}
					{Delay 500}
					{PlayEndGameSound}
				end
				{TreatStream T Grid UpdatedState}
			end
		[] explosion(ID Position)|T then
			if ID == null then
				{TreatStream T Grid State}
			else
				{PlayExplosionSound}
				{AnimateExplosion Grid Position}
				{TreatStream T Grid State}
			end
		[] drone(ID Drone)|T then
			if ID == null then
				{TreatStream T Grid State}
			else
				{PlayDroneSound}
				{TreatStream T Grid State}
			end
		[] sonar(ID)|T then
			if ID == null then
				{TreatStream T Grid State}
			else
				{PlaySonarSound}
				{TreatStream T Grid State}
			end
		[] _|T then
			{TreatStream T Grid State}
		end
	end
end
