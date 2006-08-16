package RDF::Helper::Statement;
use strict;
use warnings;
use URI;
use Data::Dumper;

sub new {
    my $proto = shift;
    my $class = ref( $proto ) || $proto;
    my ($s, $p, $o) = @_;
    return bless [$s, $p, $o], $class;
}

sub subject {
    my $self = shift;
    my $new = shift;
    if (defined( $new )) {
        $self->[0] = $new;
        return 1;
    }
    else {
        return $self->[0];
    }
}

sub predicate {
    my $self = shift;
    my $new = shift;
    if (defined( $new )) {
        $self->[1] = $new;
        return 1;
    }
    else {
        return $self->[1];
    }
}

sub object {
    my $self = shift;
    my $new = shift;
    if (defined( $new )) {
        $self->[2] = $new;
        return 1;
    }
    else {
        return $self->[2];
    }
}

package RDF::Helper::Node;
use strict;
use warnings;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    if ( scalar @_ == 1) {
        my $thing = shift;
        if (ref($thing) && $thing->isa('URI')) {
            return bless( { uri => $thing }, 'RDF::Helper::Node::Resource');
        }
        else {
            return bless( { value => $thing }, 'RDF::Helper::Node::Literal' );
        }

    }
    my %args = @_;
    return bless \%args, $class;
}

sub is_resource {
	my $self	= shift;
    return $self->isa('RDF::Helper::Node::Resource');
}

sub is_literal {
	my $self	= shift;
    return $self->isa('RDF::Helper::Node::Literal');
}

sub is_blank {
	my $self	= shift;
    return $self->isa('RDF::Helper::Node::Blank');
}

sub as_string {
	my $self	= shift;
	if ($self->is_literal) {
		return $self->literal_value;
	} 
	elsif ($self->is_resource) {
		return $self->uri_value;
	} 
	else {
		return $self->blank_identifier;
	}
}

package RDF::Helper::Node::Resource;
use strict;
use warnings;
use vars qw( @ISA );
use URI;
@ISA = qw( RDF::Helper::Node );

sub uri {
    my $self = shift;
    return URI->new( $self->{uri} );
}

sub uri_value {
    my $self = shift;
    return $self->{uri};
}

package RDF::Helper::Node::Literal;
use strict;
use warnings;
use vars qw( @ISA );
@ISA = qw( RDF::Helper::Node );

sub literal_datatype {
    my $self = shift;
    return undef unless defined $self->{datatype};
    return URI->new( $self->{datatype} );
}

sub literal_value {
    my $self = shift;
    return $self->{value};
}

sub literal_value_language {
    my $self = shift;
    return $self->{language};
}

package RDF::Helper::Node::Blank;
use strict;
use warnings;
use vars qw( @ISA );
@ISA = qw( RDF::Helper::Node );

sub blank_identifier {
    my $self = shift;
    return $self->{identifier};
}



