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
@ISA = qw( RDF::Helper RDF::Helper::PerlConvenience );

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

    unless (defined($args{QueryInterface})) {
        $args{QueryInterface} = 'RDF::Helper::RDFRedland::Query';
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
    return RDF::Redland::Node->new_literal("$val", $type, $lang);
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
    my $obj  = ref($o) ? $o : RDF::Redland::Node->new_literal("$o");

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
                                  RDF::Redland::URI->new($self->{ExpandQNames} ? $self->qname2resolved($s) : $s)
                              );
    }    
    if (defined($p)) {
        $pred = ref($p) ? $p : RDF::Redland::Node->new(
                                  RDF::Redland::URI->new($self->{ExpandQNames} ? $self->qname2resolved($p) : $p)
                              );
    }    
    if (defined($o)) {
        if ( ref( $o ) ) {
            $obj = $o;
        }
        else {
            my $testval = $self->{ExpandQNames} ? $self->qname2resolved($o) : $o;
            my $type = $self->get_perl_type( $testval );
            if ( $type eq 'resource' ) {
                $obj = RDF::Redland::Node->new(
                    RDF::Redland::URI->new($testval)
                );
            }
            else {
                $obj  = RDF::Redland::Node->new_literal("$testval");
            }
        }
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

# sub exists {
#     my $self = shift;
#     if ( $self->count( @_ ) > 0 ) {
#         return 1;
#     }
#     return 0;
# }

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

sub query_interface {
    my $self = shift;
    my $new = shift;

    if (defined($new)) {
        $self->{QueryInterface} = $new;
        return 1;
    }
    
    $self->{QueryInterface} ||= 'RDF::Helper::RDFRedland::Query';
    return $self->{QueryInterface};
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
    
    my $class = $self->{QueryInterface};
    eval "require $class";
    return $class->new( $query_string, $query_lang, $self->model); 
}

#---------------------------------------------------------------------
# Perl convenience methods
#---------------------------------------------------------------------

sub tied_property_hash {
    my $self = shift;
    my $lookup_uri = shift;
    my $options = shift;
    eval "require RDF::Helper::RDFRedland::TiedPropertyHash";
    
    return RDF::Helper::RDFRedland::TiedPropertyHash->new( Helper => $self, ResourceURI => $lookup_uri, Options => $options);

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
        elsif ( $type eq 'resource' ) {
            $self->assert_resource(
                $subject, $predicate, $value
            );        
        }
        else {
            $self->assert_literal(
                $subject, $predicate, $value
            );
        }
    }
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

1;

__END__

=head1 NAME

RDF::Helper::RDFReland - RDF::Helper bridge for RDF::Redland

=head1 SYNOPSIS

  my $model = RDF::Redland::Model->new( 
      RDF::Redland::Storage->new( %storage_options )
  );

  my $rdf = RDF::Helper->new(
    Namespaces => \%namespaces,
    BaseURI => 'http://domain/NS/2004/09/03-url#'
  );

=head1 DESCRIPTION

RDF::Helper::RDFRedland is the bridge class that connects RDF::Helper's facilites to RDF::Redland and should not be used directly. 

See L<RDF::Helper> for method documentation

=head1 AUTHOR

Kip Hampton, khampton@totalcinema.com

=head1 COPYRIGHT

Copyright (c) 2004 Kip Hampton.  All rights reserved.

=head1 LICENSE

This module is free sofrware; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<RDF::Helper> L<RDF::Redland>.

=cut
