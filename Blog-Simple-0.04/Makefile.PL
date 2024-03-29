use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Blog::Simple',
    'VERSION_FROM'	=> 'Simple.pm', # finds $VERSION
	dist => {
		TARFLAGS => '--create --verbose --file=$(DISTVNAME).tar --mode=a+x'	
	},
    'PREREQ_PM'		=> {'XML::XSLT' => '0.32'}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Simple.pm', # retrieve abstract from module
       AUTHOR     => 'J. A. Robson <gilad@arbingersys.com>') : ()),
);
