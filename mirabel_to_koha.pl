#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw/ :std :utf8 /;

use Getopt::Long;
use C4::Context;
use XML::Simple;
use LWP::Simple;
use C4::Biblio;
use MARC::File::USMARC;
use YAML;

use FindBin;
use lib "$FindBin::Bin";
use Mirabel;

my ( $partenaire, $issn, $issnl, $issne, $type, $acces, $couverture, $delete, $all );

GetOptions (
    'partenaire|p=i' => \$partenaire,
    'issn|n=s' => \$issn,
    'issnl|l=s' => \$issnl,
    'issne|e=s' => \$issne,
    'type|t=s' => \$type,
    'acces|a=s' => \$acces,
    'couverture|c=s' => \$couverture,
    'delete|d' => \$delete,
    'all' => \$all
);


if ( ( $issn && $issnl ) || ( $issn && $issne ) || ( $issnl && $issne ) ) {
    warn "***ERROR: -n, -e, -l, can't be used together\n";
    print_usage();
    exit;
}
if ( $all && ( $partenaire || $issn || $issnl || $issne || $type || $acces ) ) {
    warn "***ERROR: -all can't be used with an other option";
    print_usage();
    exit;
}

my $url = "http://www.reseau-mirabel.info/devel/rest.php?";

if ( $all ) {
    $url .= "all";
} else {
    $url .= $url ~~ /\?$/ ? "partenaire=$partenaire" : "&partenaire=$partenaire" if $partenaire;
    $url .= $url ~~ /\?$/ ? "issn=$issn" : "&issn=$issn" if $issn;
    $url .= $url ~~ /\?$/ ? "issnl=$issnl" : "&issnl=$issnl" if $issnl;
    $url .= $url ~~ /\?$/ ? "issne=$issne" : "&issne=$issne" if $issne;
    $url .= $url ~~ /\?$/ ? "type=$type" : "&type=$type" if $type;
    $url .= $url ~~ /\?$/ ? "acces=$acces" : "&acces=$acces" if $acces;
    $url .= $url ~~ /\?$/ ? "couverture=$couverture" : "&couverture=$couverture" if $couverture;
}

my $path = getConfigPath();
die "/!\\ ERROR path is not set: You must set the configuration files path in koha_conf.xml\n" unless $path;

my $properfile = $path . "properdata.txt";
open my $pdfh,$properfile or die "$properfile : $!";
my $properdata = { map { chomp; my ($key,$value) = split /;/,$_; ( $key => $value ); } <$pdfh> };

my $configfile = $path . "config.yml";
my $config = YAML::LoadFile( $configfile );

print "URL: $url\n";
my $docs = get $url;
my $data = Mirabel::parse_xml($docs)

$| = 1;
foreach my $biblio ( @{ $data->{revue} } ) {
    if (!$biblio->{idpartenairerevue}) {
        printf "La revue d'ISSN %s n'a pas d'identifiant local.\n", $biblio->{issn};
        next;
    }
    print "Mise à jour de la notice " . $biblio->{idpartenairerevue} . ":\n";
    my $services = get_services( $biblio, $properdata, $config );

    my $record = GetMarcBiblio( $biblio->{idpartenairerevue} );
    print "    => La notice existe: " . ( $record ? "oui\n" : "non\n" );

    if ($record) {
	$result = import_services($biblio, $services, $record);
	print ( $result == $biblio->{idpartenairerevue} ? "Notice modifiée avec succès\n" : "Erreur lors de la modification de la notice\n" );
	print "===================================================================\n\n";
    }
}

##################################################################################
###                            SUB                                             ###
##################################################################################

sub import_services {
    my ($biblio, $services, $record) = @_;
    foreach my $s ( @$services ) {
	#delete_same( $record, $todo, $service);

	my $newfield = createField( $s->{todo}, $s->{service} );
	reorder_subfields( $newfield );

	my $exists = 0;
	foreach my $field ( $record->field( $s->{todo}{field} ) ) {
	    my $f3 = $field->subfield('3');
	    if ( $f3 && $id eq $f3 ) {
		$exists = 1;
		$field->replace_with($newfield);
		print "    field " . $s->{todo}{field} . " updated\n"; 
	    }
	}
	unless ( $exists ) {
	    $record->insert_fields_ordered( $newfield );
	    print "    field " . $s->{todo}{field} . " created\n"; 
	}
	print $newfield->as_formatted ."\n";
    }
    my $fmk = GetFrameworkCode( $biblio->{idpartenairerevue} );
    return ModBiblioMarc( $record, $biblio->{idpartenairerevue}, $fmk );
}

sub reorder_subfields {
    my $field = shift;

    my %list = map { $$_[0] => $$_[1] } ($field->subfields());
    $field->delete_subfields();

    foreach my $key (sort (keys(%list))) {
	$field->add_subfields( $key  => $list{$key} );
    }
}

sub delete_same {
    my $record = shift;
    my $todo = shift;
    my $service = shift;

    #foreach my $field ( $record->field( $todo->{field} ) ) {
    #    my $serv = $field->subfield('b');
    #    my $acces = $field->subfield('c');
    #    if ( $serv eq $service->{'nom'} && $acces eq $service->{'acces'} ) {
    #        print "    => ( x ) Champ supprimé: " . $todo->{field} . "\n";
    #        $record->delete_field( $field );
    #    }
    #}

    foreach my $field ( $record->field( $todo->{field} ) ) {
	my $id = $field->subfield('3');
    }
}

sub createField {
    my $todo = shift;
    my $service = shift;

    my $field;
    my $fieldcreated = 0;
    foreach my $key ( keys %$todo ) {

	my $serviceKey = $todo->{$key};
	my $value;

	# Cas des valeurs séparées par |. (ou)
	my ($fields, $others) = split(/:/, $serviceKey);
	$serviceKey = $fields;
	$others ||= '';
	$others =~ s/(^\(|)$//;

	my @or = split /\|/, $serviceKey;
	if ( scalar( @or ) > 1 ) {
	    foreach ( @or ) {
		$value = $service->{ $_ } if $service->{ $_ } && ref($service->{ $_ }) ne 'HASH';
		last if $value;
	    }
	}

	# Cas des valeurs séparées par un espace. ( Concatenation )
	my @and = split /\s/, $serviceKey;
	if ( scalar( @and ) > 1 ) {
	    my $count = 0;
	    foreach ( @and ) {
		$count++;
		$value .= $others if $count > 1 && ref($service->{ $_ }) ne 'HASH'; 
		$value .= $service->{ $_ } if ref($service->{ $_ }) ne 'HASH';
	    }
	}

	unless ( $value ) {
	    $value = $service->{ $serviceKey };
	}

	next unless $value;
	$value =~ s/-00//g;

	unless ( $key eq "field" ) {
	    unless ( $fieldcreated ) {
		#print "    => ( + ) Champ créé: " . $todo->{field} . "\n";
		$field = MARC::Field->new( $todo->{field},'','', $key => $value );
		$fieldcreated = 1;
	    } else {
		$field->add_subfields( $key => $value );
	    }
	}
    }

    return $field;
}

sub getConfigPath {
    # Read the koha-conf.xml and get configuration path
    my $kohaConfFile = $ENV{'KOHA_CONF'};
    die "Environment variables '\$KOHA_CONF' is not set.\n" unless $kohaConfFile;
    my $xml = XML::Simple->new();
    my $koha_conf = $xml->XMLin($kohaConfFile) ;

    my $path = $koha_conf->{config}->{mirabel};
    return $path if $path && ref($path) ne 'HASH';
    return 0;

}

sub print_usage {
    print "Using mirabel_to_koha :\n\n";
    print "    -p --partenaire				Filter by partenaire number\n";
    print "    -n --issn				Filter by issn\n";
    print "    -l --issnl				Filter by issnl\n";
    print "    -e --issne				Filter by issne\n";
    print "    -t --type				Filter by type\n";
    print "    -a --acces				Filter by acces\n";
    print "    -h --help				Print usage\n";
}
