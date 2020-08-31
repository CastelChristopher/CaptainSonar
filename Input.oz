functor
export
   isTurnByTurn:IsTurnByTurn
   nRow:NRow
   nColumn:NColumn
   map:Map
   nbPlayer:NbPlayer
   players:Players
   colors:Colors
   thinkMin:ThinkMin
   thinkMax:ThinkMax
   turnSurface:TurnSurface
   maxDamage:MaxDamage
   missile:Missile
   mine:Mine
   sonar:Sonar
   drone:Drone
   minDistanceMine:MinDistanceMine
   maxDistanceMine:MaxDistanceMine
   minDistanceMissile:MinDistanceMissile
   maxDistanceMissile:MaxDistanceMissile
   guiDelay:GUIDelay
define
   IsTurnByTurn
   NRow
   NColumn
   Map
   NbPlayer
   Players
   Colors
   ThinkMin
   ThinkMax
   TurnSurface
   MaxDamage
   Missile
   Mine
   Sonar
   Drone
   MinDistanceMine
   MaxDistanceMine
   MinDistanceMissile
   MaxDistanceMissile
   GUIDelay
in

%%%% Style of game %%%%

   IsTurnByTurn = false

%%%% Description of the map %%%%

   NRow = 10
   NColumn = 10

   Map = [[1 1 0 0 0 0 0 0 0 0]
	  [1 1 0 0 0 0 0 0 0 0]
	  [1 0 0 1 1 0 0 0 0 0]
	  [0 0 1 1 0 0 1 0 0 0]
	  [0 0 0 0 0 0 0 0 0 0]
	  [0 0 0 0 0 0 1 0 0 0]
	  [0 0 0 1 0 0 1 1 1 0]
	  [0 0 1 1 1 0 1 1 0 0]
	  [0 0 0 0 1 1 0 0 0 1]
	  [0 0 0 0 0 0 0 0 1 1]]

%%%% Players description %%%%

   NbPlayer = 6
   Players = [player45AdvancedAI player45AdvancedAI player45BasicAI player45BasicAI playerBasicAI playerBasicAI]
   Colors = [red blue green yellow black white]

   %  red      -> c(255 0 0)
   %  blue     -> c(0 0 255)
   %  green    -> c(0 255 0)
   %  yellow   -> c(255 255 0)
   %  white    -> c(255 255 255)
   %  black    -> c(0 0 0)

%%%% Thinking parameters (only in simultaneous) %%%%

   ThinkMin = 0
   ThinkMax = 0

%%%% Surface time/turns %%%%

   TurnSurface = 0

%%%% Life %%%%

   MaxDamage = 1

%%%% Number of load for each item %%%%

   Missile = 2
   Mine = 2
   Sonar = 2
   Drone = 2

%%%% Distances of placement %%%%

   MinDistanceMine = 1
   MaxDistanceMine = 2
   MinDistanceMissile = 1
   MaxDistanceMissile = 4

%%%% Waiting time for the GUI between each effect %%%%

   GUIDelay = 10 % ms

end
