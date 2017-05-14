package inventory;
use Dancer2 ':syntax';
use Dancer2 ':script';
use Template;
use DBI;
use DBD::mysql;

set template => 'template_toolkit';
set layout => undef;
set views => File::Spec->rel2abs('./views');

sub get_connection{
  my $service_name=uc $ENV{'DATABASE_SERVICE_NAME'};
  my $db_host=$ENV{"${service_name}_SERVICE_HOST"};
  my $db_port=$ENV{"${service_name}_SERVICE_PORT"};
  my $dbh=DBI->connect("DBI:mysql:database=$ENV{'MYSQL_DATABASE'};host=$db_host;port=$db_port",$ENV{'MYSQL_USER'},$ENV{'MYSQL_PASSWORD'}, { RaiseError => 1 } ) or die ("Couldn't connect to database: " . DBI->errstr );
  return $dbh;
}

sub init_db{

  my $dbh = $_[0];

  eval { $dbh->do("DROP TABLE rooms") };
  $dbh->do("CREATE TABLE rooms (room_id INTEGER not null auto_increment, room_name VARCHAR(20),capacity INTEGER, hastv BOOLEAN, PRIMARY KEY (room_id) )");
  $dbh->prepare("INSERT INTO rooms (room_name, capacity, hastv) VALUES (?, ?, ?)");
  $dbh->execute('Sky', '6', '1');
  $dbh->execute('Giraffe', '10', '1');
  $dbh->execute('Ground', '3', '0');
  # $dbh->do("CREATE TABLE foo (id INTEGER not null auto_increment, name VARCHAR(20), email VARCHAR(30), PRIMARY KEY(id))");
  # $dbh->do("INSERT INTO foo (name, email) VALUES (" . $dbh->quote("Eric") . ", " . $dbh->quote("eric\@example.com") . ")");
};

get '/user/:id' => sub {
    my $timestamp = localtime();
    my $dbh = get_connection();

    my $sth = $dbh->prepare("SELECT * FROM foo WHERE id=?") or die "Could not prepare statement: " . $dbh->errstr;
    $sth->execute(params->{id});

    my $data = $sth->fetchall_hashref('id');
    $sth->finish();

    template user => {timestamp => $timestamp, data => $data};
};

get '/' => sub {

    my $dbh = get_connection();

    eval { $dbh->prepare("SELECT * FROM rooms")->execute() };
    init_db($dbh) if $@;

    # my $sth = $dbh->prepare("SELECT * FROM foo");
    # $sth->execute();

    # my $data = $sth->fetchall_hashref('id');
    # $sth->finish();

    my $rooms = $dbh->prepare("SELECT * FROM rooms");
    $rooms->execute();
    my $roomsdata = $rooms-> fetchall_hashref('room_id');

    my $timestamp = localtime();
    template index => { timestamp => $timestamp, rooms => $roomsdata, };
};

post '/pick' => sub {
  my $roomName = params->{roomSelect};

  my $dbh = get_connection();

  my $sql = $dbh->prepare("SELECT * FROM rooms WHERE room_name=?");
  $sql->execute($roomName);
  my $roomId = $sql->fetchall_hashref('room_id');


  my %timeHash;
  for(my $i = 0; $i < 48; $i++){
    $timeHash{$i} = "$i/2";
    if (($i%2) == 1){
      $timeHash{$i} .= ":30";
    } else {
      $timeHash{$i} .= ":00";
    }
  }

  my $timest = localtime();
  template pick => {timest => $timest, roomName => $roomName, roomId => $roomId, timeHash => %timeHash};
};

post '/' => sub {

   my $name = params->{name};
   my $email = params->{email};

   my $dbh = get_connection();

   $dbh->do("INSERT INTO foo (name, email) VALUES (" . $dbh->quote($name) . ", " . $dbh->quote($email) . ") ");

   my $sth = $dbh->prepare("SELECT * FROM foo");
   $sth->execute();

   my $data = $sth->fetchall_hashref('id');
   $sth->finish();

   my $timestamp = localtime();
   template index => {data => $data, timestamp => $timestamp};
};

get '/health' => sub {
  my $dbh  = get_connection();
  my $ping = $dbh->ping();

  if ($ping and $ping == 0) {
    # This is the 'true but zero' case, meaning that ping() is not implemented for this DB type.
    # See: http://search.cpan.org/~timb/DBI-1.636/DBI.pm#ping
    return "WARNING: Database health uncertain; this database type does not support ping checks.";
  }
  elsif (not $ping) {
    status 'error';
    return "ERROR: Database did not respond to ping.";
  }
  return "SUCCESS: Database connection appears healthy.";
};

true;
