use Test::More tests => 5;
use strict;
use warnings;

BEGIN { 
    use_ok('RDF::Helper'); 
    use_ok('RDF::Helper::Constants'); 

};

my $found_libs =  0;

SKIP: {
    eval { require RDF::CoreXXX };
    skip "RDF::Core not installed", 1 if $@;
    
    my $helper = RDF::Helper->new(BaseInterface => 'RDF::Core',
                                   BaseURI => 'http://localhost/');
    $found_libs++;
    isa_ok( $helper, 'RDF::Helper::RDFCore');
    
}

SKIP: {
    eval { require RDF::Redland };
    skip "RDF::Redland not installed", 1 if $@;
    
    my $helper = RDF::Helper->new(BaseInterface => 'RDF::Redland');
    $found_libs++;
    isa_ok( $helper, 'RDF::Helper::RDFRedland');
    
}

ok( $found_libs > 0) or diag("You must have one of Perl's RDF libraries (RDF::Core, RDF::Redland, etc.) installed for this package to work!!!");
