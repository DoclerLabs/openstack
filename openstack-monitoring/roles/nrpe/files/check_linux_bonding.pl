#!/usr/bin/perl
#
# DESCRIPTION: Nagios plugin for checking the status of bonded network
#              interfaces (masters and slaves) on Linux servers.
#
# AUTHOR: Trond H. Amundsen <t.h.amundsen@usit.uio.no>
#
# Copyright (C) 2009-2014 Trond H. Amundsen
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;
use POSIX qw(isatty);
use Getopt::Long qw(:config no_ignore_case);

# Global (package) variables used throughout the code
use vars qw( $NAME $VERSION $AUTHOR $CONTACT $E_OK $E_WARNING $E_CRITICAL
             $E_UNKNOWN $USAGE $HELP $LICENSE $linebreak $counter $exit_code
             %opt %reverse_exitcode %text2exit %bonding %nagios_level_count
             @perl_warnings @reports @blacklist @ok_reports
          );
#---------------------------------------------------------------------
# Initialization and global variables
#---------------------------------------------------------------------

# Collect perl warnings in an array
$SIG{__WARN__} = sub { push @perl_warnings, [@_]; };

# Version and similar info
$NAME    = 'check_linux_bonding';
$VERSION = '1.4';
$AUTHOR  = 'Trond H. Amundsen';
$CONTACT = 't.h.amundsen@usit.uio.no';

# Exit codes
$E_OK       = 0;
$E_WARNING  = 1;
$E_CRITICAL = 2;
$E_UNKNOWN  = 3;

# Nagios error levels reversed
%reverse_exitcode
  = (
     0 => 'OK',
     1 => 'WARNING',
     2 => 'CRITICAL',
     3 => 'UNKNOWN',
    );

# Usage text
$USAGE = <<"END_USAGE";
Usage: $NAME [OPTION]...
END_USAGE

# Help text
$HELP = <<'END_HELP';

OPTIONS:

   -t, --timeout       Plugin timeout in seconds [5]
   -s, --state         Prefix alerts with alert state
   -S, --short-state   Prefix alerts with alert state abbreviated
   -n, --no-bonding    Alert level if no bonding interfaces found [ok]
   --slave-down        Alert level if a slave is down [warning]
   --disable-sysfs     Don't use sysfs (default), use procfs
   --ignore-num-ad     (IEEE 802.3ad) Don't warn if num_ad_ports != num_slaves
   -b, --blacklist     Blacklist failed interfaces
   -v, --verbose       Debug/Verbose output, reports everything
   -h, --help          Display this help text
   -V, --version       Display version info

For more information and advanced options, see the manual page or URL:
  http://folk.uio.no/trondham/software/check_linux_bonding.html
END_HELP

# Version and license text
$LICENSE = <<"END_LICENSE";
$NAME $VERSION
Copyright (C) 2009-2014 $AUTHOR
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by $AUTHOR <$CONTACT>
END_LICENSE

# Options with default values
%opt
  = ( 'timeout'       => 5,  # default timeout is 5 seconds
      'help'          => 0,
      'version'       => 0,
      'blacklist'     => [],
      'no_bonding'    => 'ok',
      'state'         => 0,
      'shortstate'    => 0,
      'linebreak'     => undef,
      'verbose'       => 0,
      'disable_sysfs' => 0,
      'slave_down'    => 'warning',
      'ignore_num_ad' => 0,
    );

# Get options
GetOptions('t|timeout=i'    => \$opt{timeout},
           'h|help'         => \$opt{help},
           'V|version'      => \$opt{version},
           'b|blacklist=s'  => \@{ $opt{blacklist} },
           'n|no-bonding=s' => \$opt{no_bonding},
           's|state'        => \$opt{state},
           'S|short-state'  => \$opt{shortstate},
           'linebreak=s'    => \$opt{linebreak},
           'v|verbose'      => \$opt{verbose},
           'disable-sysfs'  => \$opt{disable_sysfs},
           'slave-down=s'   => \$opt{slave_down},
           'ignore-num-ad'  => \$opt{ignore_num_ad},
          ) or do { print $USAGE; exit $E_UNKNOWN };

# If user requested help
if ($opt{'help'}) {
    print $USAGE, $HELP;
    exit $E_OK;
}

# If user requested version info
if ($opt{'version'}) {
    print $LICENSE;
    exit $E_OK;
}

# Reports (messages) are gathered in this array
@reports = ();

# Setting timeout
$SIG{ALRM} = sub {
    print "PLUGIN TIMEOUT: $NAME timed out after $opt{timeout} seconds\n";
    exit $E_UNKNOWN;
};
alarm $opt{timeout};

# Default line break
$linebreak = isatty(*STDOUT) ? "\n" : '<br/>';

# Line break from option
if (defined $opt{linebreak}) {
    if ($opt{linebreak} eq 'REG') {
        $linebreak = "\n";
    }
    elsif ($opt{linebreak} eq 'HTML') {
        $linebreak = '<br/>';
    }
    else {
        $linebreak = $opt{linebreak};
    }
}

# Blacklisted interfaces
@blacklist = defined $opt{blacklist} ? @{ get_blacklist() } : ();

# Translate text exit codes to values
%text2exit
  = ( 'ok'       => $E_OK,
      'warning'  => $E_WARNING,
      'critical' => $E_CRITICAL,
      'unknown'  => $E_UNKNOWN,
    );

# Check syntax of '--no-bonding' option
if (!exists $text2exit{$opt{no_bonding}}) {
    unknown_error("Wrong usage of '--no-bonding' option: '"
                  . $opt{no_bonding}
                  . "' is not a recognized keyword");
}

# Check syntax of '--slave-down' option
if (!exists $text2exit{$opt{slave_down}}) {
    unknown_error("Wrong usage of '--slave-down' option: '"
                  . $opt{slave_down}
                  . "' is not a recognized keyword");
}

#---------------------------------------------------------------------
# Functions
#---------------------------------------------------------------------

#
# Store a message in the message array
#
sub report {
    my ($msg, $exval) = @_;
    return push @reports, [ $msg, $exval ];
}

#
# Give an error and exit with unknown state
#
sub unknown_error {
    my $msg = shift;
    print "ERROR: $msg\n";
    exit $E_UNKNOWN;
}

#
# Read the blacklist option and return a hash containing the
# blacklisted components
#
sub get_blacklist {
    my @bl = ();
    my @blacklist = ();

    if (scalar @{ $opt{blacklist} } >= 0) {
        foreach my $black (@{ $opt{blacklist} }) {
            my $tmp = q{};
            if (-f $black) {
                open my $BL, '<', $black
                  or do { report('other', "Couldn't open blacklist file $black: $!", $E_UNKNOWN)
                            and return {} };
                chomp($tmp = <$BL>);
                close $BL;
            }
            else {
                $tmp = $black;
            }
            push @bl, $tmp;
        }
    }

    return [] if $#bl < 0;

    # Parse blacklist string, put in hash
    foreach my $black (@bl) {
        push @blacklist, split m{,}xms, $black;
    }

    return \@blacklist;
}

#
# Find bonding interfaces using sysfs
#
sub find_bonding_sysfs {
    my $sysdir       = '/sys/class/net';
    my $masters_file = "$sysdir/bonding_masters";
    my @bonds        = ();
    my %bonding      = ();

    if (! -f $masters_file) {
        return {};
    }

    # get bonding masters
    open my $MASTER, '<', $masters_file
      or unknown_error("Couldn't open $masters_file: $!");
    @bonds = split m{\s+}xms, <$MASTER>;
    close $MASTER;

    foreach my $bond (@bonds) {

        # get bonding mode
        open my $MODE, '<', "$sysdir/$bond/bonding/mode"
          or unknown_error("ERROR: Couldn't open $sysdir/$bond/bonding/mode: $!");
        my ($mode, $nr) = split m/\s+/xms, <$MODE>;
        close $MODE;
        $bonding{$bond}{mode} = "mode=$nr ($mode)";

        # get 802.3ad number of ports
        if ($bonding{$bond}{mode} eq 'mode=4 (802.3ad)') {
            open my $AD_NUM, '<', "$sysdir/$bond/bonding/ad_num_ports"
              or unknown_error("ERROR: Couldn't open $sysdir/$bond/bonding/ad_num_ports: $!");
            my $ad_num = <$AD_NUM>;
            close $AD_NUM;
            $bonding{$bond}{ad_num} = $ad_num;
        }

        # get slaves
        my @slaves = ();
        open my $SLAVES, '<', "$sysdir/$bond/bonding/slaves"
          or unknown_error("Couldn't open $sysdir/$bond/bonding/slaves: $!");
        @slaves = split m/\s+/xms, <$SLAVES>;
        close $SLAVES;

        # get active slave
        open my $ACTIVE, '<', "$sysdir/$bond/bonding/active_slave"
          or unknown_error("Couldn't open $sysdir/$bond/bonding/active_slave: $!");
        $bonding{$bond}{active} = <$ACTIVE>;
        close $ACTIVE;
        if (defined $bonding{$bond}{active}) {
            chop $bonding{$bond}{active};
        }

        # get primary slave
        open my $PRIMARY, '<', "$sysdir/$bond/bonding/primary"
          or unknown_error("Couldn't open $sysdir/$bond/bonding/primary: $!");
        $bonding{$bond}{primary} = <$PRIMARY>;
        close $PRIMARY;
        if (defined $bonding{$bond}{primary}) {
            chop $bonding{$bond}{primary};
        }

        # get slave status
        foreach my $slave (@slaves) {
            my $statefile = -e "$sysdir/$bond/slave_$slave/operstate"
              ? "$sysdir/$bond/slave_$slave/operstate"
                : "$sysdir/$bond/lower_$slave/operstate";
            open my $STATE, '<', "$statefile"
              or unknown_error("Couldn't open $statefile: $!");
            chop($bonding{$bond}{slave}{$slave} = <$STATE>);
            close $STATE;
        }

        # get bond state
        open my $BSTATE, '<', "$sysdir/$bond/operstate"
          or unknown_error("Couldn't open $sysdir/$bond/operstate: $!");
        chop($bonding{$bond}{status} = <$BSTATE>);
        close $BSTATE;
    }

    return \%bonding;
}


#
# Find bonding interfaces using procfs (fallback, deprecated)
#
sub find_bonding_procfs {
    my $procdir = '/proc/net/bonding';
    my @bonds   = ();
    my %bonding = ();

    opendir(my $DIR, $procdir);
    @bonds = grep { m{\A bond\d+ \z}xms && -f "$procdir/$_" } readdir $DIR;
    closedir $DIR;

    if ($#bonds == -1) {
        return {};
    }

    foreach my $b (@bonds) {
        my $slave = undef;
        open my $BOND, '<', "$procdir/$b"
          or unknown_error("Couldn't open $procdir/$b: $!");
        while (<$BOND>) {
            # get bonding mode
            if (m{\A Bonding \s Mode: \s (.+) \z}xms) {
                chop($bonding{$b}{mode} = $1);
            }
            # get 802.3ad number of ports
            elsif (defined $bonding{$b}{mode} and $bonding{$b}{mode} =~ m{802\.3ad}xms
                   and m{\A\s+ Number \s of \s ports: \s (\d+) .*\z}xms) {
                chomp($bonding{$b}{ad_num} = $1);
            }
            # get slave
            elsif (m{\A Slave \s Interface: \s (.+) \z}xms) {
                chop($slave = $1);
            }
            # get slave and bonding status
            elsif (m{\A MII \s Status: \s (.+) \z}xms) {
                if (defined $slave) {
                    chop($bonding{$b}{slave}{$slave} = $1);
                }
                else {
                    chop($bonding{$b}{status} = $1);
                }
            }
            # get primary slave
            elsif (m{\A Primary \s Slave: \s (\S+) .* \z}xms) {
                chomp($bonding{$b}{primary} = $1);
            }
            # get active slave
            elsif (m{\A Currently \s Active \s Slave: \s (.+) \z}xms) {
                chop($bonding{$b}{active} = $1);
            }
        }
    }

    return \%bonding;
}

#
# Find bonding interfaces
#
sub find_bonding {
    my $bonding = undef;

    if ($opt{disable_sysfs}) {
        $bonding = find_bonding_procfs();
    }
    else {
        # first try sysfs
        $bonding = find_bonding_sysfs();

        # second try procfs
        if (scalar keys %{ $bonding } == 0) {
            $bonding = find_bonding_procfs();
        }
    }

    # if no bonding interfaces found, exit
    if (scalar keys %{ $bonding } == 0) {
        print $reverse_exitcode{$text2exit{$opt{no_bonding}}}
          . ": No bonding interfaces found\n";
        exit $text2exit{$opt{no_bonding}};
    }

    return $bonding;
}

#
# Returns true if an interface is blacklisted
#
sub blacklisted {
    return 0 if !defined $opt{blacklist};
    my $if = shift;
    foreach $b (@blacklist) {
        if ($if eq $b) {
            return 1;
        }
    }
    return 0;
}

#=====================================================================
# Main program
#=====================================================================

%bonding = %{ find_bonding() };
MASTER:
foreach my $b (sort keys %bonding) {

    # If the master interface is blacklisted
    if (blacklisted($b)) {
        my $msg = sprintf 'Bonding interface %s [%s] is %s, but IGNORED',
          $b, $bonding{$b}{mode}, $bonding{$b}{status};
        report($msg, $E_OK);
        next MASTER;
    }

    if ($bonding{$b}{status} ne 'up') {
        my $msg = sprintf 'Bonding interface %s [%s] is %s',
          $b, $bonding{$b}{mode}, $bonding{$b}{status};
        report($msg, $E_CRITICAL);
    }
    else {
        my $slaves_are_up = 1; # flag

      SLAVE:
        foreach my $i (sort keys %{ $bonding{$b}{slave} }) {

            # If the slave interface is blacklisted
            if (blacklisted($i)) {
                my $msg = sprintf 'Slave interface %s [member of %s] is %s, but IGNORED',
                  $i, $b, $bonding{$b}{slave}{$i};
                report($msg, $E_OK);
                next SLAVE;
            }

            if ($bonding{$b}{slave}{$i} ne 'up') {
                $slaves_are_up = 0;  # not all slaves are up
                my $msg = sprintf 'Bonding interface %s [%s]: Slave %s is %s',
                  $b, $bonding{$b}{mode}, $i, $bonding{$b}{slave}{$i};
                report($msg, $text2exit{$opt{slave_down}});
            }
        }
        if ($slaves_are_up) {
            my %slave = map { $_ => q{} } keys %{ $bonding{$b}{slave} };
            foreach my $s (keys %slave) {
                if (defined $bonding{$b}{primary} and $bonding{$b}{primary} eq $s) {
                    $slave{$s} .= '*';
                }
                if (defined $bonding{$b}{active} and $bonding{$b}{active} eq $s) {
                    $slave{$s} .= '!';
                }
            }
            if (scalar keys %slave == 1) {
                my @slaves = keys %slave;
                my $msg = sprintf 'Bonding interface %s [%s] has only one slave (%s)',
                  $b, $bonding{$b}{mode}, $slaves[0];
                report($msg, $E_WARNING);
            }
            elsif (scalar keys %slave == 0) {  # FIXME: does this ever happen?
                my $msg = sprintf 'Bonding interface %s [%s] has zero slaves!',
                  $b, $bonding{$b}{mode};
                report($msg, $E_CRITICAL);
            }
            elsif (defined $bonding{$b}{ad_num} and $bonding{$b}{ad_num} != scalar keys %slave
                   and $opt{ignore_num_ad} == 0) {
                my $msg = sprintf 'Bonding interface %s [%s]: Number of AD ports (%d) does not equal the number of slaves (%d)',
                  $b, $bonding{$b}{mode}, $bonding{$b}{ad_num}, scalar keys %slave;
                report($msg, $E_WARNING);
            }
            else {
                my @slaves = map { $_ . $slave{$_} } sort keys %slave;
                my $msg = sprintf 'Interface %s is %s: %s, %d slaves: %s',
                  $b, $bonding{$b}{status}, $bonding{$b}{mode},
                    scalar @slaves, join q{, }, @slaves;
                report($msg, $E_OK);
            }
        }
    }
}

# Counter variable
%nagios_level_count
  = (
     'OK'       => 0,
     'WARNING'  => 0,
     'CRITICAL' => 0,
     'UNKNOWN'  => 0,
    );

# holds only ok messages
@ok_reports = ();

# Reset the WARN signal
$SIG{__WARN__} = 'DEFAULT';

# Print any perl warnings that have occured
if (@perl_warnings) {
    foreach (@perl_warnings) {
        chop @$_;
        report("INTERNAL ERROR: @$_", $E_UNKNOWN);
    }
}

$counter = 0;
ALERT:
foreach (sort {$a->[1] < $b->[1]} @reports) {
    my ($msg, $level) = @{ $_ };
    $nagios_level_count{$reverse_exitcode{$level}}++;

    if ($level == $E_OK && !$opt{verbose}) {
        push @ok_reports, $msg;
        next ALERT;
    }

    # Prefix with nagios level if specified with option '--state'
    $msg = $reverse_exitcode{$level} . ": $msg" if $opt{state};

    # Prefix with one-letter nagios level if specified with option '--short-state'
    $msg = (substr $reverse_exitcode{$level}, 0, 1) . ": $msg" if $opt{shortstate};

    ($counter++ == 0) ? print $msg : print $linebreak, $msg;
}

# Determine our exit code
$exit_code = $E_OK;
if ($nagios_level_count{UNKNOWN} > 0)  { $exit_code = $E_UNKNOWN;  }
if ($nagios_level_count{WARNING} > 0)  { $exit_code = $E_WARNING;  }
if ($nagios_level_count{CRITICAL} > 0) { $exit_code = $E_CRITICAL; }

# Print OK messages
$counter = 0;
if ($exit_code == $E_OK && !$opt{verbose}) {
    foreach my $msg (@ok_reports) {
        # Prefix with nagios level if specified with option '--state'
        $msg = "OK: $msg" if $opt{state};

        # Prefix with one-letter nagios level if specified with option '--short-state'
        $msg = "O: $msg" if $opt{shortstate};

        ($counter++ == 0) ? print $msg : print $linebreak, $msg;
    }
}

print "\n";

# Exit with proper exit code
exit $exit_code;
