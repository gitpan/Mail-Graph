#!/usr/bin/perl -w

use Test;
use strict;

BEGIN
  {
  $| = 1;
  unshift @INC, '../blib/lib';
  chdir 't' if -d 't';
  plan tests => 38;
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

##############################################################################
# tests for the _average function

my $data = { 
  '1/1/1900' => 10,	# avrg: 10/7 => 1
  '2/1/1900' => 20,	# 30/7 =>
  '3/1/1900' => 30,	# 60/7
  '4/1/1900' => 40,	# 100/7
  '5/1/1900' => 50,	# 150/7
  '6/1/1900' => 60,	# 210/7
  '7/1/1900' => 70,	# 280/7
  '8/1/1900' => undef,	# 270/7
  '9/1/1900' => 10,	# 260/7
  '10/1/1900' => 20,	# 250/7
  '11/1/1900' => 30,	# 240/7
  '12/1/1900' => 40,	# 230/7
  '13/1/1900' => 50,	# 220/7
  };
my $result = { 
  '1/1/1900' => 
  int((10)/7),
  '2/1/1900' => 
  int((10+20)/7),
  '3/1/1900' => 
  int((10+20+30)/7),
  '4/1/1900' => 
  int((10+20+30+40)/7),
  '5/1/1900' => 
  int((10+20+30+40+50)/7),
  '6/1/1900' => 
  int((10+20+30+40+50+60)/7),
  '7/1/1900' => 
  int((10+20+30+40+50+60+70)/7),
  '8/1/1900' => 
  int((20+30+40+50+60+70+0)/7),
  '9/1/1900' => 
  int((30+40+50+60+70+0+10)/7),
  '10/1/1900' => 
  int((40+50+60+70+0+10+20)/7),
  '11/1/1900' => 
  int((50+60+70+0+10+20+30)/7),
  '12/1/1900' => 
  int((60+70+0+10+20+30+40)/7),
  '13/1/1900' => 
  int((70+0+10+20+30+40+50)/7),
  };

my $res = 
 Mail::Graph::_average ( 
   { 
   _options => { average => 7, generate => { last_x_days => 30 }, }, 
   }, $data, 
 );

foreach (keys %$res)
  {
  ok ($res->{$_}->[1],$result->{$_});
  }

