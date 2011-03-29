use Test::More;

use strict;
use warnings;
use Data::Dumper;

use RDF::Helper;

use constant URI1 => 'http://example.org/one';
use constant XSD_INT => 'http://www.w3.org/2001/XMLSchema#int';

#----------------------------------------------------------------------
# RDF::Redland
#----------------------------------------------------------------------
SKIP: {
  eval { require RDF::Redland };
  skip "RDF::Redland not installed", 5 if $@;

  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Redland',
      BaseURI => 'http://totalcinema.com/NS/test#'
  );
  
  test( $rdf );

}

#----------------------------------------------------------------------
# RDF::Trine
#----------------------------------------------------------------------
SKIP: {
  eval { require RDF::Trine };
  skip "RDF::Redland not installed", 5 if $@;

  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Trine',
      BaseURI => 'http://totalcinema.com/NS/test#'
  );

  test( $rdf );

}

sub test {
  my $rdf = shift;
  ok( $rdf->new_resource(URI1) );
  ok( $rdf->new_literal('A Value') );
  ok( $rdf->new_bnode );

  my $typed = $rdf->new_literal('15', undef, XSD_INT);
  my $langed = $rdf->new_literal('Speek Amurrican', 'en-US');

  ok($typed->literal_datatype->as_string eq XSD_INT);
  ok($langed->literal_value_language eq 'en-US');
}

done_testing();
