#!/usr/bin/perl -w

use strict;
use lib '../lib';
use Mail::Graph;

my $mg = Mail::Graph->new( 
  input => 'archive',
  output => 'output',
  template => 'index.tpl',
  no_title => 1,
  );
die "Error: ",$mg->error(),"\n" if $mg->error();
$mg->generate();

print "\nDone\n";
