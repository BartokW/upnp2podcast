#! /user/bin/perl
use MD5;


open(HTMLFILE,"$ARGV[0]");    

my $fileContents = "";

print stderr "  + Input File: $inputFile\n";

while(<HTMLFILE>)
{
    $fileContents .= $_;
}

print stderr "    - MD5: (".MD5->hexhash($fileContents).")\n";

