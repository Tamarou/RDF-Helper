use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'RDF::Helper',
    VERSION_FROM      => 'lib/RDF/Helper.pm', # finds $VERSION
    PREREQ_PM         => {
        'Data::Uniqid' => 0,
    }, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/RDF/Helper.pm', # retrieve abstract from module
       AUTHOR         => 'Kip Hampton <kip@local>') : ()),
);
