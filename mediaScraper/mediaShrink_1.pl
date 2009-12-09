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
    use Encode qw(encode decode);
    use utf8;
    use Win32::Process;
    use Win32;

    # Get the directory the script is being called from
    $executable = $0;
    $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;;
    $executablePath = $`;
    $executableEXE  = $3; 
    
    $codeVersion = "$executableEXE v2.0 (SNIP:BUILT)";
    
    if (!(-e "$executablePath\\$executableEXE.bat"))
    {
        if (open(BATFILE,">$executablePath\\$executableEXE.bat"))
        {
            print BATFILE "\@ECHO OFF\n";
            print BATFILE "\n";
            print BATFILE ":LOOP\n";
            print BATFILE "IF (%1)==() GOTO NEXT\n";
            print BATFILE "set COMMAND=%COMMAND% \"%~f1\"\n";
            print BATFILE "shift\n";
            print BATFILE "GOTO LOOP\n";
            print BATFILE "\n";
            print BATFILE ":NEXT\n";
            print BATFILE "cd /D \"$executablePath\"\n";
            print BATFILE "start /I /B /LOW /WAIT $executableEXE.exe %COMMAND%\n";
            print BATFILE "GOTO EOF\n";
            close(BATFILE);
      }
    }
    
    open(USEAGE,"$executablePath\\mediaShrink.readme.txt");
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
    
    foreach (@parameters)
    {
        push (@quotedParameters, "\"$_\"")
    }
    
    
    if (-e "$executablePath\\mediaShrink.defaults.extra.txt")
    {
        open(DEFAULTS,"$executablePath\\mediaShrink.defaults.extra.txt");
        $defaultsOptions .= <DEFAULTS>; 
        close(DEFAULTS);    
    }
    $defaultsOptions .= " ";
    if (-e "$executablePath\\mediaShrink.defaults.txt")
    {
        open(DEFAULTS,"$executablePath\\mediaShrink.defaults.txt");
        $defaultsOptions .= <DEFAULTS>; 
        close(DEFAULTS);    
    }
    
    $optionsForEngine = "$defaultsOptions /mediaShrink fixBug @quotedParameters";
    
    if ($executable =~ /\.pl$/)
    {
        $mediaEngine = "$executablePath\\mediaEngine.pl";
    }
    else
    {
        $mediaEngine = "$executablePath\\mediaEngine.exe";
    }
    
    print "        - Executing command (new): (\"$mediaEngine\" $optionsForEngine)\n";
    system("\"$mediaEngine\" $optionsForEngine");
    $exitcode  = $? >> 8;
    
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

