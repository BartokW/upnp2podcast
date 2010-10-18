# Profile: HandBrake
#
# Main handbrake profile, passes video to mencoder HandBrake it can't handle the content
#

    Profile           =HandBrake
    Encode CLI #1     =?>quickStreamFix||inputMain:videoContainer=~mpegts||inputMain:videoCorruption&&(>!cutComm||(>cutComm&&onlyWhenVprj&&!EXT:vprj<)<)<:>QuickStream Fix<?
    Encoder #1        =/insertFunction
    Encode CLI #1     =?>cutComm&&!isDVD&&inputMain:videoCodec=~mpeg2video<:>Cut Commercials<?
    Encoder #1        =/insertFunction
    Encode CLI #4     =?>ORIGINAL:embeddedCCCount>10&&!handbrakeSubtitleTracks&&!noSubtitles<:>extractSubtitles<?
    Encoder #4        =/insertFunction
    Encode CLI #1     =!#handbrake_1#-v -i "%%inputMain_REVSLASHES%%" -o "%%OUTPUT_MAIN_REVSLASHES%%.%%container%%" %%SNIP:Handbrake DVD%% ?>handbrakeFullCommand<:>%%handbrakeFullCommand%%<=>handbrakeProfile<:>--preset="%%handbrakeProfile%%"<=>%%SNIP:Handbrake Subtitles%% %%SNIP:Handbrake Video%% %%SNIP:Handbrake Audio%% %%SNIP:Handbrake Video Filters%%<?
    Encoder #1        =/exe HandBrakeCLI.exe
    Encode CLI #1     =?>!(>prevExeLog=~Rip done<)<:>/ERROR "Handbrake encode didn't finish properly"<?
    Encoder #1        =/setOptions  
    Encode CLI #2     =?>inputMain:videoContainer=~matroska<:>mkvAttachExtras<?
    Encoder #2        =/insertFunction
    Encode CLI #3     =outputModes
    Encoder #3        =/insertFunction

outputModes


# Profile: HandBrakeAAC51
#
# Add 5.1 AAC track to handbrake .mkv output
#

    Profile           =HandBrakeAAC51
    Encode CLI #2     =splitAV
    Encoder #2        =/insertFunction
    Encode CLI #2     =makeAAC51
    Encoder #2        =/insertFunction
    Encode CLI #2     =?>mkv<:>mkvMux<=>mp4<:>mp4Mux<?
    Encoder #2        =/insertFunction
