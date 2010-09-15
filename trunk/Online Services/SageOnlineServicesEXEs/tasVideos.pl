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
  use LWP::Simple qw($ua get head);
  use threads;
  use threads::shared;
  use Thread::Semaphore;
  
  $ua->timeout(30);
  $ua->agent( 'Mozilla/4.0 (compatible; MSIE 5.12; Mac_PowerPC)' );
  
  my $debug = 0;

  # Get the directory the script is being called from
  $executable = $0;
  $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;
  $executablePath = $`;
  $executableEXE  = $3; 
  
  my $semaphoreDailyMotion = Thread::Semaphore->new(10);
  my $semaphoreYoutube     = Thread::Semaphore->new(10);
  my $semaphoreGeneric     = Thread::Semaphore->new();
   
  open(LOGFILE,">$executablePath\\$executableEXE.log");

  # Get Start Time
  my ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();
  my @startTime = ( $startSecond, $startMinute, $startHour);  # Get Start Time
  
  my $year = 1900 + $yearOffset;
  $month++;
  my $dateString = sprintf("%04d%02d%02d",$year,$month,$dayOfMonth);
  $dateXMLString = sprintf("%04d-%02d-%02d",$year,$month,$dayOfMonth);

  # Code version
  my $codeVersion = "$executableEXE v1.0 (SNIP:BUILT)".($debug ? "(debug)" : "");
  
  my $invalidMsg .= "\n$codeVersion\n";
  $invalidMsg .= "\tUSAGE:";
  $invalidMsg .= "\t$executableEXE.exe /profile <Profile name>\n\n";

  my ($feed_begin, $feed_item, $feed_end) = populateFeedStrings();

  echoPrint("Welcome to $codeVersion!\n");
  echoPrint("  + Path: $executablePath\n");

  # Move arguments into user array so we can modify it
  my @parameters = @ARGV;

  # Initilize options data structures
  my %optionsHash;
  my @inputFiles;
  my @emptyArray = ();
  my %emptyHash  = ();
  my $feedTitle  = "Tool Assisted Speedruns";
  
  my %urlToFeedTitle = (   'http://tasvideos.org/Movies-RatingY-Rec.html'   => 'Recommended Videos',
                           'http://tasvideos.org/Movies-NES-FDS.html'   => 'Nintendo',
                           'http://tasvideos.org/Movies-SNES.html'   => 'Super Nintendo',
                           'http://tasvideos.org/Movies-N64.html'   => 'Nintendo 64',
                           'http://tasvideos.org/Movies-GBA.html'   => 'Nintendo Gameboy',
                           'http://tasvideos.org/Movies-DS.html'   => 'Nintendo DS',
                           'http://tasvideos.org/Movies-Genesis-32X-SegaCD.html'   => 'Sega Genesis',
                           'http://tasvideos.org/Movies-Saturn.html'   => 'Sega Saturn',
                           'http://tasvideos.org/Movies-PSX.html'   => 'Sony Playstation',
                           'http://tasvideos.org/Movies-Arcade.html'   => 'Arcade Games',
                           'http://tasvideos.org/Movies-Hacks.html'   => 'Special Runs',);
              
    
  
  # Setting cli options
  foreach (@parameters)
  {
      $parametersString .= "\"$_\" ";
  }
  
  setOptions(decode('ISO-8859-1' , $parametersString),\@emptyArray,\%optionsHash,\@inputFiles,\%emptyHash,"  ");
  
  if (@parameters == 0)
  {
      echoPrint("  + No Options!  Priting default menu\n");
      outputMenu($feed_begin, $feed_item, $feed_end);
      exit 0;
  }
  
  if (exists $optionsHash{lc("url")})
  {
      $feedTitle = $urlToFeedTitle{$optionsHash{lc("url")}};
  
      $content = decode('UTF-8', get $optionsHash{lc("url")});
      $content =~ s/&amp;/&/g;
      $content =~ s/&quot;/&/g;
      $regExGroups   = '(http://www.archive.org/download/[^"]*)';
      $regExGroups   = '(table.*?(youtube.com\/watch?|archive.org|www.dailymotion.com\/(video|user)).*?/table)';
      $regExMovies   = 'http://www.archive.org/download/[^"]*';
      $regExYoutube      = 'http://www.youtube.com/watch?[^"]*';
      $regExDailyMotion  = 'http://www.dailymotion.com/(video|user)/[^"]*';
      $regExTitle        = 'Movie #[0-9]+">([^<]*)';
      $regExDesc     = 'class="blah" valign="top">(.*)</td>';
      $regExThumb     = 'http://media.tasvideos.org/[^"]*png';
      
      my @items = ();
      
      $rv = matchShortest($content,$regExGroups);
    
      while (!($rv eq ""))
      {       
          $thr1 = threads->create(\&processBlock, $rv);
          #push(@items,processBlock($rv));
          $content =~ s/\Q$rv\E//gsm;
          $rv = matchShortest($content,$regExGroups);
          @threads = threads->list();
      
          # Wait for threads to finish
          if (threads->list() > 20)
          {
              while (threads->list() > 15)
              {
                  # Wait for threads to finish
                  foreach my $thr (threads->list(threads::joinable)) 
                  {
                      #push(@items,$thr->join());
                      $item = $thr->join();
                      $item =~ /&&&&&/sm;
                      push(@items,$`);
                      echoPrint("! Thread Finished (".threads->list().") :  $' \n");
                  }
              }
          }
          
      }
    
      # Wait for threads to finish
      while (threads->list())
      {
          # Wait for threads to finish
          foreach my $thr (threads->list(threads::joinable)) 
          {
                #push(@items,$thr->join());
                $item = $thr->join();
                $item =~ /&&&&&/sm;
                push(@items,$`);
                echoPrint("! Thread Finished (".threads->list().") :  $' \n");
          }
      }
    
      
      #my ($feed_begin, $feed_item, $feed_end, $textOnlyDescription) = populateFeedStrings();
      $opening = $feed_begin;
      $opening =~ s/%%FEED_TITLE%%/$feedTitle/g;
      $opening =~ s/%%FEED_DESCRIPTION%%/$codeVersion @ARGV/g;
      print encode('UTF-8', $opening);
      foreach (@items)
      {
          if (!($_ eq ""))
          {
              print encode('UTF-8', $_);
          }
      }  
      print encode('UTF-8', $feed_end);
  }
  else
  {
      echoPrint("  ! No /url specificed, leaving blank\n");    
  }
  
  my ( $finishSecond, $finishMinute, $finishHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();
  
  # handle negative times
  if ( $finishSecond < $startSecond )
  {
      $finishSecond += 60;
      $finishMinute--;
  }
  if ( $finishMinute < $startMinute )
  {
      $finishMinute += 60;
      $finishHour--;
  }
  if ( $finishHour < $startHour )
  {
      $finishHour += 24;
  }

  $durHour = sprintf( "%02d", ( $finishHour - $startHour ) );
  $durMin  = sprintf( "%02d", ( $finishMinute - $startMinute ) );
  $durSec  = sprintf( "%02d", ( $finishSecond - $startSecond ) );
  my $transcodeTime = $durHour . ":" . $durMin . ":" . $durSec;
  echoPrint("  + Finished in ($transcodeTime)\n");
  

  sub processBlock
  {
      my ($block) = shift(@_);
      my ($title, $desc, $thumbnail, $video, $newItem);
      my ($content_type, $document_length, $modified_time, $expires, $server);
      
      # Get Start Time
      my ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();
    
          
      if ($block =~ /$regExYoutube/sm)
      {
          ($video , $content_type) = youtube($&);
      } 
      elsif ($block =~ /$regExDailyMotion/sm)
      {
          $video = dailyMotion($&);
      }          
      elsif ($block =~ /$regExMovies/sm)
      {
          $video = $&;
      }
      
      if ($block =~ /$regExTitle/sm)
      {
          $title = $1;
          #echoPrint("+ Analyzing: $title ($video)\n"); 
      }
      
      if ($block =~ /$regExThumb/sm)
      {
          $thumbnail = $&;
      }

      if ($block =~ /$regExDesc/sm)
      {
          $desc = $1;
          $desc =~ s/<[^>]*>//gsm;
          $desc =~ s/\n/ /gsm;
      }
    
        
      if (!($video eq ""))
      {
          if ($content_type eq "")
          {
              if ($video =~ /youtube/i)
              {
                  $semaphoreYoutube->down();    
              }
              elsif ($video =~ /dailymotion/i)
              {
                  $semaphoreDailyMotion->down(); 
              }
              else
              {
                  $semaphoreGeneric->down();
              }
              ($content_type, $document_length, $modified_time, $expires, $server) = head($video);
              if ($video =~ /youtube/i)
              {
                  $semaphoreYoutube->up();    
              }
              elsif ($video =~ /dailymotion/i)
              {
                  $semaphoreDailyMotion->up(); 
              }
              else
              {
                  $semaphoreGeneric->up();
              }              
              #$content_type = 'video/mp4'
          }
      
          $newItem   = $feed_item;
      
          my $videoXML       = toXML($video);
          my $titleXML       = $title;
          my $descriptionXML = $desc;
          my $thumnailXML    = toXML($thumbnail);
          
          $newItem =~ s/%%ITEM_TITLE%%/$titleXML/g;
          $newItem =~ s/%%ITEM_DATE%%/$dateXMLString/g;
          $newItem =~ s/%%ITEM_DESCRIPTION%%/$descriptionXML/g;
          $newItem =~ s/%%ITEM_URL%%/$videoXML/g;
          $newItem =~ s/%%ITEM_DUR%%//g;
          $newItem =~ s/%%ITEM_SIZE%%/$document_length/g;
          $newItem =~ s/%%ITEM_TYPE%%/$content_type/g;
          $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
          $newItem =~ s/%%ITEM_DUR_SEC%%//g;       
      }

      
      # Get Finish Time
      my ( $finishSecond, $finishMinute, $finishHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();
  
      # handle negative times
      if ( $finishSecond < $startSecond )
      {
          $finishSecond += 60;
          $finishMinute--;
      }
      if ( $finishMinute < $startMinute )
      {
          $finishMinute += 60;
          $finishHour--;
      }
      if ( $finishHour < $startHour )
      {
          $finishHour += 24;
      }
  
      $durHour = sprintf( "%02d", ( $finishHour - $startHour ) );
      $durMin  = sprintf( "%02d", ( $finishMinute - $startMinute ) );
      $durSec  = sprintf( "%02d", ( $finishSecond - $startSecond ) );
      my $transcodeTime = $durHour . ":" . $durMin . ":" . $durSec;
       
      return sprintf($newItem."&&&&& %-50s (%9s) (%s)",$title,$transcodeTime,$video);
  }

   ##### Youtube Decoding
    sub youtube
    {
        my ($url) = @_;
        return ($url,'video/mp4');   # to disbable youtube decoding
        #echoPrint("    + Decoding Youtube ($url)\n");
        $semaphoreYoutube->down();
        my $content = decode('UTF-8', get $url);
        #sleep(1);
        $semaphoreYoutube->up();
        my $videoIDRegEx = '"video_id": "([^"]*)"';
        my $videoTRegEx = '"t": "([^"]*)"';
      
        
        $content =~ /$videoIDRegEx/;
        my $videoID = $1;
        
        $content =~ /$videoTRegEx/;
        my $videoT = $1;
        
        my $videoURLBase = 'http://www.youtube.com/get_video?video_id='.$videoID.'&t='.$videoT;
 
        $videoURLBase =~ s/%2F/\//g;
        $videoURLBase =~ s/%3F/?/g;
        $videoURLBase =~ s/%3D/=/g;
        $videoURLBase =~ s/%40/@/g;
        $videoURLBase =~ s/%3A/:/g;
        
        my @youtubeQualities = (37,35,34,22,18,6);
        
        #echoPrint("      - Found : $videoURL\n");

        my $videoURL  = $videoURLBase;
        foreach (@youtubeQualities)
        {
            #echoPrint("        + Quality : $_\n");
            #echoPrint("          - Link         : ".$videoURLBase.'&fmt='.$_."\n");
            $semaphoreYoutube->down();
            my ($content_type, $document_length, $modified_time, $expires, $server) = head($videoURLBase.'&fmt='.$_); 
            $semaphoreYoutube->up(); 
            #echoPrint("          - Content Type : ($content_type)\n");
            #echoPrint("          - Length       : ($document_length)\n");
            if (!($content_type eq ""))
            {
                $videoURL = $videoURLBase.'&fmt='.$_;
                last;  
            }
        }        
        return ($videoURL,$content_type);
    }

   ##### DailyMotion Decoding
    sub dailyMotion
    {
        my ($url) = @_;
        #echoPrint("    + Decoding DailyMotion ($url)\n");
        $semaphoreDailyMotion->down();
        my $content = decode('UTF-8', get $url);
        #sleep(1);
        $semaphoreDailyMotion->up();
        my $videoRegEx = 'addVariable\("video", "([^"]*)';
        
        $content =~ /$videoRegEx/;
        $videoURLs = $1;
        $videoURLs =~ s/%2F/\//g;
        $videoURLs =~ s/%3F/?/g;
        $videoURLs =~ s/%3D/=/g;
        $videoURLs =~ s/%40/@/g;
        $videoURLs =~ s/%3A/:/g;
        
        #echoPrint("      - Found : ($videoURL)\n");

        my @resolutions = split(/%7C%7C/,$videoURLs);
        
        my $biggest  = 0;
        my $size     = 0;
        my $videoURL = "";
        foreach (@resolutions)
        {
            #echoPrint("        + Quality : ($_)\n");
            if (/([0-9]+)x([0-9]+)/)
            {
                #echoPrint("        + Size : ($&)\n");
                $size = $1 * $2;
                if ($size > $biggest)
                {
                    $videoURL = $_;
                }
            }
        }
             
        return $videoURL;
    }
  
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
    
    sub matchShortest
    {
        my ($string,$regEx,$rvRef) = @_;
        my $shortest;
        my $length = length $string;
        my $i = 0;
        
        while ($string =~ /(?=$regEx)/gsm) {
            $i++;
            $m_len = length $1;
            # save the match if it's shorter than the last one
            ($shortest, $length) = ($1, $m_len) if $m_len < $length;
            last;
        }
        $$rvRef = $shortest;
        return $shortest;
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
    <title><![CDATA[%%FEED_TITLE%%]]></title> 
    <description><![CDATA[$codeVersion @ARGV]]></description> 
    <language>en-us</language> 
    <itunes:summary><![CDATA[%%FEED_DESCRIPTION%%]]></itunes:summary> 
    <itunes:subtitle><![CDATA[%%FEED_DESCRIPTION%%]]></itunes:subtitle> 
FEED_BEGIN

    my $feed_item = <<'PODCAST_ITEM';
    <item> 
      <title><![CDATA[%%ITEM_TITLE%%]]></title> 
      <description><![CDATA[%%ITEM_DESCRIPTION%%]]></description> 
      <itunes:subtitle><![CDATA[%%ITEM_DESCRIPTION%%]]></itunes:subtitle>
      <itunes:duration>%%ITEM_DUR%%</itunes:duration>
      <enclosure url="%%ITEM_URL%%" length="%%ITEM_SIZE%%" type="%%ITEM_TYPE%%" /> 
      <media:content duration="%%ITEM_DUR_SEC%%" medium="video" fileSize="%%ITEM_SIZE%%" url="%%ITEM_URL%%" type="%%ITEM_TYPE%%"> 
       <media:title><![CDATA[%%ITEM_TITLE%%]]></media:title> 
        <media:description><![CDATA[%%ITEM_DESCRIPTION%%]]></media:description> 
        <media:thumbnail url="%%ITEM_PICTURE%%"/> 
      </media:content> 
    </item> 
PODCAST_ITEM

    my $feed_end = <<'FEED_END';
  </channel> 
</rss> 
FEED_END

    return ($feed_begin, $feed_item, $feed_end);
  }
  
  
    #$url     = 'http://tasvideos.org/Movies-RatingY-Rec.html';
  #$url     = 'http://tasvideos.org/Movies-NES-FDS.html';
  #$url     =  'http://tasvideos.org/Movies-SNES.html';
  #$url     = 'http://tasvideos.org/Movies-GBA.html';
  #$url = 'http://tasvideos.org/Movies-DS.html';
  

  sub outputMenu
  {
      my ($feed_begin, $feed_item, $feed_end) = @_;
      my @items = ();
      my $newItem,$video,$title,$description,$type,$thumbnail;
      my $opening;
      
      my @tasURLS = 
             ( {url   => 'http://tasvideos.org/Movies-RatingY-Rec.html',
                title => 'Recommended Videos',
                desc  => 'Recommended videos from all systems',
                thumbnail =>'http://docs.google.com/uc?id=0B_sMJcYiGvN4MDE1MjFlYmUtZWMwMS00OWJlLTg0ZjctNDRmMDQ5NjU2MDI5&export=download&hl=en'},
                
               {url   => 'http://tasvideos.org/Movies-NES-FDS.html',
                title => 'NES',
                desc  => 'Tool assisted speedrun videos for NES',
                thumbnail =>'http://docs.google.com/uc?id=0B_sMJcYiGvN4NjMyMWVmMTAtMTM5Ny00ZTM3LTg2YjctNWI2YTQ4NWUzNmQy&export=download&hl=en'},
                
               {url   => 'http://tasvideos.org/Movies-SNES.html',
                title => 'SNES',
                desc  => 'Tool assisted speedrun videos for SNES',
                thumbnail =>'http://docs.google.com/uc?id=0B_sMJcYiGvN4ZGE0MjIxY2UtMTc0NS00NDI3LWEzODYtOGIwNGUzMGNhNjQ5&export=download&hl=en'},                              
                
               {url   => 'http://tasvideos.org/Movies-N64.html',
                title => 'N64',
                desc  => 'Tool assisted speedrun videos for N64',
                thumbnail =>'http://docs.google.com/uc?id=0B_sMJcYiGvN4MjFkYmRkZWUtMzJiMy00MzE3LTlmODgtYWYzY2EzYjk1MmIw&export=download&hl=en'},
              
               {url   => 'http://tasvideos.org/Movies-GBA.html',
                title => 'Gameboy',
                desc  => 'Tool assisted speedrun videos for Gameboy',
                thumbnail =>'http://docs.google.com/uc?id=0B_sMJcYiGvN4OWY1YmJkZjctNzE2My00NDVmLTliYTctNzg4MTRlMGVkNDA3&export=download&hl=en'},
               
               {url   => 'http://tasvideos.org/Movies-DS.html',
                title => 'DS',
                desc  => 'Tool assisted speedrun videos for DS',
                thumbnail =>'http://docs.google.com/uc?id=0B_sMJcYiGvN4NTMxYjllZmUtZDQ1Ny00NzdmLTljY2UtMTVjNDZlYjQ1NjQx&export=download&hl=en'},
                
              {url   => 'http://tasvideos.org/Movies-Genesis-32X-SegaCD.html',
                title => 'Sega',
                desc  => 'Tool assisted speedrun videos for Sega',
                thumbnail =>'http://docs.google.com/uc?id=0B_sMJcYiGvN4MDFlMWU0MzctYzU5ZS00MWM2LTg5OTUtMzgwMDgxZDJiMjA1&export=download&hl=en'},
          
              {url   => 'http://tasvideos.org/Movies-Saturn.html',
                title => 'Saturn',
                desc  => 'Tool assisted speedrun videos for Saturn',
                thumbnail =>'http://docs.google.com/uc?id=0B_sMJcYiGvN4NTkwMDg5NTktMTNjOC00MzkxLTlhZjktMzU4ZjBhOGM2MGM2&export=download&hl=en'},
                
              {url   => 'http://tasvideos.org/Movies-PSX.html',
                title => 'Playstation',
                desc  => 'Tool assisted speedrun videos for Playstation',
                thumbnail =>'http://docs.google.com/uc?id=0B_sMJcYiGvN4MDI4ZTFjYjAtOTIzYy00NDZjLThlZDItNWRiYjUxMWFiYjdi&export=download&hl=en'},
                
              {url   => 'http://tasvideos.org/Movies-Arcade.html',
                title => 'Arcade',
                desc  => 'Tool assisted speedrun videos for Arcade',
                thumbnail =>'http://docs.google.com/uc?id=0B_sMJcYiGvN4MTkxM2VmYjQtNTc5YS00MzRlLWFkZGEtYTgxYzgxZDJjMTA1&export=download&hl=en'},
                
              {url   => 'http://tasvideos.org/Movies-Hacks.html',
                title => 'Special Runs',
                desc  => 'Tool assisted speedrun videos for Special Runs',
                thumbnail =>'http://docs.google.com/uc?id=0B_sMJcYiGvN4MDM2ZjJiZmItZjNjNS00MmQwLWFjOWQtOWQ4M2ZmNGI5NTZi&export=download&hl=en'}
                

              );
      
      $opening = $feed_begin;
      $opening =~ s/%%FEED_TITLE%%/Tool Assisted Speedruns/g;
      $opening =~ s/%%FEED_DESCRIPTION%%/Tool Assisted Speedruns/g;
      
      foreach $urlHashRef (@tasURLS)
      {
          $newItem = $feed_item;
          $video             = toXML('external,"'.$executable.'",/url||'.$urlHashRef->{url});
          $title             = $urlHashRef->{title};
          $description       = $urlHashRef->{desc};
          $thumbnail         = toXML($urlHashRef->{thumbnail});
          $type              = 'sagetv/subcategory';
          
          $newItem =~ s/%%ITEM_TITLE%%/$title/g;
          $newItem =~ s/%%ITEM_DATE%%/$dateXMLString/g;
          $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
          $newItem =~ s/%%ITEM_URL%%/$video/g;
          $newItem =~ s/%%ITEM_DUR%%/1/g;
          $newItem =~ s/%%ITEM_SIZE%%/1/g;
          $newItem =~ s/%%ITEM_TYPE%%/$type/g;
          $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
          $newItem =~ s/%%ITEM_DUR_SEC%%/1/g; 
          push(@items,$newItem);            
      }
            
      print encode('UTF-8', $opening);
      foreach (@items)
      {
          if (!($_ eq ""))
          {
              print encode('UTF-8', $_);
          }
      }  
      print encode('UTF-8', $feed_end);
  }
  
  sub toXML
  {
      my ($string) = @_;
      $string =~ s/\&/&amp;/g;
      $string =~ s/"/&quot;/g; #"
      $string =~ s/</&lt;/g;
      $string =~ s/>/&gt;/g;
      $string =~ s/'/&apos;/g;  #'
      return $string;
  }
  
  exit;

      
      
  
  
  
  
