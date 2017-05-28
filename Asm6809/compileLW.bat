@echo off
cls
%~d1
cd %~p1

..\..\..\roms\lw\lwasm -t 12 -b -o %~n1.bin %~nx1 -l >result-%~n1.txt 2>&1

if errorlevel 1 goto HERE

del temp\?*.*
rd temp
goto FIM

:HERE
del temp\?*.*
rd temp
move result.txt %TEMP%\error.txt
start notepad %TEMP%\error.txt
del error.txt
rem pause >nul

:FIM
