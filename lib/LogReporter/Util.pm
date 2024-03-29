package LogReporter::Util;
use strict;
use warnings;
use feature ':5.10';
use Socket;

use Exporter 'import';
our @EXPORT = (qw());
our @EXPORT_OK = (qw(unitize SortIP LookupIP schwartz schwartzn schwerz schwerzn));

sub unitize {
    my ($num) = @_;
    my $kilobyte = 1024;
    my $megabyte = 1048576;
    my $gigabyte = 1073741824;
    my $terabyte = 1099511627776;

    return sprintf "%.3f TB", ($num / $terabyte)  if ($num >= $terabyte);
    return sprintf "%.3f GB", ($num / $gigabyte)  if ($num >= $gigabyte);
    return sprintf "%.3f MB", ($num / $megabyte)  if ($num >= $megabyte);
    return sprintf "%.3f KB", ($num / $kilobyte)  if ($num >= $kilobyte);
    return sprintf "%.3f  B", ($num);
}

sub canonical_ipv6_address {
    my @a = split /:/, shift;
    my @b = qw(0 0 0 0 0 0 0 0);
    my $i = 0;
    # comparison is numeric, so we use hex function
    while (defined $a[0] and $a[0] ne '') {$b[$i++] = hex(shift @a);}
    @a = reverse @a;
    $i = 7;
    while (defined $a[0] and $a[0] ne '') {$b[$i--] = hex(shift @a);}
    @b;
}

sub SortIP {
    no warnings;
    # $a & $b are in the caller's namespace.
    my $package = (caller)[0];
    no strict 'refs'; # Back off, man. I'm a scientist.
    my $A = $ {"${package}::a"};
    my $B = $ {"${package}::b"};
    $A =~ s/^::(ffff:)?(\d+\.\d+\.\d+\.\d+)$/$2/;
    $B =~ s/^::(ffff:)?(\d+\.\d+\.\d+\.\d+)$/$2/;
    use strict 'refs'; # We are a hedge. Please move along.
    if ($A =~ /:/ and $B =~ /:/) {
        my @a = canonical_ipv6_address($A);
        my @b = canonical_ipv6_address($B);
        while ($a[1] and $a[0] == $b[0]) {shift @a; shift @b;}
        $a[0] <=> $b[0];
    } elsif ($A =~ /:/) {
        -1;
    } elsif ($B =~ /:/) {
        1;
    } else {
        my ($a1, $a2, $a3, $a4) = split /\./, $A;
        my ($b1, $b2, $b3, $b4) = split /\./, $B;
        $a1 <=> $b1 || $a2 <=> $b2 || $a3 <=> $b3 || $a4 <=> $b4;
    }
}

my %LookupCache = ();
sub LookupIP {
    my ($Addr) = @_;
    return $Addr;
    return $LookupCache{$Addr} if exists $LookupCache{$Addr};
    
    $Addr =~ s/^::ffff://;
    
    my ($name);
    if ($Addr =~ /^[\d\.]*$/) {
        my $PackedAddr = pack('C4', split /\./,$Addr);
        $name = gethostbyaddr($PackedAddr,AF_INET());
    } elsif ($Addr =~ /^[0-9a-zA-Z:]*/) {
        my $PackedAddr = pack('n8', canonical_ipv6_address($Addr));
        $name = gethostbyaddr($PackedAddr, AF_INET6());
    }
    
    if ($name) {
        my $val = "$Addr ($name)";
        $LookupCache{$Addr} = $val;
        return $val;
    } else {
        $LookupCache{$Addr} = $Addr;
        return ($Addr);
    }
}

sub schwartz(&@) {
    my $xfm = shift;
    return  map { $_->[0] }
            sort { $a->[1] cmp $b->[1] }
            map { [$_, $xfm->($_) ] }
                @_;
}
sub schwartzn(&@) {
    my $xfm = shift;
    return  map { $_->[0] }
            sort { $a->[1] <=> $b->[1] }
            map { [$_, $xfm->($_) ] }
                @_;
}
sub schwerz(&@) {
    my $xfm = shift;
    return  map { $_->[0] }
            sort { $b->[1] cmp $a->[1] }
            map { [$_, $xfm->($_) ] }
                @_;
}
sub schwerzn(&@) {
    my $xfm = shift;
    return  map { $_->[0] }
            sort { $b->[1] <=> $a->[1] }
            map { [$_, $xfm->($_) ] }
                @_;
}


1;
