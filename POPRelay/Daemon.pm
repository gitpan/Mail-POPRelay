package Mail::POPRelay::Daemon;

use strict;
use Mail::POPRelay;
use File::Tail;
use vars qw[@ISA $VERSION ];
use POSIX qw[setsid ];

@ISA     = qw[Mail::POPRelay ];
$VERSION = '0.1.0';


# trap signal handling
# ---------
sub __setupSignals {
	my $self = shift;

	$SIG{'TERM'} = sub { $self->wipeRelayDirectory();  };
	$SIG{'KILL'} = sub { $self->wipeRelayDirectory();  };
	$SIG{'HUP'}  = sub { $self->cleanRelayDirectory(); };
}


# daemonize
# ---------
sub init {
	my $self = Mail::POPRelay::init(@_);

	defined(my $pid = fork()) or die "Unable to fork: $!";
	if ($pid) {
		# parent
		return $pid;
	} else {
		# sibling
		chdir('/')              or die "Can't chdir to /: $!";
		setsid()                or die "Can't start new session: $!";
		open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";

		$self->__setupSignals();
		$self->__mainLoop();

		return $self;
	}
}


# ---------
sub __mainLoop {
	my $self = shift;

	my $fileTail = File::Tail->new (
		name        => $self->{'mailLogFile'},
		interval    => 2,
		maxinterval => 3,
		adjustafter => 3,
	) or die "Unable to tail $self->{'mailLogFile'}: $!";

	my $line;
	while (defined($line = $fileTail->read())) {
		if ($line =~ m|$self->{'mailLogRegExp'}|) {
			print "o Removing addresses\n" if $Mail::POPRelay::DEBUG;
			$self->cleanRelayDirectory();
			print "o Adding address\n" if $Mail::POPRelay::DEBUG;
			$self->addRelayAddress($1, $2);
			print "o Generating relay file.\n" if $Mail::POPRelay::DEBUG;
			$self->generateRelayFile();
		}
	}
}


1337;

__END__

=head1 NAME

Mail::POPRelay::Daemon - Dynamic Relay Access Control Daemon Class


=head1 SYNOPSIS

Please see README.


=head1 DESCRIPTION

The daemon class of POPRelay.


=head1 DIAGNOSTICS

die().  Will write to syslog eventually.


=head1 CONTRIBUTE

If you feel compelled to write a subclass of POPRelay::Daemon, please let
me know so that it may be reviewed for addition to the CVS repository!


=head1 AUTHOR

Keith Hoerling <keith@hoerling.com>


=head1 SEE ALSO

Mail::POPRelay(3pm), poprelay_cleanup(1p), poprelay_ipop3d(1p).

=cut

# $Id: Daemon.pm,v 1.3 2001/11/25 00:37:27 keith Exp $
