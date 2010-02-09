##    UPnP2Podcast.pl - Display UPnP servers as podcasts
##    Copyright (C) 2009    Scott Zadigian  zadigian(at)gmail
##
##    This program is free software; you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation; either version 2 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with this program; if not, write to the Free Software
##    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
##    02111-1307, USA
##---------------------------------------------------------------------------##
#! /user/bin/perl
#
  #use strict;
##### Import libraries
  use Encode qw(encode decode);
  use utf8;
  
  my $debug = 0;

  # Get the directory the script is being called from
  my $executable = $0;
  $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;
  my $executablePath = $`;
  my $executableEXE  = $3; 
   
  open(LOGFILE,">$executablePath\\$executableEXE.log");
  
  # Get Start Time
  my ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();


  # Code version
  my $codeVersion = "$executableEXE v1.0 (SNIP:BUILT)".($debug ? "(debug)" : "");
  
  my $invalidMsg .= "\n$codeVersion\n";
  $invalidMsg .= "\tUSAGE:";
  $invalidMsg .= "\t$executableEXE.exe /audio <#> /video <#> /image <#> /text <#> /subcat <#>\n\n";

  my ($feed_begin, $feed_item, $feed_end, $textOnlyDescription) = populateFeedStrings();

  echoPrint("Welcome to $codeVersion!\n");
  echoPrint("  + Path: $executablePath\n");

  # Move arguments into user array so we can modify it
  my @parameters = @ARGV;

  # Initilize options data structures
  my %optionsHash;
  my @inputFiles;
  my @emptyArray = ();
  my %emptyHash  = ();
  
  # Setting cli options
  foreach (@parameters)
  {
      $parametersString .= "\"$_\" ";
  }
  
  setOptions(decode('ISO-8859-1' , $parametersString),\@emptyArray,\%optionsHash,\@inputFiles,\%emptyHash,"  ");

  if (@ARGV == 0)
  {
      echoPrint("  ! No Parameters: just printint one of each\n");
      $optionsHash{lc("audio")}  = 1;
      $optionsHash{lc("video")}  = 1; 
      $optionsHash{lc("text")}   = 1; 
      $optionsHash{lc("subcat")} = 1; 
      $optionsHash{lc("image")}  = 1; 
  }

  my @items = ();
  
  
  for($i=0;$i<$optionsHash{lc("audio")};$i++)
  {
      $newItem = $feed_item;
      
      echoPrint("  + Adding Audio ($i)\n");
      
      $content     = 'http://hd.engadget.com/podcasts/EngadgetHD_Podcast_176.mp3';
      $thumbnail   = 'http://www.blogcdn.com/www.engadget.com/media/2006/09/engadgetpodcastlogo.jpg';
      $description = '<![CDATA['."\n + $codeVersion\n  - ($parametersString)\n\n".'No guests this week, but theres still plenty of HD related topics to talk about. Of course that includes 3D, but after that we had time to discuss a new Blu-ray player from Oppo, future possibilities for digital distribution and exactly what were expecting from NBCs costly Winter Olympics coverage. After that the talk turns to the legal aspects of the latest action from the FCC, and Microsofts patent infringement lawsuit. We wrap things up with an evaluation of DirecTVs multiroom beta, and just what happened to all the hype over connected HDTVs in 2010.]]>';
      $type        = 'audio/mp3';

      $newItem =~ s/%%ITEM_TITLE%%/Audio Item #$i/g;
      $newItem =~ s/%%ITEM_DATE%%//g;
      $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
      $newItem =~ s/%%ITEM_URL%%/$content/g;
      $newItem =~ s/%%ITEM_DUR%%//g;
      $newItem =~ s/%%ITEM_SIZE%%//g;
      $newItem =~ s/%%ITEM_TYPE%%/$type/g;
      $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
      $newItem =~ s/%%ITEM_DUR_SEC%%//g;
      push(@items,$newItem);
  }

  for($i=0;$i<$optionsHash{lc("video")};$i++)
  {
      $newItem   = $feed_item;
      
      echoPrint("  + Adding Video ($i)\n");
      
      $content     = 'http://www.podtrac.com/pts/redirect.mp4/bitcast-a.bitgravity.com/revision3/web/hdnation/0030/hdnation--0030--noveltyremote--hd.h264.mp4';
      $thumbnail   = 'http://bitcast-a.bitgravity.com/revision3/images/shows/hdnation/hdnation_200x200.jpg';
      $description = '<![CDATA['."\n + $codeVersion\n  - ($parametersString)\n\n".'Robert reveals his Silent Home Theater PC Parts, iPad: Is this the ultimate remote control? Recording Over The Air HDTV, Will your next HDTV be 21:9? The Blu-ray Releases for February 2, 2010.]]>';
      $type        = 'video/mp4';
      
      $newItem =~ s/%%ITEM_TITLE%%/Video Item #$i/g;
      $newItem =~ s/%%ITEM_DATE%%//g;
      $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
      $newItem =~ s/%%ITEM_URL%%/$content/g;
      $newItem =~ s/%%ITEM_DUR%%//g;
      $newItem =~ s/%%ITEM_SIZE%%//g;
      $newItem =~ s/%%ITEM_TYPE%%/$type/g;
      $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
      $newItem =~ s/%%ITEM_DUR_SEC%%//g;
      push(@items,$newItem);
  }
  
  for($i=0;$i<$optionsHash{lc("subcat")};$i++)
  {
      $newItem   = $feed_item;
      
      echoPrint("  + Adding Subcategory ($i)(".$optionsHash{lc("subcat")}.")\n");
      
      $content     = 'external,onlineServicesTest';
      $thumbnail   = 'http://upload.wikimedia.org/wikipedia/commons/thumb/4/43/Feed-icon.svg/128px-Feed-icon.svg.png';
      $description = '<![CDATA['."\n + $codeVersion\n  - ($parametersString)\n\n".'Subcatagory #'.$i.']]>';
      $type        = 'sagetv/subcategory';
      
      $newItem =~ s/%%ITEM_TITLE%%/Subcatagory Item #$i/g;
      $newItem =~ s/%%ITEM_DATE%%//g;
      $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
      $newItem =~ s/%%ITEM_URL%%/$content/g;
      $newItem =~ s/%%ITEM_DUR%%//g;
      $newItem =~ s/%%ITEM_SIZE%%//g;
      $newItem =~ s/%%ITEM_TYPE%%/$type/g;
      $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
      $newItem =~ s/%%ITEM_DUR_SEC%%//g;
      
      push(@items,$newItem);
  }
  
  for($i=0;$i<$optionsHash{lc("text")};$i++)
  {
      $newItem = $feed_item;
      
      echoPrint("  + Adding Text ($i)\n");
      
      $content     = '';
      $thumbnail   = 'http://www.iconarchive.com/icons/deleket/sleek-xp-basic/256/Text-Bubble-icon.png';
      $description = $textOnlyDescription;
      $type        = 'sagetv/textonly';
      
      $newItem =~ s/%%ITEM_TITLE%%/Text Only Item (UTF-8) #$i/g;
      $newItem =~ s/%%ITEM_DATE%%//g;
      $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
      $newItem =~ s/%%ITEM_URL%%/$content/g;
      $newItem =~ s/%%ITEM_DUR%%//g;
      $newItem =~ s/%%ITEM_SIZE%%//g;
      $newItem =~ s/%%ITEM_TYPE%%/$type/g;
      $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
      $newItem =~ s/%%ITEM_DUR_SEC%%//g;
      push(@items,$newItem);
  }
  
  for($i=0;$i<$optionsHash{lc("image")};$i++)
  {
      $newItem = $feed_item;
      
      echoPrint("  + Adding Image ($i)\n");
      
      $content     = 'http://microsoftfeed.com/wp-content/uploads/2009/11/LastFM1-972x1024.jpg';
      $thumbnail   = 'http://i.zdnet.com/blogs/zdnet-iphoto.jpg';
      $description = '<![CDATA['."\n + $codeVersion\n  - ($parametersString)\n\n".'Image #'.$i.']]>';
      $type        = 'image/jpeg';
      
      $newItem =~ s/%%ITEM_TITLE%%/Image Item #$i/g;
      $newItem =~ s/%%ITEM_DATE%%//g;
      $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
      $newItem =~ s/%%ITEM_URL%%/$content/g;
      $newItem =~ s/%%ITEM_DUR%%//g;
      $newItem =~ s/%%ITEM_SIZE%%//g;
      $newItem =~ s/%%ITEM_TYPE%%/$type/g;
      $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
      $newItem =~ s/%%ITEM_DUR_SEC%%//g;
      push(@items,$newItem);
  }
  
  #my ($feed_begin, $feed_item, $feed_end, $textOnlyDescription) = populateFeedStrings();
  $opening = $feed_begin;
  $opening =~ s/%%FEED_TITLE%%/Online Services Test/g;
  $opening =~ s/%%FEED_DESCRIPTION%%/$codeVersion @ARGV/g;
  print encode('UTF-8', $opening);
  foreach (@items)
  {
      print encode('UTF-8', $_);
  }  
  print encode('UTF-8', $feed_end);
  
  ##### Overwrite echoPrint for compatability
    sub echoPrint
    {
        my ($stringToPrint) = @_;
        $utf8String = encode('UTF-8', $stringToPrint);
        print stderr $utf8String;
        print LOGFILE $utf8String;
    }   
      
  ##### Populate an options Hash
    sub setOptions
    {
        my ($optionsString,$optionsArray,$optionsHash,$inputFiles,$commandHash,$logSpacing) = @_; 
        my @newOptions;
        my $key;
        my $noOverwrite = 0;
        my $parameterString = "";
        
        echoPrint("$logSpacing+ Parsing switches\n");
        echoPrint("$logSpacing  - optionsString: $optionsString\n");
        
        if (@{$optionsArray}) { echoPrint("$logSpacing  - optionsArray: @{$optionsArray}\n"); }
        if ($optionsString)
        {
            @newOptions= splitWithQuotes($optionsString," ");
        }
        @newOptions = (@{$optionsArray},@newOptions,);
        if (exists $commandHash->{lc("noOverwrite")})
        {
            $noOverwrite = 1;
            echoPrint("$logSpacing    + No Overwritting!\n");
            
        }
        while (@newOptions != 0)
        {
            if ($newOptions[0] =~ m#^/ERROR$#)
            {   # Message from profile that an unrecoverable error has occured
                $reason = "Error reported from profile file: $newOptions[1]";
                echoPrint("    ! $reason\n");
                echoPrint("    ! Moving onto next file");
                $optionsHash->{lc("wereDoneHere")} = $reason;
                $errorLevel++;
                return;
            }
            elsif ($newOptions[0] =~ m#^/(!?)([a-zA-Z0-9_]+)#i)
            {   # Generic add sub string
                echoPrint("$logSpacing  - Adding to to options Hash\n");
                $getVideoInfoCheck = $1;
                $key = $2;
                echoPrint("$logSpacing    + Key: $key ($optionsHash->{lc($key)})\n");
                if (exists $optionsHash->{lc($key)} && $noOverwrite)
                {
                    if ((!($newOptions[1] =~ m#^[/%]# || $newOptions[1] eq "") || $newOptions[1] =~ m#^/.*/#))
                    {
                        echoPrint("$logSpacing      ! Already Exists, skipping: (".$newOptions[0]." ".$newOptions[1].")\n");
                        shift(@newOptions);    # Remove next parameter also
                    }
                    else
                    {
                        echoPrint("$logSpacing      ! Already Exists, skipping: (".$newOptions[0].")\n");
                    }
                }
                elsif (exists $optionsHash->{lc("no".$key)})
                {
                    if ((!($newOptions[1] =~ m#^[/%]# || $newOptions[1] eq "") || $newOptions[1] =~ m#^/.*/#))
                    {
                        echoPrint("$logSpacing      ! Found /no$key, skipping (".$newOptions[0]." ".$newOptions[1].")\n");
                        shift(@newOptions);    # Remove next parameter also
                    }
                    else
                    {
                        echoPrint("$logSpacing      ! Found /no$key, skipping (".$newOptions[0].")\n");
                    }
                }
                else
                {
                    $optionsHash->{lc($key)} = "";
                    if ((!($newOptions[1] =~ m#^[/%]# || $newOptions[1] eq "") || $newOptions[1] =~ m#^/.*/#))
                    {   # If the next parameter data for switch
                        $optionsHash->{lc($key)} = $newOptions[1];
                        echoPrint("$logSpacing    + Value: $optionsHash->{lc($key)}\n");
                        $parameterString .= " $newOptions[0] \"$newOptions[1]\"";
                        shift(@newOptions);    # Remove next parameter also
                        if ($getVideoInfoCheck eq "!")
                        {
                            getVideoInfo($optionsHash->{lc($key)},"     ",$optionsHash);
                        }
                        
                    }
                    else
                    {
                        $parameterString .= " $newOptions[0]";
                    }                 
                }
    
            }
            elsif ($newOptions[0] =~ m#^%([a-zA-Z0-9_]+)#i)
            {   # Generic remove sub string
                echoPrint("$logSpacing    + Found Option ($newOptions[0])\n");
                echoPrint("$logSpacing      - Removing custom switch from hash \n");
                $key = $1;
                echoPrint("$logSpacing      -  Key: $key\n");
                delete $optionsHash->{lc($key)};
            }
            elsif ($inputFiles && (-e encode('ISO-8859-1',$newOptions[0]) || -d encode('ISO-8859-1',$newOptions[0])))
            {
                push(@{$inputFiles}, $newOptions[0]);
                echoPrint("$logSpacing  - Adding Inputfile: $newOptions[0]\n");
            }
            else
            {
                echoPrint("$logSpacing    ! couldn't understand ($newOptions[0]), throwing it away\n");
            }
            shift(@newOptions); 
        }
        #echoPrint("! Returing: ($parameterString)\n");
        return $parameterString;
    }
##### Split a line of text ignoring quoted text
    sub splitWithQuotes
    {
        my ($originalLine,$split) = @_;
        # Handle Quotes
        my @splitWithQuotes = ();
        my %quoteHash = {};
        my $quoteNum = 0;
        while($originalLine =~ /"([^"]*)"/)#"
        {
            $quoteHash{$quoteNum} = $1;
            $originalLine = $`."quote$quoteNum".$';  
            $quoteNum++;
        }
        @splitWithQuotes = split(/"[^"]"/,$originalLine); #"
        @splitWithQuotes = split(/$split/,$originalLine);
        for($i=0;$i<@splitWithQuotes;$i++)
        {
            if ($splitWithQuotes[$i] =~ /quote([0-9]+)$/)
            {
                $splitWithQuotes[$i] = "$quoteHash{$1}";
                echoPrint("        - Replacing $&: $quoteHash{$1}\n",2);
            }
        }
        return @splitWithQuotes;
    }


  sub populateFeedStrings()
  {
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    my $year = 1900 + $yearOffset;
    $month++;
    my $feed_begin = <<FEED_BEGIN;
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
  xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel> 
    <title>%%FEED_TITLE%%</title> 
    <description>$codeVersion @ARGV</description> 
    <language>en-us</language> 
    <itunes:summary>%%FEED_DESCRIPTION%%</itunes:summary> 
    <itunes:subtitle>%%FEED_DESCRIPTION%%</itunes:subtitle> 
FEED_BEGIN

    my $feed_item = <<'PODCAST_ITEM';
    <item> 
      <title>%%ITEM_TITLE%%</title> 
      <description>%%ITEM_DESCRIPTION%%</description> 
      <pubDate>1981-09-15</pubDate> 
      <itunes:subtitle>%%ITEM_DESCRIPTION%%</itunes:subtitle>
      <itunes:duration>%%ITEM_DUR%%</itunes:duration>
      <enclosure url="%%ITEM_URL%%" length="%%ITEM_SIZE%%" type="%%ITEM_TYPE%%" /> 
      <media:content duration="%%ITEM_DUR_SEC%%" medium="video" fileSize="%%ITEM_SIZE%%" url="%%ITEM_URL%%" type="%%ITEM_TYPE%%"> 
       <media:title>%%ITEM_TITLE%%</media:title> 
        <media:description>%%ITEM_DESCRIPTION%%</media:description> 
        <media:thumbnail url="%%ITEM_PICTURE%%"/> 
      </media:content> 
    </item> 
PODCAST_ITEM

    my $feed_end = <<'FEED_END';
  </channel> 
</rss> 
FEED_END

    my $textOnlyDescription = <<'TEXT_ITEM';    
Τη γλώσσα μου έδωσαν ελληνική
το σπίτι φτωχικό στις αμμουδιές του Ομήρου.
Μονάχη έγνοια η γλώσσα μου στις αμμουδιές του Ομήρου.
από το Άξιον Εστί
του Οδυσσέα Ελύτη
TEXT_ITEM
    $textOnlyDescription = '<![CDATA['."\n + $codeVersion\n  - ($parametersString)\n\n".$textOnlyDescription."]]>";

    return ($feed_begin, $feed_item, $feed_end, $textOnlyDescription);
  }
  
  
