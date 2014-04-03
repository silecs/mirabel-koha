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

use FindBin;
use lib "$FindBin::Bin";
use Mirabel;

# remove "experimental" warning in Perl >= 5.18
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

my ($man, $partenaire, $issn, $issnl, $issne, $type, $acces, $couverture, $delete, $all, $lacunaire, $selection, $ressource );

GetOptions (
    'man' => \$man,
    'partenaire|p=i' => \$partenaire,
    'issn|n=s' => \$issn,
    'issnl|l=s' => \$issnl,
    'issne|e=s' => \$issne,
    'type|t=s' => \$type,
    'acces|a=s' => \$acces,
    'couverture|c=s' => \$couverture,
    'delete|d' => \$delete,
    'all' => \$all,
    'paslacunaire' => \$lacunaire,
    'passelection' => \$selection,
    'ressource|r=s' => \$ressource,
);

# Print help thanks to Pod::Usage
pod2usage({-verbose => 2, -utf8 => 1, -noperldoc => 1}) if $man;

# Load configuration files.
my $properdata = Mirabel::read_data_config();
my $config = Mirabel::read_service_config();

if ( ( $issn && $issnl ) || ( $issn && $issne ) || ( $issnl && $issne ) ) {
    warn "***ERROR: -n, -e, -l, can't be used together\n";
    pod2usage(-verbose => 0);
}
if ( $all && ( $partenaire || $issn || $issnl || $issne || $type || $acces ) ) {
    warn "***ERROR: -all can't be used with an other option";
    pod2usage(-verbose => 0);
}

my $url = $config->{base_url} . '?';

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
    $url .= $url =~ /\?$/ ? "lacunaire=$lacunaire" : "&lacunaire=0" if $lacunaire;
    $url .= $url =~ /\?$/ ? "selection=$selection" : "&selection=0" if $selection;
    $url .= $url =~ /\?$/ ? "ressource=$ressource" : "&ressource=$ressource" if $ressource;
}

print "URL: $url\n";
my $docs = get $url;
my $data = Mirabel::parse_xml($docs);

$| = 1;
foreach my $biblio ( @{ $data->{revue} } ) {
    if (!$biblio->{idpartenairerevue}) {
        printf "La revue d'ISSN %s n'a pas d'identifiant local.\n", $biblio->{issn};
        next;
    }
    print "Mise à jour de la notice " . $biblio->{idpartenairerevue} . ":\n";
    my $services = get_services( $biblio, $properdata, $config->{update} );

    my $record = GetMarcBiblio( $biblio->{idpartenairerevue} );
    print "    => La notice existe: " . ( $record ? "oui\n" : "non\n" );

    if ($record) {
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
    $field->delete_subfield({}); # remove every subfield

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
                $value .= $service->{ $_ } . ' ' if ref($service->{ $_ }) ne 'HASH';
            }
            $value =~ s/\s*$//;
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

__END__

=head1 NAME

=encoding utf8

mirabel_to_koha.pl

=head1 SYNOPSIS

mirabel_to_koha.pl [options]

 Options :
    --help          -h
    --man
    --partenaire=   -p
    --issn=         -s
    --issnl=        -l
    --issne=        -e
    --type=         -t
    --acces=        -a
    --delete        -d
    --all
    --paslacunaire
    --passelection
    --ressource=    -r

=head1 DESCRIPTION

Lire B<README.md> pour des informations détaillées.

=cut
