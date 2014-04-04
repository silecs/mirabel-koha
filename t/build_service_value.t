use strict;
use Test::More tests => 10;

use FindBin;
use lib "$FindBin::Bin/..";

use Mirabel;

use utf8;
use open qw( :encoding(UTF-8) :std );

my $service = {
	id => 1195,
	nom => "Dialnet",
	acces => "Libre",
	urlservice => "",
	urldirecte => "http://dialnet.unirioja.es/",
	debut => "2000",
	fin => "",
};

ok(!defined build_service_value("inconnu", $service), "inconnu");
cmp_ok(build_service_value("nom", $service), 'eq', "Dialnet", "nom");
cmp_ok(build_service_value("id", $service), 'eq', "1195", "id");
cmp_ok(build_service_value("inconnu|nom", $service), 'eq', "Dialnet", "inconnu|nom");
cmp_ok(build_service_value("nom|id", $service), 'eq', "Dialnet", "nom|id");
cmp_ok(build_service_value("urlservice|urldirecte", $service), 'eq', "http://dialnet.unirioja.es/", "urlservice|urldirecte");
cmp_ok(build_service_value("urldirecte|urlservice", $service), 'eq', "http://dialnet.unirioja.es/", "urldirecte|urlservice");
cmp_ok(build_service_value("id nom", $service), 'eq', "1195 Dialnet", "id nom");
cmp_ok(build_service_value("debut fin", $service), 'eq', "2000", "debut fin");
cmp_ok(build_service_value("fin debut", $service), 'eq', "2000", "fin debut");
#cmp_ok(build_service_value("debut fin:(periode)", $service), 'eq', "Depuis 2000", "debut fin:(periode)");
#cmp_ok(build_service_value("debut fin :(periode)", $service), 'eq', "Depuis 2000", "debut fin :(periode)");
#cmp_ok(build_service_value("fin debut :(periode)", $service), 'eq', "Jusqu'à 2000", "fin debut :(periode)");
#$service->{fin} = "2005";
#cmp_ok(build_service_value("debut fin :(periode)", $service), 'eq', "2000 à 2005", ":(periode) avec 2 dates");

