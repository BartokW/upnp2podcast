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
    Encode CLI #12    =ErrorCheck
    Encoder #12       =/insertFunction

    Encode CLI #2     =/container mkv /vcodec x264 /autoCrop /vProfile MQ
    Encoder #2        =/setOptions /noOverwrite

    Encode CLI #2     =/vbitrate ?>%%SNIP:HDTVCheck%%<:>2000<=>isDVD<:>1800<=>1500<?
    Encoder #2        =/setOptions /noOverwrite

    Encode CLI #2     =/acodec ?>ORIGINAL:audioCodec=~(ac3|dts)&&ORIGINAL:audioChannels=~6&&!ORIGINAL:43in169<:>passthrough<=>faac<? /abitrate 160
    Encoder #2        =/setOptions /noOverwrite

    Encode CLI #2     =?>isDVD<:>/decomb /IVTC %cutComm<?
    Encoder #2        =/setOptions /noOverwrite

    Encode CLI #6     =?>ORIGINAL:percentFilm>25&&%%SNIP:HDTVCheck%%<:>/IVTC<?
    Encoder #6        =/setOptions /noOverwrite

    Encode CLI #6     =?>ORIGINAL:videoCodec=~mpeg2video&&!%%SNIP:HDTVCheck%%<:>/decomb<?
    Encoder #6        =/setOptions /noOverwrite

    Encode CLI #9     =?>!isDVD<:>/yRes ?>ORIGINAL:43in169<:>540<=>ORIGINAL:cropY>720<:>720<=>%%ORIGINAL:cropY%%<?<?
    Encoder #9        =/setOptions /noOverwrite

    Encode CLI #10    =?>%%SNIP:SubtitleSuccess%%&&%%container%%=~(mkv|mp4)<:>/addSubtitleTrack<?
    Encoder #10       =/setOptions /noOverwrite

    Encode CLI #12    =Handbrake
    Encoder #12       =/branch


    
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
    
