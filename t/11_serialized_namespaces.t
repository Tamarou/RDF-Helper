use Test::More;

use strict;
use warnings;

use RDF::Helper;

#----------------------------------------------------------------------
# RDF::Redland
#----------------------------------------------------------------------
SKIP: {
  eval { require RDF::Redland };
  skip "RDF::Redland not installed", 2 if $@;


  test( 'RDF::Redland' );
}

#----------------------------------------------------------------------
# RDF::Trine
#----------------------------------------------------------------------
SKIP: {
  eval { require RDF::Trine };
  skip "RDF::Trine not installed", 2 if $@;

  test( 'RDF::Trine' );
}

done_testing();

#
# Test Methods
#

sub test {
  my $class = shift;
  my $rdf = RDF::Helper->new(
      BaseInterface => $class,
      namespaces => { 
        dc => 'http://purl.org/dc/terms/',
        rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        '#default' => "http://xmlns.com/foaf/0.1/"
     }
  );
  my $obj = $rdf->get_object('http://dahut.pm.org/dahut_group.rdf#bender');
  $obj->rdf_type('http://xmlns.com/foaf/0.1/Person');
  $obj->name("Bender");
  $obj->dc_description("A description of Bender");
  my $xmlstring = $rdf->serialize(format => 'rdfxml');
  like($xmlstring, qr|xmlns:dc="http://purl.org/dc/terms/"|, 'DC prefix declaration');
  like($xmlstring, qr|<dc:description>|, 'DC element present');
}
