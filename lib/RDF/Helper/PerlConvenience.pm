package RDF::Helper::PerlConvenience;
use strict;
use warnings;
use Data::Dumper;



sub resourcelist_from_property {
    my %args = @_;
    
    my @found_data = ();
    
    foreach my $stmnt ( 
$args{RDFStore}->get_statements( undef, $args{PropertyURI}, $args{Value})) {
        push @found_data, $stmnt->subject->uri->as_string;        
    }
    
    return @found_data;
}

sub resolved2prefixed {
    my $self = shift;
    my $lookup = shift;
    foreach my $uri ( sort {length $b <=> length $a} (keys( %{$self->{_NS}} )) ) { 
        #warn "URI $uri LOOKUP $lookup ";
        if ( $lookup =~ /^($uri)(.*)$/ ) {
            my $prefix = $self->{_NS}->{$uri};
            return $2 if $prefix eq '#default';
            return $prefix . ':' . $2;
        }
    }
    return undef;
}

sub prefixed2resolved {
    my $self = shift;
    my $lookup = shift;
    
    my ( $name, $prefix ) = reverse ( split /:/, $lookup );
    
    my $uri;
    if ( $prefix ) {
        if ( defined $self->{Namespaces}->{$prefix} ) {
            $uri = $self->{Namespaces}->{$prefix};
        }
        else {
            warn "Unknown prefix: $prefix, in QName $lookup. Falling back to the default predicate URI";
        }
    }
    
    $uri ||= $self->{Namespaces}->{'#default'};
    return $uri . $name;
}

sub qname2resolved {
    my $self = shift;
    my $lookup = shift;
    
    my ( $prefix, $name ) = $lookup =~ /^([^:]+):(.+)$/;
    return $lookup unless (exists($self->{Namespaces}->{$prefix}));
    return $self->{Namespaces}->{$prefix} . $name;
}

1;
