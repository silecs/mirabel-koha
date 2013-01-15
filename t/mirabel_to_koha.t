use Test::More tests => 19;

use FindBin;
use lib "$FindBin::Bin/..";

use XML::Simple;
use YAML;
use Mirabel;

use utf8;
use open qw/ :std :utf8 /;

my $properfile = "data/properdata.txt";
open my $pdfh,$properfile or die "$properfile : $!";
my $properdata = { map { chomp; my ($key,$value) = split /;/,$_; ( $key => $value ); } <$pdfh> };

my $configfile = "data/config.yml";
my $config = YAML::LoadFile( $configfile );

my $data = Mirabel::parse_xml("data/mirabel-1.xml");

ok(exists $data->{revue}, "Au moins une revue");

my $revues = $data->{revue};
cmp_ok(scalar @$revues, '==', 1, "Une revue attendue");

my $biblio = $revues->[0];
cmp_ok($biblio->{idpartenairerevue}, '==', 30, "idpartenairerevue");
cmp_ok($biblio->{issn}, 'eq', '0001-7728', "issn");

my $services = get_services( $biblio, $properdata, $config );
cmp_ok(scalar @$services, '==', 3, "Services");

cmp_ok($services->[0]{id}, '==', 1195, "Service 1 : id");
cmp_ok($services->[1]{id}, '==', 1844, "Service 2 : id");
cmp_ok($services->[2]{id}, '==', 4515, "Service 3 : id");

isa_ok($services->[0]{service}, "HASH");
ok(exists $services->[0]{service}{couverture}, "Service 1 : le champ couverture existe");

cmp_ok($services->[0]{service}{couverture}, 'eq', "", "Service 1 : couverture");
cmp_ok($services->[1]{service}{couverture}, 'eq', "", "Service 2 : couverture");
cmp_ok($services->[2]{service}{couverture}, 'eq', "Sélection d'articles", "Service 3 : couverture");

cmp_ok($services->[0]{type}, 'eq', "som", "Service 1 : type");
cmp_ok($services->[1]{type}, 'eq', "texteint", "Service 2 : type");
cmp_ok($services->[2]{type}, 'eq', "index", "Service 3 : type");

cmp_ok($services->[0]{todo}{field}, '==', 388, "Service 1 : todo");
cmp_ok($services->[1]{todo}{field}, '==', 857, "Service 2 : todo");
cmp_ok($services->[2]{todo}{field}, '==', 389, "Service 3 : todo");

done_testing();
