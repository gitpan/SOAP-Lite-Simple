package SOAP::Lite::Simple::DotNet;

use strict;
use Carp;

use vars qw($VERSION);
use base qw(SOAP::Lite::Simple);

$VERSION = 0.1;

=head1 NAME

SOAP::Lite::Simple::DotNet - talk with .net webservices

=head1 DESCRIPTION

This package helps in talking with .net servers, it just needs
a bit of XML thrown at it and you get some XML back.
It's designed to be REALLY simple to use, it doesn't try to 
be cleaver in any way (patches for 'cleaverness' welcome).

=head1 SYNOPSIS

  If your .net services.asmx looks like this:

  <?xml version="1.0" encoding="utf-8"?>
  <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body>
      <GetActivity xmlns="http://www.yourdomain.com/services">
        <userId>long</userId>
      </GetActivity>
    </soap:Body>
  </soap:Envelope>


  # Create an object with basic SOAP::Lite config stuff
  my $dotnet = SOAP::Lite::Simple::DotNet->new({
    uri 		=> 'http://www.yourdomain.com/services',
    proxy 		=> 'http://www.yourproxy.com/services/services.asmx',
    xmlns 		=> 'http://www.yourdomain.com/services',
    soapversion 	=> '1.1', # defaults to 1.1
    timeout		=> '30', # detauls to 30 seconds
  });


  # Create the following XML:

  my $user_id = '900109';
  my $xml = "<userId _value_type='long'>$user_id</userId>";
  # IMPORTANT: you must set _value_type to long - matching the requirement in the services.asmx

  # Actually do the call
  if( $dotnet->fetch({
                         'method' => 'GetActivity',
                         'xml' => $xml,
                     }) ) {

                     # extract the results (XML string)
                     my $xml_results = $obj->results;

                     # Now validate the XML

  } else {
    # Got an error
    print "Problem using service:" . $dotnet->error();

  }

=head1 methods

=head2 new()

  my $dotnet->SOAP::Lite::Simple::DotNet->new({
    uri 	=> 'http://www.yourdomain.com/services',
    proxy 	=> 'http://www.yourproxy.com/services/services.asmx',
    xmlns 	=> 'http://www.yourdomain.com/services',
    soapversion => '1.1', # defaults to 1.1
    timeout	=> '30', # detauls to 30 seconds
  });

This constructor requires uri, proxy and xmlns to be
supplied, otherwise it will croak.

=head2 fetch()

  # Generate the required XML, this is the bit after the Method XML element
  # in the services.asmx descriptor for this method (see SYNOPSIS).
  my $user_id = '900109';
  my $xml = "<userId _value_type='long'>$user_id</userId>";

  if(my $xml_result = $dotnet->fetch({ method => 'GetActivity', xml => $xml }) {
	# You got some XML back
	my $parser = XML::LibXML->new();
	my $doc = $parser->parse_string($xml_result);

	# now validate the XML is what you were expecting.

  } else {
	# There was some sort of error
	print $dotnet->error() . "\n";
  }

This method actually calls the web service, it takes a method name
and an xml string. If there is a problem with either the XML or
the SOAP transport (e.g. web server error/could not connect etc)
undef will be returned and the error() will be set.

If all is successful the the XML string will be parsed back.
This still has all the SOAP wrapper stuff on it, so you'll
want to strip that out. IMPORTANT: you still need to validate
the XML contains the data you are expecting, if the server
has encountered an application error it may report this
in the XML.

If someone writes a 'validate_responce' method which takes
the XML result and check's it for SOAP errors I'd be
happy to add it (but I don't know/care enough about what
errors there could be to do it my self).

=cut

sub _call {
	my ($self,$method) = @_;

	# No, I don't know why this has to be a sub, it just does,
	# it's to do with the on_action which .net requires so it
	# submits as $uri/$method, rather than $uri#$method	
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

=head2 error()

  $self->error();

If fetch returns undef then check this method, it will either be that the XML
was not correctly formatted and XML::LibXML could not parse it, or there was
a transport error with the web service. Actual application errors will be
contained in the XML returned so you must validate this.

=cut

=head1 HOW TO DEBUG

At the top of your script, before 'use SOAP::Lite::Simple::DotNet' add:

use SOAP::Lite (  +trace => 'all',
                  readable => 1,
                  outputxml => 1,
               );

It may or may not help, .net services don't give you many helpful error messages!
At least you can see what's being submitted and returned. It can be the
smallest thing that causes a problem, mis-typed data (see _value_type in xml),
or typo in xmlns line.

=head1 BUGS

This is only designed to work with .net services, It may work
 with others. I haven't found any open webservices which I can use
to test against, but as far as I'm aware it all works - .net services
are all standard.. right.. :) ?

=head1 AUTHOR

Leo Lapworth <LLAP@cuckoo.org>

=head1 COPYRIGHT

(c) 2005 Leo Lapworth

This library is free software, you can use it under the same 
terms as perl itself.

=head1 SEE ALSO

  <SOAP::Lite::Simple>, <SOAP::Data::Builder> 

=cut

1;
