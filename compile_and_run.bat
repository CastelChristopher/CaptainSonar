@echo off
echo clean functors
rm .\GUI.ozf > nul 2>&1
rm .\Input.ozf > nul 2>&1
rm .\Main.ozf > nul 2>&1
rm .\Player45AdvancedAI.ozf > nul 2>&1
rm .\Player45BasicAI.ozf > nul 2>&1
rm .\PlayerManager.ozf > nul 2>&1

echo compile functors
@echo on
ozc -c .\*.oz
REM > nul 2>&1

if %ERRORLEVEL% GEQ 1 (
    echo error compiling functors
) else (
    echo run game
    ozengine.exe .\Main.ozf
)

PAUSE
