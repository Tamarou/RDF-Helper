package RDF::Helper::RDFTrine;
use strict;
use warnings;
use Data::Dumper;
our @ISA = qw( RDF::Helper RDF::Helper::PerlConvenience );


sub new {
    my $proto = shift;
    my %args = @_;
    my $class = ref($proto) || $proto;

    return bless {}, $class;
    
}


sub new_native_resource {
    my $self = shift;
    my $val = shift;
    return RDF::Trine::Node::Resource->new($val);
}


sub new_native_literal {
    my $self = shift;
    my ($val, $lang, $type) = @_;
    return RDF::Trine::Node::Literal->new($val, $lang, $type);
}


sub include_rdfxml {
    my $self = shift;
    my %args = @_;
    my $p = RDF::Trine::Parser->new('rdfxml');
    
    my $base_uri = $self->{BaseURI};

    if (defined( $args{filename} ) ) {
        my $file = $args{filename};
        if ( $file !~ /^file:/ ) {
            $file = 'file:' . $file;
        }
        $p->parse_file_into_model($base_uri, $file, $self->model() );
    }
    elsif (defined( $args{xml} ) ) {
        $p->parse_into_model($base_uri, $args{xml}, $self->model() );
    }
    else {
        die "Missing argument. Yous must pass in an 'xml' or 'filename' argument";
    }
    return 1;
}   



sub get_enumerator {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my ($subj, $pred, $obj) = $self->normalize_triple_pattern( $s, $p, $o );

    my @nodes = map { $self->helper2native($_) } ( $subj, $pred, $obj );

    return RDF::Helper::RDFTrine::Enumerator->new(
        statement => RDF::Trine::Statement->new( @nodes ),
        model => $self->model,
    );
}



sub helper2native {
    my $self = shift;
    my $in = shift;

    return undef unless $in;

    my $out = undef;
    if ( $in->is_resource ) {
        $out = $self->new_native_resource( $in->uri->as_string );
    }
    elsif ( $in->is_blank ) {
        $out = $self->new_native_bnode( $in->blank_identifier );
    }
    else {
        my $type_uri = undef;
        if ( my $uri = $in->literal_datatype ) {
            $type_uri = $uri->as_string;
        }
        $out = $self->new_native_literal( $in->literal_value, $in->literal_value_language, $type_uri
        );
    }
    return $out;
}



sub count {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my $retval = 0;

    # if no args are passed, just return the size of the model
    unless ( defined($s) or defined($p) or defined($o) ) {
        return $self->{Model}->size;
    }

    my $stream = $self->get_enumerator($s, $p, $o);

    my $e = $self->get_enumerator(@_);
    while( my $s = $e->next ) {
        $retval++;
    }

    return $retval;

}

#---------------------------------------------------------------------
# Sub-object Accessors
#---------------------------------------------------------------------

sub model {
    my $self = shift;
    my $new = shift;

    if (defined($new)) {
        $self->{Model} = $new;
        return 1;
    }

    unless (defined($self->{Model})) {
        $self->{Model} = RDF::Trine::Model->new(
             RDF::Trine::Store::Memory->new()
        );
    }
    return $self->{Model};
}


1;




package RDF::Helper::RDFTrine::Enumerator;
use strict;
use warnings;
use RDF::Trine::Statement;
use RDF::Helper::Statement;

sub new {
    my $proto = shift;
    my %args = @_;
    my $class = ref($proto) || $proto;
    die "Not enough args" unless $args{model};
    my $statement = delete $args{statement} || RDF::Trine::Statement->new( undef, undef, undef );
    my $self = bless \%args, $class;
    $self->{stream} = $self->{model}->get_statements( $statement->nodes );
    return $self;
}
##

sub next {
    my $self = shift;
    my $in = undef;
    if ( defined $self->{stream} && !$self->{stream}->end ) {
        $in = $self->{stream}->current;
        $self->{stream}->next;
    }

    unless ( $in ) {;
        delete $self->{stream};
        return undef;
    }

    my $s = undef;
    my @nodes = ();
    foreach my $type qw( subject predicate object ) {
        push @nodes, process_node( $in->$type );
    }
    return RDF::Helper::Statement->new( @nodes )
}

sub process_node {
    my $in = shift;

    my $out = undef;
    if ( $in->is_resource ) {
        $out = RDF::Helper::Node::Resource->new( uri => $in->uri_value );
    }
    elsif ( $in->is_blank ) {
        $out = RDF::Helper::Node::Blank->new( identifier => $in->blank_identifier );
    }
    else {
        my $type_uri = undef;
        if ( my $uri = $in->literal_datatype ) {
            $type_uri = $uri->as_string;
        }
        $out = RDF::Helper::Node::Literal->new(
            value => $in->literal_value,
            language => $in->literal_value_language,
            datatype => $type_uri
        );
    }
    return $out;
}

1;
__END__
