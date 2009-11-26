# Function: QuickStream Fix
#
# Do a quickstream fix on mpegs
#
#   INPUT : %%inputMain%%.(mpg|ts)
#   OUTPUT: %%OUTPUT_MAIN%%.mpg
#

    Profile           =QuickStream Fix
    Encode CLI #1     =?>EXISTS:C:\Program Files\VideoReDoPlus\VideoReDo.exe<:>/VideoRedoPath "C:\Program Files\VideoReDoPlus\"<=>EXISTS:C:\Program Files\VideoReDoTVSuite\VideoReDo3.exe<:>/VideoRedoPath "C:\Program Files\VideoReDoTVSuite\"<?
    Encoder #1        =/setOptions
    Encode CLI #1     =?>VideoRedoPath<:>#VRD_StreamFix#//nologo "%%VideoRedoPath%%\vp.vbs" "%%inputMain%%" "%%OUTPUT_MAIN%%.mpg" /t1 /q /e<?
    Encoder #1        =/exe cscript
    Encode CLI #3     =?>VideoRedoPath<:>/quickStreamFixFile "%%inputMain%%"<?
    Encoder #3        =/setOptions


# Profile: QuickStreamFix
#
# Handles error case where people have old profile name w/o space
#

    Profile           =QuickStreamFix
    Encode CLI #1     =QuickStream Fix
    Encoder #1        =/insertFunction


