#!/usr/bin/perl -w

use Test;
use strict;

BEGIN
  {
  $| = 1;
  unshift @INC, '../blib/lib';
  chdir 't' if -d 't';
  plan tests => 25;
  }

use Mail::Graph;

my $mg = Mail::Graph->new( input => '.', output => '.', );

ok (ref($mg),'Mail::Graph');
ok ($mg->error()||'','');

# some internal tests
my ($day,$month,$year,$dow,$hour,$minute,$second,$offset) = 
 Mail::Graph->_parse_date('');
ok ($day,0); ok ($month,0); ok ($year,0); ok ($hour,0);
ok ($minute,0); ok ($second,0); ok ($offset,0);

($day,$month,$year,$dow,$hour,$minute,$second,$offset) = 
 Mail::Graph->_parse_date('Tue Oct 27 18:38:52 1998');
ok ($day,27); ok ($month,10); ok ($year,1998); ok ($hour,18);
ok ($minute,38); ok ($second,52); ok ($offset,0); ok ($dow,2);

($day,$month,$year,$dow,$hour,$minute,$second,$offset) = 
 Mail::Graph->_parse_date('Sun, 19 Jul 1998 23:49:16 +0200');
ok ($day,19); ok ($month,7); ok ($year,1998); ok ($hour,23);
ok ($minute,49); ok ($second,16); ok ($offset,'+0200'); ok ($dow,7);

