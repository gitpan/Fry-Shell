use ExtUtils::MakeMaker;
WriteMakefile(NAME=>'Fry::Shell',
	VERSION_FROM=>'lib/Fry/Shell.pm',
	PREREQ_PM=>{Term::ReadLine=>'1.01', Class::Data::Global=>'0.01'}
);
