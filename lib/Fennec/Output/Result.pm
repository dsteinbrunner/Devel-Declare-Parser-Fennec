package Fennec::Output::Result;
use strict;
use warnings;

use base 'Fennec::Output';

use Fennec::Util::Accessors;
use Fennec::Runner;
use Fennec::Workflow;
use Try::Tiny;

use Scalar::Util qw/blessed/;

our @ANY_ACCESSORS = qw/ skip todo /;
our @WORKFLOW_ACCESSORS = qw/ name file line /;
our @SIMPLE_ACCESSORS = qw/ pass benchmark /;
our @PROPERTIES = (
    @WORKFLOW_ACCESSORS,
    @SIMPLE_ACCESSORS,
    @ANY_ACCESSORS,
    qw/ stderr stdout workflow_stack test /,
);
our $TODO;

Accessors @SIMPLE_ACCESSORS;

sub TODO {
    my $class = shift;
    ($TODO) = @_ if @_;
    return $TODO;
}

sub fail { !shift->pass }

sub new {
    my $class = shift;
    my %proto = @_;
    my $pass = delete $proto{ pass };

    return bless(
        {
            $TODO ? ( todo => $TODO ) : (),
            %proto,
            pass => $pass ? 1 : 0,
        },
        $class
    );
}

for my $workflow_accessor ( @WORKFLOW_ACCESSORS ) {
    no strict 'refs';
    *$workflow_accessor = sub {
        my $self = shift;
        return $self->{ $workflow_accessor }
            if $self->{ $workflow_accessor };

        return undef unless $self->workflow
                        and $self->workflow->can( $workflow_accessor );

        return $self->workflow->$workflow_accessor;
    };
}

for my $any_accessor ( @ANY_ACCESSORS ) {
    no strict 'refs';
    *$any_accessor = sub {
        my $self = shift;
        return $self->{ $any_accessor }
            if $self->{ $any_accessor };

        return unless $self->workflow;
        return unless $self->workflow->isa( 'Fennec::Workflow' );
        return $self->workflow->$any_accessor
            if $self->workflow && $self->workflow->can( $any_accessor );
    };
}

sub test {
    my $self = shift;
    if ( my $workflow = $self->workflow ) {
        return $workflow if $workflow->isa( 'Fennec::Test' );
        my $test = $workflow->test if $workflow->can( 'test' );
        return $test if $test;
    }
    return $self->{ test };
}

sub fail_workflow {
    my $class = shift;
    my ( $workflow, @stdout ) = @_;
    $class->new( pass => 0, workflow => $workflow, stdout => \@stdout )->write;
}

sub skip_workflow {
    my $class = shift;
    my ( $workflow, $reason, @stdout ) = @_;
    $reason ||= $workflow->skip if $workflow->can( 'skip' );
    $reason ||= "no reason";
    $class->new( pass => 0, workflow => $workflow, skip => $reason, stdout => \@stdout )->write;
}

sub pass_workflow {
    my $class = shift;
    my ( $workflow, %proto ) = @_;
    $class->new( %proto, pass => 1, workflow => $workflow )->write;
}

sub pass_file {
    my $class = shift;
    my ( $file, %proto ) = @_;
    $class->new( %proto, pass => 1, name => $file->filename )->write;
}

sub fail_file {
    my $class = shift;
    my ( $file, @stdout ) = @_;
    $class->new( pass => 0, name => $file->filename, stdout => \@stdout )->write;
}

sub serialize {
    my $self = shift;
    my $data = { map {( $_ => ( $self->$_ || undef ))} @PROPERTIES };
    return {
        bless => ref( $self ),
        data => $data,
    };
}

1;

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Fennec is free software; Standard perl licence.

Fennec is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the license for more details.
