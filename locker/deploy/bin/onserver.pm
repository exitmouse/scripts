package onserver;
use strict;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(setup totmp print_login_info press_enter $server $tmp $USER $HOME $sname $deploy $addrend $admin_username $requires_sql $addrlast $sqlhost $sqluser $sqlpass $sqldb $sqldbcurl $admin_password $scriptsdev $human);

our $server = "scripts.mit.edu";

our ($tmp, $USER, $HOME, $sname, $deploy, $addrend, $admin_username, $requires_sql, $addrlast, $sqlhost, $sqluser, $sqlpass, $sqldb, $sqldbcurl, $admin_password, $scriptsdev, $human);

$tmp = ".scripts-tmp";
sub totmp {
  open(FILE, ">$tmp");
  print FILE $_[0];
  close(FILE);
}

sub print_login_info {
  print "\nYou will be able to log in to $sname using the following:\n";
  print "  username: $admin_username\n";
  print "  password: $admin_password\n";
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
  
  if($requires_sql) {
    print "\nCreating SQL database for $sname...\n";
   
    my $getpwd=`/mit/scripts/sql/bin$scriptsdev/get-password`;
    ($sqlhost, $sqluser, $sqlpass) = split(/\s/, $getpwd);
    
    $sqldb=`/mit/scripts/sql/bin$scriptsdev/get-next-database "$addrlast"`;
    $sqldb=`/mit/scripts/sql/bin$scriptsdev/create-database "$sqldb"`;
    if($sqldb eq "") {
      print "\nERROR:\n";
      print "Your SQL account failed to create a SQL database.\n";
      print "You should log in at http://sql.mit.edu to check whether\n";
      print "your SQL account is at its database limit or its storage limit.\n";
      print "If you cannot determine the cause of the problem, please\n";
      print "feel free to contact sql\@mit.edu for assistance.\n";
      `touch .failed`;
      exit 1;
    }
    $sqldbcurl = $sqldb;
    $sqldbcurl =~ s/\+/\%2B/;
  }
 
  if(-e "$HOME/web_scripts/$addrend/.admin") { 
    $admin_password=`cat $HOME/web_scripts/$addrend/.admin`;
  }
  chomp($admin_password);
  unlink "$HOME/web_scripts/$addrend/.admin";
  
  print "\nConfiguring $sname...\n";
  
  `date > .scripts-version`;
  `stat /mit/scripts/deploy$scriptsdev/$deploy.tar.gz >> .scripts-version`;

  select STDOUT;
  $| = 1; # STDOUT is *hot*!
}
