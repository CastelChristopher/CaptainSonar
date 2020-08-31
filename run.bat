@echo off
echo clean functors
rm .\Input.ozf > nul 2>&1

echo compile functors
@echo on
ozc -c .\Input.oz
REM > nul 2>&1

if %ERRORLEVEL% GEQ 1 (
    echo error compiling functors
) else (
    echo run game
    ozengine.exe .\Main.ozf
)

PAUSE
