@ECHO OFF
REM  MediaScraper.exe
REM    Usage: TO use this batch file set this directory your mediaScraper directory
REM           then drag and drop any number of files and/or directories.

set DIRECTORY="D:\upnp2podcast\mediaScraper"

REM  Options:  
REM    /genPropretyFile - Generate .properties file (default)
REM    /genMyFile       - Generate .my file
REM    /genInfoFIle     - Generate .info file
REM    /updateInfo      - Overwrite metadata file if it exists
REM
REM  examples:
REM    mediaScraper.exe %COMMAND% /genPropertyFile /genMyFile /updateInfo
REM

:LOOP
IF (%1)==() GOTO NEXT
set COMMAND=%COMMAND% "%~f1"
shift
GOTO LOOP

:NEXT
cd /D "%DIRECTORY%"
mediaShrink.pl %COMMAND% /profile "autoEncode" /batch  /saveLog /onePass /vcodec ffmpeg
pause
GOTO EOF


