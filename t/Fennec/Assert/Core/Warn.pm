package TEST::Fennec::Assert::Core::Warn;
use strict;
use warnings;

use Fennec;
use Fennec::Assert::Interceptor;

our $CLASS = 'Fennec::Assert::Core::Warn';

tests 'warning is' => sub {
    my $res = capture {
        warning_is {
            warn 'apple'
        } 'apple at ' . __FILE__ . ' line ' . ln(-1) . ".\n", "pass";
        warning_is { warn 'xxx' } 'yyy', "fail";
        warning_is { warn 'a'; warn 'b' } 'a', "multiple warnings";
    };
    ok( $res->[0]->pass, "First result passed" );
    ok( !$res->[1]->pass, "Second result failed" );
    ok( !$res->[2]->pass, "Third result failed" );
    is( $res->[2]->stderr->[0], "Too many warnings:", "multiple warnings" );
    like( $res->[2]->stderr->[1], qr/\ta at/, "Warning 1" );
    like( $res->[2]->stderr->[2], qr/\tb at/, "Warning 2" );
};

tests 'warnings are' => sub {
    my $res = capture {
        warnings_are {
            warn 'a';
            warn 'b';
        } [
            'a at ' . __FILE__ . ' line ' . ln(-3) . ".\n",
            'b at ' . __FILE__ . ' line ' . ln(-2) . ".\n"
        ], "pass";
        warnings_are {
            warn 'aaa';
        } [
            'xxxx',
            'yyyy',
        ], "fail";
    };
    ok( $res->[0]->pass, "First result pass" ) || diag @{ $res->[0]->stderr };
    ok( !$res->[1]->pass, "Second result fail" );
};

tests 'warnings like' => sub {
    my $res = capture {
        warnings_like {
            warn 'apple';
            warn 'bear';
            warn 'capooza';
        } [
            qr/^apple/,
            qr/^bear/,
            qr/^capooza/,
        ], "pass";
        warnings_like {
            warn 'abble';
            warn 'bear';
            warn 'capooza';
        } [
            qr/^apple/,
            qr/^bear/,
            qr/^capooza/,
        ], "fail";
        warnings_like {
            warn 'bear';
            warn 'capooza';
        } [
            qr/^apple/,
            qr/^bear/,
            qr/^capooza/,
        ], "fail";
    };
    ok( $res->[0]->pass, "First passes" );
    ok( !$res->[1]->pass, "Second fails" );
    ok( !$res->[2]->pass, "Third fails" );
    is(
        $res->[1]->stderr->[0],
        "'abble at /home/exodist/Projects/Fennec/t/Fennec/Assert/Core/Warn.pm line 58.\n' does not match '(?-xism:^apple)'",
        "msg"
    );
    is_deeply(
        $res->[2]->stderr,
        [
            "Wrong number of warnings:",
            "\tbear at /home/exodist/Projects/Fennec/t/Fennec/Assert/Core/Warn.pm line 67.\n",
            "\tcapooza at /home/exodist/Projects/Fennec/t/Fennec/Assert/Core/Warn.pm line 68.\n",
        ],
        "messages",
    );
};

tests 'warning like' => sub {
    my $res = capture {
        warning_like { warn 'aaa' }
            qr/^aaa/,
            "pass";
        warning_like { warn 'aaa'; warn 'bbb' }
            qr/^aaa/,
            "Too many";
        warning_like { 1 }
            qr/aaa/,
            "no warnings";
    };
    ok( $res->[0]->pass, "First passes" );
    ok( !$res->[1]->pass, "Second failed" );
    ok( !$res->[2]->pass, "Third failed" );
    is( $res->[1]->stderr->[0], "Too many warnings:", "Proper error" );
    is( @{ $res->[1]->stderr }, 3, "Show warnings" );
    is( $res->[2]->stderr->[0], "Did not warn as expected", "Proper error" );
};

tests 'warnings exist' => sub {
    my $res = capture {
        warnings_exist { warn 'aaa'; warn 'bbb' } [
            qr/aaa/,
            'bbb at ' . __FILE__ . ' line ' . ln(-1) . ".\n",
        ], "Pass";
        warnings_exist { warn 'aaa'; warn 'xxx' } [
            qr/aaa/,
            qr/bbb/,
        ], "Missing + Extra";
    };
    ok( $res->[0]->pass, "First result pass" ) || diag @{ $res->[0]->stderr };
    ok( $res->[1]->fail, "Second result failed" );
    is(
        ( grep {
            $_ eq 'Missing warnings:' ||
            $_ eq 'Extra warnings (not an error):'
        } @{ $res->[1]->stderr }),
        2,
        "Extra and missing"
    );
    is( @{ $res->[1]->stderr }, 4, "Show everything" );
};

1;

__END__

sub warnings_exist(&$;$) {
    my ( $sub, $in, $name ) = @_;
    my $matches = ref($in) eq 'ARRAY' ? $in : [ $in ];
    my @warns = capture_warnings( \&$sub );
    my %found;
    my @extra;
    for my $warn ( @warns ) {
        my $matched = 0;
        for my $match ( @$matches ) {
            if ( ref( $match ) ? $warn =~ $match : $match eq $warn ) {
                $found{ $match }++;
                $matched++;
            }
        }
        push @extra => $warn unless $matched;
    }
    my @missing = grep { !$found{$_} } @$matches;
    result(
        pass => @missing ? 0 : 1,
        name => $name,
        stderr => [
            @missing ? ( "Missing warnings:", map { "\t$_" } @missing )
                     : (),
            @extra ? ( "Extra warnings (not an error):", map { "\t$_" } @extra )
                   : (),
        ]
    );
}

1;
