#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw/ :std :utf8 /;

use C4::Context;
use C4::Biblio;
use MARC::File::USMARC;

use FindBin;
use lib "$FindBin::Bin";
use MirabelKoha;
use Mirabel;

# remove "experimental" warning in Perl >= 5.18
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

my %opts = %{parse_arguments(\@ARGV)};

# Load configuration files.
Mirabel::init($opts{configkoha}, $opts{config});
my $config = Mirabel::read_service_config();

validate_options(\%opts);


my $data = Mirabel::query_webservice($config->{base_url}, webservice_parameters(\%opts));

$| = 1;
foreach my $biblio ( @{ $data->{revue} } ) {
    if (!$biblio->{idpartenairerevue}) {
        printf "La revue d'ISSN %s n'a pas d'identifiant local.\n", $biblio->{issn};
        next;
    }
    print "Mise à jour de la notice " . $biblio->{idpartenairerevue} . ":\n";
    my $services = Mirabel::get_services( $biblio, $config->{types}, $config->{update} );

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
    --collection=   -c   Seulement les accès de la collection : liste d'ID séparés par ","
    --mesressources      Seulement pour les ressources suivies par ce partenaire

    --simulation
    --config=
    --config-koha=

=head1 DESCRIPTION

Lire B<README.md> pour des informations détaillées.

=cut
