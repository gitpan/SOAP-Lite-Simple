package SOAP::Lite::Simple;

use strict;
use Carp;
use XML::LibXML;
use SOAP::Lite;
use SOAP::Data::Builder;

use vars qw($VERSION);

use base qw(Class::Accessor::Chained::Fast);

my @methods = qw(results results_xml uri xmlns proxy soapversion timeout error strip_default_xmlns);

__PACKAGE__->mk_accessors(@methods);

$VERSION = 1.1;

=head1 NAME

SOAP::Lite::Simple - Simple frame work for talking with web services

=head1 DESCRIPTION

This package is the base class for talking with web services,
there are specific modules to use depending on the type
of service you are calling, e.g. <SOAP::Lite::Simple::DotNet> or
<SOAP::Lite::Simple::Real>

This package helps in talking with web services, it just needs
a bit of XML thrown at it and you get some XML back.
It's designed to be REALLY simple to use, it doesn't try to 
be cleaver in any way (patches for 'cleaverness' welcome).

=head1 SYNOPSIS

  See SOAP::Lite::Simple::DotNet for usage example.

  If you are creating a child class you just need to
  impliment the actual _call();

  package SOAP::Lite::Simple::<PACKAGE NAME>;

  use base qw(SOAP::Lite::Simple);

  sub _call {
	my ($self,$method) = @_;

	# Impliment it! - below is the code from Simple::DotNet

	# This code is the .NET specific way of calling SOAP,
	# it might work for other stuff as well        
        my $soap_action = sub {return $self->uri() . '/' . $method};
        
        my $caller = $self->{soap}
                        ->uri($self->uri())
                        ->proxy($self->proxy(), timeout => $self->timeout())
                        ->on_action( $soap_action );
        
        $caller->soapversion($self->soapversion());

        # Create a SOAP::Data node for the method name
        my $method_name = SOAP::Data->name($method)->attr({'xmlns' => $self->xmlns()});
  
        # Execute the SOAP Request and get the resulting XML
        my $res = $caller->call( $method_name => $self->{sdb}->to_soap_data());

        return $res;
  }

  1;

=head1 methods

=head2 new()

  my $soap_simple->SOAP::Lite::Simple::DotNet->new({
    uri 	=> 'http://www.yourdomain.com/services',
    proxy 	=> 'http://www.yourproxy.com/services/services.asmx',
    xmlns 	=> 'http://www.yourdomain.com/services',
    soapversion => '1.1', # defaults to 1.1
    timeout	=> '30', # detauls to 30 seconds
    strip_default_xmlns => 1, # defaults to 1
  });

This constructor requires uri, proxy and xmlns to be
supplied, otherwise it will croak.

strip_default_xmlns is used to remove xmlns="http://.../"
from returned XML, it will NOT alter xmlns:FOO="http//.../"
set to '0' if you do not wish for this to happen.

=cut

# Get an XML Parser
my $parser = XML::LibXML->new();
$parser->validation(0);
$parser->expand_entities(0);

my @config_methods = qw(uri xmlns proxy soapversion strip_default_xmlns);

sub new {
        my ($proto,$conf) = @_;
        my $class = ref($proto) || $proto;
        my $self = {};
        bless($self,$class);

	# Set up default soapversion and timeout
	$conf->{soapversion} = '1.1' unless defined $conf->{soapversion};
	$conf->{timeout} = '30' unless defined $conf->{soapversion};
	$conf->{strip_default_xmlns} = 1 unless defined $conf->{strip_default_xmlns};

	# Read in the required params
	foreach my $soap_conf (@config_methods) {
		unless( defined $conf->{$soap_conf} ) {
			croak "$soap_conf is required";
		} else {
			$self->$soap_conf($conf->{$soap_conf});
		}
	}

	# Set up the SOAP object
	$self->{soap} = SOAP::Lite->new;
	# We want the raw XML back
	$self->{soap}->outputxml(1);

	return $self;

};

=head2 fetch()

  # Generate the required XML, this is the bit after the Method XML element
  # in the services.asmx descriptor for this method (see Soap::Lite::Simple::DotNet SYNOPSIS).
  my $user_id = '900109';
  my $xml = "<userId _value_type='long'>$user_id</userId>";

  if(my $xml_result = $soap_simple->fetch({ method => 'GetActivity', xml => $xml }) {
	# You got some XML back
	my $parser = XML::LibXML->new();
	my $doc = $parser->parse_string($xml_result);

	# now validate the XML is what you were expecting.

  } else {
	# There was some sort of error
	print $soap_simple->error() . "\n";
  }

This method actually calls the web service, it takes a method name
and an xml string. If there is a problem with either the XML or
the SOAP transport (e.g. web server error/could not connect etc)
undef will be returned and the error() will be set.

If all is successful the the XML string will be parsed back.
This still has all the SOAP wrapper stuff on it, so you'll
want to strip that out. 

We check for Fault/faultstring in the returned XML,
anything else you'll need to check for yourself.

=cut

sub fetch {
	my ($self,$conf) = @_;

	# Check we have at least an empty string	
	if(!defined $conf->{xml}) {
		$self->error('You must supply at least an empty string for the xml');
		return undef;
	}
	if(!defined $conf->{method} or $conf->{method} eq '') {
		$self->error('You must supply a method name');
		return undef;
	}

	# add some wrapping paper so XML::LibXML likes it with no top level
	$conf->{xml} = '<soap_lite_wrapper>' . $conf->{xml} . '</soap_lite_wrapper>';
	my $xml;
	eval { $xml = $parser->parse_string($conf->{xml}) };
	if($@) {
		$self->error('Error parsing your XML: ' . $@);
		return undef;
	}

      	# create a builder
	$self->{sdb} = SOAP::Data::Builder->new();

	# Create the SOAP data from the XML
	my $nodes = $xml->childNodes;
	my $top = $nodes->get_node(1); # our wrapper
	if( my $nodes = $top->childNodes ) {
		foreach my $node (@{$nodes}) {
			$self->_process_node({node => $node});
		}	
	}	

	################
	## Execute the call and get the result back
	################

	# execute the call in the relevant style
	my $res = $self->_call($conf->{method});

	if (!defined $res or $res =~ /^\d/) {
                # Got a web error - well, if it was XML it wouldn't start with a digit!
                $self->error($res);
                return undef;
        } else {
		# Strip out crap default name space stuff as it makes it hard
		# to parse and there's no reason for it I can see!
		$res =~ s/xmlns=".+?"//g if $self->strip_default_xmlns();	

		# Generate xml object from the responce
		my $res_xml;
		eval { $res_xml = $parser->parse_string($res) };
        	if($@) {
			# Not valid xml
			$self->error('Unable to parse returned data as XML');
			return undef;
		} else {
			
			# Now look for faults	
			if(my $nodes = $res_xml->findnodes("//faultstring") ) {
				# loop through faultstrings - checking it's parent is 'Fault'
				# We do not care about namespaces
				foreach my $node ($nodes->get_nodelist()) {
					my $parentnode = $node->parentNode();
					if($parentnode->nodeName() =~ /Fault/) {
						# There is a "(*:)Fault/faultstring"
						# get the human readable string
						$self->error($nodes->get_node(1)->findvalue('.' , $nodes));
						last;	
					}
				}	
			}

			# See if there was a fault
			return undef if $self->error();

			# All looking good
			$self->results_xml($res_xml);
			$self->results($res);
			return $res;
		}
	}
}

=head2 error()

  $self->error();

If fetch returns undef then check this method, it will either be that the XML
you supplied was not correctly formatted and XML::LibXML could not parse it, there was
a transport error with the web service or either soap:Fault and soapenv:Fault error
messages were returned in the XML.

=head2 results();

  my $results = $soap_simple->results();

Can be called after fetch() to get the raw XML, if fetch was sucessful.

=head2 results_xml();

  my $results_as_xml = $soap_simple->results_xml();

Can be called after fetch() to get the XML::LibXML Document element of the returned
xml, as long as fetch was sucessful.

=cut

### Private methods

# Convert the XML to SOAP::Data::Builder
sub _process_node {
	my ($self,$conf) = @_;

	# Loop over the XML and generate the data
	
	# Set up the parent if there was one
	my $parent = '';
	$parent = $conf->{parent} if defined $conf->{parent};

	my $type = 'string';
	# Extract the attributes from the node
	my %attribs;
	foreach my $att ($conf->{node}->attributes()) {
		# skip anything which isn't defined!
		next unless defined $att;
		# Check if it's out 'special' value
		if($att->name() eq '_value_type') {
			$type = $att->value();
		} else {
			$attribs{$att->name()} = $att->value();
		}
	}
	
	my $value = '';
	my @t = $conf->{node}->childNodes();
	if(scalar(@t) == 1) {
		# at the end of the line, just got the value node below get the value
		$value = $conf->{node}->textContent();

		$parent = $self->{sdb}->add_elem(
			name => $conf->{node}->nodeName, 
			attributes => \%attribs,
			parent => $parent,
			value => $value,
			type => $type,
		);

	} else {
		# Add it - it's a node without a value, but has child nodes
		$parent = $self->{sdb}->add_elem(
				name => $conf->{node}->nodeName, 
				attributes => \%attribs,
				parent => $parent,
				type => $type,
			);

		foreach my $node ( $conf->{node}->childNodes() ) {
			# process each child node as long as it's not
			# a text node (type 3)
			$self->_process_node({ 
				'node' => $node, 
				'parent' => $parent,
			}) if $node->nodeType != 3;
		}
	}
}

=head1 HOW TO DEBUG

At the top of your script, before 'use SOAP::Lite::Simple::<TYPE>' add:

use SOAP::Lite (  +trace => 'all',
                  readable => 1,
                  outputxml => 1,
               );

It may or may not help, not all web services give you many helpful error messages!
At least you can see what's being submitted and returned. It can be the
smallest thing that causes a problem, mis-typed data (see _value_type in xml),
or typo in xmlns line.

If the type of module (e.g. SOAP::Lite::Simple::DotNet) doesn't work, switch
to one of the other ones and see if that helps. 

=head1 SEE ALSO

<SOAP::Lite::Simple::DotNet> <SOAP::Lite::Simple::Real>

=head1 AUTHOR

Leo Lapworth <LLAP@cuckoo.org>

=head1 COPYRIGHT

(c) 2005 Leo Lapworth

This library is free software, you can use it under the same 
terms as perl itself.

=head1 THANKS

Thanks to Foxtons for letting me develope this on their time and
to Aaron for his help with understanding SOAP a bit more and
the London.pm list for ideas.

=cut

1;
