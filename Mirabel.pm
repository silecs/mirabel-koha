package Mirabel;

use LWP::UserAgent;
use URI;
use XML::Simple;
use YAML;

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
  &build_service_value
);


my $path;

sub init {
    if (!$path) {
        $path = get_config_path(@_);
        die "/!\\ ERROR path is not set: You must set the configuration files path in koha_conf.xml\n"
            unless $path;
    }
}



sub build_service_value {
    my $serviceKey = shift;
    my $service = shift;
    my $biblio = shift;

    my $value;

    my $filter;
    if ($serviceKey =~ s/\s*:\((\w+)\)\s*$//) {
        $filter = "filter_value_" . $1;
        $filter = (exists &{$filter}) ? \&{$filter} : "";
    }

    # Cas des valeurs séparées par | (ou)
    my @or = split /\|/, $serviceKey;
    if ( scalar( @or ) > 1 ) {
        foreach ( @or ) {
            $value = read_single_value($_, $service, $biblio);
            last if $value;
        }
    }

    # Cas des valeurs séparées par un espace.
    my @and = split /\s/, $serviceKey;
    if ( scalar( @and ) > 1 ) {
        my @subvalues = map { read_single_value($_, $service, $biblio) } @and;
        if (@and and scalar(@and) != scalar(@subvalues)) {
            printf STDERR
                "Attention: %d champs attendus d'après la configuration, %d remplis\n",
                scalar(@and), scalar(@subvalues);
        }
        $value = $filter ? &$filter(@subvalues) : join(" ", grep {!/^$/} @subvalues);
    }

    if ( not $value ) {
        $value = read_single_value($serviceKey, $service, $biblio);
    }
    if ($value) {
        $value =~ s/-00//g;
    }
    return $value;
}

sub read_single_value {
    my ($name, $service, $biblio) = @_;
    if ($name =~ m/^titre\.(.+)/) {
        my $bname = $1;
        if (exists $biblio->{ $bname } && ref($biblio->{ $bname }) ne 'HASH') {
            return $biblio->{ $bname };
        }
    } elsif (exists $service->{ $name } && ref($service->{ $name }) ne 'HASH') {
        return $service->{ $name };
    }
    return;
}

sub filter_value_dates {
    return join(" ", map { $a = $_; $a =~ s/-00//g; $a; } @_);
}

sub filter_value_periode {
    my ($deb, $fin) = map { $a = $_; $a =~ s/-00//g; $a; } @_;
    if ($deb and $fin) {
        return "de $deb à $fin";
    } elsif ($deb and !$fin) {
        return "depuis $deb";
    } elsif (!$deb and $fin) {
        return "jusqu'à $fin";
    } else {
        return "";
    }
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
    my $data = $xmlsimple->parse_string($input);
	die "\nAucune revue ne correspond (la liste reçue de Mirabel est vide).\n" unless $data and exists $data->{revue};
	return $data;
}

sub get_services {
    my ($biblio, $types, $config) = @_;

    my $services = [];
    foreach ( sort {$a <=> $b} keys(%{ $biblio->{services}->{service} }) ) {
        my $service = $biblio->{services}->{service}->{$_};
        $service->{id} = $_;
        if (!defined $types->{ $service->{type} }) {
            warn "Type de service inconnu : $service->{type}\n";
            next;
        }
        my $type = $types->{ $service->{type}  };
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

# private function
sub get_config_path {
    my $kohaConfFile = shift;
    $path = shift;

    if (!$path) {
        if (!$kohaConfFile) {
            # Read the koha-conf.xml and get configuration path
            $kohaConfFile = $ENV{'KOHA_CONF'};
            die "Environment variable '\$KOHA_CONF' is not set, and no parameter --config-koha.\n" unless $kohaConfFile;
        }
        die("$kohaConfFile est introuvable.\n") unless -f $kohaConfFile;
        my $xml = XML::Simple->new();
        my $koha_conf = $xml->XMLin($kohaConfFile) ;
        warn "Config Koha : $kohaConfFile\n";

        $path = $koha_conf->{config}->{mirabel};
        if ($path && ref($path) ne 'HASH') {
            if (-f $path) {
                $path =~ s{/[^/]+?$}{/}; # TODO: use a proper dirname() function
            }
        } else {
			warn "Le fichier $kohaConfFile ne contient pas le champ config.mirabel.\n";
		}
    }
    $path =~ s{([^/])$}{$1/}; # add trailing /
    die "Le chemin vers les fichiers de configuration pour Mirabel n'est pas un répertoire valide : $path\n"
        unless (-d $path and -r "${path}config.yml");

    warn "Config Mirabel (config.yml) lue dans $path\n";
    return $path;
}

1;

