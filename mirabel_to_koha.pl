#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw/ :std :utf8 /;

use Getopt::Long qw(:config auto_help);
use Pod::Usage;
use C4::Context;
use XML::Simple;
use C4::Biblio;
use MARC::File::USMARC;
use YAML;

use FindBin;
use lib "$FindBin::Bin";
use Mirabel;

# remove "experimental" warning in Perl >= 5.18
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

my %opts = (
    'config' => '',
    'configkoha' => '',
);

GetOptions (
    \%opts,
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
);
$opts{lacunaire} = !$opts{paslacunaire} if defined $opts{paslacunaire} ;
$opts{selection} = !$opts{passelection} if defined $opts{passelection};

# Print help thanks to Pod::Usage
pod2usage({-verbose => 2, -utf8 => 1, -noperldoc => 1}) if $opts{man};

# Load configuration files.
Mirabel::init(@opts{qw/configkoha config/});
my $properdata = Mirabel::read_data_config();
my $config = Mirabel::read_service_config();

if ( (grep {defined} @opts{qw/issn issnl issne/}) > 1 ) {
    pod2usage(-verbose => 0, -message => "## ERREUR : issn, issnl, et issne sont incompatibles.\n");
}
if ( $opts{all} and (grep {defined} @opts{qw/partenaire issn issnl issne type acces lacunaire selection ressource/}) ) {
    pod2usage(-verbose => 0, -message => "## ERREUR : --all est incompatible avec d'autres options.\n");
}

my %url_args = ();
if ($opts{all}) {
    $url_args{all} = undef;
} else {
    foreach (qw/partenaire issn issnl issne type acces selection revue ressource mesressources lacunaire selection/) {
        $url_args{$_} = $opts{$_} if $opts{$_};
    }
}

my $data = Mirabel::query_webservice($config->{base_url}, \%url_args);

$| = 1;
foreach my $biblio ( @{ $data->{revue} } ) {
    if (!$biblio->{idpartenairerevue}) {
        printf "La revue d'ISSN %s n'a pas d'identifiant local.\n", $biblio->{issn};
        next;
    }
    print "Mise à jour de la notice " . $biblio->{idpartenairerevue} . ":\n";
    my $services = Mirabel::get_services( $biblio, $properdata, $config->{update} );

    my $record = GetMarcBiblio( $biblio->{idpartenairerevue} );
    print "    => La notice existe: " . ( $record ? "oui\n" : "non\n" );

    if ($record and !$opts{simulation}) {
        my $result = import_services($biblio, $services, $record);
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

__END__

=head1 NAME

=encoding utf8

mirabel_to_koha.pl

=head1 SYNOPSIS

mirabel_to_koha.pl [options]

 Options :
    --help          -h
    --man

    --partenaire=   -p   Identifiant numérique du partenaire
    --issn=         -s   ISSN
    --issnl=        -l   ISSNl
    --issne=        -e   ISSNe
    --type=         -t   Type, parmi (texte ; sommaire ; resume ; indexation ; tout)
    --acces=        -a   Accès, parmi (libre ; restreint ; tout)
    --all
    --pas-lacunaire      Exclut les accès lacunaires (certains numéros manquent)
    --pas-selection      Exclut les accès sélections (certains articles manquent)
    --revue=             Seulement les accès de la revue : liste d'ID séparés par ","
    --ressource=    -r   Seulement les accès de la ressource : liste d'ID séparés par ","
    --mesressources      Seulement pour les ressources suivies par ce partenaire

    --simulation
    --config=
    --config-koha=

=head1 DESCRIPTION

Lire B<README.md> pour des informations détaillées.

=cut
