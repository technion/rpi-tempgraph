#!/usr/bin/perl -T
#Basic application to gather data from my Pi and graph it
#technion@lolware.net
#Currently an aplha grade app

use RRDs;

use strict;
use warnings;

$ENV{'PATH'} = '/bin:/usr/bin';
my $ERR;
my $XMLHL;

sub getntp(); #Gathers offset and stratum on NTP server
sub getenv(); #Gathers temp and humidity
sub updategraphs(); #Graphs previous information
sub getload(); #Produces load averages 
sub getmem(); #Gathers memory data
sub getdisk(); #Gathers disk data

open $XMLHL, '>/usr/local/nginx/html/mystats.xml' or die "Unable to create stats file: $!";;

&getload;
&getmem;
&getdisk;

close $XMLHL;

&getntp;
&getenv;
&updategraphs;

sub getntp() {


	my $rv = `/usr/local/bin/ntpq -c rv 2>&1`;

	die "Received error $!" if $?;

	my ($stratum, $offset);

	die "Invalid offset" unless $rv =~ /offset=-?(\d+)/;
	$offset = $1;

	die "Invalid stratum" unless $rv =~ /stratum=(\d+)/;
	$stratum = $1;

	die "Invalid recovered data" if (!defined($offset) || !defined($stratum));

	RRDs::update('/var/graphs/ntp.rrd', "N:$stratum:$offset");
	$ERR=RRDs::error;
	die "ERROR while updating mydemo.rrd: $ERR\n" if $ERR;
}


sub getenv() {

	my ($hum, $temp);

	my $dht = `/usr/bin/sudo /usr/local/bin/loldht 2>&1`;
	die "Received error $!" if $?;

	#Format:
	#Humidity = 58.50 % Temperature = 22.90 *C

	die "Invalid dht" unless $dht =~ /Humidity = (\d+)/;
	$hum = $1;
	die "Invalid dht" unless $dht =~ /Temperature = (\d+)/;
	$temp = $1;

	die "Invalid dht" if (!defined($temp) || !defined($hum));

	RRDs::update('/var/graphs/env.rrd', "N:$hum:$temp");
	$ERR=RRDs::error;
	die "ERROR while updating mydemo.rrd: $ERR\n" if $ERR;
}

sub updategraphs() {


	RRDs::graph('/usr/local/nginx/html/stratum.png', 'DEF:mystratum=/var/graphs/ntp.rrd:stratum:AVERAGE', 'LINE3:mystratum#FF0000:stratum');
	$ERR=RRDs::error;
	die "ERROR while updating stratum.png: $ERR\n" if $ERR;

	RRDs::graph('/usr/local/nginx/html/offset.png', 'DEF:myoffset=/var/graphs/ntp.rrd:offset:AVERAGE', 'LINE3:myoffset#00FF00:offset'); 
	$ERR=RRDs::error;
	die "ERROR while updating offset.png: $ERR\n" if $ERR;

	RRDs::graph('/usr/local/nginx/html/humidity.png', 'DEF:myhum=/var/graphs/env.rrd:humidity:AVERAGE', 'LINE3:myhum#FF0000:humidity');
	$ERR=RRDs::error;
	die "ERROR while updating humidity.png: $ERR\n" if $ERR;

	RRDs::graph('/usr/local/nginx/html/temp.png', 'DEF:mytemp=/var/graphs/env.rrd:temp:AVERAGE', 'LINE3:mytemp#00FF00:temperature');
	$ERR=RRDs::error;
	die "ERROR while updating temp.png: $ERR\n" if $ERR;

}


sub getload() {
	open FH,'</proc/loadavg' or die "Unable to open loadavg $!"; 

	my $line = <FH>;
	die "Invalid loadavg" unless 
		($line =~ /^(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)/) ;
	print $XMLHL "$1 $2 $3\n";

	close FH;
}

sub getmem() {
	
	use Sys::MemInfo qw(totalmem freemem totalswap);

	print $XMLHL "total memory: ".(&totalmem / 1024)."\n";
	print $XMLHL "free memory:  ".(&freemem / 1024)."\n";

	print $XMLHL "total swap: ".(&totalswap / 1024)."\n";
	print $XMLHL "free swap:  ".(Sys::MemInfo::get("freeswap") / 1024)."\n";
}

sub getdisk() {
	use Filesys::Df;

	my $ref = df("/tmp");  # Default output is 1K blocks
	if(defined($ref)) {
	print $XMLHL "Total 1k blocks: $ref->{blocks}\n";
	print $XMLHL "Total 1k blocks free: $ref->{bfree}\n";

	if(exists($ref->{files})) {
		print $XMLHL "Total inodes: $ref->{files}\n"; 
		print $XMLHL "Total inodes free: $ref->{ffree}\n"; 
     }
  }

}

