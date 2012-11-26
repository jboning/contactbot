# Copyright (C) 2012 Josiah Boning
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
#use warnings; ## why did I turn this off? I fear.

my %CONFIG = (
	server => "",
	channel => "",
	owner => "",
);

# Add nicknmaes here!
my %NICKNAMES = (
);

use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '0.2';
%IRSSI = (
	authors     => 'Josiah Boning',
	contact     => 'jboning@gmail.com',
	name        => 'contactbot',
	description => 'Manage games of contact',
	license     => 'GPLv3',
	changed     => '2012-11-26',
);

my $SELFPOPWAIT = 5;

my @queue = ();
my $wm = '';
my $prefix = '';
my %used = ();
my @contacted = ();
my $selfpoptime = time - $SELFPOPWAIT;

##
## BEGIN LULZ
##

my $lulzprob = 0;
my @lulz;
push @lulz, sub {$_[0] =~ tr/aeiouy/oooooo/};
push @lulz, sub {
	$_[0] =~ tr/aeiouy/yyyyyy/;
	foreach (reverse(1 .. length($_[0])-1)) {
		substr($_[0], $_, 0) = "'" if (rand() < 0.2);
	}
	$_[0] =~ s/y([bcdfghjklmnpqrstvwxz])'/y$1$1h'/g;
};
push @lulz, sub {$_[0] =~ s/(.)/$1$1/g};
push @lulz, sub {$_[0] = $NICKNAMES{lc($_[0])} || $_[0]};
push @lulz, sub {
	foreach (reverse(0 .. length($_[0])-1)) {
		if (substr($_[0], $_, 1) =~ /[aeiouy]/) {
			substr($_[0], $_, 1) = "" if (rand() < 0.7);
		}
	}
};
push @lulz, sub {$_[0] =~ s/((\w)+)/$1$2/g for (0 .. rand(3)+2)};
push @lulz, sub {
	my @prefixes = (
		'',
		'my man ',
		'King ',
		'Queen ',
		'Lord ',
		'Lady ',
		'Sir ',
		'the Honorable ',
		'Magister ',
		'arg blarg ',
		'Master ',
		'lol',
	);
	my @suffixes = (
		'',
		' the Horrible',
		' the Great',
		'osaurus',
		' the Awesome',
		' the Magnificent',
		' the n00bish',
		'-o-tron',
		'lol',
		'inator',
	);
	substr($_[0], 0, 0) = $prefixes[rand(@prefixes)];
	substr($_[0], length($_[0]), 0) = $suffixes[rand(@suffixes)];
};

sub lulzify {
	my ($name) = @_;
	my $origname = $name;
	while ($name eq $origname) {
		my $lul = $lulz[int(rand(@lulz))];
		$lul->($name);
	}
	return $name;
};

##
## END LULZ
##

##
## Functions to deal with irc input
##

sub debug {
	my $queue = join ", ", @queue;
	my $used = join ", ", sort keys %used;
	Irssi::print $_[0]."; queue is {$queue}; wm is $wm; prefix is $prefix; used is {$used}; selfpoptime $selfpoptime";
}

## Respond to messages on channels we're in. Only supports one channel.
sub public {
	my ($server, $msg, $nick, $address, $target) = @_;

	if ($target ne $CONFIG{channel}
	    || $server->{tag} ne $CONFIG{server}) {
		return;
	}

	my $self = $server->{nick};
	my $tome = 0;
	$tome = 1 if ($msg =~ /^$self/);
	my $fromwm = ($nick eq $wm);

	$msg =~ s/^$self\S*\s+//;

	## Queue management
	if ($msg =~ /^enclue/i) {
		push @queue, $nick;
		debug "Enclued $nick";
	}
	if ($msg =~ /^pop/i && ($fromwm || @queue > 0 && $nick eq $queue[0])) {
		if (@queue != 0) {
			return if (time - $selfpoptime < $SELFPOPWAIT);
			$selfpoptime = time if ($nick eq $queue[0]);
			my $cluer = shift @queue;
			$cluer = "$cluer: ".lulzify($cluer) if rand() < $lulzprob;
			my @queue = map {rand() < $lulzprob ? lulzify($_) : $_} @queue;
			my $queue = join ", ", @queue;
			$server->send_message($target, "$cluer, your clue! remaining queue is {$queue}", 0);
			debug "Popped $cluer";
		}
		else {
			$server->send_message($target, 'The queue is empty', 0) if ($tome);
			debug "Pop, but empty queue";
		}
	}
	if ($msg =~ /^poof/i || $msg =~ /^declue/i) {
		my @q;
		foreach (@queue) {
			push @q, $_ unless ($nick eq $_);
		}
		@queue = @q;
	}
	if ($msg =~ /^queue/i && $tome) {
		my @queue = map {rand() < $lulzprob ? lulzify($_) : $_} @queue;
		my $queue = join ', ', @queue;
		$server->send_message($target, "The queue is {$queue}", 0);
	}
	
	## Wordmaster management
	if (($msg =~ /^choosewm/i || $msg =~ /^selectwm/i) && $tome) {
		my @choices = split ' ', $msg;
		my $wm = $choices[int(rand(@choices)-1)+1];
		$wm = "$wm: ".lulzify($wm) if rand() < $lulzprob;
		$server->send_message($target, "$wm, I choose you!", 0);
	}
	if (($msg =~ /^wm/i || $msg =~ /^wordmaster/i) && $tome) {
		my $wm = lulzify($wm) if rand() < $lulzprob;
		$server->send_message($target, "The wordmaster is $wm", 0);
	}

	## Track things it's not
	if ($fromwm && $prefix && ($msg =~ /^not/i || $msg =~ /^it is not/i || $msg =~ /^it's not/i || $msg =~ /it isn't/i || $msg =~ /isn't/i || $msg =~ /^nor/i || $msg =~ /^no, (it is|it's) not/i)) {
		my $caughtused = 0;
		while ($msg =~ /\b($prefix\w*)\b/ig) {
			$caughtused = 1;
			$used{$1} = 1;
		}
		debug "Caught words it's not" if $caughtused;
	}
	if ($msg =~ /^used/i && $tome) {
		my $used = join ", ", sort keys %used;
		$server->send_message($target, "the word is none of {$used}", 0);
	}

	## lulz!
	if (($msg =~ /^more lulz/i || $msg =~ /^moar lulz/i) && $tome) {
		$lulzprob += 0.25 if $lulzprob < 1;
		Irssi::print "caught more lulz; now $lulzprob";
	}
	if ($msg =~ /^fewer lulz/i && $tome) {
		$lulzprob -= 0.25 if $lulzprob > 0;
		Irssi::print "caught fewer lulz; now $lulzprob";
	}
}

## Respond to privmsgs
sub private {
	my ($server, $msg, $nick, $address) = @_;
	if ($msg =~ /^queue/) {
		my @queue = map {rand() < $lulzprob ? lulzify($_) : $_} @queue;
		my $queue = join ', ', @queue;
		$server->send_message($nick, "The queue is {$queue}", 1);
	}
	if ($msg =~ /^wm/ || $msg =~ /^wordmaster/) {
		my $wm = lulzify($wm) if rand() < $lulzprob;
		$server->send_message($nick, "The wordmaster is $wm", 1);
	}
	if ($msg =~ /^used/) {
		my $used = join ", ", sort keys %used;
		$server->send_message($nick, "the word is none of {$used}", 1);
	}
	if ($msg =~ /^help/) {
		my $helpmsg = <<EOF;
Hi! I exist to help manage games of contact. My owner is $CONFIG{owner}. I respond to the following commands, which must be at the beginning of a line (mod being addressed to me): enclue -- put yourself in the clue queue
pop -- when said by the wordmaster (or the next person in the queue), ask the next person in the queue for their clue
poof, declue -- remove yourself from the queue
queue -- show the queue (must be addressed to me)
choosewm, selectwm -- pick a wordmaster from a list of names (must be addressed to me)
wm, wordmaster -- show who the wordmaster is (it's whoever last set the topic)
not, it is not, it's not, it isn't, isn't, nor -- when said by the wordmaster, search the line for words that match the prefix, and remember them as used
used -- show words that have been used
help -- show this whole thing (must be addressed to me)
moar lulz, more lulz, fewer lulz -- should be obvious! (must be addressed to me)
A description of the game of Contact is available at http://mrwright.name/contact.txt
EOF
		$server->send_message($nick, $_, 1) foreach split "\n", $helpmsg;
	}
}

## Parse the topic and update game state accordingly
sub topic {
	my $channel = $_[0];

	if ($channel->{name} ne $CONFIG{channel}
	    || $channel->{server}{tag} ne $CONFIG{server}) {
		return;
	}

	## Find the wordmaster
	($wm) = ($channel->{topic_by} =~ /(.+)!/);

	## Find the prefix
	my $topic = $channel->{topic};
	$topic =~ s/\s*[|#].*$//;
	my $oldprefix = $prefix;
	($prefix) = ($topic =~ /(\w+)$/);

	if ($prefix =~ /$oldprefix/) {
		## Continue game: only keep relevant words in the used list
		my @used = grep {/^$prefix/i} keys %used;
		%used = ();
		$used{$_} = 1 foreach @used;
	}
	else {
		## New game!
		%used = ();
		@queue = ();
	}

	debug "loaded topic state";
}

##
## Functions for local irssi interaction
##

sub getstate {
	my ($data, $server, $witem) = @_;
	unless ($server && $server->{connected}) {
		Irssi::print("I'm not connected to a server!");
	}
	unless ($witem && $witem->{type} eq "CHANNEL") {
		if ($data && $server->ischannel($data)) {
			$witem = $server->channel_find($data);
		}
	}
	unless ($witem) {
		Irssi::print("That's not a channel!");
		return;
	}
	topic $witem;
}

Irssi::signal_add 'message public' => \&public;
Irssi::signal_add 'message private' => \&private;
Irssi::signal_add 'channel topic changed' => \&topic;
Irssi::signal_add 'channel joined' => \&topic;
Irssi::command_bind 'getstate' => \&getstate;
