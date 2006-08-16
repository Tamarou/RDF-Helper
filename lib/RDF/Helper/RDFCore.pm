package RDF::Helper::RDFCore;
use strict;
use warnings;
use RDF::Core::Model;
use RDF::Core::Model::Serializer;
use RDF::Core::Model::Parser;
use RDF::Core::Enumerator;
use RDF::Core::Statement;
use RDF::Core::Resource;
use RDF::Core::Literal;
use RDF::Core::Storage::Memory;
use RDF::Core::Storage::DB_File;
use RDF::Core::NodeFactory;
use RDF::Core::Evaluator;
use RDF::Core::Query;
use RDF::Core::Schema;
use RDF::Helper::PerlConvenience;
use Data::Dumper;
use Cwd;
use vars qw( @ISA );
@ISA = qw( RDF::Helper RDF::Helper::PerlConvenience );

sub new {
    my $proto = shift;
    my %args = @_;
    my $class = ref($proto) || $proto;
    
    unless (defined($args{BaseURI})) {
        $args{BaseURI} = 'file:' . getcwd();
    }


    unless (defined($args{Model})) {
        $args{Model} = RDF::Core::Model->new( Storage => RDF::Core::Storage::Memory->new() );
    }
    
    unless (defined($args{NodeFactory})) {
        $args{NodeFactory} = RDF::Core::NodeFactory->new(BaseURI => $args{BaseURI});
    }
    
    unless (defined($args{Namespaces})) {
        $args{Namespaces} = {
            rdf => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
        };
    }

    unless (defined($args{Namespaces}->{'#default'})) {
        $args{Namespaces}->{'#default'} = $args{BaseURI};
    }
    
    my %foo  = reverse %{$args{Namespaces}};
    $args{_NS} = \%foo;
    
    return bless \%args, $class;
}

sub new_native_bnode {
    my $self = shift;
    my $id = shift;
    return $self->{NodeFactory}->newResource($id);
}

sub new_native_resource {
    my $self = shift;
    my $val = shift;
    return RDF::Core::Resource->new($val);
}

sub new_native_literal {
    my $self = shift;
    my ($val, $lang, $type) = @_;
    return RDF::Core::Literal->new($val, $lang, $type);
}

##
sub get_enumerator {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my ($subj, $pred, $obj) = $self->normalize_triple_pattern( $s, $p, $o );

    my @nodes = map { $self->helper2native($_) } ( $subj, $pred, $obj );

    return RDF::Helper::RDFCore::Enumerator->new(
        statement => RDF::Core::Statement->new(@nodes),
        model => $self->model,
    );
}
##

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

sub remove_statements {
    my $self = shift;

    my $del_count = 0;

    my $e = $self->get_enumerator(@_);
    while( my $s = $e->next ) {    
        my @nodes = ();
        foreach my $type qw( subject predicate object ) {
            push @nodes, $self->helper2native( $s->$type );
        }
        $self->{Model}->removeStmt( RDF::Core::Statement->new(@nodes) );
        $del_count++;
    }

    return $del_count;
}

sub assert_literal {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my $subj = ref($s) ? $s->isa('RDF::Helper::Node') ? $self->helper2native( $s ) : $s : $self->new_native_resource( $self->{ExpandQNames} ? $self->qname2resolved($s) : $s);
    
    my $pred = ref($p) ? $p->isa('RDF::Helper::Node') ? $self->helper2native( $p ) : $p : $self->new_native_resource( $self->{ExpandQNames} ? $self->qname2resolved($p) : $p);
    
    my $obj  = ref($o) ? $o->isa('RDF::Helper::Node') ? $self->helper2native( $o ) : $o : $self->new_native_literal("$o");

    #warn Dumper( $subj, $pred, $obj );
    $self->{Model}->addStmt(
        RDF::Core::Statement->new($subj, $pred, $obj)
    );
}

sub assert_resource {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my $subj = ref($s) ? $s->isa('RDF::Helper::Node') ? $self->helper2native( $s ) : $s : $self->new_native_resource( $self->{ExpandQNames} ? $self->qname2resolved($s) : $s);
    
    my $pred = ref($p) ? $p->isa('RDF::Helper::Node') ? $self->helper2native( $p ) : $p : $self->new_native_resource( $self->{ExpandQNames} ? $self->qname2resolved($p) : $p);
    
    my $obj = ref($o) ? $o->isa('RDF::Helper::Node') ? $self->helper2native( $o ) : $o : $self->new_native_resource( $self->{ExpandQNames} ? $self->qname2resolved($o) : $o);

    #warn Dumper( $subj, $pred, $obj );
    $self->{Model}->addStmt(
        RDF::Core::Statement->new($subj, $pred, $obj)
    );
}

#---------------------------------------------------------------------
# Batch inclusions
#---------------------------------------------------------------------

sub include_model {
    my $self = shift;
    my $model = shift;

    my $enum = $model->getStmts;
    my $statement = $enum->getFirst;

    while ( defined( $statement )) {
        $self->{Model}->addStmt( $statement );
        $statement = $enum->getNext;
    }
    return 1;   
}

sub include_rdfxml {
    my $self = shift;
    my %args = @_;
    my $p;
    
    if (defined( $args{filename} ) ) {
        $p = RDF::Core::Model::Parser->new( Model => $self->{Model},
                                            Source => $args{filename}, 
                                            SourceType => 'file',
                                            BaseURI => $self->{BaseURI} );
    }
    elsif (defined( $args{xml} ) ) {
        $p = RDF::Core::Model::Parser->new( Model => $self->{Model},
                                            Source => $args{xml}, 
                                            SourceType => 'string',
                                            BaseURI => $self->{BaseURI} );
    }
    else {
        die "Missing argument. Yous must pass in an 'xml' or 'filename' argument";
    }
    $p->parse;
    return 1;
}

sub serialize {
    my $self = shift;
    my %args = @_;
    
    my $xml = '';
    my $serializer = RDF::Core::Model::Serializer->new(
        Model => $self->{Model},
        Output => \$xml,
        BaseURI => $self->{BaseURI},
    );
    $serializer->serialize();
    return $xml;
}

sub count {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my ($subj, $pred, $obj) = $self->normalize_triple_pattern( $s, $p, $o );

    my @nodes = map { $self->helper2native($_) } ( $subj, $pred, $obj );

    #warn "TESTING: " . Dumper( $subj, $pred, $obj );
    return $self->{Model}->countStmts(@nodes);
}

sub execute_query {
    my $self = shift;
    my ($q) = @_;
    return $self->query->query($q); 
}

    
sub model {
    my $self = shift;
    my $new = shift;

    if (defined($new)) {
        $self->{Model} = $new;
        return 1;
    }

    unless (defined($self->{Model})) {
        $self->{Model} = RDF::Code::Model->new();
    }
    return $self->{Model};
}

sub node_factory {
    my $self = shift;
    my $new = shift;

    if (defined($new)) {
        $self->{NodeFactory} = $new;
        return 1;
    }

    unless (defined($self->{NodeFactory})) {
        $self->{NodeFactory} = RDF::Core::NodeFactory->new(BaseURI => $self->{BaseURI});
    }
    return $self->{NodeFactory};
}

sub get_uri {
    my $self = shift;
    my ($name, $suffix) = @_;

    return $self->{Namespaces}->{$name} . $suffix;
}

sub ns {
    my $self = shift;
    my ($name, $uri) = @_;

    if (defined($uri)) {
        $self->{Namespaces}->{$name} = $uri;
        return 1;
    }

    return $self->{Namespaces}->{$name};
}

#---------------------------------------------------------------------
# Redland-specific enumerator
#---------------------------------------------------------------------

package RDF::Helper::RDFCore::Enumerator;
use strict;
use warnings;
use RDF::Helper::Statement;
use Data::Dumper;

sub new {
    my $proto = shift;
    my %args = @_;
    my $class = ref($proto) || $proto;
    die "Not enough args" unless $args{model};
    my $statement = delete $args{statement};
    
    #warn "ENUM" . Dumper( $statement );
    
    my @nodes = ();
    if (defined( $statement )) {
        foreach my $type qw( getSubject getPredicate getObject ) {
            push @nodes, $statement->$type;
        }
    }
    my $self = bless \%args, $class;
    $self->{stream} = $self->{model}->getStmts( @nodes );
    $self->{first_statement} = $self->{stream}->getFirst;
    return $self;
}

sub next {
    my $self = shift;
    my $in = undef;
    if ( defined $self->{stream} ) {
        if ( exists( $self->{first_statement} )) {
            $in = delete $self->{first_statement};
        }
        else {
            $in = $self->{stream}->getNext;
        }
    }

    unless ( $in ) {
        delete $self->{stream};
        return undef;
    }

    my $s = undef;
    my @nodes = ();
    foreach my $type qw( getSubject getPredicate getObject ) {
        push @nodes, process_node( $in->$type );
    }
    return RDF::Helper::Statement->new( @nodes )
}

sub process_node {
    my $in = shift;
    
    my $out = undef;
    if ( $in->isLiteral ) {
        $out = RDF::Helper::Node::Literal->new(
            value => $in->getValue,
            language => $in->getLang,
            datatype => $in->getDatatype,
        );
    }
    else {
        $out = RDF::Helper::Node::Resource->new( uri => $in->getURI );
    }
    return $out;
}

1;

__END__

=head1 NAME

RDF::Helper::Core- RDF::Helper bridge for RDF::Core

=head1 SYNOPSIS

  my $model = RDF::Core::Model->new( 
      Storage => RDF::Core::Storage::Postgres->new( %storage_options )
  );

  my $rdf = RDF::Helper->new(
    Namespaces => \%namespaces,
    BaseURI => 'http://domain/NS/2004/09/03-url#'
  );

=head1 DESCRIPTION

RDF::Helper::RDFCore is the bridge class that connects RDF::Helper's facilites to RDF::Core and should not be used directly. 

See L<RDF::Helper> for method documentation

=head1 AUTHOR

Kip Hampton, khampton@totalcinema.com

=head1 COPYRIGHT

Copyright (c) 2004 Kip Hampton.  All rights reserved.

=head1 LICENSE

This module is free sofrware; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<RDF::Helper> L<RDF::Core>.

=cut
