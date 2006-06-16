package RDF::Helper::RDFRedland;
use strict;
use warnings;
use RDF::Redland;
use RDF::Helper::RDFRedland::Query;
use Cwd;
use RDF::Helper::PerlConvenience;
use RDF::Helper::Object;
use vars qw( @ISA );
use Data::Dumper;
@ISA = qw( RDF::Helper::PerlConvenience );

sub new {
    my $proto = shift;
    my %args = @_;
    my $class = ref($proto) || $proto;
    
    unless (defined($args{BaseURI})) {
        $args{BaseURI} = 'file:' . getcwd();
    }

    unless (defined($args{Model})) {
        $args{Model} = 
            RDF::Redland::Model->new( 
                RDF::Redland::Storage->new(
                    "hashes", "temp", "new='yes',hash-type='memory'"
                ),
                ""
            );
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


sub new_resource {
    my $self = shift;
    my $val = shift;
    return RDF::Redland::Node->new(
        RDF::Redland::URI->new($val)
    );
}

sub new_literal {
    my $self = shift;
    my ($val, $lang, $type) = @_;
    if ( defined ($type) and !ref( $type ) ) {
        $type = RDF::Redland::URI->new($type);
    }
    return RDF::Redland::Node->new_literal($val, $type, $lang);
}

sub new_bnode {
    return RDF::Redland::Node->new_from_blank_identifier();
}

sub assert_literal {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my $subj = ref($s) ? $s : RDF::Redland::Node->new(
                                  RDF::Redland::URI->new($self->{ExpandQNames} ? $self->qname2resolved($s) : $s)
                              );
    my $pred = ref($p) ? $p : RDF::Redland::Node->new(
                                  RDF::Redland::URI->new($self->{ExpandQNames} ? $self->qname2resolved($p) : $p)
                              );
    my $obj  = ref($o) ? $o : RDF::Redland::Node->new_literal($o);

    $self->{Model}->add_statement($subj, $pred, $obj);
}

sub assert_resource {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my $subj = ref($s) ? $s : RDF::Redland::Node->new(
                                  RDF::Redland::URI->new($self->{ExpandQNames} ? $self->qname2resolved($s) : $s)
                              );
                              
    my $pred = ref($p) ? $p : RDF::Redland::Node->new(
                                  RDF::Redland::URI->new($self->{ExpandQNames} ? $self->qname2resolved($p) : $p)
                              );
                              
    my $obj  = ref($o) ? $o : RDF::Redland::Node->new(
                                  RDF::Redland::URI->new($self->{ExpandQNames} ? $self->qname2resolved($o) : $o)
                              );

    $self->{Model}->add_statement($subj, $pred, $obj);
}


sub remove_statements {
    my $self = shift;

    my $del_count = 0;
    
    my $stream = $self->get_enumerator(@_);
    while($stream && !$stream->end) {
        $self->{Model}->remove_statement( $stream->current );
        $del_count++;
        $stream->next;
    }

    return $del_count;
}

sub update_node {
    my $self = shift;
    my ($s, $p, $o, $new) = @_;

    my $update_method = undef;
    
    # first, try to grok the ype form the incoming node
    
    if ( ref( $new ) and $new->isa('RDF::Redland::Node') ) {
        if ( $new->is_literal ) {
            $update_method = 'update_literal';
        }
        elsif ( $new->is_resource or $new->is_blank) {
            $update_method = 'update_resource';
        }
    }
    
    unless ( $update_method ) {
        foreach my $stmnt ( $self->get_statements( $s, $p, $o ) ) {
            my $obj = $stmnt->object;
            if ( $obj->is_literal ) {
                $update_method = 'update_literal';
            }
            elsif ( $obj->is_resource or $obj->is_blank) {
                $update_method = 'update_resource';
            }
            else {
                warn "updating unknown node type, falling back to literal.";
                $update_method = 'update_literal';
            }
        }
    }
    return $self->$update_method( $s, $p, $o, $new );
}

sub update_literal {
    my $self = shift;
    my ($s, $p, $o, $new) = @_;

    my $count = $self->remove_statements($s, $p, $o);
    warn "More than one resource removed.\n" if $count > 1;
    return $self->assert_literal($s, $p, $new);
}

sub update_resource {
    my $self = shift;
    my ($s, $p, $o, $new) = @_;

    my $count = $self->remove_statements($s, $p, $o);
    warn "More than one resource removed.\n" if $count > 1;
    return $self->assert_resource($s, $p, $new);
}

sub get_enumerator {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my ($subj, $pred, $obj) = (undef, undef, undef);

    if (defined($s)) {
       $subj = ref($s) ? $s : RDF::Redland::Node->new(
                                  RDF::Redland::URI->new($s)
                              );
    }    
    if (defined($p)) {
        $pred = ref($p) ? $p : RDF::Redland::Node->new(
                                  RDF::Redland::URI->new($p)
                              );
    }    
    if (defined($o)) {
        $obj  = ref($o) ? $o : RDF::Redland::Node->new_literal($o);
    }

    return $self->{Model}->find_statements(
        RDF::Redland::Statement->new( $subj, $pred, $obj )
    );
}


sub get_triples {
    my $self = shift;
    my @ret_array = ();
    
    foreach my $stmnt ( $self->get_statements(@_)) {
        my $subj = $stmnt->subject;
        my $obj  = $stmnt->object;
  
        my $subj_value = $subj->is_blank  ? $subj->blank_identifier : $subj->uri->as_string;
        my $obj_value;
        if ( $obj->is_literal ) {
            $obj_value = $obj->literal_value;
        } elsif ($obj->is_resource) {
            $obj_value = $obj->uri->as_string;
        } else {
            $obj_value = $obj->as_string;
        }
        #my $obj_value;
        #eval {
        #    $obj_value  = $obj->is_literal ? $obj->literal_value     : $obj->uri->as_string;
        #};
        #if ($@) {
            #warn $@;
            #warn "predicate: " . $stmnt->predicate->uri->as_string;
            #warn qq{\$obj = "$obj"};
            #warn qq{\$obj->is_literal = "} . $obj->is_literal . '"';
            #warn qq{\$obj->is_resource = "} . $obj->is_resource . '"';
            #warn qq{\$obj->is_blank = "} . $obj->is_blank . '"';
            #warn qq{\$obj->uri = "} . $obj->uri . '"';
            #warn qq{\$obj_value = "$obj_value"};
            #die;
        #}
        
        push @ret_array, [ $subj_value,
                           $stmnt->predicate->uri->as_string,
                           $obj_value ];
    }
    
    return @ret_array;
}

sub get_statements {
    my $self = shift;
    my @ret_array = ();

    my $stream = $self->get_enumerator(@_);
    while( $stream && !$stream->end ) {
        push @ret_array, $stream->current;
        $stream->next;
    }
    
    return @ret_array;
}

sub exists {
    my $self = shift;
    if ( $self->count( @_ ) > 0 ) {
        return 1;
    }
    return 0;
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
    
    while( $stream && !$stream->end ) {
        $retval++;
        $stream->next;
    }
    
    return $retval;
    
}

#---------------------------------------------------------------------
# Batch inclusions
#---------------------------------------------------------------------

sub include_model {
    my $self = shift;
    my $model = shift;

    my $stream = $model->as_stream;
    
    while( $stream && !$stream->end ) {
        $self->model->add_statement( $stream->current );
        $stream->next;
    }
    
    return 1;   
}

sub include_rdfxml {
    my $self = shift;
    my %args = @_;
    my $p = RDF::Redland::Parser->new('rdfxml');
    
    my $base_uri = RDF::Redland::URI->new( $self->{BaseURI} );
    
    if (defined( $args{filename} ) ) {
        my $file = $args{filename};
        if ( $file !~ /^file:/ ) {
            $file = 'file:' . $file;
        }
        my $source_uri = RDF::Redland::URI->new( $file );
        $p->parse_into_model($source_uri, $base_uri, $self->model() );
    }
    elsif (defined( $args{xml} ) ) {
        $p->parse_string_into_model($args{xml}, $base_uri, $self->model() );
    }
    else {
        die "Missing argument. Yous must pass in an 'xml' or 'filename' argument";
    }
    return 1;
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
        $self->{Model} = RDF::Redland::Model->new( 
             RDF::Redland::Storage->new(
                    "hashes", "temp", "new='yes',hash-type='memory'"
             ),
             ""
        );
    }
    return $self->{Model};
}

sub serialize {
    my $self = shift;
    my %args = @_;
    
    $args{format} ||= 'rdfxml-abbrev';
    my $serializer = undef;
    # Trix is handled differently
    if ( $args{format} eq 'trix' ) {
        eval "require RDF::Trix::Serializer::Redland";
        $serializer = RDF::Trix::Serializer::Redland->new( Models => [ [$self->model] ]);
        
        # XXX: Cleanup on aisle 5...
        my $trix = $serializer->as_string();
        
        if ($args{filename}) {
            open( TRIX, $args{filename} ) || die "could not open file '$args{filename}' for writing: $! \n";
            print TRIX $trix;
            close TRIX;
            return 1;
        }
        return $trix;
    }
    
    $serializer = RDF::Redland::Serializer->new( $args{format} );
    if ($serializer->can("set_namespace")) {
        while (my ($prefix, $uri) = each %{$self->{Namespaces}}) {
            next if ($prefix eq 'rdf' or $prefix eq '#default');
            $serializer->set_namespace($prefix, RDF::Redland::URI->new($uri));
        }
    }

    if ( $args{filename} ) {
        return $serializer->serialize_model_to_file($args{filename}, RDF::Redland::URI->new($self->{BaseURI}), $self->model);
    }
    else {
        return $serializer->serialize_model_to_string( RDF::Redland::URI->new($self->{BaseURI}), $self->model)
    }
}

sub new_query {
    my $self = shift;
    my ($query_string, $query_lang) = @_;
    return RDF::Helper::RDFRedland::Query->new( $query_string, $query_lang, $self->model); 
    #return $query->execute($self->model);
}

#---------------------------------------------------------------------
# Perl convenience methods
#---------------------------------------------------------------------

sub get_perl_type {
    my $self = shift;
    my $wtf = shift;

    my $type = ref( $wtf );
    if ( $type ) {
        if ( $type eq 'ARRAY' or $type eq 'HASH' or $type eq 'SCALAR') {
            return $type;
        }
        else {
            # we were passed an object, yuk.
            # props to barrie slaymaker for the tip here... mine was much fuglier. ;-) 
            if ( UNIVERSAL::isa( $wtf, "HASH" ) ) {
                return 'HASH';
            }
            elsif ( UNIVERSAL::isa( $wtf, "ARRAY" ) ) {
                return 'ARRAY';
            }
            elsif ( UNIVERSAL::isa( $wtf, "SCALAR" ) ) {
                return 'SCALAR';
            }
            else {
                return $type;
            }
        }

    }
    else {
        if ( $wtf =~ /^(http|file|ftp|urn|shttp):/ ) {
            #warn "type for $wtf is resource";
            return 'resource';
        }
        else {
            return 'literal';
        }
    }
}

sub tied_property_hash {
    my $self = shift;
    my $lookup_uri = shift;
    eval "require RDF::Helper::RDFRedland::TiedPropertyHash";
    
    return RDF::Helper::RDFRedland::TiedPropertyHash->new( Helper => $self, ResourceURI => $lookup_uri );

}

sub property_hash {
    my $self = shift;
    my $resource = shift;
    my %found_data = ();
    my %seen_keys = ();
    
    $resource ||= $self->new_bnode;
    
    foreach my $t ( $self->get_triples( $resource ) ) {

        my $key = $self->resolved2prefixed( $t->[1] ) || $t->[1];

        if ( $seen_keys{$key} ) {
            if ( ref $found_data{$key} eq 'ARRAY' ) {
                push @{$found_data{$key}}, $t->[2];
            }
            else {
                my $was = $found_data{$key};
                $found_data{$key} = [$was, $t->[2]];
            }
        }
        else {
            $found_data{$key} = $t->[2];
        }
        
        $seen_keys{$key} = 1;
        
    }
    
    return \%found_data;
}

sub arrayref2rdf {
    my $self = shift;
    my $array     = shift;
    my $subject   = shift;
    my $predicate = shift;
    
    $subject ||= $self->new_bnode;
    
    foreach my $value (@{$array}) {
        my $type = $self->get_perl_type( $value );
                
        if ( $type eq 'HASH' ) {
            my $obj = $self->new_bnode;
            $self->assert_resource( $subject, $predicate, $obj );
            $self->hashref2rdf( $value, $obj );
        }
        elsif ( $type eq 'ARRAY' ) {
            die "Lists of lists (arrays of arrays) are not compatible with storage via RDF";
        }
        elsif ( $type eq 'SCALAR' ) {
            $self->assert_resource(
                $subject, $predicate, $$value
            );
        }
        else {
            $self->assert_literal(
                $subject, $predicate, $value
            );
        }
    }
}

sub hashref2rdf {
    my $self = shift;
    my $hash = shift;
    my $subject = shift;
    
    $subject ||= $hash->{"rdf:about"};
    $subject ||= $self->new_bnode;
    
    unless ( ref( $subject ) ) {
        $subject = $self->new_resource( $subject );
    }
    
    foreach my $key (keys( %{$hash} )) {
        next if ($key eq 'rdf:about');
        
        my $value = $hash->{$key};
        my $type = $self->get_perl_type( $value );
        my $predicate = $self->prefixed2resolved( $key );
        
        if ( $type eq 'HASH' ) {
            my $obj = $value->{'rdf:about'} || $self->new_bnode;
            $self->assert_resource( $subject, $predicate, $obj );
            $self->hashref2rdf( $value, $obj );
        }
        elsif ( $type eq 'ARRAY' ) {
            $self->arrayref2rdf( $value, $subject, $predicate );
        }
        # XXX Nacho: This part was buggy, but it's been ages since
        # I ran into this problem.
        elsif ( $type eq 'SCALAR' ) {
            $self->assert_resource(
                $subject, $predicate, $$value
            );        
        }
        else {
            $self->assert_literal(
                $subject, $predicate, $value
            );
        }
    }
}

### XXX
sub hashes_from_statement {
    my $self = shift;
    my ($s, $p, $o) = @_;
    my @lookup_subjects = ();
    my %found_data = ();
    
    foreach my $stmnt ( $self->get_statements( $s, $p, $o ) ) {
        my $subj = $stmnt->subject;
        my $key = $subj->is_resource ? $subj->uri->as_string : $subj->blank_identifier;
        $found_data{$key} = $self->hash_from_resource( $subj );
        
    }
    
    return \%found_data;
}

sub hashlist_from_statement {
    my $self = shift;
    my ($s, $p, $o) = @_;
    my @lookup_subjects = ();
    my @found_data = ();
    
    foreach my $stmnt ( $self->get_statements( $s, $p, $o ) ) {
        my $subj = $stmnt->subject;
        my $key = $subj->is_resource ? $subj->uri->as_string : $subj->blank_identifier;
        push @found_data, [$key, $self->property_hash( $subj )];
        
    }
    
    return @found_data;
}
#
sub deep_prophash {
    my $self = shift;
    my $resource = shift;
    my %found_data = ();
    my %seen_keys = ();
    
    foreach my $stmnt ( 
$self->get_statements($resource, undef, undef)) {
        my $pred = $stmnt->predicate->uri->as_string,
        my $obj  = $stmnt->object;
        my $value;
        
        if ( $obj->is_literal ) {
            $value = $obj->literal_value;
        }
        elsif ( $obj->is_resource ) {
            # if nothing else in the model points to this resource
            # just give the URI as a literal string
            if ( $self->count( $obj, undef, undef) == 0 ) {
                $value = $obj->uri->as_string;
            }
            # otherwise, recurse
            else {
                $value = $self->deep_prophash( $obj );
            }

        }
        else {
            $value = $self->deep_prophash( $obj );
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
#

sub resourcelist {
    my $self = shift;
    my ( $p, $o ) = @_;
    
    my %seen_resources = ();
    my @retval = ();
    
    foreach my $stmnt ( $self->get_statements( undef, $p, $o ) ) {
        my $s = $stmnt->subject->is_resource ? $stmnt->subject->uri->as_string : $stmnt->subject->blank_identifier;
        next if defined $seen_resources{$s};
        push @retval, $s;
        $seen_resources{$s} = 1;
    }

    return @retval;
}

sub get_object {
    my $self = shift;
    my $resource = shift;
    my %args = ref($_[0]) eq 'HASH' ? %{$_[0]} : @_;
    my $obj = new RDF::Helper::Object( RDFHelper => $self, ResourceURI => $resource, %args );
    return $obj;
}

package Dead;
### XXX:


sub execute_query {
    my $self = shift;
    my ($q) = @_;
    return $self->query->query($q); 
}


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
