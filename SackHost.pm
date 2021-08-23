#!/bin/false

package SackHost;

use SackUtils;
use LWP::Simple;

$current_host='blah';

sub readConfig
{
  ($stanza, $host) = @_;

  while (<main::config>)
  {
    chomp;
    $_ =~ s/#.*//;   # ditch comments
    next if /^\s*$/; # skip blank lines

    if (/^\s*trust\s*\}?\s*$/)
    {
      # only trust if we're looking at the local config
      $SackHost::config{$host}{trust}=1 if ($current_host eq 'localhost');
    }
    elsif (/^\s*cfg\s+(\S+)\s*\}?\s*$/)
    {
      # add to list of configs to pull if looking at trusted host
      if (($current_host eq 'localhost') or 
         ($SackHost::config{$current_host}{trust}==1))
      {
        unless ((defined $SackHost::list{$host})
              or ($host eq $main::global{'localname'}))
        {
          push @main::remotehosts,$host;
          $SackHost::list{$host}=1;
        }
      }
      $SackHost::config{$host}{cfg}=$1;
    }
    else
    {
       SackUtils::warn("Can't parse $_") unless /^\s*\}\s*$/;
    }
    last if /\}/;
  }
}

sub dumpConfig
{
  # doesn't actially make sense for this case
}

sub setCurrentHost
{
  $current_host=shift;
}

sub pullConfig
{
  ($server) = shift;

#SackUtils::warn("loading config from $server");

  $file="$main::global{remotedir}$server\n";
  if ($SackHost::config{$server}{cfg} =~ q!^https?://!)
  {
    $content=LWP::Simple::get($SackHost::config{$server}{cfg});
    if (defined $content)
    {
      if (open (F, ">$file"))
      {
        print F $content;
        close F;
      }
      else
      {
        SackUtils::warn("Can't open file $file: $!");
      }
    }
    else
    {
      SackUtils::warn("Can't get config from $SackHost::config{$server}{cfg}");
    }
  }
  else
  {
    SackUtils::warn("Can't pull config from $SackHost::config{$server}{cfg}");
  }
 
  return $file;
}

#SackUtils::warn("Loading SackHost.pm");
1;
