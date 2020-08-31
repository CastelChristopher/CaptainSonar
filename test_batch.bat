@echo off
SET /P _input_number_batches=Number of batches ?

SET "var="&for /f "delims=0123456789" %%i in ("%_input_number_batches%") do set var=%%i

if defined var (
    echo Enter le GUD number Pl0x
    PAUSE
) else (
    echo Aight %_input_number_batches% coming right up :3 !
    FOR /L %%A IN (1,1,%_input_number_batches%) DO start compile_and_run.bat
)
