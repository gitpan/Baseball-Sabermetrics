package Baseball::Sabermetrics;

use Baseball::Sabermetrics::Team;
use Baseball::Sabermetrics::Player;
use strict;
use warnings;
use base qw/ Baseball::Sabermetrics::Team /;

=head1 NAME

Sabermetrics - a baseball statistic module

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Sabermetrics provides an easy interface for calculating baseball statistics, given a data importer.  In this package, I've writen CPBL.pm for (L<Chinese Professional Baseball League>).

  use Baseball::Sabermetrics;
  use Baseball::Sabermetrics::CPBL;

  my $league = Baseball::Sabermetrics->new(league => 'CPBL');


  # Actually these are predefined.
  # Those data with 'p_' or '_allowed' here are for seperating pitchers
  # and batters.

  $league->define(
      rc => 'ab * obp',
      babip => '(h_allowed - hr_allowed) / (p_pa - h_allowed - p_so - p_bb - hr_allowed',
      # what started with '$' will be reserved.
      # Players have team and league predefined, and team has league.
      formula1 => 'hr / $_->team->hr';
      formula2 => 'hr / $_->league->hr';
      complex => sub {
	    print "You can write a sub directly\n";
	    $_->slg - $_->ba;
      },
      ...
  );

  Some formulas can be applied to players, teams, and league, depend on what columns are used in the formula.  For example, ab and obp are defined for players, teams, and league, so that rc is available for all of them.

  # top 5 obp of teams
  $_->print qw/ team name ba obp slg isop / for $league->top('teams', 5, 'obp');

  # top 10 obp of players
  $_->print qw/ team name ba obp slg isop / for $league->top('players', 10, 'obp');

  # show a player's information
  $league->players('Chien-Ming Wang')->print qw/ win lose ip so bb whip go_ao /;
  $league->teams('Yankees')->players('Chien-Ming Wang')->print qw/ win lose ip so bb whip go_ao /;

  # show team statistics data (accumulated from players')
  $league->{Yankees}->print qw/ win lose ip so bb whip go_ao /;

  # show all available formula
  print join ' ', $league->formula_list;

=head1 Data Structure

Sabermetrics is aimed for providing a base class of your interested teams (a league, for example).  You'll need to provide a data retriever to pull data out.  The following example shows how you have to fill data into this structure.

 $league = {
    teams => {
	Yankees => {
	    players => {
		"Chien-Ming Wang" => {
		    ip => 57.33333333333,
	     	    game => 9,
		       ...
		};
		...
	    }
	},
	Athletics => {
	    ...
	},
    },
 };

=head1 FUNCTIONS

=over 4

=item new([I<%hash>])

Create sabermetric data set of a group of teams.

If $hash{Accumulate} is false, players data will not be accumulated to their teams and the league (and therefore team-wise and league-wise statistics are not allowed).

=cut

sub new
{
    my ($class, %config) = @_;
    my $self;
    
    if (exists $config{data}) {
	$self = $config{data};
    }
    elsif (exists $config{league}) {
	eval "require Baseball::Sabermetrics::League::$config{league}; \$self = Baseball::Sabermetrics::League::$config{league}->new(\%config);";
	die unless $self;
    }
    else {
	die "You have to provide statistic data";
    }

    bless $self, $class;

    if (exists $config{Accumulate} && !$config{Accumulate}) {
	$self->{_DontAccumulate} = 1;
    }

    for my $team (values %{$self->{teams}}) {
	$team = Baseball::Sabermetrics::Team->new($team);
	$team->{league} = $self;
	for my $p (values %{$team->{players}}) {
	    $p = Baseball::Sabermetrics::Player->new($p);
	    $p->{team} = $team;
	    $p->{league} = $self;
	}
    }

    setup_common_info($self);

    return $self;
}

sub player_accumulate_term
{
    # picher and batter's game is the same here, could be a problem later?
    return qw/  gs sv bs hld cg sho ip p_pa np h_allowed hr_allowed
		sh_allowed sf_allowed p_bb p_ibb hb p_so wp bk r_allowed er
		pa ab rbi r h 1b 2b 3b hr tb dp sh sf 4ball ibb bb so sb cs
		finn tc po a e f_dp ppo tp pb c_cs c_sb /;
}

sub team_accumulate_term
{
    return qw/ game win lose tie /;
}

sub setup_common_info
{
    my $league = shift;
    for my $tname (keys %{$league->{teams}}) {
	my $team = $league->{teams}->{$tname};
	$team->{name} = $tname;
	unless (exists $league->{_DontAccumulate}) {
	    no warnings;
	    for my $name (keys %{$team->{players}}) {
		my $p = $team->{players}->{$name};
		$p->{name} = $name;
		for (player_accumulate_term()) {
		    $league->{$_} += $p->{$_};
		    $p->{team}->{$_} += $p->{$_};
		}
	    }
	    for (team_accumulate_term()) {
		$league->{$_} += $team->{$_};
	    }
	}
	$league->{players}->{$_} = $team->{players}->{$_} for (keys %{$team->{players}});
    }
    delete $league->{_DontAccumulate};
}

=item players([$name])

If $name is given, return that player of type Sabermetrics::Player.  Otherwise, returns all players.

=cut

sub players
{
    my ($self, $name) = @_;
    if ($name) {
	die "Player not found: $name\n" unless exists $self->{players}->{$name};
	return $self->{players}->{$name};
    }
    return values %{$self->{players}};
}

=item teams([$name])

If $name is given, return that team of type Sabermetrics::Team.  Otherwise, returns all teams.

=cut

sub teams
{
    my ($self, $name) = @_;
    if ($name) {
	die "Team not found: $name\n" unless exists $self->{teams}->{$name};
	return $self->{teams}->{$name};
    }
    return values %{$self->{teams}};
}

=item pitchers

Return all pitchers, i.e., NP (Number of Pitches) > 0.

=item batters

Return all batters, i.e., PA (Plate Appearances) > 0.

=back

=cut


=head1 AUTHOR

Victor Hsieh, C<< <victor at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-sabermetrics at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Sabermetrics>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Sabermetrics

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Sabermetrics>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Sabermetrics>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Sabermetrics>

=item * Search CPAN

L<http://search.cpan.org/dist/Sabermetrics>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2006 Victor Hsieh, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Baseball::Sabermetrics
