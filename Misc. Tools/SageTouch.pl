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
    use Win32::FileTime;
 
 
    if (-d "$ARGV[0]")
    {
        opendir(SCANDIR,"$ARGV[0]");
        my @filesInDir = readdir(SCANDIR);
        foreach (@filesInDir)
        {
            if (/\.mpg$/)
            {
                print "  + Found: $_\n";
                push(@filesToCheck,$ARGV[0]."\\$_");
            }
        }
    }
    else
    {
        print "  + Found: $ARGV[0]\n";
        push(@filesToCheck,$ARGV[0]);
    }
 
 foreach $filename (@filesToCheck)
 {
    my $filetime = Win32::FileTime->new( $filename );
     print "- $filename\n";
     print "  + Original\n";
     printf( 
       "    - Created  : %4d/%02d/%02d %02d:%02d:%02d\n",
       $filetime->Create( 
           'year', 
           'month', 
           'day', 
           'hour', 
           'minute', 
           'second' 
       )
   ); 
   
      printf( 
       "    - Modified : %4d/%02d/%02d %02d:%02d:%02d\n",
       $filetime->Modify( 
           'year', 
           'month', 
           'day', 
           'hour', 
           'minute', 
           'second' 
       )
   );        
   

     my ($createdYear, $createdMonth, $createdDay, $createdHour, $createdMin, $createdSec) = $filetime->Create( 
         'year', 
         'month', 
         'day', 
         'hour', 
         'minute', 
         'second' 
     );
 
      my $ffmpegString  = "ffmpeg -dumpmetadata -v 2 -i \"$filename\" 2>&1";
      my $ffmpegOutput = `$ffmpegString`;    
      my @ffmpegOutput = split(/(\n|\r)/,$ffmpegOutput); 
      my $hour;
      my $min;
      my $sec; 
      my @days_in_month = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
      foreach (@ffmpegOutput)
      {
          if ( $_ =~ /Duration: ([0-9][0-9]):([0-9][0-9]):([0-9][0-9])/ )
          {
              print "  + Duration Line:     $_\n";
              $hour = $1;
              $min  = $2;
              $sec  = $3;
              print "    - totalHour = $hour ($createdHour)(".($createdHour + $hour).")\n";
              print "    - totalMin  = $min ($createdMin)(".($createdMin + $min).")\n";
              print "    - totalSec  = $sec ($createdSec)(".($createdSec + $sec).")\n";
          }
      }
      
      my $newSec = $createdSec + $sec;
      if ($newSec > 59)
      {
          $newSec -= 60;
          $min++;
      }
      
      my $newMin = $createdMin + $min;
      if ($newMin > 59)
      {
          $newMin -= 60;
          $hour++;
      }                
      
      my $newHour = $createdHour + $hour;
      if ($newHour > 23)
      {
          $newHour -= 24;
          $createdDay++;
      }
      
      if ($createdDay > $days_in_month[$createdMonth])
      {
          $createdDay = 1;
          $createdMonth++;
      }
      
      if ($createdMonth > 12)
      {
          $createdMonth = 1;
          $createdYear++;
      }
      
      printf("    - Updated  : %4d/%02d/%02d %02d:%02d:%02d\n", $createdYear, $createdMonth, $createdDay, $newHour, $newMin, $newSec); 
      `touch.exe /t $createdYear $createdMonth $createdDay $newHour $newMin $newSec $filename`;
      
    my $filetime = Win32::FileTime->new( $filename );
    print "  + Updated:\n";
   
     printf( 
       "    - Created  : %4d/%02d/%02d %02d:%02d:%02d\n",
       $filetime->Create( 
           'year', 
           'month', 
           'day', 
           'hour', 
           'minute', 
           'second' 
       )
   ); 
   
      printf( 
       "    - Modified : %4d/%02d/%02d %02d:%02d:%02d\n",
       $filetime->Modify( 
           'year', 
           'month', 
           'day', 
           'hour', 
           'minute', 
           'second' 
       )
   );        
  }
      
      
      


    
