# Profile: HandBrake
#
# Main handbrake profile, passes video to mencoder HandBrake it can't handle the content
#

    Profile           =HandBrake
    Encode CLI #1     =?>!errorChecked<:>ErrorCheck<?
    Encoder #1        =/insertFunction
    Encode CLI #1     =SetDefaults
    Encoder #1        =/insertFunction
    Encode CLI #1     =?>forceMencoder<:>mencoder<?
    Encoder #1        =/branch
    Encode CLI #1     =?>inputMain:videoContainer=~mpegts&&(>!cutComm||(>cutComm&&onlyWhenVprj&&!EXT:vprj<)<)<:>QuickStream Fix<?
    Encoder #1        =/insertFunction
    Encode CLI #1     =?>cutComm&&!isDVD<:>Cut Commercials<?
    Encoder #1        =/insertFunction
    Encode CLI #2     =?>addSubtitleTrack<:>extractSubtitles<?
    Encoder #2        =/insertFunction
    Encode CLI #1     =!#handbrake_1#-v -i "%%inputMain_REVSLASHES%%" -o "%%OUTPUT_MAIN_REVSLASHES%%.?>avi<:>avi<=>mp4<:>mp4<=>mkv<?" %%SNIP:Handbrake DVD%% %%SNIP:Handbrake Subtitles%% %%SNIP:Handbrake Video%% %%SNIP:Handbrake Audio%% %%SNIP:Handbrake Video Filters%%
    Encoder #1        =/exe HandBrakeCLI.exe
    Encode CLI #5     =?>addSubtitleTrack&&EXISTS:%%INPUTSUB%%<:>/subtitleComplete<?
    Encoder #5        =/setOptions
    Encode CLI #2     =?>aac51<:>HandBrakeAAC51<?
    Encoder #2        =/insertFunction
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
