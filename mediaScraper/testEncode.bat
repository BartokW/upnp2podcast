@ECHO OFF

set COMMAND=
:LOOP
IF (%1)==() GOTO NEXT
set COMMAND=%COMMAND% %1
shift
GOTO LOOP

:NEXT
cd /D "D:\SageTVDev\mediaScraper"
start "MediaShrink" /B /LOW /WAIT mediaShrink.pl %COMMAND% /vcodec ffmpeg /tee
echo Exit Code = %ERRORLEVEL%
pause
exit

REM
REM
REM Some useful command lines I use, you can just copy/rename this file and replace the the above encode command with these for some handy drag and drop encoding
REM
REM Manually select DVD titles to encode
REM     start "MediaShrink" /B /LOW /WAIT mediaShrink.exe %COMMAND% /vbitrate 2000 /twopass /manualTitles /tee
REM
REM Encode for iPhone
REM     start "MediaShrink" /B /LOW /WAIT mediaShrink.exe %COMMAND% /container mp4 /tee /handbrakeProfile "iPhone & iPod Touch" /outputSubFolder "iPhone"
REM
REM Encode for Hardware Player
REM     start "MediaShrink" /B /LOW /WAIT mediaShrink.exe %COMMAND% /container mp4 /tee /handbrakeProfile "Universal" /outputSubFolder "Xbox"
REM
REM Encode for High Quality Encode
REM     start "MediaShrink" /B /LOW /WAIT mediaShrink.exe %COMMAND% /vbitrate 2500 /vprofile HQ /tee
REM
REM Encode for Medium Quality Encode
REM     start "MediaShrink" /B /LOW /WAIT mediaShrink.exe %COMMAND% /vbitrate 2500 /tee
REM
REM Encode for Low Quality Encode
REM     start "MediaShrink" /B /LOW /WAIT mediaShrink.exe %COMMAND% /vbitrate 2000 /tee
REM
