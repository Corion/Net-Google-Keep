#!perl -w
use strict;

use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

use Data::Dumper;

use Net::Google::Keep::Downsync;

my $p = Net::Google::Keep::Downsync->new();

for (@ARGV) {
    my @items = $p->parse_file( $_ );
    
    #print "$_\n" for sort keys %$items;
    
    my %seen;
    for my $item (@items) {
        print join "\n", $item->as_markdown;
        print "\n";
    }
    
}