#!/bin/false

package SackConfig;

use SackUtils;

sub readConf
{
  my $conf=shift;
  my %config;

  if(-e $conf && open(C, $conf))
  {
    while (<C>)
    {
      chomp;
      next if /^\s*$/;  # skip blank lines
      next if /^#/;  # skip comment only lines
      if (/^module\s+(\S+)\s+(\S+)\s*$/)
      {
        $config{module}{$1}=$2;
      }
      elsif (/^remotedir\s+(\S+)\s*$/)
      {
        $config{remotedir}=$1;
        mkdir($config{remotedir}) unless (-d $config{remotedir});
      }
      elsif (/^localname\s+(\S+)\s*$/)
      {
        $config{localname}=$1;
      }
      elsif (/^localalias\s+(\S+)\s*$/)
      {
        $config{localalias}{$1}=1;
      }
      elsif (/^defaultmodules\s+(\S+)\s*$/)
      {
        $config{defaultmodules}{$1}=1;
      }
      elsif (/^local\s+(\S+)\s+(\S+)\s+(.+)\s*$/)
      {
        $config{local}{$1}{$2}=$3;
      }
      else
      {
        SackUtils::warn("unknown stanza $_ - ignoring");
      }
    }
    close C;
  } else {
    SackUtils::warn("Can't open $conf: $!");
  }
  return %config;
}

1;
