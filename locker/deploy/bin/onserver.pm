package onserver;
use strict;
use Exporter;
use Sys::Hostname;
use File::Spec::Functions;
use File::Basename;
use Socket;
use Cwd qw(abs_path);
use POSIX qw(strftime);
use LWP::UserAgent;
use URI;
our @ISA = qw(Exporter);
our @EXPORT = qw(setup totmp fetch_uri print_login_info press_enter $server $tmp $USER $HOME $sname $deploy $addrend $admin_username $requires_sql $addrlast $sqlhost $sqluser $sqlpass $sqldb $sqldbcurl $admin_password $scriptsdev $human);

our $server = "scripts.mit.edu";

our ($tmp, $USER, $HOME, $sname, $deploy, $addrend, $admin_username, $requires_sql, $addrlast, $sqlhost, $sqluser, $sqlpass, $sqldb, $sqldbcurl, $admin_password, $scriptsdev, $human);

$tmp = ".scripts-tmp";
sub totmp {
  open(FILE, ">$tmp");
  print FILE $_[0];
  close(FILE);
}

my $ua = LWP::UserAgent->new;
my $base_uri;

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
  
  ($sname, $deploy, $addrend, $admin_username, $requires_sql, $scriptsdev, $human) = @ARGV;
  chdir "$HOME/web_scripts/$addrend";
  
  if($addrend =~ /^(.*)\/$/) {
    $addrend = $1;
  }
  ($addrlast) = ($addrend =~ /([^\/]*)$/);
  
  $base_uri = "http://$server/~$USER/$addrend/";
  
  if($requires_sql) {
    print "\nCreating SQL database for $sname...\n";
   
    my $getpwd=system("/mit/scripts/sql/bin$scriptsdev/get-password");
    ($sqlhost, $sqluser, $sqlpass) = split(/\s/, $getpwd);
    
    $sqldb=system("/mit/scripts/sql/bin$scriptsdev/get-next-database", $addrlast);
    $sqldb=system("/mit/scripts/sql/bin$scriptsdev/create-database", $sqldb);
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
    $sqldbcurl = $sqldb;
    $sqldbcurl =~ s/\+/\%2B/;
  }
 
  if(-e "$HOME/web_scripts/$addrend/.admin") { 
    open ADMIN, "<$HOME/web_scripts/$addrend/.admin";
    $admin_password=<ADMIN>;
    chomp($admin_password);
    close ADMIN;
    unlink "$HOME/web_scripts/$addrend/.admin";
  } 

  print "\nConfiguring $sname...\n";
  
  open(VERSION, ">.scripts-version") or die "Can't write scripts-version file: $!\n";
  print VERSION strftime("%F %T %z\n", localtime);
  print VERSION $ENV{'USER'}, '@', getclienthostname(), "\n";
  my $tarball = abs_path("/mit/scripts/deploy$scriptsdev/$deploy.tar.gz");
  print VERSION $tarball, "\n";
  $tarball =~ s|/deploydev/|/deploy/|;
  print VERSION dirname($tarball), "\n";
  close(VERSION);

  select STDOUT;
  $| = 1; # STDOUT is *hot*!
}

1;
