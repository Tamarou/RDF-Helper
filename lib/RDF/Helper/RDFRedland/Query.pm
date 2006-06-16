package RDF::Helper::RDFRedland::Query;
use strict;
use warnings;
use vars qw( @ISA );
@ISA = qw( RDF::Redland::Query );


sub new {
    my $proto = shift;
    my ($query_string, $query_lang, $model ) = @_;
    my $class = ref ($proto) || $proto;
    my $obj = $class->SUPER::new( $query_string, undef, undef, $query_lang );
    $obj->{Model} = $model;
    return bless $obj, $class;
}

sub execute {
    my $self = shift;
    my $model = shift;
    $self->{_RESULTS_} = $self->SUPER::execute( $model || $self->{Model} );
}

sub selectrow_hashref {
    my $self = shift;
    unless ( defined( $self->{_RESULTS_} ) ) {
        $self->execute;
    }
    
    if ( $self->{_RESULTS_}->finished ) {
        $self->{_RESULTS_} = undef;
        return undef;
    }
    
    
    my $found_data = {};
    for (my $i=0; $i < $self->{_RESULTS_}->bindings_count(); $i++) {
            my $node = $self->{_RESULTS_}->binding_value($i);
            my $value = $node->is_literal ? $node->literal_value : $node->uri->as_string;
            my $key = $self->{_RESULTS_}->binding_name($i);
            $found_data->{$key} = $value;
    };
    $self->{_RESULTS_}->next_result;
    return $found_data;
}

sub selectrow_arrayref {
    my $self = shift;
    unless ( defined( $self->{_RESULTS_} ) ) {
        $self->execute;
    }
    
    if ( $self->{_RESULTS_}->finished ) {
        $self->{_RESULTS_} = undef;
        return undef;
    }
    
    
    my $found_data = [];
    for (my $i=0; $i < $self->{_RESULTS_}->bindings_count(); $i++) {
            my $node = $self->{_RESULTS_}->binding_value($i);
            my $value = $node->is_literal ? $node->literal_value : $node->uri->as_string;
            push @{$found_data}, $value;
    };
    $self->{_RESULTS_}->next_result;
    return $found_data;
}
