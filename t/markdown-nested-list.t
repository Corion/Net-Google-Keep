#!perl -w
use strict;
use Net::Google::Keep::Downsync;

use JSON 'decode_json';
use Path::Class 'file';
use Data::Dumper;

use Test::More tests => 4;

my $p = Net::Google::Keep::Downsync->new();

my $original = scalar file( 't/autoextract.json' )->slurp(iomode => '<:raw');

(my $nested_list) = grep { $_->id eq '1528446687601.1235046561' } $p->parse_string( $original );

ok $nested_list, 'We found our nested list';
is $nested_list->title, 'Google Keep Autoextract (indented list)', '... the title looks OK';

my @md = $nested_list->as_markdown;
my @expected = split /\r?\n/, <<'MARKDOWN';
---
## Google Keep Autoextract (indented list)

- [ ] Top item
    - [ ] Sub item1
    - [ ] Sub item 2
- [ ] Top item 2  (unchecked)
    - [ ] Sub item 2.1
    - [x] Sub item 2.2 (checked)
- [x] Top item 3 (checked)
    - [x] Sub item 3.1 (unchecked)
    - [x] Sub item 3.2 (checked)
- [ ] Top item 4
    - [ ] Sub item 4.1
    - [ ] Sub item 4.2
MARKDOWN

# Unindent items for comparing the overall order
my @expected_item_order = map { my $r=$_; $r =~ s/^\s+//; $r } @expected;
my @md_item_order = map { my $r=$_; $r =~ s/^\s+//; $r } @md;
is_deeply \@md_item_order, \@expected_item_order,
    "The order of items is kept correctly in markdown conversion"
    or diag Dumper [\@md_item_order, \@expected_item_order];

is_deeply \@md, \@expected, "The markdown conversion keeps nested lists correct"
    or diag Dumper [\@md, \@expected];

done_testing;