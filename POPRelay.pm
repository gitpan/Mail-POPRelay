package Mail::POPRelay;

use strict;
use Mail::Object;
use vars qw[$VERSION @ISA ];

use constant PRESERVE_MESSAGE => "# Above configuration will be preserved by POPRelay.\n";

$VERSION = '1.0.0';
@ISA     = qw[Mail::Object ];

$Mail::POPRelay::DEBUG = 0;

# ---------
sub __initTest {
	my $self   = shift;
	my %qaTest = %{; shift};

	foreach (keys %qaTest) {
		die sprintf "%s was not specified.\n", $qaTest{$_} unless defined $self->{$_};
	}
	return $self;
}


# ---------
sub init {
	my $myDefaults = {
		mailLogFile           => '/var/log/maillog',
		mailProgram           => 'sendmail',
		mailProgramRestart    => 0,
		makemapLocation       => '/usr/sbin/makemap',
		mailRelayIsDatabase   => 0,
		mailRelayDatabaseType => 'hash',
		mailRelayDirectory    => '/var/spool/poprelay',
	};
	splice(@_, 2, 0, splice(@_, 1, 1, $myDefaults));
	my $self = Mail::Object::init(@_);
	
	my %qualityAssurance = (
		mailLogFile         => 'Mail log file',
		mailProgram         => 'Mail program',
		mailRelayDirectory  => 'Mail access relay directory',
		mailRelayFile       => 'Mail access relay file',
		mailRelayPeriod     => 'Mail access relay period',
		makemapLocation     => 'Makemap location',
	);

	$self->addAttributeWithValue('relayPreserve', $self->__generatePreserveList());

	$self->__createRelayDirectory()
		unless (-d $self->{'mailRelayDirectory'});

	return $self->__initTest(\%qualityAssurance);
}


# ---------
sub restartMailProgram {
	my $self = shift;
	return `/etc/init.d/$self->{'mailProgram'} restart`;
}


# purge all relay addresses
# ---------
sub wipeRelayDirectory {
	my $self = shift;

	print "o Wiping relay directory\n" if $Mail::POPRelay::DEBUG;
	my $mailRelayDirectory = $self->{'mailRelayDirectory'};
	foreach (<$mailRelayDirectory/*>) {
		unlink($_) or die "Unable to remove $_: $!";
	}
	return $self;
}


# purge only expired relay addresses
# ---------
sub cleanRelayDirectory {
	my $self = shift;

	print "o Cleaning relay directory\n" if $Mail::POPRelay::DEBUG;
	my($mailRelayDirectory, @purgeCount) = ($self->{'mailRelayDirectory'}, 0);
	foreach (<$mailRelayDirectory/*>) {
		chomp();
		my $modifyTime = (stat("$_"))[8] or die "Unable to stat $_: $!";

		if (time > ($modifyTime + $self->{'mailRelayPeriod'})) {
			printf "	`- removing %s (%d - %d < %d)\n", $_, time, ($modifyTime + $self->{'mailRelayDirectory'}, $self->{'mailRelayPeriod'}) if $Mail::POPRelay::DEBUG;
			unlink($_) or die "Unable to unlink $_: $!";
			push @purgeCount, $_;
		}
	}
	return wantarray ? @purgeCount : scalar @purgeCount;
}


# ---------
sub addRelayAddress {
	my $self          = shift;
	my $userName      = shift;
	my $userIpAddress = shift;

	open(OUT, ">$self->{'mailRelayDirectory'}/$userIpAddress") or die "Unable to open $self->{'mailRelayDirectory'}/$userIpAddress: $!";
	print OUT $userName;
	close(OUT);

	return $self;
}


# ---------
sub __generatePreserveList {
	my $self = shift;

	my @preserveList;
	my $mailRelayFile = $self->{'mailRelayFile'};
	open(PACCESS, "<$mailRelayFile") or die "Unable to open $mailRelayFile: $!";
	while (<PACCESS>) {
		last if $_ eq PRESERVE_MESSAGE;
		push @preserveList, $_;
	}
	close(PACCESS);
	return join('', @preserveList);
}


# ---------
sub __createRelayDirectory {
	my $self = shift;

	die "Unable to create mail relay directory: $!" unless
		mkdir($self->{'mailRelayDirectory'}, 0027);

	return $self;
}


# write out entire relaying file
# ---------
sub generateRelayFile {
	my $self = shift;

	my @relayArray;
	my $mailRelayDirectory = $self->{'mailRelayDirectory'};
	
	$self->__createRelayDirectory()
		unless (-d $self->{'mailRelayDirectory'});

	foreach (<$mailRelayDirectory/*>) {
		s/.*\/(.+\d)$/$1/;
		printf "    `- adding $_\n" if $Mail::POPRelay::DEBUG;
		push @relayArray, ($self->{'mailRelayIsDatabase'})
			? sprintf "$_\tRELAY",
			: sprintf "$_";
	}

	# recreate preserve list incase of change
	$self->{'relayPreserve'} = $self->__generatePreserveList();

	my $mailRelayFile = $self->{'mailRelayFile'};
	open(RACCESS, ">$mailRelayFile") or die "Unable to open $mailRelayFile: $!";
	print RACCESS $self->{'relayPreserve'}, PRESERVE_MESSAGE, join("\n", @relayArray);
	close(RACCESS);

	# generate relay database if needed
	if ($self->{'mailRelayIsDatabase'}) {
		print "o Generating relay database\n" if $Mail::POPRelay::DEBUG;
		`$self->{'makemapLocation'} $self->{'mailRelayDatabaseType'} $self->{'mailRelayFile'} < $self->{'mailRelayFile'}`;
	}

	# restart mail server if needed 
	# (functionally this shouldn't be here but it does clean things up a bit)
	if ($self->{'mailProgramRestart'}) {
		sleep(3);
		print "o Restarting mail daemon\n" if $Mail::POPRelay::DEBUG;
		$self->restartMailProgram();
	}
	return $self;
}


1337;


__END__

=head1 NAME

Mail::POPRelay - Dynamic Relay Access Control


=head1 DESCRIPTION

Mobile POP Relay is designed as a framework to support
relaying through many different types of POP and email
servers. This software is useful for mobile users and is fully
compatible with virtual domains.

One of the main differences between this relay server and others is that
neither modification of the POP server or mail program is needed.  This
software should integrate seamlessly given the correct agent is provided.
Each agent possesses the ability to specify certain variables in order to create
a custom taylored relay agent per your servers setup.  Here is a list of the
available options and their descriptions:

	mailLogFile           
		Absolute location of the mail log file to monitor (tail).
		Defaulted to '/var/log/maillog'

	mailProgram
		Mail program service name.  Used to restart the email server
		if necessary through /etc/init.d.  Proper naming here should
		reflect your mail service name in /etc/init.d.
		Defaulted to 'sendmail'

	mailProgramRestart
		Should the mail server be restarted after adding to the relay file?
		This shouldn't be necessary if using an access database style relay file.
		Defaulted to '0'

	makemapLocation
		Absolute location of makemap used to create access database style
		relay files.
		Defaulted to '/usr/sbin/makemap'

	mailRelayIsDatabase
		Set accordingly if your mail relay file is a database.
		Defaulted to '0'

	mailRelayDatabaseType
		Ignore this value if your mail relay file is not a database.
		Specify the type for makemap if it is.
		Defaulted to 'hash'

	mailRelayDirectory
		A spool directory for creating program related relay tracking
		files.
		Defaulted to '/var/spool/poprelay'
		
	mailRelayFile
		Absolute location of the mail access relay file.
		No default value.

	mailRelayPeriod
		After a user successfully logs in we must set a period for
		which he/she can relay mail.  Specify this here in seconds.
		No default value.

Use the SYNOPSIS to help create your own agents.

=head1 SYNOPSIS

So how do I create my own agents?  
Simple.  Create a file in the ./bin directory for your agent and 
follow the instructions below.

1) Copy this header into your agent file:

----- BEGIN HEADER -----

use Mail::POPRelay;

# Mail::POPRelay is designed to be subclassed.

use strict;

use Mail::POPRelay;

use vars qw[@ISA ];

@ISA = qw[Mail::POPRelay ];

----- SNIP -----


2) Create a configuration for the agent.

Each agent should work w/ specific POP and Mail daemon configurations.
To accomodate these configurations, each agent combines different 
options described above in DESCRIPTION.

As a good foundation to get started, lets re-create the existing generic iPOP3 / Sendmail 
configuration that already exists in the ./bin directory.  

Copy the below agent body into your agent file:

----- BEGIN AGENT BODY -----

my %options = (
	mailRelayDirectory    => '/var/spool/poprelay',
	mailRelayPeriod       => 86400, # in seconds
	mailLogRegExp         => 'ipop3d\[\d+\]:.+user=(\w+) host=.*\[(\d+\.\d+\.\d+\.\d+)\] nmsgs=',

	# redhat 7.0 w/ access db
	mailRelayFile         => '/etc/mail/access',
	mailRelayIsDatabase   => 1,
	mailRelayDatabaseType => 'hash',
);
my $popDaemon = new Mail::POPRelay::Daemon(\%options);

----- SNIP -----


3) Modify / add or delete agent options

It may be necessary to change the relaying period.  Simply modify
the value of "mailRelayPeriod" from 86400 to your own value.

Maybe you aren't running a database compatible mail daemon.  This might require
switching the value of "mailRelayIsDatabase" from 1 to 0 and adding the option
"mailProgramRestart => 1".

Modification of the mailLogRegExp option may be necessary.  Scan your 
mail log file for the POP authentication line and set a matching regular expression
for the mailLogRegExp value.  The user name must end up in $1 and the relay host in $2.


=head1 METHODS

=over 4

=item	$popRelay->wipeRelayDirectory();

	Remove all relay access files

=item	$popRelay->cleanRelayDirectory();

	Remove expired access files

=item	$popRelay->generateRelayFile();

	Create relay file in relay directory.  An attempt to create 
	the relay directory will be made if it doesn't already exist.
	This method now also handles restarting the mail program and/or
	creating the access db file if necessary.

=item	$popRelay->restartMailProgram();

	Use is deprecated.  Not absolutely necessary anymore.  Read above.

=item	$popRelay->addRelayAddress('User Name', 'IP Address')

	Adds a user to relay mail for.


=back


=head1 DIAGNOSTICS

die().  Will write to syslog eventually.


=head1 CONTRIBUTIONS

=item John Beppu <beppu@lbox.org>

	Found a bug in the signal handlers.  Thanks for looking over my code ;)

=item Jefferson S. M <linuxman@trendservices.com.br>

	Provided a testing facility for the ipop3d_vpopd agent.


=head1 AUTHOR

Keith Hoerling <keith@hoerling.com>


=head1 SEE ALSO

Mail::POPRelay::Daemon(3pm), poprelay_cleanup(1p), poprelay_ipop3d(1p).

=cut

# $Id: POPRelay.pm,v 1.8 2001/11/26 18:12:58 keith Exp $
