package Net::Google::Keep::List;

use Moo 2;

use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

extends 'Net::Google::Keep::Item';

has 'entries' => (
    is => 'lazy',
    default => sub { [] },
);

# We should respect the sort order here
sub append_entry( $self, $entry ) {
    push @{ $self->entries }, $entry
};

1;