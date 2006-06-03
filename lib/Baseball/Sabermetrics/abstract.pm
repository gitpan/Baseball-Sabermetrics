package Baseball::Sabermetrics::abstract;
use strict;

our $AUTOLOAD;
our %formula;

#my $DEBUG = 0;

BEGIN {
    %formula = (
	pa  =>		sub { $_->ab + $_->bb + $_->hbp + $_->sf },
	ba  =>		sub { $_->h / $_->ab },
	obp =>		sub { ($_->h + $_->bb + $_->hbp) / $_->pa },
	slg =>		sub { $_->tb / $_->ab },
	ops =>		sub { $_->obp + $_->slg },
	k_9 =>		sub { $_->p_so / $_->ip * 9 },
	bb_9 =>		sub { $_->p_bb / $_->ip * 9 },
	k_bb =>		sub { $_->p_so / $_->p_bb },
	isop =>		sub { $_->slg - $_->ba },
	rc =>		sub { $_->ab * $_->obp },

	era =>		sub { $_->er / $_->ip * 9 },
	whip =>		sub { ($_->p_bb + $_->h_allowed) / $_->ip },
	babip =>	sub { ($_->h_allowed - $_->hr_allowed) / ($_->p_pa - $_->h_allowed - $_->p_so - $_->p_bb - $_->hr_allowed) },
	go_ao =>	sub { $_->go / $_->ao },

	rf =>		sub { ($_->a + $_->po) / $_->finn * 9 },
    );
}

sub new
{
    my ($class, $hash) = @_;
    return bless \%$hash, $class;
}

sub AUTOLOAD : lvalue
{
    my $self = shift;
    my $type = ref($self) or die;
    my $name = $AUTOLOAD;
    $name =~ s/.*:://;
    my $ref;

    if ($name eq 'DESTROY') {
	# is there a better way?
	$ref = \$name;
    }
    elsif (exists $self->{$name}) {
    	$ref = \$self->{$name};
    }
    elsif (exists $formula{$name}) {
#	no strict;
#	use vars qw/ $team $league /;


	my $caller = caller;
	local $_ = $self;
#	local *league = exists $self->{league} ? \$self->{league} : undef;
#	local *team = exists $self->{team} ? \$self->{team} : undef;
#	$DEBUG && print STDERR "[",__PACKAGE__,"] calculating $self->{name}'s $name, league: $league, team: $team\n";

	unless (ref $formula{$name}) {
	    $formula{$name} =~ s{(\$?)([a-zA-Z_](?:\w|->)*)}{
		$1 ? "\$$2" : "\$_->$2"
	    }eg;
	    $formula{$name} =~ s/\$team/\$_->team/g;
	    $formula{$name} =~ s/\$league/\$_->league/g;
	    $formula{$name} = eval "sub { $formula{$name} }" or die $@;
	}

	$self->{$name} = $formula{$name}->();
	$ref = \$self->{$name};
    }
    else {
    	$ref = \$self->{$name};
    }

    $$ref;
}

sub print
{
    my $self = shift;
    if (grep /^all$/, @_) {
	@_ = keys %$self;
    }
    for (@_) {
	if ($_ eq 'team') {
	    print $self->team->name, "\t";
	}
	else {
	    my $val = $self->$_;
	    if ($val =~ s/(\d+\.\d\d\d)(\d)\d*/$1/) {
		$val += 0.001 if $2 >= 5;
	    }

	    print "$val\t";
	}
    }
    print "\n";
}

sub define
{
    my ($self, %funcs) = @_;
    %formula = (%formula, %funcs);
}

sub formula
{
    die "undefined formula" unless exists $formula{$_[1]};
    return $formula{$_[1]};
}

sub formula_list
{
    return keys %formula;
}

sub top
{
    my ($self, $what, $num, $func) = @_;
    if (! ref $func) {
	return (sort { $b->$func <=> $a->$func } $self->$what)[0..$num-1];
    }
    return (sort $func $self->what)[0..$num-1];
}

#sub declare
#{
#    my $self = shift;
#    $self->{$_} for (@_);
#}

1;
