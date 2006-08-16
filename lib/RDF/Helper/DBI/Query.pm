package RDF::Helper::DBI::Query;
use strict;
use warnings;
use Data::Dumper;

sub new {
    my $proto = shift;
    my ($query_string, $query_lang, $model) = @_;
    warn "new query called";
    die "NO RDQL" if $query_lang eq 'rdql';
    my $self = {
      Model => $model,
      Query => $query_string,
      QueryLanguage => $query_lang
    };
    my $class = ref( $proto ) || $proto;
    return bless $self, $class;
}

sub dump_sql {
    my $self = shift;
    my $c = $self->compiler;
    return $c->compile;
}

sub dump_count_sql {
    my $self = shift;
    my $c = $self->compiler;
    return $c->compile_count;
}

sub execute {
    my $self = shift;
    my $c = $self->compiler;
    my $sql = $c->compile;
    #warn "executing sql $sql";
    my $sth = $self->{Model}->{dbh}->prepare( $sql );
    $sth->execute || die "SQL Error: " . $sth->errstr;
    $self->{sth} = $sth;
    $self->{parse_tree} = $c->{parse_tree};
}

sub execute_count {
    my $self = shift;
    my $c = $self->compiler;
    my $sql = $c->compile_count;
    my $sth = $self->{Model}->{dbh}->prepare( $sql );
    $sth->execute || die "SQL Error: " . $sth->errstr;
    $self->{sth} = $sth;
    $self->{parse_tree} = $c->{parse_tree};
}

sub selectrow_hashref {
    my $self = shift;
    $self->execute unless $self->{sth};
    my $row = $self->{sth}->fetchrow_hashref;
    #warn "HASREF ROW" . Dumper( $row );
    unless ( $row ) {
        $self->{sth}->finish;
        delete $self->{sth};
        delete $self->{parse_tree};
        return undef;
    }
    return $self->fixup_row_hash( $row );
}

sub selectrow_arrayref {
    my $self = shift;
    $self->execute unless $self->{sth};
    my $row = $self->{sth}->fetchrow_hashref;
    #warn "ARRAYREF ROW" . Dumper( $row );
    unless ( $row ) {
        $self->{sth}->finish;
        delete $self->{sth};
        delete $self->{parse_tree};
        return undef;
    }
    return $self->fixup_row_array( $row );
}

sub select_count {
    my $self = shift;
    $self->execute_count;
    my $row = $self->{sth}->fetchrow_arrayref;
    return '0' unless $row;
    my $count = $row->[0];
    $self->{sth}->finish;
    delete $self->{sth};
    delete $self->{parse_tree};    
    return $count || '0';
}

sub fixup_row_hash {
    my $self = shift;
    my $row = shift;
    my %temp = map { lc($_) => $row->{$_} } ( keys( %{$row} ) );
    $row = \%temp;
    #warn Dumper( $self->{parse_tree}->{variables}, $row );
    my %hash = map { $_->[1] =>  defined ( $row->{$_->[1].'_value'} ) ? $row->{$_->[1].'_value'} : $row->{$_->[1] . '_uri'} } @{$self->{parse_tree}->{variables}};
    #warn "RETURNING HASH" . Dumper( \%hash );
    return \%hash;
}

sub fixup_row_array {
    my $self = shift;
    my $row = shift;
    my %temp = map { lc($_) => $row->{$_} } ( keys( %{$row} ) );
    $row = \%temp;
    #warn Dumper( $self->{parse_tree}->{variables}, $row );
    my @out = map { $row->{$_->[1].'_value'} || $row->{$_->[1].'_uri'} } @{$self->{parse_tree}->{variables}};
    #warn "RETRURNING " . Dumper( \@out );
    return \@out
}

sub compiler {
    my $self = shift;
    my $lang = $self->{QueryLanguage} || 'sparql';
    return  RDF::Helper::DBI::Query::SPARQL->new( QueryLanguage => $lang, Query => $self->{Query}, ModelName => $self->{Model}->{model} );
}

1;

package RDF::Helper::DBI::Query::SPARQL;
use strict;
use warnings;
use RDF::Query::Compiler::SQL;
use RDF::Query::Parser::SPARQL;
use Data::Dumper;

sub new {
    my $proto = shift;
    my %args = @_;
    my $class = ref( $proto ) || $proto;
    
    die "Pass a SPARQL query" unless $args{Query};
    $args{ModelName} ||= 'ilpdata';
    
    my $p = RDF::Query::Parser::SPARQL->new();
    
    my $tree = $p->parse( $args{Query} );
    
    die "Query parsing error: " .  $p->error . "\n" unless $tree;
    #warn "THE TREE!" . Dumper( $tree );
    $args{parse_tree} = $tree;
    return bless \%args, $class;
}


sub compile {
    my $self = shift;
    my $c = RDF::Query::Compiler::SQL->new( $self->{parse_tree}, $self->{ModelName} );
    my $sql = $c->compile;
    die "SQL compilation error: "  . $c->error . "\n" unless $sql;
    $self->{compiled} = $sql;
    return $self->{compiled};
}

sub compile_count {
    my $self = shift;
    my $sql = defined $self->{compiled} ? $self->{compiled} : $self->compile;
    $sql =~ s/^\s*\bSELECT(.*?)FROM\b/SELECT COUNT\(\*\) FROM/smg;
    return $sql;
}

1;