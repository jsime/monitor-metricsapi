use strict;
use warnings;

package Monitor::MetricsAPI;
# ABSTRACT: Metrics collection and reporting for Perl applications.

use namespace::autoclean;
use Moose;
use MooseX::ClassAttribute;
use Scalar::Util qw( blessed );
use Try::Tiny;

=head1 NAME

Monitor::MetricsAPI - Metrics collection and reporting for Perl applications.

=head1 SYNOPSIS

    use Monitor::MetricsAPI;

    my $collector = Monitor::MetricsAPI->new(
        listen => '*:8000',
        metrics => {
            messages => {
                incoming => 'counter',
                outgoing => 'counter',
            },
            networks => {
                configured => 'gauge',
                connected  => 'gauge',
            },
            users => {
                total => sub { $myapp->total_user_count() },
            }
        }
    );

    # Using the collector object methods:
    $collector->metric('messages/incoming')->add(1);
    $collector->metric('networks/connected')->set(3);

    # Using a global collector via class methods:
    Monitor::MetricsAPI->metric('messages/incoming')->increment;

=head1 DESCRIPTION

Monitor::MetricsAPI provides functionality for the collection of arbitrary
application metrics within any Perl application, as well as the reporting of
those statistics via a JSON-over-HTTP API for consumption by external systems
monitoring tools.

Using Monitor::MetricsAPI first requires that you create the metrics collector
(and accompanying reporting server), by calling new() and providing it with an
address and port to which it should listen. Additionally, any metrics you
wish the collector to track should be defined.

The example above has created a new collector which will listen to all network
interfaces on port 8000. It has also defined two metrics of type 'counter' and
one metric which will invoke the provided subroutine every time the reporting
server displays the value. Refer to L<Monitor::MetricsAPI::Metric> for more
details on support metric types and their usage.

As your app runs, it can manipulate metrics by calling various methods via the
collector object:

For applications where passing around the collector object to all of your
functions and libraries is not possible, you may also allow Monitor::MetricsAPI
to maintain the collector as a global for you. This is done automatically for
the first collector object you create (and very few applications will want to
use more than one collector anyway).

Instead of invoking metric methods on a collector object, invoke them as class
methods:

=cut

class_has 'collector' => (
    is        => 'ro',
    isa       => 'Monitor::MetricsAPI',
    predicate => '_has_global',
    writer    => '_set_global',
);

has 'servers' => (
    is      => 'ro',
    isa     => 'ArrayRef[Monitor::MetricsAPI::Server]',
    default => sub { [] },
);

has 'metrics' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

sub BUILDARGS {
    # TODO: Convert 'listen' to address/port attributes
}

sub BUILD {
    my ($self) = @_;

    $self->_set_global($self) unless $self->_has_global;

    # TODO: Create all of the metric objects.
}

=head1 METHODS

=head2 new ( listen => '...', metrics => { ... } )

Creates a new collector, which in turn initializes the defined metrics and
binds to the provided network interfaces and ports.

=cut

=head2 metric ($name)

Returns the L<Monitor::MetricsAPI::Metric> object for the given name. Metric
names are collapsed to a slash-delimited string, which mirrors the path used
by the reporting HTTP server to display individual metrics. Thus, this:

    Monitor::MetricsAPI->new(
        metrics => {
            server => {
                version => {
                    major => 'string',
                    minor => 'string',
                }
            }
        }
    );

Creates two metrics:

=over

=item 1. server/version/major

=item 2. server/version/minor

=back

=cut

sub metric {
    my $self = shift;
    try {
        $self = $self->collector
            unless blessed($self) && $self->isa('Monitor::MetricsAPI');
    } catch {
        warn "metric method called with an invalid context";
        return;
    }
}

=head1 DEPENDENCIES

Monitor::MetricsAPI primarily makes use of the CPAN distributions listed below,
though others may also be required for building, testing, and/or operation. For
the complete list of dependencies, please refer to the distribution metadata.

=over

=item * L<AnyEvent>

=item * L<Twiggy>

=item * L<Dancer2>

=item * L<Moose>

=back

=head1 BUGS

There are no known bugs at the time of this release.

Please report any bugs or problems to the module's Github Issues page:

L<https://github.com/jsime/monitor-metricsapi/issues>

Pull requests are welcome.

=head1 AUTHORS

Jon Sime <jonsime@gmail.com>

=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2015 by OmniTI Computer Consulting, Inc.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

__PACKAGE__->meta->make_immutable;
1;
