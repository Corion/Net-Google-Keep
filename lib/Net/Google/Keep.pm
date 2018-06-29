package Net::Google::Keep;
use strict;

=head1 NAME

Net::Google::Keep - access Google Keep notes from Perl

=head1 SETUP

Currently this needs a Chrome instance signed into Google (Keep) to get at the
paths and cookies.

=cut

our $VERSION = '0.01';

1;

=head1 Object model

=head2 Lists

Lists can be nested one level deep.

Nested lists are not represented as nested lists, but as one linear list.
Items that belong to a sublist have a non-empty C<superItemListId> which points
to the item they are subsidiary to:

    - item 1
        - subitem 1.1
        - subitem 1.2

is represented as this list:

    {
        entries => [
            { text => 'item 1', id => 'foo1' },
            { text => 'item 1.1', id => 'foo2', superListItemId => 'foo1' },
            { text => 'item 1.2', id => 'foo3', superListItemId => 'foo1' },
        ],
    }

=head1 SEE ALSO

L<https://github.com/kiwiz/gkeepapi>

=cut
