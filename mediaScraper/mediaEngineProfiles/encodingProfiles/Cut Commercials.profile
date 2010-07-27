# Function: Cut Commercials
#
# Attempts to cut commercials from video
#
# Input = %%inputMain%%
# Ouput = %%OUTPUT_MAIN%%.%%inputMain_EXT%%
#

    Profile           =Cut Commercials
    Encode CLI #1     =?>EXISTS:C:\Program Files\VideoReDoPlus\VideoReDo.exe<:>/VideoRedoPath "C:\Program Files\VideoReDoPlus\"<=>EXISTS:C:\Program Files\VideoReDoTVSuite\VideoReDo3.exe<:>/VideoRedoPath "C:\Program Files\VideoReDoTVSuite\"<?
    Encoder #1        =/setOptions
    Encode CLI #1     =?>inputMain:videoCodec=~mpeg2video&&VideoRedoPath&&!forceMencoderCutComm<:>?>(>EXT:VPrj&&onlyWhenVprj<)||!onlyWhenVprj<:>VRD_CutCommercials<?<=>EXT:EDL&&!onlyWhenVprj<:>mencoder_CutCommercials<?
    Encoder #1        =/insertFunction
    Encode CLI #3     =?>profile=eq=Cut Commercials||profile=eq=CutCommercials<:>outputModes<?
    Encoder #3        =/insertFunction

# Function: mencoder_CutCommercials
#
# Attempts to cut commercials from video
#
# Input = %%inputMain%%
# Ouput = %%OUTPUT_MAIN%%.%%inputMain_EXT%%
#

    Profile           =mencoder_CutCommercials
    Encode CLI #1     =?>!EXT:EDL||inputMain:videoContainer=~mpegts<:>Generate_ComCutFile_Comskip<?
    Encoder #1        =/insertFunction
    Encode CLI #1     =?>EXT:edl<:>#Cutting_Commercials#"%%inputMain%%" -o "%%OUTPUT_MAIN%%.?>inputMain:videoContainer=~mpeg<:>mpg<=>avi<?" -oac copy -ovc copy -edl "%%ORIGINAL_FULLFILE%%.edl" ?>inputMain:videoContainer=~mpeg<:>-of mpeg -mpegopts format=dvd:tsaf<?<?
    Encoder #1        =/exe mencoder.exe
    Encode CLI #4     =?>ORIGINAL:videoContainer=~matroska<:>mkvMux<=>ORIGINAL:videoContainer=~mov||ORIGINAL:videoContainer=~mp4<:>mp4Mux<?
    Encoder #4        =/insertFunction
    Encode CLI #3     =?>comCutSuccess<:>/cutCommComplete<?
    Encoder #3        =/setOptions
    Encode CLI #3     =?>comCutSuccess&&inputMain:videoContainer=~mpeg<:>/cutCommFile %%inputMain%%<?
    Encoder #3        =/setOptions

# Function: VRD_CutCommercials
#
# Do a quickstream fix on mpegs
#
#   INPUT : %%inputMain%%.(mpg|ts)
#   OUTPUT: %%OUTPUT_MAIN%%.mpg
#

    Profile           =VRD_CutCommercials
    Encode CLI #1     =?>!(>EXT:VPrj||EXT:EDL<)<:>Generate_ComCutFile_Comskip<?
    Encoder #1        =/insertFunction
    Encode CLI #1     =?>EXT:EDL&&!EXT:VPRJ<:>#edl2vprj#"%%ORIGINAL_FULLFILE%%.edl" "%%OUTPUT_VPRJ%%.VPrj"<?
    Encoder #1        =/exe edl2vprj.exe
    Encode CLI #1     =?>EXT:VPrj||EXISTS:%%inputVprj%%<:>#VRD_CUT#//nologo "%%VideoRedoPath%%\vp.vbs" "?>EXT:VPrj<:>%%ORIGINAL_FULLFILE%%.VPrj<=>%%inputVPRJ%%<?" "%%OUTPUT_MAIN%%.mpg" /t1 /q /e<?
    Encoder #1        =/exe cscript 
    Encode CLI #3     =?>EXT:VPrj||EXISTS:%%inputVprj%%<:>/cutCommComplete<?
    Encoder #3        =/setOptions
    Encode CLI #3     =?>EXT:VPrj||EXISTS:%%inputVprj%%<:>/cutCommFile "%%inputMain%%"<?
    Encoder #3        =/setOptions

# Function: VideoRedo_Funcs
#
# Do a quickstream fix on mpegs
#
#   INPUT : %%inputMain%%.(mpg|ts)
#   OUTPUT: %%OUTPUT_MAIN%%.mpg
#

    Profile           =VRD_Funcs
    Encode CLI #1     =?>VideoRedoInstalled&&inputMain:videoCodec=~mpeg2video<:>?>cutComm<:>VRD_CutCommercials<=>inputMain:videoContainer=~mpegts||alwaysStreamFix<:>QuickStream Fix<?<?
    Encoder #1        =/insertFunction

# Function: Generate_ComCutFile_Comskip
#
# Geneate a EDL/VPRJ file
#
#   INPUT : %%inputMain%%.(mpg|ts)
#   OUTPUT: %%OUTPUT_MAIN%%.mpg
#

    Profile           =Generate_ComCutFile_Comskip
    Encode CLI #1     =#COMSKIP#--ini="%%SAGEDIR%%\perl2dvd\comskip_default.ini" "%%ORIGINAL%%"
    Encoder #1        =/exe comskip.exe
    Encode CLI #1     =#DEL_EXTRA_FILES#"%%ORIGINAL_FULLFILE%%.vprj"
    Encoder #1        =/exe del
    Encode CLI #1     =#DEL_EXTRA_FILES#"%%ORIGINAL_FULLFILE%%.csv"
    Encoder #1        =/exe del


# Function: Generate_ComCutFile_VRD
#
# Do a quickstream fix on mpegs
#
#   INPUT : %%inputMain%%.(mpg|ts)
#   OUTPUT: %%OUTPUT_MAIN%%.mpg
#

    Profile           =Generate_ComCutFile_VRD
    Encode CLI #1     =#VRD_SCAN#//nologo "%%VideoRedoPath%%\AdScan.vbs" "%%inputMain%%" "%%OUTPUT_VPRJ%%.VPrj"
    Encoder #1        =/exe cscript

# Profile: CutCommercials
#
# Handles error case where people have old profile name w/o space
#

    Profile           =CutCommercials
    Encode CLI #1     =Cut Commercials
    Encoder #1        =/insertFunction
