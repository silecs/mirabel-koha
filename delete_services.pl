#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw/ :std :utf8 /;

use Getopt::Long qw(:config auto_help);
use Pod::Usage;
use C4::Context;
use XML::Simple;
use LWP::Simple;
use C4::Biblio;
use MARC::File::USMARC;
use YAML;
use DateTime;

use FindBin;
use lib "$FindBin::Bin";
use Mirabel;

my %opts = (
    "acces" => "",
    "depuis" => DateTime->from_epoch(epoch => time()-3600*24)->ymd(),
    "verbose" => 0,
);

GetOptions (
    \%opts,
    'man',
    'config=s',
    'configkoha|config-koha=s',
    'acces|acces-ids|accesids|a=s',
    'depuis|since|d=s',
    'simulation|dry-run|dryrun',
    'verbose|verbeux|v',
);

# Print help thanks to Pod::Usage
pod2usage({-verbose => 2, -utf8 => 1, -noperldoc => 1}) if $opts{man};

# Load configuration files.
Mirabel::init($opts{configkoha}, $opts{config});
my $config = Mirabel::read_config();

my @listOfFields;
push @listOfFields, $config->{delete}{$_}{field} for keys %{$config->{delete}};
warn "Champs à supprimer dans Koha : ", join(", ", sort {$a <=> $b} @listOfFields), "\n";

my @to_del;
if ($opts{acces}) {
    if ($opts{verbose}) {
        warn "Accès en paramètres, donc pas de téléchargement auprès de Mir\@bel.\n";
    }
    foreach (split /,/, $opts{acces}) {
        my ($start, $end) = split /\-/;
        if ($end) {
            die "Invalid list of ID" if ($end < $start);
            push @to_del, ($start .. $end);
        } else {
            push @to_del, $start;
        }
    }
} else {
    # Services deleted (since yesterday).
    my $url = $config->{base_url} . '?suppr=' . $opts{depuis};
    if ($opts{verbose}) {
        warn "Téléchargement auprès de Mir\@bel : $url\n";
    }

    my $docs = get $url;
    if (!$docs) {
        warn "ERREUR : le téléchargement de $url a échoué.\n";
        if ($opts{verbose}) {
            warn "Pour information, voici les en-têtes HTTP reçus :\n",
                join("\n", LWP::Simple::head($url)), "\n";
        }
        exit 2;
    }
    if ($opts{verbose}) {
        warn "    Téléchargement réussi : " . length($docs) . " octets.\n";
    }
    if ($opts{verbose}) {
        warn "Lecture des données reçues.\n";
    }
    my $xmlsimple = XML::Simple->new( ForceArray => ['service'] );
    my $data = $xmlsimple->XMLin($docs);

    # Delete non-existent services from biblio
    print "Supprime les services qui n'existent plus. ($url)\n";
    push @to_del, $_ for @{ $data->{service} };
}

if ($opts{verbose}) {
    warn "Services à supprimer : " . scalar(@to_del) . "\n";
}
services_delete(@to_del) if @to_del;
print "Terminé\n";

=pod
services_delete(id1, id2, ...)

Params: list of integers IDs
=cut
sub services_delete {
    my %to_del = map {$_ => 1} @_;
    my $biblios = get_biblios();

    foreach my $biblio ( @$biblios ) {
        my $biblionumber = $biblio->{biblionumber};
        my $param = MirabelKoha::isKohaVersionAtLeast(17, 11) ? $biblio : $biblio->{biblionumber};
        my $record = GetMarcBiblio( $param );

        my $countfield = 0;
        my @fields_to_delete = ();

        foreach my $field ( $record->field(@listOfFields) ) {
            my $id = $field->subfield('3');
            if ( $id and exists $to_del{$id} ) {
                if ($opts{simulation}) {
                    print "* biblionumber=$biblionumber : subfield('3')=$id\n";
                } else {
                    push @fields_to_delete, $field;
                }
            }
        }
        if ( @fields_to_delete ) {
            $record->delete_fields( @fields_to_delete );
            ModBiblioMarc( $record, $biblionumber, GetFrameworkCode($biblionumber) );
            printf "    $biblionumber: %d deleted\n", scalar(@fields_to_delete);
        }
    }
}

sub get_biblios {
    my $dbh = C4::Context->dbh;
    my $query = "SELECT biblionumber FROM biblio";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my $result = $sth->fetchall_arrayref({});
    return $result;
}


__END__

=head1 NAME

=encoding utf-8

delete_services.pl

=head1 SYNOPSIS

delete_services.pl [--depuis=YYYY-MM-DD] [--simulation]

delete_services.pl --acces-ids=1-6000 [--simulation]

Supprime des déclarations d'accès en ligne dans Koha
(champ I<field> du fichier I<config.yml>),
soit en interrogeant le webservice Mir@bel pour connaître les accès supprimés,
soit en utilisant des identifiants donnés en paramètre.

Par défaut, demande à Mir@bel les accès supprimés depuis 24 heures.

 Options :
    --help          -h
    --man

    --config=
    --config-koha=

    --acces-ids=    -a
    --depuis=       -d
    --simulation
    --verbeux       -v

=head1 DESCRIPTION

=over 8

=item B<--acces-ids=>?, B<--acces=>?, B<-a> ?

Utilise les id (Mir@bel) donnés en paramètre au lieu d'interroger le service Mir@bel.
Ces identifiants sont donnés sous la forme I<1-100,200,300-1000>.

=item B<--depuis=>YYYY-MM-DD, B<-d> YYYY-MM-DD

Lorsque le webservice de Mir@bel est interrogé, il transmet les accès supprimés
entre maintenant et cette date (par défaut, 24 h auparavant).

=item B<--simulation>, B<--dry-run>

Ne supprime rien, affiche la liste des suppressions prévues.

=back

=cut
