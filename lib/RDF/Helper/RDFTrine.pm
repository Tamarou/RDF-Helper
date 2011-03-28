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

1;
__END__
