use Test::More qw(no_plan);
use Test::Exception;

use FindBin;
use lib "$FindBin::Bin/..";

use XML::Simple qw(:strict);
use YAML;
use File::Slurp;
use MirabelKoha;

use utf8;
use open qw( :encoding(UTF-8) :std );

my $opts;

$opts = parse_arguments(["--pas-lacunaire"]);
cmp_ok($opts->{paslacunaire}, '==', 1, "--pas-lacunaire");
cmp_ok($opts->{lacunaire}, '==', 0, "--pas-lacunaire");

$opts = parse_arguments(["--paslacunaire"]);
cmp_ok($opts->{paslacunaire}, '==', 1, "--paslacunaire");
cmp_ok($opts->{lacunaire}, '==', 0, "--paslacunaire");

$opts = parse_arguments([]);
cmp_ok(not (exists$opts->{lacunaire}), '==', 1, "--paslacunaire");
cmp_ok(not (exists $opts->{lacunaire}), '==', 1, "lacunaire=undef");
cmp_ok(not (exists $opts->{paslacunaire}), '==', 1, "paslacunaire=undef");

$opts = parse_arguments([qw/--partenaire=1 --config=data --type=texte --acces=libre --pas-selection --pas-lacunaire/]);
cmp_ok(not (exists$opts->{lacunaire}), '==', 0, "* --paslacunaire *");

ok((exists webservice_parameters($opts)->{lacunaire}), "URL parameter 'lacunaire'");
cmp_ok(webservice_parameters($opts)->{lacunaire}, 'eq', '0', "URL parameter 'lacunaire'");

dies_ok {
	$opts = parse_arguments(["--paf"]);
} "Non existent argument";

dies_ok {
	$opts = parse_arguments(["--pas-lacunaire=0"]);
} "Bad argument";

throws_ok {
	$opts = parse_arguments(["--issn=a", "--issne=b"]);
	validate_options($opts);
} qr/issn/, "ISSN with ISSNE";

throws_ok {
	$opts = parse_arguments(["--issn=a", "--all"]);
	validate_options($opts);
} qr/\ball\b/, "--all with ISSN";


