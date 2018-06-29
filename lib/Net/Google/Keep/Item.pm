package Net::Google::Keep::Item;

use Moo 2;

use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

has 'kind' => (
    is => 'rw'
);
has 'id' => (
    is => 'rw'
);
has 'serverId' => (
    is => 'rw'
);
has 'parentId' => (
    is => 'ro',
    default => 'root',
);

has 'type' => (
    is => 'rw',
    default => 'NOTE',
);

has 'timestamps' => (
    is => 'lazy',
    default => sub { {} },
);

has 'title' => (
    is => 'rw'
);
has 'text' => (
    is => 'rw'
);
has 'baseVersion' => (
    is => 'rw'
);
has 'nodeSettings' => (
    is => 'lazy',
    default => sub { {} },
);

has 'isArchived' => (
    is => 'rw'
);
has 'isPinned' => (
    is => 'rw'
);
has 'color' => (
    is => 'rw'
);
has 'sortValue' => (
    is => 'rw'
);

has 'annotationsGroup' => (
    is => 'lazy',
    default => sub { {} },
);

has 'labelIds' => (
    is => 'lazy',
    default => sub { [] },
);

has 'lastSavedSessionId' => (
    is => 'rw'
);

has '_entries' => (
    is => 'lazy',
    default => sub { [] },
);

# We should respect the sort order here
sub append_entry( $self, $entry ) {
    push @{ $self->_entries }, $entry
};

sub as_json_keep( $self ) {
    my @result;
    my $s = { %$self };
    delete $s->{_entries};
    
    # downconvert labels
    # downconvert nodeSettings
    # downconvert timestamps
    
    push @result, $s;
    for my $e ( @{ $self->_entries }) {
        push @result, $e->as_json_keep;
    }
    @result
}

sub as_markdown( $self, $prefix = '' ) {
    my @result;
    
    if( $self->parentId eq 'root' ) {
        push @result, '---';
        push @result, $self->frontMatter;
    };
    
    if( defined $self->title ) {
        push @result, "=" . $self->title;
    };
    
    my $vis;
    if( $self->type eq 'LIST_ITEM' ) {
        $vis = "$prefix[ ] " . $self->text;
    } else {
        my $t = $self->text;
        # Indent by $prefix
        $t =~ s!^!$prefix!gm;
        $vis = $t;
    }
    
    push @result, $vis if defined $vis;
    for my $e ( @{ $self->_entries }) {
        # How can we indent stuff here?!
        # Currently only indent stuff if we are list items?!
        if( $self->type eq 'LIST_ITEM' ) {
            $prefix = "    $prefix";
        };
        push @result, $e->as_markdown();
    }
    
    my $res = join "\n", @result;
    "$res\n"
}

# This is where we store data that doesn't map to MarkDown properly
# like timestamps, labels etc.
sub frontMatter( $self ) {
}

1;