#!/bin/false

package BindConfig;

use Net::DNS;

sub test
{
 print "aargh\n\n";
}

sub readConfig
{
  ($stanza, $domain) = @_;

  if ($stanza eq 'dns')
  {
    readConfig_dns($domain);
  }
  elsif ($stanza eq 'acl')
  {
    readConfig_acl($domain)
  }
  else 
  {
    SackUtils::warn("Unknown stanza $domain for BindConfig");
  }
}

sub readConfig_acl
{
  ($aclname) = shift;
  while (<main::config>)
  {
    chomp;
    $_ =~ s/#.*//;   # ditch comments
    next if /^\s*$/; # skip blank lines

    if (/^\s*(permit)\s+(\S+)\s*\}?\s*$/)
    {
    }
    else
    {
       SackUtils::warn("Can't parse $_") unless /^\s*\}\s*$/;
    }
    last if /\}/;
  }
}

sub readConfig_dns
{
  ($domain) = shift;
  while (<main::config>)
  {
    chomp;
    $_ =~ s/#.*//;   # ditch comments
    next if /^\s*$/; # skip blank lines
 
    # lowercase everything
    $_ = lc $_;

    if (/^\s*(master|slave|file|allow-axfr|axfr-from|notify)\s+(\S+)\s*\}?\s*$/)
    {
      if ($1 eq 'file') 
      {
        $BindConfig::config{$domain}{$1}=$2;
      }
      elsif ($1 eq 'master')
      {
        $BindConfig::config{$domain}{$1}=$2;
        # keep a list of nameservers to resolve to IP
        $BindConfig::nameservers{$2}=0;
      }
      elsif ($1 eq 'axfr-from')
      {
        $BindConfig::config{$domain}{$1}=$2;
        # keep a list of nameservers to resolve to IP
        $BindConfig::nameservers{$2}=0;
      }
      else  # slave or allow-axfr or notify
      {
        $BindConfig::config{$domain}{$1}{$2}=1;
        # keep a list of nameservers to resolve to IP
        $BindConfig::nameservers{$2}=0;
      }
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
  $namedconf=$BindConfig::rootdir.$BindConfig::configfile;
print STDERR "opening $namedconf\n";
  open (bindconf, ">$namedconf") or
       SackUtils::die("Can't open $namedconf: $!");

  for $ns (keys %BindConfig::nameservers)
  {
    if ($BindConfig::nameservers{$ns} == 0)
    {
      $res=new Net::DNS::Resolver;
      $query = $res->query($ns, 'A');
      if ($query)
      {
        for $rr ($query->answer)
        {
          next unless $rr->type eq 'A';
          $BindConfig::nameservers{$ns}=$rr->address;
          last;
        }
      }
    }
    if ($BindConfig::nameservers{$ns} == 0)
    {  # try again
      $res=new Net::DNS::Resolver;
      $query = $res->query($ns, 'A');
      if ($query)
      {
        for $rr ($query->answer)
        {
          next unless $rr->type eq 'A';
          $BindConfig::nameservers{$ns}=$rr->address;
          last;
        }
      }
     if ($BindConfig::nameservers{$ns} == 0)
     {
       SackUtils::warn("Can't resolve nameserver $ns");
       $BindConfig::nameservers{$ns}="127.0.0.2"; # put something other than 0
     }
    }
  }
 
  for $zone (keys %BindConfig::config)
  {
    $zonetype='unknown';
    if (($BindConfig::config{$zone}{master} eq $main::global{localname}) or
        ($main::global{localalias}{$BindConfig::config{$zone}{master}}==1))
    {
      $zonetype='master';
    }
    else
    {
      for $ns (keys %{$BindConfig::config{$zone}{slave}})
      {
        if (($ns eq $main::global{localname}) or
            ($main::global{localalias}{$ns}==1))
        {
          $zonetype='slave';
          last;
        }
      }
      if ($zonetype eq 'unknown')
      {
#        SackUtils::warn("Skipping non relevant zone $zone");
        next;
      }
    }

    $BindConfig::config{$zone}{file} = $zone unless ($BindConfig::config{$zone}{file});
print STDERR "adding $zone\n";
    print bindconf 'zone "'.$zone.'" {'."\n";
    print bindconf '  type '.$zonetype.";\n";
    if ($zonetype eq 'slave')
    {
      print bindconf '  file "'.
           $BindConfig::secondarydir.$BindConfig::config{$zone}{file}."\";\n";
      print bindconf '  masters {'."\n";
      print bindconf '    '.
            $BindConfig::nameservers{$BindConfig::config{$zone}{'axfr-from'}}.
            '; /* axfr-from - '.$BindConfig::config{$zone}{'axfr-from'}.' */'.
            "\n" if ($BindConfig::config{$zone}{'axfr-from'} and not (($BindConfig::config{$zone}{'axfr-from'} eq $main::global{localname}) or ($main::global{localalias}{$BindConfig::config{$zone}{'axfr-from'}}==1)));
      print bindconf '    '.
            $BindConfig::nameservers{$BindConfig::config{$zone}{master}}.'; '.
            '/* MASTER - '.$BindConfig::config{$zone}{master}.' */'."\n"
            unless ($BindConfig::config{$zone}{master} eq $BindConfig::config{$zone}{'axfr-from'});
      for $ns (keys %{$BindConfig::config{$zone}{slave}})
      {
        next if ($ns eq $main::global{localname});
        next if ($main::global{localalias}{$ns}==1);
        next if ($ns eq $BindConfig::config{$zone}{'axfr-from'});
        print bindconf '    '.$BindConfig::nameservers{$ns}.'; /* '.$ns.' */'."\n";
      }
      print bindconf "  };\n";
    }
    else
    {
      print bindconf '  file "'.
           $BindConfig::primarydir.$BindConfig::config{$zone}{file}."\";\n";
    }
    print bindconf '  allow-transfer {'."\n";
    print bindconf '    localhost;'."\n";
    print bindconf '    '.
       $BindConfig::nameservers{$BindConfig::config{$zone}{master}}.'; '.
       '/* '.$BindConfig::config{$zone}{master}.' */'."\n";
    for $ns (keys %{$BindConfig::config{$zone}{slave}})
    {
      next if ($ns eq $main::global{localname});
      next if ($main::global{localalias}{$ns}==1);
      print bindconf '    '.$BindConfig::nameservers{$ns}.'; /* '.$ns.' */'."\n";
    }
    for $ns (keys %{$BindConfig::config{$zone}{'allow-axfr'}})
    {
      next if ($ns eq $main::global{localname});
      next if ($main::global{localalias}{$ns}==1);
      print bindconf '    '.$BindConfig::nameservers{$ns}.'; /* '.$ns.' */'."\n";
    }
    print bindconf "  };\n";
    if (scalar keys(%{$BindConfig::config{$zone}{'notify'}}))
    {
      print bindconf '  also-notify {'."\n";
      for $ns (keys %{$BindConfig::config{$zone}{'notify'}})
      {
        next if ($ns eq $main::global{localname});
        next if ($main::global{localalias}{$ns}==1);
        print bindconf '    '.$BindConfig::nameservers{$ns}.'; /* '.$ns.' */'."\n";
      }
      print bindconf "  };\n";
    }
    print bindconf "};\n\n";
  }
 
  close bindconf;

}

# SackUtils::warn("Loading BindConfig.pm");
1;
