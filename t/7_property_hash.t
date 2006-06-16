use Test::More tests => 19;

use RDF::Helper;
use RDF::Helper::RDFRedland::TiedPropertyHash;
use Data::Dumper;
#----------------------------------------------------------------------
# RDF::Core
#----------------------------------------------------------------------


SKIP: {
  eval { require RDF::CoreXXX };
  skip "RDF::Core not installed", 1 if $@;
  
}

#----------------------------------------------------------------------
# RDF::Redland
#----------------------------------------------------------------------
SKIP: {
  eval { require RDF::Redland };
  skip "RDF::Redland not installed", 4 if $@;

  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Redland',
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
  $rdf->include_rdfxml(filename => 't/data/use.perl.rss');
  
  my %hash = ();
  
  tie %hash, RDF::Helper::RDFRedland::TiedPropertyHash, $rdf, 'urn:x-test:1'; 
  is( tied(%hash), 'urn:x-test:1', 'Tied property "" overloading' );
  ok( tied(%hash) eq 'urn:x-test:1', 'Tied property eq overloading' );
  ok( tied(%hash) == 'urn:x-test:1', 'Tied property == overloading' );
  
  $hash{foo} = 'wibble';
  $hash{bar} = 'norkle';
  
  is( $hash{foo}, 'wibble', 'Set hash property "foo"' );
  is( $hash{bar}, 'norkle', 'Set hash property "bar"' );
  
  my $tester = delete $hash{foo};
  is( $tester, 'wibble', 'Delete hash property "foo"');
  
  my $hashref = $rdf->tied_property_hash('urn:x-test:1');
  ok( $hashref, 'tied_property_hash' );
  
  $hashref->{'dc:creator'} = 'ubu';
  is( $hashref->{'dc:creator'}, 'ubu', 'Set hash property "dc:creator"' );

  $hashref->{'dc:language'} = [qw( en-US jp fr es )];
  is( join(',', sort(@{$hashref->{'dc:language'}})), join(',', sort(qw( en-US jp fr es ))), 'set / return multiple property "dc:language" values' );

  $hashref->{'dc:language'} = [qw( en-US jp es )];
  is( join(',', sort(@{$hashref->{'dc:language'}})), join(',', sort(qw( en-US jp es ))), 'set / return different property "dc:language" values' );

  $hashref->{'dc:language'} = "en-US";
  is( ref($hashref->{'dc:language'}), '', 'Set single value into "dc:language" property' );
  is( $hashref->{'dc:language'}, 'en-US', 'Fetch value from "dc:language" property' );

  $hashref->{'link'} = 'http://www.google.com/';
  my ($link_res_1) = $rdf->get_statements('urn:x-test:1', 'http://purl.org/rss/1.0/link', undef);
  ok($link_res_1->object->is_resource, 'Set a string that looks like a URI encodes it as a resource');

  $hashref->{'link'} = ['http://www.google.com/'];
  my ($link_res_2) = $rdf->get_statements('urn:x-test:1', 'http://purl.org/rss/1.0/link', undef);
  ok($link_res_2->object->is_resource, 'Set an arrayref that looks like a URI encodes it as a resource');

  my %useperl;
  tie %useperl, RDF::Helper::RDFRedland::TiedPropertyHash, $rdf, 'http://use.perl.org/'; 
  is( $useperl{title}, 'use Perl', 'Get existing RSS property "title"' );
  is( $useperl{'dc:language'}, 'en-us', 'Get existing RSS property "dc:language"' );

  is( ref($useperl{'image'}), 'HASH', 'Resource node returns a hash reference' );
  is( $useperl{'image'}->{url}, 'http://use.perl.org/images/topics/useperl.gif', 'Traverse resource node to image -> url property' );

  #%hash = ();
#   foreach my $t ( $rdf->get_triples( 'http://use.perl.org/', 'http://purl.org/dc/elements/1.1/norkle') ) {
#       warn Dumper( $t );
#   }
  #warn $rdf->serialize;
}
