package RDF::Helper;
use strict;
use warnings;
use vars qw($VERSION);
$VERSION = '0.21';

sub new {
    my ($ref, %args) = @_;
    my $class = delete $args{BaseInterface};
    defined $class or die "You must choose a BaseInterface class like RDF::Core or RDF::Redland \n";

    if ($class eq 'RDF::Core' ) {
        require RDF::Helper::RDFCore;
        return  RDF::Helper::RDFCore->new( %args );
    }
    elsif ( $class eq 'RDF::Redland' ) {
        require RDF::Helper::RDFRedland;
        return  RDF::Helper::RDFRedland->new( %args );
    }
    else {
        die "No Helper class defined for BaseInterface'$class' \n";
    }
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

RDF::Helper - Perl extension for blah blah blah

=head1 SYNOPSIS

  use RDF::Helper;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for RDF::Helper, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Kip Hampton, E<lt>khampton@totalcinema.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004-2006 by Kip Hampton. Mike Nachbaur

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
