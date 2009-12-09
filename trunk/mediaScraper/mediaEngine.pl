##    mediaEngine.pl - An open ended executing framework
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
    use IMDB::Film;
    use Date::Calc qw(:all);
    #use Win32::Process;
    #use Win32;

    # Get the directory the script is being called from
    $executable = $0;
    $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;;
    $executablePath = $`;

    # Code version
    $codeVersion = "mediaEngine v2.0 (SNIP:BUILT)";

    $usage  = "$codeVersion\n\n";
    $usage .= "Usage: mediaEngine.exe should not be called directly.\n";
    $usage .= "       Unless you know what you are doing please use\n";
    $usage .= "       mediaShrink.exe instead.\n";
    
    # Move arguments into user array so we can modify it
    my @parameters = @ARGV;
    if (@parameters == 0)
    {
        print "ERROR: No Parameters\n\n";
        print $usage;
        print "Exiting in 5 seconds...\n";
        sleep(5);
        exit 1;
    }

    if ($parameters[0] eq "/help"  ||
        $parameters[0] eq "-help"  ||
        $parameters[0] eq "--help" ||
        $parameters[0] eq "--usage" ||
        $parameters[0] eq "-usage"  ||
        $parameters[0] eq "/usage"  ||
        $parameters[0] eq "/?")
    {
        print $usage;
        print "Exiting in 5 seconds...\n";
        sleep(5);
        exit 1;
    }
    
##### Let's get this show on the road
    echoPrint(" Welcome to $codeVersion\n");
    echoPrint(" Staring Proccesing at $startTime $startDate\n\n");
    echoPrint("  + Executable   : $executable\n");
    echoPrint("  + EXE path     : $executablePath\n");
    
    # Start at -1, elevate to 0 if nessisary
    $verboseLevel = -1; 
    
    $errorLevel = 0;

    # Create log file
    %fileHandles = ();
    
    my $zip = Archive::Zip->new();

##### Initilizing Variables  
    @emptyArray = ();
    %emptyHash  = ();

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
    
    # Initilize options data structures
    my %optionsHash;
    my @inputFiles;
    
    # Setting cli options
    foreach (@parameters)
    {
        $parametersString .= "\"$_\" ";
    }
    
    $parametersString = decode('ISO-8859-1' , $parametersString);
    
    setOptions($parametersString,\@emptyArry,\%optionsHash,\@inputFiles,\%emptyHash,"  ");
    
    my %passwords = ();
    
    if (!exists $optionsHash{lc("silent")})
    {
        $verboseLevel = 0;
        print STDOUT $ourStorySoFar;   
    }
    
    if (exists $optionsHash{lc("batch")})
    {
        $batchMode = 1;
    }

   #### extra log file
   if (exists $optionsHash{lc("altLogFile")})
   {
        open($hPerVideoLog,">".$optionsHash{lc("altLogFile")});
        print $hPerVideoLog $ourStorySoFar;
        $fileHandles{$optionsHash{lc("altLogFile")}} = $hPerVideoLog;
    }

##### Initilize Profiles
    echoPrint("\n------------------Profiles--------------------\n",2);
    echoPrint("  + Looking for profiles file...\n",2);
    unless(-e "$executablePath\\mediaEngineProfiles")
    {
        echoPrint("! Failed!  Can't find profiles folder\n",2);
        echoPrint("Exiting in 5 seconds...\n");
        sleep(5);
        exit 1;
    }
    
    $optionsHash{lc("profileFolder")} = "$executablePath\\mediaEngineProfiles";
    $optionsHash{lc("binFolder")}     = "$executablePath\\mediaEngineBins";
    $optionsHash{lc("path")}          = $executablePath;
    $optionsHash{lc("theTVDBapiKey")} = $theTVDBapiKey;
    $optionsHash{lc("quote")}         = "\"";
    $optionsHash{lc("WORKDIR")}        = $executablePath;
    $optionsHash{lc("EXEPATH")}        = $executablePath;
         
    echoPrint("   - Found = ".$optionsHash{lc("profileFolder")}."\n",2);
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
    $optionsHash{lc("mediaEngineBins")} = \%mediaEngineBins;
    
##### Seperating inputFiles into individual runs
    echoPrint("  + Seraching for input files (".$optionsHash{lc("findFileRegEx")}.")\n");
    if (@inputFiles)
    {
        for ($i=0;$i<@inputFiles;$i++)
        {
            if (-d $inputFiles[$i] && $inputFiles[$i] =~ /VIDEO_TS$/i)
            {
                @temp = (@temp,getPath($inputFiles[$i]));
            }
            elsif (-d $inputFiles[$i])
            {   # if its a directory
                @temp = (@temp,scanDir($inputFiles[$i],$optionsHash{lc("findFileRegEx")}));
            }
            elsif ($inputFiles[$i] =~ /($optionsHash{lc("findFileRegEx")})$/)
            {
                @temp = (@temp,$inputFiles[$i]);
            }
        }
        
        foreach $file (@temp)
        {
            echoPrint("    - Found File: ($file)\n");
            if (exists $optionsHash{lc("mediaShrink")} &&
                $file =~ /VIDEO_TS$/i)
            {
                @perRunOptions = (@perRunOptions,dvdScanForTitles($file,"    ",\%optionsHash));
            }
            else
            {
                @perRunOptions = (@perRunOptions,"/inputFile \"$file\"".(exists $optionsHash{lc("profile")} ? "" : " /profile ".$optionsHash{lc("defaultProfile")}));
            }
        }
    }
    else
    {   # If there's no input file leave blank
        $perRunOptions[0] = "";
    }

##### Run through files
    foreach $perRunOptions (@perRunOptions)
    {
        # Get Finish Time
        my ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();

        echoPrint("------------ Processing ----------------\n");
        echoPrint("  + Adding per run options: ($perRunOptions)(@perRunOptions)\n");
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
        setOptions($perRunOptions  ,"",\%perRunOptionsHash,\@inputFiles,\%emptyHash,"    ");               
        
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
        
        if ($mainLogFile eq "" && exists $perRunOptionsHash{lc("inputFile")})
        {
            $mainLogFile  = ($perRunOptionsHash{lc("inputFile")} =~ /VIDEO_TS/i ? getPath($perRunOptionsHash{lc("inputFile")}) : getFullFile($perRunOptionsHash{lc("inputFile")}));
            $mainLogFile .= ".".$perRunOptionsHash{lc("profile")}.".(".(scalar @perRunOptions).").log";
            if (!open($mainLog, ">".encode('ISO-8859-1',$mainLogFile) ))
            {
                echoPrint("  ! Can't open create log file");
                echoPrint("Exiting in 5 seconds...\n");
                sleep(5);
                exit 1;
            }
            print $mainLog $ourStorySoFar;
            select($mainLog);
            $fileHandles{$mainLogFile} = $mainLog;
        }
        elsif ($mainLogFile eq "")
        {
            $mainLogFile = "$executablePath\\mediaEngine.log";
            echoPrint("  ! No input file found\n");
            echoPrint("    - Making Log File: $mainLogFile\n");
            if (!open($mainLog, ">".encode('ISO-8859-1',$mainLogFile) ))
            {
                echoPrint("  ! Can't open create log file");
                echoPrint("Exiting in 5 seconds...\n");
                sleep(5);
                exit 1;
            }
            print $mainLog $ourStorySoFar;
            select($mainLog);
            $fileHandles{$mainLogFile} = $mainLog;         
        }
        
     ##### Checking for profile       
        echoPrint("  + Looking for profile: ".$perRunOptionsHash{lc("profile")}."\n");
        unless(exists  $profiles{lc($perRunOptionsHash{lc("profile")})})
        {   # Check for profile in Hash
            $reason = "Couldn't find encode profile: ".$perRunOptionsHash{lc("profile")};
            echoPrint($reason);
            echoPrint("Exiting in 5 seconds...\n");
            sleep(5);
            exit 1;
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
        #echoPrint("      + Number of Commands : ".$perRunOptionsHash{lc("numCommands")}." \n",2);
        for ($j=0;$j<$perRunOptionsHash{lc("numCommands")};$j++)
        {   # targets
        #echoPrint("      + Target  #$j        : ".$perRunOptionsHash{lc("usingTargets")}[$j]."\n",2);
        #echoPrint("      + Command #$j        : ".$perRunOptionsHash{lc("usingCommands")}[$j]."\n",2);
        }
   
        # Get start time
        ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();
    
        $perRunOptionsHash{lc("WORKDIR")}        = $executablePath;
        $perRunOptionsHash{lc("EXEPATH")}        = $executablePath;
        
        if (exists $perRunOptionsHash{lc("inputFile")})
        {
            $scratchName = $perRunOptionsHash{lc("inputFile")};
        }
        else
        {
            $scratchName = $mainLogFile;
        }
        
        $perRunOptionsHash{lc("scratchPath")}     = getFullFile($scratchName).".workFolder";
        if (exists $perRunOptionsHash{lc("centralWorkFolder")})
        {
            $perRunOptionsHash{lc("scratchPath")}     = $perRunOptionsHash{lc("centralWorkFolder")}."\\".getFile($scratchName).".workFolder";
        }
        
        if (!(-d $perRunOptionsHash{lc("scratchPath")}))
        {
            $mkdirString = encode('ISO-8859-1',"mkdir \"".$perRunOptionsHash{lc("scratchPath")}."");
            echoPrint("  + Making Work Directory: ($mkdirString)\n",2);
            `$mkdirString`;
        }
        $deleteMeFile = $perRunOptionsHash{lc("scratchPath")}."\\delete.me";
        echoPrint("    - Making delete.me file: ($deleteMeFile)\n",2);
        open(DELETEME,">$deleteMeFile");
        print DELETEME "Delete me to keep files from being deleted for debugging\n";
        close(DELETEME);

        $perRunOptionsHash{lc("scratchName")}     = getFile($scratchName).".scratch";
        $perRunOptionsHash{lc("inputMain")}       = $scratchName;
        $perRunOptionsHash{lc("original")}        = $scratchName;
        $perRunOptionsHash{lc("passLogfile")}     = $perRunOptionsHash{lc("scratchPath")}."\\passLogFile.log";
        
        # Adding scratch folder to delete list
        @deleteFiles = (@deleteFiles,$perRunOptionsHash{lc("scratchPath")});
        echoPrint("    - Adding temp dir to delete list(@deleteFiles)\n",2);

    
        echoPrint("  + Using Options\n",2);
        foreach $key (sort(keys %perRunOptionsHash))
        {
            echoPrint("     - $key($perRunOptionsHash{$key})\n",2);        
        }
        $encodeCLI = 0;
        
        if (exists $perRunOptionsHash{lc("inputFile")} && exists $perRunOptionsHash{lc("mediashrink")})
        {   # Getting Video Info
            if ($perRunOptionsHash{lc("inputFile")} =~ /VIDEO_TS$/i)
            {
                $perRunOptionsHash{lc("isDVD")} = "";
                # Not Nessisary for Handbrake 9.4
                #detectDVDTitleProperties($perRunOptionsHash{lc("inputFile")},"  ",\%perRunOptionsHash);
                #if (!exists $perRunOptionsHash{videoInfo}{lc($perRunOptionsHash{lc("inputFile")})}{lc("embeddedCCCount")})
                #{
                #    echoPrint("  ! Unable to detect DVD info, skipping to next video\n");
                #    next;
                #}
            }
            else
            {
                getVideoInfo($perRunOptionsHash{lc("inputFile")},"  ",\%perRunOptionsHash);
                if ($perRunOptionsHash{lc("profile")} =~ /encode/i)
                {
                    if (exists $perRunOptionsHash{videoInfo}{lc($perRunOptionsHash{lc("inputFile")})}{lc("inputLine")})
                    {
                        detectVideoProperties($perRunOptionsHash{lc("inputFile")},"  ",\%perRunOptionsHash);
                    }
                    else
                    {
                        $errorFileName = getFullFile($perRunOptionsHash{lc("inputFile")}).".err";
                        echoPrint("  ! Unable to detect video info, skipping to next video\n");
                        $errorLevel++;                    
                        next;
                    }
                }
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
            #    echoPrint("      + ($n) $encoder\n",2);
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
                    echoPrint("        - Adding to command parameter hash \n",2);
                    $currentCommand[0] =~ m#/([a-zA-Z0-9_]+)#i;
                    $key = $1;
                    echoPrint("          + Key: $key\n",2);
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
                        echoPrint("          + Value: $currentCommand{lc($key)}\n",2);
                        shift(@currentCommand);    # Remove next parameter also
                    }
                    shift(@currentCommand);      
                }
                else
                {
                  echoPrint("        ! couldn't understand ($currentCommand[0]), throwing it away\n",2);
                  shift(@currentCommand);  
                }
            }
            
            $snipsCurrentTarget = $currentTarget;
            while($currentTarget =~ /%%SNIP:([^%]*)%%/i)
            {
                $snippitName = $1;
                $snipToReplace = $&;
                $currentTarget =~ s#\Q$snipToReplace\E#$profiles{lc($snippitName)}{"targets"}[0]#g;
                echoPrint("      + Replacing snippit $snippitName : $currentTarget\n",2);
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
                # Add use/password to credientials
                if (exists $currentCommand{lc("password")} && 
                    exists $currentCommand{lc("user")} &&
                    exists $currentCommand{lc("get")})
                {
                    addCredentials($currentTarget,\%currentCommand,\%perRunOptionsHash,$ua);  
                    
                }
                
                if (exists $currentCommand{lc("flushRegExVars")})
                {
                    echoPrint("      + Flushing Variables: (".scalar(keys %{$perRunOptionsHash{lc("varsToFlush")}}).")\n",2); 
                    foreach (keys %{$perRunOptionsHash{lc("varsToFlush")}})
                    {
                        echoPrint("        - $_\n",2);
                        delete $perRunOptionsHash{lc($_)};
                    }
                    delete $perRunOptionsHash{lc("varsToFlush")};
                }
                
                
                if (exists $currentCommand{lc("die")})
                {   # Die, for debugging
                    echoPrint("      ! Exiting due to profile /die\n",2); 
                    echoPrint("Exiting in 5 seconds...\n");
                    sleep(5);      
                    exit 1;
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
                    setOptions($currentTarget  ,""          ,\%perRunOptionsHash,\@inputFiles,\%currentCommand,"        ");           
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
                    captureData($currentTarget,\%currentCommand,\%perRunOptionsHash,\%cachedHTML,\%profiles);
                }
            }
            else
            {
                echoPrint("      + Command Empty, Skipping: \"$currentTarget\"\n");
                foreach $key (sort(keys %perRunOptionsHash))
                {   # Convert Output files to Full input files
                    if ($key =~ /outputFile(.+)/i)
                    {
                        echoPrint("    - Deleting $key\n",2);
                        delete $perRunOptionsHash{$key};
                    }
                }
                next;
            }
            
            foreach $key (sort(keys %perRunOptionsHash))
            {   # Convert Output files to Full input files
                if ($key =~ /outputFile(.+)/i)
                {
                    $newKey = "input$1";
                    $reverse = reverseSlashes($perRunOptionsHash{lc($key)});
                    $forward = forwardSlashes($perRunOptionsHash{lc($key)});
                    if (forwardSlashes($currentTarget) =~ /\Q$forward\E\.[a-zA-Z0-9]{2,}/)
                    {
                        $newOutputFile = $&;
                        $perRunOptionsHash{lc($newKey)} = $newOutputFile;
                    }
                    echoPrint("  + $key -> $newKey ($newOutputFile)($reverse)($forward)($currentTarget)\n",2);
                    getVideoInfo($perRunOptionsHash{lc($newKey)},"        ",\%perRunOptionsHash);
                    delete $perRunOptionsHash{$key};
                }
            }
            
            if (exists $perRunOptionsHash{lc("wereDoneHere")})
            {    
                last;
            }
            
            foreach $key (keys %perRunOptionsHash)
            {   # Attempt to scrub out passwords from logfiles
                if ($key =~ /password/i && $perRunOptionsHash{$key} =~ /[a-z0-9]+/ && 
                    !exists $passwords{$perRunOptionsHash{$key}})
                {
                    $passwords{$perRunOptionsHash{$key}} = ""; 
                    # Lets try and clean out all of the passwords
                    echoPrint("\n  + Found Password: $perRunOptionsHash{$key}\n");
                    echoPrint("    - Scrubbing Password: $_\n");   
                                
                    foreach $fileHandleKeys (keys %fileHandles)
                    {   # Close all file handles
                        close $fileHandles{$fileHandleKeys};
                    }
                    
                    $ourStorySoFar =~ s/$perRunOptionsHash{$key}/*******/g; 
                    foreach $logFile (keys %fileHandles)
                    {
                        open($fileHandles{$fileHandleKeys},">$logFile");
                        print {$fileHandles{$fileHandleKeys}} $ourStorySoFar;
                        $printLogFiles .= getFile($logFile).".log, ";
                    }
                    echoPrint("\n    - Rewriting Logfiles: $printLogFiles\n");
                    $printLogFiles = "";
                }
            }
            
        }
                
        if (!exists $perRunOptionsHash{lc("saveAll")})
        {
            deleteTempFiles(\@deleteFiles);
        }
        
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
        $transcodeTime = $durHour . ":" . $durMin . ":" . $durSec;
        if (exists $perRunOptionsHash{lc("mediaShrink")})
        {
            my $originalSize = $perRunOptionsHash{videoInfo}{lc($perRunOptionsHash{lc("inputFile")})}{lc("filesize")}  / 1024;
            my $finalSize    = $perRunOptionsHash{videoInfo}{lc($perRunOptionsHash{lc($newKey)})}{lc("filesize")} / 1024;
            echoPrint("\n");
            echoPrint(        "  + Total Time : $transcodeTime\n");
            if ($finalSize != 0)
            {
            echoPrint(sprintf("  + Shrinkage  :%3d\% (%.1f MB / %.1f MB)\n",(100*($finalSize/$originalSize),$finalSize,$originalSize)));
            }       
        }

        
    }
    
    foreach $fileHandleKeys (keys %fileHandles)
    {   # Close all file handles
        @logFileToDelete = (@logFileToDelete,$fileHandleKeys);
        close $fileHandles{$fileHandleKeys};
    }
    
    if (exists $optionsHash{lc("saveZip")})
    {
        my $string_member = $zip->addString( $ourStorySoFar, 'mediaEngine.log' );
        $string_member->desiredCompressionLevel(9);
        $zip->writeToFileNamed(getFullFile($mainLogFile).".mediaEngineLog.zip");
    }
    
    if (!(exists $optionsHash{lc("saveLog")} || exists $optionsHash{lc("saveAll")}))
    {
        deleteTempFiles(\@logFileToDelete);
    }
    print "Exiting in 5 seconds...\n";
    sleep(5);    
    exit $errorLevel;
    
    
######################################################
###
###           End of Main Program
    
##### Get Video Info
    sub getVideoInfo
    {
        my ($video,$baseSpace,$perRunOptionsHash) = @_;
        my $videoInfoHash = \%{$perRunOptionsHash->{videoInfo}{lc($video)}};
        my $binFiles      = \%{$perRunOptionsHash->{lc("mediaEngineBins")}};
        my $ffmpegString  = encode('UTF-8',"\"".$binFiles->{lc("ffmpeg.exe")}."\" -dumpmetadata -v 2 -i \"$video\" 2>&1");
        my $ffmpegOutput = `$ffmpegString`;
        $ffmpegOutput =~ s/\r//g ;   
        my @ffmpegOutput = split(/\n/,$ffmpegOutput);   
        
        $videoInfoHash->{lc("fileSize")} = (-s $video)/1024;
        
        echoPrint("$baseSpace- Getting Video Info: ($video)(".$videoInfoHash->{lc("fileSize")}.")\n");        
        echoPrint(padLines("$baseSpace  - ",@ffmpegOutput),100);

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
                echoPrint("$baseSpace  - Input Line:          $_\n",2);
                echoPrint("$baseSpace    + videoContainer = ".$videoInfoHash->{lc("videoContainer")}."\n",2);
            }
    
            if ( $_ =~ /Video:/ )
            {
                $videoInfoHash->{lc("videoInfo")} = $_;
                echoPrint("$baseSpace  - Video Info Line: ".$videoInfoHash->{lc("videoInfo")}."\n",2);
    
                # Get Resolution
                if ( $videoInfoHash->{lc("videoInfo")} =~ /AR: (([0-9]{1,3}):([0-9]{1,3})),/)
                {   # Use directly reported AR
                    $videoInfoHash->{lc("ffmpegAR")} = $1;
                    if ($3 != 0)
                    {
                        $videoInfoHash->{lc("ffmpegARValue")} = $2/$3;
                    }
                    $videoInfoHash->{lc("dvdAR")} = ( $videoInfoHash->{lc("ffmpegARValue")} < 1.55 ) ? "4:3" : "16:9";
                    echoPrint("$baseSpace    + ffmpeg Reported Aspect Ratio (ffmpegAR)   = ".$videoInfoHash->{lc("ffmpegAR")}."\n",2);
                    echoPrint("$baseSpace      - Estimated DVD aspect ratio {dvdAR)      = ".$videoInfoHash->{lc("dvdAR")}."\n",2);
                }
                elsif ( $videoInfoHash->{lc("videoInfo")} =~ /(\d{3,4})x(\d{3,4})/)
                {   # Use the resolution to guess the AR
                    if ($2 != 0)
                    {
                        $videoInfoHash->{lc("ffmpegAR")} = $1 / $2;
                    }
                    $videoInfoHash->{lc("ffmpegARValue")} = $videoInfoHash->{lc("ffmpegAR")};
                    $videoInfoHash->{lc("dvdAR")} = ( $videoInfoHash->{lc("ffmpegARValue")} < 1.55 ) ? "4:3" : "16:9";
                    echoPrint("$baseSpace    + ffmpeg Reported Aspect Ratio (ffmpegAR)   = ".$videoInfoHash->{lc("ffmpegAR")}."\n",2);
                    echoPrint("$baseSpace      - Estimated DVD aspect ratio {dvdAR)      = ".$videoInfoHash->{lc("dvdAR")}."\n",2);
                }
                
                if ( $videoInfoHash->{lc("videoInfo")} =~ /(\d{3,4})x(\d{3,4})/)
                {   
                    $videoInfoHash->{lc("videoResolution")} = $&;
                    $videoInfoHash->{lc("xRes")} = $1;
                    $videoInfoHash->{lc("yRes")} = $2;
                    echoPrint("$baseSpace    + videoResolution   = ".$videoInfoHash->{lc("videoResolution")}."\n",2);
                }
                             
                if ( $videoInfoHash->{lc("videoInfo")} =~ /(\d+) kb/)
                {   # Get Bitrate
                    $videoInfoHash->{lc("videoBitrate")} = $1;
                    echoPrint("$baseSpace    + videoBitrate      = ".$videoInfoHash->{lc("videoBitrate")}."\n",2);
                }
                
                if ( $videoInfoHash->{lc("videoInfo")} =~ /\[0x([a-z0-9]{3})\]/)
                {   # Video PID
                    $videoInfoHash->{lc("videoPID")} = $1;
                    echoPrint("$baseSpace    + videoPID     = ".$videoInfoHash->{lc("videoPID")}."\n",2);
                }
                # Get Framerate
                if ( $videoInfoHash->{lc("videoInfo")} =~ /, ([0-9\.]*) fps/)
                {
                    $videoInfoHash->{lc("frameRate")} = $1;
                    echoPrint("$baseSpace    + frameRate   = ".$videoInfoHash->{lc("frameRate")}."\n",2);
                }
    
                # Get video codec
                if ( $videoInfoHash->{lc("videoInfo")} =~ /Video: ([a-zA-Z0-9]*),/)
                {
                    $videoInfoHash->{lc("videoCodec")} = $1;
                    echoPrint("$baseSpace    + videoCodec      = ".$videoInfoHash->{lc("videoCodec")}."\n",2);
                }
    
                if ( $videoInfoHash->{lc("videoInfo")} =~ /(interlaced|progressive)/)
                {
                    $videoInfoHash->{lc("$1")} = 1;
                    echoPrint("$baseSpace    + ffmpeg reports $1\n",2);
                }
            }
            elsif ( $_ =~ /Audio: ([a-zA-Z0-9]+)/ )
            {
                $videoInfoHash->{lc("audioInfo")} = $_; 
                echoPrint("$baseSpace  - Audio Info Line: ".$videoInfoHash->{lc("audioInfo")}."\n",2);
    
                if ($videoInfoHash->{lc("audioInfo")} =~ /Audio: ([a-zA-Z0-9]+)/)
                {   # Get Audio Format
                    $videoInfoHash->{lc("audioCodec")} = $1;
                    echoPrint("$baseSpace    + audioCodec     = ".$videoInfoHash->{lc("audioCodec")}."\n",2);
                }
      
                if ($videoInfoHash->{lc("audioInfo")} =~ /(\d+) Hz/)
                {   # Audio Sample Rate
                    $videoInfoHash->{lc("audioSampleRate")} = $1;
                    echoPrint("$baseSpace    + audioSampleRate = ".$videoInfoHash->{lc("audioSampleRate")}."\n",2);
                }
                
                if ($videoInfoHash->{lc("audioInfo")} =~ /(\d+) kb.s/)
                {   # Audio Bitrate
                    $videoInfoHash->{lc("audioBitRate")} = $1;
                    echoPrint("$baseSpace    + audioBitRate    = ".$videoInfoHash->{lc("audioBitRate")}."\n",2);
                }
                
                if ($videoInfoHash->{lc("audioInfo")} =~ /\[0x([a-z0-9]{3})\]/)
                {   # Audio PID
                    $videoInfoHash->{lc("audioPID")} = $1;
                    echoPrint("$baseSpace    + audioPID    = ".$videoInfoHash->{lc("audioPID")}."\n",2);
                }
                
                if ($videoInfoHash->{lc("audioInfo")} =~ /5.1/)
                {   # Get Audio Format
                    $videoInfoHash->{lc("audioChannels")} = 6; 
                    echoPrint("$baseSpace    + audioChannels  = ".$videoInfoHash->{lc("audioChannels")}."\n",2);
                }           
                elsif ($videoInfoHash->{lc("audioInfo")} =~ /stereo/)
                {
                    $videoInfoHash->{lc("audioChannels")} = 2;
                    echoPrint("$baseSpace    + audioChannels  = ".$videoInfoHash->{lc("audioChannels")}."\n",2);
                }              
            }
            elsif ( $_ =~ /Duration: ([0-9][0-9]):([0-9][0-9]):([0-9][0-9])/ )
            {
                echoPrint("$baseSpace  - Duration Line:     $_\n",2);
                $videoInfoHash->{lc("durationMin")} = int($1 * 60 + $2 + $3 / 60);
                $videoInfoHash->{lc("durationSec")} = int($1 * 3600 + $2 * 60 + $3);
                echoPrint("$baseSpace    + totalMin = ".$videoInfoHash->{lc("durationSec")}."\n",2);
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
            echoPrint("      + Processing conditional: $shortestCond\n",2);
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
                        echoPrint("        - Conditional List: $shortestBool\n",2);
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
                        echoPrint("        = Overall: True, using: $text\n",2);
                        $replaceString = $text;
                        last;
                    }
                }
                else
                {   # No conditionals, just the else
                    echoPrint("        = Overall: False, using else: $cond\n",2);
                    $replaceString = $cond;
                    last;
                }
            }
            if ($replaceString eq "")
            {
                echoPrint("        = Overall: False, leaving blank!\n",2);
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
              
        echoPrint("          + Checking: $check\n",2);
        if ($check =~ /^!/)
        {
            $negate = 1;
            $check =~ s/!//g;  #Remove the !
        }
        
        if($check eq "1" || $check eq "0")
        {
            echoPrint("            - Previously Resolved Condition: $check\n",2);  
            $condTrue = $condTrue = checkProfileCond($check, $negate, $text);;
        }
        elsif ($check =~ /EXT:([a-zA-Z0-9]+)/i)
        {
            $extToCheck = $1;
            echoPrint("            - Does file exist next to inputFile with a (.$extToCheck) extention? (".getFullFile("$perRunOptionsHash->{lc(inputFile)}").".".$extToCheck.")\n",2);
            $condTrue = checkProfileCond((((-e getFullFile("$perRunOptionsHash->{lc(inputFile)}").".".$extToCheck ||
                                            -e "$perRunOptionsHash->{lc(inputFile)}.".".$extToCheck"))?1:0), $negate, $text); 
            $perRunOptionsHash->{lc("check")} = $extToCheck;
        }
        elsif ($check =~ /EXISTS:(.*)/i)
        {
            $checkFile = encode('ISO-8859-1' , $1);
            echoPrint("            - Does file ($checkFile) exist?\n",2);
            $condTrue = checkProfileCond((((-e "$checkFile" || 
                                            -e $perRunOptionsHash->{lc("SAGE_DIR")}."\\$checkFile"))?1:0), $negate, $text); 
            $perRunOptionsHash->{lc("check")} = $checkFile;
        }
        elsif ($check =~ /NOTEMPTY:(.*)/i)
        {
            $checkFile = encode('ISO-8859-1' , $1);
            echoPrint("            - Does file ($checkFile) exist?\n",2);
            $condTrue = checkProfileCond((((-s "$checkFile" || 
                                            -s $perRunOptionsHash->{lc("SAGE_DIR")}."\\$checkFile"))?1:0), $negate, $text); 
            $perRunOptionsHash->{lc("check")} = $checkFile;
        }
        elsif ($check =~ /PATH:(.*)/i)
        {
            $checkDirectory = encode('ISO-8859-1' , $1);
            echoPrint("            - Does path to ($checkDirectory) exist?\n",2);
            $condTrue = checkProfileCond(((-d getPath("$checkDirectory"))?1:0), $negate, $text);
            $customSubStringArray->{lc("check")} = $checkDirectory;
        }
        elsif ($check =~ /DIRECTORY:(.*)/i)
        {
            $checkDirectory = encode('ISO-8859-1' , $1);
            echoPrint("            - Does file ($checkDirectory) exist?\n",2);
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
                $checkValue = lc($perRunOptionsHash->{videoInfo}{lc($fileKey)}{lc($key)});
                echoPrint("            - Does perRunOptionsHash{videoInfo}{$inputFile}{\"$key\"} (".$perRunOptionsHash->{videoInfo}{lc($fileKey)}{lc($key)}.") $meathod $lowerCase?\n",2);
                echoPrint("              + file key = $fileKey\n",2);
            }
            elsif (exists $perRunOptionsHash->{lc($checkValue)})
            {
                echoPrint("            - Does {$checkValue}(".lc($perRunOptionsHash->{lc($checkValue)}).") $meathod ($lowerCase)?\n",2);
                $checkValue = lc($perRunOptionsHash->{lc($checkValue)});
            }
            else
            {
                 echoPrint("            - Does ($checkValue) $meathod ($lowerCase)?\n",2);
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
                echoPrint("              ! Key not found ()\n",2);
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
            echoPrint("            - Does video info property ($check) exist?\n",2);
            $condTrue = checkProfileCond((exists $perRunOptionsHash->{videoInfo}{lc($fileKey)}{lc($key)}?1:0), $negate, $text);
            $perRunOptionsHash->{lc("check")}  = $perRunOptionsHash->{videoInfo}{lc($fileKey)}{lc($key)};
        }
        else
        {   # Else, check for custom conditional  
            echoPrint("            - Does custom conditional ($check) exist? ($perRunOptionsHash->{lc($check)})\n",2);
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
            echoPrint("              + ".(($negate == 1) ? "!False (True)" : "True")."\n",2);
            $condTrue = 1;
        }
        else
        {
            echoPrint("              + ".(($negate == 1) ? "!True (False)" : "False")."\n",2);
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
            echoPrint("              + ".(($negate == 1) ? "!False (True)" : "True")."\n",2);
            $condTrue = 1;
        }
        else
        {
            echoPrint("              + ".(($negate == 1) ? "!True (False)" : "False")."\n",2);
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
            echoPrint("      + Replacing snippit $snippitName : $currentTarget\n",2);
        }
        
        while($currentTarget =~ /%%RAND([0-9]+)_([0-9]+)%%/i)
        {
            $randMin   = $1;
            $randRange = $2 - $randMin;
            $toReplace = $&;
            $randomNum = int(rand($randRange)) + $randMin;
            $currentTarget =~ s#\Q$toReplace\E#$randomNum#g;
            echoPrint("      + Replacing with random int : $currentTarget\n",2);
        }
        
        while($currentTarget =~ /%%OUTPUT_([^%_]*)(_[^%]*)?%%/i)
        {   # Generate name for new output file
            $outputName  = $1;
            $outputFunc  = $2;
            $snipToReplace = $&;
            $newInputFile    = "outputFile".$outputName;
            $newInputReplace = $newInputFile.($outputFunc eq "" ? "" : "_$outputFunc" );
            $perRunOptionsHash->{lc($newInputFile)} = $perRunOptionsHash->{lc("scratchPath")}."\\".$perRunOptionsHash->{lc("scratchName")}.".".$perRunOptionsHash->{lc("commandNum")}.".$outputName";
            $currentTarget =~ s#\Q$snipToReplace\E#%%$newInputReplace%%#g;
            echoPrint("      + Replacing outputFile $snipToReplace -> $newInputFile : ($perRunOptionsHash->{lc($newInputFile)})\n",2);
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
            @parseMeathod = reverse(@parseMeathod);
    
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
                echoPrint("          - $meathod In: ($wholeSubString) with ($replaceString)\n",2);
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
                elsif ($meathod eq "PROPSPATH")
                {   
                    $replaceString =~ s/\\\\/###/g;
                    $replaceString =~ s/\\//g;
                    $replaceString =~ s/###/\\/g;
                }                
                elsif ($meathod eq "SUBDAY")
                {
                    if ($replaceString =~ /([0-9]{4})-([0-9]{2})-([0-9]{2})/)
                    {
                        my $year  = $1;
                        my $month = $2;
                        my $day   = $3;
                        $canonical = Date_to_Days($year,$month,$day);
                        ($year,$month,$day) = Add_Delta_Days(1,1,1, $canonical - 2);
                        $replaceString = "$year-$month-$day";
                    }
                }
                elsif ($meathod eq "TOXML")
                {
                    $replaceString =~ s/\&/&amp;/g;
                    $replaceString =~ s/"/&quot;/g; #"
                    $replaceString =~ s/</&lt;/g;
                    $replaceString =~ s/>/&gt;/g;
                    $replaceString =~ s/'/&apos;/g;  #'
                }
                elsif ($meathod eq "FROMXML")
                {
                    $replaceString =~ s/\&amp;/&/g;
                    $replaceString =~ s/\&quot;/"/g; #"
                    $replaceString =~ s/\&lt;/</g;
                    $replaceString =~ s/\&gt;/>/g;
                    $replaceString =~ s/\&apos;/'/g;  #'
                }
                elsif ($meathod eq "ESCCHARS")
                {
                    $replaceString =~ s#(\{|\}|\[|\]|\(|\)|\^|\$|\.|\||\*|\+|\?|\\)#\\$1#g;
                }
                elsif ($meathod eq "STRIPSPACES")
                {
                    $replaceString = trim($replaceString);
                }
                elsif ($meathod eq "REVSLASHES")
                {
                    $replaceString =~ s#\\#/#g;
                }
                elsif ($meathod eq "FORWARDSLASHES")
                {
                    $replaceString =~ s#\/#\\#g;
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
                echoPrint("          - $meathod Out: ($wholeSubString) with ($replaceString)\n",2);
            }
            echoPrint("        - Replacing: $wholeSubString with ($replaceString)\n",2);
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
        echoPrint("    - Scanning Directory: $inputFile ($fileFilter)\n");
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
                echoPrint("        - Replacing $&: $quoteHash{$1}\n",2);
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
            $serverIP     = $2;
            $serverIP80   = $serverIP.':80';
            $serverIP8080 = $serverIP.':8080';
            echoPrint("        - Adding Credientials: ".$currentCommand->{lc("user")}."\@$serverIP(".$currentCommand->{lc("realm")}.")\n");
            $ua->credentials(  # add this to our $browser 's "key ring"
              $serverIP80, $currentCommand->{lc("realm")},
              $currentCommand->{lc("user")} => $currentCommand->{lc("password")}
            );
            $ua->credentials(  # add this to our $browser 's "key ring"
              $serverIP8080, $currentCommand->{lc("realm")},
              $currentCommand->{lc("user")} => $currentCommand->{lc("password")}
            );
            if(exists $perRunOptionsHash->{lc("port")})
            {
                echoPrint("        - Adding Credientials: ".$currentCommand->{lc("user")}."\@$serverIP(".$currentCommand->{lc("realm")}.")\n");
                $ua->credentials(  # add this to our $browser 's "key ring"
                  $serverIP, $currentCommand->{lc("realm")},
                  $currentCommand->{lc("user")} => $currentCommand->{lc("password")}
                );
            }
        } 
    }

##### Append a profile to the execution list
    sub insertFunction
    {
        my ($currentTarget,$currentCommand,$perRunOptionsHash,$profiles,$branch) = @_;
        my $j;
        
        if (exists $profiles->{lc($currentTarget)})
        {
            echoPrint("        - Found function profile ($currentTarget)\n",2);
            if (!$branch)
            {
                echoPrint("        - Adding $profiles->{lc($currentTarget)}{numCommands} targets\n",2);
                $perRunOptionsHash->{lc("numCommands")} += $profiles->{lc($currentTarget)}{"numCommands"};         
            }
            else
            {
                echoPrint("        - Branching to $profiles{lc($currentTarget)}{numCommands} targets\n",2);
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
            echoPrint("        ! Couldn't find function profile ($currentTarget)\n",2);                      
        }
    }

##### Populate an options Hash
    sub setOptions
    {
        my ($optionsString,$optionsArray,$optionsHash,$inputFiles,$commandHash,$logSpacing) = @_; 
        my @newOptions;
        my $key;
        my $noOverwrite = 0;
        echoPrint("$logSpacing+ Parsing switches\n");
        echoPrint("$logSpacing  - optionsString: $optionsString\n");
        if (@{$optionsArray}) { echoPrint("$logSpacing  - optionsArray: @{$optionsArray}\n"); }
        if ($optionsString)
        {
            @newOptions= splitWithQuotes($optionsString," ");
        }
        @newOptions = (@{$optionsArray},@newOptions,);
        if (exists $commandHash->{lc("noOverwite")})
        {
            $noOverwrite = 1;
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
                echoPrint("$logSpacing    + Key: $key\n");
                if (exists $optionsHash->{lc($key)} && $noOverwrite)
                {
                    echoPrint("$logSpacing      ! Already Exists, skipping: (".$optionsHash->{lc($key)}.")\n");
                }
                else
                {
                    $optionsHash->{lc($key)} = "";
                    if ((!($newOptions[1] =~ m#^/# || $newOptions[1] eq "") || $newOptions[1] =~ m#^/.*/#))
                    {   # If the next parameter data for switch
                        $optionsHash->{lc($key)} = $newOptions[1];
                        echoPrint("$logSpacing    + Value: $optionsHash->{lc($key)}\n");
                        shift(@newOptions);    # Remove next parameter also
                        if ($getVideoInfoCheck eq "!")
                        {
                            getVideoInfo($optionsHash->{lc($key)},"     ",$optionsHash);
                        }
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
        
        if (exists $perRunOptionsHash->{lc("throttle")} && 
            ( $currentCommand->{lc("exe")} =~ /wget/      ||
              $currentCommand->{lc("exe")} =~ /curl/))
        {   # Wait 10 seconds as to not throttle websites
            echoPrint("        + Throttling: Sleeping for ".$perRunOptionsHash->{lc("throttle")}." seconds\n");
            sleep($perRunOptionsHash->{lc("throttle")});
        }
        
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
            $startRunCommand = "start /D \"".getPath($runEXE)."\" /BELOWNORMAL /WAIT /B ".$currentCommand->{lc("exe")}." $currentTarget";
        }
        else
        {   # assume its a system command and try and run it anyway
            $runEXE     = $currentCommand->{lc("exe")};
            $runCommand = $currentCommand->{lc("exe")}." $currentTarget";
            $startRunCommand = "$runEXE $currentTarget";
        }        

        if ($teeOutput && exists $perRunOptionsHash->{lc("tee")})
        {
            $captureLogTee = "\"".$binFiles->{lc("mtee.exe")}."\" \"$logFile.log\"";
            $runCommand = encode('ISO-8859-1',"$startRunCommand 2>\"$logFile.err.log\" \| $captureLogTee");
            echoPrint("        - Executing command: $startRunCommand\n");
            select(STDOUT);
            echoPrint("\n################# ".$currentCommand->{lc("exe")}." Output $comment ###############\n");
            system($runCommand);
            select($mainLog);
            $averageFPS = captureFPS("$logFile.log");
            echoPrint("\n################# ".$currentCommand->{lc("exe")}." $comment Average FPS = $averageFPS ###############\n\n");  
        }
        else
        {
            #echoPrint("        - Executing command (new): $runCommand\n");
            #Win32::Process::Create($ProcessObj, 
            #        "$runEXE",
            #        "$currentTarget",
            #        0,
            #        IDLE_PRIORITY_CLASS|DETACHED_PROCESS,
            #        getPath("$logFile.log"));
            #$ProcessObj->Wait(INFINATE);
        
            $runCommand = encode('ISO-8859-1',"$runCommand > \"$logFile.log\" 2>&1");
            echoPrint("        - Executing command: $runCommand\n");
            `$runCommand`;
            if (-s "$logFile.log")
            {
                my $linesToSave = 30;
                my $linesRead   = 0;
                my @lines = ();
                open(ENCODELOG,"$logFile.log");
                while(<ENCODELOG>)
                {
                    my $line = $_;
                    push(@lines,$_);
                    if (@lines > $linesToSave)
                    {
                        shift(@lines);
                    }
                }
                close(ENCODELOG);
                $currentCommand->{lc("encodeLog")}  = "@lines";
                unshift(@lines,"------ Last $linesToSave lines of log -------\n");
                my $fullText = "@lines";
                $fullText =~ s/\r/\n/g;
                echoPrint(padLines("          + ",split(/\n/,$fullText)),100);                   
            }
            
        } 
    }
    
    sub padLines
    {
        my ($padding,@arrayToPad) = @_;
        my $line;
        my $paddedString = "";
        
        foreach $line (@arrayToPad)
        {
            if (!($line =~ /\n$/))
            {
                $line .= "\n";
            }
            $paddedString .=  $padding.$line;       
        }
        return $paddedString;
    }

##### Write to a formated output file               
    sub outputFile
    {
        my ($currentTarget,$currentCommand,$perRunOptionsHash,$profiles) = @_;
        my $openSuccess = 0;
        my $outputLine;
        my $outputFile;
        my $outputFileHandle;
        my $encoding = (exists $currentCommand->{lc("encoding")} ? $currentCommand->{lc("encoding")} : "utf8");
        
        $currentTarget = encode("ISO-8859-1",$currentTarget);
        echoPrint("        - Outputing to file ($currentTarget): (".$currentCommand->{lc("output")}.")\n");
        if ($currentTarget =~ /STDOUT/)
        {   # Just write to STDOUT   
            $openSuccess = 1;
        }
        elsif (exists $currentCommand->{lc("append")})
        {
            echoPrint("          + Appending\n");
            if (open(OUTPUTFILE, ">>$currentTarget")) { $openSuccess = 1; }
        }
        else 
        {
            if (open(OUTPUTFILE, ">$currentTarget")) { $openSuccess = 1; }   
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
                
                if (exists $currentCommand->{lc("toXML")})
                {
                    $outputFile = toXML($outputFile);    
                }
                
                if (exists $currentCommand->{lc("fromXML")})
                {
                    $outputFile = fromXML($outputFile);    
                }
                
                if ($currentTarget eq "STDOUT")
                {
                    print STDOUT encode("ISO-8859-1",$outputFile);
                }
                else
                {
                    print OUTPUTFILE encode("ISO-8859-1",$outputFile);
                }
                close(OUTPUTFORMAT);
            }
            else
            {
                echoPrint("        ! Couldn't open ".$currentCommand{lc("output")}.".output for read\n",2);     
            }
        }
        else
        {
            echoPrint("        ! Couldn't open file for write ($currentTarget)\n",2);                      
        }
        close OUTPUTFILE;
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
                    sleep($perRunOptionsHash->{lc("throttle")});
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
            
            # Wait 10 seconds as to not throttle websites
            echoPrint("          + Sleeping for ".$perRunOptionsHash->{lc("throttle")}." seconds as to not throttle website\n");
            sleep($perRunOptionsHash->{lc("throttle")});

            if ($perRunOptionsHash->{lc("saveHTML")})
            {
                open(WRITEHTML,">".$perRunOptionsHash->{lc("EXEPATH")}."\\".$currentCommand->{lc("get")}.".".getFile($perRunOptionsHash->{lc("inputFile")}).".html");
                print WRITEHTML $cachedHTML->{lc($currentCommand{lc("get")})};
                close(WRITEHTML);  
            }
        }
        else
        {
            echoPrint("          + Using cached webpages\n");
            $cachedHTML->{lc($currentCommand{lc("get")})} = $cachedHTML->{lc("$currentTarget")};
        }        
    }

##### Read Profiles into Hash
    sub readProfiles
    {
        my ($profileFolder,$profiles,$showOutput) = @_;
        my @profileNames = ();
        my @profileFiles = scanDir($profileFolder,"profile|func|snip|output|scrape");
        
        foreach (@profileFiles)
        {
            if (/\.output$/)
            {
                $profiles->{lc(getFile($_).".output")} = $_;
            }
        }
        

        echoPrint("  + Reading Profiles (".@profileFiles.")\n",2);
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
                        $profileName = trim(lc($1)); #Save the next profile name
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
 
        if ($showOutput)
        {
            foreach $profileName (@profileNames)
            {
                echoPrint("   - Profile \"$profiles{$profileName}{name}\"\n",2);
                echoPrint("    + Number of Commands : $profiles{$profileName}{numCommands}\n",2);
                for ($j=0;$j<($profiles{$profileName}{"numCommands"});$j++)
                {   # targets
                echoPrint("      - Command #".($j+1)."        : ".$profiles{$profileName}{"targets"}[$j]."\n",2);
                if (!($profiles{$profileName}{"targets"}[$j] eq "")) { echoPrint("      - Encoder #".($j+1)."        : ".$profiles{$profileName}{"commands"}[$j]."\n",2); }
                }
            }
        }
        else
        {
            echoPrint("    - Found ".(length @profileNames)." Profiles\n",2);
        }
    }

##### Use Command
    sub captureData
    {
        my ($currentTarget,$currentCommand,$perRunOptionsHash,$cachedHTML,$profiles) = @_;
        
        my $splitter = (exists $currentCommand->{lc("split")} ? $currentCommand->{lc("split")} : "||");
        my $origCurrentTarget = $currentTarget;
        
        my @regEXCapture = ();
        while($currentTarget =~ m#\$\$([a-zA-Z0-9_]*)\$\$#)
        {
            $variable = $1;
            push @regEXCapture, $variable;
            $perRunOptionsHash->{lc("varsToFlush")}{$variable} = {};
            $currentTarget =~ s#\$\$$variable\$\$##;
            #echoPrint("        - \$".scalar(@regEXCapture).": $variable\n");
        }

        echoPrint("      + Target  : $currentTarget\n");
        for ($i=0;$i<@regEXCapture;$i++)
        {
            echoPrint("        - \$".($i+1).": $regEXCapture[$i]\n",2);
        }
        
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
    
        if (exists $currentCommand->{lc("isXML")} && $text =~ /</)
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
                $perRunOptionsHash->{lc("varsToFlush")}{$currentCommand->{lc("variable")}} = "";
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
        elsif (exists $currentCommand->{lc("imdb")})
        {   # Use IMDB api
            my $imdbObj = new IMDB::Film(crit => $text);
            echoPrint("        - Using IMDB ID: ($text)\n");  
            if ($imdbObj->status())
            {
                $perRunOptionsHash->{lc("filmTitle")} = $imdbObj->title();
                $perRunOptionsHash->{lc("releaseYear")} = $imdbObj->year();
                $perRunOptionsHash->{lc("tagline")} = $imdbObj->tagline();
                $perRunOptionsHash->{lc("plot")} = $imdbObj->plot();               
                $perRunOptionsHash->{lc("userRating")} = int($imdbObj->rating());
                $perRunOptionsHash->{lc("runTime")} = $imdbObj->duration();
                $perRunOptionsHash->{lc("trivia")} = $imdbObj->trivia();
                $perRunOptionsHash->{lc("goofs")} = $imdbObj->goofs();
                $perRunOptionsHash->{lc("awards")} = $imdbObj->awards();
                my @cast = @{ $imdbObj->cast() };
                foreach (@cast)
                {
                    $perRunOptionsHash->{lc("castIMDB")} .= $_->{"name"}.$splitter;
                    $perRunOptionsHash->{lc("rolesIMDB")} .= $_->{"role"}.$splitter;
                }
                my @writers = @{ $imdbObj->writers() };
                foreach (@writers)
                {
                    $perRunOptionsHash->{lc("writerIMDB")} .= $_->{"name"}.$splitter; 
                }
                my @directors = @{ $imdbObj->directors() };
                foreach (@directors)
                {
                    $perRunOptionsHash->{lc("directorIMDB")} .= $_->{"name"}.$splitter; 
                }
                my @genres = @{ $imdbObj->genres() };
                foreach (@genres)
                {
                    $perRunOptionsHash->{lc("genres")} .= $_.$splitter; 
                }
                my @releaseDate = @{ $imdbObj->release_dates() };
                for(@releaseDate) 
                {
                    if ($_->{"country"} eq "USA")
                    {
                        $perRunOptionsHash->{lc("releaseDate")} = $_->{"date"};
                        last;
                    }    
                }
                my @alsoKnownAs =  @{ $imdbObj->also_known_as() };
                foreach (@alsoKnownAs)
                {
                    $perRunOptionsHash->{lc("aka")} .= $_.$splitter;    
                }
                
                my %certifications = %{$imdbObj->certifications()};
                $perRunOptionsHash->{lc("miniRating")} = $certifications{"USA"};     

                echoPrint("          + filmTitle  : (".$perRunOptionsHash->{lc("filmTitle")}.")\n");
                echoPrint("          + Rated      : (".$perRunOptionsHash->{lc("miniRating")}.")\n");
                echoPrint("          + releaseYear: (".$perRunOptionsHash->{lc("releaseYear")}.")\n");
                echoPrint("          + tagline    : (".$perRunOptionsHash->{lc("tagline")}.")\n");     
                echoPrint("          + plot       : (".$perRunOptionsHash->{lc("plot")}.")\n");
                echoPrint("          + userRating : (".$perRunOptionsHash->{lc("userRating")}.")\n");
                echoPrint("          + runTime    : (".$perRunOptionsHash->{lc("runTime")}.")\n");      
                echoPrint("          + trivia     : (".$perRunOptionsHash->{lc("trivia")}.")\n");
                echoPrint("          + goofs      : (".$perRunOptionsHash->{lc("goofs")}.")\n");
                echoPrint("          + awards     : (".$perRunOptionsHash->{lc("awards")}.")\n");
                echoPrint("          + cast       : (".$perRunOptionsHash->{lc("castIMDB")}.")\n");
                echoPrint("          + roles      : (".$perRunOptionsHash->{lc("rolesIMDB")}.")\n");
                echoPrint("          + writers    : (".$perRunOptionsHash->{lc("writerIMDB")}.")\n");
                echoPrint("          + directors  : (".$perRunOptionsHash->{lc("directorIMDB")}.")\n");              
                echoPrint("          + genres     : (".$perRunOptionsHash->{lc("genres")}.")\n");  
                echoPrint("          + releaseDate: (".$perRunOptionsHash->{lc("releaseDate")}.")\n");  
                echoPrint("          + aka        : (".$perRunOptionsHash->{lc("aka")}.")\n");
            }
            else
            {
                echoPrint("    ! IMDB API Failed!!!\n"); 
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
                        $perRunOptionsHash->{lc("varsToFlush")}{$currentCommand->{lc("variable")}} = "";
                    }
                    
                    if (exists $currentCommand->{lc("foreach")})
                    {   # Insert this function again
                        if ((exists $currentCommand->{lc("forEachLimit")} && 
                             $currentCommand->{lc("forEachLimit")} >= $perRunOptionsHash->{lc("forEachLimit")}) || 
                            !(exists $currentCommand->{lc("forEachLimit")}))
                        {
                            echoPrint("            - FOREACH (".$perRunOptionsHash->{lc("forEachLimit")}."/".$currentCommand->{lc("forEachLimit")}."): Inserting (".$currentCommand->{lc("foreach")}.")\n");
                            my $storeResults = lc("forEachRemainder".int(rand(10000)));
                            $perRunOptionsHash->{$storeResults} = $after;
                            print STDOUT $perRunOptionsHash->{lc("forEachRemainder")};
                            $perRunOptionsHash->{lc("numCommands")}++;
                            
                            $forEachCommand = "/use \"@\@".$storeResults."@@\"";
                            foreach (keys %{$currentCommand})
                            {
                                if (!($_ eq lc("use")))
                                {
                                    $forEachCommand .= " /$_ \"".$currentCommand->{lc("$_")}."\"";
                                }    
                            }
                            echoPrint("              + Target: $origCurrentTarget\n",2);
                            echoPrint("              + Target: $forEachCommand\n",2);
                            unshift(@{$perRunOptionsHash->{lc("usingTargets")}},$origCurrentTarget);
                            unshift(@{$perRunOptionsHash->{lc("usingCommands")}},$forEachCommand);
                            # Insert Success function
                            insertFunction(lc($currentCommand->{lc("foreach")}),\%emptyHash,$perRunOptionsHash,$profiles,0);
                            if (exists $perRunOptionsHash->{lc("forEachLimit")})
                            {
                                $perRunOptionsHash->{lc("forEachLimit")}++;    
                            }
                            else
                            {
                                $perRunOptionsHash->{lc("forEachLimit")} = 2;    
                            }
                        }
                        else
                        {
                            echoPrint("            - FOREACH: Reached Limit (".$currentCommand->{lc("forEachLimit")}.")\n",2);
                            $perRunOptionsHash->{lc("forEachLimit")} = 1;
                        }
                    }
                                            
                }
            }
            else
            {
                $addedVariable = 0;
                
                if (exists $currentCommand->{lc("variable")})
                {   # Make sure variable is cleaned
                    delete $perRunOptionsHash->{lc($currentCommand->{lc("variable")})};
                    $perRunOptionsHash->{lc("varsToFlush")}{$currentCommand->{lc("variable")}} = "";
                }
                
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
                delete $perRunOptionsHash->{lc("forEachRemainder")};
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
    
    sub toXML
    {
        my $string = shift;
        $string =~ s/\&/&amp;/g;
        $string =~ s/"/&quot;/g; #"
        $string =~ s/</&lt;/g;
        $string =~ s/>/&gt;/g;
        $string =~ s/'/&apos;/g;  #'
        return $string;    
    }
    
    sub fromXML
    {
        my $string = shift;
        $string =~ s/\&amp;/&/g;
        $string =~ s/\&quot;/"/g; #"
        $string =~ s/\&lt;/</g;
        $string =~ s/\&gt;/>/g;
        $string =~ s/\&apos;/'/g;  #'
        return $string;    
    }
  
    sub reverseSlashes
    {
        my ($input) = @_;
        $input =~ s#\\#/#g;   
        return $input;
    }
    
    sub forwardSlashes
    {
        my ($input) = @_;
        $input =~ s#\/#\\#g;   
        return $input;
    }

    sub runCommand
    {
        my ( $command, $action ) = @_;
        echoPrint("$action: $command\n",2);
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

        foreach (keys (%passwords))
        {
            $toPrint =~ s/$_/******/g;    
        }
        
        my $shortPrint = $toPrint;     
        if ($batchMode == 0)
        {
            $shortPrint  = substr($toPrint, 0, 150);
            
            if (length($toPrint) > 150)
            {
                $shortPrint .= "...\n";    
            }
        }
        
        if ($toPrint =~ /.*\n.*\n.*\n.*\n/ && $level < 100)
        {
			      $shortPrint =~ s/\n/ /g;
			      $shortPrint = $shortPrint."\n";
            $toPrint = $shortPrint; 
        }
               
        foreach (keys %fileHandles)
        {
            print {$fileHandles{$_}} $toPrint;
        }
        
        if ($level <= $verboseLevel || $level == 100)
        {
          print STDOUT $shortPrint;
        }
        $ourStorySoFar .= $toPrint;
        $| = 1;
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
        sleep 1;
        foreach $file (@{$deleteFiles})
        {
            echoPrint("    - Deleting File: $file\n");
            if (-d $file && !($file eq ""))
            {
                if (-e "$file\\delete.me")
                {
                    $rmdirString = "rmdir /S /Q \"$file\"";
                    echoPrint("      + Deleting Folder: $rmdirString\n");
                    `$rmdirString`;
                }
                else
                {
                    echoPrint("      ! Skipping!\n");    
                }
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
    

sub detectVideoProperties
{
    my ($video,$baseSpace,$perRunOptionsHash) = @_;
    my $videoInfoArray = \%{$perRunOptionsHash->{videoInfo}{lc($video)}};
    my $binFiles      = \%{$perRunOptionsHash->{lc("mediaEngineBins")}};

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
    if ($yRes == 0)
    {
        return;
    }
    my $aspectRatioValue = $xRes/$yRes;
    my $additionalCropX = int(10*$aspectRatioValue); # Additional Crop to compensate for overscan
    my $additionalCropY = 10; # Additional Crop to compensate for overscan

    my $encodeSettings = "-acodec copy -vcodec copy -scodec copy -y";
    if (!($videoInfoArray->{lc("videoCodec")} =~ /(mpeg2video)/))
    {   # For non-mpeg sources
        $encodeSettings = "-acodec mp2 -ac 2 -vcodec mpeg2video -y";
    }

    my ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();

    $pullupEncodeSettings = "pullup,softskip -ovc lavc -lavcopts vcodec=mpeg4:mbd=2:turbo";
    if ($videoInfoArray->{lc("videoResolution")} =~ /x720/ && $videoInfoArray->{lc("videoContainer")} =~ /mpeg/)
    {   # For non-mpeg sources
        $pullupEncodeSettings = "tinterlace," . $pullupEncodeSettings;
    }
    
    echoPrint("    - Detecting Advanced Video Properties (this may take a few minutes...):\n");
    if (!exists $videoInfoArray->{lc("inputLine")})
    {
        echoPrint("      ! Failed\n");
        return;
    }
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
            echoPrint("      + Getting clip: (".int($autoCropCheckTime * $j)." - ".int(($autoCropCheckTime * $j)+$clipDuration).") $ffmpegString\n",2);
            if (!(-s "$baseFileName.clip_$j.mpg"))
            {
                `$ffmpegString`;
            }
        }

        for ($j = 1; $j < $numClips; $j++)
        {               
            $comskipString = forkCommand($binFiles->{lc("comskip.exe")}," --ini=\"".getPath($binFiles->{lc("comskip.exe")})."\\comskip.ini\" \"$baseFileName.clip_$j.mpg\" > \"$baseFileName.clip_$j.comskip.log\" 2>&1","$baseFileName.clip_$j.comskip.finished");
            echoPrint("        - Running Comskip: $comskipString\n",2);
            if (!(-s "$baseFileName.clip_$j.csv"))
            {
                `$comskipString`;
            }
                        
            $ccextratorString = forkCommand($binFiles->{lc("ccextractorwin.exe")}," -srt \"$baseFileName.clip_$j.mpg\" -o \"$baseFileName.clip_$j.srt\" > \"$baseFileName.clip_$j.ccextractor.log\" 2>&1","$baseFileName.clip_$j.ccextractor.finished");
            echoPrint("        - Running ccextrator: $ccextratorString\n",2);
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
            echoPrint("        - Getting pullup: $mencoderString\n",2);
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
            echoPrint("        - Deleting Temp Video: $delString\n",2);
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
                    #echoPrint("$j\n",2);  
                    
                    if ($highestCropConfidence > (($totalSize-$j)+$cropConfidence[$i]) || 
                        $cropConfidence[$i] > ($originalTotalSize /2))
                    {
                        last;
                    }
                }
                #echoPrint("      ? autoCrop: $topCrop[$i]:$bottomCrop[$i]:$leftCrop[$i]:$rightCrop[$i] ($cropConfidence[$i] / $totalSize / $originalTotalSize) \n",2);
                if($cropConfidence[$i] > $highestCropConfidence)
                {
                    $cropIndex = $i;
                    $highestCropConfidence = $cropConfidence[$i];
                    echoPrint("      ? autoCrop: $topCrop[$cropIndex]:$bottomCrop[$cropIndex]:$leftCrop[$cropIndex]:$rightCrop[$cropIndex] ($highestCropConfidence / $originalTotalSize) \n",2);
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
            echoPrint("      ? Adjusted for Overscan: $topCrop[$cropIndex]:$bottomCrop[$cropIndex]:$leftCrop[$cropIndex]:$rightCrop[$cropIndex] ($additionalCropX x $additionalCropY)\n",2);
         
            my $cropX = abs($rightCrop[$cropIndex] - $leftCrop[$cropIndex]);
            my $cropY = abs($topCrop[$cropIndex] - $bottomCrop[$cropIndex]);
            echoPrint("      + Orignal Cropped Res: $cropX x $cropY (".($cropX/$cropY).")\n",2);   
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
            
            # Check for letterbox and 4:3 crop
            if (($xRes - $cropX) > 100)
            {
                $videoInfoArray->{lc("43in169")} = ($xRes - $cropX);
                echoPrint("      + Detected 4:3 in 16:9 ($xRes -> $cropX)\n");    
            }          
            if (($yRes - $cropY) > 100)
            {
                $videoInfoArray->{lc("letterbox")} = ($yRes - $cropY);
                echoPrint("      + Detected letterbox ($yRes -> $cropY)\n");    
            }            
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
        
        if (exists $perRunOptionsHash->{lc("saveVideoProps")} && !(-s getFullFile($perRunOptionsHash->{lc("original")}).".props"))
        {
            open(PROPSFILE,">".getFullFile($perRunOptionsHash->{lc("original")}).".props");
            print PROPSFILE $videoInfoArray->{lc("embeddedCCCount")}.",".$videoInfoArray->{lc("percentFilm")}.",".$videoInfoArray->{lc("cropX")}.",".$videoInfoArray->{lc("cropY")}.",".$videoInfoArray->{lc("autoCropHandBrake")}.",".$videoInfoArray->{lc("autoCropHandBrake")}.",".$videoInfoArray->{lc("autoCropMencoder")}.",".$videoInfoArray->{lc("cropConfidence")};
            close PROPSFILE;
        }
    }
    echoPrint("        - Cropped Res Divisable by 16: ".$videoInfoArray->{lc("cropX")}." x ".$videoInfoArray->{lc("cropY")}." \n");   
    echoPrint("      + handbrake: " . $videoInfoArray->{lc("autoCropHandBrake")} . "\n",2);
    echoPrint("      + mencoder : " . $videoInfoArray->{lc("autoCropMencoder")} . "\n",2); 
    echoPrint("      + telecine : " . $videoInfoArray->{lc("percentFilm")} . "% ($telecineCount / $numTelecineSamples)\n");
    echoPrint("      + embeddedCC : " . $videoInfoArray->{lc("embeddedCCCount")} . "\n");

    # Get Finish Time
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
    $transcodeTime = $durHour . ":" . $durMin . ":" . $durSec;
    echoPrint("      + Analyzing Duration: $transcodeTime\n");
}


sub detectDVDTitleProperties
{
    my ($video,$baseSpace,$perRunOptionsHash) = @_;
    my $videoInfo     = \%{$perRunOptionsHash->{videoInfo}{lc($video)}};
    my $binFiles      = \%{$perRunOptionsHash->{lc("mediaEngineBins")}};   
    my $baseFile      = $perRunOptionsHash->{lc("scratchPath")}."\\".getFile($video).".testDVD";
    $videoInfo->{lc("embeddedCCCount")} = 0;
    
    for($m=1;$m<5;$m++)
    {
        my $mencoderString = "\"".$binFiles->{lc("mencoder.exe")}."\" dvd:\/\/".$perRunOptionsHash->{lc("dvdTitle")}." -dvd-device \"$video\" -ss ".($m*150)." -frames 300 -oac copy -ovc copy -o \"$baseFile.$m.mpg\" -of mpeg -mpegopts format=dvd:tsaf > \"$baseFile.$m.log\" 2>&1";
        echoPrint("$baseSpace+ Getting dvd test clip: $mencoderString\n");
        `$mencoderString`;
        if ((-e "$baseFile.$m.mpg"))
        {
            $ccextratorString = "\"".$binFiles->{lc("ccextractorwin.exe")}."\" -srt \"$baseFile.$m.mpg\" -o \"$baseFile.$m.srt\"> \"$baseFile.$m.ccextractor.log\" 2>&1";
            echoPrint("$baseSpace  - Getting SRT: $ccextratorString\n");
            if (!(-s "$baseFile.$m.srt"))
            {
                `$ccextratorString`;
            }
            $srtSize = -s "$baseFile.$m.srt";
            echoPrint("$baseSpace    + Size: $srtSize\n");
            $videoInfo->{lc("embeddedCCCount")} += -s "$baseFile.$m.srt";
        }
        else
        {
            echoPrint("$baseSpace  - Getting dvdClip: FAIL\n");
        }
    }
    echoPrint("$baseSpace    + embeddedCCCount: ".$videoInfo->{lc("embeddedCCCount")} ."\n");
}

sub dvdScanForTitles
{
    my ($video,$baseSpace,$perRunOptionsHash) = @_;
    my %titleHash = ();
    my %durHash   = ();
    my %soundHash = ();
    my %srtHash   = ();
    my %commentaryHash = ();
    my %soundHash51    = ();
    my %soundHash      = ();
    my @newPerRunOptions = ();
    my $videoInfoArray = \%{$perRunOptionsHash->{videoInfo}{lc($video)}};
    my $binFiles       = \%{$perRunOptionsHash->{lc("mediaEngineBins")}}; 
    my $baseFile       = $video.".dvdInfo";  
    my $foundTitle = -1;
    my $longest    = 0;
    my $sum        = 0;
    
    $handBrakeString = "\"".$binFiles->{lc("HandBrakeCLI.exe")}."\" -i \"".reverseSlashes($video)."\" -t 0 2>&1";
    echoPrint("  + Getting DVD info: $handBrakeString\n");
    $dvdLog = `$handBrakeString`;
    @dvdLog = split(/(\n|\r)/,$dvdLog);  
    echoPrint("    - Scanning DVD for titles\n",2);
    foreach $line (@dvdLog)
    {
        chomp($line);
        if ($line =~ /\+ title (\d+):/) 
        { 
            $currentTitle = $1;
        }
        
        if ( $line =~ /\+ duration: (\d{2}):(\d{2}):\d{2}/ && $currentTitle != $foundTitle)
        {
            $totalDur = ($1*60) + $2;
            if ($totalDur > 5)
            {
                echoPrint("      + Found Title $currentTitle ($totalDur)\n");
            }
            $titleHash{$currentTitle} = $totalDur;            
            $match = 0;
            foreach $dur (keys %durHash)
            {
                if (abs($totalDur - $dur) <= 6)
                {
                    $durHash{$dur}++;
                    $avg = int(($totalDur + $dur) / 2);
                    if ($avg != $dur)
                    {
                        $durHash{$avg} = $durHash{$dur};
                        delete $durHash{$dur};
                    }
                    $match = 1;
                    last;
                }
            }
            if (!$match) { $durHash{$totalDur} = 1; }
            $foundTitle = $currentTitle;
        }
        
        if ($totalDur > 5)
        {
            if ($line =~ /([0-9]), English \(AC3\).*,\s*[0-9]+Hz,\s*([0-9]+)bps/ && $currentTitle != 0)
            {
                    #echoPrint("        - Adding English Audio Track ($currentTitle): ($line)\n");
                    if ($2 > 300000)
                    {
                        #echoPrint("          + Audio is 5.1\n");
                        push(@{$soundHash51{$currentTitle}},$1);
                    }
                    else
                    {
                        push(@{$soundHash{$currentTitle}},$1);                    
                    }
            }
            elsif ($line =~ /([0-9]),.*eng\) \((Bitmap|Text)\)/ && $currentTitle != 0)
            {
                push(@{$srtHash{$currentTitle}},$1);
                #echoPrint("          + SRT: $1 $line\n");
            }
        }
    }
    
    echoPrint("    - Number of titles found = " . keys(%titleHash) . "\n");
    if (keys(%titleHash) == 0)
    {
        echoPrint("      ! No Titles found\n");
        return ();
    }           
    
    foreach $dur (sort { $b <=> $a } keys %durHash)
    {
        echoPrint("      + $dur ($durHash{$dur})");
        if ($longest == 0)
        {
            $longest = $dur;
            echoPrint(": Longest = $longest ($durHash{$dur})");
        }
        elsif ($dur > 10 && abs(($dur * $durHash{$dur}) - $longest) <= ($durHash{$dur}*2.5))
        {
            echoPrint(": Longest = sum of durs: ($longest ~= $dur * $durHash{$dur}(".($dur * $durHash{$dur}).")"); 
            $sum = $dur;
        }
        echoPrint("\n");
    }
    
    my @forcedTitles;
    my %forcedTitles;
    if (exists $perRunOptionsHash->{lc("forceTitle")})
    {
        @forcedTitles = split(/,/,$perRunOptionsHash->{lc("forceTitle")});
        foreach (@forcedTitles)
        {
            $forcedTitles{$_} = "";
        }
    }
    
    foreach $checkingTitle (sort { $b <=> $a } keys %titleHash)
    {
        $handbrakeAudioTracks   = "";
        $handbrakeAudioEncoders = "";
        $handbrakeAudioBitrate  = "";
        $handbrakeSubtitleTracks  = "";
        
        echoPrint("    +  Checking Title: $checkingTitle ($titleHash{$checkingTitle})($sum)($durHash{$longest})\n");
        if (((($sum && abs($titleHash{$checkingTitle} - $sum) < 5 && $durHash{$longest} == 1) ||
              (abs($titleHash{$checkingTitle} - $longest) < 5 && ($sum == 0 || $durHash{$longest} > 1))) && 
              !(exists $perRunOptionsHash->{lc("forceTitle")})) ||
              exists $forcedTitles{$checkingTitle})
        {
                $addTitle = $checkingTitle;   
                echoPrint("      - ".(exists $forcedTitles{$checkingTitle} ? "Forcing" : "Adding")." Title $checkingTitle (5.1:@{$soundHash51{$checkingTitle}}) (Stereo/Mono:@{$soundHash{$checkingTitle}})(Subtitles:@{$srtHash{$checkingTitle}})\n");
            
                foreach (@{$soundHash51{$checkingTitle}})
                {   # Add 5.1 tracks first
                    $handbrakeAudioTracks   .= "$_,";
                    $handbrakeAudioEncoders .= "ac3,";
                    $handbrakeAudioBitrate  .= "auto,";
                }
                
                foreach (@{$soundHash{$checkingTitle}})
                {   # Add stereo and mono last
                    $handbrakeAudioTracks   .= "$_,";
                    $handbrakeAudioEncoders .= "faac,";
                    $handbrakeAudioBitrate  .= "auto,";
                } 
                
                foreach (@{$srtHash{$checkingTitle}})
                {   # Add stereo and mono last
                    $handbrakeSubtitleTracks   .= "$_,";
                }                      
                
                $handbrakeAudioTracks     =~ s/,$//;
                $handbrakeAudioEncoders   =~ s/,$//;
                $handbrakeAudioBitrate    =~ s/,$//;
                $handbrakeSubtitleTracks  =~ s/,$//;

            push(@newPerRunOptions,(exists $perRunOptionsHash->{lc("profile")} ? "" : " /profile ".$perRunOptionsHash->{lc("defaultProfile")})." /inputFile \"".($video)."\" /dvdTitle $checkingTitle /handBrakeAudioTracks \"$handbrakeAudioTracks\" /handBrakeAudioEncoders \"$handbrakeAudioEncoders\" /handbrakeAudioBitrate \"$handbrakeAudioBitrate\" /isDVD /handbrakeSubtitles $handbrakeSubtitleTracks");     
        }
    }
    return @newPerRunOptions;
}





