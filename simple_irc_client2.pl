#!/usr/bin/env perl

use strict;
use Data::Dumper;
use IO::Socket::INET;
use IO::Select;

$| = 1;

my $sel  = new IO::Select();     # construct our select object
my $sock = new IO::Socket::INET( # Connect to our target server XXX need getopt long to pass stuff in
    PeerPort => 9432,
    PeerAddr => 'localhost',
) or die("Could not connect to server $!");
$sel->add($sock); # Add our new socket to our select object

sub get_data {
    foreach my $handle ( $sel->can_read(.01) ) { # Let's read from our sockets
        my $data;
        $handle->recv($data, 2048); # and read 2k of data from our socket
        if ( not $data ) { # disconnect if we have no data
            print "Disconnected!\n";
            exit();
        }
        print $data; # and print it out
    }
}

while ( 1 ) {
    &get_data();

    local $SIG{ALRM} = sub { # let's redefine sig alarm to go get data!
        &get_data();
        die();
    };
    eval {
        alarm(1);                        # set an alarm for microseconds in the future
        my $data = <STDIN>;              # read from the file handle
        alarm(0);                        # reset the alarm
        $data =~ s/[\r\n]//g;            # nuke the newline and carraige return
        $sock->send($data) if ( $data ); # send the data if any
    };
}
