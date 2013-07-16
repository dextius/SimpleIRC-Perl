#!/usr/bin/env perl

use strict;
use Data::Dumper;
use IO::Socket::INET;
use IO::Select;
use POSIX qw(strftime);

$| = 1; # disable buffering

my $sel    = new IO::Select(); # instantiate our select object
my $listen = new IO::Socket::INET(
    Listen    => 50,   # how many sockets do we want to queue up?
    LocalPort => 9432, # what port do we want to listen on?
    ReuseAddr => 1,    # Without this turned on, restarting is a pain as Unix won't let go of the port for a bit
    Proto => 'tcp',    # UDP is way more fun :(
);

$sel->add($listen); # add our listen socket to our select object

my ( %logged_in ); # A couple structures to hold our names and what sockets are connected (could have used IO::Select here)

sub add_socket {
    my $handle = shift;
    my $new_sock = $handle->accept(); # Accept returns a new socket
    $sel->add($new_sock);             # We'll go ahead and add that socket to our select loop
}

sub remove_socket {
    my $sock = shift;
    delete($logged_in{$sock});                # Remove the name mapping in logged_in
    $sel->remove($sock);                      # now it's time to remove the socket from the select object
    $sock->close();                           # and we'll close the socket to be polite
}

sub publish {
    my $sender = shift;
    my $msg = shift;
    my $date = strftime("%H:%M/%S", localtime);
    foreach my $sock ( $sel->handles() ) {
        next if ( $sock == $listen );                                  # don't send to the listen socket!
        $sock->send(sprintf("%s - %10s: %s\n", $date, $sender, $msg)); # write out our message to friends
    }
}

while ( 1 ) {
    foreach my $handle ( $sel->can_read(1) ) {
        if ( $handle == $listen ) { # listen socket has a bite!
            &add_socket($handle); # Connect and add it to our list of connected sockets
        } else { # Hmm, an already connected socket then
            my $data;
            $handle->recv($data, 2048); # Read data from the socket (2048 is in bytes)
            $data =~ s/[\r\n]//g;       # strip off the carriage return / newline

            if ( not $data ) {
                &remove_socket($handle); # Remove the socket from our list of connected sockets
            } else {
                if ( $logged_in{$handle} ) {
                    &publish($logged_in{$handle}, $data); # publish message to our connected sockets
                } else {
                    if ( my ( $name ) = $data =~ /^name=(.{1,12})$/ ) { # So, look for a 12 char or under name
                        $logged_in{$handle} = $name; # use the scalar representation of the connected handle as the key of our hash, holding the name
                        $handle->send("Welcome: $name!\n");
                    } else {
                        eval {
                            $handle->send("Please login with 'name=NAME' (12 char limit)\n"); # send authorization string
                        };
                        warn "Error: $@, data=|$data|\n" if ( $@ );
                    }
                }
            }
        }
    }
}
