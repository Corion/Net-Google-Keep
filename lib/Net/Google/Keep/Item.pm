package Net::Google::Keep::Item;

use Moo 2;

use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

use URI::URL;

has 'kind' => (
    is => 'rw'
);
has 'id' => (
    is => 'rw'
);
has 'serverId' => (
    is => 'rw'
);

has 'parentServerId' => (
    is => 'ro',
);

has 'parentId' => (
    is => 'ro',
);

has 'type' => (
    is => 'rw',
    default => 'NOTE',
);

has 'timestamps' => (
    is => 'rw',
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
    is => 'rw',
);

has 'isArchived' => (
    is => 'rw'
);
has 'isPinned' => (
    is => 'ro'
);

has 'color' => (
    is => 'rw'
);
has 'sortValue' => (
    is => 'ro'
);

has 'checked' => (
    is => 'rw',
);

has 'annotationsGroup' => (
    is => 'rw',
);

has 'labelIds' => (
    is => 'rw',
);

has 'lastSavedSessionId' => (
    is => 'rw'
);

has 'lastModifierEmail' => (
    is => 'rw'
);

has 'roleInfo' => (
    is => 'rw'
);

has 'abuseFeedback' => (
    is => 'rw'
);

has 'moved' => (
    is => 'rw'
);

has 'shareRequests' => (
    is => 'rw'
);

has 'shareState' => (
    is => 'rw'
);

has 'reminders' => (
    is => 'rw'
);

has 'blob' => (
    is => 'rw'
);

has 'extracted_text' => (
    is => 'rw'
);

has 'errorStatus' => (
    is => 'rw'
);

has '_entries' => (
    is => 'lazy',
    default => sub { [] },
);

# We should respect the sort order here
sub append_entry( $self, $entry ) {
    push @{ $self->_entries }, $entry;
    @{ $self->_entries } = sort { $b->sortValue || 0 <=> $a->sortValue || 0 } @{ $self->_entries };
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

sub as_markdown( $self, $list=undef ) {
    my @result;


    if( $self->parentId eq 'root' ) {
        push @result, '---';
        push @result, $self->frontMatter;
    };

    if( defined $self->title ) {
        push @result, "=" . $self->title;
    };

    my $vis;
    if( $self->type eq 'LIST_ITEM') {
        my $md = '';
        if( $list ) {
            if( $self->checked) {
                $md = "[x] ";
            } else {
                $md = "[ ] ";
            };
        };
        $vis = $md . $self->text;
    } elsif( $self->type eq 'BLOB' ) {

        # Assume that we are an image?!
        # https://keep.google.com/media/v2/1syAWkKrT6bU9W79vuccdD6ye-manHTN3hHO3m6DAhvaR-JkIQ3MwkSXwZEiMwdG1o0JHkg/1FqbB9TTNPAcyJD1k9SzOR5cE1lCqzlIrDprGwI7sRLimvqzkjcExYU3CaVHeBb35sDBg6g?accept=image/gif,image/jpeg,image/jpg,image/png,image/webp,audio/aac&sz=3968
        # https://keep.google.com/media/v2/{parentServerId}/{serverId}?accept=image/gif,image/jpeg,image/jpg,image/png,image/webp,audio/aac&sz=3968
        my $url = $self->blob_url;
        $vis = sprintf "(%s)[%s]", $url, $url;

        # Should we append/keep the extracted text too?!
        # Also, how does Google Keep store the image content?!
    } else {
        $vis = $self->text;
    }

    push @result, $vis if defined $vis;
    my $is_list = $self->type eq 'LIST';
    for my $e ( @{ $self->_entries }) {
        push @result, $e->as_markdown($is_list);
    }

    my $res = join "\n", @result;
    "$res\n"
}

sub blob_url( $self ) {
    if( $self->type eq 'BLOB' ) {
        # For images at least
        my $url = 'https://keep.google.com/media/v2/{parentServerId}/{serverId}?accept=image/gif,image/jpeg,image/jpg,image/png,image/webp,audio/aac&sz=3968';
        $url =~ s!\{(\w+)\}!$self->$1()!ge;
        return URI::URL->new( $url )

    } else {
        return undef
    }
}

# This is where we store data that doesn't map to MarkDown properly
# like timestamps, labels etc.
sub frontMatter( $self ) {
}

1;