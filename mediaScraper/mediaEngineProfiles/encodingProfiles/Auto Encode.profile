# Profile: Auto Encode
#
# Automagically encode content
#

    Profile           =Auto Encode
    Encode CLI #12    =ErrorCheck
    Encoder #12       =/insertFunction
    Encode CLI #1     =?>hardwareDevice<:>Auto Encode Devices<?
    Encoder #1        =/branch
    Encode CLI #2     =/autoCrop
    Encoder #2        =/setOptions
    Encode CLI #2     =?>isDVD<:>/deinterlace<&>/reverseTelecine<?
    Encoder #2        =/setOptions
    Encode CLI #3     =?>!(>mkv||avi||mp4<)<:>/mkv<?
    Encoder #3        =/setOptions
    Encode CLI #3     =?>!(>x264||xvid||divx<)<:>/x264<?
    Encoder #3        =/setOptions
    Encode CLI #3     =?>!(>ac3||mp3||aac||aac51||copyAudio<)<:>?>ORIGINAL:audioCodec=~ac3&&ORIGINAL:audioChannels=~6<:>/copyAudio<=>/aac<?<?
    Encoder #3        =/setOptions
    Encode CLI #6     =?>%%SNIP:HDTVCheck%%<:>/cliBitrate 2500 /twopass /highProfile<=>/onePass<?
    Encoder #6        =/setOptions
    Encode CLI #6     =?>ORIGINAL:percentFilm>25&&%%SNIP:HDTVCheck%%<:>/reverseTelecine<?
    Encoder #6        =/setOptions
    Encode CLI #8     =?>ORIGINAL:videoCodec=~mpeg2video&&!ORIGINAL:videoResolution=~(1280x|x720)&&!reverseTelecine<:>/deinterlace<?
    Encoder #8        =/setOptions
    Encode CLI #9     =?>%%SNIP:HDTVCheck%%&&ORIGINAL:cropY>720<:>/verticalScale 720<?
    Encoder #9        =/setOptions
    Encode CLI #10    =?>!burnSubtitles&&%%SNIP:SubtitleSuccess%%&&(>mkv||mp4<)<:>/addSubtitleTrack<?
    Encoder #10       =/setOptions
    Encode CLI #6     =?>reverseTelecine&&%%SNIP:HDTVCheck%%&&ORIGINAL:videoResolution=~(1280x|x720)<:>/forceMencoder2<?
    Encoder #6        =/setOptions
    Encode CLI #12    =?>forceMencoder<:>Mencoder<=>Handbrake<?
    Encoder #12       =/branch

# Profile: ErrorCheck
#
# Check for bad options and attempt to compensate.
# Most of this is already in the Auto Encode profile
# But this is just the basics that other profiles should
# catch also
#

    Profile           =ErrorCheck
    Encode CLI #1     =?>isDVD&&cutComm<:>%cutComm<?
    Encoder #1        =setOptions
    Encode CLI #1     =?>xvid&&!profile=eq=mencoder<:>%xvid /divx<?
    Encoder #1        =/setOptions
    Encode CLI #1     =?>avi&&!profile=eq=mencoder<:>%avi /mkv<?
    Encoder #1        =/setOptions
    Encode CLI #1     =?>copyAudio&&!ORIGINAL:audioCodec=~ac3<:>%copyAudio /mp3<?
    Encoder #1        =/setOptions
    Encode CLI #1     =?>aac51&&!ORIGINAL:audioChannels=~6<:>%aac51 /aac<?
    Encoder #1        =/setOptions
    Encode CLI #5     =?>aac51||(>(>ac3||(>copyAudio&&ORIGINAL:audioCodec=~ac3<)<)&&mp4<)<:>/mkv %avi %mp4<?
    Encoder #5        =/setOptions
    Encode CLI #1     =?>!ORIGINAL:videoContainer=~mpeg||!(>ORIGINAL:audioCodec=~ac3||ORIGINAL:audioCodec=~mp2<)<:><?
    Encoder #1        =/setOptions  
    Encode CLI #1     =?>%%SNIP:HDTVCheck%%<:><?
    Encoder #1        =/setOptions  
    Encode CLI #1     =?>ORIGINAL:videoCodec=~h264&&ORIGINAL:videoContainer=~mpegts<:><?
    Encoder #1        =/setOptions  
    Encode CLI #1     =?>burnSubtitles&&%%SNIP:SubtitleSuccess%%<:>/forceMencoder<?
    Encoder #1        =/setOptions
    Encode CLI #1     =?>addShowSegs<:>/forceMencoder<?
    Encoder #1        =/setOptions
    Encode CLI #1     =/errorChecked
    Encoder #1        =/setOptions

# Profile: SetDefaults
#
# Set default options when no other options are specified
#

    Profile           =SetDefaults
    Encode CLI #1     =?>!(>mkv||avi||mp4<)<:>/mkv<?
    Encoder #1        =/setOptions
    Encode CLI #1     =?>!(>x264||xvid||divx<)<:>/x264<?
    Encoder #1        =/setOptions
    Encode CLI #5     =?>!(>ac3||mp3||aac||aac51||copyAudio<)<:>/aac<?
    Encoder #5        =/setOptions

    
# Profile: AutoEncode
#
# Handles error case where people have old profile name w/o space
#

    Profile           =AutoEncode
    Encode CLI #1     =Auto Encode
    Encoder #1        =/insertFunction

# SNIP: HDTVCheck
#
# Snip to check for HDTV
#

    Profile           =HDTVCheck
    Encode CLI #1     =(>ORIGINAL:videoCodec=~mpeg2video&&ORIGINAL:videoResolution=~(1920x|x1080|1280x|x720)<)
    Encoder #1        =
    
# SNIP: SNIP:SubtitleSuccess
#
# Snip to check for valid subtitles
#

    Profile           =SubtitleSuccess
    Encode CLI #1     =(>(>EXT:smi||EXT:srt<)||ORIGINAL:embeddedCCCount>10<)
    Encoder #1        =
