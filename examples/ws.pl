#!/usr/bin/perl

use lib '/home/victor/cpb2/Sabermetrics/lib';
use Data::Dumper;
use Sabermetrics;

my $league = Sabermetrics->new( league => 'CPB2', file => "$ENV{HOME}/cpb2/_LEAGUE" );

$league->define(

ws => 'att_ws + pitch_ws + def_ws',

att_ws => 'pa > 0 ? $team->team_att_ws * marginal_rc / $team->team_total_marginal_rc : 0',

pitch_ws => 'np > 0 ? $team->team_pitchers_ws * pitcher_ws_weight / $team->team_pitchers_total_ws_weight : 0',

def_ws => '0',


# Projected WS
team_ws => '(win * 3 + tie * 1.5) * 100 / game',

# ignore field effect factor(?)
m_save => '$league->r / $league->ip * ip * 1.52 - run_allowed',

est_att_inn => 'ip + (lose - win) / 2',

m_run => 'r - $league->r / $league->ip * est_att_inn * 0.52',

team_def_ws => 'm_save / (m_run + m_save) * team_ws',

team_att_ws => 'm_run  / (m_run + m_save) * team_ws',


der => '(p_pa - h_allowed - p_so - p_bb) / (p_pa - hr_allowed - p_so - p_bb)',

team_pitchers_ws => sub {
    my $cl1 = ($_->der - $_->league->der) * 2500 + 100;
    my $cl2 = ($_->k_9 + 2.5) / 7 * 200;
    my $cl3 = (($_->league->p_bb + $_->league->hb) / $_->league->ip * $_->ip - $_->p_bb - $_->hb + 200);
    my $cl4 = ($_->league->hr_allowed / $_->league->ip * $_->ip - $_->hr_allowed) * 5 + 200;
    my $cl5 = ($_->league->e + $_->league->pb / 2) / $_->league->ip * $_->ip - ($_->e + $_->pb / 2) + 100;
    my $cl6 = 100;

    ($_->cl1 + $_->cl2 + $_->cl3 + $_->cl4 + 650 + 405 * $_->win / $_->game) / (2 * $_->cl1 + $_->cl2 + $_->cl3 + $_->cl4 + $_->cl5 + $_->cl6 + 1097.5 + 405 * $_->win / $_->game) * $_->team_def_ws;
},


run_per_out => 'r / ip / 3',

outs_made => 'ab - h + dp + sf + cs',

marginal_rc => 'rc - outs_made * $league->run_per_out * 0.52 ',

team_total_marginal_rc => sub {
    my $sum = 0;
    for my $p ($_->batters) {
	$sum += $p->marginal_rc;
    }
    $sum;
},


run_per_game => 'r / ip * 9',

pitcher_zero_base => sub {
    # XXX it's strange. check the formula again.
    my $A = $_->league->run_per_game * 1.52 - $_->run_per_game;
    my $B = $_->A * $_->defense_ws / $_->team_def_ws;
    $A - $B;
},

team_fielding_ws => 'team_def_ws - team_pitchers_ws',

pitcher_ws_weight => sub {
    my $cl1 = $_->team->pitcher_zero_base * $_->ip - ($_->er + 0.5 * ($_->run_allowed - $_->er));
    my $cl2 = ($_->win * 3 - $_->lose + $_->save) / 3;

    my $save_eq_inn = $_->save * 3; # 中繼成功省略

    my $A = $_->h_allowed + $_->p_bb + $_->hb;
    my $B = (($_->h_allowed - $_->hr_allowed) * 1.255 + $_->hr_allowed * 4) * 0.89 + ($_->p_bb + $_->hb) * 0.56;
    my $C = $_->p_pa;
    my $tmp = $A * $B / $C;
    my $era_in_theory = $tmp >= 2.24 ? $tmp / $_->ip * 9 - 0.56 : $tmp / $_->ip * 9 * 0.75;

    my $cl3 = ($_->team->pitcher_zero_base - $era_in_theory) * $save_eq_inn;

    $cl1 + $cl2 + $cl3;
},

team_pitchers_total_ws_weight => sub {
    my $sum = 0;
    for my $p ($_->pitchers) {
	$sum += $p->pitcher_ws_weight;
    }
    $sum;
},

);

print "           W  L  T   WS      DEF WS%\n";
for my $t ($league->teams) {
    printf "%-10s %d %d %d   %.2f  %.2f%%\n", $t->name, $t->win, $t->lose, $t->tie, $t->team_ws, $t->team_def_ws / $t->team_ws * 100;
}
print "\n";

print "pitchers ws\n\n";
$_->print qw/ team name ws / for $league->top('pitchers', 10, 'ws');
print "\n";

print "batters ws\n\n";
$_->print qw/ team name ws / for $league->top('batters', 10, 'ws');
