use Test::More tests => 15;

use strict;
use warnings;
use Data::Dumper;

use RDF::Helper;

use constant URI1 => 'http://example.org/one';
use constant XSD_INT => 'http://www.w3.org/2001/XMLSchema#int';
#----------------------------------------------------------------------
# RDF::Core
#----------------------------------------------------------------------
SKIP: {
  eval { require RDF::Core };
  skip "RDF::Core not installed", 5 if $@;

  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Core',
      BaseURI => 'http://totalcinema.com/NS/test#'
  );
  
  test( $rdf );
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
  
  test( $rdf );

}

#----------------------------------------------------------------------
# DBI
#----------------------------------------------------------------------
SKIP: {
  eval { require DBI };
  skip "DBI not installed", 5 if $@;
  unless ( $ENV{DBI_DSN} and $ENV{DBI_USER} and $ENV{DBI_PASS} ) {
      skip "Environment not set up for running DBI tests, see the README", 5
  }

  my $rdf = RDF::Helper->new(
      BaseInterface => 'DBI',
      BaseURI => 'http://totalcinema.com/NS/test#',
      ModelName => 'testmodel',
      DBI_DSN => $ENV{DBI_DSN},
      DBI_USER => $ENV{DBI_USER},
      DBI_PASS => $ENV{DBI_PASS},
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
