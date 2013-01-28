package Mirabel;

use XML::Simple;

use strict;
use Exporter;
our @ISA = qw( Exporter );

our $VERSION = 2.0;

our @EXPORT = qw(
    &get_services
    &getConfigPath
);

sub parse_xml {
	my ($input) = @_;
	my $xmlsimple = XML::Simple->new( ForceArray => [ 'revue', 'service' ], SuppressEmpty => '');
	return $xmlsimple->XMLin($input);
}

sub get_services {
    my ($biblio, $properdata, $config) = @_;

    my $services = [];
    foreach ( sort {$a <=> $b} keys %{ $biblio->{services}->{service} } ) {
	my $service = $biblio->{services}->{service}->{$_};
        $service->{id} = $_;
	if (!defined $properdata->{ $service->{type} }) {
	    warn "Type de service inconnu : $service->{type}\n";
	    next;
	}
	my $type = $properdata->{ $service->{type}  };
	if (!defined $config->{ $type }) {
	    warn "Pas d'action pour le service : $type\n";
	    next;
	}
	my $id = $service->{id};
	my $todo = $config->{ $type } if $config->{ $type };
	next unless $todo;
        push @$services, {
	    type => $type,
	    id => $service->{id},
	    todo => $config->{ $type },
	    service => $service
	};
    }
    return $services;
}

sub getConfigPath {
    # Read the koha-conf.xml and get configuration path
    my $kohaConfFile = $ENV{'KOHA_CONF'};
    die "Environment variables '\$KOHA_CONF' is not set.\n" unless $kohaConfFile;
    my $xml = XML::Simple->new();
    my $koha_conf = $xml->XMLin($kohaConfFile) ;

    my $path = $koha_conf->{config}->{mirabel};
    return $path if $path && ref($path) ne 'HASH';
    return 0;

}

1;

