#!perl -w
use strict;
use Net::Google::Keep::Downsync;

use JSON 'decode_json';
use Path::Class 'file';
use Data::Dumper;

use Test::More tests => 3;

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

is 0+@original, 0+@json, "We keep the same number of items";

is_deeply [map { $_->{id} } @original], [map { $_->{id} } @json], "We keep all ids";

if( ! is_deeply \@json, \@original, "We can roundtrip the data") {
    # find where things went wrong and dump just that...
    diag Dumper [$json[2], $original[2]];
};

done_testing;