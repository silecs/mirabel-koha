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
    "acces-ids" => "",
    "depuis" => DateTime->from_epoch(epoch => time()-3600*24)->ymd(),
);

GetOptions (
    \%opts,
    'man',
    'acces|acces-ids|accesids|a=s',
    'depuis|since|d=s',
    'simulation|dry-run|dryrun',
);

# Print help thanks to Pod::Usage
pod2usage(-verbose => 2) if $opts{man};

# Load configuration files.
my $config = Mirabel::read_service_config();

my @listOfFields;
push @listOfFields, $config->{delete}{$_}{field} for keys %{$config->{delete}};

my $biblios = get_biblios();

my @to_del;
if ($opts{acces}) {
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
    # Services deleted since yesterday.
    my $url = $config->{base_url} . '?suppr=' . $opts{depuis};

    my $docs = get $url;
    my $xmlsimple = XML::Simple->new( ForceArray => ['service'] );
    my $data = $xmlsimple->XMLin($docs);

    # Delete non-existent services from biblio
    print "Supprime les services qui n'existent plus. ($url)\n";
    push @to_del, $_ for @{ $data->{service} };
}

foreach my $biblio ( @$biblios ) {
    my $biblionumber = $biblio->{biblionumber};
    my $record = GetMarcBiblio( $biblionumber );

    my $countfield = 0;

    #foreach my $field ( $record->field(qw/857 388 389 398/) ) {
    foreach my $field ( $record->field(@listOfFields) ) {
        my $id = $field->subfield('3');
        if ( $id && in_array( \@to_del, $id) ) {
            $countfield++;
            if ($opts{simulation}) {
                printf("* %s\n", $record->title()) if ($countfield == 1);
                printf "    %4d. $id\n", $countfield;
            } else {
                $record->delete_field( $field );
            }
        }
    }
    if ( $countfield and !$opts{simulation} ) {
        my $fmk = GetFrameworkCode( $biblionumber );
        ModBiblioMarc( $record, $biblionumber, $fmk );
    }
    print "$biblionumber: $countfield deleted\n";
}
print "Terminé\n";

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


__END__

=head1 NAME

=encoding utf8

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
    --acces-ids=    -a
    --depuis=       -d
    --simulation

=head1 DESCRIPTION

=over 8

=item B<--acces-ids=>?, B<--acces=>?, B<-a> ?

Utilise les id (Mir@bel) donnés en paramètre au lieu d'interroger le service Mir@bel.
Ces identifiants sont données sous la forme I<1-100,200,300-1000>.

=item B<--depuis=>YYYY-MM-DD, B<-d> YYYY-MM-DD

Lorsque le webservice de Mir@bel est interrogé, il transmet les accès supprimés
entre maintenant et cette date (par défaut, 24 h auparavant).

=item B<--simulation>, B<--dry-run>

Ne supprime rien, affiche la liste des suppressions prévues.

=back

=cut
