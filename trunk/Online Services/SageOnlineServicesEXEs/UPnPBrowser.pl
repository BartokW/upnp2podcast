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
  use Encode;
  use utf8;
  use Digest::MD5 qw(md5 md5_hex md5_base64);
  use LWP::UserAgent;
  use Net::UPnP::ControlPoint;
  use Net::UPnP::AV::MediaServer;
  
  my $obj = Net::UPnP::ControlPoint->new();
  my $mediaServer = Net::UPnP::AV::MediaServer->new();
  
  # Setup LWP user agent
  my $ua = LWP::UserAgent->new;
  $ua->agent( 'Mozilla/4.0 (compatible; MSIE 5.12; Mac_PowerPC)' );
  $ua->timeout(25);    

  # Get the directory the script is being called from
  $executable = $0;
  $executablePath = getPath($executable);
  $executableEXE  = getFile($executable); 
   
  open(LOGFILE,">$executablePath/$executableEXE.log");


  # Get Start Time
  my ( $startSecond, $startMinute, $startHour) = localtime();
  my @startTime = ( $startSecond, $startMinute, $startHour);

  # Code version
  my $codeVersion = "$executableEXE v1.1 (SNIP:BUILT)";
  
  my $invalidMsg .= "\n$codeVersion\n";
  $invalidMsg .= "\tUSAGE:";
  $invalidMsg .= "\t$executableEXE.exe /profile <Profile name>\n\n";

  my ($feed_begin, $feed_item, $feed_end) = populateFeedStrings();

  echoPrint("Welcome to $codeVersion! (".localtime()."\n");
  echoPrint("  + Path: $executablePath\n");
  
  if (!(-d "$executablePath\\$executableEXE"))
  {
      echoPrint("  + Making .cache Directory: ($executablePath\\$executableEXE)\n");
      {
          mkdir("$executablePath\\$executableEXE");
      }
  }
  
  # Find SageTV Directory and check version
  my @checkPaths = ($executablePath,
                    getParentDir($executablePath),
                    'C:/Program Files/SageTV/SageTV',
                    '/opt/sagetv/server/');
  
  my $sageDir = $executablePath;                
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
  
  my $updateSuccess;
  my $serverPresetVersion = 0;
  my $serverPresets = "";
  my $presetVersion = -1;
  
  if ((@parameters == 0 || int(rand(10)) > 5) || !(-s "$executablePath\\$executableEXE\\$executableEXE.presets"))  
  {
      my $presetsURL    = 'http://upnp2podcast.googlecode.com/svn/trunk/Online%20Services/SageOnlineServicesEXEs/UPnPBrowser.presets';  
      
      echoPrint("  + Checking for preset updates\n");
      my $response  = $ua->get($presetsURL);  
      if ($response->is_success)
      {
          $serverPresets = $response->decoded_content((charset => "ISO-8859-1"));
          $serverPresets =~ s/\r//g;
          $serverPresets =~ /Version=([0-9]+)/;
          $serverPresetVersion = $1;
          echoPrint("    - Downloaded $executableEXE.presets (Version: $serverPresetVersion)\n");
      }
      else
      {
          echoPrint("  ! Failed to download updates file ($presetsURL)\n");
      }
      
      if (open(PRESETS,"$executablePath\\$executableEXE\\$executableEXE.presets"))
      {   
          $presetVersion = <PRESETS>;
          $presetVersion =~ /Version=([0-9]+)/i;
          $presetVersion = $1;
          echoPrint("    - Existing Presets Version ($presetVersion)\n");
      }
      close(PRESETS);
      
      # Check to see if file is most recent
      if ($serverPresetVersion > $presetVersion && !($serverPresets eq ""))
      {
          echoPrint("      ! Updating Presets File ($serverPresetVersion > $presetVersion)\n");
          open(PRESETS,">$executablePath\\$executableEXE\\$executableEXE.presets");
          print PRESETS $serverPresets;
          close(PRESETS);         
      }      
  }
  
  my %presets = ();
  if (-s "$executablePath\\$executableEXE\\$executableEXE.presets")
  {   # Read in Presets      
      if (open(PRESETS,"$executablePath\\$executableEXE\\$executableEXE.presets"))
      {   
          my $presetVersion = <PRESETS>;
          $presetVersion =~ /Version=([0-9]+)/i;
          $presetVersion = $1;
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
  
  if (@parameters == 1 &&  $parameters[0] =~ /:/)
  {
      echoPrint("  + Detected v1 parameter string, converting to v2 ($parameters[0])\n");
      my @v1sting = split(/:/, $parameters[0]);
      
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

      if (!($sageVersion =~ /SageTV V7/i))
      {
          #disabling subcats
          $optionsHash{lc("disableSubcats")} = 1;
          echoPrint("    - /disableSubcats\n");        
      }        
  }
  else
  {
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
  }
  
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
  
  my $serverWait = 1;
  if (exists $optionsHash{lc("serverSearchTimeout")})
  {
      echoPrint("  + /serverSearchTimeout : (".$optionsHash{lc("serverSearchTimeout")}.")\n");
      $serverWait = $optionsHash{lc("serverSearchTimeout")};
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
      $opening =~ s/%%FEED_TITLE%%/UPnP Browser/g;
      $opening =~ s/%%FEED_DESCRIPTION%%/UPnP Browser/g;
      
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
          $newItem =~ s/%%ITEM_DATE%%//g;
          $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
          $newItem =~ s/%%ITEM_URL%%/$video/g;
          $newItem =~ s/%%ITEM_DUR%%//g;
          $newItem =~ s/%%ITEM_SIZE%%//g;
          $newItem =~ s/%%ITEM_TYPE%%/$type/g;
          $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
          $newItem =~ s/%%ITEM_DUR_SEC%%//g; 
          push(@items,$newItem);            
      }
      
      # Add in Long Search
      $newItem = $feed_item;
      $video             = toXML('external,"'.$executable.'",/serverSearchTimeout||30||/mainMenu');
      $title             = "Find More Servers...";
      $description       = "Re-run the UPnP server search with an extra long timeout to find more servers (~10 minutes).";
      $thumbnail         = '';
      $type              = 'sagetv/subcategory';
      
      $newItem =~ s/%%ITEM_TITLE%%/$title/g;
      $newItem =~ s/%%ITEM_DATE%%//g;
      $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
      $newItem =~ s/%%ITEM_URL%%/$video/g;
      $newItem =~ s/%%ITEM_DUR%%//g;
      $newItem =~ s/%%ITEM_SIZE%%//g;
      $newItem =~ s/%%ITEM_TYPE%%/$type/g;
      $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
      $newItem =~ s/%%ITEM_DUR_SEC%%//g; 
      push(@items,$newItem);
      
      my $execTime = executionTime(@startTime);      
      print encode('UTF-8', $opening);
      foreach (@items)
      {
          if (!($_ eq ""))
          {
              $_ =~ s/EXE_TIME/($execTime)/g;
              print encode('UTF-8', $_);
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
          $video             = toXML('external,'.$executable.',/device||'.$_->getfriendlyname()."||/uid||0");
          $title             = "UPnP Browser Error!";
          $description       = "UPnP Browser Error!  Unable to find UPnP Device ($lookingFor)"." (EXE_TIM  )";
          $thumbnail         = '';
          $type              = 'sagetv/textonly';
          
          $newItem =~ s/%%ITEM_TITLE%%/$title/g;
          $newItem =~ s/%%ITEM_DATE%%//g;
          $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
          $newItem =~ s/%%ITEM_URL%%/$video/g;
          $newItem =~ s/%%ITEM_DUR%%//g;
          $newItem =~ s/%%ITEM_SIZE%%//g;
          $newItem =~ s/%%ITEM_TYPE%%/$type/g;
          $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
          $newItem =~ s/%%ITEM_DUR_SEC%%//g; 
          push(@items,$newItem);            

          my $execTime = executionTime(@startTime);      
          print encode('UTF-8', $opening);
          foreach (@items)
          {
              if (!($_ eq ""))
              {
                  $_ =~ s/EXE_TIME/$execTime/g;
                  print encode('UTF-8', $_);
              }
          }  
          print encode('UTF-8', $feed_end);
          echoPrint($execTime);           
          exit 0;
      }
      
      if (exists $optionsHash{lc("path")} && $foundDevice == 1 &&!exists $optionsHash{lc("uid")})
      {  # if all we get is a path, serach the tree for the uid
          $optionsHash{lc("uid")} = 0;
          my @splitString = split(/\//,$optionsHash{lc("path")});
          echoPrint("  + GetContent from: ".(shift @splitString)."\n");
          
          foreach $lookingFor (@splitString)
          {         
              echoPrint("    - Looking for : ".$lookingFor."\n");
              
              # Checking Cache
              my @content_list = ();              
              @content_list = $mediaServer->getcontentlist(ObjectID => $optionsHash{lc("uid")});
              my $found  = 0;
              foreach $content (@content_list)
              {
                  echoPrint("      + ".($content->iscontainer() ? "/" : "")."".$content->gettitle()." (".$content->getid().")\n");
                  if ($content->gettitle() =~ /$lookingFor/i)
                  {
                      echoPrint("        - Found! : $`(".$&.")$'\n");
                      $optionsHash{lc("uid")} = $content->getid();
                      $found = 1;
                      #last;    
                  }    
              }              
              if ($found == 0)
              {
                  echoPrint("    ! Couldn't find : ".$lookingFor."\n");
                  echoPrint("    + Execution time: ".executionTime(@startTime)."\n");  
                  exit 0; 
              }
          }

      }
      #die;  
      
      if (exists $optionsHash{lc("uid")} && $foundDevice == 1)
      {
                             
          my @items = ();
          @items    = (@items, addItems($mediaServer, 
                                        $optionsHash{lc("uid")}, 
                                        $optionsHash{lc("path")}, 
                                        $optionsHash{lc("device")},
                                        $optionsHash{lc("filter")}, 
                                        !(exists $optionsHash{lc("disableSubcats")}), 
                                        (exists $optionsHash{lc("depth")} ? $optionsHash{lc("depth")} : 0) ));
          
          my $opening = $feed_begin;;
          $opening =~ s/%%FEED_TITLE%%/UPnP Browser ($lookingFor)/g;
          $opening =~ s/%%FEED_DESCRIPTION%%/UPnP Browser ($lookingFor)/g;

          my $execTime = executionTime(@startTime);      
          print encode('UTF-8', $opening);
          foreach (@items)
          {
              if (!($_ eq ""))
              {
                  $_ =~ s/EXE_TIME/$execTime/g;
                  print encode('UTF-8', $_);
              }
          }  
          print encode('UTF-8', $feed_end);
          echoPrint($execTime);  
          exit 0;               
      }     
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
                    @items = (@items, addItems($mediaServer, $_->getid(), $path."/".$_->gettitle(), $device, $filter, $disableSubcats, ($depth - 1)));        
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
                    $video             = toXML('external,'.$executable.",/device||".$device."||/uid||".$_->getid()."||/path||".$path."/".$_->gettitle());
                    $title             = $_->gettitle();
                    $description       = $path.$_->gettitle();
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
                    $newItem =~ s/%%ITEM_DATE%%//g;
                    $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
                    $newItem =~ s/%%ITEM_URL%%/$video/g;
                    $newItem =~ s/%%ITEM_DUR%%//g;
                    $newItem =~ s/%%ITEM_SIZE%%//g;
                    $newItem =~ s/%%ITEM_TYPE%%/$type/g;
                    $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
                    $newItem =~ s/%%ITEM_DUR_SEC%%//g; 
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
        
                if ($title =~ /s([0-9]+)e([0-9]+): (.*)/)
                {
                    my $season  = $1;
                    my $episode = $2;
                    my $episodeTitle = $3;
                    $description        = "Season $season Episode $episode - $description"; 
                    $title = $episodeTitle;
                }
                
                $dur    =~ /([0-9]+):([0-9]+):([0-9]+).([0-9]+)/;
                my $durTotalSec = $1*60*60 + $2*60 + $3;
                my $durTotalMin = $durTotalSec/60;
                
                if ($video =~ /(hulu|cbs)/i)
                {   # Roughly Account for commercials
                    while($durTotalMin > 0)
                    {
                        $durTotalMin -= 7;
                        $durTotalSec += 30;    
                    }  
                }
                
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
        
                my $durDisplay = sprintf("%02d:%02d:%02d", $durDisHour, $durDisMin, $durDisSec);       
                
                $date  =~ /^(.*)T/;
                $date  = $1;                    
                
                $newItem =~ s/%%ITEM_TITLE%%/$title/g;
                $newItem =~ s/%%ITEM_DATE%%/$date/g;
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
    return @items;
  }
  
  sub updateFeedFiles
  {
    my ($ua) = @_;
    my $rv = 0;  
    # URL of file containing feed versions
    my $feedPath = "$executablePath/STVs/SageTV7/OnlineVideos/";
    my $feedVersionURL = 'http://upnp2podcast.googlecode.com/svn/trunk/upnp2podcast/Feeds/$executableEXE.presets';
    my ($updateFile, $propFileName, $propFileVersion, 
        $propFileMD5, $propFileURL, $topLine, $currentVersion,
        $updatedMD5, $propPlugIn);
    $feedVersionURL    =~ /http:\/\/[^\/]/;
    my $feedBaseURL    = $&;

    echoPrint("  + Checking for feed updates\n");

    my $response  = $ua->get($feedVersionURL);
    
    if ($response->is_success)
    {
        my $content = $response->decoded_content((charset => "ISO-8859-1"));
        $content =~ s/\r//g;
        
        my @plugIns = ();
        if (open(PLUGINS,"UPnP2Podcast.plugins"))
        {
            @plugIns = <PLUGINS>;
            chomp(@plugIns);
            close(PLUGINS);  
        }
       
        my @content = split(/\n/,$content);
        echoPrint("  + Downloaded FeedVersions.txt (".md5_hex($content)."), checking for updates(".$feedVersionURL.")\n");
        foreach (@content)
        {
            $updateFile      = 0;
            if (/(.*),(.*),(.*),(.*),(.*)/)
            {
                ($propFileName, $propFileVersion, $propFileMD5, $propFileURL, $propPlugIn) = ($1,$2,$3,$4,$5);
                echoPrint("    - File      : $propFileName\n");
                echoPrint("      - Version : $propFileVersion\n");
                echoPrint("      - URL     : $propFileURL\n");
                echoPrint("      - MD5     : $propFileMD5\n");
                echoPrint("      - Plugin  : $propPlugIn\n");
                if (grep(/\Q$propPlugIn\E/,@plugIns) || $propPlugIn eq "")
                {
                    if ($propFileURL =~ /\Q^$feedBaseURL\E/ || 1)
                    {   # Make sure it comes from my google code account
                        if (-e "$feedPath$propFileName")
                        {
                            open(FEED,"$feedPath$propFileName");
                            $topLine = <FEED>;
                            chomp($topLine);
                            close(FEED);
                            $currentVersion = "";
                            if ($topLine =~ /Version=([0-9]+)/i)
                            {
                                $currentVersion = $1;
                            }
                            echoPrint("      - Local Version : $currentVersion\n");
                            if ($propFileVersion > $currentVersion)
                            {
                                $updateFile = 1;    
                            }
                        }
                        else
                        {
                            $updateFile = 1;
                        }
                    }
                }
                else
                {
                    echoPrint("        + PlayOn Plug-in ($propPlugIn) not installed, skipping (@plugIns)\n");    
                }
                                
                if ($updateFile)
                {
                    echoPrint("      - Updating File!\n");                         
                    my $response  = $ua->get($propFileURL);
                    
                    if ($response->is_success)
                    {
                        my $content = $response->decoded_content((charset => "ISO-8859-1"));
                        $content =~ s/\r//g;
                        $updatedMD5 = md5_hex($content);
                        echoPrint("        + MD5 URL : $updatedMD5 ($propFileMD5)($feedPath$propFileName)\n");
                        if ($updatedMD5 eq $propFileMD5)
                        {
                            if (open(FEED,">$feedPath$propFileName"))
                            {
                                print FEED $content;
                                close(FEED);
                            }
                            else
                            {
                                echoPrint("        ! Couldn't open file for write ($feedPath$propFileName)\n");
                            }    
                            $rv++;
                        }
                        else
                        {
                            echoPrint("        - MD5 check failed, skipping!\n");    
                        }
                    }
                } 
            }
        }  
    }
    else
    {
        echoPrint("  ! Failed to get $executableEXE.FeedVersions.txt, skipping updates\n");
    } 
    return $rv;   
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
        my $rv = getPath($fileName)."/".getFile($fileName);
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

      
      
  
  
  
  
