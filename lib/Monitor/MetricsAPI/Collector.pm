use strict;
use warnings;

package Monitor::MetricsAPI::Collector;

use namespace::autoclean;
use Moose;

=head1 NAME

Monitor::MetricsAPI::Collector - Metrics collection object

=head1 SYNOPSIS

=cut

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

=head1 METHODS

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

The metric object returned by this method may then be modified, according to
its own methods documented in L<Monitor::MetricsAPI::Metric> and the
type-specific documentation, or its value may be accessed via the standard
value() metric method.

Updating a metric:

    $collector->metric('users/total')->set($user_count);

Retrieving the current value of a metric:

    $collector->metric('users/total')->value;

=cut

sub metric {
    my ($self, $name) = @_;

    unless (defined $name) {
        warn "cannot retrieve metric value without a name";
        return;
    }

    unless (exists $self->metrics->{$name}) {
        warn "the metric $name does not exist";
        return;
    }

    return $self->metrics->{$name};
}

=head2 add_metric ($name, $type, $callback)

Allows for adding a new metric to the collector as your application is running,
instead of having to define everything at startup.

If the metric already exists, this method will be a noop as long as all of the
metric options match (i.e. the existing metric is of the same type as what you
specified in add_metric()). If the metric already exists and you have specified
options which do not match the existing ones, a warning will be emitted and no
other actions will be taken.

Both $name and $type are required. If $type is 'callback' then a subroutine
reference must be passed in for $callback. Refer to the documentation in
L<Monitor::MetricsAPI::Metric> for details on individual metric types.

=cut

sub add_metric {
    my ($self, $name, $type, $callback) = @_;

    unless (defined $name && defined $type) {
        warn "metric creation requires a name and type";
        return;
    }

    if ($type eq 'callback' && (!defined $callback || ref($callback) ne 'CODE')) {
        warn "callback metrics must also provide a subroutine";
        return;
    }

    if (exists $self->metrics->{$name}) {
        return if $self->metrics->{$name}->type eq $type;
        warn "metric $name already exists, but is not of type $type";
        return;
    }

    my $metric = Monitor::MetricsAPI::Metric->new(
        type => $type,
        name => $name,
        ( $type eq 'callback' ? ( callback => $callback ) : ())
    );

    unless (defined $metric) {
        warn "could not create the metric $name";
        return;
    }

    $self->metrics->{$metric->name} = $metric;
    return $metric;
}

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
