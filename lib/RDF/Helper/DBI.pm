package RDF::Helper::DBI;
use strict;
use warnings;
use RDF::Query::Model::SQL;
use DBI;
use URI;
use Cwd;
use RDF::Helper::Statement;
use RDF::Helper::DBI::Query;
use RDF::Helper::PerlConvenience;
use RDF::Helper::Object;
use RDF::Helper::DBI::Model;
use RDF::Helper::DBI::Enumerator;
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
    
    #warn Dumper( \%args );

    unless (defined($args{Model})) {
        if ( defined( $args{dbh}) || defined ($args{DBI_DSN})) {
            unless ( defined( $args{ModelName} ) ) {
                die "You must pass a ModelName";
            }
            
            my $dbh = delete $args{dbh};
            
            unless (defined( $dbh )) {
                $dbh = DBI->connect( $args{DBI_DSN}, $args{DBI_USER}, $args{DBI_PASS}) || die $DBI::errstr;
            }
            
            my $do_nuke = $args{CreateNew} || undef;
            RDF::Helper::DBI::Model::bootstrap_model_db( $dbh, $args{ModelName}, $do_nuke );
            
            $args{Model} = RDF::Helper::DBI::Model->new( $dbh, $args{ModelName} );
        }
        else {
            # still got nothing' huh?
            die "Temp storage not yet available with DBI BaseInterface";
        }
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
        $args{QueryInterface} = 'RDF::Helper::DBI::Query';
    }
    
    my %foo  = reverse %{$args{Namespaces}};
    $args{_NS} = \%foo;
    
    return bless \%args, $class;
}

sub new_statement {
    my $self = shift;
    return RDF::Helper::Statement->new( @_ );
}

sub count {
    my $self = shift;
    my ( $s, $p, $o ) = @_;
    my ( $subj, $pred, $obj ) = $self->normalize_triple_pattern( $s, $p, $o );
    return $self->model->count( $subj, $pred, $obj ); 
}

sub add_statement {
    my $self = shift;
    return $self->model->add_statements(@_);
}

sub remove_statement {
    my $self = shift;
    return $self->model->remove_statements(@_);
}

sub remove_statements {
    my $self = shift;
    my ( $s, $p, $o ) = @_;
    my ( $subj, $pred, $obj ) = $self->normalize_triple_pattern( $s, $p, $o );
    return $self->remove_statement($self->new_statement( $subj, $pred, $obj));
}

sub assert_literal {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my $subj = ref($s) ? $s : $self->new_resource( $self->{ExpandQNames} ? $self->qname2resolved($s) : $s);
    
    my $pred = ref($p) ? $p : $self->new_resource( $self->{ExpandQNames} ? $self->qname2resolved($p) : $p);

    my $obj  = ref($o) ? $o : $self->new_literal("$o");

    $self->add_statement( $self->new_statement( $subj, $pred, $obj ) );
}

sub assert_resource {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my $subj = ref($s) ? $s : $self->new_resource( $self->{ExpandQNames} ? $self->qname2resolved($s) : $s);
    
    my $pred = ref($p) ? $p : $self->new_resource( $self->{ExpandQNames} ? $self->qname2resolved($p) : $p);
                              
    my $obj  = ref($o) ? $o : $self->new_resource( $self->{ExpandQNames} ? $self->qname2resolved($o) : $o);

    $self->add_statement( $self->new_statement( $subj, $pred, $obj ) );
}


sub get_enumerator {
    my $self = shift;
    my ($s, $p, $o) = @_;

    my ($subj, $pred, $obj) = $self->normalize_triple_pattern( $s, $p, $o );

    return $self->model->get_enumerator( $self->new_statement( $subj, $pred, $obj ) );
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
    return $self->{Model};
}



#---------------------------------------------------------------------
# Batch inclusions
#---------------------------------------------------------------------

sub include_model {
    my $self = shift;
    my $model = shift;

    my $e = $model->get_enumerator;
    
    while( my $s = $e->next ) {
        $self->model->add_statement( $s );
    }
    
    return 1;   
}

sub new_query {
    my $self = shift;
    my ($query_string, $query_lang) = @_;
    
    my $class = $self->{QueryInterface};
    eval "require $class";
    return $class->new( $query_string, $query_lang, $self->model); 
}

sub include_rdfxml {
    my $self = shift;
    my %args = @_;
    
    my $helper = undef;
    eval { require RDF::Redland };
    unless ( $@ ) {
        $helper = RDF::Helper->new( InMemory => 1, BaseInterface => 'RDF::Redland' );
    }
    
    unless ( $helper ) {
        eval { require RDF::Core };
        unless ( $@ ) {
            $helper = RDF::Helper->new( InMemory => 1, BaseInterface => 'RDF::Core' );
        }    
    }
    
    die "RDF/XML parsing not implemented natively" unless $helper;
    
    $helper->include_rdfxml( %args );
    
    my $e = $helper->get_enumerator;
    
    while (my $s = $e->next ) {
        #warn "Importing statement" , Dumper( $s );
        $self->add_statement( $s );
    }
    return 1;
}

sub serialize {
    my $self = shift;
    my %args = @_;
    
    my $helper = undef;
    eval { require RDF::Redland };
    unless ( $@ ) {
        $helper = RDF::Helper->new( InMemory => 1, BaseInterface => 'RDF::Redland' );
    }
    
    unless ( $helper ) {
        eval { require RDF::Core };
        unless ( $@ ) {
            $helper = RDF::Helper->new( InMemory => 1, BaseInterface => 'RDF::Core' );
        }    
    }
    
    die "Serialization not implemented natively" unless $helper;
    
    my $e = $self->get_enumerator;
    
    while (my $s = $e->next ) {
        #warn "Importing statement" , Dumper( $s );
        $helper->add_statement( $s );
    }
    return $helper->serialize( %args );
}

1;

__END__

=head1 NAME

RDF::Helper::DBI - Generic RDF::Helper bridge for RDBMS-based Models

=head1 SYNOPSIS

  my $dbh = DBI->connect( $dsn, $user, $pass);
  
  my $rdf = RDF::Helper->new(
    BaseInterface => 'DBI',
    ModelName => 'mymodel',
    Namespaces => \%namespaces,
    dbh => $dbh,
    BaseURI => 'http://domain/NS/2004/09/03-url#'
  );

=head1 DESCRIPTION

RDF::Helper::DBI is the bridge class that connects RDF::Helper's facilites to RDBMS-based triplestores and should not be used directly. 

See L<RDF::Helper> for method documentation

=head1 AUTHOR

Kip Hampton, khampton@totalcinema.com

=head1 COPYRIGHT

Copyright (c) 2004-2006 Kip Hampton.  All rights reserved.

=head1 LICENSE

This module is free sofrware; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<RDF::Helper> L<RDF::Redland>.

=cut
