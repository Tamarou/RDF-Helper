package RDF::Helper::DBI::Model;
use strict;
use warnings;
use RDF::Helper::Statement;
use RDF::Helper::DBI::Enumerator;
use Math::BigInt lib => 'BitVect';
use Digest::MD5 qw(md5);


sub new {
	my $class	= shift;
	my $dbh		= shift;
	my $model	= shift;
	my $self	= bless( {
					dbh				=> $dbh,
					model			=> $model,
					model_number	=> _mysql_hash( $model ),
					sttime			=> time
				}, $class );
}

# sub model {
# 	my $self	= shift;
# 	return [ @{ $self }{qw(dbh model)} ];
# }

sub add_statements {
    my $self = shift;
    my @statements = @_;

    my $model_number = $self->{model_number};
    my $dbh = $self->{dbh};
        
    foreach my $stmnt ( @statements ) {
        my $stmnt = shift;
        
        my $s_hash = _mysql_node_hash( $stmnt->subject );
        my $p_hash = _mysql_node_hash( $stmnt->predicate );
        my $o = $stmnt->object;
        my $o_hash = _mysql_node_hash( $o );
        my $o_type = undef;

        if ( $o->is_blank ) {
            $o_type = 'bnode';
        }
        elsif ( $o->is_resource ) {
            $o_type = 'resource';
        }
        else {
            $o_type = 'literal';
        }
        my $ctxt = 0;
        unless ( $self->statemethashes_exists( $s_hash, $p_hash, $o_hash ) ) {
                my $main_insert = $dbh->prepare("INSERT into Statements$model_number (Subject, Predicate, Object, Context) VALUES ($s_hash, $p_hash, $o_hash, '$ctxt')") or die $dbh->errstr;;
            $main_insert->execute() or die $dbh->errstr;
        }
        
        if ( $stmnt->subject->is_blank ) {
            $self->add_bnode_db( $stmnt->subject, $s_hash );        
        }
        else {
            $self->add_resource_db( $stmnt->subject, $s_hash );
        }
        $self->add_resource_db( $stmnt->predicate, $p_hash );
        
        my $o_method = 'add_' . $o_type . '_db';
        $self->$o_method( $o, $o_hash );
        
    }
}

sub get_statements {
    my $self = shift;
    my @ret_array = ();

    my $e = $self->get_enumerator(@_);
    while( my $s = $e->next ) {
        push @ret_array, $s;
    }
    
    #warn "RET STEMNT" . Dumper( \@ret_array );
    return @ret_array;
}

sub get_enumerator {
    my $self = shift;
    my $statement = shift;

    return RDF::Helper::DBI::Enumerator->new(
        model => $self,
        statement => $statement
    );
}

sub remove_statements {
    my $self = shift;

    my $model_number = $self->{model_number};
    my $dbh = $self->{dbh};
    my $del_count = 0;
    foreach my $stmnt ( $self->get_statements(@_) ) {
        my $s_hash = _mysql_node_hash( $stmnt->subject );
        my $p_hash = _mysql_node_hash( $stmnt->predicate );
        my $o_hash = _mysql_node_hash( $stmnt->object );
        $dbh->do("DELETE FROM Statements$model_number WHERE Subject = $s_hash AND Predicate = $p_hash AND Object = $o_hash") or die $dbh->errstr;
        $del_count++;
    }
    return $del_count;
}

sub count {
    my $self = shift;
    my ( $subj, $pred, $obj ) = @_;
    my $s_hash = defined $subj ? _mysql_node_hash( $subj ) : undef;
    my $p_hash = defined $pred ? _mysql_node_hash( $pred ) : undef;
    my $o_hash = defined $obj ? _mysql_node_hash( $obj ) : undef;
    return $self->statementhashes_count( $s_hash, $p_hash, $o_hash ); 
}

sub resourcehash_in_db {
    my $self = shift;
    my $hash = shift;
    die "Nope" unless $hash;
    return $self->_in_db( 'Resources', $hash );
}

sub literalhash_in_db {
    my $self = shift;
    my $hash = shift;
    die "Nope" unless $hash;
    return $self->_in_db( 'Literals', $hash );
}

sub bnodehash_in_db {
    return $_[0]->_in_db( 'Bnodes', $_[1] );
}

sub statementhashes_count {
    my $self = shift;
    my ( $s, $p, $o ) = @_;
    my $model_number = $self->{model_number};
    my $sql = "SELECT COUNT(*) FROM  Statements$model_number";
    my @where = ();
    my @bindings = ();
    push @where, "Subject = $s" if defined $s;
    push @where, "Predicate = $p" if defined $p;
    push @where, "Object = $o" if defined $o;
    if ( scalar @where ) {
        $sql .= " WHERE " . join(" AND ", @where);
    }
    my $dbh = $self->{dbh};
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute or die $sth->errstr;
    my $found = 0;
    while ( my $ret = $sth->fetchrow_arrayref) {
        #warn "found STMNT!!!";
        $found = $ret->[0] || 0;
    }
    $sth->finish;
    #warn "did find? $found";
    return $found;
}

sub statemethashes_exists {
    my $self = shift;
    my $count = $self->statementhashes_count( @_ );
    return $count > 0 ? 1 : undef;
}

sub add_resource_db {
    my $self = shift;
    my $node = shift;
    my $hash = shift || _mysql_node_hash( $node );
    unless ( $self->resourcehash_in_db( $hash ) ) {
        return $self->_add_db( 'Resources', ['ID', 'URI'], [$hash, $node->as_string] );
    }
    return 1;
}

sub add_literal_db {
    my $self = shift;
    my $node = shift;
    my $hash = shift || _mysql_node_hash( $node );
    my ($val, $lang, $type) = ($node->literal_value, $node->literal_value_language, $node->literal_datatype );
    unless ( $self->literalhash_in_db( $hash )) {
        no warnings 'uninitialized';
        return $self->_add_db( 'Literals', ['ID', 'Value', 'Language', 'Datatype'], [$hash, $val, "$lang", "$type"] );
    }
    return 1;
}

sub add_bnode_db {
    my $self = shift;
    my $node = shift;
    my $hash = shift || _mysql_node_hash( $node );
    unless ( $self->bnodehash_in_db( $hash )) {
        return $self->_add_db( 'Bnodes', ['ID', 'Name'], [$hash, $node->as_string] );
    }
    return 1;
}

sub delete_resource_db {
    my $self = shift;
    my $node = shift;
    my $hash = shift || _mysql_node_hash( $node );
    return $self->_delete_db( 'Resources', $hash );
}

sub delete_literal_db {
    my $self = shift;
    my $node = shift;
    my $hash = shift || _mysql_node_hash( $node );
    return $self->_delete_db( 'Literals', $hash );
}

sub delete_bnode_db {
    my $self = shift;
    my $node = shift;
    my $hash = shift || _mysql_node_hash( $node );
    return $self->_delete_db( 'Bnodes', $hash );
}

sub _delete_db {
    my $self = shift;
    my ( $table, $id ) = @_;
    my @where = ();
    my $dbh = $self->{dbh};
    my $sql = "DELETE FROM $table WHERE ID = $id";
    my $ret = $dbh->do($sql) or die $dbh->errstr;
    return $ret;
}


sub _add_db {
    my $self = shift;
    my ( $table, $cols, $data ) = @_;
    #warn "add db data  $table " . Dumper( $cols, $data ); 
    my $dbh = $self->{dbh};
    my $sql = "INSERT INTO $table (" . join(', ', @$cols ) . ") VALUES (" . (join ', ',  map { $dbh->quote($_) } @{$data}) . ")";
    #warn "SQL $sql";
    my $ret = $dbh->do($sql) or die $dbh->errstr;
    return $ret;
}

sub _in_db {
    my $self = shift;
    my $table = shift;
    my $hash = shift;
    return undef unless $table && $hash;
    #warn "FEH $table $hash \n";
    my $dbh = $self->{dbh};
    my $sth = $dbh->prepare("SELECT ID FROM $table WHERE ID = $hash")  or die $dbh->errstr;
    $sth->execute() or die $sth->errstr;

    my $found = 0;
    while ( my $ret = $sth->fetchrow_arrayref) {
        #warn "found!!!";
        $found++;
    }
    #warn "did find? $found";
    return $found > 0 ? 1 : undef;;
}


sub bootstrap_model_db {
    my $dbh = shift;
    my $model_name = shift;
    my $do_nuke = shift;

    my $model_number = _mysql_hash( $model_name );
    my $table_name = "Statements" . $model_number;

    my $driver = $dbh->{Driver}->{Name};    
    #warn "recreating table $table_name \n";
    my $sth = $dbh->prepare("SELECT ID from Models where Name = '$model_name'") or die $dbh->errstr;
    $sth->execute() or die $sth->errstr;
    my $row = $sth->fetchrow_arrayref;
    if (defined $row->[0]) {
        return unless defined $do_nuke;
        $dbh->do("DELETE FROM Models where Name = '$model_name'") or die $dbh->errstr;
        eval {
        $dbh->do("DROP TABLE $table_name") or die $dbh->errstr;
        }
        
    }

    my $main_ins = "INSERT INTO Models (ID, Name) VALUES ($model_number, '$model_name')";
    $dbh->do($main_ins) or die $dbh->errstr;

    my $create_table = undef;
  
    if ( $driver =~ /^mysql/i ) {
          $create_table = "CREATE TABLE $table_name  (Subject bigint unsigned NOT NULL, Predicate bigint unsigned NOT NULL, Object bigint unsigned NOT NULL,
          Context bigint unsigned NOT NULL,
          KEY Context (Context),
          KEY SubjectPredicate (Subject,Predicate),
          KEY PredicateObject (Predicate,Object),
          KEY ObjectSubject (Object,Subject),
          UNIQUE S_P_O  (Subject, Predicate, Object)
        ) TYPE=MyISAM DELAY_KEY_WRITE=1 MAX_ROWS=100000000 AVG_ROW_LENGTH=33";
    }
    else {
          $create_table = "CREATE TABLE $table_name (Subject numeric(20) NOT NULL, Predicate numeric(20) NOT NULL, Object numeric(20) NOT NULL, Context numeric(20) NOT NULL )";
    }
    $dbh->do($create_table) || die $dbh->errstr;
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