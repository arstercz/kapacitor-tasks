#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use Data::Dumper;

while(<stdin>) {
  my $text = "$_";
  my $json = from_json($text);
  print Dumper($json);
}
