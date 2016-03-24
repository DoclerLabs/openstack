#!/usr/bin/env perl
# vim: se et ts=4:

#
# Copyright (C) 2012, Giacomo Montagner <giacomo@entirelyunlike.net>
#               2015, Yann Fertat, Romain Dessort, Jeff Palmer,
#                     Christophe Drevet-Droguet <dr4ke@dr4ke.net>
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl 5.10.1.
# For more details, see http://dev.perl.org/licenses/artistic.html
#
# This program is distributed in the hope that it will be
# useful, but without any warranty; without even the implied
# warranty of merchantability or fitness for a particular purpose.
#

our $VERSION = "1.1.1";

open(STDERR, ">&STDOUT");

# CHANGELOG:
#   1.0.0   - first release
#   1.0.1   - fixed empty message if all proxies are OK
#   1.0.2   - add perfdata
#   1.0.3   - redirect stderr to stdout
#   1.0.4   - fix undef vars
#   1.0.5   - fix thresholds
#   1.1.0   - support for HTTP interface
#   1.1.1   - drop perl 5.10 requirement

use strict;
use warnings;
use File::Basename qw/basename/;
use IO::Socket::UNIX;
use Getopt::Long;
my $lwp = eval {
    require LWP::Simple;
    LWP::Simple->import;
    1;
};

sub usage {
    my $me = basename $0;
    print <<EOU;
NAME
    $me - check haproxy stats for errors, using UNIX socket interface

SYNOPSIS
    $me [OPTIONS]

DESCRIPTION
    Get haproxy statistics via UNIX socket and parse information searching for errors.

    OPTIONS
    -c, --critical
        Set critical threshold for sessions number (chacks current number of sessions
        against session limit, if enforced) to the specified percentage.
        If no session limit (slim) was specified for the given proxy, this option has
        no effect.

    -d, --dump
        Just dump haproxy stats and exit;

    -h, --help
        Print this message.

    -m, --ignore-maint
        Assume servers in MAINT state to be ok.

    -p, --proxy
        Check only named proxies, not every one. Use comma to separate proxies
        in list.

    -P, --no-proxy
        Do not check named proxies. Use comma to separate proxies in list.

    -s, --sock, --socket
        Use named UNIX socket instead of default (/var/run/haproxy.sock)

    -U, --url
        Use HTTP URL instead of socket. The LWP::Simple perl module is used if
        available. Otherwise, it falls back to using the external command `curl`.

    -u, --user, --username
        Username for the HTTP URL

    -x, --pass, --password
        Password for the HTTP URL

    -w, --warning
        Set warning threshold for sessions number to the specified percentage (see -c)

CHECKS AND OUTPUT
    $me checks every proxy (or the named ones, if -p was given)
    for status. It returns an error if any of the checked FRONTENDs is not OPEN,
    any of the checked BACKENDs is not UP, or any of the checkes servers is not UP;
    $me reports any problem it found.

EXAMPLES
    $me -s /var/spool/haproxy/sock
        Use /var/spool/haproxy/sock to communicate with haproxy.

    $me -p proxy1,proxy2 -w 60 -c 80
        Check only proxies named "proxy1" and "proxy2", and set sessions number
        thresholds to 60% and 80%.

AUTHOR
    Written by Giacomo Montagner

REPORTING BUGS
    Please report any bug to bugs\@entirelyunlike.net

COPYRIGHT
    Copyright (C) 2012 Giacomo Montagner <giacomo\@entirelyunlike.net>.
    $me is distributed under GPL and the Artistic License 2.0

SEE ALSO
    Check out online haproxy documentation at <http://haproxy.1wt.eu/>

EOU
}

my %check_statuses = (
    UNK     => "unknown",
    INI     => "initializing",
    SOCKERR => "socket error",
    L4OK    => "layer 4 check OK",
    L4CON   => "connection error",
    L4TMOUT => "layer 1-4 timeout",
    L6OK    => "layer 6 check OK",
    L6TOUT  => "layer 6 (SSL) timeout",
    L6RSP   => "layer 6 protocol error",
    L7OK    => "layer 7 check OK",
    L7OKC   => "layer 7 conditionally OK",
    L7TOUT  => "layer 7 (HTTP/SMTP) timeout",
    L7RSP   => "layer 7 protocol error",
    L7STS   => "layer 7 status error",
);

my @status_names = (qw/OK WARNING CRITICAL UNKNOWN/);

# Defaults
my $swarn = 80.0;
my $scrit = 90.0;
my $sock  = "/var/run/haproxy.sock";
my $url;
my $user = '';
my $pass = '';
my $dump;
my $ignore_maint;
my $proxy;
my $no_proxy;
my $help;

# Read command line
Getopt::Long::Configure ("bundling");
GetOptions (
    "c|critical=i"      => \$scrit,
    "d|dump"            => \$dump,
    "h|help"            => \$help,
    "m|ignore-maint"    => \$ignore_maint,
    "p|proxy=s"         => \$proxy,
    "P|no-proxy=s"      => \$no_proxy,
    "s|sock|socket=s"   => \$sock,
    "U|url=s"           => \$url,
    "u|user|username=s" => \$user,
    "x|pass|password=s" => \$pass,
    "w|warning=i"       => \$swarn,
);

# Want help?
if ($help) {
    usage;
    exit 3;
}

my $haproxy;
if ($url and $lwp) {
    my $geturl = $url;
    if ($user ne '') {
        $url =~ /^([^:]*:\/\/)(.*)/;
        $geturl = $1.$user.':'.$pass.'@'.$2;
    }
    $geturl .= ';csv';
    $haproxy = get($geturl);
} elsif ($url) {
    my $haproxyio;
    my $getcmd = "curl --insecure -s --fail "
               . "--user '$user:$pass' '".$url.";csv'";
    open $haproxyio, "-|", $getcmd;
    while (<$haproxyio>) {
        $haproxy .= $_;
    }
    close($haproxyio);
} else {
    # Connect to haproxy socket and get stats
    my $haproxyio = new IO::Socket::UNIX (
        Peer => $sock,
        Type => SOCK_STREAM,
    );
    die "Unable to connect to haproxy socket: $sock\n$@" unless $haproxyio;
    print $haproxyio "show stat\n" or die "Print to socket failed: $!";
    $haproxy = '';
    while (<$haproxyio>) {
        $haproxy .= $_;
    }
    close($haproxyio);
}

# Dump stats and exit if requested
if ($dump) {
    print($haproxy);
    exit 0;
}

# Get labels from first output line and map them to their position in the line
my @hastats = ( split /\n/, $haproxy );
my $labels = $hastats[0];
die "Unable to retrieve haproxy stats" unless $labels;
chomp($labels);
$labels =~ s/^# // or die "Data format not supported.";
my @labels = split /,/, $labels;
{
    no strict "refs";
    my $idx = 0;
    map { $$_ = $idx++ } @labels;
}

# Variables I will use from here on:
our $pxname;
our $svname;
our $status;
our $slim;
our $scur;

my @proxies = split ',', $proxy if $proxy;
my @no_proxies = split ',', $no_proxy if $no_proxy;
my $exitcode = 0;
my $msg;
my $checked = 0;
my $perfdata = "";

# Remove excluded proxies from the list if both -p and -P options are
# specified.
my %hash;
@hash{@no_proxies} = undef;
@proxies = grep{ not exists $hash{$_} } @proxies;

foreach (@hastats) {
    chomp;
    next if /^#/;
    next if /^[[:space:]]*$/;
    my @data = split /,/, $_;
    if (@proxies) { next unless grep {$data[$pxname] eq $_} @proxies; };
    if (@no_proxies) { next if grep {$data[$pxname] eq $_} @no_proxies; };

    # Is session limit enforced?
    if ($data[$slim]) {
        $perfdata .= sprintf "%s-%s=%u;%u;%u;0;%u;", $data[$pxname], $data[$svname], $data[$scur], $swarn * $data[$slim] / 100, $scrit * $data[$slim] / 100, $data[$slim];

        # Check current session # against limit
        my $sratio = $data[$scur]/$data[$slim];
        if ($sratio >= $scrit / 100 || $sratio >= $swarn / 100) {
            $exitcode = $sratio >= $scrit / 100 ? 2 :
                $exitcode < 2 ? 1 : $exitcode;
            $msg .= sprintf "%s:%s sessions: %.2f%%; ", $data[$pxname], $data[$svname], $sratio * 100;
        }
    }

    # Check of BACKENDS
    if ($data[$svname] eq 'BACKEND') {
        if ($data[$status] ne 'UP') {
            $msg .= sprintf "BACKEND: %s is %s; ", $data[$pxname], $data[$status];
            $exitcode = 2;
        }
    # Check of FRONTENDS
    } elsif ($data[$svname] eq 'FRONTEND') {
        if ($data[$status] ne 'OPEN') {
            $msg .= sprintf "FRONTEND: %s is %s; ", $data[$pxname], $data[$status];
            $exitcode = 2;
        }
    # Check of servers
    } else {
        if ($data[$status] ne 'UP') {
            next if ($ignore_maint && $data[$status] eq 'MAINT');
            next if $data[$status] eq 'no check';   # Ignore server if no check is configured to be run
            next if $data[$svname] eq 'sock-1';
            $exitcode = 2;
            our $check_status;
            $msg .= sprintf "server: %s:%s is %s", $data[$pxname], $data[$svname], $data[$status];
            $msg .= sprintf " (check status: %s)", $check_statuses{$data[$check_status]} if $check_statuses{$data[$check_status]};
            $msg .= "; ";
        }
    }
    ++$checked;
}

unless ($msg) {
    $msg = @proxies ? sprintf("checked proxies: %s", join ', ', sort @proxies) : "checked $checked proxies.";
}
print "Check haproxy $status_names[$exitcode] - $msg|$perfdata\n";
exit $exitcode;
