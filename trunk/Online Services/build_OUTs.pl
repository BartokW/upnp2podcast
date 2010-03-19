#!/usr/bin/perl -w
# Get the directory the script is being called from
my $executable = $0;
$executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;
my $executablePath = $`;
my $executableEXE  = $3; 

if (@ARGV == 0)
{
    print "No Script!\n";
    exit 0;
}

my $script = $1;
$script =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;
my $scriptPath = $`;
my $scriptEXE  = $3; 


my $cwd  = `pwd`;
my $date = `date`;
`cp "$script" "script.pl"`;
`perl -pi.bak -e "s/SNIP:BUILT/Built on $date/g" "script.pl"`;
`pp -N=Comments="$scriptEXE.out v1.0 by evilpenguin ($date)" -c-o "$scriptEXE.out" "script.pl"`
`del "script.pl"`;
