#!/bin/false

package SackUtils;

# right now this is just print to STDERR... prolly switch to syslog
# or something later.

sub warn
{
  ($msg) = @_;
  print STDERR $msg."\n";
}

sub die
{
  ($msg) = @_;
  print STDERR $msg."\n";
  exit -99;
}

1;
