package Mirabel;

use LWP::UserAgent;
use URI;
use XML::Simple;
use utf8;
use open qw( :encoding(UTF-8) :std );

use strict;
use Exporter;
our @ISA = qw( Exporter );

our $VERSION = 2.0;

our @EXPORT = qw(
  &query_webservice
  &get_services
  &read_service_config
  &read_data_config
  &build_service_value
);


my $path;

sub init {
    if (!$path) {
        $path = get_config_path();
        die "/!\\ ERROR path is not set: You must set the configuration files path in koha_conf.xml\n"
            unless $path;
    }
}



sub build_service_value {
        my $serviceKey = shift;
        my $service = shift;

        my $value;

        my ($fields, $others) = split(/:/, $serviceKey);
        $serviceKey = $fields;
        $others ||= '';
        $others =~ s/(^\(|)$//;

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
                $value .= $others if $count > 1 && ref($service->{ $_ }) ne 'HASH';
                $value .= $service->{ $_ } . ' ' if ref($service->{ $_ }) ne 'HASH';
            }
            $value =~ s/\s*$//;
        }

        unless ( $value ) {
            $value = $service->{ $serviceKey };
        }
        if ($value) {
            $value =~ s/-00//g;
        }
        return $value;
}

sub query_webservice {
    my ($url, $url_args) = @_;

    my $ua = LWP::UserAgent->new;
    my $full_url = URI->new($url);
    $full_url->query_form($url_args);
    print "URL : $full_url\n";
    my $response = $ua->get($full_url);
    if ($response->is_success) {
        return parse_xml($response->decoded_content);
    } else {
        die "L'interrogation du webservice Mirabel a échoué : " . $response->status_line;
    }
}

sub parse_xml {
    my ($input) = @_;
	die "Le XML reçu de Mirabel est vide !\n"
        unless $input;
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
    my $properdata = { map { chomp;  if (/^\s*$/) { (); } else { my ($key,$value) = split /;/,$_; ( $key => $value );} } <$pdfh> };
    close $pdfh;
    return $properdata;
}

# private function
sub get_config_path {
    # Read the koha-conf.xml and get configuration path
    my $kohaConfFile = $ENV{'KOHA_CONF'};
    die "Environment variables '\$KOHA_CONF' is not set.\n" unless $kohaConfFile;
    my $xml = XML::Simple->new();
    my $koha_conf = $xml->XMLin($kohaConfFile) ;
    warn "Config Koha : $kohaConfFile\n";

    my $path = $koha_conf->{config}->{mirabel};
    if ($path && ref($path) ne 'HASH') {
        if (-f $path) {
            $path =~ s{/[^/]+?$}{/}; # TODO: use a proper dirname() function
        }
        warn "Config Mirabel (config.yml et properdata.txt) lue dans $path\n";
        return $path;
    }
    warn "Le chemin vers les fichiers de configuration pour Mirabel n'est pas valide dans la config Koha.\n";
    return "";
}

1;

