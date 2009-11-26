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

    # Get the directory the script is being called from
    $executable = $0;
    $executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;;
    $executablePath = $`;
    $executableEXE  = $3; 
    
    # Move arguments into user array so we can modify it
    my @parameters = @ARGV;
    
    foreach (@parameters)
    {
        push (@quotedParameters, "\"$_\"")
    }
    
    # Read default options from file
    $optionsFile = (-s "$executablePath\\$executableEXE.defaults.secret.txt") ? "$executablePath\\$executableEXE.defaults.secret.txt" : "$executablePath\\$executableEXE.defaults.txt";
    open(DEFAULTS,$optionsFile);
    $defaultsOptions = <DEFAULTS>; 
    close(DEFAULTS);
    
    $optionsForEngine = "$defaultsOptions /$executableEXE fixBug @quotedParameters";
    
    if ($executable =~ /\.pl$/)
    {
        $mediaEngine = "$executablePath\\mediaEngine.pl"
    }
    else
    {
        $mediaEngine = "$executablePath\\mediaEngine.exe"
    }
    system("\"$mediaEngine\" $optionsForEngine");

