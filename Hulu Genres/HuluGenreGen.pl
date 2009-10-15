#! /user/bin/perl

# Move arguments into user array so we can modify it
my @parameters = @ARGV;
if (@parameters == 0)
{
    print $invalidMsg;
    exit;
}

%categories = ();
%shows      = ();

foreach $inputFile (@parameters)
{
    open(HTMLFILE,"$inputFile");    
    print "Input File: $inputFile\n";
    
    $inputFile =~ /\\?([^\\]*)\./;
    $inputFileName = $1;
  
    print "Input File Name: $inputFileName\n";  

    while (<HTMLFILE>)
    {
    		chomp;
    		if (/\/network\/([^"]+)/) #"
    		{
    			$_ =~ /title="([^"]+)/;
    			$foundNetwork = $1;
    			$foundNetwork =~ s/&amp\;/&/g;
    			$foundNetwork =~ s/\-/ /g;
    			#print "  + Found Network: ($foundNetwork)\n";
    		}
    		
    		if (/www.hulu.com[^"]*" class="show.thumb info.hover"/)
    		{
    			$_ =~ />([^<]+)/; #"
    			$show    = $1;
    			$show =~ s/&amp\;/&/g;
    			print "      + Show: $show\n";
    			push(@{$categories{$inputFileName}{$foundNetwork}},$show);
    			#print "      + Keys : ".(keys %categories)."\n";
    			push(@{$shows{$show}},[$inputFileName,$foundNetwork]);
    		}	
    }
}

$linksFile   = "";
$textFile    = "";
$feedNames   = "";
$sourceNames = "";
$rowsCols    = "";
$subCatagorys = "";
$customSources  = "CustomSources=xPodcastABC_Current,xPodcastNBC_Current,xPodcastFOX_Current,xPodcastComedy_Central_Current,xPodcastUSA_Current,xPodcastSyFy_Current,xPodcastBrowseHulu\n";


# Hardcoded Stuff
$sourceNames .= "\nSource/xPodcastBrowseHulu/LongName=Browse Hulu\n";
$sourceNames .= "Source/xPodcastBrowseHulu/ShortName=Browse Hulu\n";

@hardcodedShows = ('xPodcastABC_Current','xPodcastNBC_Current','xPodcastFOX_Current','xPodcastUSA_Current','xPodcastComedy_Central_Current','xPodcastSyFy_Current');
@{$currentShows{'xPodcastABC_Current'}} = ('Shaq Vs','Extreme Makeover: Home Edition','Eastwick','Shark Tank','Scrubs','Jimmy Kimmel Live','Supernanny','Brothers & Sisters','Dancing With The Stars','Hank','Ugly Betty','FlashForward','The Forgotten','Desperate Housewives','Modern Family','Wipeout','Lost','Better Off Ted','Defying Gravity','Grey.s Anatomy','Castle','Cougar Town','The Middle','Crash Course','Private Practice');
@{$currentShows{'xPodcastNBC_Current'}} = ('Late Night with Jimmy Fallon','Mercy','Parks and Recreation','Heroes','The Office','30 Rock','Saturday Night Live','The Biggest Loser','The Jay Leno Show','Trauma','Chuck','The Tonight Show with Conan O.Brien');#'
@{$currentShows{'xPodcastFOX_Current'}} = ('House','Bones','Lie To Me','The Cleveland Show','Brothers','Glee','The Simpsons','Fringe','.Til Death','Kitchen Nightmares','Dollhouse','Family Guy','American Dad.','Hell.s Kitchen');#'
@{$currentShows{'xPodcastUSA_Current'}} = ('Psych','The Starter Wife','In Plain Sight','Royal Pains','Burn Notice','Monk');#'
@{$currentShows{'xPodcastComedy_Central_Current'}} = ('The Colbert Report','The Daily Show with Jon Stewart');#'
@{$currentShows{'xPodcastSyFy_Current'}} = ('Stargate Universe','Scare Tactics','Ghost Hunters International','Ghost Hunters','Sanctuary','Stargate Atlantis','Stargate SG.1');#'


foreach (@hardcodedShows)
{
    $rowsCols  .= "\n".$_."/CategoryTable/NumRows=4\n";
    $rowsCols  .= $_."/CategoryTable/NumCols=4\n";
    if (/xPodcast(.*)_Current/)
    {
        $hardCodedNetwork = $1;
        $hardCodedNetwork =~ s/_/ /g;       
    		$sourceNames .= "\nSource/$_/LongName=$hardCodedNetwork\n";
        $sourceNames .= "Source/$_/ShortName=$hardCodedNetwork\n";        
    }
    $sourceNames .= "\n";
}


$linksFile  .= <<HARDCODED_LINKS;
# Hulu
xFeedPodcastCustom/aaHuluUserQueue=xPodcastBrowseHulu;external,UPnP2Podcast,PlayOn:Hulu:User Queue:By Name:+2
xFeedPodcastCustom/zaHuluRecentEpisodes=xPodcastBrowseHulu;external,UPnP2Podcast,PlayOn:Hulu:Recently Added Episodes:+2
xFeedPodcastCustom/zbHuluRecentMovies=xPodcastBrowseHulu;external,UPnP2Podcast,PlayOn:Hulu:Recently Added Feature Films:+2
xFeedPodcastCustom/zcHuluPopularToday=xPodcastBrowseHulu;external,UPnP2Podcast,PlayOn:Hulu:Popular Videos Today:+2
xFeedPodcastCustom/zdHuluPopularThisWeek=xPodcastBrowseHulu;external,UPnP2Podcast,PlayOn:Hulu:Popular Videos This Week:+2
xFeedPodcastCustom/zeHuluPopularThisMonth=xPodcastBrowseHulu;external,UPnP2Podcast,PlayOn:Hulu:Popular Videos This Month:+2
xFeedPodcastCustom/zfHuluPopularAllTime=xPodcastBrowseHulu;external,UPnP2Podcast,PlayOn:Hulu:Popular Videos All Time:+2

HARDCODED_LINKS

$textFile  .= <<HARDCODED_CATS;
Category/aaHuluUserQueue/LongName=User Queue
Category/aaHuluUserQueue/ShortName=User Queue

Category/zaHuluRecentEpisodes/LongName=Recently Added Episodes
Category/zaHuluRecentEpisodes/ShortName=Recently Added Episodes

Category/zbHuluRecentMovies/LongName=Recently Added Movies
Category/zbHuluRecentMovies/ShortName=Recently Added Movies

Category/zcHuluPopularToday/LongName=Popular Today
Category/zcHuluPopularToday/ShortName=Popular Today

Category/zdHuluPopularThisWeek/LongName=Popular This Week
Category/zdHuluPopularThisWeek/ShortName=Popular This Week

Category/zeHuluPopularThisMonth/LongName=Popular This Month
Category/zeHuluPopularThisMonth/ShortName=Popular This Month

Category/zfHuluPopularAllTime/LongName=Popular All Time
Category/zfHuluPopularAllTime/ShortName=Popular All Time
HARDCODED_CATS

foreach $category (sort { lc ($a) cmp lc($b) } keys %categories)
{
    print "  + Category: $category\n";
    #print "    - Keys : ".(keys %{$categories{$category}})."\n";
    $catPodcastName = "xPodcastHulu_By_".$category;
    
		$rowsCols    .= "$catPodcastName/CategoryTable/NumRows=4\n";
		$rowsCols    .= "$catPodcastName/CategoryTable/NumCols=4\n\n";
		
		$subCatagorys .= "\nxFeedPodcastCustom/Hulu_By_$category=xPodcastBrowseHulu;xURLNone\n";
		$subCatagorys .= "Hulu_By_$category/IsCategory=true\n";
		$subCatagorys .= "Hulu_By_$category/CategoryName=".$catPodcastName."\n";
		
		$sourceNames .= "\nCategory/Hulu_By_$category/LongName=$category\n";
		$sourceNames .= "Category/Hulu_By_$category/ShortName=$category\n";
		$sourceNames .= "Source/$catPodcastName/LongName=$category\n";
		$sourceNames .= "Source/$catPodcastName/ShortName=$category\n";

    foreach $network (sort { lc ($a) cmp lc($b) } keys %{$categories{$category}})
    {
        if (@{$categories{$category}{$network}} == 0)
        {
            next;
        }
    		print "    - Network: $network\n";
    
    		$networkStriped = $network;
    		$networkStriped =~ s/[ .:&!]//g; 
    		$subCatName     = "Hulu_".$category."_".$networkStriped."_SubCat";
    
    		$networkHuluBanner = $network;
    		$networkHuluBanner =~ s/&/and/g;
    		$networkHuluBanner =~ s/[ \-]/_/g;
    		$networkHuluBanner =~ s/[.:'`"]//g; #"
    		$networkPoster = "http://assets.hulu.com/companies/company_thumbnail_".lc($networkHuluBanner).".jpg";
    		print stderr "      + Thumb: $networkPoster\n";
    		
    		#print "    - Stripped: $networkStriped\n";
    		$subCatagorys .= "\nxFeedPodcastCustom/".$subCatName."=$catPodcastName;xURLNone\n";
    		$subCatagorys .= $subCatName."/IsCategory=true\n";
    		$subCatagorys .= $subCatName."/CategoryName=xPodcast_".$subCatName."\n";
    		
    		#$feedNames   .= ",xPodcast_".$networkStriped;
    		$rowsCols    .= "xPodcast_".$subCatName."/CategoryTable/NumRows=4\n";
    		$rowsCols    .= "xPodcast_".$subCatName."/CategoryTable/NumCols=4\n\n";
    
        $sourceNames .= "\nCategory/".$subCatName."/ThumbURL=$networkPoster\n";
    		$sourceNames .= "Category/".$subCatName."/LongName=$network\n";
    		$sourceNames .= "Category/".$subCatName."/ShortName=$network\n";
    		$sourceNames .= "Source/xPodcast_".$subCatName."/LongName=$network\n";
    		$sourceNames .= "Source/xPodcast_".$subCatName."/ShortName=$network\n";
    }
}

foreach $show (keys %shows)
{
    print "  + Show: $show\n"; 
    
		$showHuluBanner = $show;
		$showHuluBanner =~ s/&/and/g;
		$showHuluBanner =~ s/[ \-]/_/g;
		$showHuluBanner =~ s/[.:'`"!]//g; #"
		$poster = "http://assets.hulu.com/shows/show_thumbnail_".lc($showHuluBanner).".jpg";

    print "    - Found Poster     : ($poster)\n";
    
    if ($show =~ /^The ([a-zA-Z])/i)
		{
        $showFirstLetter = $1;    
    }
    else
    {
        $showFirstLetter = substr($show, 0, 1);
    }
		
		$showStripped    = $show;
		$showStripped    =~ s/[ .:&\-()\$'"!]//g; #"
		
		$showRegEx       = $show;
		$showRegEx       =~ s/[^a-zA-Z0-9]/./g; #"
    
  	# Scrape it, bitches!
    $command = "mediaEngine.pl /profile theTVDBTitleOnly /showtitle \"$show\" /throttle 0";
    print stderr "    - Command        : ($command)\n";
    $output  = "";#`$command`;
        
    # Clear out List
    $tvDBposter = "";
    $firstAired = "";
    $network = "";
    $genre = "";
    if ($output =~ /posters\/([^,]+)/m)
    {
        $tvDBposter = "http://thetvdb.com/banners/_cache/posters/$1";
        print stderr "      + TVDB Poster    : ($tvDBposter)\n";      
    }

    if ($output =~ /FirstAired>([0-9]+)/m)
    {
        $firstAired = "$1";
        print stderr "      + FirstAired     : ($firstAired)\n";      
    }
    
    if ($output =~ /\$\$showNetwork\$\$ = \(([^)]+)/m)
    {
        $network = "$1";
        $network =~ s/&amp\;/&/g;
        print stderr "      + Network        : ($network)\n";      
    }
    
    if ($output =~ /\$\$showGenre\$\$ = \(([^)]+)/m)
    {
        $genre = "$1";
        $genre =~ s/&amp\;/&/g;
        @genres = split(/\|/,$genre);
        print stderr "      + Found Genere     : (@genres)\n";      
    } 
 

    $textFile  .= "\nCategory/Hulu_Show_".$showStripped."/ThumbURL=$poster\n";
		$textFile  .= "Category/Hulu_Show_".$showStripped."/LongName=$show\n";
		$textFile  .= "Category/Hulu_Show_".$showStripped."/ShortName=$show\n\n";          		

		$linksFile  .= "# Show        : $show\n";
		$linksFile  .= "# FirstAired  : $firstAired\n";
		$linksFile  .= "# Network     : $network\n";
		$linksFile  .= "# Genres      : @genres\n";
		$linksFile  .= "# TVDB Poster : $tvDBposter\n";

    $linksFile .=   "xFeedPodcastCustom/Hulu_Show_".$showStripped."="; 

    foreach $hardcodedNetworkFeed (@hardcodedShows)
    {
        #print "   + $hardcodedNetworkFeed\n";
        foreach $currentNetworkShow (@{$currentShows{$hardcodedNetworkFeed}})
        {
            #print "   + $currentNetworkShow\n";
            if ($show =~ /^$currentNetworkShow$/)
            {
                $linksFile .= $hardcodedNetworkFeed.",";
                print "    - Hardcoded: $hardcodedNetworkFeed\n";   
            }
        }
    }
       		
    foreach $list (@{$shows{$show}})
    {
        $category = $list->[0];
        $network  = $list->[1];
        $network =~ s/[ .:&!]//g; 
    		$subCatName     = "Hulu_".$category."_".$network."_SubCat";
        print "    - Category: $category / $network\n";
        $linksFile .= "xPodcast_".$subCatName.","; 
    }  
    chop($linksFile);
    $linksFile .=   ";external,UPnP2Podcast,PlayOn:Hulu:TV Episodes:".uc($showFirstLetter).":^".$showRegEx."\$:+2\n"; 
}

open (LINKS,">CustomOnlineVideoLinks_UPnP2Podcast_Hulu.properties");
open (NAMES,">CustomOnlineVideoUIText_UPnP2Podcast_Hulu.properties");

$rowsCols =~ s/\/Hulu_By_Network/\/abHulu_By_Network/g;
$rowsCols =~ s/^Hulu_By_Network/abHulu_By_Network/g;

$subCatagorys =~ s/\/Hulu_By_Network/\/abHulu_By_Network/g;
$subCatagorys =~ s/\nHulu_By_Network/\nabHulu_By_Network/g;

$linksFile =~ s/\/Hulu_By_Network/\/abHulu_By_Network/g;
$linksFile =~ s/\nHulu_By_Network/\nabHulu_By_Network/g;

$sourceNames =~ s/\/Hulu_By_Network/\/abHulu_By_Network/g;
$sourceNames =~ s/\nHulu_By_Network/\nabHulu_By_Network/g;

$textFile =~ s/\/Hulu_By_Network/\/abHulu_By_Network/g;
$textFile =~ s/\nHulu_By_Network/\nabHulu_By_Network/g;
$textFile =~ s/=Network/=By Network/g;
$textFile =~ s/=Network/=By Network/g;  

($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$theTime = sprintf("%04d%02d%02d",$year,($month+1),$dayOfMonth);

$linksFileContents .=  "# Version=$theTime\n\n";
$linksFileContents .=  "#\n# Top Level Categories\n#\n";
$linksFileContents .=  "\n$customSources\n";
$linksFileContents .=  "#\n# Rows and Colums\n#\n";
$linksFileContents .=  "\n$rowsCols\n";
$linksFileContents .=  "#\n# Declare Sub Catagories\n#\n";
$linksFileContents .=  "\n$subCatagorys\n";
$linksFileContents .=  "#\n# Declare Links\n#\n";
$linksFileContents .=  "\n$linksFile\n";


$textFileContents .= "# Version=$theTime\n\n";
$textFileContents .=  "#\n# Source and Cagegory names\n#\n";
$textFileContents .=  "\n$sourceNames\n";
$textFileContents .=  "#\n# Feed names\n#\n";
$textFileContents .= "\n$textFile\n";

print LINKS $linksFileContents;
print NAMES $textFileContents;

close(NAMES);
close(LINKS);

use MD5;

print stderr "  + MD5 Links: (".MD5->hexhash($linksFileContents).")\n";
print stderr "  + MD5 Names: (".MD5->hexhash($textFileContents).")\n";
