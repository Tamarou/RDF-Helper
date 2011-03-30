package RDF::Helper::Statement;
use Moose;
use Moose::Util::TypeConstraints;

class_type 'RDF::Helper::Node::Resource';
class_type 'RDF::Helper::Node::Literal';
class_type 'RDF::Helper::Node::Blank';

subtype 'RDF::Helper::Type::ValidNode' => as
'RDF::Helper::Node::Resource|RDF::Helper::Node::Literal|RDF::Helper::Node::Blank';

has [qw(subject predicate object)] => (
    isa      => 'RDF::Helper::Type::ValidNode',
    is       => 'ro',
    required => 1
);

sub BUILDARGS {
    my $class = shift;
    my ( $s, $p, $o ) = @_;
    return { subject => $s, predicate => $p, object => $o };
}

package RDF::Helper::Node;
use strict;
use warnings;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    if ( scalar @_ == 1 ) {
        my $thing = shift;
        if ( ref($thing) && $thing->isa('URI') ) {
            return 'RDF::Helper::Node::Resource'->new( { uri => $thing } );
        }
        else {
            return bless( { value => $thing }, 'RDF::Helper::Node::Literal' );
        }

    }
    my %args = @_;
    return bless \%args, $class;
}

sub is_resource {
    my $self = shift;
    return $self->isa('RDF::Helper::Node::Resource');
}

sub is_literal {
    my $self = shift;
    return $self->isa('RDF::Helper::Node::Literal');
}

sub is_blank {
    my $self = shift;
    return $self->isa('RDF::Helper::Node::Blank');
}

sub as_string {
    my $self = shift;
    if ( $self->is_literal ) {
        return $self->literal_value;
    }
    elsif ( $self->is_resource ) {
        return $self->uri_value;
    }
    else {
        return $self->blank_identifier;
    }
}

package RDF::Helper::Node::Resource;
use Moose;
use URI;
extends qw(Moose::Object RDF::Helper::Node);

has uri_value => (
    isa      => 'Str',
    init_arg => 'uri',
    is       => 'ro',
    required => 1,
);

sub uri { URI->new( shift->uri_value ) }

package RDF::Helper::Node::Literal;
use Moose;
extends qw(Moose::Object RDF::Helper::Node);

has value => (
    isa      => 'Str',
    reader   => 'literal_value',
    required => 1,
);

has datatype => (
    is        => 'ro',
    predicate => 'has_datatype'
);

has language => (
    reader => 'literal_value_language',
);

sub literal_datatype {
    my $self = shift;
    return unless defined $self->has_datatype;
    return URI->new( $self->datatype );
}


package RDF::Helper::Node::Blank;
use Moose;
extends qw(Moose::Object RDF::Helper::Node);

has identifier => (
    isa      => 'Str',
    reader   => 'blank_identifier',
    required => 1
);

1