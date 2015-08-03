use strict;
use warnings;

package Monitor::MetricsAPI::Server::Routes;

use Dancer2;

set serializer => 'JSON';

=head1 NAME

Monitor::MetricsAPI::Server::Routes

=head1 SYNOPSIS

You should not interact with this module directly in your code. Please refer to
L<Monitor::MetricsAPI> for how to integrate this service with your application.

=head1 DESCRIPTION

The base Dancer2 application which provides HTTP API routes for MetricsAPI.

=cut

=head1 ROUTES

The following routes are provided by this server for viewing the collected
metrics.

=cut

=head2 /

Returns a small JSON structure with metadata about the metrics collector. May
be used as a heartbeat for the service.

=cut

get '/' => sub {
    return { status => 'ok' };
};

=head2 /all

Returns a full export of all metrics that have been configured in the
containing application. This will include the invoking of all callback metrics.
Depending on your metrics collection, this can be a computationally expensive
process.

If you have any non-trivial callback metrics collected by your application, you
should exercise care in your calls to this route.

=cut

get '/all' => sub {
    my $coll = Monitor::MetricsAPI->collector;

    return { status => 'collector_fail', message => 'Could not access metrics collector.' }
        unless defined $coll;

    return { status => 'no_metrics', message => 'The collector does not have any metrics defined.' }
        unless scalar(keys(%{$coll->metrics})) > 0;

    my $response = {
        status  => 'ok',
        message => 'Request processed successfully.',
        service => {
            name    => 'Monitor::MetricsAPI',
            version => $Monitor::MetricsAPI::VERSION,
        },
        metrics => {
        }
    };

    $response->{'metrics'}{$_->name} = $_->value for values %{$coll->metrics};

    return $response;
};

=head2 /metric/**

Returns a single named metric, instead of the entire collection of metrics. The
use of this route is substantially preferred for monitoring systems which use
checks against individual metrics, as it limits the invocations of potentially
expensive callback metrics (assuming your application configures any).

A complete metric name must be provided. For returning groups of metrics under
a common namespace, use the /metrics/ route instead.

=cut

get '/metric/**' => sub {
    my ($mparts) = splat;

    my $coll = Monitor::MetricsAPI->collector;
    my $metric_name = join('/', @{$mparts});

    return { status => 'collector_fail', message => 'Could not access metrics collector.' }
        unless defined $coll;
    return { status => 'not_found', message => 'Invalid metric name provided.' }
        unless exists $coll->metrics->{$metric_name};

    my $metric = $coll->metric($metric_name);

    return {
        status  => 'ok',
        message => 'Request processed successfully.',
        service => {
            name    => 'Monitor::MetricsAPI',
            version => $Monitor::MetricsAPI::VERSION,
        },
        metrics => {
            $metric->name => $metric->value
        }
    };
};

=head2 /metrics/**

Returns a collection of metrics under the given namespace. Each component of
the namespace prefix you wish to return must be fully specified, but you can
select as deep or as shallow a namespace as you like. In other words, if you
have the following metrics:

    messages/incoming/total
    messages/incoming/rejected
    messages/outgoing/total
    messages/outgoing/supressed
    users/total

And your monitoring application calls this service with the following path:

    /metrics/messages/outgoing

Then this route will return two metrics:

    messages/outgoing/total
    messages/outgoing/supressed

But if you try to call this service with:

    /metrics/messages/out

You will receive an error response.

If you specify the full name of a single metric, you will receive only that
metric back in the response output. Given that, why would you ever use the
"/metric/**" route over this one? Using the single-metric route when you truly
only want a single metric will return an error if the name you give is a
namespace instead of a single metric. It is possible this may be useful in
some circumstances.

=cut

get '/metrics/**' => sub {
    my ($nsparts) = splat;

    my $coll = Monitor::MetricsAPI->collector;
    my $prefix = join('/', @{$nsparts});

    return { status => 'collector_fail', message => 'Could not access metrics collector.' }
        unless defined $coll;

    return { status => 'no_group', message => 'Must provide metric group prefix.' }
        unless defined $prefix && $prefix =~ m{\w+};

    my @metrics =
        map { $coll->metric($_) }
        grep { $_ =~ m{^$prefix(/|$)} }
        keys %{$coll->metrics};

    return { status => 'not_found', message => 'Invalid metric group name provided.' }
        unless @metrics > 0;

    my $response = {
        status  => 'ok',
        message => 'Request processed successfully.',
        service => {
            name    => 'Monitor::MetricsAPI',
            version => $Monitor::MetricsAPI::VERSION,
        },
        metrics => {
        }
    };

    $response->{'metrics'}{$_->name} = $_->value for @metrics;

    return $response;
};

=head1 OUTPUT FORMATS

By default, all routes provided by this module return JSON. However, clients
may request alternate representations if they are easier to consume. Output
serialization is handled via L<Dancer2::Serializer::Mutable>, which allows
clients to indicate their preferred format using the HTTP 'Accept-type' header.

Current supported serialization types are:

=over

=item * JSON (Default)

Accept-type: application/json

=item * YAML

Accept-type: text/x-yaml

=item * XML

Accept-type: text/xml

=back

=head1 OUTPUT STRUCTURE

Unless otherwise noted, all routes return a similar data structure to the one
described in this section. For simplicity, the examples used here will all be
in the default serializer's JSON notation. The underlying data structure will
be the same regardless of the chosen serialization method, only its serialized
representation will differ.

=head2 Complete Example

    { "status": "ok",
      "message: "Request processed successfully.",
      "service": {
        "name": "Monitor::MetricsAPI",
        "version": "0.001",
        "host": "127.0.0.1",
        "port": 8200
      },
      "metrics": {
        "messages/incoming/total": 5019,
        "messages/incoming/rejected": 104,
        "messages/outgoing/total": 1627,
        "messages/outgoing/suppressed": 5,
        "users/total": 1928
      }
    }

=head2 Status

The status attribute is present in every response, and anything other than the
string "ok" indicates an error condition. Responses with a non-"ok" status may
not contain any additional attributes beyond a message which will contain an
error message.

=head2 Message

Contains a human-readable message, useful for discerning the reason for failed
requests. Otherwise easily ignored.

=head2 Service

The value of the service attribute is an object containing metadata about the
metrics reporting service.

=head2 Metrics

The metrics attribute contains an object of all metrics which matched the
request. In the case of requests to the "/all" route, this will be every metric
collected by the service for your application. For both the "/metric" and
"/metrics" routes, only those metrics which matched your request will appear
in the object, and all others will be omitted from the output.

The data type of each metric's value will depend on the type of metric that is
being collected. Counters and gauges will return numbers, boolean metrics will
return true, false or null, and string metrics will return, well, strings.
Callback metrics can return any type, entirely dependent upon what the
subroutine you provided for the callback does.

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

1;
