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
  use LWP::Simple;
  use MD5;
  
  my $debug = 1;

  # Get the directory the script is being called from
  my $executable = $0;
  $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;
  my $executablePath = $`;
  my $executableEXE  = $3; 
  

  my $fLOGFILE;  
  if ($debug)
  {
    $fLOGFILE = stderr;
  }
  else
  {
      open($fLOGFILE,">$executablePath\\$executableEXE.log");  
  }

  # Code version
  my $codeVersion = "$executableEXE v1.5".($debug ? "(debug)" : "");
  
  my $invalidMsg .= "\n$codeVersion\n";
  $invalidMsg .= "\tUSAGE:";
  $invalidMsg .= "\t$executableEXE.exe (Quicktime Search String)\n\n";

  # Move arguments into user array so we can modify it
  my @parameters = @ARGV;

  my ($feed_begin, $item, $fakeItem, $feed_end) = populateFeedStrings();

  print $fLOGFILE "Welcome to $codeVersion!\n";
  print $fLOGFILE "  + Path: $executablePath\n";
  print $fLOGFILE "  + Parameters\n";
  foreach (@parameters)  
  {
      print $fLOGFILE "    - ($_)\n";  
  }
  
  my $podcastFeed  = "";
  my %podcastItems = ();
  my $opening      = ""; 

  my $userInput = $parameters[0]; 
  my @searchStrings = split("&&",$userInput);
            
  foreach (@searchStrings)    
  {
      print $fLOGFILE "  + Search String: $_\n"; 
      my @splitString = split(":",$_);   
      
      my %contents = {};
      my $error    = 0;
      my $dirPath  = "";
      
      my $lookingFor = shift(@splitString);
      my $foundDevice = 0;
      
      if ($lookingFor =~ /quicktime/i)
      {
          quickTimeTrailers();
      }
      # Placeholder for UPnP stuff
  }

    if ($opening eq "")
    {
        $opening  = $feed_begin;
        $opening  =~ s/%%FEED_TITLE%%/No Videos Found/sg;
        $opening  =~ s/%%FEED_DESCRIPTION%%/No Videos Found/sg;    
    }

    $podcastFeed .= $opening;        
    
    if (keys %podcastItems)
    {
        foreach (sort { lc($a) cmp lc($b) } keys %podcastItems)
        {  # sort hashes alphabetically
            $podcastFeed .= $podcastItems{$_};
        }
        updateRecentPodcasts($executablePath,$parameters[0]);
    }
    else
    {   # If no videos were found
        my $failureDescription = "No videos found for UPnP search string ($parameters[0]).  Since online videos are constantly being added and removed this could mean that there are just no videos available at this time. (This message is from the UPnP2Podcast Plug-in)";
        $fakeItem =~ s/%%ITEM_TITLE%%/No Videos Found/g;
        $fakeItem =~ s/%%ITEM_DESCRIPTION%%/$failureDescription/g;   
        $podcastFeed .= $fakeItem;    
    }

    $podcastFeed .= $feed_end;

    print encode("utf8", $podcastFeed); 
    
    if (!$debug)
    { 
        print $fLOGFILE "<----------------- Feed ------------------>\n";
        print $fLOGFILE encode("utf8", $podcastFeed);
    }
 
     sub addItem {
        my ($content) = @_;
        my $id    = $content->getid();
        my $title = decode('utf8' ,$content->gettitle());
        my $url   = $content->geturl();
        my $size  = $content->getSize();
        my $date  = $content->getdate();
        my $rating      = $content->getRating();
        my $userRating  = $content->getUserRating();
        my $dur  = $content->getDur();
        my $screenShot  = $content->getPicture();
        my $desc = decode('utf8' ,$content->getDesc());
        my $newItem = $item;

        if ($title =~ /s([0-9]+)e([0-9]+): (.*)/)
        {
            my $season  = $1;
            my $episode = $2;
            my $episodeTitle = $3;
            $newItem =~ s/%%ITEM_DESCRIPTION%%/Season $season Episode $episode - $desc/sg; 
            $newItem =~ s/%%ITEM_TITLE%%/$episodeTitle/sg;
        }
        else
        {
            $newItem =~ s/%%ITEM_DESCRIPTION%%/$desc/sg;
            $newItem =~ s/%%ITEM_TITLE%%/$title/sg;     
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
        
        $newItem =~ s/%%ITEM_URL%%/$url/sg;
        $newItem =~ s/%%ITEM_SIZE%%/$size/sg;
        $newItem =~ s/%%ITEM_DATE%%/$date/sg;
        $newItem =~ s/%%ITEM_PICTURE%%/$screenShot/sg;
        $newItem =~ s/%%ITEM_DUR_SEC%%/$durTotalSec/sg;
        $newItem =~ s/%%ITEM_DUR%%/$durDisplay/sg;
        
        $podcastItems{lc($title)} = $newItem;
    }
    
    sub getTheTime()
    {
        #($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
        #$year = 1900 + $yearOffset;
        #$theTime = "$hour:$minute:$second: ";
        return "";#$theTime;
    }

  sub quickTimeTrailers()
  {
    my ($searchString, $debug, $fLOGFILE) = @_;
    # URL of file containing feed versions
    my $alltrailers = 'http://www.apple.com/trailers/home/feeds/genres.json';
    my $origContent = get $alltrailers;
    $origContent =~ s/(\r|\n)//g;
    $workingContent = $origContent;
    @allTrailers = split(/\}\]\}/,$workingContent);
    foreach (@allTrailers)
    {
        if (/"title":"([^"]*)"/) #"
        {
            $title = $1;
            print "  + Title: $title\n";
        }
        if (/"releasedate":"([^"]*)"/) #"
        {
            $releaseDate = $1; 
            $releaseDate =~ / 00:/;
            $releaseDate = $`;
            print "    - Release Date: $releaseDate\n";
        }
        if (/"studio":"([^"]*)"/) #"
        {
            $studio = $1; 
            print "    - Studio      : $studio\n";
        }
        if (/"poster":"([^"]*)"/) #"
        {
            $poster = $1; 
            print "    - Poster      : $poster\n";
        }
        if (/"rating":"([^"]*)"/) #"
        {
            $rating = $1;
            print "    - Rated       : $rating\n";
        }
        if (/"actors":\[([^\]]*)\]/) #"
        {
            $actors = $1;
            $actors =~ s/"//g; #"
            $actors =~ s/,/, /g; #"
            print "    - Actors      : $actors\n";
        }
        if (/"genre":\[([^\]]*)\]/) #"
        {
            $genres = $1;
            $genres =~ s/"//g; #"
            $genres =~ s/,/, /g; #"
            print "    - Genres      : $genres\n";
        }
        if (/"location":"([^"]*)"/) #"
        {
            my $trailerPageURL = "http://www.apple.com$1";
            print "    - Trailer Page: $trailerPageURL\n";
            my $trailerPageContent = get $trailerPageURL;
            my $trailerCount = 0;
            @trailerPageLines = split(/>/,$trailerPageContent) ;
            foreach (@trailerPageLines)
            {
                chomp;
                if (/meta name="Description" content="(.*)"/) #"
                {
                    $description = $1;
                    print "      + Description : $description\n"; 
                }
                if (/http[^"]*\.mov/) #"
                {
                    if ($sizes == 1)
                    {   # Pair sizes with Trailers
                        while (@foundSizes)
                        {
                            print "      + " . pop(@foundSizes) . " MB : ". pop(@foundTrailers) ."\n";   
                        }
                    }
                    #print "      + $&\n"; 
                    push(@foundTrailers,$&);
                    $trailerCount++;   
                }
                if (/([0-9]+) MB/) #"
                {
                    push(@foundSizes,$1);
                    #print "      + $&\n"; 
                    $sizes = 1;
                }
            } 
            if ($trailerCount == 0)
            {
                $trailerPageContent = get $trailerPageURL."/hd/";
                @trailerPageLines = split(/>/,$trailerPageContent);
                $sizes = 0;
                foreach (@trailerPageLines)
                {
                    chomp;
                    if (/meta name="Description" content="(.*)"/) #"
                    {
                        $description = $1;
                        print "      + Description : $description\n"; 
                    }
                    if (/http[^"]*\.mov/) #"
                    {
                        if ($sizes == 1)
                        {   # Pair sizes with Trailers
                            while (@foundSizes)
                            {
                                print "      + " . pop(@foundSizes) . " MB : ". pop(@foundTrailers) ."\n";   
                            }
                        }
                        #print "      + $&\n"; 
                        push(@foundTrailers,$&);
                        $trailerCount++;   
                    }
                    if (/([0-9]+) MB/) #"
                    {
                        push(@foundSizes,$1);
                        #print "      + $&\n"; 
                        $sizes = 1;
                    }
                }            
            }
           if ($sizes == 1)
            {   # Pair sizes with Trailers
                while (@foundSizes)
                {
                    print "      + " . pop(@foundSizes) . " : ". pop(@foundTrailers) ."\n";   
                }
            }         
        }
        #exit;
        #print "  + $_\n"
    }
    exit;
    return $rv;   
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
#		<image> 
#			<title>%%FEED_IMAGE%%</title> 
#			<url>%%FEED_IMAGE_URL%%</url> 
#		</image> 

    my $item = <<'PODCAST_ITEM';
    <item> 
      <title>%%ITEM_TITLE%%</title> 
      <description>%%ITEM_DESCRIPTION%%</description> 
      <pubDate>%%ITEM_DATE%%</pubDate> 
      <itunes:subtitle>%%ITEM_DESCRIPTION%%</itunes:subtitle>
      <itunes:duration>%%ITEM_DUR%%</itunes:duration>
      <enclosure url="%%ITEM_URL%%" length="%%ITEM_SIZE%%" type="video/mpeg2" /> 
      <media:content duration="%%ITEM_DUR_SEC%%" medium="video" fileSize="%%ITEM_SIZE%%" url="%%ITEM_URL%%" type="video/mpeg2"> 
       <media:title>%%ITEM_TITLE%%</media:title> 
        <media:description>%%ITEM_DESCRIPTION%%</media:description> 
        <media:thumbnail url="%%ITEM_PICTURE%%"/> 
      </media:content> 
    </item> 
PODCAST_ITEM

    my $fakeItem = <<PODCAST_FAKE_ITEM;
   <item> 
      <title>%%ITEM_TITLE%%</title> 
      <description>%%ITEM_DESCRIPTION%%</description> 
      <pubDate>1981-09-15</pubDate> 
      <itunes:subtitle>%%ITEM_DESCRIPTION%%</itunes:subtitle>
      <itunes:duration>00:46:35</itunes:duration>
      <enclosure url="http://127.0.0.1/fake.mpg" length="1668940000" type="video/mpeg2" /> 
      <media:content duration="2795" medium="video" fileSize="1668940000" url="http://127.0.0.1/fake.mpg" type="video/mpeg2"> 
       <media:title>%%ITEM_TITLE%%</media:title> 
        <media:description>%%ITEM_DESCRIPTION%%</media:description> 
        <media:thumbnail url="http://127.0.0.1/fake.jpg"/> 
      </media:content> 
    </item> 
PODCAST_FAKE_ITEM

    my $feed_end = <<'FEED_END';
  </channel> 
</rss> 
FEED_END

    return ($feed_begin, $item, $fakeItem, $feed_end);
  }
    