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
  use utf8;
  use LWP;
  use URI::Escape;
  use Net::Google::PicasaWeb;
  use Crypt::Random qw( makerandom );
  use Crypt::CBC;
  use Crypt::Twofish;
  
  # Setup a global User Agent
  $browser = LWP::UserAgent->new( );
  $browser->timeout(30);
  $browser->agent( 'Mozilla/4.0 (compatible; MSIE 5.12; Mac_PowerPC)' );

  # Get the directory the script is being called from
  $executable = $0;
  $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;
  $executablePath = $`;
  $executableEXE  = $3; 
   
  open(LOGFILE,">$executablePath\\$executableEXE.log");

  # Get Start Time
  my ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();

  # Code version
  my $codeVersion = "$executableEXE v1.0 (SNIP:BUILT)".($debug ? "(debug)" : "");
  
  my $invalidMsg .= "\n$codeVersion\n";
  $invalidMsg .= "\tUSAGE:";
  $invalidMsg .= "\t$executableEXE.exe /url <URL>\n\n";

  my ($feed_begin, $feed_item, $feed_end) = populateFeedStrings();

  echoPrint("Welcome to $codeVersion!\n");
  echoPrint("  + Path: $executablePath\n");
  
  my $key;
  if (-s "$executablePath\\$executableEXE.key")
  {
      echoPrint("  + Retrieving encryption key ($executableEXE.key)\n");
      if (open(KEYMASTER,"$executablePath\\$executableEXE.key"))
      {
          $key = <KEYMASTER>;
          close(KEYMASTER);
      }
  }
  else
  {
      echoPrint("  ! Encryption Key doesn't exist yet, generating one ($executableEXE.key)\n");
      $key = makerandom( Size => 128, Strength => 1);
      if (open(KEYMASTER,">$executablePath\\$executableEXE.key"))
      {
          print KEYMASTER $key;
          close(KEYMASTER);
      }
  }
  
  my $userName;
  my $password;
  my $cipher = new Crypt::CBC ($key, 'Twofish');
  if (-s "$executablePath\\$executableEXE.username" && defined $key)
  {
      echoPrint("  + Retrieving username ($executableEXE.username)\n");
      if (open(KEYMASTER,"$executablePath\\$executableEXE.username"))
      {
          my $ciphertext = <KEYMASTER>;
          $userName = $cipher->decrypt($ciphertext);
          close(KEYMASTER);
      }
      echoPrint("    - Usename : ($userName)\n");
  }
  
  if (-s "$executablePath\\$executableEXE.password" && defined $key)
  {
      echoPrint("  + Retrieving password ($executablePath\\$executableEXE.password)\n");
      if (open(KEYMASTER,"$executablePath\\$executableEXE.password"))
      {
          my $ciphertext = <KEYMASTER>;
          $password = $cipher->decrypt($ciphertext);
          close(KEYMASTER);
      }
      echoPrint("    - Password : (********)\n");
  }

  # Move arguments into user array so we can modify it
  my @parameters = @ARGV;
  
  if (@parameters == 0)
  {
      echoPrint("  + No Options!  Priting default menu\n");
      outputMenu($feed_begin, $feed_item, $feed_end, (defined $userName && defined $password));
      exit 0;
  }

  # Initilize options data structures
  my %optionsHash;
  my @inputFiles;
  my @emptyArray = ();
  my %emptyHash  = ();
  
  # Setting cli options
  foreach (@parameters)
  {
      $parametersString .= "\"$_\" ";
  }
  
  setOptions(decode('ISO-8859-1' , $parametersString),\@emptyArray,\%optionsHash,\@inputFiles,\%emptyHash,"  ");

  if (exists $optionsHash{lc('setUserName')})
  {
      echoPrint("  + Setting Username (".$optionsHash{lc('setUsername')}.")\n");
      if (open(USERNAME,">$executablePath\\$executableEXE.username"))
      {
          print USERNAME $cipher->encrypt($optionsHash{lc('setUsername')});
          close(USERNAME);
      }
      errorToXML('Updated Username','Updated Username, please reenter Picasa Web for the echange to take effect');
  }
  
  if (exists $optionsHash{lc('setPassword')})
  {
      echoPrint("  + Setting Password (**************)\n");
      if (open(USERNAME,">$executablePath\\$executableEXE.password"))
      {
          print USERNAME $cipher->encrypt($optionsHash{lc('setPassword')});
          close(USERNAME);
      }
      errorToXML('Updated Password','Updated Password, please reenter Picasa Web for the echange to take effect');
  }

  # Login
  my $service = Net::Google::PicasaWeb->new;
  my @items = ();
  
  if (defined $userName && defined $password)
  {
      echoPrint("  + Logging In...\n");
      my $response = $service->login($userName, $password);
      if ($response->is_success)
      {
          echoPrint("    + Success...\n");
      }
      else
      {
          echoPrint("    ! Login Failure...\n");
          errorToXML('Login Failure','Picasa Web Login Failure, try entring your user name and password again');  
      }
  
      if (exists $optionsHash{lc('listAlbums')})
      {
          echoPrint("  + Listing Albums\n");
          my @albums = $service->list_albums( user_id => $userName);
          for my $album (@albums) 
          {
              echoPrint("    - Title    : ".$album->title."\n");
              echoPrint("      + Author : ".$album->author_name." (".$album->author_uri.")\n");
              echoPrint("      + Thumb  : ".$album->photo->content->url."\n"); 
              echoPrint("      + ID     : ".$album->entry_id."\n");
              echoPrint("      + Summary: ".$album->summary."\n");
              $newItem = $feed_item;
              $video             = toXML('external,"'.$executable.'",/getAlbum||'.$album->entry_id);
              $title             = $album->title;
              $description       = "Album : ".$album->title."\nDescription : ".$album->summary."\n";
              $thumbnail         = toXML(getPhotoThumb($album->photo->content->url));
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
      }
      elsif (exists $optionsHash{lc('getAlbum')})
      {
          echoPrint("  + Getting Album (".$optionsHash{lc('getAlbum')}.")\n");
          my $album = $service->get_album( user_id => $userName,
                                          album_id => $optionsHash{lc('getAlbum')});
          if ($album)
          {
              echoPrint("    - Title    : ".$album->title."\n");
              echoPrint("      + Author : ".$album->author_name." (".$album->author_uri.")\n");
              echoPrint("      + ID     : ".$album->entry_id."\n");
              echoPrint("      + Summary: ".$album->summary."\n");
              my @photos = $album->list_media_entries;
              for my $photo (@photos) 
              {
                  my $media_info = $photo->photo;
                  echoPrint("    - Image Title  : ".$media_info->title."\n");
                  echoPrint("      + URL        : ".$media_info->content->url."\n");
                  echoPrint("      + Thumbnails :\n");
                  #for my $thumbnail ($media_info->thumbnails) {
                  #    echoPrint("        - Thumbnail URL: ".$thumbnail->url."\n");
                  #    echoPrint("          + Thumbnail Dimensions: ".$thumbnail->width."x".$thumbnail->height."\n");
                  #}
                  echoPrint("      + Description: ".$media_info->description."\n");
                  
                  $newItem = $feed_item;
                  $video             = toXML($media_info->content->url);
                  $title             = $media_info->title;
                  $description       = "Title : ".$media_info->title."\nDescription : ".$media_info->description."\n";
                  $thumbnail         = toXML(getPhotoThumb($media_info->content->url));
                  $type              = 'image/jpeg';
                  
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
          else
          {
              echoPrint("    ! Album does not exist\n");
              errorToXML('No Album','The requested album does not exist!');
          }      
      }
  }
  

  
  #my ($feed_begin, $feed_item, $feed_end, $textOnlyDescription) = populateFeedStrings();
  my $opening = $feed_begin;
  $opening =~ s/%%FEED_TITLE%%/Picasa Web/g;
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
  
  my ( $finishSecond, $finishMinute, $finishHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();
  
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

  $durHour = sprintf( "%02d", ( $finishHour - $startHour ) );
  $durMin  = sprintf( "%02d", ( $finishMinute - $startMinute ) );
  $durSec  = sprintf( "%02d", ( $finishSecond - $startSecond ) );
  my $transcodeTime = $durHour . ":" . $durMin . ":" . $durSec;
  echoPrint("  + Finished in ($transcodeTime)\n");

  #http://lh4.ggpht.com/_tpSPv1gZCY4/S5Fz5StBmKI/AAAAAAAAAB4/0nIE1AdhrPA/s72/seven_shine_1680_1050.jpg
    sub getPhotoThumb
    {
        my $url = shift;
        $url =~ /[^\/]*$/;
        my $before = $`;
        my $after  = $&;
        return $before.'s144/'.$after;
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
            # save the match if it's shorter than the last one
            ($shortest, $length) = ($1, $m_len) if $m_len < $length;
            last;
        }
        $$rvRef = $shortest;
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
      <pubDate>1981-09-15</pubDate> 
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

  sub outputMenu
  {
      my ($feed_begin, $feed_item, $feed_end, $userInfoDefined) = @_;
      my @items = ();
      my $newItem,$video,$title,$description,$type,$thumbnail;
      my $opening;
           
      $opening = $feed_begin;
      $opening =~ s/%%FEED_TITLE%%/Picasa Web Albums/g;
      $opening =~ s/%%FEED_DESCRIPTION%%/Picasa Web Albums/g;
      
      if ($userInfoDefined)
      {
          # Get Albums
          $newItem = $feed_item;
          $video             = toXML('external,"'.$executable.'",/listAlbums');
          $title             = 'List Albums';
          $description       = 'List Picasa Web Albums';
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

      # User Name
      $newItem = $feed_item;
      $video             = toXML('external,"'.$executable.'",/setUserName||%%getuserinput=PicasaWeb Username%%');
      $title             = 'Set Username';
      $description       = 'Set Picasa Web Username';
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
      
      # Password
      $newItem = $feed_item;
      $video             = toXML('external,"'.$executable.'",/setPassword||%%getuserinput=Picasa Web Password%%');
      $title             = 'Set Password';
      $description       = 'Set Picasa Web Password';
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
  
  sub errorToXML
  {
      my $shortDescription = shift;
      my $longDescription = shift;
      my $newItem,$video,$title,$description,$type,$thumbnail;
      my $opening;
           
      $opening = $feed_begin;
      $opening =~ s/%%FEED_TITLE%%/$shortDescription/g;
      $opening =~ s/%%FEED_DESCRIPTION%%/$longDescription/g;

      $newItem = $feed_item;
      $video             = '';
      $title             = $shortDescription;
      $description       = $longDescription;
      $thumbnail         = '';
      $type              = 'sagetv/textOnly';
      
      $newItem =~ s/%%ITEM_TITLE%%/$title/g;
      $newItem =~ s/%%ITEM_DATE%%//g;
      $newItem =~ s/%%ITEM_DESCRIPTION%%/$description/g;
      $newItem =~ s/%%ITEM_URL%%/$video/g;
      $newItem =~ s/%%ITEM_DUR%%//g;
      $newItem =~ s/%%ITEM_SIZE%%//g;
      $newItem =~ s/%%ITEM_TYPE%%/$type/g;
      $newItem =~ s/%%ITEM_PICTURE%%/$thumbnail/g;
      $newItem =~ s/%%ITEM_DUR_SEC%%//g; 
      
      print encode('UTF-8', $opening);
      print encode('UTF-8', $newItem);
      print encode('UTF-8', $feed_end);
      exit;  
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
  
  exit;

      
      
  
  
  
  
