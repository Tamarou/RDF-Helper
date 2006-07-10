use Test::More tests => 31;

use strict;
use warnings;

use RDF::Helper;
use RDF::Helper::Constants qw(:rdf :rss1 :foaf);

use constant URI1 => 'http://example.org/one';
use constant URI2 => 'http://example.org/two';

#----------------------------------------------------------------------
# RDF::Core
#----------------------------------------------------------------------
SKIP: {
  eval { require RDF::Core };
  skip "RDF::Core not installed", 12 if $@;

  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Core',
      BaseURI => 'http://totalcinema.com/NS/test#'
  );
  
  # assert_resource - explicit constructors/nodes
  my $subj = $rdf->new_resource(URI1);
  my $pred = $rdf->new_resource(RDF_TYPE);
  my $obj  = $rdf->new_resource(RSS1_ITEM);  
  $rdf->assert_resource($subj, $pred, $obj);
  
  ok( $rdf->exists($subj, $pred, $obj) == 1, 'assert_resource as objects' );

  # assert_resource - as strings
  $rdf->assert_resource(URI1, RSS1_LINK, URI2); 

  ok( $rdf->exists(URI1, RSS1_LINK, URI2) == 1, 'assert_resource as strings' );

  # assert_literal - explicit constructors/nodes
  $subj = $rdf->new_resource(URI1);
  $pred = $rdf->new_resource(RSS1_TITLE);
  $obj  = $rdf->new_literal('Some Title');
  $rdf->assert_literal($subj, $pred, $obj);

  ok( $rdf->exists($subj, $pred, $obj) == 1, 'assert_literal as objects' );

  # assert_resource - as strings
  $rdf->assert_literal(URI1, RSS1_DESCRIPTION, 'Some Description');

  ok( $rdf->exists(URI1, RSS1_DESCRIPTION, 'Some Description') == 1, 'assert_literal as strings' ); 

  ok( $rdf->count() == 4, 'count() with no args.');
  ok( $rdf->count(URI1) == 4, 'count() with subject only.');
  ok( $rdf->count(undef, RSS1_TITLE) == 1, 'count() with pred only.');
  ok( $rdf->count(undef, undef, 'Some Title') == 1, 'count() with object only.');
  
  $rdf->remove_statements(undef, RSS1_TITLE);
  
  ok( $rdf->count() == 3, 'remove statement');
  
  $rdf->update_literal(URI1, RSS1_DESCRIPTION, 'Some Description', 'New Description');

  ok( $rdf->exists(URI1, RSS1_DESCRIPTION, 'Some Description') == 0, 'update literal' );

  ok( $rdf->exists(URI1, RSS1_DESCRIPTION, 'New Description') == 1, 'update literal' );

  my @trips = $rdf->get_triples(URI1);
  ok( scalar(@trips) == 3, 'get tiples');
}

#----------------------------------------------------------------------
# RDF::Redland
#----------------------------------------------------------------------
SKIP: {
  eval { require RDF::Redland };
  skip "RDF::Redland not installed", 19 if $@;

  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Redland',
      BaseURI => 'http://totalcinema.com/NS/test#'
  );
  
  # assert_resource - explicit constructors/nodes
  my $subj = $rdf->new_resource(URI1);
  my $pred = $rdf->new_resource(RDF_TYPE);
  my $obj  = $rdf->new_resource(RSS1_ITEM);  
  $rdf->assert_resource($subj, $pred, $obj);
  
  ok( $rdf->exists($subj, $pred, $obj) == 1, 'assert_resource as objects' );

  # assert_resource - as strings
  $rdf->assert_resource(URI1, RSS1_LINK, URI2); 

  ok( $rdf->exists(URI1, RSS1_LINK, $rdf->new_resource(URI2)) == 1, 'assert_resource as strings' );

  # assert_literal - explicit constructors/nodes
  $subj = $rdf->new_resource(URI1);
  $pred = $rdf->new_resource(RSS1_TITLE);
  $obj  = $rdf->new_literal('Some Title');
  $rdf->assert_literal($subj, $pred, $obj);

  ok( $rdf->exists($subj, $pred, $obj) == 1, 'assert_literal as objects' );

  # assert_literal - as strings
  $rdf->assert_literal(URI1, RSS1_DESCRIPTION, 'Some Description');

  ok( $rdf->exists(URI1, RSS1_DESCRIPTION, 'Some Description') == 1, 'assert_literal as strings' ); 

  # bugfix test 
  # assert_literal - numeric unquoted
  $rdf->assert_literal(URI1, RSS1_DESCRIPTION, 420);

  ok( $rdf->exists(URI1, RSS1_DESCRIPTION, 420) == 1, 'assert_literal as bare numeric string' ); 
  
  ok( $rdf->count() == 5, 'count() with no args.');
  ok( $rdf->count(URI1) == 5, 'count() with subject only.');
  ok( $rdf->count(undef, RSS1_TITLE) == 1, 'count() with pred only.');
  ok( $rdf->count(undef, undef, 'Some Title') == 1, 'count() with object only.');
  
  $rdf->remove_statements(undef, RSS1_TITLE);
  
  ok( $rdf->count() == 4, 'remove statement');
  
  $rdf->update_literal(URI1, RSS1_DESCRIPTION, 'Some Description', 'New Description');

  ok( $rdf->exists(URI1, RSS1_DESCRIPTION, 'Some Description') == 0, 'update literal' );

  ok( $rdf->exists(URI1, RSS1_DESCRIPTION, 'New Description') == 1, 'update literal' );

  my @trips = $rdf->get_triples(URI1, undef, undef);
  ok( scalar(@trips) == 4, 'get triples');

  #print $rdf->serialize();

  my $rdf2 = RDF::Helper->new(
      BaseInterface => 'RDF::Redland',
      BaseURI => 'http://totalcinema.com/NS/test#',
      Namespaces => {
        rdf => RDF_NS,
        rss => RSS1_NS
      },
      ExpandQNames => 1,
  );
  $rdf2->assert_resource( URI1, 'rdf:type', 'rss:item' );
  ok( $rdf2->exists(URI1, RDF_TYPE, RSS1_ITEM) == 1, 'assert_resource using qnames' );
  ok( $rdf2->exists(URI1, 'rdf:type', 'rss:item') == 1, 'assert_resource using qnames and checking with qnames' );
  $rdf2->assert_literal( URI1, 'rss:description', 'Some Description' );
   ok( $rdf2->exists(URI1, RSS1_DESCRIPTION, 'Some Description') == 1, 'assert_literal using qnames' ); 

  $rdf2->update_literal( URI1, 'rss:description', 'Some Description', 'Some Other Description' );
   ok( $rdf2->exists(URI1, RSS1_DESCRIPTION, 'Some Description') == 0, 'update_literal using qnames' ); 
   ok( $rdf2->exists(URI1, RSS1_DESCRIPTION, 'Some Other Description') == 1, 'update_literal using qnames' ); 
  ok( $rdf2->count(undef, 'rss:description') == 1, 'count() with qnamed pred only.'); 
  #warn $rdf2->serialize;

}
