package Net::Google::Keep::Downsync;
use Moo 2;

use Net::Google::Keep::Item;

use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

use Carp 'croak';
use Path::Class 'file';

=begin rant

We hand-roll the JSON pluggable parser
because Moo::Role/Role::Tiny has no nice parametrized role, like

    with 'Moo::AggregateObject', 'json' => { options => {}, class => 'JSON' }; 

=cut

has 'json_options' => (
    is => 'lazy',
    default => sub { [] },
);

has 'json_class' => (
    is => 'lazy',
    default => sub { 'JSON' },
);

has 'json' => (
    is => 'lazy',
    default => sub($self) {
        my $class = $self->json_class;
        (my( $file ) = $class ) =~ s{::|'}{/}g;
        require "$file.pm"; # dies if the file is not found
        $class->new( @{ $self->json_options } )->utf8
    },
);

# where will we store the settings?

sub inflate_tree( $self, $tree ) {
    my @result;
    # parse out lists, and other stuff
    my %parents;
    my %orphans;
    for my $item ( @{ $tree->{nodes}}) {
        if( $item->{parentId} eq 'root' ) {
            # a top-level entry
            my $title = $item->{title} // '<no title>';
            #warn sprintf "%s - %s", $item->{type}, $title;
            my $entries = delete( $orphans{ $item->{id}}) || [];
            $item->{_entries} = $entries;
            my $i = Net::Google::Keep::Item->new( $item );
            push @result, $i;
            $parents{ $item->{id} } = $i;
            
        } elsif(   $item->{type} eq 'LIST_ITEM'
                or $item->{type} eq 'BLOB' ) {
            my $i = Net::Google::Keep::Item->new( $item );
            
            # Have we seen the parent already?
            my $parentId = $i->parentId;
            if( my $list = $parents{ $parentId }) {
                $list->append_entry( $i );
            } else {
                $orphans{ $parentId } ||= [];
                push @{ $orphans{ $parentId }}, $i;
            };

        } else {
            croak "Unknown type '$item->{type}' in tree";
        };
    }
    if( keys %orphans ) {
        croak "Orphaned items in tree";
    };
    
    return @result
}

sub parse_string( $self, $str ) {
    my $payload = $self->json->decode( $str );
    return $self->inflate_tree( $payload )
};

sub parse_file( $self, $filename ) {
    return $self->parse_string( scalar file( $filename )->slurp( iomode => '<:raw' ))
}

sub parse_fh( $self, $fh ) {
    local $/;
    return $self->parse_string( <$fh> )
}

sub parse( $self, %options ) {
    if( exists $options{ string } ) {
        return $self->parse_string( $options{ string })
    } elsif( exists $options{ file } ) {
        return $self->parse_file( $options{ file })
    } elsif( exists $options{ fh }) {
        return $self->parse_file( $options{ file })
    } elsif( exists $options{ tree }) {
        return $self->inflate_tree( $options{ tree })
    } else {
        croak "Don't know what to parse";
    }
}

1;