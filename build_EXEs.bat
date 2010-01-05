ECHO off
setlocal
FOR /F "TOKENS=1* DELIMS= " %%A IN ('DATE/T') DO SET CDATE=%%B
FOR /F "TOKENS=1,2 eol=/ DELIMS=/ " %%A IN ('DATE/T') DO SET mm=%%B
FOR /F "TOKENS=1,2 DELIMS=/ eol=/" %%A IN ('echo %CDATE%') DO SET dd=%%B
FOR /F "TOKENS=2,3 DELIMS=/ " %%A IN ('echo %CDATE%') DO SET yyyy=%%B
SET date=%mm%/%dd%/%yyyy% 
ECHO on

pp -N=Comments="%~n1.exe v1.0 by evilpenguin (%time% %date%)" -o "%~dp1%~n1.exe" "%~f1"

pause