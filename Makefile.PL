use ExtUtils::MakeMaker;

my $VERSION = '1.2';

my $ABSTRACT = "Module for simply interacting with webservices";

WriteMakefile(
 	'NAME'		=> 'SOAP::Lite::Simple',
	'ABSTRACT'	=> $ABSTRACT,
	'AUTHOR'	=> 'Leo Lapworth',
	'VERSION'	=> $VERSION, # finds $VERSION
	'PREREQ_PM'		=> {
		'SOAP::Lite'	=> 0.6,
		'SOAP::Data::Builder' => 0.8,
		'XML::LibXML' 		=> 0.6,
		'Test::More' 	=> 0.6,
		'File::Slurp' 	=> 0.1,
    	}, 
);
