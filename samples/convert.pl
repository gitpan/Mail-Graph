#!/usr/bin/perl -w

# convert a mail-dir folder into mbox format archive

my $dir = '~/Mail/spam/';
my $output = 'archive/spams_cnv.txt';

opendir DIR , $dir or die "Cannot read dir $dir: $!";
@files = readdir DIR;
closedir DIR;

my @mail;
foreach $file (@files)
  {
  my @lines = ();
  my ($date,$from); $date = "\n"; $from = "";
  open FILE, "$dir/$file" or die "Cannot read file $file: $!";
  while (<FILE>)
    {
    $line = $_;
    if ($line =~ /^X-RDate: /i)
      {
      $line =~ s/\s\(\/etc.*//;			# correct corrupted dates
      $date = $line; $date =~ s/^X-RDate: //;
      }
    if (($line =~ /^Date: /i) && ($date eq "\n"))
      {
      $date = $line; $date =~ s/^Date: //;
      }
    if (($line =~ /^From: /i) && ($from eq ''))
      {
      $from = $line; $from =~ s/^From: //; $from =~ s/\n//;
      }
    if ($line =~ /^Return-Path: /i)
      {
      $from = $line; $from =~ s/^Return-Path: //; $from =~ s/\n//;
      }
    push @lines,$line;
    }
  close FILE;
  splice @lines, 1,1,"X-FILE: $file\n";
  unshift @lines, "\nFrom $from $date"; # insert proper FROM
  push @mail, @lines if @lines > 3;
  }
  
$mail[0] =~ s/^\n//;

open FILE, ">$output" or die "Cannot write file $output: $!";
foreach (@mail) { print FILE $_; }
close FILE;

unlink $output.'.gz'; `gzip $output`;