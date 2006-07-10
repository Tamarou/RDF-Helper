use Test::More tests => 5;
use strict;
use warnings;

BEGIN { 
    use_ok('RDF::Helper'); 
    use_ok('RDF::Helper::Constants'); 

};

my $found_libs =  0;

test( base => 'RDF::Core', class => 'RDF::Helper::RDFCore' );
test( base => 'RDF::Redland', class => 'RDF::Helper::RDFRedland' );

ok( $found_libs > 0) or diag("You must have one of Perl's RDF libraries (RDF::Core, RDF::Redland, etc.) installed for this package to work!!!");

sub test {
    my %args = @_;
SKIP: {
    eval "require $args{base}";
    skip "$args{base} not installed", 1 if $@;
    
    my $helper = RDF::Helper->new(BaseInterface => $args{base});
    $found_libs++;
    isa_ok( $helper, $args{class});
}
}
