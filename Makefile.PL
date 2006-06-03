# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name            'Baseball-Sabermetrics';
all_from        'lib/Baseball/Sabermetrics.pm';

# Specific dependencies
#requires        'Carp'              => 0;
build_requires  'Test::More'        => '0.42';
recommends      'WWW::Mechanize'    => '0.01';

no_index        'directory'         => 'examples';

auto_install;
WriteAll;
