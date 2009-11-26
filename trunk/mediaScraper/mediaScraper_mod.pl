##    scraper.pl - An open ended metadata scaper
##    Copyright (C) 2006    Scott Zadigian  zadigian(at)gmail
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
##### Import libraries
    use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
    use Encode qw(encode decode);
    use LWP::UserAgent;
    use utf8;
    use XML::Simple;
    use Data::Dumper;

    # Code version
    $codeVersion = "mediaScraper v1.0beta";
    
    $invalidMsg .= "\n$codeVersion\n";
    $invalidMsg .= "\tUSAGE:";
    $invalidMsg .= "\tmediaScraper.exe (File|Folder) (File|Folder)...\n\n";

    # Get the directory the script is being called from
    $executable = $0;
    $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;;
    $executablePath = $`;

    # Create log file
    $logFile = "$executablePath\\scraper.log";
    open( LOGFILE, ">$logFile" ) || die "Can't open create log file";
    select(LOGFILE);
    $| = 1;

##### Initilizing Variables
    # Get the current Date
    @f = (localtime)[ 3 .. 5 ]; # grabs day/month/year values
    $startDate = ( $f[1] + 1 ) . "-" . $f[0] . "-" . ( $f[2] + 1900 );
    ( $sec, $min, $hr ) = localtime();
    $startTime = sprintf("%02d:%02d:%02d",$hr,$min,$sec);
    
    # Setup LWP user agent
    $ua = LWP::UserAgent->new;
    $ua->agent( 'Mozilla/4.0 (compatible; MSIE 5.12; Mac_PowerPC)' );
    $ua->timeout(25);
    #$ua->proxy('http', $proxy);
    
    # theTVDB.com API key
    $theTVDBapiKey = "5645B594A3F32D27";
    
    # Odds and ends
    $illCharFileRegEx = "('|\"|\\\\|/|\\||<|>|:|\\*|\\?|\\&|\\;|`)";
    $findFileRegEx = "avi|mpg|mkv|mp4|mpeg|VIDEO_TS|ts|ogm";
    
    # If we create a file or folder, make sure it gets added to this list so it can be cleaned up
    #@deleteFiles = ($logFile);

##### Let's get this show on the road
    echoPrint("Welcome to $codeVersion\n");
    echoPrint("Staring Proccesing at $startTime $startDate\n\n");
    echoPrint("  + Logfile      : $logFile\n");
    echoPrint("  + Executable   : $executable\n");
    echoPrint("  + EXE path     : $executablePath\n");
    
    # Move arguments into user array so we can modify it
    my @parameters = @ARGV;
    if (@parameters == 0)
    {
        print $invalidMsg;
        die;
    }
    
    # Initilize options data structures
    my %optionsHash;
    my @inputFiles;
    
    # Read default options from file
    $optionsFile = (-s "$executablePath\\defaults.secret.txt") ? "$executablePath\\defaults.secret.txt": "$executablePath\\defaults.txt";
    open(DEFAULTS,$optionsFile);
    $defaultsOptions = <DEFAULTS>; 
    close(DEFAULTS);
    
    # Setting options
    setOptions($defaultsOptions,\@parameters,\%optionsHash,\@inputFiles,"  ");

##### Initilize Profiles
    print "\n------------------Profiles--------------------\n";
    print "  + Looking for profiles file...\n";
    unless(-e "$executablePath\\mediaEngineProfiles")
    {
        print "! Failed!  Can't find profiles folder\n";
        die "Can't find profiles folder";
    }
    
    $optionsHash{lc("profileFolder")} = "$executablePath\\mediaEngineProfiles";
    $optionsHash{lc("binFolder")}     = "$executablePath\\mediaEngineBins";
    $optionsHash{lc("path")}          = $executablePath;
    $optionsHash{lc("theTVDBapiKey")} = $theTVDBapiKey;
    $optionsHash{lc("quote")}         = "\"";
    $optionsHash{lc("WORKDIR")}        = $executablePath;
    $optionsHash{lc("EXEPATH")}        = $executablePath;
         
    print "   - Found = ".$optionsHash{lc("profileFolder")}."\n";
    %profiles = ();
    readProfiles($optionsHash{lc("profileFolder")},\%profiles);
    
##### Find EXE's
    echoPrint("  + Seraching for avaialble binaries\n");
    @mediaEngineBins = (scanDir($optionsHash{lc("profileFolder")},"exe"),scanDir($optionsHash{lc("binFolder")},"exe"));
    foreach (@mediaEngineBins)
    {
        $mediaEngineBins{lc(getFile($_).".".getExt($_))} = $_;
        $mediaEngineBins{lc(getFile($_))} = $_;
        echoPrint("      + ".getFile($_).".".getExt($_)."\t: $_\n");
    }
##### Seperating inputFiles into individual runs
    echoPrint("  + Seraching for input files ($findFileRegEx)\n");
    if (@inputFiles)
    {
        for ($i=0;$i<@inputFiles;$i++)
        {
            if (-d $inputFiles[$i])
            {   # if its a directory
                @temp = (@temp,scanDir($inputFiles[$i],$findFileRegEx));
            }
            else
            {
                @temp = (@temp,$inputFiles[$i]);
            }
        }
        
        foreach $file (@temp)
        {
            echoPrint("    - Found File: ($file)\n");
            @perRunOptions = (@perRunOptions,"/inputFile \"$file\"".(exists $optionsHash{lc("profile")} ? "" : " /profile inputFile"));
        }
    }
    else
    {   # If there's no input file leave blank
        $perRunOptions[0] = "";
    }

##### Run through files
    foreach $perRunOptions (@perRunOptions)
    {
        echoPrint("------------ Processing ----------------\n");
        echoPrint("  + Adding per run options: ($perRunOptions)\n");
    ##### Initilizing run
        my %perRunOptionsHash = %optionsHash;
        foreach (keys %cachedHTML)
        {   # Clear out old cached varaibles, leave absoulte addresses
            if ($_ !~ /^http/)
            {
                delete $cachedHTML{$_};
            }
        }
        
    ##### Add extra options to options hash        
        setOptions($perRunOptions  ,"",\%perRunOptionsHash,\@inputFiles,"    ");               
        
        # Print out header
        if (exists $perRunOptionsHash{lc("inputFile")})
        {
            $mainProcessingTarget = "inputFile = ".getFile($perRunOptionsHash{lc("inputFile")});
        }
        elsif (exists $perRunOptionsHash{lc("showTitle")})
        {
            $mainProcessingTarget = "showTitle = ".$perRunOptionsHash{lc("showTitle")};
        }
        echoPrint("  + Processing: $mainProcessingTarget\n");
        
     ##### Checking for profile       
        echoPrint("  + Looking for profile: ".$perRunOptionsHash{lc("profile")}."\n");
        unless(exists  $profiles{lc($perRunOptionsHash{lc("profile")})})
        {   # Check for profile in Hash
            $reason = "Couldn't find encode profile: ".$perRunOptionsHash{lc("profile")};
            die $reason;    
        }
    
     ##### Pull out Profile information
        $perRunOptionsHash{lc("usingProfile")}    = $profiles{lc($perRunOptionsHash{lc("profile")})}{"name"};
        $perRunOptionsHash{lc("numCommands")}     = $profiles{lc($perRunOptionsHash{lc("profile")})}{"numCommands"};
        for ($j=0;$j<$perRunOptionsHash{lc("numCommands")};$j++)
        {   # targets
            push @{$perRunOptionsHash{lc("usingTargets")}},  $profiles{lc($perRunOptionsHash{lc("profile")})}{"targets"}[$j];
            push @{$perRunOptionsHash{lc("usingCommands")}}, $profiles{lc($perRunOptionsHash{lc("profile")})}{"commands"}[$j];
        }
        
        echoPrint("    - Found \"".$perRunOptionsHash{lc("usingProfile")}."\"\n");
        #print "      + Number of Commands : ".$perRunOptionsHash{lc("numCommands")}." \n";
        for ($j=0;$j<$perRunOptionsHash{lc("numCommands")};$j++)
        {   # targets
        #print "      + Target  #$j        : ".$perRunOptionsHash{lc("usingTargets")}[$j]."\n";
        #print "      + Command #$j        : ".$perRunOptionsHash{lc("usingCommands")}[$j]."\n";
        }
   
        # Get start time
        ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();
    
        $perRunOptionsHash{lc("WORKDIR")}        = $executablePath;
        $perRunOptionsHash{lc("EXEPATH")}        = $executablePath;
        
        if (exists $perRunOptionsHash{lc("inputFile")})
        {
            $perRunOptionsHash{lc("scratchPath")}     = getFullFile($perRunOptionsHash{lc("inputFile")}).".workFolder";
            if (!(-d $perRunOptionsHash{lc("scratchPath")}))
            {
                $mkdirString = "mkdir \"".$perRunOptionsHash{lc("scratchPath")}."";
                print "  + Making Work Directory: ($mkdirString)\n";
                `$mkdirString`;
            }
            $deleteMeFile = $perRunOptionsHash{lc("scratchPath")}."\\delete.me";
            print "    - Making delete.me file: ($deleteMeFile)\n";
            open(DELETEME,">$deleteMeFile");
            print DELETEME "Delete me to keep files from being deleted for debugging\n";
            close(DELETEME);

            $perRunOptionsHash{lc("scratchName")}     = getFile($perRunOptionsHash{lc("inputFile")}).".scratch";
            $perRunOptionsHash{lc("inputMain")}       = $perRunOptionsHash{lc("inputFile")};
            $perRunOptionsHash{lc("original")}        = $perRunOptionsHash{lc("inputFile")};
            $perRunOptionsHash{lc("passLogfile")}     = $perRunOptionsHash{lc("scratchPath")}."\\passLogFile.log";
            
            # Adding scratch folder to delete list
            @deleteFiles = (@deleteFiles,$perRunOptionsHash{lc("scratchPath")});
            print "    - Adding temp dir to delete list(@deleteFiles)\n";
        }
    
        print "  + Using Options\n";
        foreach $key (sort(keys %perRunOptionsHash))
        {
            print "     - $key($perRunOptionsHash{$key})\n";        
        }
        $encodeCLI = 0;
        
        if (exists $perRunOptionsHash{lc("inputFile")})
        {   # Getting Video Info
            getVideoInfo($perRunOptionsHash{lc("inputFile")},"  ",\%perRunOptionsHash,\%mediaEngineBins);
            if ($perRunOptionsHash{lc("profile")} =~ /encode/)
            {
                detectVideoProperties($perRunOptionsHash{lc("inputFile")},"  ",\%perRunOptionsHash,\%mediaEngineBins);
            }
        }
        
        echoPrint("\n######## Starting Processing\n");
        while($perRunOptionsHash{lc("numCommands")} > 0)
        {           
            $perRunOptionsHash{lc("commandNum")}++;
            # shift off first command
            $currentTarget = shift(@{$perRunOptionsHash{lc("usingTargets")}});
            $currentCommand = shift(@{$perRunOptionsHash{lc("usingCommands")}});
            $perRunOptionsHash{lc("numCommands")}--;
                        
            echoPrint("\n    - Remaining Commands (".$perRunOptionsHash{lc("numCommands")}."): ($currentCommand)\n");
            $n=0;
            #foreach $encoder (@{$perRunOptionsHash{lc("usingTargets")}})
            #{ For debugging
            #    print "      + ($n) $encoder\n";
            #    $n++;
            #}
            # Replacing snippits
            
            # Parseing Parameters
            $currentTargetOrig  = $currentTarget;
            $currentCommandOrig = $currentCommand;
            $currentCommand     = processCondLine($currentCommand,
                                                  \%perRunOptionsHash,
                                                  \%profiles);
                                                  
            echoPrint("      + Command : $currentCommand\n");    
    
            %currentCommand = {};
            @currentCommand = splitWithQuotes($currentCommand," ");        
            while (@currentCommand != 0)
            {
                if ($currentCommand[0] =~ m#/([a-zA-Z0-9_]+)#i)
                {   # Generic add sub string
                    print "        - Adding to command parameter hash \n";
                    $currentCommand[0] =~ m#/([a-zA-Z0-9_]+)#i;
                    $key = $1;
                    print "          + Key: $key\n";
                    $currentCommand{lc($key)} = "";   
                    if (!($currentCommand[1] =~ m#^/# || $currentCommand[1] eq "") || $currentCommand[1] =~ m#^/.*/# )
                    {   # If the next parameter data for switch
                        if ($currentCommand[1] =~ /\@\@([^\@]*)\@\@/)
                        {   # For replacing at the last minute to avoid the data getting parsed
                            $currentCommand{lc($key)} = $perRunOptionsHash{lc($1)};
                        }
                        else
                        {
                            $currentCommand{lc($key)} = $currentCommand[1];
                        }
                        print "          + Value: $currentCommand{lc($key)}\n";
                        shift(@currentCommand);    # Remove next parameter also
                    }
                    shift(@currentCommand);      
                }
                else
                {
                  print "        ! couldn't understand ($currentCommand[0]), throwing it away\n";
                  shift(@currentCommand);  
                }
            }
            
            $snipsCurrentTarget = $currentTarget;
            while($currentTarget =~ /%%SNIP:([^%]*)%%/i)
            {
                $snippitName = $1;
                $snipToReplace = $&;
                $currentTarget =~ s#\Q$snipToReplace\E#$profiles{lc($snippitName)}{"targets"}[0]#g;
                print "      + Replacing snippit $snippitName : $currentTarget\n";
            }
                  
            # Remove Comments
            $commentsCurrentTarget = $currentTarget;
            $currentTarget =~ s/##([a-zA-Z0-9_ ]+)##//g;
                    
            # Process out conditional statments
            $conditionalsCurrentTarget = $currentTarget;
            $currentTarget = processCondLine($currentTarget,
                                             \%perRunOptionsHash,
                                             \%profiles);
                                                    
            #echoPrint("      + Result : $currentTarget\n");
            if (!($currentTarget eq ""))
            {
                @regEXCapture = ();
                while($currentTarget =~ m#\$\$([a-zA-Z0-9_]*)\$\$#)
                {
                    $variable = $1;
                    push @regEXCapture, $variable;
                    $currentTarget =~ s#\$\$$variable\$\$##;
                    #echoPrint("        - \$".scalar(@regEXCapture).": $variable\n");
                }
                echoPrint("      + Target  : $currentTarget\n");
                for ($i=0;$i<@regEXCapture;$i++)
                {
                    print "        - \$".($i+1).": $regEXCapture[$i]\n";
                }
                
                # Add use/password to credientials
                if (exists $currentCommand{lc("password")} && 
                    exists $currentCommand{lc("user")} &&
                    exists $currentCommand{lc("get")})
                {
                    addCredentials($currentTarget,\%currentCommand,\%perRunOptionsHash,$ua);  
                }
                
                
                if (exists $currentCommand{lc("die")})
                {   # Die, for debugging      
                    die;
                }
                elsif (exists $currentCommand{lc("insertFunction")})
                {   # Insert function
                    insertFunction($currentTarget,\%currentCommand,\%perRunOptionsHash,\%profiles,0); 
                }
                elsif (exists $currentCommand{lc("branch")})
                {   # Insert function
                    $branch = 1;
                    insertFunction($currentTarget,\%currentCommand,\%perRunOptionsHash,\%profiles,$branch); 
                }
                elsif (exists $currentCommand{lc("break")})
                {   # Be done!
                    $perRunOptionsHash{lc("numCommands")} = 0;
                    @{$perRunOptionsHash->{lc("usingTargets")}} = ();
                    @{$perRunOptionsHash->{lc("usingCommands")}} = ();
                }
                if (exists $currentCommand{lc("setOptions")})
                {   # Insert function
                    setOptions($currentTarget  ,""          ,\%perRunOptionsHash,\@inputFiles,"        ");           
                }
                elsif (exists $currentCommand{lc("exe")})
                {   # Insert function
                    launchEXE($currentTarget,\%currentCommand,\%mediaEngineBins,\%perRunOptionsHash);
                }          
                elsif (exists $currentCommand{lc("output")})
                {   # Insert function
                    outputFile($currentTarget,\%currentCommand,\%perRunOptionsHash,\%profiles);
                }
                elsif (exists $currentCommand{lc("get")})
                {    
                    getHTML($currentTarget,\%currentCommand,\%perRunOptionsHash,\%cachedHTML,$ua);
                }
                elsif (exists $currentCommand{lc("use")})
                {
                    captureData($currentTarget,\%currentCommand,\%perRunOptionsHash,\%cachedHTML);
                }
            }
            else
            {
                echoPrint("      + Command Empty, Skipping: \"$currentTarget\"\n");
                next;
            }
            
            foreach $key (sort(keys %perRunOptionsHash))
            {   # Convert Output files to Full input files
                if ($key =~ /outputFile(.+)/i)
                {
                    $newKey = "input$1";
                    $currentTarget =~ /\Q$perRunOptionsHash{lc($key)}\E\.[a-zA-Z0-9]{2,}/;
                    $newOutputFile = $&;
                    $perRunOptionsHash{lc($newKey)} = $newOutputFile;
                    print "  + $key -> $newKey ($newOutputFile)($currentTarget)\n";
                    getVideoInfo($perRunOptionsHash{lc($newKey)},"          ",\%perRunOptionsHash,\%mediaEngineBins);
                    delete $perRunOptionsHash{lc($key)};
                }
            }
        }
        deleteTempFiles(\@deleteFiles);
    }
######################################################
###
###           End of Main Program
    
##### Get Video Info
    sub getVideoInfo()
    {
        my ($video,$baseSpace,$perRunOptionsHash,$binFiles) = @_;
        my $ffmpegString  = encode('UTF-8',"\"".$binFiles->{lc("ffmpeg.exe")}."\" -dumpmetadata -v 2 -i \"$video\" 2>&1");
        my $ffmpegOutput = `$ffmpegString`;    
        my @ffmpegOutput = split(/(\n|\r)/,$ffmpegOutput);   
        $videoInfoHash = \%{$perRunOptionsHash->{videoInfo}{lc($video)}};
        
        $videoInfoHash->{lc("fileSize")} = (-s $video)/1024;
        
        echoPrint("$baseSpace+ Getting Video Info: ($video)(".$videoInfoHash->{lc("fileSize")}.")\n");

        foreach (@ffmpegOutput)
        {
            chomp;
            if ( $_ =~ m#I/O error occured# || $_ =~ m#Unknown format$#)
            {
                echoPrint("$baseSpace  ! Error in ffmpeg log: ($&)\n");
                return;
            }
    
            if ( $_ =~ /Input #0, ([a-zA-Z0-9_\-]+)/ )
            {
                $videoInfoHash->{lc("inputLine")} = $_;
                $videoInfoHash->{lc("videoContainer")} = $1;
                echoPrint("$baseSpace  - Input Line:          $_\n");
                print "$baseSpace    + videoContainer = ".$videoInfoHash->{lc("videoContainer")}."\n";
            }
    
            if ( $_ =~ /Video:/ )
            {
                $videoInfoHash->{lc("videoInfo")} = $_;
                echoPrint("$baseSpace  - Video Info Line: ".$videoInfoHash->{lc("videoInfo")}."\n");
    
                # Get Resolution
                if ( $videoInfoHash->{lc("videoInfo")} =~ /AR: (([0-9]{1,3}):([0-9]{1,3})),/)
                {   # Use directly reported AR
                    $videoInfoHash->{lc("ffmpegAR")} = $1;
                    $videoInfoHash->{lc("ffmpegARValue")} = $2/$3;
                    $videoInfoHash->{lc("dvdAR")} = ( $videoInfoHash->{lc("ffmpegARValue")} < 1.55 ) ? "4:3" : "16:9";
                    print "$baseSpace    + ffmpeg Reported Aspect Ratio (ffmpegAR)   = ".$videoInfoHash->{lc("ffmpegAR")}."\n";
                    print "$baseSpace      - Estimated DVD aspect ratio {dvdAR)      = ".$videoInfoHash->{lc("dvdAR")}."\n";
                }
                elsif ( $videoInfoHash->{lc("videoInfo")} =~ /(\d{3,4})x(\d{3,4})/)
                {   # Use the resolution to guess the AR
                    $videoInfoHash->{lc("ffmpegAR")} = $1 / $2;
                    $videoInfoHash->{lc("ffmpegARValue")} = $videoInfoHash->{lc("ffmpegAR")};
                    $videoInfoHash->{lc("dvdAR")} = ( $videoInfoHash->{lc("ffmpegARValue")} < 1.55 ) ? "4:3" : "16:9";
                    print "$baseSpace    + ffmpeg Reported Aspect Ratio (ffmpegAR)   = ".$videoInfoHash->{lc("ffmpegAR")}."\n";
                    print "$baseSpace      - Estimated DVD aspect ratio {dvdAR)      = ".$videoInfoHash->{lc("dvdAR")}."\n";
                }
                
                if ( $videoInfoHash->{lc("videoInfo")} =~ /(\d{3,4})x(\d{3,4})/)
                {   
                    $videoInfoHash->{lc("videoResolution")} = $&;
                    $videoInfoHash->{lc("xRes")} = $1;
                    $videoInfoHash->{lc("yRes")} = $2;
                    print "$baseSpace    + videoResolution   = ".$videoInfoHash->{lc("videoResolution")}."\n";
                }
                             
                if ( $videoInfoHash->{lc("videoInfo")} =~ /(\d+) kb/)
                {   # Get Bitrate
                    $videoInfoHash->{lc("videoBitrate")} = $1;
                    print "$baseSpace    + videoBitrate      = ".$videoInfoHash->{lc("videoBitrate")}."\n";
                }
                
                if ( $videoInfoHash->{lc("videoInfo")} =~ /\[0x([a-z0-9]{3})\]/)
                {   # Video PID
                    $videoInfoHash->{lc("videoPID")} = $1;
                    print "$baseSpace    + videoPID     = ".$videoInfoHash->{lc("videoPID")}."\n";
                }
                # Get Framerate
                if ( $videoInfoHash->{lc("videoInfo")} =~ /, ([0-9\.]*) fps/)
                {
                    $videoInfoHash->{lc("frameRate")} = $1;
                    print "$baseSpace    + frameRate   = ".$videoInfoHash->{lc("frameRate")}."\n";
                }
    
                # Get video codec
                if ( $videoInfoHash->{lc("videoInfo")} =~ /Video: ([a-zA-Z0-9]*),/)
                {
                    $videoInfoHash->{lc("videoCodec")} = $1;
                    print "$baseSpace    + videoCodec      = ".$videoInfoHash->{lc("videoCodec")}."\n";
                }
    
                if ( $videoInfoHash->{lc("videoInfo")} =~ /(interlaced|progressive)/)
                {
                    $videoInfoHash->{lc("$1")} = 1;
                    print "$baseSpace    + ffmpeg reports $1\n";
                }
            }
            elsif ( $_ =~ /Audio: ([a-zA-Z0-9]+)/ )
            {
                $videoInfoHash->{lc("audioInfo")} = $_; 
                echoPrint("$baseSpace  - Audio Info Line: ".$videoInfoHash->{lc("audioInfo")}."\n");
    
                if ($videoInfoHash->{lc("audioInfo")} =~ /Audio: ([a-zA-Z0-9]+)/)
                {   # Get Audio Format
                    $videoInfoHash->{lc("audioCodec")} = $1;
                    print "$baseSpace    + audioCodec     = ".$videoInfoHash->{lc("audioCodec")}."\n";
                }
      
                if ($videoInfoHash->{lc("audioInfo")} =~ /(\d+) Hz/)
                {   # Audio Sample Rate
                    $videoInfoHash->{lc("audioSampleRate")} = $1;
                    print "$baseSpace    + audioSampleRate = ".$videoInfoHash->{lc("audioSampleRate")}."\n";
                }
                
                if ($videoInfoHash->{lc("audioInfo")} =~ /(\d+) kb.s/)
                {   # Audio Bitrate
                    $videoInfoHash->{lc("audioBitRate")} = $1;
                    print "$baseSpace    + audioBitRate    = ".$videoInfoHash->{lc("audioBitRate")}."\n";
                }
                
                if ($videoInfoHash->{lc("audioInfo")} =~ /\[0x([a-z0-9]{3})\]/)
                {   # Audio PID
                    $videoInfoHash->{lc("audioPID")} = $1;
                    print "$baseSpace    + audioPID    = ".$videoInfoHash->{lc("audioPID")}."\n";
                }
                
                if ($videoInfoHash->{lc("audioInfo")} =~ /5:1/)
                {   # Get Audio Format
                    $videoInfoHash->{lc("audioChannels")} = 6; 
                    print "$baseSpace    + audioChannels  = ".$videoInfoHash->{lc("audioChannels")}."\n";
                }           
                elsif ($videoInfoHash->{lc("audioInfo")} =~ /stereo/)
                {
                    $videoInfoHash->{lc("audioChannels")} = 2;
                    print "$baseSpace    + audioChannels  = ".$videoInfoHash->{lc("audioChannels")}."\n";
                }              
            }
            elsif ( $_ =~ /Duration: ([0-9][0-9]):([0-9][0-9]):([0-9][0-9])/ )
            {
                echoPrint("$baseSpace  - Duration Line:     $_\n");
                $videoInfoHash->{lc("durationMin")} = int($1 * 60 + $2 + $3 / 60);
                $videoInfoHash->{lc("durationSec")} = int($1 * 3600 + $2 * 60 + $3);
                print "$baseSpace    + totalMin = ".$videoInfoHash->{lc("durationSec")}."\n";
            }
        }
    }

##### Parse Profile Files
    sub processCondLine
    {
        my ($currentTarget,$perRunOptionsHash,$profiles) = @_;        
        my $replaceString = $currentTarget;
        
        $currentTarget = substituteStrings($currentTarget,
                                           $perRunOptionsHash,
                                           $profiles);
            
        while(matchShortest($currentTarget,"\\?[0-9a-zA-Z ]*>(.*?)<[0-9a-zA-Z ]*\\?"))
        {   # Match shortest conditional
            $replaceString = "";
            $shortestCond = matchShortest($currentTarget,"\\?[0-9a-zA-Z ]*>(.*?)<[0-9a-zA-Z ]*\\?");
            @conditionalList = split(/<=>/,$shortestCond);
            print "      + Processing conditional: $shortestCond\n";
            foreach $cond (@conditionalList)
            {
                if ($cond =~ /<:>/)
                {
                    # Add in a group to ensure that it has atleast one
                    $boolList = "(>$`<)";
                    $text = $';
                    while(matchShortest($boolList,"\\(>(.*?)<\\)"))
                    {
                        $shortestBool = matchShortest($boolList,"\\(>(.*?)<\\)");
                        print "        - Conditional List: $shortestBool\n";
                        $overall = 0;                            
                        @toCheck = ();
                        @checkWith = ("||");
                        @everyThing = split(/(\|\||&&|!\||!&|:\|)/,$shortestBool);
                        for($j=0;$j<@everyThing;$j+=2)
                        {
                            push(@toCheck,$everyThing[$j]);
                            push(@checkWith,$everyThing[($j+1)]);
                        }
                        foreach $check (@toCheck)
                        {
                            $result = checkConditional($check,$text,$perRunOptionsHash,$profiles);
                            $logicalOp = shift(@checkWith);
                            if ($logicalOp eq "&&")
                            {
                                $overall = (($overall == 1) && ($result == 1) ? 1 : 0);
                            }
                            elsif($logicalOp eq "!|")
                            {
                                $overall = (($result == 1) && ($overall == 1)? 0 : 1);
                            }
                            elsif($logicalOp eq "!&")
                            {
                                $overall = (($result == 0) && ($overall == 0)? 1 : 0);
                            }
                            elsif($logicalOp eq ":|")
                            {
                                $overall = (($result == $overall) ? 0 : 1);
                            }
                            else # ||
                            {
                                $overall = (($result == 1) ? 1 : $overall);
                            }
                        }
                        $boolList =~ s/\(>\Q$shortestBool\E<\)/$overall/;
                    }
                    if ($overall == 1)
                    {
                        print "        = Overall: True, using: $text\n";
                        $replaceString = $text;
                        last;
                    }
                }
                else
                {   # No conditionals, just the else
                    print "        = Overall: False, using else: $cond\n";
                    $replaceString = $cond;
                    last;
                }
            }
            if ($replaceString eq "")
            {
                print "        = Overall: False, leaving blank!\n";
            }
            
            $currentTarget =~ s/\?\d?>\Q$shortestCond\E<\d?\?/$replaceString/;
        }
        return $currentTarget;
    }

    sub checkConditional
    {
        my ($check, 
            $text,
            $perRunOptionsHash,
            $profiles) = @_;
            
        my $condTrue                    = 0;
        my $negate                      = 0;
        my $key                         = "";
              
        print "          + Checking: $check\n";
        if ($check =~ /^!/)
        {
            $negate = 1;
            $check =~ s/!//g;  #Remove the !
        }
        
        if($check eq "1" || $check eq "0")
        {
            print "            - Previously Resolved Condition: $check\n";  
            $condTrue = $condTrue = checkProfileCond($check, $negate, $text);;
        }
        elsif ($check =~ /EXT:([a-zA-Z0-9]+)/i)
        {
            $extToCheck = $1;
            print "            - Does file exist next to inputFile with a (.$extToCheck) extention? (".$perRunOptionsHash->{lc("inputFile")}.")\n";
            $condTrue = checkProfileCond((((-e getFullFile("$perRunOptionsHash->{lc(inputFile)}").$extToCheck ||
                                            -e "$perRunOptionsHash->{lc(inputFile)}.$extToCheck"))?1:0), $negate, $text); 
            $perRunOptionsHash->{lc("check")} = $extToCheck;
        }
        elsif ($check =~ /EXISTS:(.*)/i)
        {
            $checkFile = encode('ISO-8859-1' , $1);
            print "            - Does file ($checkFile) exist?\n";
            $condTrue = checkProfileCond((((-e "$checkFile" || 
                                            -e $perRunOptionsHash->{lc("SAGE_DIR")}."\\$checkFile"))?1:0), $negate, $text); 
            $perRunOptionsHash->{lc("check")} = $checkFile;
        }
        elsif ($check =~ /PATH:(.*)/i)
        {
            $checkDirectory = encode('ISO-8859-1' , $1);
            print "            - Does path to ($checkDirectory) exist?\n";
            $condTrue = checkProfileCond(((-d getPath("$checkDirectory"))?1:0), $negate, $text);
            $customSubStringArray->{lc("check")} = $checkDirectory;
        }
        elsif ($check =~ /DIRECTORY:(.*)/i)
        {
            $checkDirectory = encode('ISO-8859-1' , $1);
            print "            - Does file ($checkDirectory) exist?\n";
            $condTrue = checkProfileCond((((-d "$checkDirectory" || -d $perRunOptionsHash->{lc("SAGE_DIR")}."\\$checkDirectory" || -d $perRunOptionsHash->{lc("SAGE_DIR")}."\\mediaEngineBins\\$checkDirectory"))?1:0), $negate, $text); 
            $perRunOptionsHash->{lc("check")} = $checkDirectory;
        }
        elsif ($check =~ /(.*)(=eq=|=~|>|<|>=|<=|==)(.*)/i)
        {   # Checking videoInfo hash
            $perRunOptionsHash->{lc("right")} = $3;
            $lowerCase  = lc($3);
            $meathod    = $2;
            $checkValue = $1;
            if ($checkValue =~ /([a-zA-Z0-9_]*):([a-zA-Z0-9_]+)/)
            {
                $inputFile = $1;
                $key = $2;
                if (exists $perRunOptionsHash->{lc($inputFile)})
                {
                    $fileKey = lc($perRunOptionsHash->{lc($inputFile)});
                }
                $checkValue = $perRunOptionsHash->{videoInfo}{lc($fileKey)}{lc($key)};
                print "            - Does perRunOptionsHash{videoInfo}{$inputFile}{\"$key\"} (".$perRunOptionsHash->{videoInfo}{lc($fileKey)}{lc($key)}.") $meathod $lowerCase?\n";
                print "              + file key = $fileKey\n";
            }
            else
            {
                 print "            - Does ($checkValue) $meathod ($lowerCase)?\n";
            }
            $perRunOptionsHash->{lc("left")} = $checkValue;
            $checkValue = lc($checkValue);
    
            if ($meathod eq "=~")
            {
                $condStatment = ($checkValue =~ /$lowerCase/)?1:0;
            }
            elsif ($meathod eq "==")
            {
                $condStatment = ($checkValue == $lowerCase)?1:0;
            }
            elsif ($meathod eq ">")
            {
                $condStatment = ($checkValue > $lowerCase)?1:0;
            }
            elsif ($meathod eq "<")
            {
                $condStatment = ($checkValue < $lowerCase)?1:0;
            }
            elsif ($meathod eq "<=")
            {
                $condStatment = ($checkValue <= $lowerCase)?1:0;
            }
            elsif ($meathod eq ">=")
            {
                $condStatment = ($checkValue >= $lowerCase)?1:0;
            }
            else
            {   # else assume eq
                $condStatment = ($checkValue eq $lowerCase)?1:0;
            }
            
            if ($key eq "" || exists $perRunOptionsHash->{videoInfo}{lc($fileKey)}{lc($key)})
            {
                $condTrue = checkProfileCond($condStatment, $negate, $text);
            }
            else
            {
                print "              ! Key not found\n";
                $condTrue = checkProfileCond(0, $negate, $text);
            }
        }
        elsif ($check =~ /([a-zA-Z0-9_]*):([a-zA-Z0-9]+)/i)
        {
            $inputFile = $1;
            $key = $2;
            if (exists $perRunOptionsHash->{lc($inputFile)})
            {
                $fileKey = lc($perRunOptionsHash->{lc($inputFile)});
            }
            print "            - Does video info property ($check) exist?\n";
            $condTrue = checkProfileCond((exists $perRunOptionsHash->{videoInfo}{lc($fileKey)}{lc($key)}?1:0), $negate, $text);
            $perRunOptionsHash->{lc("check")}  = $perRunOptionsHash->{videoInfo}{lc($fileKey)}{lc($key)};
        }
        else
        {   # Else, check for custom conditional  
            print "            - Does custom conditional ($check) exist? ($perRunOptionsHash->{lc($check)})\n";
            $condTrue = checkProfileCond((exists $perRunOptionsHash->{lc($check)}), $negate, $text);                             
        }
        return $condTrue;
    }
    
    sub checkProfileCond
    {
        my ($inputCond,$negate,$text) = @_;
        my $condTrue = 0;
    
        if (  ($inputCond   && $negate == 0) ||
            (!($inputCond)  && $negate == 1))
        {
            print "              + ".(($negate == 1) ? "!False (True)" : "True")."\n";
            $condTrue = 1;
        }
        else
        {
            print "              + ".(($negate == 1) ? "!True (False)" : "False")."\n";
        }
        return $condTrue;
    }
    
    
    sub checkProfileCond
    {
        my ($inputCond,$negate,$text) = @_;
        my $condTrue = 0;
    
        if (  ($inputCond   && $negate == 0) ||
            (!($inputCond)  && $negate == 1))
        {
            print "              + ".(($negate == 1) ? "!False (True)" : "True")."\n";
            $condTrue = 1;
        }
        else
        {
            print "              + ".(($negate == 1) ? "!True (False)" : "False")."\n";
        }
        return $condTrue;
    }
    
    sub matchShortest
    {
      my ($string, $regEx) = @_;
      my $shortest;
      my $length = length $string;
      
      while ($string =~ /(?=$regEx)/g) {
        $m_len = length $1;
        # save the match if it's shorter than the last one
        ($shortest, $length) = ($1, $m_len) if $m_len < $length;
      }
      
      return $shortest;
    }

sub substituteStrings
{
    my( $currentTarget,
        $perRunOptionsHash,
        $profiles) = @_;     
        
    while($currentTarget =~ /%%SNIP:([^%]*)%%/i)
    {
        $snippitName = $1;
        $snipToReplace = $&;
        $currentTarget =~ s#\Q$snipToReplace\E#$profiles->{lc($snippitName)}{"targets"}[0]#g;
        print "      + Replacing snippit $snippitName : $currentTarget\n";
    }
    
    while($currentTarget =~ /%%OUTPUT_([^%]*)%%/i)
    {   # Generate name for new output file
        $outputName = $1;
        $outputExt  = $2;
        $snipToReplace = $&;
        $newInputFile = "outputFile".$outputName;
        $perRunOptionsHash->{lc($newInputFile)} = $perRunOptionsHash->{lc("scratchPath")}."\\".$perRunOptionsHash->{lc("scratchName")}.".".$perRunOptionsHash->{lc("commandNum")}.".$outputName";      
        $currentTarget =~ s#\Q$snipToReplace\E#%%$newInputFile%%#g;
        print "      + Replacing outputFile $snipToReplace -> $newInputFile : ($perRunOptionsHash->{lc($newInputFile)})\n";
    }    
                    
    while($currentTarget =~ /%%([a-zA-Z0-9_:\*]*)%%/)
    {
        my $wholeSubString = $&;
        my $subString = $1;
        my $multiplyBy = 1;
        my $parseMeathod = "";
        my $replaceString = "";
        my @parseMeathod = ();
        
        if ($subString =~ /\*([0-9]*(\.[0-9]+){0,1})/)
        {   # In case we need to do some math
            $subString = $`;
            $multiplyBy = $1;
        }
        
        while ($subString =~ /_([a-zA-Z0-9]*)$/)
        {   # Check for parse meathod
            $subString    = $`;
            push(@parseMeathod,$1);
        }

        if ($subString =~ /([a-zA-Z0-9_]*):([a-zA-Z0-9_]*)/)
        {   # Look in video info hash first
            if (exists  $perRunOptionsHash->{videoInfo}{lc($perRunOptionsHash->{lc($1)})}{lc($2)})
            {   # Then Check the global hash
                $replaceString = $perRunOptionsHash->{videoInfo}{lc($perRunOptionsHash->{lc($1)})}{lc($2)};
            }            
        }
        elsif (exists  $perRunOptionsHash->{lc($subString)})
        {   # Then Check the global hash
            $replaceString = $perRunOptionsHash->{lc($subString)};
        }

        foreach $meathod (@parseMeathod)
        {   
            #print "          - $meathod In: ($wholeSubString) with ($replaceString)\n";
            if ($multiplyBy != 1)
            {
                $replaceString *= $multiplyBy;
            }
    
            if ($meathod eq "STRIPZEROS")
            {
                $replaceString =~ s/^0+//g;
            }
            elsif ($meathod eq "WIN32")
            {
                $replaceString =~ s/$illCharFileRegEx//g;
            }
            elsif ($meathod eq "ESCCHARS")
            {
                $replaceString =~ s#(\{|\}|\[|\]|\(|\)|\^|\$|\.|\||\*|\+|\?|\\)#\\$1#g;
            }
            elsif ($meathod eq "STRIPSPACES")
            {
                $replaceString = trim($replaceString);
            }
            elsif ($meathod eq "DOTTOSPACE")
            {
                $replaceString =~ s/[\._]/ /g;
            }
            elsif ($meathod eq "EXT")
            {
                $replaceString = getExt($replaceString);
            }
            elsif ($meathod eq "FILE")
            {
                $replaceString = getFileWExt($replaceString);
            }
            elsif ($meathod eq "NAME")
            {
                $replaceString = getFile($replaceString);
            }
            elsif ($meathod eq "PATH")
            {
                $replaceString = getPath($replaceString);
            }
            elsif ($meathod eq "DIR")
            {
                $replaceString = getFile(getPath($replaceString));
            }
            elsif ($meathod eq "DRIVE")
            {
                $replaceString = getDriveLetter($replaceString);
            }
            elsif ($meathod eq "FULLFILE")
            {
                $replaceString = getFullFile($replaceString);
            }
            #print "          - $meathod Out: ($wholeSubString) with ($replaceString)\n";
        }
        print "        - Replacing: $wholeSubString with ($replaceString)\n";
        $currentTarget =~ s/\Q$wholeSubString\E/$replaceString/g;
    }   
    return $currentTarget;

}

##### Scan a directory and return an array of the matching files
    sub scanDir
    {
        my ($inputFile, $fileFilter) = @_;
        my @files = ();
        my @dirs  = ();
        my $file;
        my $dir;
        $inputFile =~ s/\"//g;
        $inputFile =~ s/(\\|\/)$//g;
        echoPrint("    - Scanning Directory: $inputFile\n");
        opendir(SCANDIR,"$inputFile");
        my @filesInDir = readdir(SCANDIR);
        if (!(-e "$inputFile\\$file\\mediaScraper.skip"))
        {
            foreach $file (@filesInDir)
            {
                #echoPrint("-> $file\n");
                next if ($file =~ m/^\./);
                next if !($file =~ m/($fileFilter)$/ || -d "$inputFile\\$file");       
                if (-d "$inputFile\\$file" && !($file =~ m/VIDEO_TS$/)) { push(@dirs,"$inputFile\\$file"); }
                else { push(@files,"$inputFile\\$file"); } 
            }
            foreach $dir (@dirs)
            {
                @files = (@files,scanDir($dir,$fileFilter));     
            }
        }
        else
        {
            echoPrint("      + Found .skip, ignoring Directory\n");
        }
        #echoPrint("!!! @files\n");
        return @files;  
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
                print "        - Replacing $&: $quoteHash{$1}\n";
            }
        }
        return @splitWithQuotes;
    }

##### Add credentials to the user Agent
    sub addCredentials
    {
        my ($currentTarget,$currentCommand,$perRunOptionsHash,$ua) = @_;
        my $serverIP;
        if ($currentTarget =~ m#http:(\\\\|\/\/)([^\\\/]*)#)
        {
            $serverIP = $2;
            echoPrint("        - Adding Credientials: ".$currentCommand->{lc("user")}."\@$serverIP\n");
            $ua->credentials(  # add this to our $browser 's "key ring"
              $serverIP.':8080',
              '',
              $currentCommand->{lc("user")} => $currentCommand->{lc("password")}
            );
            $ua->credentials(  # add this to our $browser 's "key ring"
              $serverIP.':8080',
              '',
              $currentCommand->{lc("user")} => $currentCommand->{lc("password")}
            );
        } 
    }

##### Append a profile to the execution list
    sub insertFunction
    {
        my ($currentTarget,$currentCommand,$perRunOptionsHash,$profiles,$branch) = @_;
        my $j; 
        if (exists $profiles->{lc($currentTarget)})
        {
            print "        - Found function profile ($currentTarget)\n";
            if (!$branch)
            {
                print "        - Adding $profiles->{lc($currentTarget)}{numCommands} targets\n";
                $perRunOptionsHash->{lc("numCommands")} += $profiles->{lc($currentTarget)}{"numCommands"};         
            }
            else
            {
                print "        - Branching to $profiles{lc($currentTarget)}{numCommands} targets\n";
                $perRunOptionsHash->{lc("numCommands")} = $profiles{lc($currentTarget)}{"numCommands"};
                @{$perRunOptionsHash->{lc("usingTargets")}} = ();
                @{$perRunOptionsHash->{lc("usingCommands")}} = ();
            }
    
            for ($j=$profiles->{lc($currentTarget)}{"numCommands"}-1;$j>=0;$j--)
            {
                unshift(@{$perRunOptionsHash->{lc("usingTargets")}},$profiles->{lc($currentTarget)}{"targets"}[$j]);
                unshift(@{$perRunOptionsHash->{lc("usingCommands")}},$profiles->{lc($currentTarget)}{"commands"}[$j]);
            }   
        }
        else
        {
            print "        ! Couldn't find function profile ($currentTarget)\n";                      
        }
    }

##### Populate an options Hash
    sub setOptions
    {
        my ($optionsString,$optionsArrry,$optionsHash,$inputFiles,$logSpacing) = @_; 
        my @newOptions;
        my $key;
        echoPrint("$logSpacing+ Parsing switches\n");
        echoPrint("$logSpacing  - optionsString: $optionsString\n");
        if (@{$optionsArrry}) { echoPrint("$logSpacing  - optionsArray: @{$optionsArrry}\n"); }
        if ($optionsString)
        {
            @newOptions= splitWithQuotes($optionsString," ");
        }
        @newOptions = (@{$optionsArrry},@newOptions,);
        while (@newOptions != 0)
        {
            if ($newOptions[0] =~ m#^/ERROR$#)
            {   # Message from profile that an unrecoverable error has occured   
                $reason = "Error reported from profile file: $newOptions[1]";
                die $reason;
            }  
            elsif ($newOptions[0] =~ m#^/([a-zA-Z0-9_]+)#i)
            {   # Generic add sub string
                echoPrint("$logSpacing  - Adding to to options Hash\n");
                $key = $1;
                echoPrint("$logSpacing    + Key: $key\n");
                $optionsHash->{lc($key)} = "";   
                if (!($newOptions[1] =~ m#^/# || $newOptions[1] eq "") || $newOptions[1] =~ m#^/.*/# )
                {   # If the next parameter data for switch
                    $optionsHash->{lc($key)} = $newOptions[1];
                    echoPrint("$logSpacing    + Value: $optionsHash->{lc($key)}\n");
                    shift(@newOptions);    # Remove next parameter also
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
            elsif ($inputFiles && (-e "$newOptions[0]" || -d "$newOptions[0]"))
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
    }

##### Launch an EXE
    sub launchEXE
    {
        my ($currentTarget,$currentCommand,$binFiles,$perRunOptionsHash) = @_;
        my $runCommand;
        my $teeOutput;
        my $comment;
        my $processObject;
        my $logFile = $perRunOptionsHash->{lc("scratchPath")}."\\".$perRunOptionsHash->{lc("scratchName")}.".".$perRunOptionsHash->{lc("commandNum")}.".".getFile($currentCommand->{lc("exe")});
        
        if ($currentTarget =~ /^!/)
        {   # Log to stdout
            $teeOutput        = 1;
            $currentTarget    = $';
        }
        
        if ($currentTarget =~ /^#([^#]*)#/)
        {   # Remove Comments
            $comment        = $1;
            $currentTarget  = $';    
        }
                  
        if (exists $binFiles->{lc($currentCommand->{lc("exe")})})
        {
            $runEXE     = $binFiles->{lc($currentCommand->{lc("exe")})};
            $runCommand = "\"$runEXE\" $currentTarget";
        }
        else
        {   # assume its a system command and try and run it anyway
            $runEXE     = $currentCommand->{lc("exe")};
            $runCommand = $currentCommand->{lc("exe")}." $currentTarget";
        }
        

        if ($teeOutput)
        {
            $captureLogTee = "\"".$binFiles->{lc("mtee.exe")}."\" \"$logFile.log\"";
            $runCommand = encode('ISO-8859-1',"$runCommand 2>\"$logFile.err.log\" \| $captureLogTee");
            echoPrint("        - Executing command: $runCommand\n");
            select(STDOUT);
            print "\n################# ".$currentCommand->{lc("exe")}." Output $comment ###############\n";
            system($runCommand);
            select(LOGFILE);
            $averageFPS = captureFPS("$logFile.log");
            echoPrint("\n################# ".$currentCommand->{lc("exe")}." $comment Average FPS = $averageFPS ###############\n\n");  
        }
        else
        {
            $runCommand = encode('ISO-8859-1',"$runCommand > \"$logFile.log\" 2>&1");
            echoPrint("        - Executing command: $runCommand\n");
            `$runCommand`;
        } 
    }

##### Write to a formated output file               
    sub outputFile
    {
        my ($currentTarget,$currentCommand,$perRunOptionsHash,$profiles) = @_;
        my $openSuccess = 0;
        my $outputLine;
        my $outputFile;
        my $encoding = (exists $currentCommand->{lc("encoding")} ? $currentCommand->{lc("encoding")} : "utf8");
        
        $currentTarget = encode("ISO-8859-1",$currentTarget);
        echoPrint("        - Outputing to file ($currentTarget): (".$currentCommand->{lc("output")}.")\n");
        if (exists $currentCommand->{lc("append")})
        {
            echoPrint("          + Appending\n");
            if (open(OUTPUTTOFILE,">>$currentTarget")) { $openSuccess = 1; }
        }
        else 
        {
            if (open(OUTPUTTOFILE,">$currentTarget")) { $openSuccess = 1; }   
        }
        if ($openSuccess == 1)
        {
            if (open(OUTPUTFORMAT,$profiles->{lc($currentCommand->{lc("output")}.".output")}))
            {
                $outputFile = "";
                while (<OUTPUTFORMAT>)
                {
                    chomp;
                    $outputLine = $_;
                    $outputLine = processCondLine($outputLine,
                                                  $perRunOptionsHash,
                                                  $profiles);
                
                    $outputLine =~ s/\s*$//;
                    $outputFile .= "$outputLine\n";
                }
                print OUTPUTTOFILE encode($encoding,$outputFile);
                close(OUTPUTFORMAT);
            }
            else
            {
                print "        ! Couldn't open ".$currentCommand{lc("output")}.".output for read\n";     
            }
        }
        else
        {
            print "        ! Couldn't open file for write ($currentTarget)\n";                      
        }
        close OUTPUTTOFILE;
    }

##### Get and webpage useing LWP                
    sub getHTML
    {
        my ($currentTarget,$currentCommand,$perRunOptionsHash,$cachedHTML,$ua) = @_;
        my $url = URI->new(encode('UTF-8', $currentTarget));
        my $requestSuccess = 0;
        my $i = 0;
        my $zip = Archive::Zip->new();
    
        $currentCommand->{lc("get")} =~ s/\$//g;
        
        if (exists $currentCommand->{lc("isZip")})
        {
            
            if ($currentTarget =~ /([^|]*)\|\|([^|]*)/)
            {
                $zipFile = $1;
                $fileToRead = $2;
                echoPrint("      + Reading Zip File: $zipFile ($fileToRead)\n");
                $zip->read("$zipFile");
                $cachedHTML->{lc($currentCommand{lc("get")})} = $zip->contents( "$fileToRead" );
            }
            else
            {
                echoPrint("      + Failed to read Zip: $currentTarget\n");
            }           
        }
        elsif (!exists $cachedHTML->{lc("$currentTarget")})
        {   
            my $response = $ua->get($url);
            echoPrint("      + Requesting WebAddress: $url\n");
            for($i=0;$i<5;$i++)
            {
                echoPrint("        - Attempt #".($i+1));
                if ($response->is_success) 
                {
    
                    $requestSuccess = 1;
                    last;
                } 
                else
                {
                    sleep(5);
                    $response = $ua->get($url);
                }            
            }
            
            if ($response->is_success) 
            {
                my $content = $response->decoded_content;
                while($content =~ /&#([0-9]+);/) 
                { $content = $`.chr($1) .$'; }                       
                $cachedHTML->{lc($currentCommand{lc("get")})} = $content;
                $cachedHTML->{lc("$currentTarget")}           = $content;
                echoPrint(" Success: ".$response->status_line."\n");
            }
            else
            {
                echoPrint(" Failure: ".$response->status_line."\n");
            }  
            sleep(1);
            
            if ($perRunOptionsHash->{lc("saveHTML")})
            {
                open(WRITEHTML,">".$perRunOptionsHash->{lc("EXEPATH")}."\\".$currentCommand->{lc("get")}.".".getFile($perRunOptionsHash->{lc("inputFile")}).".html");
                print WRITEHTML $cachedHTML->{lc($currentCommand{lc("get")})};
                close(WRITEHTML);  
            }
        }
        else
        {
            $cachedHTML->{lc($currentCommand{lc("get")})} = $cachedHTML->{lc("$currentTarget")};
        }
    }

##### Read Profiles into Hash
    sub readProfiles
    {
        my ($profileFolder,$profiles) = @_;
        my @profileNames = ();
        my @profileFiles = scanDir($profileFolder,"profile|func|snip|output|scrape");
        
        foreach (@profileFiles)
        {
            if (/\.output$/)
            {
                $profiles->{lc(getFile($_).".output")} = $_;
            }
        }
        
        print "  + Reading Profiles\n";
        foreach $file (@profileFiles)
        {
            @commands = ();
            @targets = ();
            $numCommands = 0;
            if ($file =~ /\.(profile|func|snip|output|scrape)$/i)
            {
                open(PREFS,"$file");
                while (<PREFS>)
                {
                    chomp;
                    if ( $_ =~ /Profile[#0-9 ]*=(.*)/)
                    {   # If multiple profiles in one file
                        if (!($profileName eq ""))
                        {
                            $profiles->{$profileName}{"name"}         = trim($profileName);
                            $profiles->{$profileName}{"commands"}     = [@commands];
                            $profiles->{$profileName}{"targets"}     = [@targets];
                            $profiles->{$profileName}{"numCommands"}   = $numCommands;
                            push @profileNames, $profileName;  # Add to list
                        }
                        $profileName = lc($1); #Save the next profile name
                        $numCommands = 0;
                    }
                    
                    if($_ =~ /^\s*(Encode CLI|Target)/i)
                    {   # CLI
                        $line = $_;
                        $line =~ /=/;
                        $targets[$numCommands] = trim($');
        
                        # Encoder
                        $line = <PREFS>;
                        chomp($line);
                        $line =~ /=/;
                        $commands[$numCommands] = trim($');
        
                        $numCommands++;
                    }
                }
                
                if (!($profileName eq ""))
                {   # For the last or only profile in the file
                    $profiles->{$profileName}{"name"}         = $profileName;
                    $profiles->{$profileName}{"commands"}     = [@commands];
                    $profiles->{$profileName}{"targets"}     = [@targets];
                    $profiles->{$profileName}{"numCommands"}   = $numCommands;
                    push @profileNames, $profileName;  # Add to list
                }
                $profileName = "";  
            }
        }
        close(PREF);
        
        foreach $profileName (@profileNames)
        {
            print "   - Profile \"$profiles{$profileName}{name}\"\n";
            print "    + Number of Commands : $profiles{$profileName}{numCommands}\n";
            for ($j=0;$j<($profiles{$profileName}{"numCommands"});$j++)
            {   # targets
            print "      - Command #".($j+1)."        : ".$profiles{$profileName}{"targets"}[$j]."\n";
            if (!($profiles{$profileName}{"targets"}[$j] eq "")) { print "      - Encoder #".($j+1)."        : ".$profiles{$profileName}{"commands"}[$j]."\n"; }
            }
        }
    }

##### Use Command
    sub captureData
    {
        my ($currentTarget,$currentCommand,$perRunOptionsHash,$cachedHTML) = @_;
        
        my $splitter = (exists $currentCommand->{lc("split")} ? $currentCommand->{lc("split")} : "||");
        if ($splitter eq "\\n")
        {
            $splitter = "\n";
        }

        my $success = 0;
    
        if (exists $cachedHTML->{lc($currentCommand->{lc("use")})})
        {
            $text = $cachedHTML->{lc($currentCommand->{lc("use")})};
            @text = split(/(\n|\r)/,$text);
        }
        elsif (exists $perRunOptionsHash->{lc($currentCommand->{lc("use")})})
        {
            $text = $perRunOptionsHash->{lc($currentCommand->{lc("use")})};
            @text = split(/(\n|\r)/,$text);
        }
        elsif (-s $currentCommand->{lc("use")} && exists $currentCommand->{lc("readFile")})
        {
            open(READIN,$currentCommand->{lc("use")});
            @text = <READIN>;
            $text = "@text";
        }
        else
        {
            $text = $currentCommand->{lc("use")};
            @text = split(/(\n|\r)/,$text);
        }
        
        if (exists $currentCommand->{lc("flatten")}) { $text =~ s/(\n|\r)//g; }
    
        if ($text eq "") 
        { 
            echoPrint("      ! /use is empty, skipping\n");
            return; 
        }
    
        if (exists $currentCommand->{lc("isXML")})
        {
            echoPrint("      + Parseing XML: $currentTarget\n");
            my $xml = new XML::Simple;
            my $data = $xml->XMLin($text);
                                    
            # Parse Tree
            foreach (split(/\->/,$currentTarget)) { $data = $data->{$_}; }
            
            # If data exists, use it
            if (!(ref($data) || $data eq "") && 
                exists $currentCommand->{lc("variable")})
            {
                $perRunOptionsHash->{lc($currentCommand->{lc("variable")})} =  $data;
                echoPrint("        - \$\$".$currentCommand->{lc("variable")}."\$\$ = $data\n"); 
            }
            else
            {
                echoPrint("        - Failure!\n");
                if (exists $currentCommand->{lc("clearOnFailure")} && 
                    exists $currentCommand->{lc("variable")})
                {
                    delete $perRunOptionsHash->{lc($currentCommand->{lc("variable")})};
                    echoPrint("          + Clearing \$\$".$currentCommand->{lc("variable")}."\$\$\n"); 
                }
            }
        }
        else # /isRegex
        {
            if (!(exists $currentCommand->{lc("multiple")}))
            {
                if ($text =~ /$currentTarget/i)
                {
                    $before = $`;
                    $match  = $&;
                    $after  = $';
                    echoPrint("      + Success\n");
                    echoPrint("        - [$&]\n");
                    for ($i=0;$i<@regEXCapture;$i++)
                    {
                        $regExResult = ($i + 1);
                        if (!(exists $currentCommand->{lc("noOverWrite")}   && 
                              $perRunOptionsHash->{lc($regEXCapture[$i])})  &&
                            !($$regExResult eq ""))
                        {
                            $perRunOptionsHash->{lc($regEXCapture[$i])} = trim($$regExResult);
                            $success = 1;
                        }
                    }
                    if(!@regEXCapture) { $success = 1 };
                    
                    if (exists $currentCommand->{lc("variable")})
                    {
                        $outputLine = $currentCommand->{lc("format")};
                        while ($outputLine =~ /\$\$([^\$]*)\$\$/)
                        {
                            $outputLine = $`.$perRunOptionsHash->{lc($1)}.$';
                        }
                        if (!($outputLine eq ""))
                        {
                            $perRunOptionsHash->{lc($currentCommand->{lc("variable")})} .= $outputLine;
                        }
                    }                        
                }
            }
            else
            {
                $addedVariable = 0;
                for ($i=0;$i<@regEXCapture;$i++)
                {   # Clear out variables
                    $regExResult = ($i + 1);
                    $perRunOptionsHash->{lc($regEXCapture[$i])} = "";
                }
                while ($text =~ /$currentTarget/i)
                {
                    $before = $`;
                    $match = $&;
                    $after = $';
                    $text = $';
                    if (exists $currentCommand->{lc("format")})
                    {
                        for ($i=0;$i<@regEXCapture;$i++)
                        {
                            $regExResult = ($i + 1);
                            $replacements{lc($regEXCapture[$i])} = $$regExResult;
                            $perRunOptionsHash->{lc($regEXCapture[$i])} .= trim($$regExResult);
                            $perRunOptionsHash->{lc($regEXCapture[$i])} .= $splitter;
                        }
                        $outputLine = $currentCommand->{lc("format")};
                        while ($outputLine =~ /\$\$([^\$]*)\$\$/)
                        {
                            if (exists $replacements{lc($1)})
                            {
                                $outputLine = $`.$replacements{lc($1)}.$';
                            }
                            elsif (exists $perRunOptionsHash->{lc($1)})
                            {
                                $outputLine = $`.$perRunOptionsHash->{lc($1)}.$';
                            }    
                        }
    
                        if (exists $currentCommand->{lc("variable")})
                        {
                            $perRunOptionsHash->{lc($currentCommand->{lc("variable")})} .= $outputLine.$splitter;
                        }
                        else
                        {
                            $perRunOptionsHash->{lc($regEXCapture[0])} .= $outputLine.$splitter;
                        }    
                        $success++;             
                    }
                    else
                    {
                        for ($i=0;$i<@regEXCapture;$i++)
                        {
                            $regExResult = ($i + 1);
                            $perRunOptionsHash->{lc($regEXCapture[$i])} .= trim($$regExResult);
                            $perRunOptionsHash->{lc($regEXCapture[$i])} .= $splitter;
                        }
                        $success++;
                    }          
                }
            }
            
            if ($success)
            {
                echoPrint("      + Success ($success)\n");
                foreach $thing (("variable","removeMatch","captureBefore","captureAfter"))
                {
                    if (exists $currentCommand->{lc($thing)})
                    {
                        $currentCommand->{lc($thing)} =~ s/\$//g;
                        push @regEXCapture,$currentCommand->{lc($thing)};
                    }
                }
                
                if (exists $currentCommand->{lc("removeMatch")})
                {
                    $currentCommand->{lc("removeMatch")} =~ s/\$//g;
                    $perRunOptionsHash->{lc($currentCommand->{lc("removeMatch")})} = $before.$after;
                }
                
                if (exists $currentCommand->{lc("captureBefore")})
                {
                    $currentCommand->{lc("captureBefore")} =~ s/\$//g;
                    $perRunOptionsHash->{lc($currentCommand->{lc("captureBefore")})} = $before;
                }
                
                if (exists $currentCommand->{lc("captureAfter")})
                {
                    $currentCommand->{lc("captureAfter")} =~ s/\$//g;
                    $perRunOptionsHash->{lc($currentCommand->{lc("captureAfter")})} = $after;
                }
                              
                for ($i=0;$i<@regEXCapture;$i++)
                {
                    echoPrint("        - \$\$$regEXCapture[$i]\$\$ = (".$perRunOptionsHash->{lc($regEXCapture[$i])}.")\n");
                } 
            } 
    
            if ($success == 0)
            {
                echoPrint("      ! Failure\n");
                if (exists $currentCommand->{lc("clearOnFailure")})
                {
                    for ($i=0;$i<@regEXCapture;$i++)
                    {
                        echoPrint("        - Clearing \$\$$regEXCapture[$i]\$\$\n");
                        delete $perRunOptionsHash->{lc($regEXCapture[$i])};
                    }                    
                }
            }
        }
    }

##### Helper Functions
    sub getExt
    {   # G:\videos\filename(.avi)
        my ( $fileName ) = @_;
        my $rv = "";
        if ($fileName =~ m#(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#)
        {
            $rv = $3;
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
        my $rv = "";
        if ($fileName =~ m#(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#)
        {
            $rv = $` . $2;   
        }
        if (-d $fileName)
        {
            $rv = $fileName;
        }
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
    
        if (-d $fileName && $fileName =~ m#([^\\/]*)$#)
        {
                $rv = $&;
        }
    
        return $rv;
    }
    
    sub getFileWExt
    {   # G:\videos\(filename.avi)
        my ( $fileName ) = @_;
        my $rv = "";
        if ($fileName =~ m#([^\\/]*)$#)
        {
            $rv = $&;
        }
    
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

    sub trim
    {
       my $string = shift;
       $string =~ s/^\s+|\s+$//g;
       return $string;
    }
  
    sub reverseSlashes
    {
        my ($input) = @_;
        $input =~ s#\\#/#g;   
        return $input;
    }

    sub runCommand
    {
        my ( $command, $action ) = @_;
        print "$action: $command\n";
        `$command`;
    }
    
    sub forkCommand
    {
        my ($program,$command,$finishedFile) = @_;
        $programString =  "start /B /D \"".getPath($program)."\" ".getFileWExt($program)." $command";
        return ($programString); 
    }
    
    sub echoPrint
    {
        my ($toPrint,$level) = @_;
        my $shortPrint  = substr($toPrint, 0, 150);
        if ($shortPrint !~ /\n$/)
        {
            $shortPrint .= "...\n";    
        }
        print $toPrint;
        if ($level >= $verboseLevel)
        {
          print STDOUT $shortPrint;
        }
    }
    
    sub flatten
    {
        my ($text) = @_;
        $text =~ s/\n//;
        return $text;
    }

    sub forkCommand
    {
        my ($program,$command,$finishedFile) = @_;
        $programString =  "start /B /D \"".getPath($program)."\" ".getFileWExt($program)." $command";
        return ($programString); 
    }
    
    sub captureFPS
    {
        my ($logFile) = @_;
        my $total = 0;
        my $number = 0;
        my $average = 0;
        if (open(ENCODELOG,"$logFile"))
        {
            while(<ENCODELOG>)
            {
                chomp;
                $thing = $_;
                if($thing =~ /\r/)
                {
                    $thing =~ s/(\r|\n)/@@@/g;
                    @lines = split(/@@@/,$thing);
                    foreach $line (@lines)
                    {
                        if ($line =~ /([0-9]+.[0-9]+)\s?fps/)
                        {
                            if ($1 != 0)
                            {
                                $total += $1;
                                $number++;
                                $average = $total/$number;
                            }
                        }
                    }
                }
            }
        }
        close(ENCODELOG);
        return sprintf( "%.2f", $average );
    }

    sub deleteTempFiles
    {
        my ($deleteFiles) = @_;
        echoPrint("\n  + Deleting temp files (@{$deleteFiles})\n");
        foreach $file (@{$deleteFiles})
        {
            echoPrint("    - Deleting File: $file\n");
            if (-d $file && !($file eq "") && -e "$file\\delete.me")
            {
                $rmdirString = "rmdir /S /Q \"$file\"";
                echoPrint("      + Deleting Folder: $rmdirString\n");
                `$rmdirString`;
            }
            elsif (-e $file && !($file eq ""))
            {
                $delString = "del /Q \"$file\"";
                echoPrint("      + Deleting File: $delString\n");
                `$delString`;            
            }
        }  
        @{$deleteFiles} = ();  
    }
    

sub detectVideoProperties()
{
    my ($video,$baseSpace,$perRunOptionsHash,$binFiles) = @_;
    $videoInfoArray = \%{$perRunOptionsHash->{videoInfo}{lc($video)}};
    if (!exists $videoInfoHash->{lc("inputLine")})
    {
        return;
    }

    my (@topCrop, @bottomCrop, @leftCrop, @rightCrop, @aspectRatio, @cropConfidence);
    @topCrop = @bottomCrop = @leftCrop = @rightCrop = @aspectRatio = @cropConfidence = ();
    my ($highestCropConfidence, $percentConfidence, $totalSize, $backUpPlan,
        $telecineCount, $prevDuration, $curDuration, $numTelecineSamples) = 0;
    $highestCropConfidence = $percentConfidence = $totalSize = $backUpPlan = 0;
    $telecineCount = $prevDuration = $curDuration = $numTelecineSamples = $embeddedCCCount = 0;
    my $sizeClip = 0;
    my $sizePrevClip = -1;
    my $cropIndex = -1;
    my $cropMargin = 10;
    my $baseFileName = $perRunOptionsHash->{lc("scratchPath")}."\\".getFile($perRunOptionsHash->{lc("original")});
    my $numClips = 6;
    my $clipDuration = 10;
    my $autoCropCheckTime = ((($videoInfoArray->{lc("durationMin")} < 10)?$videoInfoArray->{lc("durationMin")}:30) * 10) / $numClips;

    my $xRes = $videoInfoArray->{lc("xRes")};
    my $yRes = $videoInfoArray->{lc("yRes")};
    my $aspectRatioValue = $xRes/$yRes;
    my $additionalCropX = int(10*$aspectRatioValue); # Additional Crop to compensate for overscan
    my $additionalCropY = 10; # Additional Crop to compensate for overscan

    my $encodeSettings = "-acodec copy -vcodec copy -scodec copy -y";
    if (!($videoInfoArray->{lc("videoCodec")} =~ /(mpeg2video)/))
    {   # For non-mpeg sources
        $encodeSettings = "-acodec mp2 -ac 2 -vcodec mpeg2video -y";
    }

    ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();

    $pullupEncodeSettings = "pullup,softskip -ovc lavc -lavcopts vcodec=mpeg4:mbd=2:turbo";
    if ($videoInfoArray->{lc("videoResolution")} =~ /x720/ && $videoInfoArray->{lc("videoContainer")} =~ /mpeg/)
    {   # For non-mpeg sources
        $pullupEncodeSettings = "tinterlace," . $pullupEncodeSettings;
    }
    
    echoPrint("    - Detecting Crop Settings:\n");
    if (open(PROPSFILE,getFullFile($perRunOptionsHash->{lc("original")}).".props"))
    {
        $line = <PROPSFILE>;
        $line =~ /([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)/;
        $videoInfoArray->{lc("embeddedCCCount")} = $1;
        $videoInfoArray->{lc("percentFilm")} = $2;
        $videoInfoArray->{lc("cropX")} = $3;
        $videoInfoArray->{lc("cropY")} = $4;
        $videoInfoArray->{lc("autoCropHandBrake")} = $5;
        $videoInfoArray->{lc("autoCropHandBrake")} = $6;
        $videoInfoArray->{lc("autoCropMencoder")} = $7;
        $videoInfoArray->{lc("cropConfidence")} = $8;
        close PROPSFILE;
    }
    else
    {
        for ($j = 1; $j < $numClips; $j++)
        {   # Get all clips upfront
            if ($j == ($numClips-1))
            {
                $ffmpegString =  "\"".$binFiles->{lc("ffmpeg.exe")}."\" -i \"".$perRunOptionsHash->{lc("original")}."\" $encodeSettings -ss ".($autoCropCheckTime * $j)." -t $clipDuration \"$baseFileName.clip_$j.mpg\" > \"$baseFileName.clip_$j.ffmpeg.log\" 2>&1";
            }
            else
            {
                $ffmpegString = forkCommand($binFiles->{lc("ffmpeg.exe")}," -i \"".$perRunOptionsHash->{lc("original")}."\" $encodeSettings -ss ".($autoCropCheckTime * $j)." -t $clipDuration \"$baseFileName.clip_$j.mpg\" > \"$baseFileName.clip_$j.ffmpeg.log\" 2>&1","");        
            }
            print "      + Getting clip: (".int($autoCropCheckTime * $j)." - ".int(($autoCropCheckTime * $j)+$clipDuration).") $ffmpegString\n";
            if (!(-s "$baseFileName.clip_$j.mpg"))
            {
                `$ffmpegString`;
            }
        }

        for ($j = 1; $j < $numClips; $j++)
        {               
            $comskipString = forkCommand($binFiles->{lc("comskip.exe")}," --ini=\"".getPath($binFiles->{lc("comskip.exe")})."comskip.ini\" \"$baseFileName.clip_$j.mpg\" > \"$baseFileName.clip_$j.comskip.log\" 2>&1","$baseFileName.clip_$j.comskip.finished");
            print "        - Running Comskip: $comskipString\n";
            if (!(-s "$baseFileName.clip_$j.csv"))
            {
                `$comskipString`;
            }
            
            $ccextratorString = forkCommand($binFiles->{lc("ccextractorwin.exe")}," -srt \"$baseFileName.clip_$j.mpg\" -o \"$baseFileName.clip_$j.srt\" > \"$baseFileName.clip_$j.ccextractor.log\" 2>&1","$baseFileName.clip_$j.ccextractor.finished");
            print "        - Running ccextrator: $ccextratorString\n";
            if (!(-s "$baseFileName.clip_$j.srt"))
            {
                `$ccextratorString`;
            }
            
    
            if ($j >= ($numClips-2) || 1)
            {
                $mencoderString =  "\"".$binFiles->{lc("mencoder.exe")}."\" \"$baseFileName.clip_$j.mpg\" -nosound -priority belownormal -v -vf $pullupEncodeSettings -o NUL > \"$baseFileName.clip_$j.pullup.log\" 2>&1";
            }
            else
            {
                $mencoderString = forkCommand($binFiles->{lc("mencoder.exe")}," \"$baseFileName.clip_$j.mpg\" -nosound -priority belownormal -v -vf $pullupEncodeSettings -o NUL > \"$baseFileName.clip_$j.pullup.log\" 2>&1","$baseFileName.clip_$j.pullup.finished");        
            }
            print "        - Getting pullup: $mencoderString\n";
            if (!(-s "$baseFileName.clip_$j.pullup.log"))
            {
                `$mencoderString`;
            }
        }

        #while(checkFinished(@checkForFinished) != 1)
        #{
        #    sleep 1;
        #}
        for ($j = 1; $j < $numClips; $j++)
        {  
            if (open( PULLUPINFO, "$baseFileName.clip_$j.pullup.log"))
            {
                $prevDuration = 0;
                while(<PULLUPINFO>)
                {
                    if ($_ =~ /duration: ([0-9]+)/)
                    {
                        $curDuration = $1;
                        if ($curDuration == 3 && $prevDuration == 2)
                        {
                            $telecineCount++;
                            $durationBetween = 0;
                        }
                        $prevDuration = $curDuration;
                        $numTelecineSamples++;
                    }
                }
                close(PULLUPINFO);
            }          
              
            if (open( CROPINFO, "$baseFileName.clip_$j.csv"))
            {
                while(<CROPINFO>)
                {
                    if ($_ =~ /[0-9\-]+[ ,]+[0-9\-]+[ ,]+[0-9\-]+[ ,]+[0-9\-]+[ ,]+[0-9\-]+[ ,]+[0-9\-]+[ ,]+([0-9\-]+)[ ,]+([0-9\-]+)[ ,]+([0-9\-]+)[ ,]+[0-9\-]+[ ,]+[0-9\-]+[ ,]+[0-9\-]+[ ,]+([0-9\-]+)[ ,]+([0-9\-]+)[ ,]+[0-9\-]+[ ,]+[0-9\-]+/)
                    {
                        push @topCrop,     $1;
                        push @bottomCrop,  $2;
                        push @aspectRatio, $3;
                        push @leftCrop,    $4;
                        push @rightCrop,   $5;
                    }
                }
                close(CROPINFO);
            }
            
            if (-s "$baseFileName.clip_$j.srt")
            {
                $embeddedCCCount =+ -s "$baseFileName.clip_$j.srt";
            }
            
            # We're done with video so we can delete it
            $delString = "del \"$baseFileName.clip_$j.mpg\" > NUL 2>&1";
            print "        - Deleting Temp Video: $delString\n";
            `$delString`;
        }
    
        $numTelecineSamples = int($numTelecineSamples/2);
       
        $originalTotalSize = @topCrop;
        if ($originalTotalSize > 0)
        {
            $totalSize = $originalTotalSize;
            for($i=0;$i<$totalSize;$i++)
            {
                $cropConfidence[$i] = 1;
                for($j=($i+1);$j<$totalSize;$j++)
                {
                    if (abs($topCrop[$i]-$topCrop[$j]) < $cropMargin &&
                        abs($bottomCrop[$i]-$bottomCrop[$j]) < $cropMargin &&
                        abs($leftCrop[$i]-$leftCrop[$j]) < $cropMargin &&
                        abs($rightCrop[$i]-$rightCrop[$j]) < $cropMargin)
                    {
                        $cropConfidence[$i]++;
                        splice(@topCrop,$j,1);
                        splice(@bottomCrop,$j,1);
                        splice(@leftCrop,$j,1);
                        splice(@rightCrop,$j,1);
                        $j--;
                        $totalSize = @topCrop;
                    } 
                    #print "$j\n";  
                    
                    if ($highestCropConfidence > (($totalSize-$j)+$cropConfidence[$i]) || 
                        $cropConfidence[$i] > ($originalTotalSize /2))
                    {
                        last;
                    }
                }
                #print "      ? autoCrop: $topCrop[$i]:$bottomCrop[$i]:$leftCrop[$i]:$rightCrop[$i] ($cropConfidence[$i] / $totalSize / $originalTotalSize) \n";
                if($cropConfidence[$i] > $highestCropConfidence)
                {
                    $cropIndex = $i;
                    $highestCropConfidence = $cropConfidence[$i];
                    print "      ? autoCrop: $topCrop[$cropIndex]:$bottomCrop[$cropIndex]:$leftCrop[$cropIndex]:$rightCrop[$cropIndex] ($highestCropConfidence / $originalTotalSize) \n";
                }
                
                if ($highestCropConfidence > $totalSize  || 
                    $highestCropConfidence > ($originalTotalSize/2))
                {
                    last;
                }
            }
            
            if ($totalSize != 0)
            {
                $percentConfidence = $highestCropConfidence / $totalSize;
            }
            
            # Only compensate for overscan if nessisary
            if ($rightCrop[$cropIndex]            < $additionalCropX) { $rightCrop[$cropIndex]  = $additionalCropX; }
            if (($xRes - $leftCrop[$cropIndex])   < $additionalCropX) { $leftCrop[$cropIndex]   = $xRes - $additionalCropX; }
            if ($topCrop[$cropIndex]              < $additionalCropY) { $topCrop[$cropIndex]    = $additionalCropY; }
            if (($yRes - $bottomCrop[$cropIndex]) < $additionalCropY) { $bottomCrop[$cropIndex] = $yRes - $additionalCropY; }    
            print "      ? Adjusted for Overscan: $topCrop[$cropIndex]:$bottomCrop[$cropIndex]:$leftCrop[$cropIndex]:$rightCrop[$cropIndex] ($additionalCropX x $additionalCropY)\n";
         
            my $cropX = abs($rightCrop[$cropIndex] - $leftCrop[$cropIndex]);
            my $cropY = abs($topCrop[$cropIndex] - $bottomCrop[$cropIndex]);
            print "      + Orignal Cropped Res: $cropX x $cropY (".($cropX/$cropY).")\n";   
            while ($cropX%16 != 0)
            {
                if($cropX%16 > 2)
                {
                    $rightCrop[$cropIndex]--;
                    $leftCrop[$cropIndex]++;
                    $cropX = abs($rightCrop[$cropIndex] - $leftCrop[$cropIndex]);
                }
                else
                {
                    $cropX--;
                }    
            }
            
            while ($cropY%16 != 0)
            {
                if($cropY > 2)
                {
                    $bottomCrop[$cropIndex]--;
                    $topCrop[$cropIndex]++;
                    $cropY = abs($bottomCrop[$cropIndex] - $topCrop[$cropIndex]);
                }
                else
                {
                    $cropY--;
                }  
            }
            
            
            $videoInfoArray->{lc("autoCropHandBrake")} = "$topCrop[$cropIndex]:".($yRes - ($cropY+$topCrop[$cropIndex])).":$leftCrop[$cropIndex]:".($xRes - ($cropX+$leftCrop[$cropIndex]));  
            $videoInfoArray->{lc("autoCropMencoder")} =  "$cropX:$cropY:$leftCrop[$cropIndex]:$topCrop[$cropIndex]";
            $videoInfoArray->{lc("cropConfidence")} = $percentConfidence;
    
            if (abs($videoInfoArray->{lc("ffmpegARValue")} - $aspectRatioValue) > .05)
            {   
                $cropX = int($cropX * (($videoInfoArray->{lc("ffmpegARValue")} * $yRes)/$xRes));
                while ($cropX%16 != 0)
                {
                    $cropX--;
                }
                echoPrint("      + Scaled for res for ".$videoInfoArray->{lc("ffmpegAR")}.": $cropX x $cropY (".($cropX/$cropY).") \n");    
            }
            
            $videoInfoArray->{lc("cropX")} = $cropX;
            $videoInfoArray->{lc("cropY")} = $cropY;        

        }
        if ($videoDVDMode == 0)
        {   # Only get percentTelecine/EmbeddedCC if compressing video
            if ($numTelecineSamples != 0)
            {
                $videoInfoArray->{lc("percentFilm")} = int(($telecineCount / $numTelecineSamples) * 100);
            }
            $videoInfoArray->{lc("embeddedCCCount")} = $embeddedCCCount;
        }
        
        if (exists $perRunOptionsHash->{lc("saveVideoProps")} && !(-s getFullFile($videoInfoArray->{lc("fullPath")}).".props"))
        {
            open(PROPSFILE,">".getFullFile($videoInfoArray->{lc("fullPath")}).".props");
            print PROPSFILE $videoInfoArray->{lc("embeddedCCCount")}.",".$videoInfoArray->{lc("percentFilm")}.",".$videoInfoArray->{lc("cropX")}.",".$videoInfoArray->{lc("cropY")}.",".$videoInfoArray->{lc("autoCropHandBrake")}.",".$videoInfoArray->{lc("autoCropHandBrake")}.",".$videoInfoArray->{lc("autoCropMencoder")}.",".$videoInfoArray->{lc("cropConfidence")};
            close PROPSFILE;
        }
    }
    echoPrint("        - Cropped Res Divisable by 16: ".$videoInfoArray->{lc("cropX")}." x ".$videoInfoArray->{lc("cropY")}." \n");   
    print "      + handbrake: " . $videoInfoArray->{lc("autoCropHandBrake")} . "\n";
    print "      + mencoder : " . $videoInfoArray->{lc("autoCropMencoder")} . "\n"; 
    echoPrint("      + telecine : " . $videoInfoArray->{lc("percentFilm")} . "% ($telecineCount / $numTelecineSamples)\n");
    echoPrint("      + embeddedCC : " . $videoInfoArray->{lc("embeddedCCCount")} . "\n");

    # Get Finish Time
    ( $finishSecond, $finishMinute, $finishHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();

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
    $transcodeTime = $durHour . ":" . $durMin . ":" . $durSec;
    echoPrint("      + Analyzing Duration: $transcodeTime\n");
}



