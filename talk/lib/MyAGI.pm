package MyAGI;
use FindBin;
use lib "$FindBin::RealBin";
use Asterisk::AGI;
use vars qw(@ISA);
@ISA = qw(Asterisk::AGI);
my $object;
my %agi_vars;

sub new {
return $object if $object;
$object = new Asterisk::AGI;
%agi_vars = $object->ReadParse;
bless $object;
return $object;
}

sub get_agi_var {
my $class = shift;
my $var = shift;
if (defined($agi_vars{$var})) {
return $agi_vars{$var};
}
else {
return undef;
}
}

1;
