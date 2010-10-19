##    media???.pl - A wrapper for mediaEngine
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
    # Get the directory the script is being called from
    $executable = $0;
    $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;;
    $executablePath = $`;
    $executableEXE  = $3; 
    $exitCode = 0;
    
    $codeVersion = "$executableEXE v3.0 (SNIP:BUILT)";
    
    if (!(-e "$executablePath\\$executableEXE.bat"))
    {
        if (open(BATFILE,">$executablePath\\$executableEXE.bat"))
        {
            print BATFILE "\@ECHO OFF\n\n";
            print BATFILE "set COMMAND=\n";
            print BATFILE ":LOOP\n";
            print BATFILE "IF (%1)==() GOTO NEXT\n";
            print BATFILE "set COMMAND=%COMMAND% %1\n";
            print BATFILE "shift\n";
            print BATFILE "GOTO LOOP\n\n";
            print BATFILE ":NEXT\n";
            print BATFILE "cd /D \"$executablePath\"\n";
            print BATFILE "start \"MediaShrink\" /B /LOW /WAIT $executableEXE.exe %COMMAND%\n";
            print BATFILE "echo Exit Code = %ERRORLEVEL%\n";
            print BATFILE "exit\n\n"; 
            print BATFILE "REM\nREM\n";
            print BATFILE "REM Some useful command lines I use, you can just copy/rename this file and replace the the above encode command with these for some handy drag and drop encoding\nREM\n";
            print BATFILE "REM Manually select DVD titles to encode\nREM     start \"MediaShrink\" /B /LOW /WAIT $executableEXE.exe %COMMAND% /vbitrate 2000 /twopass /manualTitles /tee\nREM\n";               
            print BATFILE "REM Encode for iPhone\nREM     start \"MediaShrink\" /B /LOW /WAIT $executableEXE.exe %COMMAND% /container mp4 /tee /handbrakeProfile \"iPhone & iPod Touch\" /outputSubFolder \"iPhone\"\nREM\n";   
            print BATFILE "REM Encode for Hardware Player\nREM     start \"MediaShrink\" /B /LOW /WAIT $executableEXE.exe %COMMAND% /container mp4 /tee /handbrakeProfile \"Universal\" /outputSubFolder \"Xbox\"\nREM\n";
            print BATFILE "REM Encode for High Quality Encode\nREM     start \"MediaShrink\" /B /LOW /WAIT $executableEXE.exe %COMMAND% /vbitrate 2500 /vprofile HQ /tee\nREM\n";      
            print BATFILE "REM Encode for Medium Quality Encode\nREM     start \"MediaShrink\" /B /LOW /WAIT $executableEXE.exe %COMMAND% /vbitrate 2500 /tee\nREM\n"; 
            print BATFILE "REM Encode for Low Quality Encode\nREM     start \"MediaShrink\" /B /LOW /WAIT $executableEXE.exe %COMMAND% /vbitrate 2000 /tee\nREM\n";           
            close(BATFILE);
      }
    }
    
    open(USEAGE,"$executablePath\\$executableEXE.readme.txt");
    $usage = "$codeVersion\n";
    while(<USEAGE>)
    {
        $usage .= $_;
    }
    close(USEAGE) ;
    
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
    
    $useAltLaunch = 0;
    foreach (@parameters)
    {
        if (/useAltlaunch/i)
        {
            $useAltLaunch = 1;
            print "  + /useAltLaunch : Using alternative launching method\n";
        }
        else
        {
            push (@quotedParameters, "\"$_\"")
        }
        
    }
    
    
    if (-e "$executablePath\\$executableEXE.defaults.extra.txt")
    {
        open(DEFAULTS,"$executablePath\\$executableEXE.defaults.extra.txt");
        $defaultsOptions .= <DEFAULTS>; 
        close(DEFAULTS);    
    }
    $defaultsOptions .= " ";
    if (-e "$executablePath\\$executableEXE.defaults.txt")
    {
        open(DEFAULTS,"$executablePath\\$executableEXE.defaults.txt");
        $defaultsOptions .= <DEFAULTS>; 
        close(DEFAULTS);    
    }
    
    $optionsForEngine = "$defaultsOptions /$executableEXE fixBug @quotedParameters";
    
    if ($executable =~ /\.pl$/)
    {
        $mediaEngine = "$executablePath\\mediaEngine.pl";
    }
    else
    {
        $mediaEngine = "$executablePath\\mediaEngine.exe";                    
    }

    print " Executing command: \"$mediaEngine\" $optionsForEngine\n";
    system("\"$mediaEngine\" $optionsForEngine");
    $exitcode = 1;
    if (open(EXITCODE,"$executablePath\\mediaEngine.exit"))
    {
        $exitcode = <EXITCODE>;    
    }
    close(EXITCODE); 
    $delString = "del \"$executablePath\\mediaEngine.exit\"";
    `$delString`;


    print "Exiting Code: ($exitcode)\n";
    print "Exiting in 5 seconds...\n";
    sleep(5);
    exit $exitcode; 
    

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

