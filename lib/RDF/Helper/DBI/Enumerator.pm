package RDF::Helper::DBI::Enumerator;
use strict;
use warnings;
use Digest::MD5 qw(md5);
use Math::BigInt lib => 'BitVect';;
use Data::Dumper;
use RDF::Helper::Statement;

sub new {
    my $proto = shift;
    my %args = @_;
    my $class = ref($proto) || $proto;
    die "Not enough args" unless $args{model};
    my $self = bless \%args, $class;
    my $model_number = $args{model}->{model_number};
    my @where = ();
    
    my $sql = qq|
    select ljr0.URI as subject_uri,
           ljr1.URI as predicate_uri,
           ljr2.URI as object_uri,
           ljb0.Name as subject_name,
           ljl0.Value as object_value,
           ljl0.Language as object_language,
           ljl0.Datatype as object_datatype,
           ljb1.Name as object_name
    from Statements$model_number s0
        left join Resources ljr0  on ( s0.Subject = ljr0.ID )
        left join Resources ljr1 on ( s0.Predicate = ljr1.ID )
        left join Resources ljr2 on ( s0.Object = ljr2.ID )
        left join Bnodes ljb0 on ( s0.Subject = ljb0.ID )
        left join Bnodes ljb1 on ( s0.Object = ljb1.ID )
        left join Literals ljl0 on ( s0.Object = ljl0.ID )
    |;

    if ( my $stmnt = $args{statement} ) {
        if (my $s = $stmnt->subject ) {
            push @where, 's0.Subject = ' . _mysql_node_hash( $s );
        }
        
        if (my $p = $stmnt->predicate ) {
            #warn "P is $p";
            push @where, 's0.Predicate = ' . _mysql_node_hash( $p );
        }

        
        if (my $o = $stmnt->object ) {
            push @where, 's0.Object = ' . _mysql_node_hash( $o );
        }
    }
    
    if ( scalar( @where )) {
        $sql .= ' WHERE ' . join(' AND ', @where );
    }

    #warn $sql;
    my $sth = $args{model}->{dbh}->prepare( $sql );
    $sth->execute || die "SQL Error: " . $sth->errstr;
    $self->{sth} = $sth;
    return $self;
}

sub next {
    my $self = shift;
    my $row = $self->{sth}->fetchrow_hashref;
    #warn "ROW" . Dumper( $row );
    unless ( $row ) {
        $self->{sth}->finish;
        delete $self->{sth};
        return undef;
    }

    my $s = undef;
    if ( defined( $row->{subject_uri} )) {
        $s = RDF::Helper::Node::Resource->new( uri => $row->{subject_uri} );
    }
    else {
        #warn "fetching BNODE";
        $s = RDF::Helper::Node::Blank->new( identifier => $row->{subject_name} );
    }
    
    my $p = RDF::Helper::Node::Resource->new( uri => $row->{predicate_uri} );  
    my $o = undef;
    if (defined($row->{object_uri})) {
        $o = RDF::Helper::Node::Resource->new( uri => $row->{object_uri} );
    }
    elsif ( defined($row->{object_name}) ) {
        $o = RDF::Helper::Node::Blank->new( identifier => $row->{object_name} );    
    }
    else {
        $o = RDF::Helper::Node::Literal->new(
            value => $row->{object_value},
            language => $row->{object_language},
            datatype => $row->{object_datatype}
        );
    }
    return RDF::Helper::Statement->new( $s, $p, $o)
}

sub _mysql_hash {
	my $data	= shift;
	my @data	= unpack('C*', md5( $data ));
	my $sum		= Math::BigInt->new('0');
	foreach my $count (0 .. 7) {
		my $data	= Math::BigInt->new( $data[ $count ] ); #shift(@data);
		my $part	= $data << (8 * $count);
		$sum		+= $part;
	}
	return $sum;
}

sub _mysql_node_hash {
    my $node = shift;
    return undef unless $node;
	
	my $data;
	if ($node->is_resource ) {
		$data	= 'R' . $node->as_string;
	} 
	elsif ($node->is_blank) {
		$data	= 'B' . $node->as_string;
	} 
	elsif ($node->is_literal) {
		my ($val, $lang, $dt)	= ($node->literal_value, $node->literal_value_language, $node->literal_datatype);
		no warnings 'uninitialized';
		$data	= sprintf("L%s<%s>%s", $val, $lang, $dt);
	} 
	else {
		return undef;
	}
	
	my $hash	= _mysql_hash( $data );
	return $hash;
}

1;