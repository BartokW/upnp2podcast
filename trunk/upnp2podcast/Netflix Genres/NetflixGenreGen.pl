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
%children   = ();

$inputFile = $parameters[0];

open(HTMLFILE,"$inputFile");    
print "Input File: $inputFile\n";

$inputFile =~ /\\?([^\\]*)\./;
$inputFileName = $1;

print "Input File Name: $inputFileName\n";  

while (<HTMLFILE>)
{
    $i++;
    if (/^ *[+-] \\([^(]*)\(([0-9]+)\)[ !]*\(([0-9]+)\)/)
    {
        $line = $_;
        $line =~ s/&amp\;/&/g;
        $line =~ /^ *[+-] \\([^(]*)\(([0-9]+)\)[ !]*\(([0-9]+)\)/;
        $name     = $1;
        $depth    = $2;
        $children = $3;
        chop($name);
        if ($depth <= 3 && $name !~ /([A-Z]-[A-Z]|Page [0-9]|Browse Genre)/)
        {     
            for ($j=0;$j<$depth;$j++)
            {
                print "  ";
            }
            print "+ $name ($depth) ($children) \n";
            if ($depth == 2)
            {
                $mainGenre = $name;
            }
            else
            {
          			push(@{$categories{$mainGenre}},$name);                  
            }
            $children{$name} = $children; 
        }
    }
}

$linksFile      = "";
$textFile       = "";
$feedNames      = "";
$sourceNames    = "";
$rowsCols       = "";
$subCatagorys   = "";
$customSources  = "CustomSources=xPodcastBrowseNetflix\n";

$sourceNames .= "\nSource/xPodcastBrowseNetflix/LongName=Browse Netflix\n";
$sourceNames .= "Source/xPodcastBrowseNetflix/ShortName=Browse Netflix\n";

foreach $category (sort { lc ($a) cmp lc($b) } keys %categories)
{
    print "  + Genre: ($category)\n";
    $categoryStripped = $category;
    $categoryStripped =~ s/[ .:&!]//g; 
    #print "    - Keys : ".(keys %{$categories{$category}})."\n";
    $catPodcastName = "Netflix_By_".$categoryStripped;
    
		$categoryRegEx       = $category;
		$categoryRegEx       =~ s/&/&amp;/g; #"
		$categoryRegEx       =~ s/[^a-zA-Z0-9]/./g; #"
		
		$subCatagorys .= "\nxFeedPodcastCustom/$catPodcastName=xPodcastBrowseNetflix;xURLNone\n";
		$subCatagorys .= "$catPodcastName/IsCategory=true\n";
		$subCatagorys .= "$catPodcastName/CategoryName=xPodcast_".$catPodcastName."\n";
		
		$sourceNames .= "\nCategory/$catPodcastName/LongName=$category\n";
		$sourceNames .= "Category/$catPodcastName/ShortName=$category\n";
		$sourceNames .= "Source/xPodcast_$catPodcastName/LongName=$category\n";
		$sourceNames .= "Source/xPodcast_$catPodcastName/ShortName=$category\n";
    
    foreach $show (@{$categories{$category}})
    {
        print "    - Sub: ($show)\n";

    		$showStripped    = $show;
    		$showStripped    =~ s/[ .:&\-()\$'"!]//g; #"
    		
    		$showRegEx       = $show;
		    $showRegEx       =~ s/&/&amp;/g; #"
    		$showRegEx       =~ s/[^a-zA-Z0-9]/./g; #"
     
    		$textFile  .= "\nCategory/Netflix_Genre_".$showStripped."/LongName=$show\n";
    		$textFile  .= "Category/Netflix_Genre_".$showStripped."/ShortName=$show\n\n";
       
        $linksFile .=   "\nxFeedPodcastCustom/Netflix_Genre_".$showStripped."=xPodcast_$catPodcastName";    		
        $linksFile .=   ";external,UPnP2Podcast,PlayOn:Netflix:Browse Genres:^".$categoryRegEx."\$:^".$showRegEx."\$:";
        
        if ($children{$show}  == 5 || $children{$show} == 9)
        {
            $linksFile .= "+3\n";   
        }
        else
        {
            $linksFile .= "+2\n"; 
        }
    }		
}

$linksFile .= "\nxFeedPodcastCustom/aaNetflixQueue=xPodcastBrowseNetflix;external,UPnP2Podcast,PlayOn:Netflix:Instant Queue:Queue Top 50:+2\n";
$linksFile .= "\nxFeedPodcastCustom/abNetflixNewArrivals=xPodcastBrowseNetflix;external,UPnP2Podcast,PlayOn:Netflix:New Arrivals:New Movies:+3\n";
$linksFile .= "\nxFeedPodcastCustom/acNetflixMovieTrailers=xPodcastBrowseNetflix;external,UPnP2Podcast,PlayOn:Hulu:Film Trailers:+2\n";

$textFile  .= <<EXTRAS;
Category/aaNetflixQueue/LongName=Instant Queue
Category/aaNetflixQueue/ShortName=Instant Queue

Category/abNetflixNewArrivals/LongName=New Arrivals
Category/abNetflixNewArrivals/ShortName=Netflix New Arrivals

Category/acNetflixMovieTrailers/LongName=Movie Tailers
Category/acNetflixMovieTrailers/ShortName=Movie Tailers
EXTRAS

open (LINKS,">CustomOnlineVideoLinks_UPnP2Podcast_Netflix.properties");
open (NAMES,">CustomOnlineVideoUIText_UPnP2Podcast_Netflix.properties"); 

($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$theTime = sprintf("%04d%02d%02d",$year,($month+1),$dayOfMonth);

$linksFileContents .= "# Version=$theTime\n\n";
$linksFileContents .= "\n#\n# Top Level Categories\n#\n";
$linksFileContents .= "CustomSources=xPodcastBrowseNetflix\n";
$linksFileContents .= "\n#\n# Rows and Colums\n#\n";
$linksFileContents .= "\n$rowsCols\n";
$linksFileContents .= "\n#\n# Declare Sub Catagories\n#\n";
$linksFileContents .= "\n$subCatagorys\n";
$linksFileContents .= "\n#\n# Declare Links\n#\n";
$linksFileContents .= "\n$linksFile\n";

$textFileContents .= "# Version=$theTime\n\n";
$textFileContents .= "\n#\n# Source and Cagegory names\n#\n";
$textFileContents .= "\n$sourceNames\n";
$textFileContents .= "\n#\n# Feed names\n#\n";
$textFileContents .= "\n$textFile\n";

print LINKS $linksFileContents;
print NAMES $textFileContents;

close(NAMES);
close(LINKS);

use MD5;

print stderr "  + MD5 Links: (".MD5->hexhash($linksFileContents).")\n";
print stderr "  + MD5 Names: (".MD5->hexhash($textFileContents).")\n";
