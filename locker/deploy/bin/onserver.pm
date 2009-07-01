package onserver;
use strict;
use Exporter;
use Sys::Hostname;
use File::Spec::Functions;
use File::Basename;
use File::Copy;
use Socket;
use Cwd qw(abs_path);
use POSIX qw(strftime);
use LWP::UserAgent;
use IPC::Open2;
use URI;
our @ISA = qw(Exporter);
our @EXPORT = qw(setup totmp fetch_uri print_login_info press_enter $server $tmp $USER $HOME $sname $deploy $addrend $base_uri $ua $admin_username $requires_sql $addrlast $sqlhost $sqluser $sqlpass $sqldb $admin_password $scriptsdev $human $email);

our $server = "scripts.mit.edu";

our ($tmp, $USER, $HOME, $lname, $sname, $deploy, $addrend, $base_uri, $ua, $admin_username, $requires_sql, $addrlast, $sqlhost, $sqluser, $sqlpass, $sqldb, $admin_password, $scriptsdev, $human, $email);

$tmp = ".scripts-tmp";
sub totmp {
  open(FILE, ">$tmp");
  print FILE $_[0];
  close(FILE);
}

$ua = LWP::UserAgent->new;
push @{$ua->requests_redirectable}, 'POST';

sub fetch_uri {
    my ($uri, $get, $post) = @_;
    my $u = URI->new($uri);
    my $req;
    if (defined $post) {
	$u->query_form($post);
	my $content = $u->query;
	$u->query_form($get);
	$req = HTTP::Request->new(POST => $u->abs($base_uri));
	$req->content_type('application/x-www-form-urlencoded');
	$req->content($content);
    } else {
	$u->query_form($get) if (defined $get);
	$req = HTTP::Request->new(GET => $u->abs($base_uri));
    }
    my $res = $ua->request($req);
    if ($res->is_success) {
	return $res->content;
    } else {
	print STDERR "Error fetching configuration page: ", $res->status_line, "\n";
	return undef;
    }
}

sub print_login_info {
  print "\nYou will be able to log in to $sname using the following:\n";
  print "  username: $admin_username\n";
  print "  password: $admin_password\n";
}

sub getclienthostname {
    if (my $sshclient = $ENV{"SSH_CLIENT"}) {
	my ($clientip) = split(' ', $sshclient);
	my $hostname = gethostbyaddr(inet_aton($clientip), AF_INET);
	return $hostname || $clientip;
    } else {
	return hostname();
    }
}

sub press_enter {
  local $/ = "\n";
  print "Press [enter] to continue with the install.";
  my $enter = <STDIN>; 
}

sub setup {
  $ENV{PATH} = '/bin:/usr/bin';
  $USER = $ENV{USER};
  $HOME = $ENV{HOME};
  
  ($lname, $sname, $deploy, $addrend, $admin_username, $requires_sql, $scriptsdev, $human) = @ARGV;
  chdir "$HOME/web_scripts/$addrend";
  $email = "$human\@mit.edu";
  
  if($addrend =~ /^(.*)\/$/) {
    $addrend = $1;
  }
  ($addrlast) = ($addrend =~ /([^\/]*)$/);
  
  $base_uri = "http://$server/~$USER/$addrend/";
  
  if($requires_sql) {
    print "\nCreating SQL database for $sname...\n";
   
    open GETPWD, '-|', "/mit/scripts/sql/bin$scriptsdev/get-password";
    ($sqlhost, $sqluser, $sqlpass) = split(/\s/, <GETPWD>);
    close GETPWD;
    open SQLDB, '-|', "/mit/scripts/sql/bin$scriptsdev/get-next-database", $addrlast;
    $sqldb = <SQLDB>;
    close SQLDB;
    open SQLDB, '-|', "/mit/scripts/sql/bin$scriptsdev/create-database", $sqldb;
    $sqldb = <SQLDB>;
    close SQLDB;
    if($sqldb eq "") {
      print "\nERROR:\n";
      print "Your SQL account failed to create a SQL database.\n";
      print "You should log in at http://sql.mit.edu to check whether\n";
      print "your SQL account is at its database limit or its storage limit.\n";
      print "If you cannot determine the cause of the problem, please\n";
      print "feel free to contact sql\@mit.edu for assistance.\n";
      open FAILED, ">.failed";
      close FAILED;
      exit 1;
    }
  }
 
  if(-e "$HOME/web_scripts/$addrend/.admin") { 
    open ADMIN, "<$HOME/web_scripts/$addrend/.admin";
    $admin_password=<ADMIN>;
    chomp($admin_password);
    close ADMIN;
    unlink "$HOME/web_scripts/$addrend/.admin";
  } 

  # This code was originally in onathena
  my $repo = "/mit/scripts/wizard$scriptsdev/srv/$deploy.git";
  if(-e $repo) {
    # Much of this can be replaced with
    # system("git", "clone", "--shared", $repo, ".");
    # but only once we complete the FC11 transition and are running
    # a version of Git more recent than 1.6.1 on all servers.
    `git init`;
    open HTACCESS, '>', '.git/.htaccess' or die $!;
    print HTACCESS "Deny from all";
    close HTACCESS;
    open ALTERNATES, '>', '.git/objects/info/alternates' or die $!;
    print ALTERNATES "$repo/objects";
    close ALTERNATES;
    system("git", "remote", "add", "origin", $repo);
    `git config branch.master.remote origin`;
    `git config branch.master.merge refs/heads/master`;
    `git fetch origin`;
    `git branch --track master origin/master`;
    system("git checkout master"); # to get output
  } else {
    system("tar", "zxpf", "/mit/scripts/deploy$scriptsdev/$deploy.tar.gz");
    my @files = glob("* .*"); # You /don't/ want to match dotfiles
    if (@files == 3) {
      chdir $files[0] or die $!;
      for (glob("{,.??}*")) {
        move($_, catfile("..", $_)) || die $!;
      }
      chdir ".."
    }
    rmdir $files[0];
  }
  if(-f "/mit/scripts/deploy$scriptsdev/php.ini/$deploy") {
    # Copy in PHP file,  perform substitutions, and make symlinks
    # to php.ini in all subdirectories
    my $nodot = $lname; $nodot =~ s/\.//;
    open(PHPIN, "/mit/scripts/deploy$scriptsdev/php.ini/$deploy") || die $!;
    open(PHPOUT, ">", "php.ini") || die $!;
    while(<PHPIN>) {
      s/SCRIPTS_USER/$lname/;
      s/SCRIPTS_NODOT/$nodot/;
      print PHPOUT $_ or die $!;
    }
    close(PHPOUT) || die $!;
    close(PHPIN) || die $!;
    # athrun doesn't exist on scripts.  But find exists!  Use alternate script
    system("/mit/scripts/bin/fix-php-ini-scripts");
  }

  print "\nConfiguring $sname...\n";
  if($requires_sql) {
    print "A copy of ${USER}'s SQL login info will be placed in\n/mit/$USER/web_scripts/$addrend.\n";
  }
  
  if(-e "/mit/scripts/wizard$scriptsdev/srv/$deploy.git") {
    # fake an empty commit to get version info
    my $pid = open2(\*GIT_OUT, \*GIT_IN, "git commit-tree HEAD: -p HEAD") or die "Can't execute git process";
    print GIT_IN "User autoinstalled application\n";
    print GIT_IN "Installed-by: ", $ENV{'USER'}, '@', getclienthostname(), "\n";
    close(GIT_IN);
    my $hash=<GIT_OUT>;
    chomp($hash);
    close(GIT_OUT);
    waitpid $pid, 0; # reap zombies
    system("git reset $hash");
  } else {
    open(VERSION, ">.scripts-version") or die "Can't write scripts-version file: $!\n";
    print VERSION strftime("%F %T %z\n", localtime);
    print VERSION $ENV{'USER'}, '@', getclienthostname(), "\n";
    my $tarball = abs_path("/mit/scripts/deploy$scriptsdev/$deploy.tar.gz");
    print VERSION $tarball, "\n";
    $tarball =~ s|/deploydev/|/deploy/|;
    print VERSION dirname($tarball), "\n";
    close(VERSION);
  }

  select STDOUT;
  $| = 1; # STDOUT is *hot*!
}

1;
