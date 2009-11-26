#! /user/bin/perl
#
    
# Get the directory the script is being called from
$executable = $0;
$executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;;
$executablePath = $`;

$seriesPage  = "D:\\TestVideos\\Terminator.html";
$episodePage = "D:\\TestVideos\\Terminator.ep1.html";

$fileName = "TerminatorTheSarahConnorChronicles-BrothersofNablus-3994527.mpg";
$fileName =~ /([^\-]*)-([^\-]*)/;
$series  = $1;
$episode = $2;
print "Series:  $series\n";
print "Episode: $episode\n";

open(SERIES,"$seriesPage");

@seriesPage = <SERIES>;

foreach $line (@seriesPage)
{
    if ($line =~ /([0-9]+) - ([0-9]+)/)
    {
        $seasonNum = $1;
        $episodeNum = $2;
        $remainder = $';
        $remainder =~ /lid=[0-9]*">(.*)<\/a>/;#"
        $showTitle = $1;
        $remainder = $';
        $remainder =~ /([0-9]{4}\-[0-9]{2}\-[0-9]{2})/;
        $origAirDate = $1;
        print "$seasonNum x $episodeNum - $showTitle ($origAirDate)\n";
    }
}

open(SERIES,"$episodePage");

@episodePage = <SERIES>;

foreach $line (@episodePage)
{
    if ($line =~ /name="FirstAired" value="([^"]*)/)
    {
        $firstAired = $1;
    }
    elsif ($line =~ /name="GuestStars" value="([^"]*)/)
    {
        $guestStars = $1;
        @guestStars = split(/\|/,$guestStars);
    }
    elsif ($line =~ /name="Director" value="([^"]*)/)
    {
        $director = $1;
        @director = split(/\|/,$director);
    }
    elsif ($line =~ /name="Writer" value="([^"]*)/)
    {
        $writers = $1;
        @writers = split(/\|/,$writers);
    }
    elsif ($line =~ /name="ProductionCode" value="([^"]*)/)
    {
        $productionCoded = $1;
    }
    elsif ($line =~ /"Overview_7" style="display: inline">(.*)<\/textarea>/)
    {
        $description = $1;
    }
}
print "Airdate    : $firstAired\n";
print "Guest Stars: @guestStars\n";
print "Director   : @director\n";
print "Writers    : @writers\n";
print "Production : $productionCoded\n";
print "Description: $description\n";



#<tr><td class="even"><a href="/?tab=episode&seriesid=[0-9]*&seasonid=[0-9]*&id=[0-9]*&amp;lid=[0-9]*">1 - 1</a></td><td class="even"><a href="/?tab=episode&seriesid=80344&seasonid=27988&id=332184&amp;lid=7">Pilot</a></td><td class="even">2008-01-13</td><td class="even"><img src="/images/checkmark.png" width=10 height=10> &nbsp;</td></tr>



