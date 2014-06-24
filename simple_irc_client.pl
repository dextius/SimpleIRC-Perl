#!/usr/bin/env perl

use strict;
use Data::Dumper;
use IO::Socket::INET;
use IO::Select;

$| = 1;

my $sel  = new IO::Select();     # Define the select object
my $sock = new IO::Socket::INET( # Define the socket connection
    PeerPort => 9432,
    PeerAddr => 'localhost',
) or die("Could not conect to server! $!");

$sel->add($sock);   # add our socket to the select object (messages from the socket will be received here)
$sel->add(\*STDIN); # add the stdin typeglob to the select object! (listen for user input from the keyboard)

while ( 1 ) {
    foreach my $handle ( $sel->can_read(1) ) { # let's read some data from our socket
        my $data;
        if ( $handle == \*STDIN ) {          # Oh, data from the command line, that's nice
            $data = readline($handle);       # read the data via readline!
            $data =~ s/[\r\n]//g;            # nuke the newline and carraige return
            $sock->send($data) if ( $data ); # Ok, let's send the data now
        } else {
            $handle->recv($data, 2048); # read 2k off the socket
            if ( not $data ) {
                print "Disconnected!\n";
                exit();
            }
            print $data;                # and print it out
        }
    }
}
