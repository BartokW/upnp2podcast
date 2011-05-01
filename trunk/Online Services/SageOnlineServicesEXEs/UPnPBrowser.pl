#!/usr/bin/perl
## 
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
#
  #use strict;
##### Import libraries
  use Encode qw(encode decode);
  use utf8;
  use Digest::MD5 qw(md5 md5_hex md5_base64);
  use Net::UPnP::ControlPoint;
  use Net::UPnP::AV::MediaServer;
  
  my $obj = Net::UPnP::ControlPoint->new();
  my $mediaServer = Net::UPnP::AV::MediaServer->new();

  $FS = "\\";
  $binPath = "win32";
  if ($^O =~ /linux/i)
  {
      $linux = 1;
      $FS = "/";
      $binPath = "linux";
  }

  # Get the directory the script is being called from
  $executable = $0;
  $executablePath = getPath($executable);
  $executableEXE  = getFile($executable);
  $workPath       = "$executablePath".$FS."$executableEXE";
  
  $atomicParsleyEXE = $executablePath.$FS."UPnPBrowser".$FS.$binPath.$FS."AtomicParsley.exe";
  
  $outputPathName = "";
   
  open(LOGFILE,">$executablePath/$executableEXE.log");

  # Get Start Time
  my ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();
  my @startTime = ( $startSecond, $startMinute, $startHour);  # Get Start Time
  
  my $year = 1900 + $yearOffset;
  $month++;
  my $dateString = sprintf("%04d%02d%02d",$year,$month,$dayOfMonth);
  $dateXMLString = sprintf("%04d-%02d-%02d",$year,$month,$dayOfMonth);

  # Code version
  my $codeVersion = "$executableEXE v1.6 (SNIP:BUILT)";
  
  my $invalidMsg .= "\n$codeVersion\n";
  $invalidMsg .= "\tUSAGE:";
  $invalidMsg .= "\t$executableEXE.exe /profile <Profile name>\n\n";

  my ($feed_begin, $feed_item, $feed_end) = populateFeedStrings();
  
  echoPrint("Welcome to $codeVersion! (".localtime()."\n");
  echoPrint("  + Path: $executablePath\n");
  
  if (!(-d "$executablePath".$FS."$executableEXE"))
  {
      echoPrint("  + Making .cache Directory: ($executablePath".$FS."$executableEXE)\n");
      {
          mkdir("$executablePath".$FS."$executableEXE");
      }
  }
  
  # Find SageTV Directory and check version
  my @checkPaths = ($executablePath,
                    getPath($executablePath),
                    'C:/Program Files/SageTV/SageTV',
                    'C:/Program Files (x86)/SageTV/SageTV',
                    'C:/Program Files (x64)/SageTV/SageTV',
                    '/opt/sagetv/server/');
  
  $sageDir = $executablePath;                
  foreach (@checkPaths)
  {
      echoPrint("  + Checking: ($_)\n");
      if (-e "$_/Sage.properties")
      {
          $sageDir = $_;
          last;
      }
  }
  
  if (open(PROPERTIES,"$sageDir/Sage.properties"))
  {
      echoPrint("  + Found SageTV Dir: ($sageDir)\n");
      while (<PROPERTIES>)
      {
          chomp;
          if (/^stv_update\/last_version_in_sys_msg=/)
          {
              $stvVersions = $';
          }
    
          if (/^version=/)
          {
              $sageVersion = $';
          }         
      }
      close(PROPERTIES);
      echoPrint("    - SageTV Version: ($sageVersion)\n");
      echoPrint("    - STV Version   : ($stvVersions)\n");
  }
  else
  {
      echoPrint("  ? Warning, couldn't find SageTV Directory\n");    
  }

  # Move arguments into user array so we can modify it
  my @parameters = @ARGV;

  # Initilize options data structures
  my %optionsHash = ();
  my @inputFiles = ();
  my @emptyArray = ();
  my %emptyHash  = ();
  my $feedTitle  = "UPnP Browser";
  
  %playOnFileHash = ();
  %existingFilesHash = ();
  
  my @content_list = ();
  
  my %presets = ();
  if (-s "$executablePath".$FS."$executableEXE".$FS."$executableEXE.presets")
  {   # Read in Presets      
      if (open(PRESETS,"$executablePath".$FS."$executableEXE".$FS."$executableEXE.presets"))
      {   
          <PRESETS> =~ /Version=([0-9]+)/i;
          my $presetVersion = $1;
          echoPrint("  + Reading Presets ($presetVersion)\n");
          
          while(<PRESETS>)
          {
              chomp;
              if (/^(.*):::(.*)/)
              {
                  echoPrint("    - $1 :  ($2)\n");    
                  $presets{lc($1)} = $2;
              }
          }
      }
  }
  
  my @toScrape = ();
  if (-s "$executablePath".$FS."$executableEXE".$FS."$executableEXE.toScrape")
  {
      if (open(TOSCRAPE,"$executablePath".$FS."$executableEXE".$FS."$executableEXE.toScrape"))
      {   
          while(<TOSCRAPE>)
          {
              chomp;
              if (!($_ =~ /^#/))
              {
                  @toScrape = (@toScrape,$_);
              }
          }
          close(TOSCRAPE);
      }  
  }

  
  if (@parameters == 1 &&  $parameters[0] =~ /:/)
  {
      echoPrint("  + Detected v1 parameter string, converting to v2 (/serach $parameters[0])\n");
      $parameters[1] = $parameters[0];
      $parameters[0] = "/search";       
  }

  # Setting cli options
  $parametersString = "";
  foreach (@parameters)
  {
      $parametersString .= "\"$_\" ";
  }
  
  setOptions(decode('ISO-8859-1' , $parametersString),\@emptyArray,\%optionsHash,\@inputFiles,\%emptyHash,"  ");
  
  if (exists $optionsHash{lc("preset")})
  {   # Add in presets
      if (exists $presets{lc($optionsHash{lc("preset")})})
      {
          echoPrint("  + Using Preset ".$optionsHash{lc("preset")}." (".$presets{lc($optionsHash{lc("preset")})}.")\n"); 
          setOptions(decode('ISO-8859-1' , $presets{lc($optionsHash{lc("preset")})}),\@emptyArray,\%optionsHash,\@inputFiles,\%emptyHash,"    ");              
      }
      else
      {
          echoPrint("  ! Couldn't find Preset ".$optionsHash{lc("preset")}." (".$presets{lc($optionsHash{lc("preset")})}.")\n");               
      }
  }
  
  $myMovies = 0;
  if (exists $optionsHash{lc("myMovies")})
  {
      $myMovies = 1;    
  }
  
  if (exists $optionsHash{lc("cleanScrapeMode")})
  {
      if (exists $optionsHash{lc("outputDir")}   && 
          !($optionsHash{lc("outputDir")} eq "") &&
          -d $optionsHash{lc("outputDir")})
      {   # Add in presets
          $workPath = $optionsHash{lc("outputDir")};
          cleanWorkPath($workPath);
      }
      else
      {
          echoPrint("  ! /cleanScrapeMode but /outputDir (".$optionsHash{lc("outputDir")}.") isn't valid, exiting!\n");
          exit;
      }  
  }
  
  if (exists $optionsHash{lc("scrapeMode")})
  {
      $optionsHash{lc("device")} = "PlayOn";
      if (exists $optionsHash{lc("outputDir")}   && 
          !($optionsHash{lc("outputDir")} eq "") &&
          -d $optionsHash{lc("outputDir")})
      {   # Add in presets
          $workPath = $optionsHash{lc("outputDir")};
      }
      else
      {
          echoPrint("  ! /scrapeMode but /outputDir (".$optionsHash{lc("outputDir")}.") isn't valid, exiting!\n");
          exit 1;
      }

      %existingFilesHash = scanDir($workPath,"playon");
  }

  my $serverWait = (exists $optionsHash{lc("serverSearchTimeout")} ? $optionsHash{lc("serverSearchTimeout")} : 1);
  echoPrint("  + /serverSearchTimeout : (".$serverWait.")\n");
  
  if (exists $optionsHash{lc("search")})
  {
      echoPrint("  + Breaking up /search into options\n");
      my @v1sting = split(/:/, $optionsHash{lc("search")});
      
      $optionsHash{lc("device")} = shift @v1sting;
      echoPrint("    - /device : (".$optionsHash{lc("device")}.")\n");
      
      my $v1Depth = pop @v1sting;
      $v1Depth =~ /\+([0-9])/;
      $optionsHash{lc("depth")} = $1-1;
      echoPrint("    - /depth : (".$optionsHash{lc("depth")}.")\n");
      
      my $v1path = $optionsHash{lc("device")}."/"; 
      foreach (@v1sting)
      {
          $v1path .= $_."/";   
      }
      $optionsHash{lc("path")} = $v1path;
      echoPrint("    - /path  : (".$optionsHash{lc("path")}.")\n");
  }

  if (@parameters == 0 || exists $optionsHash{lc("mainMenu")})
  {
      echoPrint("  + /mainMenu : Printing available UPnP Servers\n");
      my @dev_list = $obj->search(st =>'upnp:rootdevice', mx => $serverWait);

      if (opendir(SCANDIR,"$executablePath/$executableEXE"))
      {
          my @filesInDir = readdir(SCANDIR);
          echoPrint("  + Checking for .cache files not found in search\n");
          foreach $fileName (@filesInDir)
          {
              if ($fileName =~ /$executableEXE\.(.*)\.cache/)
              {
                  $nameToCheck = $1;
                  $found = 0;
                  foreach $server (@dev_list)
                  {
                      if (toWin32($server->getfriendlyname()) eq $nameToCheck)
                      {
                          $found = 1;
                          last;    
                      }        
                  }
                  
                  if ($found == 0)
                  {   # Add to Dev List
                      echoPrint("    - Found ($fileName), adding to list\n");
                      if (open(UPNPCACHE,"$executablePath/$executableEXE/$fileName"))
                      {                      
                          @cacheFull = <UPNPCACHE>;
                          $cacheText  = "@cacheFull";
                          $cacheText  =~ /=======================/;
                          $post_con = $';
                          $dev = Net::UPnP::Device->new();              
               		        $dev->setssdp($cacheText);
              		        $dev->setdescription($post_con);
              		        @dev_list = (@dev_list, $dev);
          		        }
          		        close(UPNPCACHE);
                  }
              }
          }
      }
      
  
      foreach (@dev_list)
      {
          chomp;
          echoPrint("    - Device: ".$_->getfriendlyname()."(".$_->getdevicetype().")\n");
          echoPrint("      + Geneating Cache: ($executableEXE.".$_->getfriendlyname().".cache)\n");
          $dev = $_;
          if (open(UPNPCACHE,">$executablePath/$executableEXE/$executableEXE.".toWin32($_->getfriendlyname()).".cache"))
          {
              print UPNPCACHE $dev->getssdp()."=======================".$dev->getdescription();
          }
          close(UPNPCACHE);
      }
  
      my (@items, $opening, $newItem, $video, $title, $description, $type, $thumbnail);
  
      $opening = $feed_begin;
      $opening =~ s/%%FEED_TITLE%%/$feedTitle/g;
      $opening =~ s/%%FEED_DESCRIPTION%%/$feedTitle/g;
      
      foreach (@dev_list)
      {
          if ($_->getfriendlyname() eq "" || (exists $optionsHash{lc("filter")} && $_->getfriendlyname() =~ /$optionsHash{lc("filter")}/))
          {
              next;
          }
          $newItem = $feed_item;
          $video             = toXML('external,"'.$executable.'",/device||'.$_->getfriendlyname()."||/uid||0||/path||".$_->getfriendlyname());
          $title             = $_->getfriendlyname();
          $description       = $_->getfriendlyname()."  (EXE_TIME)";
          $thumbnail         = '';
          $type              = 'sagetv/subcategory';
          
          $newItem =~ s/%%ITEM_TITLE%%/$title/g;
          $newItem =~ s/%%ITEM_DATE%%/$dateXMLString/g;
          $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
          $newItem =~ s/%%ITEM_URL%%/$video/g;
          $newItem =~ s/%%ITEM_DUR%%/1/g;
          $newItem =~ s/%%ITEM_SIZE%%/1/g;
          $newItem =~ s/%%ITEM_TYPE%%/$type/g;
          $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
          $newItem =~ s/%%ITEM_DUR_SEC%%/1/g; 
          push(@items,$newItem);            
      }
      
      # Add in Long Search
      $newItem = $feed_item;
      $video             = toXML('external,"'.$executable.'",/serverSearchTimeout||30||/mainMenu');
      $title             = "Find More Servers...";
      $description       = "Re-run the UPnP server search with an extra long timeout to find more servers (~5 minutes).";
      $thumbnail         = '';
      $type              = 'sagetv/subcategory';
      
      $newItem =~ s/%%ITEM_TITLE%%/$title/g;
      $newItem =~ s/%%ITEM_DATE%%/$dateXMLString/g;
      $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
      $newItem =~ s/%%ITEM_URL%%/$video/g;
      $newItem =~ s/%%ITEM_DUR%%/1/g;
      $newItem =~ s/%%ITEM_SIZE%%/1/g;
      $newItem =~ s/%%ITEM_TYPE%%/$type/g;
      $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
      $newItem =~ s/%%ITEM_DUR_SEC%%/1/g; 
      push(@items,$newItem);
      
      my $execTime = executionTime(@startTime);      
      print encode('utf8', $opening);
      foreach (@items)
      {
          if (!($_ eq ""))
          {
              $_ =~ s/EXE_TIME/($execTime)/g;
              print encode('utf8', $_);
          }
      }  
      print encode('UTF-8', $feed_end);
      echoPrint("    + Execution time: $execTime\n");         
      exit 0;
  }
  
  my $foundDevice = 0;
  if (exists $optionsHash{lc("device")})
  {
      my $lookingFor = $optionsHash{lc("device")};
      echoPrint("  + Looking for UPnP Server: ".$lookingFor."\n");
      if (opendir(SCANDIR,"$executablePath/$executableEXE"))
      {
          my @filesInDir = readdir(SCANDIR);
          foreach $cacheFile (@filesInDir)
          {
              if ($cacheFile =~ /$executableEXE\.(.+)\.cache/)
              {
                  $cacheServer = $1;
                  if ($cacheServer =~ /$lookingFor/i)
                  {
                      echoPrint("    - Found Cache ($cacheFile)\n");
                      if (open(UPNPCACHE,"$executablePath/$executableEXE/$cacheFile"))
                      {
                          $foundDevice = 1;
                          @cacheFull = <UPNPCACHE>;
                          $cacheText  = "@cacheFull";
                          $cacheText  =~ /=======================/;
                          $post_con = $';
                          $dev = Net::UPnP::Device->new();              
               		        $dev->setssdp($cacheText);
              		        $dev->setdescription($post_con);
              		        $mediaServer->setdevice($dev);
                          close(UPNPCACHE);
                          
                          # Try getting the top level to verify that .cache is real
                          echoPrint("       - Checking if cache is valid...\n");
                          @content_list = $mediaServer->getcontentlist(ObjectID => 0);
                          if ($content_list[0] =~ /^!!/)
                          {  # Cache is bad, delete it and run full serach
                              $foundDevice = 0;
                              `del "$executablePath".$FS."$executableEXE".$FS."$cacheFile"`;
                              echoPrint("       ! Cache is stale, deleting and doing full search ($cacheFile)\n");
                          }
                  		    last;
                      }
                      close(UPNPCACHE);

                  }
              }
          }
      }
          
      if ($foundDevice == 0)
      {
          my @dev_list = $obj->search(st =>'upnp:rootdevice', mx => $serverWait);
          foreach (@dev_list)
          {
              chomp;
              echoPrint("    - Device: ".$_->getfriendlyname()."(".$_->getdevicetype().")\n");
              if ($_->getfriendlyname() =~ /\Q$lookingFor\E/i)
              {
                  $dev = $_;
                  if (open(UPNPCACHE,">$executablePath/$executableEXE/$executableEXE.".toWin32($_->getfriendlyname()).".cache"))
                  {
                      print UPNPCACHE $dev->getssdp()."=======================".$dev->getdescription();
                  }
                  close(UPNPCACHE);
                  $foundDevice = 1;
                  echoPrint("      + Found $lookingFor\n"); 
                  $mediaServer->setdevice($dev);
                  last;
              }
          }
      }
      
      if (!$foundDevice)
      {
          echoPrint("  ! Error! Couldn't find UPnP Device: ($lookingFor)\n");
          my $opening;
          my @items = ();
          my ($newItem, $video, $title, $description, $type, $thumbnail);
      
      
          $opening = $feed_begin;
          $opening =~ s/%%FEED_TITLE%%/UPnP Browser (Error!)/g;
          $opening =~ s/%%FEED_DESCRIPTION%%/UPnP Browser (Error!)/g;
          
          $newItem = $feed_item;
          $video             = toXML('external,'.$executable.',/serverSearchTimeOut||30||/search||'.$optionsHash{lc("search")});
          $title             = "UPnP Browser Error!";
          $description       = "UPnP Browser Error!  Unable to find UPnP Device ($lookingFor), select this to try a longer server serach. (~5 minutes)"." (EXE_TIME)";
          $thumbnail         = '';
          $type              = 'sagetv/textonly';
          
          $newItem =~ s/%%ITEM_TITLE%%/$title/g;
          $newItem =~ s/%%ITEM_DATE%%/$dateXMLString/g;
          $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
          $newItem =~ s/%%ITEM_URL%%/$video/g;
          $newItem =~ s/%%ITEM_DUR%%/1/g;
          $newItem =~ s/%%ITEM_SIZE%%/1/g;
          $newItem =~ s/%%ITEM_TYPE%%/$type/g;
          $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
          $newItem =~ s/%%ITEM_DUR_SEC%%/1/g; 
          push(@items,$newItem);        

          my $execTime = executionTime(@startTime);      
          print encode('UTF-8', $opening);
          foreach (@items)
          {
              if (!($_ eq ""))
              {
                  $_ =~ s/EXE_TIME/$execTime/g;
                  print encode('utf8', $_);
              }
          }  
          print encode('utf8', $feed_end);
          echoPrint($execTime);           
          exit 0;
      }
      
      # Try Looping here
      my @items = ();
      if (exists $optionsHash{lc("scrapeMode")})
      {
          @PlayONPaths = (@toScrape);
      }
      else
      {
          @PlayONPaths = ($optionsHash{lc("path")});
      }     
      
      foreach $playONPath (@PlayONPaths)
      {
          if (exists $optionsHash{lc("scrapeMode")})
          {   # Pull depth off end of path for scrape mode
              if ($playONPath =~ m#/\+([0-9]+) *$#)
              {
                  $playONPath = $`;
                  $optionsHash{lc("depth")} = $1;
                  echoPrint("  + Setting depth: ($1)($playONPath)\n");
              }
              else
              {
                  $optionsHash{lc("depth")} = 2;
                  echoPrint("  + Setting depth: DEFAULT (2)($playONPath)\n");
              }
          }
          
          echoPrint("LOOPING: $playONPath\n");
          $feedTitle = $playONPath;
          $skipping = 0;

          if (!($playONPath eq "") && $foundDevice == 1 && !(exists $optionsHash{lc("uid")}))
          {  # if all we get is a path, serach the tree for the uid
              $optionsHash{lc("uid")} = 0;
              $optionsHash{lc("isContainer")} = 0;
              my @splitString = split(/\//,$playONPath);
              $optionsHash{lc("path")}   = $optionsHash{lc("device")};
              echoPrint("  + GetContent from: ".(shift @splitString)." (@splitString)\n");
              
              foreach $lookingFor (@splitString)
              {         
                  echoPrint("    - Looking for : ".$lookingFor."\n");          
                  @content_list = $mediaServer->getcontentlist(ObjectID => $optionsHash{lc("uid")});
                  my $found  = 0;
                  foreach $content (@content_list)
                  {
                      echoPrint("      + ".($content->iscontainer() ? "/" : "")."".$content->gettitle()." (".$content->getid().")\n");
                      if ($content->gettitle() =~ /$lookingFor/i)
                      {
                          echoPrint("        - Found! : $`(".$&.")$'\n");
                          $optionsHash{lc("uid")}   = $content->getid();
                          $optionsHash{lc("path")} .= "".$FS."".$content->gettitle();
                          $optionsHash{lc("isContainer")} = $content->iscontainer(); 
                          $found = 1;
                          #last;    
                      }    
                  }
                                
                  if ($found == 0)
                  {
                      echoPrint("    ! Couldn't find : ".$lookingFor."!\n");
                      $skipping = 1;
                      last;
                  }
              }              
          }
          
          if (exists $optionsHash{lc("uid")} && $foundDevice == 1 && $skipping != 1)
          {              
              @items    = (@items, addItems($mediaServer, 
                                            $optionsHash{lc("uid")}, 
                                            $optionsHash{lc("path")}, 
                                            $optionsHash{lc("device")},
                                            $optionsHash{lc("filter")}, 
                                            !(exists $optionsHash{lc("disableSubcats")}),
                                            exists $optionsHash{lc("scrapeMode")}, 
                                            (exists $optionsHash{lc("depth")} ? $optionsHash{lc("depth")} : 0) ));             
          }
          
          # Clear UID for looping
          delete $optionsHash{lc("uid")};
      }  
               
      if (exists $optionsHash{lc("outputPath")})
      {
          print encode('utf8', $outputPathName);
      }
      elsif (exists $optionsHash{lc("scrapeMode")})
      {
          # Find existing PlayON Files
          @existingFiles = scanDir($workPath,"playon");
          %playOnFileHashCopy = %playOnFileHash;
          echoPrint("  + Running in scrape mode, adding/removing content\n");
          if (!(exists $optionsHash{lc("addOnly")}))
          {   # Only add videos
              foreach $exitingFile (sort(keys %existingFilesHash))
              {                                           
                  echoPrint("    - Missing : ($exitingFile)(".getFile($exitingFile)." (".(-s getFullFile($exitingFile)).")\n"); 
                  if (-e $exitingFile && $exitingFile =~ /\.playon$/ && (-s getFullFile($exitingFile)) < 40000)
                  {   # never delete *anything* over 400kb                 
                      $rmString = encode('ISO-8859-1', "del /Q \"$exitingFile\"");
                      #echoPrint("    - rm : ($rmString)\n");
                      `$rmString`;
                      $rmString = encode('ISO-8859-1', "del /Q \"".getFullFile($exitingFile)."\"");
                      #echoPrint("    - rm : ($rmString)\n");
                      `$rmString`;
                      
                      if (-e getFullFile(encode('ISO-8859-1', $exitingFile)).".properties")
                      {
                          $rmString = encode('ISO-8859-1', "del /Q \"".getFullFile($exitingFile).".properties"."\"");
                          #echoPrint("    - rm : ($rmString)\n");
                          `$rmString`;
                      }
                      
                      #Check to see if folder is empty
                      my $checkFolder = getPath($exitingFile);
                      opendir(SCANDIR,"$checkFolder");
                      my @filesInDir = readdir(SCANDIR);
                      #echoPrint("      - Checking if folder is empty : ($checkFolder)\n");
                      $depthProtection = 0;
                      while(@filesInDir == 2 && $depthProtection < 4)
                      {
                          $rmString = encode('ISO-8859-1', "rmdir /Q \"$checkFolder\"");
                          echoPrint("      + Folder empty, deleting : ($rmString)\n");
                          `$rmString`;
                          
                          close(SCANDIR);
                          $checkFolder = getPath($checkFolder);
                          opendir(SCANDIR,"$checkFolder");
                          @filesInDir = readdir(SCANDIR);
                          #echoPrint("      + Checking if folder is empty : ($checkFolder)\n");
                          $depthProtection++;                          
                      }
                      close(SCANDIR);
                      
                  }        
              }
          }
          
          foreach $newFile (sort(keys %playOnFileHashCopy))
          {
              echoPrint("    - Added : (".getFile($newFile).")\n");
              
              my $tempNewFile =  $newFile;
              my @pathsToMake = ();
              while(!(-d getPath($tempNewFile)))
              {
                  unshift(@pathsToMake,getPath($tempNewFile));
                  $tempNewFile = getPath($tempNewFile);
              }
              foreach $path (@pathsToMake)
              {           
                  $mkdirString = "mkdir \"$path\"";
                  echoPrint("      + mkdir : ($mkdirString)\n");
                  `$mkdirString`; 
              }
                              
              $baseVideo = "playon.m4v";

              $playOnPath  = "PlayOn,,,".$playOnFileHashCopy{$newFile};              
              #echoPrint("    - PathString : ($playOnPath)\n");
              if ($playOnPath =~ /PlayON:([^:]*):/i)
              {
                  $playOnType = "PlayOn,$1"; 
              }
              else
              {
                  $playOnType  = "PlayOn,Other"; 
              }
                            
              if (!(-e $newFile))
              {   # Only do it if the file doesn't already exist       
                  $copyString = encode('ISO-8859-1', ($linux == 1 ? "cp" : "copy")." \"$executablePath".$FS."$executableEXE".$FS."$baseVideo\" \"".$newFile."\"");
                  ##echoPrint("    - copying : ($copyString)\n");
                  `$copyString`;
                  
                  if (open(PROPERTIES,">$newFile.playon"))
                  {   # Make properties file   
                      print PROPERTIES $playOnPath;
                      close PROPERTIES;                  
                  }   

                  $tagString = encode('ISO-8859-1', ($linux == 1 ? "cp" : "\"$atomicParsleyEXE\"")." \"$newFile\" --overWrite --copyright \"$playOnType\" --comment \"$playOnPath\"");
                  #echoPrint("    - Tagging : ($tagString)\n");
                  `$tagString`;
              }
          }                  
      }
      else
      {
          my $opening = $feed_begin;
          $opening =~ s/%%FEED_TITLE%%/$feedTitle/g;
          $opening =~ s/%%FEED_DESCRIPTION%%/UPnP Browser ($lookingFor)/g;   
          print encode('ISO-8859-1', toANSII($opening));
          foreach (@items)
          {
              if (!($_ eq ""))
              {
                  $_ =~ s/EXE_TIME/$execTime/g;
                  $_ = toANSII($_);
                  utf8::downgrade($_);
                  print encode('ISO-8859-1', toANSII($_));
              }
          }  
          print encode('ISO-8859-1', toANSII($feed_end));
      }
      #Exposé
      my $execTime = executionTime(@startTime);   
      echoPrint($execTime);  
      exit 0;
  }
  
  ##### Overwrite echoPrint for compatability
    sub echoPrint
    {
        my ($stringToPrint) = @_;
        #$stringToPrint = encode('utf8', $stringToPrint);
        print stderr $stringToPrint;
        print LOGFILE $stringToPrint;
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
            if ($newOptions[0] =~ m#^/(!?)([a-zA-Z0-9_]+)#i)
            {   # Generic add sub string
                echoPrint("$logSpacing  - Adding to to options Hash\n");
                $getVideoInfoCheck = $1;
                $key = $2;
                echoPrint("$logSpacing    + Key: $key (".(exists $optionsHash->{lc($key)} ? $optionsHash->{lc($key)} : "" ).")\n");
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
        return $parameterString;
    }
##### Split a line of text ignoring quoted text
    sub splitWithQuotes
    {
        my ($originalLine,$split) = @_;
        # Handle Quotes
        my @splitWithQuotes = ();
        my %quoteHash = ();
        my $quoteNum = 0;
        echoPrint("          + Original ($originalLine)\n",2);
        while($originalLine =~ /"([^"]*)"/)#"
        {
            $quoteHash{$quoteNum} = $1;
            $originalLine = $`."quote$quoteNum".$';  
            $quoteNum++;
        }
        echoPrint("          + Quoted ($originalLine)\n",2);
        @splitWithQuotes = split(/\Q$split\E/,$originalLine);
        echoPrint("          + Split (@splitWithQuotes)\n",2);
        for($i=0;$i<@splitWithQuotes;$i++)
        {
            if ($splitWithQuotes[$i] =~ /quote([0-9]+)/)
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
            # save the match if it's shorter than the last one
            ($shortest, $length) = ($1, $m_len) if $m_len < $length;
            last;
        }
        $$rvRef = $shortest;
        return $shortest;
    }


  sub populateFeedStrings
  {
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


  sub addItems
  {
      my $mediaServer    = shift;
      my $uid            = shift;
      my $path           = shift;
      my $device         = shift;
      my $filter         = shift;
      my $disableSubcats = shift;
      my $scrapeMode     = shift;
      my $depth          = shift;

      my ($newItem, $video, $title, $description ,$type, $thumbnail);       
      my @content_list = $mediaServer->getcontentlist(ObjectID => $uid);
      my @items = ();
      
      if ($content_list[0] =~ /^!!/)
      {
        echoPrint("    - Error UID invalid, trying full path search\n");
      }
      else
      {
        echoPrint("    - Found UID ($uid), outputing directory\n");          
        foreach (@content_list)
        {
            if ($_->iscontainer())
            {
                if ($depth != 0)
                {
                    echoPrint("      / ".$_->gettitle()."\n");
                    @items = (@items, addItems($mediaServer, $_->getid(), $path."".$FS."".$_->gettitle(), $device, $filter, $disableSubcats, $scrapeMode, ($depth - 1)));        
                }
                elsif ($disableSubcats == 1)
                {     
                    if (!($filter eq "") && !($_->gettitle() =~ /$filter/))
                    {   # Check Filter
                        echoPrint("      / ".$_->gettitle()." (FILTERED)\n");
                        next;
                    }
                    echoPrint("      / ".$_->gettitle()."\n");                   
                    $newItem = $feed_item;
                    $video             = toXML('external,'.$executable.",/device||".$device."||/uid||".$_->getid()."||/path||".$path."".$FS."".$_->gettitle());
                    $title             = $_->gettitle();
                    $description       = "$path".$FS."".$_->gettitle();
                    $thumbnail         = '';
                    $type              = 'sagetv/subcategory';
                    
                    if ($path =~ /hulu.*networks$/i)
                    {
                      	$networkHuluBanner = $title;
                    		$networkHuluBanner =~ s/&//g;
                    		$networkHuluBanner =~ s/[ \-]/_/g;
                    		$networkHuluBanner =~ s/[.:'`"!]//g; #"
                    		$thumbnail = toXML("http://assets.hulu.com/companies/company_thumbnail_".lc($networkHuluBanner).".jpg");                    
                    }
                    elsif ($path =~ /hulu/i)
                    {   # Try and drop in show thumbnails in Hulu, there's gotta be a better way to handle this
                    		$showHuluBanner = $title;
                    		$showHuluBanner =~ s/&/and/g;
                    		$showHuluBanner =~ s/[ \-]/_/g;
                    		$showHuluBanner =~ s/[.:'`"!\\\/]//g; #"
                    		$thumbnail = toXML("http://assets.hulu.com/shows/show_thumbnail_".lc($showHuluBanner).".jpg");
                    }
                    
                    $newItem =~ s/%%ITEM_TITLE%%/$title/g;
                    $newItem =~ s/%%ITEM_DATE%%/$dateXMLString/g;
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
            elsif ($_->isitem())
            {
                if (!($filter eq "") && !($_->gettitle() =~ /$filter/))
                {   # Check Filter
                    echoPrint("      + ".$_->gettitle()." (FILTERED)\n"); 
                    next;
                }                       

                echoPrint("      + ".$_->gettitle()."\n"); 
                my $newItem = $feed_item;
                my $content = $_;
                my $id    = $content->getid();
                my $title = $content->gettitle();
                my $video = toXML($content->geturl());
                my $size  = $content->getSize();
                my $date  = $content->getdate();
                my $rating      = $content->getRating();
                my $userRating  = $content->getUserRating();
                my $dur  = $content->getDur();
                my $thumbnail  = toXML($content->getPicture());
                my $description = $content->getDesc();
                my $type = 'video/mpeg2';
                
                if ($scrapeMode)
                {
                    scrapePlayON($path,$content->getDesc(),$content->gettitle(),$content->getdate());
                    next;
                }
                else
                {
                    if ($title =~ /^s([0-9]+)e([0-9]+): (.*)/i)
                    {   # Hulu Show
                        my $season  = $1;
                        my $episode = $2;
                        my $episodeTitle = $3;
                        $description        = "Season $season Episode $episode - $description"; 
                        $title = $episodeTitle;
                    }
                    elsif ($title =~ /(.*) - s([0-9]+)e([0-9]+): (.*)/)
                    {   # Hulu Queue
                        my $show    = $1;
                        my $season  = $2;
                        my $episode = $3;
                        my $episodeTitle = $4;
                        $description        = "Season $season Episode $episode - $episodeTitle"; 
                        $title = $show;                                        
                    }
                    
                    $dur    =~ /([0-9]+):([0-9]+):([0-9]+).([0-9]+)/;
                    $durForDate = sprintf("%02d:%02d:%02d", $1, $2, $3);
                    my $durTotalSec = $1*60*60 + $2*60 + $3;
                    my $durTotalMin = $durTotalSec/60;
                                        
                    do
                    {   # Roughly Account for commercials
                        $durTotalMin -= 7;
                        $durTotalSec += 60;    
                    }while($durTotalMin > 0);  
    
                    
                    my $durDisSec  = $durTotalSec;
                    my $durDisMin  = 0;
                    my $durDisHour = 0;
                    
                    while ($durDisSec > 60)
                    {
                        $durDisSec -= 60;
                        $durDisMin   += 1;
                        if ($durDisMin == 60)
                        {
                            $durDisHour += 1;
                            $durDisMin   = 0;
                        }
                    }
                    
                    $outputPathName = $content->geturl()."||$durTotalSec";
            
                    my $durDisplay = sprintf("%02d:%02d:%02d", $durDisHour, $durDisMin, $durDisSec);       
                    
                    $date  =~ /^(.*)T/;
                    $date  = $1; 
                    
                    $description =~ s/\&amp;/&/g;
                    $description =~ s/\&quot;/"/g; #"
                    $description =~ s/\&lt;/</g;
                    $description =~ s/\&gt;/>/g;
                    $description =~ s/\&apos;/'/g;  #'              

                    $title =~ s/\&amp;/&/g;
                    $title =~ s/\&quot;/"/g; #"
                    $title =~ s/\&lt;/</g;
                    $title =~ s/\&gt;/>/g;
                    $title =~ s/\&apos;/'/g;  #'  
                    
                    $newItem =~ s/%%ITEM_TITLE%%/$title/g;
                    $newItem =~ s/%%ITEM_DATE%%/$durForDate ($date)/g;
                    $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
                    $newItem =~ s/%%ITEM_URL%%/$video/g;
                    $newItem =~ s/%%ITEM_DUR%%/$durDisplay/g;
                    $newItem =~ s/%%ITEM_SIZE%%/$size/g;
                    $newItem =~ s/%%ITEM_TYPE%%/$type/g;
                    $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
                    $newItem =~ s/%%ITEM_DUR_SEC%%/$durTotalSec/g;
                    push(@items,$newItem);
                }                
            } 
       }
    }          
    return @items;
  }
  
##### Helper Functions
    sub getExt
    {   # G:\videos\filename(.avi)
        my ( $fileName ) = @_;
        my $rv = "";
        if ($fileName =~ m#(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#)
        {
            $rv = ".$3";
        }
        return $rv;
    }

    sub getDriveLetter
    {   # (G:)\videos\filename.avi
        my ( $fileName ) = @_;
        my $rv = "";
        if ($fileName =~ /([a-zA-Z]:|\\\\)/)
        {
            $rv = $&;
        }
        return $rv;
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
        my $rv = "";
        #echoPrint("  + GetPath IN : ($fileName)\n");
        if ($fileName =~ m#[\\/]$#)
        {   # If it ends in \ chop it off
            $fileName = "$`";
        }
        
        $fileName .= ".txt";  # Always append an extention
        if ($fileName =~ m#([^\\/]*)$#)
        {
            $rv = $`;
        }
      
        $rv =~ s#(\\|/)$##;
        #echoPrint("  + GetPath OUT: ($rv)\n");
        return $rv;
    }
    
    sub getParentDir
    {   # (C:\some\path)\name\
        my $fileName = shift;
        my $rv = getPath(getPath($fileName));
        return $rv;
    }

    sub toANSII
    {
        my $replaceString = shift;
        $replaceString =~ s/\P{IsASCII}//g;
        return $replaceString;
    } 
    
    sub toWin32
    {
        my $replaceString = shift;
        my $illCharFileRegEx = "('|\"|\\\\|/|\\||<|>|:|\\*|\\?|\\&|\\;|`)";
        $replaceString =~ s/$illCharFileRegEx//g;
        return $replaceString;
    } 
    
    sub executionTime
    {
        my ($startSecond, $startMinute, $startHour) = @_;
        my ($finishSecond, $finishMinute, $finishHour ) = localtime();
  
        # handle negative times
        if ( $finishSecond < $startSecond )
        {
            $finishSecond += 60;
            $finishMinute--;
        }
        if ( $finishMinute < $startMinute )
        {
            $finishMinute += 60;
            $finishHour--;
        }
        if ( $finishHour < $startHour )
        {
            $finishHour += 24;
        }

        my $transcodeTime = sprintf( "%02d", ( $finishHour - $startHour ) ) .     ":" . 
                            sprintf( "%02d", ( $finishMinute - $startMinute ) ) . ":" . 
                            sprintf( "%02d", ( $finishSecond - $startSecond ) );
        #echoPrint("  + executionTime ($transcodeTime)\n");
        return "$transcodeTime";
    }
    
    sub updatePresets
    {
        echoPrint("Nothing to see here\n");   
    }
    
    sub cleanWorkPath
    {
        my ($workPath) = @_;
        my %existingFilesHash = scanDir($workPath,"playon");
        
        foreach $exitingFile (sort(keys %existingFilesHash))
        {
            echoPrint("    - Cleaning : (".getFile($exitingFile)." (".(-s getFullFile($exitingFile)).")\n"); 
            if (-e $exitingFile && $exitingFile =~ /\.playon$/ && (-s $exitingFile) < 40000)
            {   # never delete anything over 60 mb                 
                $rmString = encode('ISO-8859-1', "del /Q \"$exitingFile\" 2>1");
                #echoPrint("    - rm : ($rmString)\n");
                `$rmString`;
                $rmString = encode('ISO-8859-1', "del /Q \"".getFullFile($exitingFile)."\"");
                #echoPrint("    - rm : ($rmString)\n");
                `$rmString`;
                
                if (-e getFullFile(encode('ISO-8859-1', $exitingFile)).".properties")
                {
                    $rmString = encode('ISO-8859-1', "del /Q \"".getFullFile($exitingFile).".properties"."\"");
                    #echoPrint("    - rm : ($rmString)\n");
                    `$rmString`;
                }
                
                #Check to see if folder is empty
                my $checkFolder = getPath($exitingFile);
                opendir(SCANDIR,"$checkFolder");
                my @filesInDir = readdir(SCANDIR);
                #echoPrint("      - Checking if folder is empty : ($checkFolder)\n");
                $depthProtection = 0;
                while(@filesInDir == 2 && $depthProtection < 4)
                {
                    if (!("$checkFolder" eq "$workPath"))
                    {
                        $rmString = encode('ISO-8859-1', "rmdir /Q \"$checkFolder\"");
                        echoPrint("      + Folder empty, deleting : ($rmString)\n");
                        `$rmString`;
                    }
                    
                    close(SCANDIR);
                    $checkFolder = getPath($checkFolder);
                    opendir(SCANDIR,"$checkFolder");
                    @filesInDir = readdir(SCANDIR);
                    #echoPrint("      + Checking if folder is empty : ($checkFolder)\n");
                    $depthProtection++;                          
                }
                close(SCANDIR);       
            }        
        }
        echoPrint("    - Folders Cleaned!\n");
        exit;   
    }    
    
    
    sub scrapePlayON
    {
        my ($playONPath,$playONDescription,$playONTitle,$playONAirdate) = @_;
        my $season;
        my $episode;
        my $description;
        my $mediaType;
        my $showTitle;
        my $mediaType;
        my $airdate;
        my $airYear;
        my $playOnRegExPath = $playONPath . "\\" . $playONTitle; 
        
        
        # Get Airdate
        if ($playONAirdate =~ /([0-9]{4})-[0-9]{2}-[0-9]{2}/)
        {
            $airdate    = $&;
            $airYear    = $1;
        }
        
        if ($playOnRegExPath =~ /([^\\-]+) - s([0-9]+)e([0-9]+): (.*)$/i)
        {     # Hulu TV Type 1
              #echoPrint("    - TV Type #1 ($playOnRegExPath)\n");
              $showTitle    = $1;
              $season       = $2;
              $episode      = $3;
              $episodeTitle = $4;
              $description  = $playONDescription;
              $mediaType = "TV";
        }
        elsif ($playOnRegExPath =~ /([^\\]+)\\Full Episodes\\s([0-9]+)e([0-9]+): (.*)/i) 
        {     # Hulu TV Type 2, also works for other paths
              #echoPrint("    - TV Type #2 ($playOnRegExPath)\n");
              $showTitle    = $1;
              $season       = $2;
              $episode      = $3;
              $episodeTitle = $4;
              $description  = $playONDescription;
              $mediaType = "TV";
        }
        elsif ($playOnRegExPath =~ /([^\\]+)\\Full Episodes\\(.*)/i) 
        {     # Episodes without S/E info
              #echoPrint("    - TV Type #3 ($playOnRegExPath)\n");
              $showTitle    = $1;
              $episodeTitle = $2;
              $description  = $playONDescription;
              $mediaType = "TV";
        }
        elsif ($playOnRegExPath =~ /([^\\]+) .Season ([0-9]+).\\Full Episodes\\Ep. ([0-9]+) . (.*)/i) 
        {     # For some MTV stuff
             # echoPrint("    - TV Type #4 ($playOnRegExPath)\n");
              $showTitle    = $1;
              $episodeTitle = $2;
              $description  = $playONDescription;
              $mediaType = "TV";
        }
        elsif ($playOnRegExPath =~ /([^\\]+)\\Season ([0-9]+)\\([0-9]+): (.*)/i) 
        {     # Netflix TV type 1 - New Series format
              #echoPrint("    - TV Type #5 ($playOnRegExPath)\n");
              $showTitle    = $1;
              $season       = $2;
              $episode      = $3;
              $episodeTitle = $4;
              $description  = $playONDescription;
              $mediaType = "TV";
        }
        elsif ($playOnRegExPath   =~ /\\([^\\]+): The Complete Series\\([0-9]+): (.*)/i) 
        {     # Netflix TV type 2  - SOme shows that only have 1 season are wierd
              #echoPrint("    - TV Type #6 ($playOnRegExPath)\n");
              $showTitle    = $1;
              $season       = 1; # Assume these shows only have 1 season
              $episode      = $2;
              $episodeTitle = $3;
              $description  = $playONDescription;
              $mediaType = "TV";      
        }
        elsif($playOnRegExPath   =~ /\\([^\\]+)\\(Volume|Collection) [0-9]+\\[0-9]+: (.*)/i)
        {   # Collections and Volumes don't have acurate season/episode info
              #echoPrint("    - TV Type #7 ($playOnRegExPath)\n");
              $showTitle    = $1;
              $episodeTitle = $3;
              $description  = $playONDescription;
              $mediaType = "TV";      
        }
        elsif($playOnRegExPath   =~ /\\([^\\]+)\\([0-9]+): (.*)/i)
        {     #Probably a miniseries of some kind
              #echoPrint("    - TV Type #7 ($playOnRegExPath)\n");
              $showTitle    = $1;
              $season       = 1; # Assume these shows only have 1 season
              $episode      = $2;
              $episodeTitle = $3;
              $description  = $playONDescription;
              $mediaType = "TV";      
        }
        else
        {     # Treat like movie
              #echoPrint("    - Moive! ($playOnRegExPath)\n");
              $mediaType   = "Movie";
              $showTitle   = $playONTitle;
              $description = $playONDescription;            
        }

        $playONRegEx =  $playONTitle;
        if ($playONTitle =~ /s([0-9]+)e([0-9]+)/)
        {
            $playONRegEx = $`."s0*".($1 + 0)."e0*".($2 + 0)."".$';
        }
        
        my $path           = "/outputPath||/search||$playONPath\\$playONRegEx\\+1";
        $path              =~ s/:/./gi;
        $path              =~ s/\\/:/gi;
        $path              =~ s/\P{IsASCII}/./g;
        
        $showTitle =~ s/\&amp;/&/g;
        $showTitle =~ s/\&quot;/"/g; #"
        $showTitle =~ s/\&lt;/</g;
        $showTitle =~ s/\&gt;/>/g;
        $showTitle =~ s/\&apos;/'/g;  #'
        $showTitle =~ s/ & / and /g;
        
        $episodeTitle =~ s/\&amp;/&/g;
        $episodeTitle =~ s/\&quot;/"/g; #"
        $episodeTitle =~ s/\&lt;/</g;
        $episodeTitle =~ s/\&gt;/>/g;
        $episodeTitle =~ s/\&apos;/'/g;  #'
        $episodeTitle =~ s/ & / and /g;  
        
        my $fileName       = $showTitle;
        my $folder         = "";  
        if ($mediaType eq "TV")
        {
            $folder = "TV".$FS."".toWin32($showTitle);
            if (!($season eq ""))
            {
                $folder           .= "".$FS."Season $season"; 
                $fileName         .= " S".$season."E".sprintf("%02d",$episode)." - $episodeTitle";
            }
            else
            {
                $fileName         .= " -- $episodeTitle";
            }
        }
        else
        {
            $folder = "Movies".($myMovies == 1 ? $FS.toWin32($showTitle) : "");
            if (!($airYear eq ""))
            {
                $fileName   .= " ($airYear)";    
            }            
        }
        
        $fileName = toANSII(toWin32($fileName));
        $folder   = toANSII($folder);
        $fullFileName = "$workPath".$FS."$folder".$FS."$fileName.m4v";
        
        if (-e $fullFileName)
        {   # If file already exists, ignore it.
            delete $existingFilesHash{$fullFileName.".playon"};            
        }
        else
        {   # Else, add it to the list of files to create
            $playOnFileHash{$fullFileName} = $path;
        }    
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
                $file = decode('ISO-8859-1', $file);
                #echoPrint("-> $file\n");
                next if ($file =~ m/^\./);
                next if !($file =~ m/($fileFilter)$/ || -d encode('ISO-8859-1', "$inputFile\\$file"));       
                if (-d encode('ISO-8859-1', "$inputFile\\$file") && !($file =~ m/VIDEO_TS$/)) { push(@dirs,"$inputFile\\$file"); }
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

      
      
  
  
  
  
