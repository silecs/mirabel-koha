package MirabelKoha;

use strict;
use utf8;
use open qw( :encoding(UTF-8) :std );

use Getopt::Long qw(:config auto_help);
use Pod::Usage;

use C4::Context;
use C4::Biblio;
use MARC::File::USMARC;
use Mirabel;

require Exporter;
use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# set the version for version checking
our $VERSION     = 1.00;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
	&parse_arguments
	&validate_options
	&webservice_parameters
	&import_services
);


sub parse_arguments {
	my $argv = shift;
	my $opts = {
		'config' => '',
		'configkoha' => '',
	};

	Getopt::Long::GetOptionsFromArray (
		$argv,
		$opts,
		'man|manual',
		'config=s',
		'configkoha|config-koha=s',
		'partenaire|p=i',
		'issn|n=s',
		'issnl|l=s',
		'issne|e=s',
		'type|t=s',
		'acces|a=s',
		'all',
		'paslacunaire|pas-lacunaire',
		'passelection|pas-selection',
		'revue=s',
		'ressource|r=s',
		'mesressources',
		'simulation|dry-run|dryrun',
	) or die("Erreur : paramètres non valides.\n");

	if (defined $opts->{paslacunaire}) {
		$opts->{lacunaire} = $opts->{paslacunaire} ? 0 : 1;
	}
	if (defined $opts->{passelection}) {
		$opts->{selection} = $opts->{passelection} ? 0 : 1;
	}

	# Print help thanks to Pod::Usage
	pod2usage({-verbose => 2, -utf8 => 1, -noperldoc => 1}) if $opts->{man};

	return $opts;
}

sub validate_options {
	my $opts = shift;

	if ( (grep {defined($opts->{$_})} qw/issn issnl issne/) > 1 ) {
		pod2usage(-exitval => "NOEXIT", -verbose => 0);
		die("## ERREUR : issn, issnl, et issne sont incompatibles.\n");
	}
	if ( $opts->{all} and (grep {defined($opts->{$_})} qw/partenaire issn issnl issne type acces lacunaire selection ressource/) ) {
		pod2usage(-exitval => "NOEXIT", -verbose => 0);
		die("## ERREUR : --all est incompatible avec d'autres options.\n");
	}
}

sub webservice_parameters {
	my $opts = shift;
	my $url_args = {};
	if ($opts->{all}) {
		$url_args->{all} = undef;
	} else {
		foreach (qw/partenaire issn issnl issne type acces selection revue ressource mesressources lacunaire selection/) {
			$url_args->{$_} = $opts->{$_} if (defined $opts->{$_});
		}
	}
	return $url_args;
}

sub import_services {
    my ($biblio, $services, $record) = @_;
    foreach my $s ( @$services ) {

        #delete_same( $record, $todo, $service);

        my $newfield = createField( $s->{todo}, $s->{service} );
        reorder_subfields( $newfield );

        my $exists = 0;
        foreach my $field ( $record->field( $s->{todo}{field} ) ) {
            my $f3 = $field->subfield('3');
            if ( $f3 && $s->{id} eq $f3 ) {
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
    $field->delete_subfield('match' => qr//); # remove every subfield

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
        my $value = build_service_value($todo->{$key}, $service);
        next unless $value;

        if ( $key ne "field" ) {
            if ( $fieldcreated ) {
                $field->add_subfields( $key => $value );
            } else {
                #print "    => ( + ) Champ créé: " . $todo->{field} . "\n";
                $field = MARC::Field->new( $todo->{field},'','', $key => $value );
                $fieldcreated = 1;
            }
        }
    }

    return $field;
}


1;

