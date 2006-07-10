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

sub get_triples {
    my $self = shift;
    my @ret_array = ();
    
    foreach my $stmnt ($self->get_statements(@_)) {
        my $obj_value;
        my $obj = $stmnt->getObject;
        
        if ($obj->isa('RDF::Core::Literal')) {
            $obj_value = $obj->getValue;
        }
        else {
            $obj_value = $obj->getURI;
        }
        
        push @ret_array, [ $stmnt->getSubject->getURI,
                           $stmnt->getPredicate->getURI,
                           $obj_value ];
    }
    
    return @ret_array;
}
    
sub get_statements {
    my $self = shift;
    my @ret_array = ();

    my $enum = $self->get_enumerator(@_);
    my $stmt = $enum->getFirst;
  
    while ( defined($stmt)) {
        push @ret_array, $stmt;
        $stmt = $enum->getNext;
    }
    
    return @ret_array;
}

sub new_bnode {
    my $self = shift;
    return $self->{NodeFactory}->newResource;
}

sub new_resource {
    my $self = shift;
    my $val = shift;
    return RDF::Core::Resource->new($val);
}

sub new_literal {
    my $self = shift;
    my ($val, $lang, $type) = @_;
    return RDF::Core::Literal->new($val, $lang, $type);
}

##
sub get_enumerator {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my ($subj, $pred, $obj) = (undef, undef, undef);

    if (defined($s)) {
       $subj = ref($s) ? $s : RDF::Core::Resource->new( $self->{ExpandQNames} ? $self->qname2resolved($s) : $s);
    }    
    if (defined($p)) {
        $pred = ref($p) ? $p : RDF::Core::Resource->new( $self->{ExpandQNames} ? $self->qname2resolved($p) : $p);
    }    
    if (defined($o)) {
        if ( ref( $o ) ) {
            $obj = $o;
        }
        else {
            my $testval = $self->{ExpandQNames} ? $self->qname2resolved($o) : $o;
            my $type = $self->get_perl_type( $testval );
            if ( $type eq 'resource' ) {
                $obj = RDF::Core::Resource->new( $testval);
            }
            else {
                $obj  = RDF::Core::Literal->new("$testval");
            }
        }
    }

    return $self->{Model}->getStmts($subj, $pred, $obj);
}
##

sub remove_statements {
    my $self = shift;

    my $del_count = 0;
    my $enum = $self->get_enumerator(@_);
    my $stmt = $enum->getFirst;
  
    while ( defined($stmt)) {
        $self->{Model}->removeStmt($stmt);
        $stmt = $enum->getNext;
        $del_count++;
    }

    return $del_count;
}

sub assert_literal {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my $subj = ref($s) ? $s : RDF::Core::Resource->new($s);
    my $pred = ref($p) ? $p : $subj->new($p);
    my $obj  = ref($o) ? $o : RDF::Core::Literal->new($o);
    $self->{Model}->addStmt(
        RDF::Core::Statement->new($subj, $pred, $obj)
    );
}

sub update_literal {
    my $self = shift;
    my ($s, $p, $o, $new) = @_;

    my $count = $self->remove_statements($s, $p, $o);
    warn "More than one resource removed.\n" if $count > 1;
    return $self->assert_literal($s, $p, $new);
}

sub assert_resource {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my $subj = ref($s) ? $s : RDF::Core::Resource->new($s);
    my $pred = ref($p) ? $p : $subj->new($p);
    my $obj  = ref($o) ? $o : RDF::Core::Resource->new($o);

    $self->{Model}->addStmt(
        RDF::Core::Statement->new($subj, $pred, $obj)
    );
}

sub update_resource {
    my $self = shift;
    my ($s, $p, $o, $new) = @_;

    my $count = $self->remove_statements($s, $p, $o);
    warn "More than one resource removed.\n" if $count > 1;
    return $self->assert_resource($s, $p, $new);
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

    my ($subj, $pred, $obj) = (undef, undef, undef);

    if (defined($s)) {
       $subj = ref($s) ? $s : RDF::Core::Resource->new($s);
    }    
    if (defined($p)) {
        $pred = ref($p) ? $p : RDF::Core::Resource->new($p);
    }    
    if (defined($o)) {
        $obj  = ref($o) ? $o : RDF::Core::Literal->new($o);
    }

    return $self->{Model}->countStmts($subj, $pred, $obj);
}

sub execute_query {
    my $self = shift;
    my ($q) = @_;
    return $self->query->query($q); 
}

sub deep_prophash {
    my $self = shift;
    my $resource = shift;
    my %found_data = ();
    my %seen_keys = ();
    
    foreach my $stmnt ( 
$self->get_statements($resource, undef, undef)) {
        my $pred = $stmnt->getPredicate->getLabel,
        my $obj  = $stmnt->getObject;
        my $value;
        
        if ( $obj->isLiteral ) {
            $value = $obj->getLabel;
        }
        else {
            # if nothing else in the model points to this resource
            # just give the URI as a literal string
            if ( $self->count( $obj, undef, undef) == 0 ) {
                $value = $obj->getLabel;
            }
            # otherwise, recurse
            else {
                $value = $self->deep_prophash( $obj );
            }

        }

        my $key = $self->resolved2prefixed( $pred ) || $pred;
        
        if ( $seen_keys{$key} ) {
            if ( ref $found_data{$key} eq 'ARRAY' ) {
                push @{$found_data{$key}}, $value;
            }
            else {
                my $was = $found_data{$key};
                $found_data{$key} = [$was, $value];
            }
        }
        else {
            $found_data{$key} = $value;
        }
        
        $seen_keys{$key} = 1;
        
    }
    
    return \%found_data;
}

#---------------------------------------------------------------------
# Sub-object Accessors
#---------------------------------------------------------------------
sub query {
    my $self = shift;
    my $new = shift;
    
    if (defined($new)) {
        $self->{Query} = $new;
        return 1;
    }

    unless (defined($self->{Query})) {
        $self->{Query} = RDF::Core::Query->new(
            Evaluator => $self->evaluator,
        );
    }
    
    return $self->{Query};
}

sub evaluator {
    my $self = shift;
    my $new = shift;
    
    if (defined($new)) {
        $self->{Evaluator} = $new;
        return 1;
    }
    
    unless (defined($self->{Evaluator})) {
        $self->{Evaluator} = RDF::Core::Evaluator->new(
            Model => $self->{Model},
            Factory => $self->{NodeFactory},
            Functions => $self->function,
            Namespaces => $self->{Namespaces},
        );
    }
    
    return $self->{Evaluator};
}

sub function {
    my $self = shift;
    my $new = shift;
    
    if (defined($new)) {
        $self->{Function} = $new;
        return 1;
    }
    
    unless (defined($self->{Function})) {
        $self->{Function} = RDF::Core::Function->new(
            Data => $self->{Model},
            Schema => $self->schema,
            Factory => $self->{NodeFactory},
        );
    }
    return $self->{Function};
}

sub schema {
    my $self = shift;
    my $new = shift;
    
    if (defined($new)) {
        $self->{Schema} = $new;
        return 1;
    }
    
    unless (defined($self->{Schema})) {
        $self->{Schema} = RDF::Core::Schema->new(
            Storage => $self->{Model}->getOptions->{Storage},
            Factory => $self->{NodeFactory},
        );
    }   
    return $self->{Schema};
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
