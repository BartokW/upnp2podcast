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

my $ext = "out";
if (`arch` =~ /64/)
{
   $ext = "64bitOut";
}

my $script = $ARGV[0];
$script =~ m#(\\|\/)?(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;
my $scriptPath = $`;
my $scriptEXE  = $3; 

print "  + Script : ($script)\n";

my $cwd  = `pwd`;
my $date = `date`;
chomp $date;

$cpString = "cp \"$script\" ./script.pl";
print "  + Copying Script : ($cpString)\n";
`$cpString`;
$perlString = "perl -pi.bak -e \"s/SNIP:BUILT/Built on $date/g\" ./script.pl";
print "  + editing temp Script : ($perlString)\n";
`$perlString`;
$ppString = "pp -N=Comments=\"$scriptEXE.$ext v1.0 by evilpenguin ($date)\" -c -M PerlIO.pm -o \"$scriptEXE.$ext\" ./script.pl";
print "  + packing : ($ppString)\n";
`$ppString`;
$delString = "rm ./script.pl";
print "  + Deleting : ($delString)\n";
`$delString`;
