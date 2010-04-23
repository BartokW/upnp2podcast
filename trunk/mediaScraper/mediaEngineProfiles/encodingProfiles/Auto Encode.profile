# Profile: Auto Encode
#
# Automagically encode content
#
# HQ HDTV  - /container mkv /vcodec x264 /vbitrate 2500 /acodec ac3       /addSubtitles /verticalScale 720
# MQ HDTV  - /container mkv /vcodec x264 /vbitrate 2000 /acodec ac3       /addSubtitles /verticalScale 688
# LQ HDTV  - /container mkv /vcodec x264 /vbitrate 1500 /acodec faac      /addSubtitles /verticalScale 540
# 4:3 HDTV - /container mkv /vcodec x264 /vbitrate 1500 /acodec faac      /addSubtitles /verticalScale 540 /decomb
# 4:3 SDTV - /container mkv /vcodec x264 /vbitrate 1500 /acodec faac      /addSubtitles /verticalScale 540 /decomb
# DVD      - /container mkv /vcodex x264 /vbitrate 2000 /acodec (ac3|dts) /addSubtitles                    /decomb

    Profile           =Auto Encode
    Encode CLI #1     =ErrorCheck
    Encoder #1        =/insertFunction

    Encode CLI #2     =/container mkv /vcodec x264 /autoCrop /vProfile MQ
    Encoder #2        =/setOptions /noOverwrite

    Encode CLI #3     =/vbitrate ?>%%SNIP:HDTVCheck%%<:>2000<=>isDVD<:>1800<=>1500<?
    Encoder #3        =/setOptions /noOverwrite

    Encode CLI #4     =?>ORIGINAL:audioCodec=~(ac3|dts)&&ORIGINAL:audioChannels=~6&&!ORIGINAL:43in169<:>passthrough<=>/acodec faac /abitrate 160<? 
    Encoder #4        =/setOptions /noOverwrite

    Encode CLI #4     =/acodec ?>ORIGINAL:audioCodec=~ac3<:>ac3<=>ORIGINAL:audioCodec=~dts<:>dts<=>faac /abitrate 160<? 
    Encoder #4        =/setOptions /noOverwrite

    Encode CLI #5     =?>isDVD<:>/decomb /IVTC %cutComm<?
    Encoder #5        =/setOptions /noOverwrite

    Encode CLI #6     =?>ORIGINAL:percentFilm>25&&%%SNIP:HDTVCheck%%<:>/IVTC<?
    Encoder #6        =/setOptions /noOverwrite

    Encode CLI #7     =?>ORIGINAL:videoCodec=~mpeg2video&&!%%SNIP:HDTVCheck%%<:>/decomb<?
    Encoder #7        =/setOptions /noOverwrite

    Encode CLI #8     =?>!isDVD&&!noAutoCrop&&!xRes&&!yRes<:>/yres ?>ORIGINAL:43in169<:>540<=>ORIGINAL:cropY>720<:>720<=>%%ORIGINAL:cropY%%<?<?
    Encoder #8        =/setOptions /noOverwrite

    Encode CLI #9     =?>%%SNIP:SubtitleSuccess%%&&%%container%%=~(mkv|mp4)<:>/addSubtitleTrack<?
    Encoder #9        =/setOptions /noOverwrite

    Encode CLI #10    =Handbrake
    Encoder #10       =/branch


    
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
    Encode CLI #1     =(>ORIGINAL:videoCodec=~mpeg2video&&ORIGINAL:videoResolution=~(1920x|x1080|1280x|x720)&&!ORIGINAL:43in169<)
    Encoder #1        =
    
