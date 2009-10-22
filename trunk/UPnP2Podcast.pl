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
  use Net::UPnP::ControlPoint;
  use Net::UPnP::AV::MediaServer;
  
  my $debug = 0;

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
  $invalidMsg .= "\t$executableEXE.exe (UPnP Search String)\n\n";

  # Move arguments into user array so we can modify it
  my @parameters = @ARGV;

  my ($feed_begin, $item, $fakeItem, $feed_end) = populateFeedStrings();
    
  if (!(-e 'tinFoilHat.txt') && (@parameters == 0 || int(rand(4)) == 0))
  {
      print $fLOGFILE "  + Checking for feed updates\n";
      my $updateSuccess =  updateFeedFiles($executablePath,$debug, $fLOGFILE);
      if (@parameters == 0)
      {
          if ($updateSuccess)
          {
              $fakeItem =~ s/%%ITEM_TITLE%%/Feeds Updated/g;
              $fakeItem =~ s/%%ITEM_DESCRIPTION%%/Updated feed files.  Exit and re-enter the Online Services Menu to refres/g;     
          }
          else
          {
              $fakeItem =~ s/%%ITEM_TITLE%%/No Updates Found/g;
              $fakeItem =~ s/%%ITEM_DESCRIPTION%%/There were no feed updates available at this time/g;           
          }
          print $feed_begin . $fakeItem . $feed_end;
          exit
      }
  }

  my $obj = Net::UPnP::ControlPoint->new();
  my $mediaServer = Net::UPnP::AV::MediaServer->new();    

  my $podcastFeed  = "";
  my %podcastItems = ();
  my $opening      = ""; 

  my $userInput = $parameters[0]; 
  my @searchStrings = split("&&",$userInput);
  my @dev_list = $obj->search();
             
    foreach (@searchStrings)    
    {
        print $fLOGFILE "  + Search String: $_\n"; 
        my @splitString = split(":",$_);   
        
        my %contents = {};
        my $error    = 0;
        my $dirPath  = "";
        
        my $lookingFor = shift(@splitString);
        my $foundDevice = 0;
        
        print $fLOGFILE "    - Looking for UPnP Server: $lookingFor\n";
        foreach (@dev_list)
        {
            chomp;
            print $fLOGFILE "      + Device: ".$_->getfriendlyname()."(".$_->getdevicetype().")\n";
            if ($_->getfriendlyname() =~ /$lookingFor/i)
            {
                $mediaServer->setdevice($_);
                $foundDevice = 1;
                print $fLOGFILE "        - Found $lookingFor\n"; 
                my $dirPath = $_->getfriendlyname()."\\";
                last;
            }
        }

        
        if (!$foundDevice)
        {
            print $fLOGFILE "  ! Error! Couldn't find UPnP Device: ($lookingFor)\n";
            next;
        }
        
        my $id    = 0;
        my $newId = 0;
        my $lastContent = 0;
        my $depth   = 0;
        my $options = "";
        my $filter  = "";
        my $first   = 1;
        while (@splitString)
        {
            $lookingFor = shift(@splitString);            
            # Get the content list at the current level
            if ($lastContent)
            {
                print $fLOGFILE "GetContent from: ".$lastContent->gettitle()." ($id)\n";
            }
            my @content_list = $mediaServer->getcontentlist(ObjectID => $id);
            
            # If we see the +[0-9] we're done  
            if ($lookingFor =~ /\+([0-9]+)([^:]*)/i)
            {
                $depth   = $1;
                $options = $2;
                if (@splitString)
                {
                    $filter = shift(@splitString);
                }
                next;
            }

            # Loop through content list to find next folder
            print $fLOGFILE "    - Current Dir: $dirPath\n";  
            print $fLOGFILE "      + Looking For: $lookingFor\n";
            print $fLOGFILE "      + Listing Directory:\n";
            my $content;   
            foreach $content (@content_list) 
            {
                if ($content->gettitle() =~ /$lookingFor/i)
                { 
                    print $fLOGFILE getTheTime()."      ***";  
                    $newId = $content->getid();
                    $lastContent = $content;
                    $dirPath .= $content->gettitle()."\\";
                    #last;
                }   
                else
                {
                    print $fLOGFILE getTheTime()."        -";    
                }          
                print $fLOGFILE " \\".$content->gettitle();
                print $fLOGFILE "\n";
            }
            if ($first)
            {
                open(PLUGINS,">UPnP2Podcast.plugins");
                foreach $content (@content_list) 
                {
                    chomp;
                    print PLUGINS $content->gettitle()."\n";
                }
                close(PLUGINS);               
            }
            
            if ($newId eq $id)
            {
                print $fLOGFILE getTheTime()."      ! Fail couldn't find ($lookingFor)\n";
                $error    = 1;
                last;
            }
            $id = $newId;
            $first = 0;
 
        }
        
        if (!$error && $lastContent)
        {
            if ($opening eq "")
            {   # Use the first search as the feed channel
                $opening = $feed_begin;
                my $title = $lastContent->gettitle();
                $opening =~ s/%%FEED_TITLE%%/$title/sg;
                $opening =~ s/%%FEED_DESCRIPTION%%/$title/sg;
            }
           
            print $fLOGFILE getTheTime()."    - Success!\n";
            print $fLOGFILE getTheTime()."      + Found Directory: $dirPath\n";
            print $fLOGFILE getTheTime()."        - Searching ($depth) folders deep for video content\n";
            if (!($filter eq ""))
            {
                print $fLOGFILE getTheTime()."        - Filtering results: ($filter)\n";
            }
            print_content($mediaServer, $lastContent, 1, $depth, $filter,$fLOGFILE);
        }
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
    
    
    sub print_content {
        my ($mediaServer, $content, $indent, $depth, $filter,$fLOGFILE) = @_;
        my $id = $content->getid();
        my $title = $content->gettitle();
        my $n;
        
        if ($depth == 0)
        {
            return;
        }

        #print $fLOGFILE getTheTime()."  ! Depth($depth), Title ($title), Filter ($filter)\n";
        #if ($content->isitem() && ($title =~ /$filter/ || $filter eq ""))
        #{
            print $fLOGFILE getTheTime()." ";  
            for (my $n=0; $n<$indent; $n++) {
                print $fLOGFILE getTheTime()."  ";
            }
            if ($n % 2)
            {
                print $fLOGFILE getTheTime()." +";
            }
            else
            {
                print $fLOGFILE getTheTime()." -";
            }        
            
            print $fLOGFILE getTheTime()." \\$title";
            if ($content->isitem()) {
                print $fLOGFILE getTheTime()." (" . $content->geturl();
                if (length($content->getdate())) {
                    print $fLOGFILE getTheTime()." - " . $content->getdate();
                }
                print $fLOGFILE getTheTime()." - " . $content->getcontenttype() . ")";
                if ($title =~ /$filter/ || $filter eq "")
                {
                    addItem($content);
                }
            }
            print $fLOGFILE getTheTime()."\n";
            #print $fLOGFILE getTheTime()." ! ($filterRegExCapture)\n";
        #}
        $depth--;
        
        unless ($content->iscontainer()) {
            #print $fLOGFILE getTheTime()." ! Return: Not Container\n";
            return;
        }
        #print "GetContent from: $title ($id)\n";
        my @child_content_list = $mediaServer->getcontentlist(ObjectID => $id );

        while (@child_content_list <= 0) {
            my $counter++;
            print LOGFILE " !";
            #print LOGFILE " ! Return: no children (@child_content_list)($id)\n";
            sleep(5);
            @child_content_list = $mediaServer->getcontentlist(ObjectID => $id );
            if ($counter == 5)
            {
                last;
            }
        }

        if (@child_content_list <= 0) {
            print $fLOGFILE getTheTime()." ! Return: no children (@child_content_list)($id)\n";
            return;
        }
        $indent++;
        if (@child_content_list == 1 && $depth == 0)
        {   # Fine, try just *1*  more
            $depth++;    
        }
        foreach my $child_content (@child_content_list) {
            print_content($mediaServer, $child_content, $indent,$depth,$filter,$fLOGFILE);
        }
    }
    
    sub getTheTime()
    {
        #($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
        #$year = 1900 + $yearOffset;
        #$theTime = "$hour:$minute:$second: ";
        return "";#$theTime;
    }

  sub updateFeedFiles()
  {
    my ($executablePath, $debug, $fLOGFILE) = @_;
    my $rv = 0;  
    # URL of file containing feed versions
    my $feedPath       = "$executablePath\\STVs\\SageTV3\\OnlineVideos\\";
    my $feedVersionURL = 'http://upnp2podcast.googlecode.com/files/FeedVersions.txt';
    my ($updateFile, $propFileName, $propFileVersion, 
        $propFileMD5, $propFileURL, $topLine, $currentVersion,
        $updatedMD5, $propPlugIn);
    $feedVersionURL    =~ /http:\/\/[^\/]/;
    my $feedBaseURL    = $&;

    if ($debug)
    {
        $feedVersionURL = 'http://upnp2podcast.googlecode.com/svn/trunk/FeedVersionsTest.txt';
    }

    my $content = get $feedVersionURL;
    $content =~ s/\r//g;
    if (defined $content)
    {
        open(PLUGINS,"UPnP2Podcast.plugins");
        my @plugIns = <PLUGINS>;
        chomp(@plugIns);
        close(PLUGINS);  
       
        my @content = split(/\n/,$content);
        print $fLOGFILE "  + Downloaded FeedVersions.txt (".MD5->hexhash($content)."), checking for updates(".$feedVersionURL.")\n";
        foreach (@content)
        {
            $updateFile      = 0;
            if (/(.*),(.*),(.*),(.*),(.*)/)
            {
                ($propFileName, $propFileVersion, $propFileMD5, $propFileURL, $propPlugIn) = ($1,$2,$3,$4,$5);
                print $fLOGFILE "    - File      : $propFileName\n";
                print $fLOGFILE "      - Version : $propFileVersion\n";
                print $fLOGFILE "      - URL     : $propFileURL\n";
                print $fLOGFILE "      - MD5     : $propFileMD5\n";
                print $fLOGFILE "      - Plugin  : $propPlugIn\n";
                if (grep(/\Q$propPlugIn\E/,@plugIns) || $propPlugIn eq "")
                {
                    if ($propFileURL =~ /\Q^$feedBaseURL\E/ || 1)
                    {   # Make sure it comes from my google code account
                        if (-e "$feedPath\\$propFileName")
                        {
                            open(FEED,"$feedPath\\$propFileName");
                            $topLine = <FEED>;
                            chomp($topLine);
                            close(FEED);
                            $currentVersion = "";
                            if ($topLine =~ /Version=([0-9]+)/i)
                            {
                                $currentVersion = $1;
                            }
                            print $fLOGFILE "      - Local Version : $currentVersion\n";
                            if ($propFileVersion > $currentVersion)
                            {
                                $updateFile = 1;    
                            }
                        }
                        else
                        {
                            $updateFile = 1;
                        }
                    }
                }
                else
                {
                    print $fLOGFILE "        + PlayOn Plug-in ($propPlugIn) not installed, skipping (@plugIns)\n";    
                }
                
                
                if ($updateFile)
                {
                    print $fLOGFILE "      - Updating File!\n";             
                    $content = get $propFileURL;
                    if (!($content eq ""))
                    {
                        $content =~ s/\r//g;
                        $updatedMD5 = MD5->hexhash($content);
                        print $fLOGFILE "        + MD5 URL : $updatedMD5 ($propFileMD5)\n";
                        if ($updatedMD5 eq $propFileMD5)
                        {
                            open(FEED,">$feedPath\\$propFileName");
                            print FEED $content;
                            close(FEED);
                            $rv++;
                        }
                        else
                        {
                            print $fLOGFILE "        - MD5 check failed, skipping!\n";    
                        }
                    }
                } 
            }
        }  
    }
    else
    {
        print $fLOGFILE "  ! Failed to get FeedVersions.txt, skipping updates\n";
    } 
    return $rv;   
  }

  sub populateFeedStrings()
  {
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
      <itunes:subtitle>%%ITEM_DESCRIPTION%%</itunes:subtitle>
      <itunes:duration>00:01:00</itunes:duration>
      <enclosure url="http://127.0.0.1/fake.mpg" length="10000" type="video/mpeg2" /> 
      <media:content duration="60" medium="video" fileSize="10000" url="http://127.0.0.1/fake.mpg" type="video/mpeg2"> 
        <media:title>%%ITEM_TITLE%%</media:title> 
        <media:description>%%ITEM_DESCRIPTION%%<</media:description>
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
    
  sub updateRecentPodcasts()
  {
    my ($executablePath,$searchString) = @_;
    my $feedPath       = "$executablePath\\STVs\\SageTV3\\OnlineVideos\\";
    my $fileContents;
    my $searchToRemove;
    my $updateFile;
    my $foundNewOne;
    my $file;
    my $seachesToCheck;
    my $line;
    my $notInList;
    my @newList;
    my $foundInList;
    
    print $fLOGFILE "  + Adding to recent: ($searchString)\n";
    
    open(RECENT,"UPnP2Podcast.recent");
    my @recentSearches = <RECENT>;
    close(RECENT);
    
    foreach (@recentSearches)
    {
        chomp;
        #print $fLOGFILE "?  $_ ()\n";
        if ($searchString eq $_)
        {
            print $fLOGFILE "    + Already in list, moving to top! ($searchString)($_)\n";
            $foundInList = 1;
        }
        else
        {
            push(@newList,$_);
        }
    }
    
    if ($foundInList)
    {   # Move to top
        push(@newList,$searchString);
        open(RECENT,">UPnP2Podcast.recent");
        foreach (@newList)
        {
            chomp;
            print RECENT $_."\n";
        }
        close(RECENT); 
        return;   
    }
    
    push(@recentSearches,$searchString);

    opendir(SCANDIR,"$feedPath");
    my @filesInDir = readdir(SCANDIR);
    close(SCANDIR);
    $updateFile = 0;
    foreach $file (@filesInDir)
    {
        if ($file =~ /.properties$/)
        {
            print $fLOGFILE "    - Checking file: ($file)\n";
            open(PROPFILE,$feedPath.$file);
            $fileContents = "";
            $updateFile   = 0;
            while (<PROPFILE>)
            { 
                chomp;
                $line = $_;
                foreach $seachesToCheck (@recentSearches)
                {   #$searchString
                    if ($line =~ /\Q$seachesToCheck\E/i && $line !~ /xPodcastUPnP_Recent/)
                    {
                        print $fLOGFILE "      + Found: $line\n";
                        $line =~ s/=/=xPodcastUPnP_Recent,/;
                        $updateFile = 1;
                        print $fLOGFILE "        - Updated: $line\n";
                        if ($seachesToCheck eq $searchString)
                        {
                            $foundNewOne = 1;
                        }
                        last;
                    }
                                    
                }
                $fileContents .= $line . "\n"; 
            }
            close(PROPFILE);
            if ($updateFile)
            {
                print $fLOGFILE "        -  Updating file (".$feedPath.$file.")\n";
                open(PROPFILE,">".$feedPath.$file);
                print PROPFILE $fileContents; 
                close(PROPFILE);
            }    
        }
    }
    
    if (!$foundNewOne)
    {   # Didn't find new one
        print $fLOGFILE "  + Couldn't find ($searchString)\n";
        pop(@recentSearches);    
    }
    
    if (@recentSearches > 10)
    {
        $searchToRemove = shift(@recentSearches);
        print $fLOGFILE "    - Removing : ($searchToRemove)\n";
    }
    
    print $fLOGFILE "  + Removing expired recent searches\n";
    foreach $file (@filesInDir)
    {
        if ($file =~ /^CustomOnlineVideoLinks.*\.properties$/)
        {
            print $fLOGFILE "    - Checking file: ($file)\n";
            $fileContents = "";
            $updateFile   = 0;
            open(PROPFILE,$feedPath.$file);
            while (<PROPFILE>)
            {
                chomp;
                $line      = $_;
                if ($line =~ /xPodcastUPnP_Recent/i && $line !~ /CustomSources/i)
                {
                    $notInList = 1;
                    print $fLOGFILE "      + Checking Line ($line)\n"; 
                    foreach $seachesToCheck (@recentSearches)
                    {   #$searchString
                        if ($line =~ /\Q$seachesToCheck\E/i) 
                        {
                        
                            print $fLOGFILE "          + MATCH: ($seachesToCheck)\n"; 
                            $notInList = 0;
                            last;   
                        }
                    }
                    
                    if ($notInList)
                    {
                        $line =~ s/xPodcastUPnP_Recent,//g;
                        $updateFile = 1;
                        print $fLOGFILE "          + Removed: ($line)\n";
                    }
                }
                $fileContents .= $line."\n";
            }
            close(PROPFILE);
            if ($updateFile)
            {
                open(PROPFILE,">".$feedPath.$file);
                print PROPFILE $fileContents; 
                close(PROPFILE); 
            }    
        }
    }
        
    open(RECENT,">UPnP2Podcast.recent");
    foreach (@recentSearches)
    {
        chomp;
        print RECENT $_."\n";
    }
    close(RECENT);
}
    