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

        use Term::ReadKey;
        #ReadMode 4; # Turn off controls keys
        my $offset = 10;
        if (!($ARGV[0] eq ""))
        {
            $offset = $ARGV[0];
        }
        my $key;
        my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
        my $theTime = sprintf("%02d:%02d:%02d",$hour,$minute,$second); 
        my $startTime = time();
        my $finishTime = $startTime + ($offset); # Run for 6 hours
        
        print "$theTime : Running for $offset seconds...\n";
        while (time() < $finishTime)
        {
            while (not defined ($key = ReadKey(-1))) 
            {
                    # No key yet    
            }
            ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
            $year = 1900 + $yearOffset;
            $theTime = sprintf("%02d:%02d:%02d",$hour,$minute,$second);         
            print "$theTime : Get key ($key)\n";
        }
        ReadMode 0; # Reset tty mode before exiting

