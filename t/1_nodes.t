use Test::More tests => 10;

use strict;
use warnings;

use RDF::Helper;

use constant URI1 => 'http://example.org/one';
use constant XSD_INT => 'http://www.w3.org/2001/XMLSchema#int';
#----------------------------------------------------------------------
# RDF::Core
#----------------------------------------------------------------------
SKIP: {
  eval { require RDF::CoreXXX };
  skip "RDF::Core not installed", 5 if $@;

  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Core',
      BaseURI => 'http://totalcinema.com/NS/test#'
  );
  
  ok( $rdf->new_resource(URI1) );
  ok( $rdf->new_literal('A Value') );  
  ok( $rdf->new_bnode );
  
  my $typed = $rdf->new_literal('15', undef, XSD_INT);
  my $langed = $rdf->new_literal('Speek Amurrican', 'en-US');

  ok($typed->getDatatype eq XSD_INT);
  ok($langed->getLang eq 'en-US');
}

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
  
  ok( $rdf->new_resource(URI1) );
  ok( $rdf->new_literal('A Value') );
  ok( $rdf->new_bnode );

  my $typed = $rdf->new_literal('15', undef, XSD_INT);
  my $langed = $rdf->new_literal('Speek Amurrican', 'en-US');

  SKIP: {
      skip "Datatypes not working properly", 1;
      ok($typed->literal_datatype eq XSD_INT);
  }
  ok($langed->literal_value_language eq 'en-US');
}
