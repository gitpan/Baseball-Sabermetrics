package Baseball::Sabermetrics::League::CPBL;

use WWW::Mechanize;
use HTML::TableExtract;
use Encode qw/ encode decode /;

use strict;

sub new
{
    my $league = {};
    my $teams = $league->{teams} = {};

    $teams->{bulls} = { code => 'B02', name => 'bulls', company => "興農" };
    $teams->{cobras} = { code => 'G01', name => 'cobras', company => "誠泰" };
    $teams->{elephants} = { code => 'E01', name => 'elephants', company => "兄弟" };
    $teams->{whales} = { code => 'W01', name => 'whales', company => "中信" };
    $teams->{lions} = { code => 'L01', name => 'lions', company => "統一" };
    $teams->{bears} = { code => 'A02', name => 'bears', company => "La New" };

    extract_score($league, "http://www.cpbl.com.tw/Score/FightScore.aspx");

    for my $team (values %$teams) {
	print "Fetching records of team $team->{name}\n";

	my $code = $team->{code};

	extract_record(
		$team,
		"http://www.cpbl.com.tw/teams/Team_Pitcher.aspx?Tno=$code",
		[qw/ name game gs _ _ win lose tie sv bs hld _ cg sho /]);
	extract_record(
		$team,
		"http://www.cpbl.com.tw/teams/Team_Pitcher.aspx?Tno=$code&page=2",
		[qw/ name ip p_pa np h_allowed hr_allowed sh_allowed sf_allowed p_bb p_ibb hb p_so wp bk r_allowed er /]);

	extract_record(
		$team,
		"http://www.cpbl.com.tw/teams/Team_Hitter.aspx?Tno=$code",
		[qw/ name game pa ab rbi r h 1b 2b 3b hr tb dp /]);
	extract_record(
		$team,
		"http://www.cpbl.com.tw/teams/Team_Hitter.aspx?Tno=$code&page=2",
		[qw/ name sh sf 4ball ibb bb so sb cs /]);

	# finn stards for fielding innings
	extract_defense(
		$team,
		"http://www.cpbl.com.tw/teams/Team_defend.aspx?Tno=$code",
		[qw/ name finn tc po a e f_dp ppo tp pb c_cs c_sb _ /]);
    }

    $league;
}

sub get_table_in_html
{
    my ($url, $attribs) = @_;

    my $mech = WWW::Mechanize->new();
    my $te = HTML::TableExtract->new(attribs => $attribs);
    $te->parse($mech->get($url)->content);

    my @tables = $te->tables;
    die "No table is found" unless @tables;
    return shift @tables;
}

sub extract_score
{
    my ($league, $url) = @_;
    my $table = get_table_in_html($url, { class => 'Report_Table_score' });
    my (undef, undef, @teams) = $table->rows;
    for my $team (@teams) {
	my ($name, $game, $score) = @$team;
	$name =~ s/\d\.//;
	my ($t) = grep { $_->{company} eq $name } values %{$league->{teams}};
	$t->{game} = $game;
	($t->{win}, $t->{lose}, $t->{tie}) = ($score =~ /(\d+)勝(\d+)和(\d+)敗/);
    }
}

sub extract_record
{
    my ($team, $url, $cols) = @_;

    my $table = get_table_in_html($url, { class => 'Report_Table' });
    die "Table not found" unless $table;

    my (undef, $header, @players) = $table->rows;
    
    for my $p_row (@players) {
	my @rows = @$p_row;
	my $name = shift @rows;
	$name =~ s/\s//g;

	$team->{players}->{$name} = {}
	    unless exists $team->{players}->{$name};

	my $p = $team->{players}->{$name};
	for (1..@$cols - 1) {
	    my $t = $cols->[$_];
	    if ($t eq '_') {
		shift @rows;
		next;
	    }
	    $p->{$t} = shift @rows;
	}

	$p->{ip} = int($p->{ip}) + ($p->{ip} - int $p->{ip}) * 10 / 3
	    if exists $p->{ip};

	if (exists $p->{'4ball'}) {
	    #$p->{hbp} = $p->{bb} - $p->{ibb} - $p->{'4ball'};
	    # XXX I'm not sure whether ibb is counted in bb in cpbl.com.tw
	    $p->{hbp} = $p->{bb} - $p->{'4ball'};
	    delete $p->{'4ball'};
	}
	else {
	    # XXX I'm not sure whether ibb is counted in bb in cpbl.com.tw
	    #$p->{p_bb} = $p->{p_bb} + $p->{p_ibb};
	}
    }
}

sub extract_defense
{
    my ($team, $url, $cols) = @_;

    my $table = get_table_in_html($url, { id => 'DefendDG' });
    die "Table not found" unless $table;

    my ($header, @players) = $table->rows;
    
    for my $p_row (@players) {
	my @rows = @$p_row;
	my $name = shift @rows;
	$name =~ s/\s//g;

	$team->{players}->{$name} = {}
	    unless exists $team->{players}->{$name};

	my $p = $team->{players}->{$name};
	$p->{name} = $name;
	for (1..@$cols - 1) {
	    my $t = $cols->[$_];
	    if ($t eq '_') {
		shift @rows;
		next;
	    }
	    $p->{$t} = shift @rows;
	}
    }
}

1;
