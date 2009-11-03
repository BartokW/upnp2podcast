#! /user/bin/perl
use Win32::Process;
use Win32;

# Move arguments into user array so we can modify it
my @parameters = @ARGV;

# Get the directory the script is being called from
my $executable = $0;
$executable =~ m#(\\|\/)(([^\\/]*)\.([a-zA-Z0-9]{2,}))$#;
my $executablePath = $`;
my $executableEXE  = $3; 

$hdhr        = "$executablePath\\hdhomerun_config.exe";
$setChannel  = "hdhomerun_config.exe $parameters[0] set /tuner$parameters[1]/channel auto:";
$setProgram  = "hdhomerun_config.exe $parameters[0] set /tuner$parameters[1]/program ";
$getDebug    = "hdhomerun_config.exe $parameters[0] get /tuner$parameters[1]/debug";
$getPrograms = "hdhomerun_config.exe $parameters[0] get /tuner$parameters[1]/streaminfo";
$saveClip    = "hdhomerun_config.exe $parameters[0] save /tuner$parameters[1]";
$discover    = "hdhomerun_config.exe discover";


if (!(-e $hdhr))
{
    print " Couldn't find hdhomerun_config.exe.  Please run from SiliconDust\HDhomerun\ directory\n";
    exit;
}

if ($parameters[0] eq "")
{
    print " Usage:";
    print "\t$executableEXE <HDHR ID> <tuner # (0 or 1)>\n";
    print "\t  ex:\n";
    print "\t\t$executableEXE 1234567 0\n";
    print "\t\t$executableEXE 1234567 1\n";
    print "\n\tAvailable HDHR:\n\n";
    print `$discover`;
    exit;
}

print "Starting Scan!\n";  

$analog = 0;
$docsis = 0;
$unused = 0;
$hd     = 0;
$sd     = 0;
$hdBandwith = 0;
$sdBandwith = 0;

for ($i=1;$i<39;$i++)
{
    $bitrateArray[$i] = 0;
}

%leftover = ();

$allData = "";

$numBitrateSamples = 30;
$startChannel = 2;
$endChannel   = 135 ;
if (!($parameters[2] eq ""))
{
    $numBitrateSamples = $parameters[2];   
}

if (!($parameters[3] eq ""))
{
    $startChannel = $parameters[3];   
}

if (!($parameters[4] eq ""))
{
    $endChannel = $parameters[4];   
}

for ($channel=$startChannel;$channel<=$endChannel;$channel++)
{
    if ($totalDigBPS != 0)
    {
        $leftover{($channel-1)} = $channelBps - $totalDigBPS;
        print sprintf("    -total: %.2f Mbs (%.2f)\n",$totalDigBPS, $channelBps - $totalDigBPS);
    }
    elsif ($totalDigBPS == 0 && $channelBps != 0)
    {
        $allData .= sprintf("%d,0,0,%.2f,DOCSIS/VOD/VOIP\n",($channel-1),0,$channelBps);
        $docsis++;
    }
    
    `$setChannel$channel`;
    sleep(5);
    $programs = `$getPrograms`;
    $stats = `$getDebug`; 
    $stats =~ /ss=([0-9]+)/;
    $ss = $1;
    $stats =~ /ts:  bps=([0-9]+)/;
    $channelBps = $1;
    $channelBps = $channelBps / (1024 * 1024);
    print sprintf("  + Found Channel: %3d, %3d%, %4.2f Mbs\n",$channel,$ss,$channelBps);
    #print $stats;
    if ($channelBps == 0)
    {
        if ($ss < 70)
        {
            $allData .= sprintf("%d,0,0,0,empty\n",$channel);
            $unused++;
        }
        else
        {
            $allData .= sprintf("%d,0,0,0,analog\n",$channel);
            $analog++;
        }

    } 

    
    @programs = split(/\n/,$programs);
    $totalDigBPS = 0;
    foreach (@programs)
    {
        if (/([0-9]+): (.*)/)
        {
            $programNum = $1;
            $name       = $2;
            `$setProgram $programNum`;
            sleep(5);
            $numAvg = $numBitrateSamples;
            @sum    = ();
            $sum    =  0;
            for ($i=0;$i<$numAvg;$i++)
            {
                $stats = `$getDebug`;       
                $stats =~ /flt: bps=([0-9]+)/;
                $bps   = $1/ (1024*1024);
                push(@sum,$bps);
                #print "      + bps: ".$bps."\n";
                sleep(1); 
            }
            #print $stats;
            @sum = sort(@sum);
            $j = 0;
            #print sprintf("    - %.2f, %.2f, %.2f, %.2f\n",$sum[0],$sum[1],$sum[23],$sum[24]);
            for ($i=2;$i<($numAvg-2);$i++)
            {   # skip highest and lowest
                $sum += $sum[$i];
                $j++
            }
            $programAvgBPS = $sum/$j;
            $totalDigBPS += $programAvgBPS;

            print sprintf("    - %4d, %.2f Mbs, $name\n",$programNum,$programAvgBPS);
            #getClip("$channel-$programNum.ts"); 

            if ($programAvgBPS > 9.5)
            {
                $allData .= sprintf("%d,%d,%.2f,%.2f,QAM HD,$name\n",$channel,$programNum,$programAvgBPS,$channelBps);
                $hd++;
                $hdBandwith += $programAvgBPS;
            }
            else
            {
                $allData .= sprintf("%d,%d,%.2f,%.2f,QAM SD,$name\n",$channel,$programNum,$programAvgBPS,$channelBps);
                $sd++;
                $sdBandwith += $programAvgBPS;
            }
 
            for ($i=1;$i<39;$i++)
            {
                if ($programAvgBPS > ($i-1) && $programAvgBPS < $i)
                {
                    $bitrateArray[$i]++;
                }
            }          
        }
    } 
}

if ($totalDigBPS != 0)
{
    $leftover{($channel-1)} = $channelBps - $totalDigBPS;
    print sprintf("    -total: %.2f Mbs (%.2f)\n",$totalDigBPS, $channelBps - $totalDigBPS);
}
elsif ($totalDigBPS == 0 && $channelBps != 0)
{
    $allData .= sprintf("%d,%d,%.2f,DOCSIS/VOD/VOIP\n",($channel-1),0,$channelBps);
    $docsis++;
}

($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$theTime = sprintf("$month-$dayOfMonth-$year %d.%02d channelScan",$hour,$minute,$second);

open(CSV,">$theTime.csv");
select(CSV);

print "\n--------- All Data ----------\n";
print "Channel,Program,Bitrate,Channel Bitrate,Type\n";
print $allData;

print "\n--------- Number of Channels by Type ----------\n";
print "Analog,$analog\n";
print "Docsis/VOD/Voip,$docsis\n";
print "Empty,$unused\n";
print "SD (<9 Mbs),$sd\n";
print "HD (>9 Mbs),$hd\n\n";

print "\n--------- Channels Bandwidth by Type ----------\n";
print "Analog,".($analog*38)."\n";
print "Docsis/VOD/Voip,".($docsis*38)."\n";
print "Empty,".($unused*38)."\n";
print sprintf("SD (<9 Mbs),%.2f\n",$sdBandwith);
print sprintf("HD (>9 Mbs),%.2f\n\n",$hdBandwith);


print "\n--------- Channel Bandwidth ----------\n";
print "Bitrate Range,Number of Channels\n";
for ($i=1;$i<39;$i++)
{
    print sprintf("%2d-%2d Mbs,$bitrateArray[$i]\n",$i-1,$i);
}

print "\n--------- Leftover Bandwidth by Channel----------\n";
print "Channel,Leftover Bitrate\n";
foreach (sort keys %leftover)
{
    print sprintf("%3d,%.2f\n",$_,$leftover{$_});
}
close(CSV);

exit;

  sub getClip()
  {
    my ($fileName) = @_;
    Win32::Process::Create($processObj,
    $hdhr,
    $saveClip." G:\\Post\\".$fileName,
    0,
    NORMAL_PRIORITY_CLASS,
    ".");
    
    sleep(10);
    $processObj->Kill(0);
  }
