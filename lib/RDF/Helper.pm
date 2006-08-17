package RDF::Helper;
use strict;
use warnings;
use RDF::Helper::Statement;
use RDF::Helper::Object;
use vars qw($VERSION);
$VERSION = '1.05';

sub new {
    my ($ref, %args) = @_;
    my $class = delete $args{BaseInterface};
    
    unless ( $class ) {
        if ( defined( $args{Model} ) ) {
            if ( $args{Model}->isa('RDF::Redland::Model') ) {
                $class = "RDF::Redland";
            }
            elsif ( $args{Model}->isa('RDF::Core::Model') ) {
                $class = "RDF::Core";           
            }
        }
        else {
            $class = "RDF::Redland";
        }
    }
    
    $args{QueryInterface} ||= 'RDF::Helper::RDFQuery';

    if ($class eq 'RDF::Core' ) {
        require RDF::Helper::RDFCore;
        return  RDF::Helper::RDFCore->new( %args );
    }
    elsif ( $class eq 'RDF::Redland' ) {
        require RDF::Helper::RDFRedland;
        return  RDF::Helper::RDFRedland->new( %args );
    }
    elsif ( $class eq 'DBI' or $class eq 'RDF::Query' ) {
        require RDF::Helper::DBI;
        return  RDF::Helper::DBI->new( %args );
    }
    else {
        die "No Helper class defined for BaseInterface '$class'\n";
    }
}

sub get_object {
    my $self = shift;
    my $resource = shift;
    my %args = ref($_[0]) eq 'HASH' ? %{$_[0]} : @_;
    my $obj = new RDF::Helper::Object( RDFHelper => $self, ResourceURI => $resource, %args );
    return $obj;
}

sub new_query {
    my $self = shift;
    my ($query_string, $query_lang) = @_;
    
    my $class = $self->{QueryInterface};
    eval "require $class";
    return $class->new( $query_string, $query_lang, $self->model); 
}

sub new_resource {
    my $self = shift;
    my $uri = shift;
    return RDF::Helper::Node::Resource->new( uri => $uri );
}

sub new_literal {
    my $self = shift;
    my ($val, $lang, $type )  = @_;
    return RDF::Helper::Node::Literal->new( 
        value => $val,
        language => $lang,
        datatype => $type
    );
}

sub new_bnode {
    my $self = shift;
    my $id = shift;
    $id ||= time . 'r' . $self->{bnodecounter}++;
    return RDF::Helper::Node::Blank->new(
        identifier => $id
    );
}

sub get_statements {
    my $self = shift;
    my @ret_array = ();

    my $e = $self->get_enumerator(@_);
    while( my $s = $e->next ) {
        push @ret_array, $s;
    }
    
    return @ret_array;
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
        
        push @ret_array, [ $subj_value,
                           $stmnt->predicate->uri->as_string,
                           $obj_value ];
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

sub normalize_triple_pattern {
    my $self = shift;
    my ($s, $p, $o) = @_;
    my ($subj, $pred, $obj) = (undef, undef, undef);

    if (defined($s)) {
       $subj = ref($s) ? $s : $self->new_resource( $self->{ExpandQNames} ? $self->qname2resolved($s) : $s);
    }    
    if (defined($p)) {
        $pred = ref($p) ? $p : $self->new_resource( $self->{ExpandQNames} ? $self->qname2resolved($p) : $p);
    }    
    if (defined($o)) {
        if ( ref( $o ) ) {
            $obj = $o;
        }
        else {
            my $testval = $self->{ExpandQNames} ? $self->qname2resolved($o) : $o;
            my $type = $self->get_perl_type( $testval );
            if ( $type eq 'resource' ) {
                $obj  = $self->new_resource("$testval");
            }
            else {
                $obj  = $self->new_literal("$testval");
            }
        }
    }
    return ( $subj, $pred, $obj );
}

sub query_interface {
    my $self = shift;
    my $new = shift;

    if (defined($new)) {
        $self->{QueryInterface} = $new;
        return 1;
    }
    
    $self->{QueryInterface} ||= 'RDF::Helper::RDFQuery';
    return $self->{QueryInterface};
}

1;
__END__

=head1 NAME

RDF::Helper - Provide a consistent, Perlish interface to Perl's varous RDF processing tools. 

=head1 SYNOPSIS

  use RDF::Helper;
  
  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Redland',
      Namespaces => { 
          dc => 'http://purl.org/dc/elements/1.1/',
          rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
         '#default' => "http://purl.org/rss/1.0/",
     }
  );

=head1 DESCRIPTION

This module intends to simplify, normalize and extend Perl's existing facilites for interacting with RDF data. 

RDF::Helper's goal is to offer a common interface to existing packages like L<RDF::Redland> and L<RDF::Core> that makes things easier, more Perlish, and less verbose for everyday use, but that in no way blocks power-users from taking advantage of what those tools individually offer.

=head1 CONSTRUCTOR OPTIONS

  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Redland',
      Namespaces => { 
          dc => 'http://purl.org/dc/elements/1.1/',
          rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
         '#default' => "http://purl.org/rss/1.0/",
     },
     ExpandQNames => 1
  );

=head2 BaseInterface

The C<BaseInterface> option expects a string that corresponds to the class name of the underlying Perl RDF library that will be used by this instance of the Helper. Currently, only L<RDF::Redland> is fully supported.  The default value for this
option if omitted is C<RDF::Redland>.

=head2 Model

The C<Model> option expects a blessed instance object of the RDF model that will be operated on with this instance of the Helper. Obviously, the type of object passed should correspond to the L<BaseInterface> used (L<RDF::Redland::Model> for a BaseInterface of L<RDF::Redland>, etc.). If this option is omitted, a new, in-memory model will be created.  

=head2 Namespaces

The C<Namespaces> option expects a hash reference of prefix/value pairs for the namespaces that will be used with this instance of the Helper. The special '#default' prefix is reserved for setting the default namespace.

For convenience, the L<RDF::Helper::Constants> class will export a number of useful constants that can be used to set the namespaces for common grammars:

  use RDF::Helper;
  use RDF::Helper::Constants qw(:rdf :rss1 :foaf);

  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Redland',
      Namespaces => { 
          rdf => RDF_NS,
          rss => RSS1_NS,
          foaf => FOAF_NS
     },
     ExpandQNames => 1
  );
  
=head2 ExpandQNames

Setting a non-zero value for the C<ExpandQNames> option configures the current instance of the Helper to allow for qualified URIs to be used in the arguments to many of the Helper's convenience methods. For example, given the L<Namespaces> option for the previous example, with C<ExpandQNames> turned on, the following will work as expected.

  $rdf->assert_resource( $uri, 'rdf:type', 'foaf:Person' );
  
With C<ExpandQNames> turned off, you would have to pass the full URI for both the C<rdf:type> predicate, and the C<foaf:Person> object to achieve the same result.

=head2 BaseURI

If specified, this option sets what the base URI will be when working with so called abbreviated URIs, like C<#me>.  If you do not specify an explicit BaseURI option, then one will be created automatically for you.  See L<http://www.w3.org/TR/rdf-syntax-grammar/#section-Syntax-ID-xml-base> for more information on abbreviated URIs.

=head1 METHODS

=head2 new_resource

  $res = $rdf->new_resource($uri)

Creates and returns a new resource object that represents the supplied URI.  In many cases this is not necessary
as the methods available in L<RDF::Helper> will automatically convert a string URI to the appropriate object type
in the back-end RDF implementation.

=head2 new_literal

  $lit = $rdf->new_literal($text)
  $lit = $rdf->new_literal($text, $lang)
  $lit = $rdf->new_literal($text, $lang, $type)

Creates and returns a new literal text object that represents the supplied string.  In many cases this is not necessary
as the methods available in L<RDF::Helper> will automatically convert the value to the appropriate object type
in the back-end RDF implementation.

When it is necessary to explicitly create a literal object is when you want to specify the language or datatype of the
text string.  The datatype argument expects a Resource object or a string URI.

=head2 new_bnode

  $bnode = $rdf->new_bnode()

Creates and returns a new "Blank Node" that can be used as the subject or object in a new statement.

=head2 assert_literal

  $rdf->assert_literal($subject, $predicate, $object)

This method will assert, or "insert", a new statement whose value, or "object", is a literal.

Both the subject and predicate arguments can either take a URI object, a URI string.

Additionally, if you used the L</ExpandQNames> option when creating the L<RDF::Helper> object,
you can use QNames in place of the subject and predicate values.  For example, "rdf:type" would
be properly expanded to its full URI value.

=head2 assert_resource

  $rdf->assert_resource($subject, $predicate, $object)

This method will assert, or "insert", a new statement whose value, or "object", is a resource.

The subject, predicate and object arguments can either take a URI object, or a URI string.

Like L</assert_literal>, if you used the L</ExpandQNames> option when creating the L<RDF::Helper> object,
you can use QNames in place of any of the arguments to this method.  For example, "rdf:type" would
be properly expanded to its full URI value.

=head2 remove_statements

  $count = $rdf->remove_statements()
  $count = $rdf->remove_statements($subject)
  $count = $rdf->remove_statements($subject, $predicate)
  $count = $rdf->remove_statements($subject, $predicate, $object)

This method is used to remove statements from the back-end RDF model whose constituent parts match the
supplied arguments.  Any of the arguments can be omitted, or passed in as C<undef>, which means any value
for that triple part will be matched and removed.

For instance, if values for the predicate and object are given, but the subject is left as "undef", then
any statement will be removed that matches the supplied predicate and object.  If no arguments are supplied,
then all statements in the RDF model will be removed.

The number of statements that were removed in this operation is returned.

=head2 update_node

  $rdf->update_node($subject, $predicate, $object, $new_object)

This method is used when you wish to change the object value of an existing statement.  This method acts as
an intelligent wrapper around the L</update_literal> and L</update_resource> methods, and will try to auto-detect
what type of object is currently in the datastore, and will try to set the new value accordingly.  If it can't
make that determination it will fallback to L</update_literal>.

Keep in mind that if you need to change a statement from having a Resource to a Literal, or vice versa, as its
object, then you may need to invoke the appropriate update method directly.

=head2 update_literal

  $rdf->update_literal($subject, $predicate, $object, $new_object)

Updates an existing statement's literal object value to a new one.  For more information on the operation of this
method, see L</update_node>.

=head2 update_resource

  $rdf->update_resource($subject, $predicate, $object, $new_object)

Updates an existing statement's resource object value to a new one.  For more information on the operation of this
method, see L</update_node>.

=head2 get_statements

  @stmts = $rdf->get_statements()
  @stmts = $rdf->get_statements($subject)
  @stmts = $rdf->get_statements($subject, $predicate)
  @stmts = $rdf->get_statements($subject, $predicate, $object)

This method is used to fetch and return statements from the back-end RDF model whose constituent parts match the
supplied arguments.  Any of the arguments can be omitted, or passed in as C<undef>, which means any value
for that triple part will be matched and returned.

For instance, if values for the predicate and object are given, but the subject is left as "undef", then
any statement will be returned that matches the supplied predicate and object.  If no arguments are supplied,
then all statements in the RDF model will be returned.

Depending on which back-end type being used, different object types will be returned.  For instance, if L<RDF::Redland>
is used, then all the returned objects will be of type L<RDF::Redland::Statement>.

=head2 get_triples

  @stmts = $rdf->get_triples()
  @stmts = $rdf->get_triples($subject)
  @stmts = $rdf->get_triples($subject, $predicate)
  @stmts = $rdf->get_triples($subject, $predicate, $object)

This method functions in the same way as L</get_statements>, except instead of the statements being represented as
objects, the statement's values are broken down into plain strings and returned as an anonymous array.  Therefore,
an individual element of the returned array may look like this:

  [ "http://some/statement/uri", "http://some/predicate/uri", "some object value" ]

=head2 resourcelist
         
  @subjects = $rdf->resourcelist()      
  @subjects = $rdf->resourcelist($predicate)    
  @subjects = $rdf->resourcelist($predicate, $object)   

This method returns the unique list of subject URIs from within the RDF model that optionally match the predicate   
and/or object arguments.  Like in L</get_statements>, either or all of the arguments to this method can be C<undef>.    

=head2 exists

  $result = $rdf->exists()
  $result = $rdf->exists($subject)
  $result = $rdf->exists($subject, $predicate)
  $result = $rdf->exists($subject, $predicate, $object)

Returns a boolean value indicating if any statements exist in the RDF model that matches the supplied arguments.

=head2 count

  $count = $rdf->count()
  $count = $rdf->count($subject)
  $count = $rdf->count($subject, $predicate)
  $count = $rdf->count($subject, $predicate, $object)

Returns the number of statements that exist in the RDF model that matches the supplied arguments.  If no arguments are
supplied, it returns the total number of statements in the model are returned.

=head2 include_model

  $rdf->include_model($model)

Include the contents of another, already opened, RDF model into the current model.

=head2 include_rdfxml

  $rdf->include_rdfxml(xml => $xml_string)      
  $rdf->include_rdfxml(filename => $file_path)      

This method will import the RDF statements contained in an RDF/XML document, either from a file or a string, into the   
current RDF model.  If a L</BaseURI> was specified in the L<RDF::Helper> L<constructor|/"CONSTRUCTOR OPTIONS">, then that    
URI is used as the base for when the supplied RDF/XML is imported.  For instance, if the hash notation is used to   
reference an RDF node (e.g. C<E<lt>rdf:Description rdf:about="#dahut"/E<gt>>), the L</BaseURI> will be prepended to the     
C<rdf:about> URI.   

=head2 serialize

  $string = $rdf->serialize()   
  $string = $rdf->serialize(format => 'ntriple')    
  $rdf->serialize(filename => 'out.rdf')    
  $rdf->serialize(filename => 'out.n3', format => 'ntriple')    

Serializes the back-end RDF model to a string, using the specified format type, or defaulting to abbreviated RDF/XML.  The      
serialization types depends on which RDF back-end is in use.  The L<RDF::Redland> support within L<RDF::Helper> supports the    
following serialization types:      

=over 4     

=item *     

rdfxml      

=item *     

rdfxml-abbrev   

=item *     

ntriple     

=item *     

trix    

=back

=head2 new_query

  $query_object = $obj->new_query( $query, [$base_uri, $lang_uri, $lang_name] );

Returns an instance of the class defined by the L<QueryInterface> argument passed to the constructor (or the default class for the base interface if none is explicityly set) that can be used to query the currently selected model.

=head1 PERLISH CONVENIENCE METHODS

=head2 property_hash

  $hash_ref = $rdf->property_hash($subject)
         
For instances when you don't know what properties are bound to an RDF node, or when it is too cumbersome to     
iterate over the results of a L</get_triples> method call, this method can be used to return all the properties     
and values bound to an RDF node as a hash reference.  The key name will be the predicate URI (QName-encoded if      
a matching namespace is found), and the value will be the object value of the given predicate.  Multiple object     
values for the same predicate URI will be returned as an array reference.   

It is important to note that this is a read-only dump from the RDF model.  For a "live" alternative to this, see    
L</tied_property_hash>.     

=head2 deep_prophash    

  $hashref = $rdf->deep_prophash($subject)

This method is similar to the L</property_hash> method, except this method will recurse over children nodes, in
effect creating a nested hashref datastructure representing a node and all of its associations.

B<Note:> This method performs no checks to ensure that it doesn't get stuck in a deep recursion loop, so be
careful when using this.

=head2 tied_property_hash

  $hash_ref = $rdf->tied_property_hash($subject)
  $hash_ref = $rdf->tied_property_hash($subject, \%options)     
                 
Like L</property_hash>, this method returns a hash reference containing the predicates and objects bound to the     
given subject URI.  This method differs however in that any changes to the hash will immediately be represented     
in the RDF model.  So if a new value is assigned to an existing hash key, if a new key is added, or a key is deleted    
from the hash, that will transparently be represented as updates, assertions or removal operations against the      
model.      

Optionally a hash can be passed to this method when tieing a property hash to give additional instructions to the   
L<RDF::Helper::RDFRedland::TiedPropertyHash> object.  Please see the documentation in that class for more
information.

=head2 get_object

  $obj = $rdf->get_object($subject, %options)
  $obj = $rdf->get_object($subject, \%options)

Returns an instance of L<RDF::Helper::Object> bound to the given subject URI.  This exposes that RDF node as an
object-oriented class interface, allowing you to interact with and change that RDF node and its properties using
standard Perl-like accessor methods.  For more information on the use of this method, please see L<RDF::Helper::Object>.

=head2 arrayref2rdf
 
 $obj->arrayref2rdf(\@list, $subject, $predicate);
 $obj->arrayref2rdf(\@list, undef, $predicate);

Asserts a list of triples with the the subject C<$subject>, predicate C<$predicate> and object(s) contained in C<\@list>. It the subject is undefined, a new blank node will be used.

=head2 hashref2rdf

  $object->hashref2rdf( \%hash );
  $object->hashref2rdf( \%hash, $subject );

This method is the reverse of L</property_hash> and L</deep_prophash> in that it accpets a Perl hash reference and unwinds it into a setions of triples in the RDF store. If the C<$subject> is missing or undefined a new blank node will be used.
  
=head2 hashlist_from_statement

  @list = $rdf->hashlist_from_statement()
  @list = $rdf->hashlist_from_statement($subject)
  @list = $rdf->hashlist_from_statement($subject, $predicate)
  @list = $rdf->hashlist_from_statement($subject, $predicate, $object)

Accepting a sparsely populated triple pattern as its argument, this methods return a list of subject/hash reference pairs for all statements that match the pattern. Each member in the list will have the following structure:

  [ $subject, $hash_reference ]

=head1 ACCESSOR METHODS

=head2 model

  $model = $rdf->model()    
  $rdf->model($new_model)   

An accessor method that can be used to retrieve or set the back-end RDF model that this L<RDF::Helper> instance uses.   

=head2 query_interface

  $iface = $rdf->query_interface()
  $rdf->query_interface($iface)

Accessor method that is used to either set or retrieve the current class name that should be used for composing and
performing queries.

=head1 SEE ALSO

L<RDF::Helper::Object>; L<RDF::Redland>; L<RDF::Core>; L<RDF::Query>

=head1 AUTHOR

Kip Hampton, E<lt>khampton@totalcinema.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004-2006 by Kip Hampton. Mike Nachbaur

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
