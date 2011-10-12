#!/usr/bin/env perl
use strict;
use warnings;
use feature ':5.10';


use Carp;
use Config::General;
use Data::Dumper; #$Data::Dumper::Indent = 2;
use List::MoreUtils qw/apply natatime/;

use FindBin;
use lib "$FindBin::Bin/../lib";

use LogReporter;

my $ConfigDir = "/usr/local/logreporter/conf/";
my $PerlVersion = "$^X";

### Load config
my $all_config = read_config($ConfigDir . 'logreporter.conf');
my $source_config = delete $all_config->{sources};
my $service_config = delete $all_config->{services};
say Dumper($all_config,$source_config,$service_config);

## Process config
my ($all_sources, $all_services) = ({},{});

foreach my $src_name (keys %$source_config){
    my $src_config = $source_config->{$src_name};
    my $files = $src_config->{files};
    my $filters = [];
    
    my $it = natatime 2, @{$src_config->{filters}};
    while( my ($name, $conf) = $it->() ){
        eval "use LogReporter::Filter::$name ()";
        die $@ if $@;
        push @$filters, "LogReporter::Filter::$name"->new(
            %$conf
        );
    }

    say Dumper($files,$filters);
    my $src_obj = LogReporter::Source::File->new(
        name => $src_name,
        files => $files,
        filters => $filters,
    );
    
    $all_sources->{$src_name} = $src_obj;
}

foreach my $svc_name (keys %$service_config){
    my $svc_config = $service_config->{$svc_name};
    my $sources = $svc_config->{sources};
    my $filters = $svc_config->{filters};
    
    my $src_objs = [ map { $all_sources->{$_} } @$sources ];

    eval "use LogReporter::Service::$svc_name ()";
    die $@ if $@;
    my $svc_obj = "LogReporter::Service::$svc_name"->new(
        filters => $filters,
        sources => $src_objs,
    );
}

say "Initializing sources";
apply { $_->init() } values %$all_sources;
say "Initializing services";
apply { $_->init() } values %$all_services;

say "Running sources";
apply { $_->run() } values %$all_sources;

say "Finalizing sources";
apply { $_->finalize() } values %$all_sources;
say "Finalizing services";
apply { $_->finalize() } values %$all_services;

say "Collecting output";
my $all_output = "";
foreach my $service (values %$all_services){
    $all_output .= $service->get_output();
}

print "FINAL OUTPUT:\n--------------------------------------------\n";
print $all_output;
print "--------------------------------------------\n";
exit;


sub read_config {
    my ($name) = @_;
    our $config;
    do $name;
    return $config;
}

