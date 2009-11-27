#! /user/bin/perl
use MD5;

# Get the directory the script is being called from
$executable = $0;
$executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;;
$executablePath = $`;

opendir(FEEDS,$executablePath);
@feedFiles = readdir(FEEDS);

@builtIn = ('aRecent','Hulu','Netflix','zExtras','zzPlayONSettings');

foreach (@feedFiles)
{
    if (/.properties$/)
    {
        $fileName = $`;
        $fileName =~ /_([A-Z]+)$/i;
        $plugInName = $1;
        $fileContents = "";
        open(HTMLFILE,"$executablePath\\$_"); 
        print stderr "  + Input File: $fileName\n";
        print stderr "    - PlugIn: $plugInName\n";
        @isPlugIn = grep(/$plugInName/, @builtIn);
        $printPlugIn = "";
        if (!@isPlugIn)
        {
            $printPlugIn = $plugInName;
            print stderr "      + Not Built-in\n";    
        }
        while(<HTMLFILE>)
        {
            if (/# Version=([0-9]+)/)
            {
                $date = $1;
                print stderr "    - Vesion: $plugInName\n";
            }
            $fileContents .= $_;
        }
        print stderr "    - MD5: ".MD5->hexhash($fileContents)."\n";
        $feedFileText .= "$fileName.properties,$date,".MD5->hexhash($fileContents).",http://upnp2podcast.googlecode.com/svn/trunk/upnp2podcast/Feeds/$fileName.properties,$printPlugIn\n"  
    }
}

open(FEEDFILE,">FeedVersions.txt");
print FEEDFILE $feedFileText;

