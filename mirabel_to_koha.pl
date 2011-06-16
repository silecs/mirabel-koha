#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use C4::Context;
use XML::Simple;
use LWP::Simple;
use C4::Biblio;
use MARC::File::USMARC;
use utf8;
use YAML;
use open qw/ :std :utf8 /;

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


if ( ( $issn && $issnl ) || ( $issn && $issne ) || ( $issnl && $issne ) ) { warn "***ERROR: -n, -e, -l, can't be used together\n"; print_usage(); exit }
if ( $all && ( $partenaire || $issn || $issnl || $issne || $type || $acces ) ) { warn "***ERROR: -all can't be used with an other option"; print_usage(); exit }

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

my $properfile = "properdata.txt";
open my $pdfh,$properfile or die "$properfile : $!";
my $properdata = { map { chomp; my ($key,$value) = split /;/,$_; ( $key => $value ); } <$pdfh> };

my $configfile = "config.yml";
my $config = YAML::LoadFile( $configfile );

my $docs = get $url;
my $xmlsimple = XML::Simple->new( ForceArray => [ 'revue', 'service' ], );
my $data = $xmlsimple->XMLin($docs);

$| = 1;
foreach my $biblio ( @{ $data->{revue} } ) {
    print "Mise à jour de la notice " . $biblio->{idpartenairerevue} . ":\n";
    my $result = doit( $biblio );
    print ( $result == $biblio->{idpartenairerevue} ? "Notice modifiée avec succés\n" : "Erreur lors de la modification de la notice\n" );
    print "===================================================================\n\n";
}

##################################################################################
###                            SUB                                             ###
##################################################################################

sub doit {
    my $biblio = shift;

    my @services;
    foreach ( keys %{ $biblio->{services}->{service} } ) {
        $biblio->{services}->{service}->{$_}->{id} = $_;
        push @services, $biblio->{services}->{service}->{$_};
    }

    my $record = GetMarcBiblio( $biblio->{idpartenairerevue} );
    print "    => La notice existe: " . ( $record ? "oui\n" : "non\n" );

    my $result = '';
    if ( $record ) {
	foreach my $service ( @services ) {
	    my $type = $properdata->{ $service->{type}  };
	    my $id = $service->{id};
	    my $todo = $config->{ $type } if $config->{ $type };
	    return unless $todo;

	    #delete_same( $record, $todo, $service);

	    my $newfield = createField( $todo, $service );
	    reorder_subfields( $newfield );

	    my $exists = 0;
	    foreach my $field ( $record->field( $todo->{field} ) ) {
		my $f3 = $field->subfield('3');
		if ( $f3 && $id eq $f3 ) {
		    $exists = 1;
		    $field->replace_with($newfield);
		    print "    field " . $todo->{field} . " updated\n"; 
		}
	    }
	    unless ( $exists ) {
		$record->insert_fields_ordered( $newfield );
		print "    field " . $todo->{field} . " created\n"; 
	    }
	    print $newfield->as_formatted ."\n";
	}
	my $fmk = GetFrameworkCode( $biblio->{idpartenairerevue} );
	$result = ModBiblioMarc( $record, $biblio->{idpartenairerevue}, $fmk );
    }
    return $result;
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
		$value .= " à " if $count > 1 && ref($service->{ $_ }) ne 'HASH'; 
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

sub get_biblios {
    my $dbh = C4::Context->dbh;
    my $query = "SELECT biblionumber from biblio";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my $result = $sth->fetchall_arrayref({});
    return $result;
}

sub in_array {
    my ($arr,$search_for) = @_;
    my %items = map {$_ => 1} @$arr;
    return (exists($items{$search_for}))?1:0;
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
