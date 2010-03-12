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
  use Net::UPnP::ControlPoint;
  use Net::UPnP::AV::MediaServer;
  
  my $obj = Net::UPnP::ControlPoint->new();
  my $mediaServer = Net::UPnP::AV::MediaServer->new();    
  
  $ua->timeout(30);
  $ua->agent( 'Mozilla/4.0 (compatible; MSIE 5.12; Mac_PowerPC)' );
  
  my $debug = 0;

  # Get the directory the script is being called from
  $executable = $0;
  $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;
  $executablePath = $`;
  $executableEXE  = $3; 
   
  open(LOGFILE,">$executablePath\\$executableEXE.log");

  # Get Start Time
  my ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();

  # Code version
  my $codeVersion = "$executableEXE v1.0 (SNIP:BUILT)".($debug ? "(debug)" : "");
  
  my $invalidMsg .= "\n$codeVersion\n";
  $invalidMsg .= "\tUSAGE:";
  $invalidMsg .= "\t$executableEXE.exe /profile <Profile name>\n\n";

  my ($feed_begin, $feed_item, $feed_end) = populateFeedStrings();

  echoPrint("Welcome to $codeVersion!\n");
  echoPrint("  + Path: $executablePath\n");

  # Check Versions
  if (open(PROPERTIES,"$executablePath\\Sage.properties"))
  {
      while (<PROPERTIES>)
      {
          chomp;
          if (/^stv_update\/last_version_in_sys_msg=/)
          {
              $stvVersions = $';
          }
    
          if (/^version=/)
          {
              $sageVersion = $';
          }          
      }
      close(PROPERTIES);
      echoPrint("  + SageTV Version: ($sageVersion)\n");
      echoPrint("    - STV Version : ($stvVersions)\n");
  }
  else
  {
      echoPrint("  ? Warning: Couldn't open ($executablePath\\sage.properties)\n");    
  }

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
  
  if (@parameters == 0)
  {
      echoPrint("  + No Options!  Printing available UPnP Servers\n");
      my @dev_list = $obj->search(st =>'upnp:rootdevice', mx => 1);
      my $opening;
      my @items = ();
      my $newItem,$video,$title,$description,$type,$thumbnail;
  
      $opening = $feed_begin;
      $opening =~ s/%%FEED_TITLE%%/UPnP Browser/g;
      $opening =~ s/%%FEED_DESCRIPTION%%/UPnP Browser/g;
      
      foreach (@dev_list)
      {
          if ($_->getfriendlyname() eq "")
          {
              next;
          }
          $newItem = $feed_item;
          $video             = toXML('external,"'.$executable.'",/device||'.$_->getfriendlyname()."||/uid||0||/path||".$_->getfriendlyname());
          $title             = $_->getfriendlyname();
          $description       = $_->getfriendlyname();
          $thumbnail         = '';
          $type              = 'sagetv/subcategory';
          
          $newItem =~ s/%%ITEM_TITLE%%/$title/g;
          $newItem =~ s/%%ITEM_DATE%%//g;
          $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
          $newItem =~ s/%%ITEM_URL%%/$video/g;
          $newItem =~ s/%%ITEM_DUR%%//g;
          $newItem =~ s/%%ITEM_SIZE%%//g;
          $newItem =~ s/%%ITEM_TYPE%%/$type/g;
          $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
          $newItem =~ s/%%ITEM_DUR_SEC%%//g; 
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
      exit 0;
  }

  
  if (exists $optionsHash{lc("device")})
  {
      my $lookingFor = $optionsHash{lc("device")};
      echoPrint("  + Looking for UPnP Server: ".$lookingFor."\n");
      if (-s "$executablePath\\$lookingFor.cache")
      {
          echoPrint("    - Found Cache ($executablePath\\$lookingFor.cache)\n");
          if (open(UPNPCACHE,"$executablePath\\$executableEXE.$lookingFor.cache"))
          {
              $foundDevice = 1;
              @cacheFull = <UPNPCACHE>;
              $cacheText  = "@cacheFull";
              $cacheText  =~ /=======================/;
              $res_msg = $`;
              $post_con = $';
              $dev = Net::UPnP::Device->new();              
   		        $dev->setssdp($cacheText);
  		        $dev->setdescription($post_con);
  		        $mediaServer->setdevice($dev);
          }
          close(UPNPCACHE);
      }
      else
      {
          my @dev_list = $obj->search(st =>'upnp:rootdevice', mx => 1);
          foreach (@dev_list)
          {
              chomp;
              echoPrint("    - Device: ".$_->getfriendlyname()."(".$_->getdevicetype().")\n");
              if ($_->getfriendlyname() =~ /\Q$lookingFor\E/i)
              {
                  $dev = $_;
                  if (open(UPNPCACHE,">$executablePath\\$executableEXE.$lookingFor.cache"))
                  {
                      print UPNPCACHE $dev->getssdp()."=======================".$dev->getdescription();
                  }
                  close(UPNPCACHE);
                  $foundDevice = 1;
                  echoPrint("      + Found $lookingFor\n"); 
                  $mediaServer->setdevice($dev);
                  last;
              }
          }
      }
      
      if (!$foundDevice)
      {
          echoPrint("  ! Error! Couldn't find UPnP Device: ($lookingFor)\n");
          my $opening;
          my @items = ();
          my $newItem,$video,$title,$description,$type,$thumbnail;
      
          $opening = $feed_begin;
          $opening =~ s/%%FEED_TITLE%%/UPnP Browser (Error!)/g;
          $opening =~ s/%%FEED_DESCRIPTION%%/UPnP Browser (Error!)/g;
          
          $newItem = $feed_item;
          $video             = toXML('external,"'.$executable.'",/device||'.$_->getfriendlyname()."||/uid||0");
          $title             = "UPnP Browser Error!";
          $description       = "UPnP Browser Error!  Unable to find UPnP Device ($lookingFor)";
          $thumbnail         = '';
          $type              = 'sagetv/textonly';
          
          $newItem =~ s/%%ITEM_TITLE%%/$title/g;
          $newItem =~ s/%%ITEM_DATE%%//g;
          $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
          $newItem =~ s/%%ITEM_URL%%/$video/g;
          $newItem =~ s/%%ITEM_DUR%%//g;
          $newItem =~ s/%%ITEM_SIZE%%//g;
          $newItem =~ s/%%ITEM_TYPE%%/$type/g;
          $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
          $newItem =~ s/%%ITEM_DUR_SEC%%//g; 
          push(@items,$newItem);            

          print encode('UTF-8', $opening);
          foreach (@items)
          {
              if (!($_ eq ""))
              {
                  print encode('UTF-8', $_);
              }
          }  
          print encode('UTF-8', $feed_end);         
          exit 0;
      }
      
      if (exists $optionsHash{lc("uid")} && $foundDevice == 1)
      {
          
          my @content_list = ();
          my $id = $optionsHash{lc("uid")};
          echoPrint("  + Looking for UID: ($id)\n");
          @content_list = $mediaServer->getcontentlist(ObjectID => $id);
          if ($content_list[0] =~ /^!!/)
          {
              echoPrint("    - Error UID invalid, trying full path search\n");
              exit 0;
          }
          else
          {
            echoPrint("    - Found UID ($id), outputing directory\n");
            my $opening;
            my @items = ();
            my $newItem,$video,$title,$description,$type,$thumbnail;
        
            $opening = $feed_begin;
            $opening =~ s/%%FEED_TITLE%%/UPnP Browser ($lookingFor)/g;
            $opening =~ s/%%FEED_DESCRIPTION%%/UPnP Browser ($lookingFor)/g;

            foreach (@content_list)
            {
                if ($_->iscontainer())
                {     
                    $newItem = $feed_item;
                    $video             = toXML('external,"'.$executable."\",/device||$lookingFor||/uid||".$_->getid()."||/path||".$optionsHash{lc("path")}."\\".$_->gettitle());
                    $title             = $_->gettitle();
                    $description       = $optionsHash{lc("path")}."\\".$_->gettitle();
                    $thumbnail         = '';
                    $type              = 'sagetv/subcategory';
                    
                    if ($optionsHash{lc("path")} =~ /hulu.*networks$/i)
                    {
                      	$networkHuluBanner = $title;
                    		$networkHuluBanner =~ s/&//g;
                    		$networkHuluBanner =~ s/[ \-]/_/g;
                    		$networkHuluBanner =~ s/[.:'`"!]//g; #"
                    		$thumbnail = toXML("http://assets.hulu.com/companies/company_thumbnail_".lc($networkHuluBanner).".jpg");                    
                    }
                    elsif ($optionsHash{lc("path")} =~ /hulu/i)
                    {   # Try and drop in show thumbnails in Hulu, there's gotta be a better way to handle this
                    		$showHuluBanner = $title;
                    		$showHuluBanner =~ s/&/and/g;
                    		$showHuluBanner =~ s/[ \-]/_/g;
                    		$showHuluBanner =~ s/[.:'`"!\\\/]//g; #"
                    		$thumbnail = toXML("http://assets.hulu.com/shows/show_thumbnail_".lc($showHuluBanner).".jpg");
                    }
                    
                    $newItem =~ s/%%ITEM_TITLE%%/$title/g;
                    $newItem =~ s/%%ITEM_DATE%%//g;
                    $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
                    $newItem =~ s/%%ITEM_URL%%/$video/g;
                    $newItem =~ s/%%ITEM_DUR%%//g;
                    $newItem =~ s/%%ITEM_SIZE%%//g;
                    $newItem =~ s/%%ITEM_TYPE%%/$type/g;
                    $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
                    $newItem =~ s/%%ITEM_DUR_SEC%%//g; 
                    push(@items,$newItem);
                }
                elsif ($_->isitem())
                {
                    my $newItem = $feed_item;
                    my $content = $_;
                    my $id    = $content->getid();
                    my $title = $content->gettitle();
                    my $video = toXML($content->geturl());
                    my $size  = $content->getSize();
                    my $date  = $content->getdate();
                    my $rating      = $content->getRating();
                    my $userRating  = $content->getUserRating();
                    my $dur  = $content->getDur();
                    my $thumbnail  = toXML($content->getPicture());
                    my $description = $content->getDesc();
                    my $type = 'video/mpeg2';
            
                    if ($title =~ /s([0-9]+)e([0-9]+): (.*)/)
                    {
                        my $season  = $1;
                        my $episode = $2;
                        my $episodeTitle = $3;
                        $description        = "Season $season Episode $episode - $description"; 
                        $title = $episodeTitle;
                    }
                    
                    $dur    =~ /([0-9]+):([0-9]+):([0-9]+).([0-9]+)/;
                    my $durTotalSec = $1*60*60 + $2*60 + $3;
                    my $durTotalMin = $durTotalSec/60;
                    
                    if ($url =~ /(hulu|cbs)/i)
                    {   # Roughly Account for commercials
                        while($durTotalMin > 0)
                        {
                            $durTotalMin -= 7;
                            $durTotalSec += 30;    
                        }  
                    }
                    
                    my $durDisSec  = $durTotalSec;
                    my $durDisMin  = 0;
                    my $durDisHour = 0;
                    
                    while ($durDisSec > 60)
                    {
                        $durDisSec -= 60;
                        $durDisMin   += 1;
                        if ($durDisMin == 60)
                        {
                            $durDisHour += 1;
                            $durDisMin   = 0;
                        }
                    }
            
                    my $durDisplay = sprintf("%02d:%02d:%02d", $durDisHour, $durDisMin, $durDisSec);       
                    
                    $date  =~ /^(.*)T/;
                    $date  = $1;                    
                    
                    $newItem =~ s/%%ITEM_TITLE%%/$title/g;
                    $newItem =~ s/%%ITEM_DATE%%/$date/g;
                    $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
                    $newItem =~ s/%%ITEM_URL%%/$video/g;
                    $newItem =~ s/%%ITEM_DUR%%/$durDisplay/g;
                    $newItem =~ s/%%ITEM_SIZE%%/$size/g;
                    $newItem =~ s/%%ITEM_TYPE%%/$type/g;
                    $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
                    $newItem =~ s/%%ITEM_DUR_SEC%%/$durTotalSec/g;
                    push(@items,$newItem);                
                } 
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
            exit 0;  
          }               
      }     
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
      <pubDate>%%ITEM_DATE%%</pubDate> 
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

      
      
  
  
  
  
