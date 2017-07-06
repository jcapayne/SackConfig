#!/bin/false

package SackNull;

# this package exists as an easy way for folks to ignore parts of
# the config they don't care about.  Not doing web?  module web null.pm
# no complaints from the parser then ;)

sub readConfig
{
  while (<main::config>)
  { 
    # just read 'til }
    last if /\}/;
  }
}

sub dumpConfig
{
   # do nothing
}


#SackUtils::warn("Loading SackNull.pm");
1;
