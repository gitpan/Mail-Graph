
package Mail::Graph;

# Read mail mbox files (compressed or uncompressed), and generate a
# statistic from it
# (c) by Tels 2002. See http://bloodgate.com/spams/ for an example.

use strict;
use GD::Graph::lines;
use GD::Graph::bars;
use GD::Graph::colour;
use GD::Graph::Data;
use GD::Graph::Error;
use Date::Calc 
  qw/Delta_Days Date_to_Days Day_of_Week Today_and_Now check_date
     Delta_YMDHMS Add_Delta_Days
    /;
use Exporter;

use vars qw/@ISA $VERSION/;

@ISA = qw/Exporter/;

$VERSION = '0.03';

my ($month_table,$dow_table);

sub new
  {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  $self->_init(@_);
  }

sub _init
  {
  my $self = shift;
  my $options = $_[0];

  $options = { @_ } unless ref $options eq 'HASH';

  $self->{_options} = $options;
  my $def = {
    input => 'archives',
    output => 'spams',
    items => 'spams',
    height => 200,
    templates => 'index.tpl',
    no_title => 0,
    generate => {
      month => 1,
      yearly => 1,
      day => 1,
      daily => 1,
      dow => 1,
      monthly => 1,
      toplevel => 1,
      rule => 1,
      target => 1,
      domain => 1,
      },
    };
  
  foreach my $k (keys %$def)
    {
    $options->{$k} = $def->{$k} unless exists $options->{$k};
    }
  $options->{output} .= '/' unless $options->{output} =~ /\/$/;
  $options->{input} .= '/'
    if -d $options->{input} && $options->{input} !~ /\/$/;
  $self->{error} = undef;
  $self->{error} = "input '$options->{input}' is neither directory nor file"
   if ((! -d $options->{input}) && (!-f $options->{input}));
  $self->{error} = "output '$options->{output}' is not a directory"
   if (! -d $options->{output});
  return $self;
  }

sub error
  { 
  my $self = shift;
  return $self->{error};
  }

sub generate
  {
  my $self = shift;

  return $self if defined $self->{error};

  my @files = $self->_gather_files($self->{_options}->{input});
  my $id = 0; my @mails;

  # for stats:
  my $stats = {};
  foreach my $k (
   qw/toplevel date month dow day yearly monthly daily rule target domain/)
    {
    $stats->{$k} = {};
    }
  foreach my $k (qw/items_proccessed items_skipped last_7_days last_24_hours/)
    {
    $stats->{stats}->{$k} = 0;
    }
  my $now = [ Today_and_Now() ];
  foreach my $file (sort @files)
    {
    print "At file $file\n";
    @mails = $self->_gather_mails($file,\$id);
    foreach my $mail (@mails)
      {
      # split "From blah@bar.baz Datestring"
      # skip replies of the mailer-daemon to non-existant addresses
      $stats->{stats}->{items_skipped}++, next
       if $mail->{header}->[0] =~ /MAILER-DAEMON/;
      $stats->{stats}->{items_skipped}++, next
       if !defined $mail->{header}->[0];

      my ($a,$b,$c,$d,$email,$domain,$toplevel,$date);

      if ($mail->{header}->[0] =~  
  /^From [<]?(.+?\@)([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})[>]? (.*)/)
        {
        $email = $1.$2;
        $domain = $2;
        $toplevel = 'undef';
        $date = $3 || 'undef';
        }
      else
        {
        $mail->{header}->[0] =~ /^From [<]?(.+?\@)([a-zA-Z0-9\-\.]+?)(\.[a-zA-Z]{2,4})[>]? (.*)/;
        $a = $1 || 'undef';
        $b = $2 || 'undef';
        $c = $3 || 'undef';
        $d = $4 || 'undef';
        $email = $a.$b.$c;
        $date = $d || 'undef';
        $toplevel = lc($c);
        $domain = $b.$c;
#        warn "huh $mail->{header}->[0]\n" if $a eq 'undef';
        }
      $stats->{stats}->{items_skipped}++, next
       if $date eq 'undef';
      my ($day,$month,$year,$dow,$hour,$minute,$second,$offset)
       = $self->_parse_date($date);

#    print "$date " ,
#    join ('|',$day,$month,$year,$dow,$hour,$minute,$seconds,$offset),"\n"
#     if !defined $month || $month eq '';

      $stats->{stats}->{items_skipped}++, next
       unless check_date($year,$month,$day);

      $stats->{stats}->{items_processed}++;

      my $target = '';
      # extract the target address
      foreach my $line (@{$mail->{header}})
        {
        if (($line =~ /^X-Envelope-To:/i) && ($target eq ''))
	  {
          $target = $line; $target =~ s/^[A-Za-z-]+: //;
	  }
#        if (($line =~ /^To:/i) && ($target eq ''))
#	  {
#          $target = $line; $target =~ s/^To: //i;
#	  }
        }
      $target = lc($target);			# normalize
      $target =~ s/^\".+?\"\s+//;		# throw away comment/name
      $target =~ s/[<>]//g; 
      $target = substr($target,0,64) if length($target) > 64;

      $target = '' if $target =~ /bizarre-talk/i;

      $domain = $target; $domain =~ /\@(.+)$/; $domain = $1 || 'unknown';
      $domain = 'unknown' if $target eq '';
      $target = 'unknown' if $target eq '';
      $stats->{target}->{$target}++;
      
      $stats->{domain}->{$domain}++;
      
      # include check for valid target domain

      my ($D_y,$D_m,$D_d, $Dh,$Dm,$Ds) =
        Delta_YMDHMS($year,$month,$day, $hour,$minute,$second, @$now);

      $stats->{stats}->{last_24_hours}++
       if ($D_y == 0 && $D_m == 0 && $D_d == 0 && $Dh < 24);
      $stats->{stats}->{last_7_days}++
       if Delta_Days($year,$month,$day,$now->[0],$now->[1],$now->[2]) <= 7;
      $year += 1900 if $year < 100;
      $stats->{month}->{$year}->[$month-1]++;
      $stats->{dow}->{$year}->[$dow-1]++;
      $stats->{day}->{$year}->[$day-1]++;
      $stats->{yearly}->{$year}++;
      $stats->{monthly}->{"$month/$year"}++;
      $stats->{daily}->{"$day/$month/$year"}++;
   
      # extract the filter rule that matched
      foreach my $line (@{$mail->{header}})
        {
        next if $line !~ /^X-Spamblock:/i; 
        my $rule = $line; $rule =~ s/^X-Spamblock: //i;
        $rule =~ s/^caught //;
        $rule =~ s/^by //;
        $rule =~ s/^rule //;
        $stats->{rule}->{$rule}++;
        }
 
#     if ($toplevel) !~ /^\.[a-z]+$/;
#      $stats->{email}->{$email}++;
      next if $toplevel eq 'undef';
      $stats->{toplevel}->{$toplevel}++;
#    print $mail->{header}->[0],"\n";
      }
    }

#  use Data::Dumper;
#  print Dumper($stats->{domain});

  my $what = $self->{_options}->{items};
  my $h = $self->{_options}->{height};

  # adjust the width of the toplevel stat, so that it doesn't look to broad
  my $w = (scalar keys %{$stats->{toplevel}}) * 30; $w = 900 if $w > 900;
  $self->_graph ($stats,'toplevel', $w, $h, {
    title => "$what/top-level domain",
    x_label => 'top-level domain',
    y_number_format => '%i',
    bar_spacing     => 3,
    });

  $self->_graph ($stats,'month', 400, $h, {
    title => "$what/month",
    x_label => 'month',
    y_number_format => '%i',
    x_labels_vertical => 0,
    bar_spacing     => 6,
    cumulate => 1, 
    },
    \&_num_to_month,
    );

  $self->_graph ($stats,'dow', 300, $h, {
    title => "$what/day",
    x_label => 'day of the week',
    x_labels_vertical => 0,
    bar_spacing     => 6,
    cumulate => 1, 
    },
    \&_num_to_dow,
    );

  $self->_graph ($stats,'day', 800, $h, {
    title => "$what/day",
    x_label => 'day of the month',
    x_labels_vertical => 0,
    bar_spacing     => 4,
    cumulate => 1, 
    },
    );

  # adjust the width of the yearly stat, so that it doesn't look to broad
  $w = (scalar keys %{$stats->{yearly}}) * 60; $w = 600 if $w > 600;
  $self->_graph ($stats,'yearly', $w, $h, {
    title => "$what/year",
    x_label => 'year',
    x_labels_vertical => 0,
    bar_spacing     => 8,
    },
    );

  # adjust the width of the monthly stat, so that it doesn't look to broad
  $w = (scalar keys %{$stats->{monthly}}) * 30; $w = 800 if $w > 800;
  $self->_graph ($stats,'monthly', $w, $h, {
    title => "$what/month",
    x_label => 'month',
    x_labels_vertical => 1,
    bar_spacing     => 2,
    },
    \&_year_month_to_num,
    );
  
  # adjust the width of the rule stat, so that it doesn't look to broad
  $w = (scalar keys %{$stats->{rule}}) * 30; $w = 800 if $w > 800;
  # need more height for long rule names
  $self->_graph ($stats,'rule', $w, $h + 200, {
    title => "$what/rule",
    x_label => 'rule',
    x_labels_vertical => 1,
    bar_spacing     => 2,
    },
    );
  
  # adjust the width of the target stat, so that it doesn't look to broad
  $w = (scalar keys %{$stats->{target}}) * 30; $w = 800 if $w > 800;
  # need more height for long target names
  $self->_graph ($stats, 'target', $w, $h + 300, {
    title => "$what/address",
    x_label => 'target address',
    x_labels_vertical => 1,
    bar_spacing     => 2,
    },
    );
  
  # adjust the width of the domain stat, so that it doesn't look to broad
  $w = (scalar keys %{$stats->{domain}}) * 30; $w = 800 if $w > 800;
  # need more height for long domain names
  $self->_graph ($stats, 'domain', $w, $h + 100, {
    title => "$what/domain",
    x_label => 'target domain',
    x_labels_vertical => 1,
    bar_spacing     => 4,
    },
    );
  
  # calculate how many entries we must skip to have a sensible amount of them
  my $skip = scalar keys %{$stats->{daily}};
  $skip = int($skip / 82); $skip = 1 if $skip < 1;
  # calculate a rolling average over the last 7 day
  my $avrg = {};
  foreach my $thisday (sort keys %{$stats->{daily}})
    {
    my $sum = $stats->{daily}->{$thisday};
    my ($day,$month,$year) = split /\//,$thisday;
    my ($d,$m,$y);
    for (my $i = 1; $i < 7; $i++)
      {
      ($y,$m,$d) = Add_Delta_Days($year,$month,$day,-$i);
      my $this = "$d/$m/$y";
      $sum += $stats->{daily}->{$this}||0;		# non-existant => 0
      }
    $avrg->{$thisday} = [ $stats->{daily}->{$thisday}, int($sum / 7) ];
    }
  $stats->{daily} = $avrg;
#  print Dumper($stats->{daily}),"\n"; exit;
  $self->_graph ($stats,'daily', 800, $h + 50, {
    title => "$what/day",
    x_label => 'date',
    x_labels_vertical => 1,
    x_label_skip => $skip,
    type	=> 'lines',
    },
    \&_year_month_day_to_num,
    $avrg,
    );
  $self->_fill_template($stats);
  }

###############################################################################
# private methods

sub _fill_template
  {
  my ($self,$stats) = @_;
  
  # read in
  my $file = $self->{_options}->{template};
  my $tpl = '';
  open FILE, "$file" or die ("Cannot read $file: $!");
  while (<FILE>) { $tpl .= $_; }
  close FILE;

  # replace placeholders
  $tpl =~ s/##generated##/scalar localtime();/eg;
  $tpl =~ s/##version##/$VERSION/g;
  $tpl =~ s/##items##/lc($self->{_options}->{items})/eg;
  $tpl =~ s/##Items##/ucfirst($self->{_options}->{items})/eg;
  $tpl =~ s/##ITEMS##/uc($self->{_options}->{items})/eg;
  
  foreach (qw/ items_processed items_skipped last_7_days last_24_hours/)
    {
    $tpl =~ s/##$_##/$stats->{stats}->{$_}/g;
    }

  # write out
  $file =~ s/\.tpl/.html/;
  $file = $self->{_options}->{output}.$file;
  open FILE, ">$file" or die ("Cannot write $file: $!");
  print FILE $tpl;
  close FILE;
  return $self;
  }

BEGIN
  {
  $month_table = { jan => 1, feb => 2, mar => 3, apr => 4, may => 5, jun => 6,
	      jul => 7, aug => 8, sep => 9, oct => 10, nov => 11, dec => 12 };
  $dow_table = { mon => 1, tue => 2, wed => 3, thu => 4, fri => 5,
                 sat => 6, sun => 7, };
  }

sub _month_to_num
  {
  my $m = lc(shift);
  return $month_table->{$m} || 0;
  }

sub _year_month_to_num
  {
  my $m = shift;

  my ($month,$year) = split /\//,$m;
  $year * 12+$month;
  }

sub _year_month_day_to_num
  {
  my $m = shift;

# print "$m ",join(' ',caller()),"\n";
  my ($day,$month,$year) = split /\//,$m;
  return Date_to_Days($year,$month,$day);
  }

sub _dow_to_num
  {
  my $d = lc(shift);
  return $dow_table->{$d} || 0;
  }

sub _num_to_dow
  {
  my $d = shift;
  foreach my $k (keys %$dow_table)
    {
    return $k if $dow_table->{$k} eq $d;
    }
  return 'unknown dow $d';
  }

sub _num_to_month
  {
  my $d = shift;
  foreach my $k (keys %$month_table)
    {
    return $k if $month_table->{$k} eq $d;
    }
  return 'unknown month $d';
  }

sub _parse_date
  {
  my ($self,$date) = @_;

  my ($day,$month,$year,$dow,$hour,$minute,$seconds,$offset);
  if ($date =~ /,/)
    {
    # Sun, 19 Jul 1998 23:49:16 +0200
    $date =~ /([A-Za-z]+),\s+(\d+)\s([A-Za-z]+)\s(\d+)\s(\d+):(\d+):(\d+)\s(.*)/;
    $day = int($2 || 0);
    $month = _month_to_num($3 || 0);
    $year = int($4 || 0); $year += 1900 if $year < 100 && $year > 0;
    $dow = _dow_to_num($1 || 0);
    $hour = $5 || 0;
    $minute = $6 || 0;
    $seconds = $7 || 0;
    $offset = $8 || 0;
    # return ($day,$month,$4,$1,$5,$6,$7,$8);
    }
  else
    {
    # Tue Oct 27 18:38:52 1998
    $date =~ /([A-Za-z]+)\s([A-Za-z]+)\s+(\d+)\s(\d+):(\d+):(\d+)\s(\d+)/;
    $day = int($3 || 0);
    $month = _month_to_num($2 || 0);
    $year = int($7 || 0); $year += 1900 if $year < 100 && $year > 0;
    $dow = _dow_to_num($1 || 0);
    $hour = $4 || 0; $minute = $5 || 0; $seconds = $6 || 0; $offset = 0;
    # return ($3,$2,$7,$1,$4,$5,$6,0);
    }
  return ($day,$month,$year,$dow,$hour,$minute,$seconds,$offset);
  }

sub _graph
  {
  my ($self,$stats,$stat,$w,$h,$options,$map,$avrg) = @_;

  return if $self->{_options}->{generate}->{$stat} == 0;	# skip this

  print "Making graph $stat...\n";
  my $max = 0;
  $map = sub { $_[0]; } if !defined $map;
  my @legend = (); my @data;
  my $k = []; my $v = [];
  if (defined $options->{cumulate})
    {
    my $make_k = 0;				# only once
    foreach my $key (sort keys %{$stats->{$stat}})
      {
      #print "at key $key\n";
      push @legend, $key;
      $v = []; my $i = 1;
      foreach my $kkey (@{$stats->{$stat}->{$key}})
        {
        $kkey = 0 if !defined $kkey;
        push @$k, &$map($i) if $make_k == 0; $i++;
        push @$v, $kkey;
        }
      $make_k = 1;
      push @data, $v;
      }
    }
  elsif ($options->{type}||'' eq 'lines')
    {
    push @legend, $stat, 'average over last 7 days';

    foreach my $key (sort { 
      my $aa = &$map($a); my $bb = &$map($b);
      if (($aa =~ /^[0-9\.]+$/) && ($bb =~ /^[0-9\.]+$/))
        {
        return $aa <=> $bb;
        }
      $aa cmp $bb;
      }  keys %{$stats->{$stat}})
      {
      push @$k, $key;
      my $i = 0;
      foreach my $j (@{$stats->{$stat}->{$key}})
        {
        push @{$v->[$i]}, $j; $i++;
        }
      }
    foreach my $j (@$v)
      {
      push @data, $j;
      }
    }
  else
    {
    foreach my $key (sort { 
      my $aa = &$map($a); my $bb = &$map($b);
      if (($aa =~ /^[0-9\.]+$/) && ($bb =~ /^[0-9\.]+$/))
        {
        return $aa <=> $bb;
        }
      $aa cmp $bb;
      }  keys %{$stats->{$stat}})
      {
      push @$k,$key;
      push @$v, $stats->{$stat}->{$key};
      }
    push @data, $v;
    }
  my @sum;
  foreach my $r ( @data )
    {
    my $i = 0;
    foreach my $h ( @$r )
      {
      $sum[$i++] += $h;
      }
    }
  foreach my $r ( @sum )
    {
    $max = $r if $r > $max;
    } 
  my $data = GD::Graph::Data->new([$k, @data]) or die GD::Graph::Data->error;

  if (int($max * 1.05) == $max)	# increase by at least 1
    {
    $max++;
    }
  else
    {
    $max = int($max*1.05);
    }
  my $defaults = {
    x_label	=> $self->{_options}->{items},
    y_label	=> 'count',
    title	=> $self->{_options}->{items} . '/day',
    y_max_value	=> $max,
    y_tick_number	=> 8,
    bar_spacing		=> 4,
    y_number_format	=> '%i',
    x_labels_vertical	=> 1,
    transparent		=> 1,
   };
  my @opt = ();
  foreach my $k (keys %$options, keys %$defaults)
    {
    next if $k eq 'title' && $self->{_options}->{no_title} != 0;
    next if $k eq 'type';
    $options->{$k} = $defaults->{$k} if !defined $options->{$k};
    push @opt, $k, $options->{$k};
    }
 
  #############################################################################
  # retry to make a graph until it fits

  $w = 120 if $w < 120;		# minimum width
  my $redo = 0;
  while ($redo == 0)
    {
    my $my_graph;
    if (($options->{type} || '') eq 'lines')
      {
      $my_graph = GD::Graph::lines->new( $w, $h );
      $my_graph->set( dclrs => [ '#9090e0','#ff6040' ] );
      }
    else
      {
      $my_graph = GD::Graph::bars->new( $w, $h );
      $my_graph->set( dclrs =>
        [ '#ff2060','#60ff80','#6080ff','#ffff00','#f060f0','#d0a040', ] );
  #      [ '#f00020','#4000e0','#d00080','#a000c0','#b000b0','#a000c0', ] );
  #      [ '#f0f090','#e0e080','#d0d070','#c0c060','#b0b050','#a0a040' ] );
      }
    $my_graph->set_legend(@legend) if @legend != 0;
  
    $my_graph->set( @opt ) or warn $my_graph->error();

    print "Making $w x $h\n";
    $my_graph->clear_errors();
    $my_graph->plot($data);
    $redo = 1;
    if (($my_graph->error()||'') =~ /Horizontal size too small/)
      {
      $w += 32; $redo = 0;
      }
    if (($my_graph->error()||'') =~ /Vertical size too small/)
      {
      $h += 64; $redo = 0;
      }
    if (!$my_graph->error())
      {
      $self->_save_chart($my_graph, $self->{_options}->{output}.$stat);
      print "Saved\n";
      last;
      }
    }
  return $self;
  }

sub _gather_files
  {
  my $self = shift;
  my $dir = shift;

  opendir DIR, $dir or die "Cannot open dir $dir: $!";
  my @files = readdir DIR;
  closedir DIR;

  my @ret = ();
  foreach my $file (@files)
    {
    next unless $file =~ /\.gz$/;		# only gz ones
    push @ret, $file;	
    }
  @ret;
  }

sub _gather_mails
  {
  my ($self,$file,$id) = @_;

  # that is a bit inefficient, sucking in anything at a time...
  my $doc = `zcat $self->{_options}->{input}$file`;

  die ("$file doesn't look like an mail archive") if $doc !~ /^From /;
  my @lines = split /\n/,$doc;

  my $header = 0; my @body_lines = (); my @header_lines = ();
  my (@ret);
  foreach my $line (@lines)
    {
    if ($line =~ /^From /)
      {
      $header = 1;
      if (@header_lines > 0)
        {
        push @ret, {
           header => [ @header_lines ], 
           body => [ @body_lines ], 
           id => $$id 
          }; 
        $$id ++;
        @body_lines = ();
        @header_lines = ();
        }
      }
    push @body_lines, $line if $header == 0;
    $header = 0 if $header == 1 && $line =~ /^\n$/;
    push @header_lines, $line if $header == 1;
    }
  if (@header_lines > 0)
    {
    push @ret, {
      header => [ @header_lines ], 
      body => [ @body_lines ], 
      id => $$id 
     }; 
    }
  @ret; 
  }

sub _save_chart
  {
  my $self = shift;
  my $chart = shift or die "Need a chart!";
  my $name = shift or die "Need a name!";
  local(*OUT);

  my $ext = $chart->export_format;

  open(OUT, ">$name.$ext") or
   die "Cannot open $name.$ext for write: $!";
  binmode OUT;
  print OUT $chart->gd->$ext();
  close OUT;
  }

1;

__END__

###############################################################################
###############################################################################
=pod

=head1 NAME

=head1 SYNOPSIS

	use Mail::Graph;

	$graph = Mail::Graph->new( items => 'spam', 
	  output => 'spams/',
	  input => '~/Mail/spam/',
          );
        $graph->generate();

=head1 DESCRIPTION

This module parses mailbox files in either compressed or uncompressed form
and then generates pretty statistics and graphs about them. Although at first
developed to do spam statistics, it works just fine for normal mail.

=head1 METHODS

=head2 new()

Create a new Mail::Graph object.

The following options exist:

	input		Path to an directory containing mbox files
			Alternatively, name of an mbox file
	output		Path where to write the output stats
	items		Try 'spams' or 'mails' (can be any string)
	generate	hash with names of stats to generate (1=on, 0=off):
			 month	   per each month of the year
			 day	   per each day of the month
			 dow	   per each day of the week
			 yearly	   per year
			 daily	   per each day (with average)
			 monthtly  per each month
			 toplevel  per top_level domain
			 rule	   per filter rule that matched
			 target	   per target address
			 domain	   per target domain
	average		set to 0 to disable, otherwise it gives the number
			of days/weeks/month to average over
	average_days	if not set, uses average, 0 to disable
	average_months	if not set, uses average, 0 to disable
	average_weeks	if not set, uses average, 0 to disable
	height		height of the generated images
	template	name of the template file (ending in .tpl) that is
			used to generate the html output, e.g. 'index.tpl'

=head2 generate()

Generate the stats.

=head2 error()

Return an error message or undef for no error.

=head1 BUGS

None known so far.

=head1 LICENSE

=head1 AUTHOR

(c) by Tels http://bloodgate.com/ 2002.

=cut

