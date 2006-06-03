package Baseball::Sabermetrics::Team;
use Baseball::Sabermetrics::abstract;
use strict;

our @ISA = qw/ Baseball::Sabermetrics::abstract /;

sub players
{
    my ($self, $name) = @_;
    if ($name) {
	die "Player not found: $name\n" unless exists $self->{players}->{$name};
	return $self->{players}->{$name};
    }
    return values %{$self->{players}};
}

sub pitchers
{
    my $self = shift;
    return grep { exists $_->{np} and $_->{np} > 0 } $self->players;
}

sub batters
{
    my $self = shift;
    return grep { exists $_->{pa} and $_->{pa} > 0 } $self->players;
}

1;
