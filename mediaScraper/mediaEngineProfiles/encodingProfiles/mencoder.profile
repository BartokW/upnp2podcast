# Profile: mencoder
#
# Main profile for the mencoder encoder
#
#

    Profile           =mencoder
    Encode CLI #1     =?>!errorChecked<:>ErrorCheck<?
    Encoder #1        =/insertFunction
    Encode CLI #1     =SetDefaults
    Encoder #1        =/insertFunction
    Encode CLI #1     =?>inputMain:videoContainer=~mpegts<:>QuickStream Fix<?
    Encoder #1        =/insertFunction
    Encode CLI #1     =?>cutComm<:>Cut Commercials<?
    Encoder #1        =/insertFunction
    Encode CLI #3     =/passOne
    Encoder #3        =/setOptions
    Encode CLI #2     =!#EncodePass_1#-o ?>!onePass<:>NUL<=>"%%OUTPUT_MAIN%%.avi"<? ?>!onePass<:>-passlogfile "%%PASS_LOGFILE%%"<? -vf %%SNIP:mencoder Video Filters%% -oac %%SNIP:mencoder Audio%% -ovc ?>xvid<:>%%SNIP:mencoder Xvid%%<=>divx<:>%%SNIP:mencoder Divx%%<=>%%SNIP:mencoder x264%%<? "%%inputMain%%" ?>addShowSegs<:>%%addShowSegs%%<?
    Encoder #2        =/exe mencoder.exe
    Encode CLI #3     =?>!onePass<:>/passTwo<?
    Encoder #3        =/setOptions
    Encode CLI #4     =?>!onePass<:>!#EncodePass_2#-o "%%OUTPUT_MAIN%%.avi" -passlogfile "%%PASS_LOGFILE%%" -vf %%SNIP:mencoder Video Filters%% -oac %%SNIP:mencoder Audio%% -ovc ?>xvid<:>%%SNIP:mencoder Xvid%%<=>divx<:>%%SNIP:mencoder Divx%%<=>%%SNIP:mencoder x264%%<? "%%inputMain%%" ?>addShowSegs<:>%%addShowSegs%%<?<? 
    Encoder #4        =/exe mencoder.exe
    Encode CLI #2     =?>mkv&&aac51&&ORIGINAL:audioChannels=eq=6&&ORIGINAL:audioCodec=~ac3<:>/splitFileAudio "?>quickStreamFixFile<:>%%quickStreamFixFile%%<=>cutCommFile<:>%%cutCommFile%%<=>%%ORIGINAL%%<?"<?
    Encoder #2        =/setOptions
    Encode CLI #2     =?>mkv||mp4<:>/splitAV<?
    Encoder #2        =/setOptions
    Encode CLI #2     =?>aac51<:>makeAAC51<?
    Encoder #2        =/insertFunction
    Encode CLI #6     =?>mkv<:>mkvMux<=>mp4<:>mp4Mux<?
    Encoder #6        =/insertFunction
    Encode CLI #2     =?>inputMain:videoContainer=~matroska<:>mkvAttachExtras<=>addSubtitleTrack&&inputMain:videoContainer=~mov<:>mp4AttachSubtitles<?
    Encoder #2        =/insertFunction
    Encode CLI #3     =outputModes
    Encoder #3        =/insertFunction

