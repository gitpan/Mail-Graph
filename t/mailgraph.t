#!/usr/bin/perl -w

use Test;
use strict;

BEGIN
  {
  $| = 1;
  unshift @INC, '../blib/lib';
  chdir 't' if -d 't';
  plan tests => 102;
  }

use Mail::Graph v0.11;

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
# test default options

my $def = {
    input => 'archives',
    output => 'spams/',
    items => 'spams',
    height => 200,
    template => 'index.tpl',
    no_title => 0,
    filter_domains => [ ],
    filter_target => [ ],
    average => 7,
    average_daily => 14,
    last_date => undef,
    generate => {
      month => 1,
      yearly => 1,
      day => 1,
      daily => 1,
      dow => 1,
      monthly => 1,
      hour => 1,
      toplevel => 1,
      rule => 1,
      target => 1,
      domain => 1,
      last_x_days => 30,
      score_histogram => 5,
      score_scatter => 5,
      score_daily => 60,
      },
   };

$mg = Mail::Graph->new( );

foreach (keys %$def)
  {
  if (! ref $def->{$_})
    {
    print "# Tried $_\n" unless ok $mg->{_options}->{$_},$def->{$_};
    }
  }

$def = {
    input => '.',
    output => '.',
    items => 'mails',
    height => 202,
    template => 'index1.tpl',
    no_title => 1,
    filter_domains => [ 'example.com' ],
    filter_target => [ 'example@example.com', 'sample', ],
    average => 17,
    average_daily => 24,
    last_date => '2002-08-2',
    generate => {
      month => 1,
      yearly => 1,
      day => 1,
      daily => 1,
      dow => 1,
      monthly => 1,
      hour => 1,
      toplevel => 1,
      rule => 1,
      target => 1,
      domain => 1,
      last_x_days => 40,
      },
   };

$mg = Mail::Graph->new( $def );

foreach (keys %$def)
  {
  if (! ref $def->{$_})
    {
    ok $mg->{_options}->{$_},$def->{$_};
    }
  }

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

###############################################################################
# test conversation functions

my $month_table = { jan => 1, feb => 2, mar => 3, apr => 4, may => 5, jun => 6,
              jul => 7, aug => 8, sep => 9, oct => 10, nov => 11, dec => 12 };

foreach my $m (keys %$month_table)
  {
  ok (Mail::Graph::_month_to_num(lc($m)),$month_table->{$m});
  ok (Mail::Graph::_month_to_num(uc($m)),$month_table->{$m});
  ok (Mail::Graph::_month_to_num(ucfirst($m)),$month_table->{$m});
  }
  
# _add_percentage

my $stats = { wahl => { 
  'red' => 38.5,
  'black' => 38.5,
  'green' => 8.6,
  'yellow' => 7.4,
  'darkred' => 4,
  'purple-green-dotted' => 3,
  } };

my $percent = {
  'red' => 38.5,
  'black' => 38.5,
  'green' => 8.6,
  'yellow' => 7.4,
  'darkred' => 4,
  'purple-green-dotted' => 3,
  };

Mail::Graph->_add_percentage($stats, 'wahl');

foreach my $key (keys %{$stats->{wahl}})
  {
  ok ($stats->{wahl}->{$key}, 
    "$percent->{$key}, $percent->{$key}%");
  }

