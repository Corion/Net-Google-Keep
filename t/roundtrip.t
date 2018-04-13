#!perl -w
use strict;
use Net::Google::Keep::Downsync;

use JSON 'decode_json';
use Path::Class 'file';
use Data::Dumper;

use Test::More tests => 1;

my $p = Net::Google::Keep::Downsync->new();

my $original = scalar file( 't/autoextract.json' )->slurp(iomode => '<:raw');

my $raw = decode_json( $original );
my @original = sort {    $a->{serverId} cmp $b->{serverId} 
                      || $a->{id} cmp $b->{id}
                      || $a->{parentServerId} cmp $b->{parentServerId}
              } @{$raw->{nodes}};
my @json     = sort {    $a->{serverId} cmp $b->{serverId}
                      || $a->{id} cmp $b->{id}
                      || $a->{parentServerId} cmp $b->{parentServerId}
              } map { $_->as_json_keep() } $p->parse_string( $original );

is_deeply \@json, \@original, "We can roundtrip the data"
    or do { diag Dumper [$json[0], $original[0]]};

done_testing;