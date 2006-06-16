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
@ISA = qw( RDF::Helper::PerlConvenience );

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

sub get_enumerator {
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

    return $self->{Model}->getStmts($subj, $pred, $obj);
}


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

sub exists {
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

    return $self->{Model}->existsStmt($subj, $pred, $obj);
}

sub execute_query {
    my $self = shift;
    my ($q) = @_;
    return $self->query->query($q); 
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

RDF::Core::Helper - A wrapper around L<RDF::Core> to simplify RDF-related tasks

=head1 SYNOPSIS

  my $rdf = new RDF::Core::Helper(
    Model => new RDF::Core::Model(
      Storage => new RDF::Core::Storage::Postgres(
        ConnectStr => 'dbi:Pg:dbname=rdf',
        DBUser     => 'dbuser',
        DBPassword => 'dbpassword',
        Model      => 'rdf-model',
      )
    ),
    BaseURI => 'http://domain/NS/2004/09/03-url#'
  );

=head1 DESCRIPTION

This module intends to simplify many of the methods and objects needed for interacting
with an RDF datastore.  URI handling, resource creation, and node insertion/updating/deletion
is all simplified in this object.  L<RDF::Core> itself, is quite simple, though it is due
to this simplicity that one's code must be verbose in order to use it effectively.  To ease the
process of using an RDF datastore, L<RDF::Core::Helper> simplifies the commonly-used
methods for accessing RDF data.

=head2 CONSTRUCTOR

  my $helper = new RDF::Core::Helper( Model => $model );

Constructor; instantiates a new instance of the Helper class.  By
supplying arguments to this constructor you can bind this instance
to an existing RDF model and/or a "Node Factory".

=head2 METHODS

=over 4

=item blank_node

  my $new_node = $helper->blank_node;

Creates and returns a new node that can be used to create and add
new resources.

=item get_triples

  my $node_array = $helper->get_triples($subject, $predicate, $object);

Retrieves triples from the datastore based on the values supplied
(similar to L</get_statements>), except the statement's individual
elements - the subject, predicate and object - are expanded into an
array reference.

=item get_statements

  my $stmt_array = $helper->get_statements($subject, $predicate, $object);
  foreach (@$stmt_array) {
    # Magic happens here
  }

Returns an array representation of the enumerator returned by
L</get_enumerator>.

=item new_resource

  my $resource = $helper->new_resource("urn:root:name");

Creates and returns a new resource based on the supplied value.  This
is mainly useful for calling the various L<RDF::Core> methods that
require a properly-formed object be supplied.

=item new_literal

  my $literal = $helper->new_literal("RDF Rocks");

Creates and returns a new literal based on the supplied value.  This
is mainly useful for calling the various L<RDF::Core> methods that
require a properly-formed object be supplied.

=item get_enumerator

  my $enum = $helper->get_enumerator($subject, $predicate, $object);

Retrieves statements from the datastore based on the values supplied.
Each value could be either a proper L<RDF::Core> object, a URI, or
C<undef>.  Whatever the values are however, they are automatically
converted to L<RDF::Core::Resource> or L<RDF::Core::Literal> objects.

This method is used by several of the other L<RDF::Core::Helper>
methods, and is thus built to be generic.

=item remove_statements

  my $count = $helper->remove_statements($subject, $predicate, $object);

Removes statements from the datastore that match the supplied
triple.  The number of statements removed is returned.

=item assert_literal

  $helper->assert_literal($subject, $predicate, $literal);

Asserts the supplied statement into the datastore as a literal value.

=item update_literal

  $helper->update_literal($subject, $predicate, $old_literal, $new_literal);

Changes the value of the literal identified by the supplied
statement.  This is achieved by first removing the old statement, and
then asserting the statement with the new literal.

=item assert_resource

  $helper->assert_resource($subject, $predicate, $resource);

Asserts the supplied statement into the datastore as a resource.

=item update_resource

  $helper->update_resource($subject, $predicate, $old_resource, $new_resource);

Changes the resource identified by the supplied statement.  This is
similar in functionality to L</update_literal>.

=item include_model

  $helper->include_model($model);

This method can be used to merge multiple models into one.  If an
additional model is created as a L<RDF::Core::Model> object, it's
statements can be extracted and added to the model the current Helper
object encapsulates.

=item include_rdfxml

  $helper->include_rdfxml(filename => $file);
  $helper->include_rdfxml(xml => $xml_string);

Includes the RDF statements present in the given file or XML string
into the current RDF model.

=item serialize_model

  my $xml_string = $helper->serialize_model();

Serializes the RDF model as XML, and returns it as a string.

=item count

  my $num_stmts = $helper->count($subject, $predicate, $object);

Returns the number of statements currently stored in the RDF model
that match the given statement.

=item exists

  if ($helper->exists($subject, $predicate, $object)) {
    # Magic happens here
  }

Returns a boolean value indicating if any statements matching the
given values exist in the RDF model.

=item get_uri

  my $uri = $helper->get_uri('rdf', 'type');
  # Returns "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  $helper->assert('urn:subject', $uri, $classType);

This helper method makes creating predicate and other URIs easier.
Instead of having to copy-and-paste the same namespace URI when
asserting statements, this can let you combine the namespace prefix
with the predicate type to create a fully-formed URI.

There are other methods for doing this though, using constants to
define both the namespace and specific predicate URIs.  TIMTOWTDI.

=item model

  my $model = $helper->model;
  $helper->model($new_model);

Accessor method providing access to the internal RDF model object.
This can be used to change which model this helper object uses.

=item node_factory

  my $node_factory = $helper->node_factory;
  $helper->node_factory($new_node_factory);

Accessor method providing access to the internal RDF node factory
object.  This can be used to change the factory this helper object
uses.

=item ns

  $helper->ns('foaf', 'http://xmlns.com/foaf/0.1/');
  my $rdf_ns = $helper->ns('rdf');
  # Returns "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

Accessor method providing access to the internal Namespaces hash.
The L</constructor> allows you to supply as many namespace prefix to
URI definitions, but it may sometimes be necessary to change this
after the fact.

By invoking this method with two arguments, it sets a new or updates
a current namespace prefix with a URI.  If supplied with only one
argument, it will return the URI for that namespace prefix if available.

=back

=head1 AUTHOR

Kip Hampton, khampton@totalcinema.com

=head1 COPYRIGHT

Copyright (c) 2004 Kip Hampton.  All rights reserved.

=head1 LICENSE

This module is free sofrware; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<RDF::Core>.

=cut
