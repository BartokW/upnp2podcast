ECHO off
setlocal
FOR /F "TOKENS=1* DELIMS= " %%A IN ('DATE/T') DO SET CDATE=%%B
FOR /F "TOKENS=1,2 eol=/ DELIMS=/ " %%A IN ('DATE/T') DO SET mm=%%B
FOR /F "TOKENS=1,2 DELIMS=/ eol=/" %%A IN ('echo %CDATE%') DO SET dd=%%B
FOR /F "TOKENS=2,3 DELIMS=/ " %%A IN ('echo %CDATE%') DO SET yyyy=%%B
SET date=%mm%-%dd%-%yyyy% 
ECHO on

copy "%~f1" "%TEMP%\script.pl"
perl -pi.bak -e "s/SNIP:BUILT/Built on %time% %date%/g" "%TEMP%\script.pl"
pp -N=Comments="%~n1.exe v1.0 by evilpenguin (%time% %date%)" -c -M perlIO.pm -o "%~dp1%~n1.exe" "%TEMP%\script.pl"

pause