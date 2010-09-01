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
  use Encode qw(encode decode);
  use LWP::Simple qw($ua get head);
    
  $ua->timeout(30);
  $ua->agent( 'Mozilla/4.0 (compatible; MSIE 5.12; Mac_PowerPC)' );
  
  my $debug = 0;

  # Get the directory the script is being called from
  $executable = $0;
  $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;
  $executablePath = $`;
  $executableEXE  = $3;
  
  if (!(-d "$executablePath\\$executableEXE"))
  {
      mkdir("$executablePath\\$executableEXE");
  } 
   
  open(LOGFILE,">$executablePath\\$executableEXE.log");

  # Get Start Time
  my ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();
  my $year = 1900 + $yearOffset;
  $month++;
  my $dateString = sprintf("%04d%02d%02d",$year,$month,$dayOfMonth);
  $dateXMLString = sprintf("%04d-%02d-%02d",$year,$month,$dayOfMonth);

  # Code version
  my $codeVersion = "$executableEXE v1.1 (SNIP:BUILT)".($debug ? "(debug)" : "");
  
  my $invalidMsg .= "\n$codeVersion\n";
  $invalidMsg .= "\tUSAGE:";
  $invalidMsg .= "\t$executableEXE.exe /profile <Profile name>\n\n";

  my ($feed_begin, $feed_item, $feed_end) = populateFeedStrings();

  echoPrint("Welcome to $codeVersion!\n");
  echoPrint("  + Path: $executablePath\n");

  # Move arguments into user array so we can modify it
  my @parameters = @ARGV;

  # Initilize options data structures
  my %optionsHash;
  my @inputFiles;
  my @emptyArray = ();
  my %emptyHash  = ();
  my $zipCode = 98122;
  my $trailerRes = "720p";
  
  if (-s "$executablePath\\$executableEXE\\$executableEXE.zipcode")
  {
      if (open(ZIPCODE,"$executablePath\\$executableEXE\\$executableEXE.zipcode"))
      {
          $zipCode = <ZIPCODE>;
          echoPrint("  + Reading zipcode ($zipCode)\n");
      }
      close(ZIPCODE);
  }
  
  if (-s "$executablePath\\$executableEXE\\$executableEXE.trailerRes")
  {
      if (open(ZIPCODE,"$executablePath\\$executableEXE\\$executableEXE.trailerRes"))
      {
          $trailerRes = <ZIPCODE>;
          echoPrint("  + Reading prefered trailer resolution ($trailerRes)\n");
      }
      close(ZIPCODE);
  }
  
  # Setting cli options
  foreach (@parameters)
  {
      $parametersString .= "\"$_\" ";
  }
  
  setOptions(decode('ISO-8859-1' , $parametersString),\@emptyArray,\%optionsHash,\@inputFiles,\%emptyHash,"  ");
  
  if (exists $optionsHash{lc("setZipCode")})
  {
      $zipCode = $optionsHash{lc("setZipCode")};
      echoPrint("  + /setZipCode : Setting Zip Code ($zipCode)\n");
      if (open(ZIPCODE,">$executablePath\\$executableEXE\\$executableEXE.zipcode"))
      {
          print ZIPCODE $zipCode;
      }
      close(ZIPCODE);
  }
  
  if (exists $optionsHash{lc("setTrailerRes")})
  {
      $trailerRes = $optionsHash{lc("setTrailerRes")};
      echoPrint("  + /setTrailerRes : Setting prefered trailer resolution to ($trailerRes)\n");
      if (open(ZIPCODE,">$executablePath\\$executableEXE\\$executableEXE.trailerRes"))
      {
          print ZIPCODE $trailerRes;
      }
      close(ZIPCODE);
  }

  if (exists $optionsHash{lc("movie")} && exists $optionsHash{lc("getTrailers")})
  {
      echoPrint("  + /getTrailers : Getting Trailers for (".$optionsHash{lc("movie")}.")\n");
      my %theaterHash = getMovieHash($zipCode);
      getTrailers($optionsHash{lc("movie")}, \%theaterHash, $trailerRes);
      cleanCache(\%theaterHash);
      exit 0;
  }
  
  if (exists $optionsHash{lc("movie")} || exists $optionsHash{lc("listTheaters")})
  {
      echoPrint("  + /movie : Printing List of theaters showing specified movie\n");
      my %theaterHash = getMovieHash($zipCode);
      echoPrint("  ! GOT HASH\n");
      outputTheaters(\%theaterHash, $optionsHash{lc("movie")});
      cleanCache(\%theaterHash);
      exit 0;
  }
  
  echoPrint("  + Default : Printing out movies from last used zipcode\n");
  my %theaterHash = getMovieHash($zipCode);
  outputMovies(\%theaterHash, $optionsHash{lc("theater")});
  cleanCache(\%theaterHash);
  exit 0;
  
  sub getTrailers
  {      
      # Check .cache
      my $movie          = shift @_;
      my $theaterHashRef = shift @_;
      my $trailerRes     = shift @_;
      my $movieURL       = $movie;
      my $content        = "";
      
      echoPrint("  + Looking for cache: (".toWin32($movie).".trailerCache)\n");
      if (open(CACHE,"$executablePath\\$executableEXE\\".toWin32($movie).".trailerCache"))
      {
          my $cacheDate   = <CACHE>;
          $cacheDate   =~ /version=([0-9]+)/i;
          $cacheDate   = $1;
          echoPrint("    + Found cache ($cacheDate)($dateString)\n");
          if ($cacheDate == $dateString)
          {
              @searchCache = <CACHE>;
              $content     = "@searchCache";
              $useCache    = 1;
              echoPrint("    ! Using cache\n"); 
          }
          close(CACHE);
      }
      
      $movieURL =~ s/[^0-9a-zA-Z ]//gi; # Remove any non alpha-numeric chars
      $movieURL =~ s/ /-/g;            # Replace Spaces with  dashes
      
      if (!$useCache)
      {
          my $searchURL =  "http://www.hd-trailers.net/movie/".$movieURL."/";
          $content = decode('UTF-8', get $searchURL);
          $content =~ s/&amp;/&/g;
          $content =~ s/&quot;/"/g;#"
          $content =~ s/&nbsp;/ /g;
          $content =~ s/&middot;/-/g;
          $content =~ s/&#39;/'/g;
          $content =~ s/&#8206;/ /g;
          if (open(CACHE,">$executablePath\\$executableEXE\\".toWin32($movie).".trailerCache"))
          {
              print CACHE "version=$dateString\n";
              print CACHE "URL=$searchURL\n";
              print CACHE $content;  
          }
      }
      return decodeTrailerHTML($content, $movie, $theaterHashRef, $trailerRes);
  }
  
  sub decodeTrailerHTML
  {
      my $content        = shift @_;
      my $movieTitle     = shift @_;
      my $theaterHash    = shift @_;
      my $trailerRes     = shift @_;
      
      my $theater;
      my $movieHash;
      my @items;
      
      foreach $theater (keys %{$theaterHash})
      {   # get
      
          if ($theater =~ /numberOfScreens/)
          {   # Skip special key
              next;
          }
          echoPrint("Checking For Theater: (".$theater.")\n"); 
          foreach $movie (@{$theaterHash->{$theater}{movies}})
          {
              echoPrint("Checking For Movie: (".$movie->{movieName}.")\n");              
              if ($movie->{movieName} =~ /^\Q$movieTitle\E$/i)
              {   # Filter Based on movie
                  $movieHash = $movie;
                  last;
              }
          }
          if (defined  $movieHash)
          {
              last;
          }
      }
      
      echoPrint("! Found Movie: (".$movieHash->{movieName}.")\n"); 
      
      # Regexs
      $regExTrailerHTML    = 'class="bottomTableName"(.+)class="bottomTableDate"';
      $regExTrailerName    = '^[^>]+>([^<]+) ?';

      $regExTrailerLinkHTML = '(class="bottomTableResolution"><a href=[^>]+>[^<]+)';
      $regExTrailerLinkURL  = 'class="bottomTableResolution"><a href="([^"]+)'; 
      $regExTrailerLinkRes  = 'class="bottomTableResolution"><a href=[^>]+>([^<]+)';
      $regExTrailerLinkSrc  = '(apple|moviefone|yahoo|krunk4ever|myspacecdn)';
      
      #decode content
      $trailerBlock = matchShortest($content,$regExTrailerHTML);
      
       
      while (!($trailerBlock eq ""))
      {
          my $trailerName = "";
          $trailerBlock =~ /$regExTrailerName/;
          $trailerName = $1;
          echoPrint("  +  Found Trailer: ($trailerName)\n");
          
          if ($trailerBlock =~ /trailers.apple.com/)
          {
              echoPrint("    !  Skipping Apple Trailer!\n");
              $content =~ s/\Q$trailerBlock\E//gsm;
              $trailerBlock = matchShortest($content,$regExTrailerHTML);
              next;
          }
          
          $linksBlock     = $trailerBlock;
          $linkBlock      = matchShortest($linksBlock,$regExTrailerLinkHTML);
          while (!($linkBlock eq ""))
          {
              my $link    = "";
              my $linkRes = "";
              my $linkSrc = "Trailer";
              if ($linkBlock =~ /$regExTrailerLinkURL/)
              {
                  $link = $1;
                  echoPrint("    -  Found URL : ($link)\n"); 
              }
              
              if ($linkBlock =~ /$regExTrailerLinkRes/)
              {
                  $linkRes = $1; 
                  echoPrint("    -  Found Res : ($linkRes)\n");
              }
              
              if ($linkBlock =~ /$regExTrailerLinkSrc/)
              {
                  $linkSrc = $1;
                  #$regExTrailerLinkSrc  = '(apple|moviefone|yahoo|krunk4ever|myspacecdn)';
                  if ($linkSrc =~ /apple/i)
                  {
                      $linkSrc = "Apple";
                  }
                  elsif ($linkSrc =~ /moviefone/i)
                  {
                      $linkSrc = "Moviefone";
                  }
                  elsif ($linkSrc =~ /yahoo/i)
                  {
                      $linkSrc = "Yahoo";
                  }
                  elsif ($linkSrc =~ /krunk4ever/i)
                  {
                      $linkSrc = "Krunk4Ever";
                  }
                  elsif ($linkSrc =~ /myspacecdn/i)
                  {
                      $linkSrc = "Myspace";
                  }    
                    
                  echoPrint("    -  Found Src : ($linkSrc)\n");
              }
              
              if ($trailerRes eq "" || $trailerRes =~ /$linkRes/i)
              {
                      $trailerItem       = $feed_item;
                      $video             = toXML($link);
                      $title             = $trailerName;
                      $description       = " ";#$movieHash->{synopsis};
                      $thumbnail         = toXML($movieHash->{moviePoster});
                      $type              = "video/flv";
                      $date              = $linkSrc;
                      
                      $trailerItem =~ s/%%ITEM_TITLE%%/$title/g;
                      $trailerItem =~ s/%%ITEM_DATE%%/$date/g;
                      $trailerItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
                      $trailerItem =~ s/%%ITEM_URL%%/$video/g;
                      $trailerItem =~ s/%%ITEM_DUR%%/1/g;
                      $trailerItem =~ s/%%ITEM_SIZE%%/1/g;
                      $trailerItem =~ s/%%ITEM_TYPE%%/$type/g;
                      $trailerItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
                      $trailerItem =~ s/%%ITEM_DUR_SEC%%/1/g;
                      push(@items,$trailerItem);                  
              }

                           
              $linksBlock  =~ s/\Q$linkBlock\E//gsm;
              $linkBlock      = matchShortest($linksBlock,$regExTrailerLinkHTML); 
          }                   
          #echoPrint("\n");
          $content =~ s/\Q$trailerBlock\E//gsm;
          $trailerBlock = matchShortest($content,$regExTrailerHTML);
          #echoPrint(" TRAILER BLOCK:\n$content\n");  
      }
      
      if (exists $movieHash->{youtube})
      {
          $trailerItem       = $feed_item;
          $video             = toXML($movieHash->{youtube});
          $title             = "Official Trailer";
          $description       = " ";#$movieHash->{synopsis};
          $thumbnail         = toXML($movieHash->{moviePoster});
          $type              = "video/flv";
          $date              = "Youtube";
          
          $trailerItem =~ s/%%ITEM_TITLE%%/$title/g;
          $trailerItem =~ s/%%ITEM_DATE%%/$date/g;
          $trailerItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
          $trailerItem =~ s/%%ITEM_URL%%/$video/g;
          $trailerItem =~ s/%%ITEM_DUR%%/1/g;
          $trailerItem =~ s/%%ITEM_SIZE%%/1/g;
          $trailerItem =~ s/%%ITEM_TYPE%%/$type/g;
          $trailerItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
          $trailerItem =~ s/%%ITEM_DUR_SEC%%/1/g;
          unshift(@items,$trailerItem);
      }  
      
      
      my $opening = $feed_begin;
      
      $opening =~ s/%%FEED_TITLE%%/$movieHash->{movieName} Trailers/g;
      $opening =~ s/%%FEED_DESCRIPTION%%/$codeVersion @ARGV/g;
      print encode('UTF-8', $opening);
      foreach (@items)
      {
          if (!($_ eq ""))
          {
              print encode('UTF-8', $_);
          }
      }  
      print encode('UTF-8', $feed_end);
       
      return;      
  }
  
  sub cleanCache
  {
      my $theaterHash = shift @_;     
      my %existingFilesHash = scanDir("$executablePath\\$executableEXE","cache");

      echoPrint("  + Cleaning up old cache files\n");
      foreach $theater (keys %{$theaterHash})
      {
          foreach $movie (@{$theaterHash->{$theater}{movies}})
          {
              foreach $cacheFiles (keys %existingFilesHash)
              {
                  if (getFile($cacheFiles) eq toWin32($movie->{movieName}))
                  {
                      #echoPrint("  ! MATCH: ".getFile($cacheFiles)."\n");
                      delete $existingFilesHash{$cacheFiles};
                  }
              }
          }
      }
      
      foreach $staleFiles (keys %existingFilesHash)
      {
          echoPrint("    ! STALE: $staleFiles\n");
          $delString = "del \"$staleFiles\"";
          `$delString`;
      }      
  }
  
  sub outputTheaters
  {
      my $theaterHash     = shift @_;
      my $movieFilter     = shift @_;
      my @items = ();
      my ($feed_begin, $feed_item, $feed_end) = populateFeedStrings();
      my $movieList;
      my $feedType;
      my $feedLink;
      my $feedTitle = "Movie Theaters";
      my $trailerItem;
      
      echoPrint("  + Outputing Theaters ($movieFilter)\n");
      
      foreach $theater (sort {$theaterHash->{$b}{screens} <=> $theaterHash->{$a}{screens}} keys %{$theaterHash})
      {
          if ($theater =~ /numberOfScreens/)
          {   # Skip special key
              next;
          }
          echoPrint("    - Theater : $theater (".@{$theaterHash->{$theater}{movies}}.")(".$theaterHash->{$theater}{screens}.")\n");
          $movieList =  "";
          $feedLink = toXML('external,"'.$executable.'",/theater||'.$theater);
          my $foundMovie = 0;
          foreach $movie (@{$theaterHash->{$theater}{movies}})
          {              
              if ($movie->{movieName} =~ /^\Q$movieFilter\E$/i && defined $movieFilter)
              {   # Filter Based on movie
                  echoPrint("      + Movie   \t: ".$movie->{movieName}."\n");
                  foreach $key (sort keys %{$movie})
                  {
                      if ($key =~ /movieName/i)
                      {
                          next;
                      }
                      echoPrint("        - $key\t: ".$movie->{$key}."\n");
                  }
                  
                  $feedLink = toXML('external,"'.$executable.'",/theater||'.$theater);
                  $movieList = $movie->{movieTimes};
                  $feedType  = 'image/jpeg';
                  $foundMovie = 1;
                  
                  # Make subcat for trailer
                  $trailerItem       = $feed_item;
                  $video             = toXML('external,"'.$executable.'",/movie||'.$movie->{movieName}.'||/getTrailers');
                  $title             = 'Check for trailers...';
                  $description       = "Search the internet for available trailers.";
                  $thumbnail         = toXML($movie->{moviePoster});
                  $type              = "sagetv/subcategory";
                  
                  $trailerItem =~ s/%%ITEM_TITLE%%/$title/g;
                  $trailerItem =~ s/%%ITEM_DATE%%/ /g;
                  $trailerItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
                  $trailerItem =~ s/%%ITEM_URL%%/$video/g;
                  $trailerItem =~ s/%%ITEM_DUR%%/1/g;
                  $trailerItem =~ s/%%ITEM_SIZE%%/1/g;
                  $trailerItem =~ s/%%ITEM_TYPE%%/$type/g;
                  $trailerItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
                  $trailerItem =~ s/%%ITEM_DUR_SEC%%/1/g;                   

                  last; 
              }
              elsif (!(defined $movieFilter))
              {   # Filter Based on movie
                  echoPrint("      + Movie   \t: ".$movie->{movieName}."\n");
                  foreach $key (sort keys %{$movie})
                  {
                      if ($key =~ /movieName/i)
                      {
                          next;
                      }
                      echoPrint("        - $key\t: ".$movie->{$key}."\n");
                  }
                  $movieList .= $movie->{movieName}.", ";
                  $feedType  = 'sagetv/subcategory';       
              }
          }
          
          if ((defined $movieFilter && $foundMovie) || !(defined $movieFilter))
          {   # If we found it or we're not filtering
              my $address = $theaterHash->{$theater}{address};
              $address =~ s/&/and/g;
              $address =~ s/ /+/g;
              my $mapThumb = "http://maps.google.com/maps/api/staticmap?center=".$address."&zoom=15&size=300x300&sensor=false&markers=color:blue|".$address;
              my $mapFull  = "http://maps.google.com/maps/api/staticmap?center=".$address."&zoom=16&size=640x640&sensor=false&markers=color:blue|".$address;
              
              if (defined $movieFilter)
              {
                  $feedLink  = toXML($mapFull);
                  $feedTitle = $movieFilter; 
              }
              
              $movieList =~ s/, $//g;          
    
              $newItem           = $feed_item;
              $video             = $feedLink;
              $title             = $theater;
              $description       = $movieList;
              $thumbnail         = toXML($mapThumb);
              $type              = $feedType;
              
              $newItem =~ s/%%ITEM_TITLE%%/$title/g;
              $newItem =~ s/%%ITEM_DATE%%/$theaterHash->{$theater}{phone}/g;
              $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
              $newItem =~ s/%%ITEM_URL%%/$video/g;
              $newItem =~ s/%%ITEM_DUR%%/1/g;
              $newItem =~ s/%%ITEM_SIZE%%/1/g;
              $newItem =~ s/%%ITEM_TYPE%%/$type/g;
              $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
              $newItem =~ s/%%ITEM_DUR_SEC%%/1/g; 
              push(@items,$newItem);
          }
 
      }
      
      if (defined $trailerItem)
      {   # Put trailer at the top
          unshift(@items,$trailerItem);
      }
      
      my $opening = $feed_begin;
      
      $opening =~ s/%%FEED_TITLE%%/$feedTitle/g;
      $opening =~ s/%%FEED_DESCRIPTION%%/$codeVersion @ARGV/g;
      print encode('UTF-8', $opening);
      foreach (@items)
      {
          if (!($_ eq ""))
          {
              print encode('UTF-8', $_);
          }
      }  
      print encode('UTF-8', $feed_end);
  }

  sub outputMovies
  {
      my $theaterHash       = shift @_;
      my $theaterFilter     = shift @_;
      my %movieList = ();
      my @items = ();
      my ($feed_begin, $feed_item, $feed_end) = populateFeedStrings();
      my $feedTitle = "Movies";
            
      if (defined $movieFilter)
      {
          $feedTitle = $theaterFilter;    
      }
      
      echoPrint("  + Outputing Movies ($theaterFilter)\n");
      
      foreach $theater (sort {$theaterHash->{$b}{screens} <=> $theaterHash->{$a}{screens}} keys %{$theaterHash})
      {
          if ($theater =~ /numberOfScreens/)
          {   # Skip special key
              next;
          }
          echoPrint("    - Theater : $theater (".@{$theaterHash->{$theater}{movies}}.")(".$theaterHash->{$theater}{screens}.")\n");
          if (!($theater =~ /^\Q$theaterFilter\E$/i) && defined $theaterFilter)
          {   # Filter Based on theater
              next;
          }
          foreach $movie (sort {$theaterHash->{numberOfScreens}{$b->{movieName}} <=> $theaterHash->{numberOfScreens}{$a->{movieName}}} @{$theaterHash->{$theater}{movies}})
          {
              echoPrint("      + Movie   \t: ".$movie->{movieName}." (".$theaterHash->{numberOfScreens}{$movie->{movieName}}.")\n");
              foreach $key (sort keys %{$movie})
              {
                  if ($key =~ /movieName/i)
                  {
                      next;
                  }
                  echoPrint("        - $key\t: ".$movie->{$key}."\n");
              }
              
              if (!exists $movieList{$movie->{movieName}})
              {
                  $movieList{$movie->{movieName}} = 1;
                  $newItem = $feed_item;
                  $video             = toXML('external,"'.$executable.'",/movie||'.$movie->{movieName}.'||/listTheaters');
                  $title             = $movie->{movieName};
                  $description       = (defined $theaterFilter ? $movie->{movieTimes} : $movie->{synopsis});
                  $thumbnail         = $movie->{moviePoster};
                  $type              = 'sagetv/subcategory';
                  $info              = $movie->{info};
                  
                  $newItem =~ s/%%ITEM_TITLE%%/$title/g;
                  $newItem =~ s/%%ITEM_DATE%%/$info/g;
                  $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
                  $newItem =~ s/%%ITEM_URL%%/$video/g;
                  $newItem =~ s/%%ITEM_DUR%%/1/g;
                  $newItem =~ s/%%ITEM_SIZE%%/1/g;
                  $newItem =~ s/%%ITEM_TYPE%%/$type/g;
                  $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
                  $newItem =~ s/%%ITEM_DUR_SEC%%/1/g; 
                  push(@items,$newItem);    
              }
          }
      }
      
      #my ($feed_begin, $feed_item, $feed_end, $textOnlyDescription) = populateFeedStrings();
      my $opening = $feed_begin;
      $opening =~ s/%%FEED_TITLE%%/$feedTitle/g;
      $opening =~ s/%%FEED_DESCRIPTION%%/$codeVersion @ARGV/g;
      print encode('UTF-8', $opening);
      foreach (@items)
      {
          if (!($_ eq ""))
          {
              print encode('UTF-8', $_);
          }
      }  
      print encode('UTF-8', $feed_end);
  }
  
  sub getMovieHash
  {      
      # Check .cache
      my $zipCode = shift @_;
      my $useCache = 0;
      my $content  = "";
      
      echoPrint("  + Looking for cache: (".toWin32($zipCode).".locCache)\n");
      if (open(CACHE,"$executablePath\\$executableEXE\\".toWin32($zipCode).".locCache"))
      {
          my $cacheDate   = <CACHE>;
          $cacheDate   =~ /version=([0-9]+)/i;
          $cacheDate   = $1;
          echoPrint("    + Found cache ($cacheDate)($dateString)\n");
          if ($cacheDate == $dateString)
          {
              @searchCache = <CACHE>;
              $content     = "@searchCache";
              $useCache    = 1;
              echoPrint("    ! Using cache\n"); 
          }
          close(CACHE);
      }
      
      if (!$useCache)
      {
          my $searchURL =  "http://www.google.com/movies?near=".toURL($zipCode)."&hl=en";
          $content = decode('UTF-8', get $searchURL).decode('UTF-8', get $searchURL."&start=10");
          $content =~ s/&amp;/&/g;
          $content =~ s/&quot;/"/g;#"
          $content =~ s/&nbsp;/ /g;
          $content =~ s/&middot;/-/g;
          $content =~ s/&#39;/'/g;
          $content =~ s/&#8206;/ /g;
          if (open(CACHE,">$executablePath\\$executableEXE\\".toWin32($zipCode).".locCache"))
          {
              print CACHE "version=$dateString\n";
              print CACHE "URL=$searchURL\n";
              print CACHE $content;  
          }
      }
      return decodeMovieHTML($content);
  }
  
  sub decodeMovieHTML
  {
      my $content = shift @_;
      
      # Clean out links to buy tickets
      $content =~ s/<a href="\/url\?q=http:\/\/www.fandango.com[^>]*>([0-9]+:[0-9]+(am|pm)?)<\/a>/$1/gm; #"
      
      # Regexs
      $regExTheatersHTML    = '(link_1_theater.*</div></div>)';
      $regExTheatersName    = 'link_1_theater[^>]*>([^<]*)';
      $regExTheatersAddress = 'link_1_theater[^>]*>[^<]*</a></h2><div class=info>([^<\-]*) ';
      $regExTheatersNumber  = 'link_1_theater[^>]*>[^<]*</a></h2><div class=info>[^<\-]* - ([^<]*)';
      
      $regExTheatersMoviesHTML  = '(link_1_theater.*)link_1_theater';; 
      $regExTheatersMovieHTML   = '(movies\?near=[^>]+mid=[^>]+>.*)</div></div>';
      
      $regExMoviesTitle         = '(movies\?near=[^>]*)">([^<]*)';
      #$regExMoviesPoster        = 'movie_poster" src="([^"]+)"'; 
      $regExMoviesDetails       = 'movies\?near=[^>]*>[^<]*</a></div><span class=info>([^<]*)'; 
      $regExMoviesDur           = '([0-9]+hr[^<]*[0-9]+min)';
      $regExMoviesRated         = 'Rated ([^&]*)';
 
      #decode content
      $theaterBlock = matchShortest($content,$regExTheatersHTML);
      my %theaterHash = ();  
      while (!($theaterBlock eq ""))
      {
          $rv = matchShortest($theaterBlock,$regExTheatersName);
          my $theater = $rv;
          echoPrint("  +  Found Theater: ($theater)\n");
          
          $rv = matchShortest($theaterBlock,$regExTheatersAddress);
          my $address = $rv;
          echoPrint("    -  Address    : ($address)\n");
          
          $rv = matchShortest($theaterBlock,$regExTheatersNumber);
          my $phoneNumber = $rv;
          echoPrint("    -  Number     : ($phoneNumber)\n");
          
          $moviesBlock     = $theaterBlock;
          $movieBlock      = matchShortest($moviesBlock,$regExTheatersMovieHTML);
          
          #echoPrint("    -  Movie Block     : ($movieBlock)\n");
          my $numberOfMovies = 0;
          
          my @moviesAtTheater = ();
          while (!($movieBlock eq ""))
          {
              $numberOfMovies++;
              my %movieHash = ();
              if ($movieBlock =~ /$regExMoviesTitle/)
              {
                  $movieHash{movieName}      = $2;
                  $theaterHash{numberOfScreens}{$movieHash{movieName}}++;
                  $detailPage = $1;
              }
              
              if ($movieBlock =~ /$regExMoviesDetails/)
              {
                  $details = $1;
              }

              if ($details    =~ /$regExMoviesDur/)
              {
                  $movieHash{movieDuration}        = $1;
              }
              
              if ($details    =~ /$regExMoviesRated/)
              {
                  $movieHash{movieRating}      = $1;
              }
                            
              if ($movieBlock =~ /class=times>(<[^>]+>)?([^<]*)/)
              {
                  $movieHash{movieTimes}  = "$2";
              }
              
              echoPrint("      + Movie : (".$movieHash{movieName}.")(".$movieHash{movieRating}.")(".$movieHash{movieDuration} .")\n");
              echoPrint("        + Times   : (".$movieHash{movieTimes}.")\n");
              #echoPrint("        + Details : ($detailPage)\n");
              
              getMovieDetails($detailPage,\%movieHash); # Poster, Trailer, Synopsis
              #getTrailers($movieHash{movieName});
              
              push(@moviesAtTheater,\%movieHash);
              
              $moviesBlock =~ s/\Q$movieBlock\E//gsm;
              $movieBlock = matchShortest($moviesBlock,$regExTheatersMovieHTML);
          }
          $theaterHash{$theater}{movies}   = \@moviesAtTheater;
          $theaterHash{$theater}{address}  = $address;
          $theaterHash{$theater}{phone}    = $phoneNumber;
          $theaterHash{$theater}{screens}  = $numberOfMovies;
                   
          #echoPrint("\n");
          $content =~ s/\Q$theaterBlock\E//gsm;
          $theaterBlock = matchShortest($content,$regExTheatersHTML);   
      } 
      return %theaterHash;      
  }
  
  sub getMovieDetails
  {
      my $detailPage   = shift @_;
      my $movieHashRef = shift @_;
      my $content;
      my $useCache = 0;
      #echoPrint("        + Looking for cache: (".toWin32($movieName).".cache)\n");
      if (open(CACHE,"$executablePath\\$executableEXE\\".toWin32($movieHashRef->{movieName}).".cache"))
      {
          #echoPrint("          - Found cache\n");
          $useCache    = 1;
          @searchCache = <CACHE>;
          $content     = "@searchCache";
          close(CACHE);
      }
      
      if (!$useCache)
      {
          my $movieURLName = $movieName;
          $movieURLName =~ s/ /+/g;  
          my $searchURL =  "http://www.google.com/$detailPage";
          echoPrint("        + Detail URL: $searchURL\n");
          $content = decode('UTF-8', get $searchURL);
          $content =~ s/&amp;/&/g;
          $content =~ s/&quot;/"/g;#"
          $content =~ s/&nbsp;/ /g;
          $content =~ s/&middot;/-/g;
          $content =~ s/&#39;/'/g;
          $content =~ s/&#8206;/ /g;
          if (open(CACHE,">$executablePath\\$executableEXE\\".toWin32($movieHashRef->{movieName}).".cache"))
          {
              print CACHE encode('UTF-8',$content);  
          }
      }
      decodeMovieDetails($content, $movieHashRef);
  }
  
  sub decodeMovieDetails
  {
      my $content      = shift @_;
      my $movieHashRef = shift @_;
      
      # Regexs
      $regExSynopsisHTML    = '<div class=syn>(.*)<span id=LessAfterSynopsisSecond0';
      $regExSynopsisText    = '<span id=MoreAfterSynopsisFirst0.*id=SynopsisSecond0>';
      $regExSynopsisHTML2    = '<div class=syn>([^<]*)<';
      
      $regExTrailerHTML     = '<([^<>]+)>See trailer';
      $regExTrailerLink     = 'href="([^"]*)"';
      $regExTrailerCache    = 'Trailer=="([^"]*)"';
      
      if ($content =~ /$regExSynopsisHTML/gsm)
      {
          my $result = $1;
          $result =~ s/$regExSynopsisText//gsm;         
          $movieHashRef->{synopsis} = $result;
          echoPrint("        + Synopsis: ".$movieHashRef->{synopsis}."\n");
              
      }
      elsif ($content =~ /$regExSynopsisHTML2/gsm)
      {
          $movieHashRef->{synopsis} = $1;
          echoPrint("        + Synopsis (2): ".$movieHashRef->{synopsis}."\n");
      }
      
      $regExPoster       = '(movies/image\?tbn=[^&]*)&';
      if ($content =~ /$regExPoster/)
      {
          $movieHashRef->{moviePoster} = "http://www.google.com/$1";
          echoPrint("        + Poster: ".$movieHashRef->{moviePoster}."\n"); 
      }

      $regExYoutube      = 'http:\/\/www.youtube.com\/v\/([^&]+)';
      if ($content =~ /$regExYoutube/)
      {
          $movieHashRef->{youtube} = "http://www.youtube.com/watch?v=$1";
          echoPrint("        + Youtube : ".$movieHashRef->{youtube}."\n");
      }
      
      $regExInfo     = '<div class=info>[^<0-9]+([^<]+)';
      if ($content =~ /$regExInfo/)
      {
          $movieHashRef->{info} = "$1";
          $movieHashRef->{info} =~ /[^a-zA-Z]+$/;
          $movieHashRef->{info} = $`;
          #echoPrint("        + Info : ($&)($1)\n");
          echoPrint("        + Info : ".$movieHashRef->{info}."\n");
      }
      
      #if ($content =~ /$regExTrailerCache/gsm)
      #{
      #    $trailer = $1;
      #    echoPrint("        + Trailer: $trailer\n");   
      #}
      #elsif ($content =~ /$regExTrailerHTML/gsm)
      #{
      #    my $result = $1;
      #    $result =~ /$regExTrailerLink/; 
      #    my $searchURL =  $1;
      #    echoPrint("        + Trailer URL: $searchURL\n");
      #    $content = decode('UTF-8', get $searchURL);
      #    $content =~ s/&amp;/&/g;
      #    $content =~ s/&quot;/"/g;#"
      #    $content =~ s/&nbsp;/ /g;
      #    $content =~ s/&middot;/-/g;
      #    $content =~ s/\\x3a/:/g;
      #    $content =~ s/\\x2f/\//g;
      #    $content =~ s/\\x2f/\//g;
      #    if ($content =~ /http[^']*\.flv/) #'
      #    {
      #        $trailer = $&;
      #        echoPrint("        + Trailer: $trailer\n");
      #    }
      #         
      #}
  }
  
  ##### Overwrite echoPrint for compatability
    sub echoPrint
    {
        my ($stringToPrint) = @_;
        $utf8String = encode('UTF-8', $stringToPrint);
        print stderr $utf8String;
        print LOGFILE $utf8String;
    }   
      
  ##### Populate an options Hash
    sub setOptions
    {
        my ($optionsString,$optionsArray,$optionsHash,$inputFiles,$commandHash,$logSpacing) = @_; 
        my @newOptions;
        my $key;
        my $noOverwrite = 0;
        my $parameterString = "";
        
        echoPrint("$logSpacing+ Parsing switches\n");
        echoPrint("$logSpacing  - optionsString: $optionsString\n");
        
        if (@{$optionsArray}) { echoPrint("$logSpacing  - optionsArray: @{$optionsArray}\n"); }
        if ($optionsString)
        {
            @newOptions= splitWithQuotes($optionsString," ");
        }
        @newOptions = (@{$optionsArray},@newOptions,);
        if (exists $commandHash->{lc("noOverwrite")})
        {
            $noOverwrite = 1;
            echoPrint("$logSpacing    + No Overwritting!\n");
            
        }
        while (@newOptions != 0)
        {
            if ($newOptions[0] =~ m#^/ERROR$#)
            {   # Message from profile that an unrecoverable error has occured
                $reason = "Error reported from profile file: $newOptions[1]";
                echoPrint("    ! $reason\n");
                echoPrint("    ! Moving onto next file");
                $optionsHash->{lc("wereDoneHere")} = $reason;
                $errorLevel++;
                return;
            }
            elsif ($newOptions[0] =~ m#^/(!?)([a-zA-Z0-9_]+)#i)
            {   # Generic add sub string
                echoPrint("$logSpacing  - Adding to to options Hash\n");
                $getVideoInfoCheck = $1;
                $key = $2;
                echoPrint("$logSpacing    + Key: $key ($optionsHash->{lc($key)})\n");
                if (exists $optionsHash->{lc($key)} && $noOverwrite)
                {
                    if ((!($newOptions[1] =~ m#^[/%]# || $newOptions[1] eq "") || $newOptions[1] =~ m#^/.*/#))
                    {
                        echoPrint("$logSpacing      ! Already Exists, skipping: (".$newOptions[0]." ".$newOptions[1].")\n");
                        shift(@newOptions);    # Remove next parameter also
                    }
                    else
                    {
                        echoPrint("$logSpacing      ! Already Exists, skipping: (".$newOptions[0].")\n");
                    }
                }
                elsif (exists $optionsHash->{lc("no".$key)})
                {
                    if ((!($newOptions[1] =~ m#^[/%]# || $newOptions[1] eq "") || $newOptions[1] =~ m#^/.*/#))
                    {
                        echoPrint("$logSpacing      ! Found /no$key, skipping (".$newOptions[0]." ".$newOptions[1].")\n");
                        shift(@newOptions);    # Remove next parameter also
                    }
                    else
                    {
                        echoPrint("$logSpacing      ! Found /no$key, skipping (".$newOptions[0].")\n");
                    }
                }
                else
                {
                    $optionsHash->{lc($key)} = "";
                    if ((!($newOptions[1] =~ m#^[/%]# || $newOptions[1] eq "") || $newOptions[1] =~ m#^/.*/#))
                    {   # If the next parameter data for switch
                        $optionsHash->{lc($key)} = $newOptions[1];
                        echoPrint("$logSpacing    + Value: $optionsHash->{lc($key)}\n");
                        $parameterString .= " $newOptions[0] \"$newOptions[1]\"";
                        shift(@newOptions);    # Remove next parameter also
                        if ($getVideoInfoCheck eq "!")
                        {
                            getVideoInfo($optionsHash->{lc($key)},"     ",$optionsHash);
                        }
                        
                    }
                    else
                    {
                        $parameterString .= " $newOptions[0]";
                    }                 
                }
    
            }
            elsif ($newOptions[0] =~ m#^%([a-zA-Z0-9_]+)#i)
            {   # Generic remove sub string
                echoPrint("$logSpacing    + Found Option ($newOptions[0])\n");
                echoPrint("$logSpacing      - Removing custom switch from hash \n");
                $key = $1;
                echoPrint("$logSpacing      -  Key: $key\n");
                delete $optionsHash->{lc($key)};
            }
            elsif ($inputFiles && (-e encode('ISO-8859-1',$newOptions[0]) || -d encode('ISO-8859-1',$newOptions[0])))
            {
                push(@{$inputFiles}, $newOptions[0]);
                echoPrint("$logSpacing  - Adding Inputfile: $newOptions[0]\n");
            }
            else
            {
                echoPrint("$logSpacing    ! couldn't understand ($newOptions[0]), throwing it away\n");
            }
            shift(@newOptions); 
        }
        #echoPrint("! Returing: ($parameterString)\n");
        return $parameterString;
    }
##### Split a line of text ignoring quoted text
    sub splitWithQuotes
    {
        my ($originalLine,$split) = @_;
        # Handle Quotes
        my @splitWithQuotes = ();
        my %quoteHash = {};
        my $quoteNum = 0;
        while($originalLine =~ /"([^"]*)"/)#"
        {
            $quoteHash{$quoteNum} = $1;
            $originalLine = $`."quote$quoteNum".$';  
            $quoteNum++;
        }
        @splitWithQuotes = split(/"[^"]"/,$originalLine); #"
        @splitWithQuotes = split(/$split/,$originalLine);
        for($i=0;$i<@splitWithQuotes;$i++)
        {
            if ($splitWithQuotes[$i] =~ /quote([0-9]+)$/)
            {
                $splitWithQuotes[$i] = "$quoteHash{$1}";
                echoPrint("        - Replacing $&: $quoteHash{$1}\n",2);
            }
        }
        return @splitWithQuotes;
    }
    
    sub matchShortest
    {
        my ($string,$regEx,$rvRef) = @_;
        my $shortest;
        my $length = length $string;
        my $i = 0;
        
        while ($string =~ /(?=$regEx)/gsm) {
            $i++;
            $m_len = length $1;
            #echoPrint("  + $m_len ($length)\n");
            # save the match if it's shorter than the last one
            ($shortest, $length) = ($1, $m_len) if $m_len < $length;
            #last;
        }
        $$rvRef = $shortest;
        #echoPrint("SHORTEST - $shortest\n");
        return $shortest;
    }


  sub populateFeedStrings()
  {
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    my $year = 1900 + $yearOffset;
    $month++;
    my $feed_begin = <<FEED_BEGIN;
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
  xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel> 
    <title><![CDATA[%%FEED_TITLE%%]]></title> 
    <description><![CDATA[$codeVersion @ARGV]]></description> 
    <language>en-us</language> 
    <itunes:summary><![CDATA[%%FEED_DESCRIPTION%%]]></itunes:summary> 
    <itunes:subtitle><![CDATA[%%FEED_DESCRIPTION%%]]></itunes:subtitle> 
FEED_BEGIN

    my $feed_item = <<'PODCAST_ITEM';
    <item> 
      <title><![CDATA[%%ITEM_TITLE%%]]></title> 
      <description><![CDATA[%%ITEM_DESCRIPTION%%]]></description> 
      <pubDate>%%ITEM_DATE%%</pubDate> 
      <itunes:subtitle><![CDATA[%%ITEM_DESCRIPTION%%]]></itunes:subtitle>
      <itunes:duration>%%ITEM_DUR%%</itunes:duration>
      <enclosure url="%%ITEM_URL%%" length="%%ITEM_SIZE%%" type="%%ITEM_TYPE%%" /> 
      <media:content duration="%%ITEM_DUR_SEC%%" medium="video" fileSize="%%ITEM_SIZE%%" url="%%ITEM_URL%%" type="%%ITEM_TYPE%%"> 
       <media:title><![CDATA[%%ITEM_TITLE%%]]></media:title> 
        <media:description><![CDATA[%%ITEM_DESCRIPTION%%]]></media:description> 
        <media:thumbnail url="%%ITEM_PICTURE%%"/> 
      </media:content> 
    </item> 
PODCAST_ITEM

    my $feed_end = <<'FEED_END';
  </channel> 
</rss> 
FEED_END

    return ($feed_begin, $feed_item, $feed_end);
  }
  
  sub toXML
  {
      my ($string) = @_;
      $string =~ s/\&/&amp;/g;
      $string =~ s/"/&quot;/g; #"
      $string =~ s/</&lt;/g;
      $string =~ s/>/&gt;/g;
      $string =~ s/'/&apos;/g;  #'
      return $string;
  }
  
  sub toWin32
  {
      my $replaceString = shift;
      my $illCharFileRegEx = "('|\"|\\\\|/|\\||<|>|:|\\*|\\?|\\&|\\;|`)";
      $replaceString =~ s/$illCharFileRegEx//g;
      return $replaceString;
  }
  
  sub toURL
  {
      my $string = shift @_;
      $string =~ s/ /+/g;
      return $string;
  }
  
##### Scan a directory and return an array of the matching files
    sub scanDir
    {
        my ($inputFile, $fileFilter) = @_;
        my %files = ();
        my @dirs  = ();
        my $file;
        my $dir;
        $inputFile =~ s/\"//g;
        $inputFile =~ s/(\\|\/)$//g;
        #echoPrint("    - Scanning Directory: $inputFile ($fileFilter)\n");
        opendir(SCANDIR,"$inputFile");
        my @filesInDir = readdir(SCANDIR);
        if (!(-e "$inputFile\\mediaScraper.skip") && $inputFile !~ /.workFolder$/i )
        {
            foreach $file (@filesInDir)
            {
                #echoPrint("-> $file\n");
                next if ($file =~ m/^\./);
                next if !($file =~ m/($fileFilter)$/ || -d "$inputFile\\$file");       
                if (-d "$inputFile\\$file" && !($file =~ m/VIDEO_TS$/)) { push(@dirs,"$inputFile\\$file"); }
                else { $files{"$inputFile\\$file"} = 1; } 
            }
            foreach $dir (@dirs)
            {
                %files = (%files,scanDir($dir,$fileFilter));     
            }
        }
        else
        {
            echoPrint("      + Found .skip, ignoring Directory\n");
        }
        #echoPrint("!!! @files\n");
        return %files;  
    }
    
sub getFullFile
    {   # (G:\videos\filename).avi
        my ( $fileName ) = @_;
        my $rv = getPath($fileName).$FS.getFile($fileName);
        return $rv;
    }
    
    sub getFile
    {   # G:\videos\(filename).avi
        my ( $fileName ) = @_;
        my $rv = "";
        
        if ($fileName =~ m#(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#)
        {
            $rv = $2;
        }
        elsif ($fileName =~ m#[^\\/]*$#)
        {
          $rv = $&;      
        }
    
        return $rv;
    }
    
    sub getFileWExt
    {   # G:\videos\(filename.avi)
        my ( $fileName ) = @_;
        my $rv = getFile($fileName).getExt($fileName);    
        return $rv;
    }
    
    sub getPath
    {   # (G:\videos\)filename.avi
        my ( $fileName ) = @_;
        $fileName .= ".txt";  # Always append an extention
        my $rv = "";
        if ($fileName =~ m#([^\\/]*)$#)
        {
            $rv = $`;
        }
      
        $rv =~ s#(\\|/)$##;
        return $rv;
    }
    
    sub getParentDir
    {   # (C:\some\path)\name\
        my $fileName = shift;
        my $rv = getPath(getPath($fileName));
        return $rv;
    } 
  
  exit;

      
      
  
  
  
  
