package Mirabel;

use XML::Simple;
use utf8;
use open qw( :encoding(UTF-8) :std );

use strict;
use Exporter;
our @ISA = qw( Exporter );

our $VERSION = 2.0;

our @EXPORT = qw(
  &get_services
  &read_service_config
  &read_data_config
);


my $path;

sub init {
    if (!$path) {
        $path = get_config_path();
        die "/!\\ ERROR path is not set: You must set the configuration files path in koha_conf.xml\n"
            unless $path;
    }
}


sub parse_xml {
    my ($input) = @_;
    my $xmlsimple = XML::Simple->new( ForceArray => [ 'revue', 'service' ], SuppressEmpty => '');
    return $xmlsimple->XMLin($input);
}

sub get_services {
    my ($biblio, $properdata, $config) = @_;

    my $services = [];
    foreach ( sort {$a <=> $b} keys(%{ $biblio->{services}->{service} }) ) {
        my $service = $biblio->{services}->{service}->{$_};
        $service->{id} = $_;
        if (!defined $properdata->{ $service->{type} }) {
            warn "Type de service inconnu : $service->{type}\n";
            next;
        }
        my $type = $properdata->{ $service->{type}  };
        if (defined $config->{ $type }) {
            push @$services, {
                type => $type,
                id => $service->{id},
                todo => $config->{ $type },
                service => $service
              };
        } else {
            warn "Pas d'action pour le service : $type\n";
        }
    }
    return $services;
}

sub read_service_config {
    init();
    my $configfile = $path . "config.yml";
    return YAML::LoadFile( $configfile );
}

sub read_data_config {
    init();
    my $properfile = $path . "properdata.txt";
    open my $pdfh, "<", $properfile or die "$properfile : $!";
    my $properdata = { map { chomp; next if /^\s*$/; my ($key,$value) = split /;/,$_; ( $key => $value ); } <$pdfh> };
    close $pdfh;
    return $properdata;
}

sub get_config_path {
    # Read the koha-conf.xml and get configuration path
    my $kohaConfFile = $ENV{'KOHA_CONF'};
    die "Environment variables '\$KOHA_CONF' is not set.\n" unless $kohaConfFile;
    my $xml = XML::Simple->new();
    my $koha_conf = $xml->XMLin($kohaConfFile) ;

    my $path = $koha_conf->{config}->{mirabel};
    return $path if $path && ref($path) ne 'HASH';
    return "";
}

1;
