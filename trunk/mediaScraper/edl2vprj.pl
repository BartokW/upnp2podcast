##    profile2bat.pl - Helper script for converting profiles into batch files
##    Copyright (C) 2006    Scott Zadigian  zadigian(at)gmail(dot)com
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

# Get the directory the script is being called from
$edlFile = $ARGV[0];
$edlFile =~ /\.[a-zA-Z]+$/;
$edlBase = $`;
$outputFile = $ARGV[1];

if ($ARGV[1] eq "")
{   # If no output file is specified put it right next to the edl
    $outputFile = $edlBase.".VPrj";
}

print "Converting:\n";
print "Video: $edlBase.mpg\n";
print "EDL: $edlFile\n";
print "VPrj: $outputFile\n\n";

if (open(EDL,"$edlFile"))
{
    open(VPRJ,">$outputFile");
    print VPRJ "<Version>2\n";
    print VPRJ "<Filename>$edlBase.mpg\n";
    while (<EDL>)
    {
        chomp;
        if(/([0-9.]+)\s+([0-9.]+)/)
        {
            print "$1,$2\n";
            print VPRJ "<Cut>".($1*(10000000)).":".($2*10000000)."\n";
        }
    }
}

close(VPRJ);
close(EDL);





























