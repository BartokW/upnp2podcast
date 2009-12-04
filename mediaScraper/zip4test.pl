##    zip4test.pl - A tool to take a snapshot of a directory
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

$pathToUse = $ARGV[0];

# Get the directory the script is being called from
$executable = $0;
$executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;;
$executablePath = $`;

$filesToCatch = "avi|mpg|mkv|mp4|mpeg|VIDEO_TS|ts|ogm|skip|override|mp3|aac|flac|m4a|m4v|mpgts";

if (-d $ARGV[0])
{
    $zip = Archive::Zip->new();
    scanDir($pathToUse,$filesToCatch,$zip);
    $zipingTo = "$executablePath\\".getFile($pathToUse).".zip";
    print "Zipping To: $zipingTo\n";
    $zip->writeToFileNamed($zipingTo);
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
    print "  + Scanning Directory: $inputFile\n";
    opendir(SCANDIR,"$inputFile");
    my @filesInDir = readdir(SCANDIR);
    foreach $file (@filesInDir)
    {
        $path = "$inputFile\\$file";
        $zipPath = $path;
        $zipPath =~ s/\Q$pathToUse\E//g;
        $zipPath =~ s/\\/\//g;
        $zipPath =~ s/\///;
        #echoPrint("-> $file\n");
        next if ($file =~ m/^\./);
        next if !($file =~ m/($fileFilter)$/i || -d "$inputFile\\$file");       
        if (-d "$inputFile\\$file" && !($file =~ m/($fileFilter)$/i)) 
        { 
            push(@dirs,"$path");
            $zipPath .= "/";
            #print "Zipping Path = $zipPath\n";
            #$zip->addDirectory( "$zipPath" );
        }
        else 
        {
            if (-d "$inputFile\\$file")
            {
                $zipPath .= "/foo.vob";
            }
            $zip->addString( '', $zipPath );
            print "Zipping File = $zipPath\n";
            push(@files,"$inputFile\\$file"); 
        } 
    }
    foreach $dir (@dirs)
    {
        @files = (@files,scanDir($dir,$fileFilter));     
    }
    #echoPrint("!!! @files\n");
    return @files;   
}

sub getFile
{
    my ( $fileName ) = @_;
    my $rv = "";
    if (-d $fileName && $fileName =~ m#([^\\/]*)$#)
    {
            $rv = $&;
    }
    return $rv;
}