#!/usr/bin/perl -w

use strict;
use lib '../lib';
use Mail::Graph;

my $mg = Mail::Graph->new( 
  input => 'archive',		# input path
  output => 'output',		# output path
  template => 'index.tpl',	# the output will be templatename.html
				# so change index.tpl to stats.tpl to get
				# stats.html as output
  no_title => 1,		# should graphs have a title? 1 => no, 0 => yes
  average => 7,
  average_daily => 14,		# if undef, set to 'average'
# last_date => '2002-08-02',	# anything newer will be ignored, good for
				# looking into the past
  graph_ext => 'png',		# or 'gif' or 'jpg'
  generate => {
      month => 1,
      yearly => 0,
      day => 1,
      daily => 1,
      hour => 1,
      dow => 1,
      monthly => 0,
      toplevel => 1,
      rule => 1,
      target => 1,
      domain => 1,
      last_x_days => 60,	# the graph should go back how many days?
      },
  );
die "Error: ",$mg->error(),"\n" if $mg->error();
$mg->generate();

print "\nDone\n";
