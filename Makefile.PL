use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Mail-Graph',
    'VERSION_FROM'	=> 'lib/Mail/Graph.pm', # finds $VERSION
    'PREREQ_PM'		=> {
	IO::Stringy 		=> 2.01,
	Mail::Util		=> 1.44,
	Mail::MboxParser	=> 0.32,
	MIME::Tools		=> 5.411,
	GD::Graph		=> 1.33, 
	GD			=> 1.38, 
	GD::Text		=> 0.82, 
	Date::Calc		=> 5.0, 
	}, # e.g., Module::Name => 1.1
    'LIBS'		=> [''], # e.g., '-lm'
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
    'INC'		=> '', # e.g., '-I/usr/include/other'
);
