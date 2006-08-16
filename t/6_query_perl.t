use Test::More tests => 18;

use RDF::Helper;
use Data::Dumper;
#----------------------------------------------------------------------
# RDF::Core
#----------------------------------------------------------------------


SKIP: {
  eval { require RDF::Core};
  skip "RDF::Core Query facilites lacking", 6 if $@;

  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Core',
      BaseURI => 'http://totalcinema.com/NS/test#',
      Namespaces => { 
        dc => 'http://purl.org/dc/elements/1.1/',
        rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        '#default' => "http://purl.org/rss/1.0/",
        slash => "http://purl.org/rss/1.0/modules/slash/",
        taxo => "http://purl.org/rss/1.0/modules/taxonomy/",
        syn => "http://purl.org/rss/1.0/modules/syndication/",
        admin => "http://webns.net/mvcb/",
     },
  );
  
  test( $rdf );
}



#----------------------------------------------------------------------
# RDF::Redland
#----------------------------------------------------------------------
SKIP: {
  eval { require RDF::Redland };
  skip "RDF::Redland not installed", 6 if $@;

  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Redland',
      BaseURI => 'http://totalcinema.com/NS/test#',
      QueryInterface => 'RDF::Helper::RDFRedland::Query',
      Namespaces => { 
        dc => 'http://purl.org/dc/elements/1.1/',
        rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        '#default' => "http://purl.org/rss/1.0/",
        slash => "http://purl.org/rss/1.0/modules/slash/",
        taxo => "http://purl.org/rss/1.0/modules/taxonomy/",
        syn => "http://purl.org/rss/1.0/modules/syndication/",
        admin => "http://webns.net/mvcb/",
     },
  );
  
  test( $rdf );
}

#----------------------------------------------------------------------
# DBI
#----------------------------------------------------------------------
SKIP: {
  eval { require DBI };
  skip "DBI not installed", 6 if $@;
  unless ( $ENV{DBI_DSN} and $ENV{DBI_USER} and $ENV{DBI_PASS} ) {
      skip "Environment not set up for running DBI tests, see the README", 6
  }

  my $rdf = RDF::Helper->new(
      BaseInterface => 'DBI',
      QueryInterface => 'RDF::Helper::DBI::Query',
      BaseURI => 'http://totalcinema.com/NS/test#',
      ModelName => 'testmodel',
      DBI_DSN => $ENV{DBI_DSN},
      DBI_USER => $ENV{DBI_USER},
      DBI_PASS => $ENV{DBI_PASS},
      CreateNew => 1,
      Namespaces => { 
        dc => 'http://purl.org/dc/elements/1.1/',
        rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        '#default' => "http://purl.org/rss/1.0/",
        slash => "http://purl.org/rss/1.0/modules/slash/",
        taxo => "http://purl.org/rss/1.0/modules/taxonomy/",
        syn => "http://purl.org/rss/1.0/modules/syndication/",
        admin => "http://webns.net/mvcb/",
     },
  );
  
  test( $rdf );
}

sub test {
  my $rdf = shift;
  $rdf->include_rdfxml(filename => 't/data/use.perl.rss');
  
  my $ref = $rdf->deep_prophash('http://use.perl.org/');
  
  #warn Dumper( $rdf, $ref );
  
  ok( scalar keys %{$ref} > 0, 'property hash contains key values' );
  my $hash_count = scalar keys %{$ref->{items}};
  
  #warn Dumper( $ref->{items} );
  #warn Dumper( $ref->{items}->{_1} );  
  
  ok ( $hash_count > 0, 'items hash key contains key values' );
  
  my $query1 = qq|
      SELECT ?creator ?date ?subject
      WHERE  (?s dc:subject ?subject)
             (?s dc:creator ?creator)
             (?s dc:date ?date)
      USING dc FOR <http://purl.org/dc/elements/1.1/>
  |;
  
  SKIP: {
    skip "RDQL not implemented by DBI::Query", 1 if $rdf->isa('RDF::Helper::DBI');
  my $result1_count = 0;
  
  my $q_obj = $rdf->new_query( $query1, 'rdql' );
  while ( my $item = $q_obj->selectrow_hashref ) {
      #warn Dumper( $item );
      if ( defined $item->{creator} and 
           defined $item->{subject} and
           defined $item->{date} ) {
             $result1_count++;
      }
  }
  
  #warn "ITEMS: $result1_count BY hash: $hash_count\n";
  ok( $hash_count == $result1_count, 'query returned the expected number of results' );
  
  my $array_count = 0;
  
  while ( my $array = $q_obj->selectrow_arrayref ) {
      #warn Dumper( $array );
      $array_count++ if scalar @{$array} == 3;
  }
  
  ok( $hash_count == $array_count, 'DBI-like interface returned the expected number of results' );
  }
    my $query2 = qq|
      PREFIX dc: <http://purl.org/dc/elements/1.1/>
      SELECT ?creator ?date ?subject
      WHERE  {
          ?s dc:subject ?subject .
          ?s dc:creator ?creator .
          ?s dc:date ?date
      }
  |;
  
  my $result2_count = 0;
  my $q_obj2 = $rdf->new_query( $query2, 'sparql' );
  while ( my $item = $q_obj2->selectrow_hashref ) {
      #warn Dumper( $item );
      if ( defined $item->{creator} and 
           defined $item->{subject} and
           defined $item->{date} ) {
             $result2_count++;
      }
  }
  ok( $hash_count == $result2_count, 'sparql query returned the expected number of results' );
  
        
    $rdf->query_interface('RDF::Helper::RDFQuery');

  
    my $result3_count = 0;
    my $q_obj3 = $rdf->new_query( $query2, 'sparql' );
    while ( my $item = $q_obj3->selectrow_hashref ) {
        #warn Dumper( $item );
        if ( defined $item->{creator} and 
             defined $item->{subject} and
             defined $item->{date} ) {
             $result3_count++;
        }
    }
  warn "Hash count $hash_count ER@ count $result3_count \n";

    ok( $hash_count == $result3_count, 'RDF::Query sparql query returned the expected number of results' );

}
