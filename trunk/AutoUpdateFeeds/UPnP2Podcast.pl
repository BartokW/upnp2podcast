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
  use LWP::Simple;
  use MD5;
  use Net::UPnP::ControlPoint;
  use Net::UPnP::AV::MediaServer;
  
  my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
  
  # Get the directory the script is being called from
  my $executable = $0;
  $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;;
  my $executablePath = $`;
  my $executableEXE  = $3; 
  
  # URL of file containing feed versions
  my $feedPath       = "$executablePath\\STVs\\SageTV3\\OnlineVideos\\";
  my $feedVersionURL = 'http://mediascraper.svn.sourceforge.net/viewvc/mediascraper/FeedVersions.txt';
  

  if (!(-e 'tinFoilHat.txt'))
  {
      my $content = get $feedVersionURL;
      if (defined $content)
      {
          print stderr "  + Downloaded FeedVersions.txt (".MD5->hexhash($content)."), checking for updates\n";
          @content = split(/\n/,$content);
          foreach (@content)
          {
              if (/(.*),(.*),(.*),(.*)/)
              {
                  $updateFile      = 0;
                  $propFileName    = $1;
                  $propFileVersion = $2;
                  $propFileMD5     = $3;
                  $propFileURL     = $4;
                  print stderr "    - File      : $propFileName\n";
                  print stderr "      - Version : $propFileVersion\n";
                  print stderr "      - URL     : $propFileURL\n";
                  print stderr "      - MD5     : $propFileMD5\n";
                  
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
                      print stderr "      - Local Version : $currentVersion\n";
                      if ($propFileVersion > $currentVersion)
                      {
                          $updateFile = 1;    
                      }
                  }
                  else
                  {
                      $updateFile = 1;
                  }
                  if ($updateFile)
                  {
                      print stderr "      - Updating File!\n";
                      $content = "";               
                      $content = get $propFileURL;
                      if (!($content eq ""))
                      {
                          $content =~ s/\r//g;
                          $updatedMD5 = MD5->hexhash($content);
                          print stderr "        + MD5 URL : $updatedMD5 ($propFileMD5)\n";
                          if ($updatedMD5 eq $propFileMD5)
                          {
                              open(FEED,">$feedPath\\$propFileName");
                              print FEED $content;
                              close(FEED);
                          }
                          else
                          {
                              print stderr "        - MD5 check failed, skipping!\n";    
                          }
                      }
                  } 
              }
              else
              {
                  print stderr "    - No match: $_\n;"
              }
          }  
      }
      else
      {
          print stderr "  ! Failed to get FeedVersions.txt, skipping updates\n";
      }
  }

# Code version
my $codeVersion = "$executableEXE v1.2";

my $invalidMsg .= "\n$codeVersion\n";
$invalidMsg .= "\tUSAGE:";
$invalidMsg .= "\t$executableEXE.exe (UPnP Search String)\n\n";

    
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

my $noItemFoundDescription = "There were no videos found with the search string ($ARGV[0]).  Since online videos are constantly being removed and added this probably indicates that there are none available at this time.";
if ($ARGV[0] !~ /playon:(hulu|netflix|cbs|cnn|espn|amazon|youtube)/i)
{
    $noItemFoundDescription .= "  This item also doesn't appears to be looking for content from PlayOn's built in sources (hulu|netflix|cbs|cnn|espn|amazon|youtube) and might require a plug-in that you don't have installed (http://www.playonplugins.com/)."    
}
my $noItemFound = <<PODCAST_NO_ITEM;
    <item> 
      <title>No Videos Found</title> 
      <description>$noItemFoundDescription</description> 
      <itunes:subtitle>No Videos Found</itunes:subtitle>
      <itunes:duration>00:01:00</itunes:duration>
      <enclosure url="http://127.0.0.1/fake.mpg" length="10000" type="video/mpeg2" /> 
      <media:content duration="60" medium="video" fileSize="10000" url="http://127.0.0.1/fake.mpg" type="video/mpeg2"> 
        <media:title>No Videos Found</media:title> 
        <media:description>No Videos Found</media:description>
        <media:thumbnail url="http://127.0.0.1/fake.jpg"/>  
      </media:content> 
    </item> 
PODCAST_NO_ITEM

my $noItemFail= <<PODCAST_FAIL_ITEM;
    <item> 
      <title>No Videos Found</title> 
      <description>%%ITEM_DESCRIPTION%%</description> 
      <itunes:subtitle>%%ITEM_DESCRIPTION%%</itunes:subtitle>
      <itunes:duration>00:00:00/itunes:duration>
      <enclosure url="http://127.0.0.1/fake.mpg" length="0" type="video/mpeg2" /> 
      <media:content duration="0" medium="video" fileSize="0" url="http://127.0.0.1/fake.mpg" type="video/mpeg2"> 
       <media:title>No Videos Found</media:title> 
      <media:description>%%ITEM_DESCRIPTION%%</media:description> 
      </media:content> 
    </item> 
PODCAST_FAIL_ITEM

my $feed_end = <<'FEED_END';
  </channel> 
</rss> 
FEED_END

    
    # Move arguments into user array so we can modify it
    my @parameters = @ARGV;
    my $obj = Net::UPnP::ControlPoint->new();
    my $mediaServer = Net::UPnP::AV::MediaServer->new();    
  
    my $podcastFeed  = "";
    my %podcastItems = ();
    my $opening      = ""; 
      
    if (@parameters > 2 || @parameters < 1)
    {
        print stderr $invalidMsg;
        my $errorDescription = "UPnP2Podcast Usage Error (@ARGV)";
        $noItemFail =~ s/%%ITEM_DESCRIPTION%%/$errorDescription/g;
        print $feed_begin . $noItemFail . $feed_end;
        exit;
    }
 
    my $userInput = $parameters[0]; 
    my @searchStrings = split("&&",$userInput);
    my @dev_list = $obj->search();
             
    foreach (@searchStrings)    
    {
        print stderr "  + Search String: $_\n"; 
        my @splitString = split(":",$_);   
        
        my %contents = {};
        my $error    = 0;
        my $dirPath  = "";
        
        my $lookingFor = shift(@splitString);
        my $foundDevice = 0;
        
        print stderr "    - Looking for UPnP Server: $lookingFor\n";
        foreach (@dev_list)
        {
            chomp;
            print stderr "      + Device: ".$_->getfriendlyname()."(".$_->getdevicetype().")\n";
            if ($_->getfriendlyname() =~ /$lookingFor/i)
            {
                $mediaServer->setdevice($_);
                $foundDevice = 1;
                print stderr "        - Found $lookingFor\n"; 
                my $dirPath = $_->getfriendlyname()."\\";
                last;
            }
        }

        
        if (!$foundDevice)
        {
            print stderr "  ! Error! Couldn't find UPnP Device: ($lookingFor)\n";
            next;
        }
        
        my $id    = 0;
        my $newId = 0;
        my $lastContent = 0;
        my $depth   = 0;
        my $options = "";
        my $filter  = "";
        while (@splitString)
        {
            $lookingFor = shift(@splitString);
            
            # Get the content list at the current level
            
            if ($lastContent)
            {
                print stderr "GetContent from: ".$lastContent->gettitle()." ($id)\n";
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
            print stderr "    - Current Dir: $dirPath\n";  
            print stderr "      + Looking For: $lookingFor\n";
            print stderr "      + Listing Directory:\n";
            my $content;   
            foreach $content (@content_list) 
            {
                if ($content->gettitle() =~ /$lookingFor/i)
                { 
                    print stderr getTheTime()."      ***";  
                    $newId = $content->getid();
                    $lastContent = $content;
                    $dirPath .= $content->gettitle()."\\";
                    #last;
                }   
                else
                {
                    print stderr getTheTime()."        -";    
                }          
                print stderr " \\".$content->gettitle();
                print stderr "\n";
            }
            
            if ($newId eq $id)
            {
                print stderr getTheTime()."      ! Fail couldn't find ($lookingFor)\n";
                $error    = 1;
                last;
            }
            $id = $newId;
 
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
           
            print stderr getTheTime()."    - Success!\n";
            print stderr getTheTime()."      + Found Directory: $dirPath\n";
            print stderr getTheTime()."        - Searching ($depth) folders deep for video content\n";
            if (!($filter eq ""))
            {
                print stderr getTheTime()."        - Filtering results: ($filter)\n";
            }
            print_content($mediaServer, $lastContent, 1, $depth, $filter);
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
    }
    else
    {   # If no videos were found
        $podcastFeed .= $noItemFound;    
    }

    $podcastFeed .= $feed_end;

    print $podcastFeed;  
 
     sub addItem {
        my ($content) = @_;
        my $id    = $content->getid();
        my $title = $content->gettitle();
        my $url   = $content->geturl();
        my $size  = $content->getSize();
        my $date  = $content->getdate();
        my $rating      = $content->getRating();
        my $userRating  = $content->getUserRating();
        my $dur  = $content->getDur();
        my $screenShot  = $content->getPicture();
        my $desc = $content->getDesc();
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
        my ($mediaServer, $content, $indent, $depth, $filter) = @_;
        my $id = $content->getid();
        my $title = $content->gettitle();
        my $n;
        
        if ($depth == 0)
        {
            return;
        }

        #print stderr getTheTime()."  ! Depth($depth), Title ($title), Filter ($filter)\n";
        #if ($content->isitem() && ($title =~ /$filter/ || $filter eq ""))
        #{
            print stderr getTheTime()." ";  
            for (my $n=0; $n<$indent; $n++) {
                print stderr getTheTime()."  ";
            }
            if ($n % 2)
            {
                print stderr getTheTime()." +";
            }
            else
            {
                print stderr getTheTime()." -";
            }        
            
            print stderr getTheTime()." \\$title";
            if ($content->isitem()) {
                print stderr getTheTime()." (" . $content->geturl();
                if (length($content->getdate())) {
                    print stderr getTheTime()." - " . $content->getdate();
                }
                print stderr getTheTime()." - " . $content->getcontenttype() . ")";
                if ($title =~ /$filter/ || $filter eq "")
                {
                    addItem($content);
                }
            }
            print stderr getTheTime()."\n";
            #print stderr getTheTime()." ! ($filterRegExCapture)\n";
        #}
        $depth--;
        
        unless ($content->iscontainer()) {
            #print stderr getTheTime()." ! Return: Not Container\n";
            return;
        }
        #print "GetContent from: $title ($id)\n";
        my @child_content_list = $mediaServer->getcontentlist(ObjectID => $id );
        if (@child_content_list <= 0) {
            print stderr getTheTime()." ! Return: no children (@child_content_list)($id)\n";
            return;
        }
        $indent++;
        foreach my $child_content (@child_content_list) {
            print_content($mediaServer, $child_content, $indent,$depth,$filter);
        }
    }
    
    sub getTheTime()
    {
        #($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
        #$year = 1900 + $yearOffset;
        #$theTime = "$hour:$minute:$second: ";
        return "";#$theTime;
    }
    