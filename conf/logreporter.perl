require DateTime::Span;
require DateTime;
$Range = DateTime::Span->from_datetimes(
    start => DateTime->new(qw/year 2011 month 10 day 16 hour 0 minute 0 second 0/),
    end => DateTime->now(),
);
{
    sources => {
        'maillog' => {
            files => [qw(
                /var/log/syslog/mail.log
                /var/log/archive/mail.log.*
                /var/log/archive/mail.log-*
            )],
            filters => [
                ISO8601 => { format => '^(\S+)\s+' },
                DateRange => { range => $Range },
                Syslog => { format => '^(?<h>\w+)\s+\[(?<l>[^\]]+)\]\s+', },
                Parser => { format => 'postfix/(?<sp>\w+)\(\d+\): ', },
            ],
        },
        'iptables' => {
            files => [qw(
                /var/log/syslog/iptables.log
                /var/log/archive/iptables.log.*
                /var/log/archive/iptables.log-*
            )],
            filters => [
                ISO8601 => { format => '^(\S+)\s+' },
                DateRange => { range => $Range },
                Syslog => { format => '^(?<h>\w+)\s+' },
            ],
        },
        'named' => {
            files => [qw(
                /var/log/named/main.log
                /var/log/archive/named/main.log.*
                /var/log/archive/named/main.log-*
            )],
            filters => [
                Strptime => { finder => '^(\d+-\w+-\d+\s+\d+:\d+:\d+)\.\d+\s+', format => '%d-%b-%Y%t%H:%M:%S' },
                DateRange => { range => $Range },
                Parser => { format => '^(?<f>\w+):\s+(?<l>\w+):\s+' },
            ],
        },
        'named_query' => {
            files => [qw(
                /var/log/named/query.log
                /var/log/archive/named/query.log.*
                /var/log/archive/named/query.log-*
                /var/log/archive/named/query.log-2011101*
            )],
            filters => [
                Strptime => { finder => '^(\d+-\w+-\d+\s+\d+:\d+:\d+)\.\d+\s+', format => '%d-%b-%Y%t%H:%M:%S' },
                DateRange => { range => $Range },
            ],
        },
        'auth' => {
            files => [qw(
                /var/log/syslog/auth.log
                /var/log/archive/auth.log.*
                /var/log/archive/auth.log-*
                $FindBin::Bin/../auth.log
            )],
            filters => [
                ISO8601 => { format => '^(\S+)\s+' },
                DateRange => { range => $Range },
                Syslog => { format => '^(?<h>\w+)\s+\[(?<l>[^\]]+)\]\s+' },
                Parser => { format => '^(?<p>\S+)\(\d+\):\s+' },
            ],
        },
    },
    services => [
        Postfix => {
            disabled => 1,
            sources => ['maillog'],
            print_summaries => 1,
            print_details => 0,
        },
        Iptables => { sources => ['iptables'],
            disabled => 1,
            proc => sub {
                my ($d, $actionType, $interface, $fromip, $toip, $toport, $svc, $proto, $prefix) = @_;
                $d->{$prefix}{$toport}{$proto}{$fromip}++;
                $d->{$prefix}{$toport}{$proto}{XXX}++;
                $d->{$prefix}{$toport}{$proto}{XXX_service} //= $svc;
                $d->{$prefix}{$toport}{XXX}++;
                $d->{$prefix}{XXX}++;
            },
            report => sub {
                use LogReporter::Util qw/SortIP/;
                my ($data) = @_;
                foreach my $prefix ( grep { !/^XXX/ } keys %{ $data } ){
                    printf "%s\n", $prefix;
                    foreach my $toport ( grep { !/^XXX/ } keys %{ $data->{$prefix} } ){
                        foreach my $proto ( grep { !/^XXX/ } keys %{ $data->{$prefix}{$toport} } ){
                            printf "  % 4d  Service %s (%s/%s)\n",
                            $data->{$prefix}{$toport}{$proto}{XXX},
                            $data->{$prefix}{$toport}{$proto}{XXX_service},
                            $proto,
                            $toport;
                            foreach my $fromip ( sort SortIP grep { !/^XXX/ } keys %{ $data->{$prefix}{$toport}{$proto} } ){
                                printf "  % 4d    %s\n",
                                $data->{$prefix}{$toport}{$proto}{$fromip},
                                $fromip;
                            }
                        }
                    }
                }
            },
        },
        Named => {
            disabled => 1,
            sources => ['named']
        },
        NamedQuery => {
            disabled => 1,
            sources => ['named_query']
        },
        OpenSSHd => {
#            disabled => 1,
            sources => ['auth'],
        },
#        zz_disk_space => { dirs => ['/etc','/var/log','/opt'], },
#        zz_uptime => { },
    ],
    
    Range => $Range,
    Host => 'li02.msk4.com',
}