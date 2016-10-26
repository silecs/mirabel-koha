use strict;
use Test::More tests => 15;

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
my $biblio = {
	issn => "0001-7728",
	url => "http://www.dalloz-revues.fr/revues/AJDA-27.htm",
	idmirabel => "1",
	idpartenairerevue => "419587",
};

ok(!defined build_service_value("inconnu", $service, $biblio), "inconnu");
cmp_ok(build_service_value("nom", $service, $biblio), 'eq', "Dialnet", "nom");
cmp_ok(build_service_value("id", $service, $biblio), 'eq', "1195", "id");
cmp_ok(build_service_value("inconnu|nom", $service, $biblio), 'eq', "Dialnet", "inconnu|nom");
cmp_ok(build_service_value("nom|id", $service, $biblio), 'eq', "Dialnet", "nom|id");
cmp_ok(build_service_value("urlservice|urldirecte", $service, $biblio), 'eq', "http://dialnet.unirioja.es/", "urlservice|urldirecte");
cmp_ok(build_service_value("urldirecte|urlservice", $service, $biblio), 'eq', "http://dialnet.unirioja.es/", "urldirecte|urlservice");
cmp_ok(build_service_value("id nom", $service, $biblio), 'eq', "1195 Dialnet", "id nom");
cmp_ok(build_service_value("debut fin", $service, $biblio), 'eq', "2000", "debut fin");
cmp_ok(build_service_value("fin debut", $service, $biblio), 'eq', "2000", "fin debut");
cmp_ok(build_service_value("debut fin:(periode)", $service, $biblio), 'eq', "depuis 2000", "debut fin:(periode)");
cmp_ok(build_service_value("debut fin :(periode)", $service, $biblio), 'eq', "depuis 2000", "debut fin :(periode)");
cmp_ok(build_service_value("fin debut :(periode)", $service, $biblio), 'eq', "jusqu'à 2000", "fin debut :(periode)");
cmp_ok(build_service_value("titre.url", $service, $biblio), 'eq', "http://www.dalloz-revues.fr/revues/AJDA-27.htm", "titre.url");
$service->{fin} = "2005";
cmp_ok(build_service_value("debut fin :(periode)", $service, $biblio), 'eq', "de 2000 à 2005", ":(periode) avec 2 dates");

