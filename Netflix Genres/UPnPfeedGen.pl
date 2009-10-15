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
##### Import libraries
    use Encode qw(encode decode);
    use utf8;
    use Net::UPnP::ControlPoint;
    use Net::UPnP::AV::MediaServer;
    
    @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
    
    open(LOGFILE,">netflixFeed.log");
    
    
    # Get the directory the script is being called from
    $executable = $0;
    $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;;
    $executablePath = $`;
    $executableEXE  = $3; 

    # Code version
    $codeVersion = "$executableEXE v1.0a";
    
    $invalidMsg .= "\n$codeVersion\n";
    $invalidMsg .= "\tUSAGE:";
    $invalidMsg .= "\t$executableEXE.exe (UPnP Search String)\n\n";
    
    # Move arguments into user array so we can modify it
    my @parameters = @ARGV;
    my $obj = Net::UPnP::ControlPoint->new();
    my $mediaServer = Net::UPnP::AV::MediaServer->new();    
      
    if (@parameters > 2 || @parameters < 1)
    {
        print LOGFILE $invalidMsg;
        exit;
    }
 
    my @dev_list = $obj->search();
          
    @splitString = split(":",$parameters[0]);   
    
    my %contents = {};
    my $error    = 0;
    my $dirPath  = "";
    
    $lookingFor = shift(@splitString);
    $foundDevice = 0;
    
    print  "    - Looking for UPnP Server: $lookingFor\n";

    ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    print  "Starting: ($hour:$minute:$second)\n";

    foreach (@dev_list)
    {
        chomp;
        print  "      + Device: ".$_->getfriendlyname()."(".$_->getdevicetype().")\n";
        if ($_->getfriendlyname() =~ /$lookingFor/i)
        {
            $mediaServer->setdevice($_);
            $foundDevice = 1;
            print LOGFILE "        - Found $lookingFor\n"; 
            $dirPath = $_->getfriendlyname()."\\";
            last;
        }
    }

    
    if (!$foundDevice)
    {
        print  "  ! Error! Couldn't find UPnP Device: ($lookingFor)\n";
        next;
    }

    ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    print  "Found Server: ($hour:$minute:$second)\n";   
  
    my @content_list = $mediaServer->getcontentlist(ObjectID => 0);
    foreach $content (@content_list)
    {
        print_content($mediaServer, $content, 1, 4, "");
    }
    ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    print LOGFILE "Finished!: ($hour:$minute:$second)\n";   


 
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
        my $durSec = $1*60*60 + $2*60 + $3;
        my $durMod = "$1:$2:$3";
        
        $date  =~ /^(.*)T/;
        $date  = $1;
        
        $newItem =~ s/%%ITEM_URL%%/$url/sg;
        $newItem =~ s/%%ITEM_SIZE%%/$size/sg;
        $newItem =~ s/%%ITEM_DATE%%/$date/sg;
        $newItem =~ s/%%ITEM_PICTURE%%/$screenShot/sg;
        $newItem =~ s/%%ITEM_DUR_SEC%%/$durSec/sg;
        $newItem =~ s/%%ITEM_DUR%%/$durMod/sg;
        
        $podcastItems{lc($title)} = $newItem;
    }
    
    
    sub print_content {
        my ($mediaServer, $content, $indent, $depth, $filter) = @_;
        my $id = $content->getid();
        my $title = $content->gettitle();
        
        if ($id =~ /hulu/i)
        {
            exit;
        }
        
        if ($depth == 0 || $content->isitem())
        {
            return;
        }
        
        #if ($title =~ /(A-B|Part 1)/)
        #{
        #    return;
        #}

        #$debugLog .=getTheTime()."  ! Depth($depth), Title ($title), Filter ($filter)\n";
        #if ($content->isitem() && ($title =~ /$filter/ || $filter eq ""))
        #{
            print LOGFILE getTheTime()." ";  
            for ($n=0; $n<$indent; $n++) {
                print LOGFILE getTheTime()."  ";
            }
            if ($n % 2)
            {
                print LOGFILE getTheTime()." +";
            }
            else
            {
                print LOGFILE getTheTime()." -";
            }        
            
            print LOGFILE getTheTime()." \\$title (".(4 - $depth).")";
            if ($content->isitem() && 0) {
                print LOGFILE getTheTime()." (" . $content->geturl();
                if (length($content->getdate())) {
                    print LOGFILE getTheTime()." - " . $content->getdate();
                }
                print LOGFILE getTheTime()." - " . $content->getcontenttype() . ")";
                if ($title =~ /$filter/ || $filter eq "")
                {
                    addItem($content);
                }
            }
            #$debugLog .=getTheTime()." ! ($filterRegExCapture)\n";
        #}
        $depth--;
        
        unless ($content->iscontainer()) {
            print LOGFILE getTheTime()." ! Return: Not Container\n";
            return;
        }

        #print LOGFILE "Getting Content List For: $title ($id)";
        my @child_content_list = $mediaServer->getcontentlist(ObjectID => $id );
        my $counter = 0;
        while (@child_content_list <= 0) {
            $counter++;
            print LOGFILE " !";
            #print LOGFILE " ! Return: no children (@child_content_list)($id)\n";
            sleep(5);
            @child_content_list = $mediaServer->getcontentlist(ObjectID => $id );
        }
        $indent++;
        print LOGFILE getTheTime()."(".@child_content_list.")\n";
        foreach my $child_content (@child_content_list) {
                print_content($mediaServer, $child_content, $indent,$depth,$filter);
        }
    }
    
    sub getTheTime()
    {
        ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
        $year = 1900 + $yearOffset;
        $theTime = "$hour:$minute:$second: ";
        return "";#$theTime;
    }
    