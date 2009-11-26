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
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Encode qw(encode decode);
use LWP::UserAgent;
use utf8;
$ua = LWP::UserAgent->new;
$ua->agent( 'Mozilla/4.0 (compatible; MSIE 5.12; Mac_PowerPC)' );
$ua->timeout(25);
#$ua->proxy('http', $proxy);

# Get the directory the script is being called from
$executable = $0;
$executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;;
$executablePath = $`;


#Get the current Date
@f = (localtime)[ 3 .. 5 ]; # grabs day/month/year values
$startDate = ( $f[1] + 1 ) . "-" . $f[0] . "-" . ( $f[2] + 1900 );
( $sec, $min, $hr ) = localtime();
$startTime = sprintf("%02d:%02d:%02d",$hr,$min,$sec);
@months   = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
$illCharFileRegEx = "('|\"|\\\\|/|\\||<|>|:|\\*|\\?|\\&|\\;|`)";
$findFileRegEx = "avi|mpg|mkv|mp4|mpeg|VIDEO_TS|ts|ogm";

$preLogTxt .= "Executable: $executable\n";
$preLogTxt .= "EXE path  : $executablePath\n";

$codeVersion = "mediaScraper v1.0beta";

$invalidMsg .= "\n$codeVersion\n";
$invalidMsg .= "\tUSAGE:";
$invalidMsg .= "\tmediaScraper.exe (File|Folder) (File|Folder)...\n\n";

if (@ARGV == 0)
{
    print $invalidMsg;
    die;
}
else
{
  @parameters = @ARGV;
}

if (-s "$executablePath\\defaults.secret.txt")
{
    $preLogTxt .= "Reading Defaults from defaults.secret.txt\n";
    open(DEFAULTS,"$executablePath\\defaults.secret.txt");
    $defaults = <DEFAULTS>; 
    @parameters = (@parameters, splitWithQuotes($defaults," "));
}
elsif (-s "$executablePath\\defaults.txt")
{
    $preLogTxt .= "Reading Defaults from defaults.txt\n";
    open(DEFAULTS,"$executablePath\\defaults.txt");
    $defaults = <DEFAULTS>; 
    @parameters = (@parameters, splitWithQuotes($defaults," "));
}
close(DEFAULTS);

%globalCustomSubStringArray = ();

$preLogTxt .= "  + Parsing CLI switches\n";
$parameterString = "@parameters"; 

while (@parameters != 0)
{
    if ($parameters[0] =~ m#/([a-zA-Z0-9_]+)#i)
    {   # Generic add sub string
        $preLogTxt .= "    - Didn't recognize ($parameters[0])\n";
        $preLogTxt .= "      + Adding to global custom switch hash \n";
        $parameters[0] =~ m#/([a-zA-Z0-9_]+)#i;
        $preLogTxt .= "        - Key: $1\n";
        $globalCustomSubStringArray{lc($1)} = 1;   
        if (!($parameters[1] =~ m#^/# || $parameters[1] eq ""))
        {   # If the next parameter data for switch
            $parameters[0] =~ m#/([a-zA-Z0-9_]+)#i;
            $globalCustomSubStringArray{lc($1)} = $parameters[1];
            $preLogTxt .= "        - Value: $globalCustomSubStringArray{lc($1)}\n";
            shift(@parameters);    # Remove next parameter also
        }
        shift(@parameters);      
    }
    elsif (-e "$parameters[0]" || -d "$parameters[0]")
    {
        push(@inputFiles, $parameters[0]);
        $preLogTxt .= "      + Adding Inputfile: $parameters[0]\n";
        shift(@parameters);   
    }
    elsif (-e "$executablePath\\$parameters[0]" || -d "$executablePath\\$parameters[0]")
    {
        push(@inputFiles, "$executablePath\\$parameters[0]");
        $preLogTxt .= "      + Adding Inputfile: $executablePath\\$parameters[0]\n";
        shift(@parameters);   
    }
    else
    {
      $preLogTxt .= "    ! couldn't understand ($parameters[0]), throwing it away\n";
      shift(@parameters);  
    }
}

# Create log file
$logFile = "$executablePath\\scraper.log";
$preLogTxt .= "\n* Sage Directory = $sageDir\n";
$preLogTxt .= "* Setting logfile = $logFile\n";
open( LOGFILE, ">$logFile" ) || die "Can't open create log file";
select(LOGFILE);
$| = 1;
echoPrint("Welcome to $codeVersion\n");
echoPrint("Staring Proccesing at $startTime $startDate\n\n");
print "$preLogTxt";
print STDOUT "$preLogTxt";

print "\n------------------Scraping Profiles--------------------\n";
print "  + Looking for Scraping profiles file...\n";
unless(-e "$executablePath\\scrapingProfiles")
{
    print "! Failed!  Can't find scraping profiles folder\n";
    die "Can't find scraping profiles folder";
}
$profileFolder = "$executablePath\\scrapingProfiles";
print "   - Found = $profileFolder\n";

unless ( opendir( PROFILES, "$profileFolder" ) )
{
    print "! Failed!  Can't open scraping profiles folder\n";
    die "Can't open scraping profiles folder";
}

@profileNames = ();
%profiles = ();
print "  + Reading Profiles\n";
while ($file = readdir(PROFILES))
{
    @commands = ();
    @targets = ();
    $numCommands = 0;
    if ($file =~ /\.(profile|func|snip|output|scrape)$/i)
    {
        open(PREFS,"$profileFolder\\$file");
        while (<PREFS>)
        {
            chomp;
            if ( $_ =~ /Profile[#0-9 ]*=(.*)/)
            {   # If multiple profiles in one file
                if (!($profileName eq ""))
                {
                    $profiles{$profileName}{"name"}         = trim($profileName);
                    $profiles{$profileName}{"commands"}     = [@commands];
                    $profiles{$profileName}{"targets"}     = [@targets];
                    $profiles{$profileName}{"numCommands"}   = $numCommands;
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
            $profiles{$profileName}{"name"}         = $profileName;
            $profiles{$profileName}{"commands"}     = [@commands];
            $profiles{$profileName}{"targets"}     = [@targets];
            $profiles{$profileName}{"numCommands"}   = $numCommands;
            push @profileNames, $profileName;  # Add to list
        }
        $profileName = "";  
    }
}
close(PREF);
close(PROFILES);

foreach $profileName (@profileNames)
{
    print "   - Profile \"$profiles{$profileName}{name}\"\n";
    print "    + Number of Commands : $profiles{$profileName}{numCommands}\n";
    for ($j=0;$j<($profiles{$profileName}{"numCommands"});$j++)
    {   # targets
    print "      - Command #".($j+1)."        : ".$profiles{$profileName}{"targets"}[$j]."\n";
    if (!($profiles{$profileName}{"targers"}[$j] eq "")) { print "      - Encoder #".($j+1)."        : ".$profiles{$profileName}{"commands"}[$j]."\n"; }
    }
}

# If we create a file or folder, make sure it gets added to this list so it can be cleaned up
@deleteFiles = ($logFile);

for ($i=0;$i<@inputFiles;$i++)
{
    if (-d $inputFiles[$i])
    {   # if its a directory
        @filesToRun = (@filesToRun,scanDir($inputFiles[$i],$findFileRegEx));
    }
    else
    {
        @filesToRun = (@filesToRun,$inputFiles[$i]);
    }
}

foreach $file (@filesToRun)
{
    echoPrint("  + Found File: ($file)\n");
}

foreach $file (@filesToRun)
{
    next if ($file eq ""); # Quick error check
    # Initilizing run
    my %tempGlobalCustomSubStringArray = ();
    %tempGlobalCustomSubStringArray = %globalCustomSubStringArray;
    $tempGlobalCustomSubStringArray{lc("inputFile")} = $file;
    
    foreach (keys %cachedHTML)
    {
        if ($_ !~ /^http/)
        {
            delete $cachedHTML{$_};
        }
    }
    

    if (!exists $tempGlobalCustomSubStringArray{lc(profile)})
    {   # This is prolly just a drag and drop so lets try and handle it
        $tempGlobalCustomSubStringArray{lc("profile")} = "inputFile";  
    }
    echoPrint("------------ Processing file: (".getFile($tempGlobalCustomSubStringArray{lc("inputFile")}).") ----------------\n");
    echoPrint("  + Looking for profile: ".$globalCustomSubStringArray{lc("profile")}."\n");
    @targets = ();
    @commands = ();
    
    # Check for profile in Hash
    unless(exists  $profiles{lc($tempGlobalCustomSubStringArray{lc("profile")})})
    {
        $reason = "Couldn't find encode profile: ".$tempGlobalCustomSubStringArray{lc("profile")};
        die $reason;    
    }
    $profile = $profiles{lc($tempGlobalCustomSubStringArray{lc("profile")})};

    # Pull out Profile information
    $videoIndex = 0;
    $usingProfile    = $profiles{lc($tempGlobalCustomSubStringArray{lc("profile")})}{"name"};
    $numCommands     = $profiles{lc($tempGlobalCustomSubStringArray{lc("profile")})}{"numCommands"};
    for ($j=0;$j<$numCommands;$j++)
    {   # targets
        push @targets,  $profiles{lc($tempGlobalCustomSubStringArray{lc("profile")})}{"targets"}[$j];
        push @commands, $profiles{lc($tempGlobalCustomSubStringArray{lc("profile")})}{"commands"}[$j];
    }
    @usingTargets      = @targets;
    @usingCommands     = @commands;
    
    echoPrint("    - Found \"$usingProfile\"\n");
    print "      + Number of Commands : $numCommands\n";
    for ($j=0;$j<$numCommands;$j++)
    {   # targets
    print "      + Target  #$j        : ".$usingTargets[$j]."\n";
    print "      + Command #$j        : ".$usingCommands[$j]."\n";
    }
    
    $numCommands   = $profiles{lc($tempGlobalCustomSubStringArray{lc("profile")})}{"numCommands"};
    $usingTargets  = [@targets];
    $usingCommands = [@commands];
        
    # Get start time
    ( $startSecond, $startMinute, $startHour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings ) = localtime();
    # Init mainSubStrings hash
    %mainSubStrings = {};
    $mainSubStrings{lc("WORKDIR")}        = $executablePath;
    $mainSubStrings{lc("SAGEDIR")}        = $executablePath;
    
    echoPrint("  + Number of Operations : $numCommands\n");
    echoPrint("  + Using Options\n");
    while( my ($key, $value) = each %tempGlobalCustomSubStringArray ) {
        print "    - $key($value)\n";
    }
    $encodeCLI = 0;
    while($numCommands > 0)
    {           
        # shift off first command
        $currentTarget = shift(@usingTargets);
        $currentCommand = shift(@usingCommands);
        $numCommands--;
                    
        echoPrint("\n    - Remaining Commands ($numCommands): ($currentCommand)\n");
        $n=0;
        #foreach $encoder (@usingTargets)
        #{ For debugging
        #    print "      + ($n) $encoder\n";
        #    $n++;
        #}
        # Replacing snippits
        
        # Parseing Parameters
        $currentTargetOrig  = $currentTarget;
        $currentCommandOrig = $currentCommand;
        while($currentCommand =~ /%%SNIP:([^%]*)%%/i)
        {
            $snippitName = $1;
            $snipToReplace = $&;
            $currentCommand =~ s#\Q$snipToReplace\E#$profiles{lc($snippitName)}{"targets"}[0]#g;
            print "      + Replacing snippit $snippitName : $currentCommand\n";
        }
        $currentCommand     = processCondLine($currentCommand,
                                              \%tempGlobalCustomSubStringArray,
                                              \%tempGlobalCustomSubStringArray,
                                              \%mainSubStrings);
        $currentCommand = substituteStrings($currentCommand,
                                            \%tempGlobalCustomSubStringArray,
                                            \%tempGlobalCustomSubStringArray,
                                            \%mainSubStrings);
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
                        $currentCommand{lc($key)} = $tempGlobalCustomSubStringArray{lc($1)};
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
              $preLogTxt .= "        ! couldn't understand ($currentCommand[0]), throwing it away\n";
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
                                      \%tempGlobalCustomSubStringArray,
                                      \%tempGlobalCustomSubStringArray,
                                      \%mainSubStrings);
    
    
        # Relace substitution strings
        $subStringCurrentTarget = $currentTarget;
        $currentTarget = substituteStrings($currentTarget,
                                        \%tempGlobalCustomSubStringArray,
                                        \%tempGlobalCustomSubStringArray,
                                        \%mainSubStrings);
                                                
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
                if ($currentTarget =~ m#http:(\\\\|\/\/)([^\\\/]*)#)
                {
                    $serverIP = $2;
                    echoPrint("        - Adding Credientials: ".$currentCommand{lc("user")}."\@$serverIP\n");
                    $ua->credentials(  # add this to our $browser 's "key ring"
                      $serverIP.':8080',
                      '',
                      $currentCommand{lc("user")} => $currentCommand{lc("password")}
                    );
                    $ua->credentials(  # add this to our $browser 's "key ring"
                      $serverIP.':8080',
                      '',
                      $currentCommand{lc("user")} => $currentCommand{lc("password")}
                    );
                }      
            }
            
            
            if (exists $currentCommand{lc("insertFunction")})
            {   # Insert function        
                if (exists $profiles{lc($currentTarget)})
                {
                    print "        - Found function profile ($currentTarget)\n";
                    print "        - Adding $profiles{lc($currentTarget)}{numCommands} targets\n";
                    $numCommands += $profiles{lc($currentTarget)}{"numCommands"}; 
                    for ($j=$profiles{lc($currentTarget)}{"numCommands"}-1;$j>=0;$j--)
                    {
                        unshift(@usingTargets,$profiles{lc($currentTarget)}{"targets"}[$j]);
                        unshift(@usingCommands,$profiles{lc($currentTarget)}{"commands"}[$j]);
                    }   
                }
                else
                {
                    print "        ! Couldn't find function profile ($currentTarget)\n";                      
                }
            }
            if (exists $currentCommand{lc("setOptions")})
            {   # Insert function        
                @newOptions= splitWithQuotes($currentTarget," ");
                while (@newOptions != 0)
                {
                    if ($newOptions[0] =~ m#/([a-zA-Z0-9_]+)#i)
                    {   # Generic add sub string
                        print "        - Adding to command parameter hash \n";
                        $newOptions[0] =~ m#/([a-zA-Z0-9_]+)#i;
                        $key = $1;
                        print "          + Key: $key\n";
                        $tempGlobalCustomSubStringArray{lc($key)} = "";   
                        if (!($newOptions[1] =~ m#^/# || $newOptions[1] eq "") || $newOptions[1] =~ m#^/.*/# )
                        {   # If the next parameter data for switch
                            $tempGlobalCustomSubStringArray{lc($key)} = $newOptions[1];
                            print "          + Value: $tempGlobalCustomSubStringArray{lc($key)}\n";
                            shift(@newOptions);    # Remove next parameter also
                        }
                        shift(@newOptions);      
                    }
                    else
                    {
                      $preLogTxt .= "        ! couldn't understand ($newOptions[0]), throwing it away\n";
                      shift(@newOptions);  
                    }
                }           
            }
            elsif (exists $currentCommand{lc("exe")})
            {   # Insert function
                if (-s "$profileFolder\\".$currentCommand{lc("exe")})
                {
                    $runCommand = "\"$profileFolder\\".$currentCommand{lc("exe")}."\" $currentTarget";
                }
                else
                {   # assume its a system command and try and run it anyway
                    $runCommand = $currentCommand{lc("exe")}." $currentTarget";
                }
                echoPrint("        - Executing command: $runCommand\n");
                $runCommand = encode('ISO-8859-1',$runCommand);
                system($runCommand);
            }          
            elsif (exists $currentCommand{lc("die")})
            {   # Die, for debugging      
                die;
            }
            elsif (exists $currentCommand{lc("output")})
            {   # Insert function
                $currentTarget = encode('ISO-8859-1',$currentTarget);
                echoPrint("        - Outputing to file ($currentTarget): (".$currentCommand{lc("output")}.")\n");
                $openSuccess = 0;
                if (exists $currentCommand{lc("append")})
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
                    if (open(OUTPUTFORMAT,"$executablePath\\scrapingProfiles\\".$currentCommand{lc("output")}.".output"))
                    {
                        $outputFile = "";
                        while (<OUTPUTFORMAT>)
                        {
                            chomp;
                            $outputLine = $_;
                            $outputLine = processCondLine($outputLine,
                                                          \%tempGlobalCustomSubStringArray,
                                                          \%tempGlobalCustomSubStringArray,
                                                          \%mainSubStrings);
                        
                            $outputLine = substituteStrings($outputLine,
                                                            \%tempGlobalCustomSubStringArray,
                                                            \%tempGlobalCustomSubStringArray,
                                                            \%mainSubStrings);
                            $outputLine =~ s/\s*$//;
                            $outputFile .= "$outputLine\n";
                        }
                        print OUTPUTTOFILE "$outputFile";
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
            elsif (exists $currentCommand{lc("branch")})
            {   # Insert function
                if (exists $profiles{lc($currentTarget)})
                {
                    print "        - Found function profile ($currentTarget)\n";
                    print "        - Branching to $profiles{lc($currentTarget)}{numCommands} targets\n";
                    $numCommands = $profiles{lc($currentTarget)}{"numCommands"};
                    @usingTargets = ();
                    @usingCommands = ();
                    for ($j=$profiles{lc($currentTarget)}{"numCommands"}-1;$j>=0;$j--)
                    {
                        unshift(@usingTargets,$profiles{lc($currentTarget)}{"targets"}[$j]);
                        unshift(@usingCommands,$profiles{lc($currentTarget)}{"commands"}[$j]);
                    }
                }
                else
                {
                    print "        ! Couldn't find function profile ($currentTarget)\n";
                }
            }
            elsif (exists $currentCommand{lc("break")})
            {   # Be done!
                $numCommands = 0;
                @usingTargets = ();
                @usingCommands = ();
            }
            elsif (exists $currentCommand{lc("setOptions")})
            {   # Pull out per video CLI options from profile
                @perVideoCLI = split( /<\&>/,  $currentTarget);
                print "        - Parsing per video options from Profile File\n"; 
                while (@perVideoCLI != 0)
                {
                    if ($perVideoCLI[0] =~ m#/ERROR$#)
                    {   # Message from profile that an unrecoverable error has occured   
                        $reason = "Error reported from profile file: $perVideoCLI[1]";
                        die $reason;
                    }             
                    elsif ($perVideoCLI[0] =~ m#/([a-zA-Z0-9_]+)#i)
                    {   # Generic add sub string
                        print "        + Found Option ($perVideoCLI[0])\n";
                        print "          - Adding to custom switch hash \n";
                        $perVideoCLI[0] =~ m#/([a-zA-Z0-9_]+)#i;
                        $key = $1;
                        print "            + Key: $key\n";
                        $tempGlobalCustomSubStringArray{lc($key)} = 1;   
                        if (!($perVideoCLI[1] =~ m#^[/%]# || $perVideoCLI[1] eq ""))
                        {   # If the next parameter data for switch
                            $tempGlobalCustomSubStringArray{lc($key)} = $perVideoCLI[1];
                            print "            + Value: $tempGlobalCustomSubStringArray{lc($key)}\n";
                            shift(@perVideoCLI);    # Remove next parameter also
                        } 
                    }
                    elsif ($perVideoCLI[0] =~ m#%([a-zA-Z0-9_]+)#i)
                    {   # Generic add sub string
                        print "        + Found Option ($perVideoCLI[0])\n";
                        print "          - Removing custom switch from hash \n";
                        $perVideoCLI[0] =~ m#!([a-zA-Z0-9_]+)#i;
                        $key = $1;
                        print "            + Key: $key\n";
                        delete $tempGlobalCustomSubStringArray{lc($key)};
                    }
                    else
                    {
                        print "        !  couldn't understand ($perVideoCLI[0]), throwing it away\n";
                    }
                    shift(@perVideoCLI); 
                }
            }
            elsif (exists $currentCommand{lc("get")})
            {    
                $url = URI->new(encode('UTF-8', $currentTarget));
                $currentCommand{lc("get")} =~ s/\$//g;
                if (!exists $cachedHTML{lc("$currentTarget")})
                {   
                    my $response = $ua->get($url);
                    echoPrint("      + Requesting WebAddress: $url\n");
                    $requestSuccess = 0;
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
                        $content = decode('UTF-8', $response->content);
                        while($content =~ /&#([0-9]+);/) 
                        { $content = $`.chr($1) .$'; }                       
                        $cachedHTML{lc($currentCommand{lc("get")})} = $content;
                        $cachedHTML{lc("$currentTarget")}           = $content;
                        echoPrint(" Success: ".$response->status_line."\n");
                    }
                    else
                    {
                        echoPrint(" Failure: ".$response->status_line."\n");
                    }  
                    sleep(1);
                    
                    if ($tempGlobalCustomSubStringArray{lc("saveHTML")})
                    {
                        open(WRITEHTML,">$executablePath\\".$currentCommand{lc("get")}.".".getFile($tempGlobalCustomSubStringArray{lc("inputFile")}).".html");
                        print WRITEHTML $cachedHTML{lc($currentCommand{lc("get")})};
                        close(WRITEHTML);  
                    }
                }
                else
                {
                    $cachedHTML{lc($currentCommand{lc("get")})} = $cachedHTML{lc("$currentTarget")};
                }
            }
            elsif (exists $currentCommand{lc("use")})
            {
                if (exists $cachedHTML{lc($currentCommand{lc("use")})})
                {
                    $text = $cachedHTML{lc($currentCommand{lc("use")})};
                    @text = split(/(\n|\r)/,$text);
                }
                elsif (exists $tempGlobalCustomSubStringArray{lc($currentCommand{lc("use")})})
                {
                    $text = $tempGlobalCustomSubStringArray{lc($currentCommand{lc("use")})};
                    @text = split(/(\n|\r)/,$text);
                }
                elsif (-s $currentCommand{lc("use")} && exists $currentCommand{lc("readFile")})
                {
                    open(READIN,$currentCommand{lc("use")});
                    @text = <READIN>;
                    $text = "@text";
                }
                else
                {
                    $text = $currentCommand{lc("use")};
                    @text = split(/(\n|\r)/,$text);
                }
                
                $success = 0;
                if (exists $currentCommand{lc("flatten")})
                {
                    $text =~ s/(\n|\r)//g;
                }
    
                if (exists $currentCommand{lc("ignoreIlligalWinChars")})
                {
                    $text =~ s/(\\|\/|:|\*|\?)//g;
                }
    
                $splitter = "||";
                if (exists $currentCommand{lc("split")})
                {
                    $splitter = $currentCommand{lc("split")};
                }
                
                if (exists $currentCommand{lc("debug")})
                { 
                    echoPrint("!!! DEBUGING !!!\\n");
                    while (!($inputRegEx =~ /done/))
                    {
                        $currentTarget = $inputRegEx;
                        $text =~ /$currentTarget/i;
                        $capture = $&;
                        echoPrint("!  * $currentTarget =~ $capture\n");
                        $| = 1;
                        echoPrint("New RegEX - ");
                        $inputRegEx = <STDIN>;
                        chomp $inputRegEx
                    }
                }
                
                if (!(exists $currentCommand{lc("multiple")}))
                {
                    if ($text =~ /$currentTarget/i)
                    {
                        $before = $`;
                        $match = $&;
                        $after = $';
                        echoPrint("      + Success\n");
                        echoPrint("        - [$&]\n");
                        $tempGlobalCustomSubStringArray{lc("forEachRemainder")} = $';
                        for ($i=0;$i<@regEXCapture;$i++)
                        {
                            $regExResult = ($i + 1);
                            if (!(exists $currentCommand{lc("noOverWrite")} && $tempGlobalCustomSubStringArray{lc($regEXCapture[$i])}) &&
                                !($$regExResult eq ""))
                            {
                                $tempGlobalCustomSubStringArray{lc($regEXCapture[$i])} = trim($$regExResult);
                                $success = 1;
                            }
                        }
                        if(!@regEXCapture) { $success = 1 };
                        
                    }
                }
                else
                {
                    $addedVariable = 0;
                    for ($i=0;$i<@regEXCapture;$i++)
                    {   # Clear out variables
                        $regExResult = ($i + 1);
                        $tempGlobalCustomSubStringArray{lc($regEXCapture[$i])} = "";
                    }
                    while ($text =~ /$currentTarget/i)
                    {
                        $before = $`;
                        $match = $&;
                        $after = $';
                        $text = $';
                        if (exists $currentCommand{lc("format")})
                        {
                            for ($i=0;$i<@regEXCapture;$i++)
                            {
                                $regExResult = ($i + 1);
                                $replacements{lc($regEXCapture[$i])} = $$regExResult;
                                $tempGlobalCustomSubStringArray{lc($regEXCapture[$i])} .= trim($$regExResult);
                                $tempGlobalCustomSubStringArray{lc($regEXCapture[$i])} .= $splitter;
                            }
                            $outputLine = $currentCommand{lc("format")};
                            while ($outputLine =~ /\$\$([^\$]*)\$\$/)
                            {
                                $outputLine = $`.$replacements{lc($1)}.$';
                            }
    
                            if (exists $currentCommand{lc("variable")})
                            {
                                $tempGlobalCustomSubStringArray{lc($currentCommand{lc("variable")})} .= $outputLine.$splitter;
                            }
                            else
                            {
                                $tempGlobalCustomSubStringArray{lc($regEXCapture[0])} .= $outputLine.$splitter;
                            }    
                            $success++;             
                        }
                        else
                        {
                            for ($i=0;$i<@regEXCapture;$i++)
                            {
                                $regExResult = ($i + 1);
                                $tempGlobalCustomSubStringArray{lc($regEXCapture[$i])} .= trim($$regExResult);
                                $tempGlobalCustomSubStringArray{lc($regEXCapture[$i])} .= $splitter;
                            }
                            $success++;
                        }          
                    }
                }
                
                if ($success)
                {
                    $tempGlobalCustomSubStringArray{lc("forEachRemainder")} = $after;
                    echoPrint("      + Success ($success)\n");
                    
                    foreach $thing (("variable","removeMatch","captureBefore","captureAfter"))
                    {
                        if (exists $currentCommand{lc($thing)})
                        {
                            $currentCommand{lc($thing)} =~ s/\$//g;
                            push @regEXCapture,$currentCommand{lc($thing)};
                        }
                    }
                    
                    if (exists $currentCommand{lc("removeMatch")})
                    {
                        $currentCommand{lc("removeMatch")} =~ s/\$//g;
                        $tempGlobalCustomSubStringArray{lc($currentCommand{lc("removeMatch")})} = $before.$after;
                    }
                    
                    if (exists $currentCommand{lc("captureBefore")})
                    {
                        $currentCommand{lc("captureBefore")} =~ s/\$//g;
                        $tempGlobalCustomSubStringArray{lc($currentCommand{lc("captureBefore")})} = $before;
                    }
                    
                    if (exists $currentCommand{lc("captureAfter")})
                    {
                        $currentCommand{lc("captureAfter")} =~ s/\$//g;
                        $tempGlobalCustomSubStringArray{lc($currentCommand{lc("captureAfter")})} = $after;
                    }
                                  
                    for ($i=0;$i<@regEXCapture;$i++)
                    {
                        echoPrint("        - \$\$$regEXCapture[$i]\$\$ = (".$tempGlobalCustomSubStringArray{lc($regEXCapture[$i])}.")\n");
                    } 
                }
                
                if (exists $currentCommand{lc("foreach")})
                {
                    if ($tempGlobalCustomSubStringArray{lc("forEachRemainder")} =~ /$currentTarget/)
                    {  # Insert function then do it again
                        $tempGlobalCustomSubStringArray{lc("forEachRemainderTEMP")} = $tempGlobalCustomSubStringArray{lc("forEachRemainder")};
                        if (exists $profiles{lc($currentCommand{lc("do")})})
                        {
                            $currentCommandOrig =~ s/use [^ ]*/use forEachRemainderTEMP/;
                            print "        - Adding Current Command\n";
                            $numCommands += $profiles{lc($currentCommand{lc("do")})}{"numCommands"}; 
                            for ($j=$profiles{lc($currentCommand{lc("do")})}{"numCommands"}-1;$j>=0;$j--)
                            {
                                unshift(@usingTargets,$currentTargetOrig);
                                unshift(@usingCommands,$currentCommandOrig);
                            }  
    
                            print "        - Adding foreach function profile (".lc($currentCommand{lc("do")}).")\n";
                            print "        - Adding ".$profiles{lc(lc($currentCommand{lc("do")}))}{numCommands}." targets\n";
                            $numCommands += $profiles{lc($currentCommand{lc("do")})}{"numCommands"}; 
                            for ($j=$profiles{lc($currentCommand{lc("do")})}{"numCommands"}-1;$j>=0;$j--)
                            {
                                unshift(@usingTargets,$profiles{lc($currentCommand{lc("do")})}{"targets"}[$j]);
                                unshift(@usingCommands,$profiles{lc($currentCommand{lc("do")})}{"commands"}[$j])
                            }   
                        }
                        else
                        {
                            print "        ! Couldn't find function profile ($currentTarget)\n";                      
                        }                              
                    }
                }  
    
                if ($success == 0)
                {
                    echoPrint("      ! Failure\n");
                    if (exists $currentCommand{lc("clearOnFailure")})
                    {
                        for ($i=0;$i<@regEXCapture;$i++)
                        {
                            echoPrint("        - Clearing \$\$$regEXCapture[$i]\$\$\n");
                            delete $tempGlobalCustomSubStringArray{lc($regEXCapture[$i])};
                        }                    
                    }
                }
            }
        }
        else
        {
            echoPrint("      + Command Empty, Skipping: \"$currentTarget\"\n");
        }
    }
}



sub runCommand
{
    my ( $command, $action ) = @_;
    print "$action: $command\n";
    `$command`;
}

sub getExt
{
    my ( $fileName ) = @_;
    my $rv = "";
    if ($fileName =~ m#(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#)
    {
        $rv = $3;
    }
    return $rv;
}

sub getDriveLetter
{
    my ( $fileName ) = @_;
    my $rv = "";
    if ($fileName =~ /([a-zA-Z]:|\\\\)/)
    {
        $rv = $&;
    }
    return $rv;
}

sub getFullFile
{
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
{
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
{
    my ( $fileName ) = @_;
    my $rv = "";
    if ($fileName =~ m#([^\\/]*)$#)
    {
        $rv = $&;
    }

    return $rv;
}

sub getPath
{
    my ( $fileName ) = @_;
    my $rv = "";
    if ($fileName =~ m#([^\\/]*)$#)
    {
        $rv = $`;
    }
  
    $rv =~ s#(\\|/)$##;
    return $rv;
}

sub nOrderEQ
{
    my ( $X, @coefs ) = @_;
    my ($result) = 0;
    my ($n)      = 0;
    my ($length) = scalar @coefs;
    #print "Result = ";
    for ( $n = 0 ; $n < $length ; $n++ )
    {
        $power = $length - $n - 1;
        #print "$coefs[$n]*$X^$power";
        if ( $n != ( $length - 1 ) )
        {
            #print " + ";
        }
        $result += $coefs[$n] * ( $X**$power );
    }
    #print " = $result\n";
    return $result;
}

sub trim{
   my $string = shift;
   $string =~ s/^\s+|\s+$//g;
   return $string;
}

sub trueOrFalse
{
    my ($value) = @_;
    my $rv = 0;
    if ($value =~ /true/i)
    {
        $rv = 1;
    }
    return $rv;
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

sub reverseSlashes
{
    my ($input) = @_;
    $input =~ s#\\#/#g;   
    return $input;
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

sub processCondLine
{
    my ($currentTarget, $customSubStringArray, 
        $globalCustomSubStringArray, $videoInfoArray, 
        $streamCopy, $mainSubStrings) = @_;        
    my $replaceString = $currentTarget;
        
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
                        $result = checkConditional($check,$text,$customSubStringArray,$globalCustomSubStringArray,$videoInfoArray, $streamCopy, $mainSubStrings);
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
        $customSubStringArray, 
        $globalCustomSubStringArray,
        $mainSubStrings) = @_;
        
    my $condTrue                    = 0;
    my $negate                      = 0;
    my $key                         = "";
    
    # If nessisary do some string substitutions
    $check = substituteStrings($check,
                              $customSubStringArray,
                              $globalCustomSubStringArray,
                              $mainSubStrings);
          
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
        print "            - Does file exist next to orignal video with a (.$1) extention? ($videoInfoArray->{lc($mainSubStrings->{lc(ORIGINAL)})}{fullPath})\n";
        $condTrue = checkProfileCond((((-e "$videoInfoArray->{lc($mainSubStrings->{lc(ORIGINAL)})}{fullPath}.$1" || -e "$videoInfoArray->{lc($mainSubStrings->{lc(ORIGINAL)})}{fullFile}.$1"))?1:0), $negate, $text); 
        $customSubStringArray->{lc("check")} = $1;
    }
    elsif ($check =~ /EXISTS:(.*)/i)
    {
        $checkDirectory = encode('ISO-8859-1' , $1);
        print "            - Does file ($checkDirectory) exist?\n";
        $condTrue = checkProfileCond((((-e "$checkDirectory" || -e $mainSubStrings->{lc("SAGE_DIR")}."\\$checkDirectory" || -e $mainSubStrings->{lc("SAGE_DIR")}."\\tv2pcBins\\$checkDirectory"))?1:0), $negate, $text); 
        $customSubStringArray->{lc("check")} = $checkDirectory;
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
        print "            - Does directory ($checkDirectory) exist?\n";
        $condTrue = checkProfileCond((((-d "$checkDirectory" || -d $mainSubStrings->{lc("SAGE_DIR")}."\\$checkDirectory" || -d $mainSubStrings->{lc("SAGE_DIR")}."\\tv2pcBins\\$checkDirectory"))?1:0), $negate, $text);
        $customSubStringArray->{lc("check")} = $checkDirectory;
    }
    elsif ($check =~ /(.*)(=eq=|=~|>|<|>=|<=|==)(.*)/i)
    {   # Checking videoInfo hash
        $customSubStringArray->{lc("right")} = $3;
        $lowerCase = lc($3);
        $meathod = $2;
        $checkValue = $1;

        print "            - Does ($checkValue) $meathod ($lowerCase)?\n";

        $customSubStringArray->{lc("left")} = $checkValue;
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
        
        if ($key eq "" || exists $videoInfoArray->{$fileKey}{"$key"})
        {
            $condTrue = checkProfileCond($condStatment, $negate, $text);
        }
        else
        {
            print "              ! Key not found\n";
            $condTrue = checkProfileCond(0, $negate, $text);
        }
    }
    else
    {   # Else, check for custom conditional  
        print "            - Does custom conditional ($check) exist?\n";
        $condTrue = checkProfileCond(((exists $customSubStringArray->{lc($check)}        || 
                                       exists $globalCustomSubStringArray->{lc($check)}  ||
                                       exists $mainSubStrings->{lc($check)})?1:0), $negate, $text);                             
    }
    return $condTrue;
}

sub substituteStrings
{
    my( $currentTarget,
        $customSubStringArray,
        $globalCustomSubStringArray,
        $mainSubStrings) = @_;     
                    
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

        if (exists  $globalCustomSubStringArray->{lc($subString)})
        {   # Then Check the global hash
            $replaceString = $globalCustomSubStringArray->{lc($subString)};
        }

        foreach $meathod (@parseMeathod)
        {   
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
            elsif ($meathod eq "ESCPAR")
            {
                $replaceString =~ s#\(#\\(#g;
                $replaceString =~ s#\)#\\)#g;
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
            #print "        - Replacing: $wholeSubString with ($replaceString)\n";
        }
        print "        - Replacing: $wholeSubString with ($replaceString)\n";
        $currentTarget =~ s/\Q$wholeSubString\E/$replaceString/;
    }   
    return $currentTarget;

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

sub cleanHTMLChars
{
  my ($text) = @_;
  my $temp = $text;
  echoPrint("!!! $translate{233}\n");
  while($text =~ /(&#(\d+|\w+);?)/)
  {
      echoPrint("!!! Found ($&)($2)(".(chr $translate{$2}).")\n");
      $text = $`.(chr $translate{$2}).$';
  }
  return $text;  
}

sub scanDir
{
    my ($inputFile, $fileFilter) = @_;
    my @files = ();
    my @dirs  = ();
    my $file;
    my $dir;
    $inputFile =~ s/\"//g;
    $inputFile =~ s/(\\|\/)$//g;
    echoPrint("  + Scanning Directory: $inputFile\n");
    opendir(SCANDIR,"$inputFile");
    my @filesInDir = readdir(SCANDIR);
    if (!(-e "$inputFile\\$file\\mediaScraper.skip"))
    {
        foreach $file (@filesInDir)
        {
            #echoPrint("-> $file\n");
            next if ($file =~ m/^\./);
            next if !($file =~ m/($fileFilter)$/ || -d "$inputFile\\$file");       
            if (-d "$inputFile\\$file" && !($file =~ m/($fileFilter)$/)) { push(@dirs,"$inputFile\\$file"); }
            else { push(@files,"$inputFile\\$file"); } 
        }
        foreach $dir (@dirs)
        {
            @files = (@files,scanDir($dir,$fileFilter));     
        }
    }
    else
    {
        echoPrint("    - Found .skip, ignoring Directory\n");
    }
    #echoPrint("!!! @files\n");
    return @files;  
}

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
    



