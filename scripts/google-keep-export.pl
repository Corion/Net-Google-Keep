#!perl -w
use strict;
use WWW::Mechanize::Chrome;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use JSON qw(decode_json encode_json);
use Future::HTTP;
Log::Log4perl->easy_init($ERROR);  # Set priority of root logger to ERROR

use Getopt::Long;
use Pod::Usage;
GetOptions(
    'f|outfile=s' => \my $filename,
    'help'        => \my $help,
) or pod2usage(2);
pod2usage(1) if $help;

=head1 SYNOPSIS

  google-keep-export.pl -f my-export-%d.json

=head1 OPTIONS

=item B<-f>, B<--outfile>

Name of the output file. If not given, the JSON will be dumped to STDOUT.

=cut

my $chrome_default;
if( $^O =~ /mswin/i ) {
    ($chrome_default) = grep { -x $_ }
                        #map  { "$_\\Google\\Chrome\\Application\\chrome.exe" }
                        map  { "$_/chrome.exe" }
                        grep { defined $_ && -d $_ }
                        ('chrome-v66-google-keep-scraper',
                         $ENV{"ProgramFiles"},
                         $ENV{"ProgramFiles(x86)"},
                         $ENV{"ProgramFilesW6432"},
                        );
} else {
    $chrome_default = undef;
};

my $m = WWW::Mechanize::Chrome->new(
    launch_exe => $chrome_default,
    #headless   => 1,
);

#$m->driver->send_message('Page.addScriptToEvaluateOnNewDocument', source => <<'JS')->get();
#  // Overwrite the `plugins` property to use a custom getter.
#  Object.defineProperty(window.navigator, 'languages', {
#    get: function () { return ['de-DE','de','en-US', 'en'] }
#  });
#  Object.defineProperty(navigator, 'plugins', {
#    // This just needs to have `length > 0` for the current test,
#    // but we could mock the plugins too if necessary.
#    get: () => [1, 2, 3, 4, 5],
#  });
#JS

$m->agent( 'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3346.0 Safari/537.36' );

my @requests;
my %seen;

# This is what we need to find the Google credentials and URLs from
# the Google Keep application. Most of this can be stored in a config file
# instead.

my $urls = $m->add_listener('Network.responseReceived', sub {
    my( $info ) = @_;
    my $url = $info->{params}->{response}->{url};
    my $id = $info->{params}->{requestId};

    return unless $url =~ /\bclients\d\.google\.com\b/;
    return unless $url =~ m!/notes/!;
    return unless $url =~ /\bchanges\?alt=json\b/;

    if( ! $seen{$id}++) {
        print "$id> $url\n";

        # https://bugs.chromium.org/p/chromium/issues/detail?id=457484
        # getResponseBody does not work for XHRs with "responseType = 'blob'"
        # So, how will we get at the data from that XHR?!
        # We need to manually replay the XHR, reproducing all the headers
        # and the POST body. Yay.
        # I guess we don't even need to do this in an .responseReceived
        # handler and can just do it in a .requestSent handler instead.

        my $req = {
            info => $info,
            postBody => [],
        };

        if( $info->{params}->{response}->{requestHeaders}->{":method"} eq 'POST' ) {
            $req->{postBody} = $m->getRequestPostData( $id );
        };
        push @requests, [ $url, $req ];

        #$urls{ $url } = $m->getResponseBody( $id )->then( sub {
        #    print Dumper $_[0];
        #    print "---";
        #    Future->done( $_[0]);
        #})->catch(sub {
        #    warn Dumper \@_;
        #});
    };
});

$m->get('https://keep.google.com/');
my ($languages,$type) = $m->eval_in_page('navigator.languages');
print Dumper $languages;
(my $plugins,$type) = $m->eval_in_page('navigator.plugins');
print Dumper $plugins;

if( $m->uri =~ m!https://accounts.google.com/! ) {
    print $m->title,"\n";
    print $m->uri,"\n";
    # If we are at the sign-in, we need user interaction :-(
    print "We need a manual login from Chrome first\n";
    exit 1;
};

$m->sleep(5);
#$m->report_js_errors;

# The magic API request for the additional notes in JSON format is
# POST https://clients6.google.com/notes/v1/changes?alt=json&key=xxx
# But we need the appropriate cookie and other stuff, as a simple GET request
# doesn't work due to missing authorization
# So, we clone the information we glean from the response(s) above and
# replay that.

if( ! @requests ) {
    print $m->title,"\n";
    print $m->uri,"\n";
    #print $m->content(format => 'html');
};

if( @requests > 1 ) {
    print "Will need to merge multiple requests\n";
};

sub fetch_xhr_json {
    my( $ua, $url, $req ) = @_;
    my $postbody = $req->{ postBody } = $req->{ postBody }->get();
    $postbody = decode_json( $postbody );
    print "Have request body\n";

    #print Dumper $req->{info}->{params}->{response}->{requestHeaders};
    my %headers = %{ $req->{info}->{params}->{response}->{requestHeaders} };
    delete $headers{ $_ } for grep { /^:/ }keys %headers;
    #print "Have request headers\n";
    #print "---\n";
    # Now replay this from a different UA:
    # Actually, we won't need to replay the request for 'index.html'
    # as we have the payload already, from above
    print "$url\n";

    return $ua->http_request('POST' => $url,
        body    => encode_json( $postbody ),
        headers => \%headers,
    )->then( sub {
        my( $body, $headers ) = @_;

        $body = decode_content( $body, $headers );

        return Future->done($body, $headers);
    })
}

sub extract_json_from_html {
    my( $html, $re ) = @_;
    my @found = $html =~ /$re/g;
    for my $item ( @found ) {
        # de-escape the Javascript to a JSON string
        $item =~ s!\\x([a-fA-F0-9]{2})!chr(hex($1))!ge;
    };
    @found
};

sub fetch_html_json {
    my( $ua, $url, $req ) = @_;

    #my $id = $info->{params}->{requestId};
    #return $m->getResponseBody( $id )->then( sub {

    # Re-fetch the data using our other UA, just to prepare when we will
    # go Chrome-less in entirety

    my %headers = %{ $req->{info}->{params}->{response}->{requestHeaders} };
    delete $headers{ $_ } for grep { /^:/ }keys %headers;

    return $ua->http_request('GET' => $url,
        #body    => encode_json( $postbody ),
        headers => \%headers,
    )->then( sub {
        # Retrieve the content from the response immediately
        # instead of re-fetching the information through $ua?!
        my( $body, $headers ) = @_;
        $body = decode_content( $body, $headers );

        my @notes = extract_json_from_html( $body, qr/loadChunk\(JSON.parse\('([^']+)'\)/);
        warn Dumper \@notes;

        # Extract the JSON for the settings
        # <script type="text/javascript" nonce="xxx">preloadUserInfo(JSON.parse('\x7b
        #$body =~ m!<script\s+type="text/javascript"\s+nonce="[^"]+">preloadUserInfo\(JSON.parse\('((?:[^\\']+|\\x[0-9a-fA-F]{2}|\\[\\'])+)'\)!
        my @settings = extract_json_from_html( $body, qr!<script\s+type="text/javascript"\s+nonce="[^"]+">preloadUserInfo\(JSON.parse\('([^']+)'\)! );
        if( ! @notes ) {
            warn "Couldn't find preloaded notes on page";
            return Future->done( '{}', {} )
        } else {
            if( @notes > 1 ) {
                warn "Multiple preloaded item sections";
            };
            $body = $notes[0];

            #warn $body;

            # return the JSON and the headers
            return Future->done( $body, {} )
        };
    })
}

my $part = 1;
my $ua = Future::HTTP->new();
for my $r (@requests) {
    my( $url, $req ) = @$r;

    # If this is the https://keep.google.com/ base URL, re-fetch that and
    # extract the first few items from that, as they don't exist anywhere else
    my $notes;
    my $mimeType = $req->{info}->{params}->{response}->{mimeType};
    if( 'text/html' eq $mimeType) {
        $notes = fetch_html_json( $ua, $url => $req );

    } elsif( 'application/json' eq $mimeType) {
        $notes = fetch_xhr_json( $ua, $url => $req );

    } else {
        die "Unknown URL content type for URL '$url' : '$mimeType'";
    };

    $notes = [$notes->get]->[0];

    # We should merge those instead of overwriting ....
    my $fh;
    if( $filename ) {

        my $target = sprintf $filename, $part++;
        print "Writing to $target\n";

        open $fh, '>', $target
            or die "Couldn't write to '$target': $!";
    } else {
        $fh = \*STDOUT;
    };
    binmode $fh, ':encoding(UTF-8)';
    print {$fh} $notes;
};

undef $m;

# Code taken from HTTP::Message, to be incorporated in Future::HTTP proper
sub decode_content {
    my($body, $headers) = @_;
    my $content_ref = \$body;
    my $content_ref_iscopy = 1;

    eval {
	if (my $h = $headers->{'content-encoding'}) {
	    $h =~ s/^\s+//;
	    $h =~ s/\s+$//;
	    for my $ce (reverse split(/\s*,\s*/, lc($h))) {
		next unless $ce;
		next if $ce eq "identity" || $ce eq "none";
		if ($ce eq "gzip" || $ce eq "x-gzip") {
		    require IO::Uncompress::Gunzip;
		    my $output;
		    IO::Uncompress::Gunzip::gunzip($content_ref, \$output, Transparent => 0)
			or die "Can't gunzip content: $IO::Uncompress::Gunzip::GunzipError";
		    $content_ref = \$output;
		    $content_ref_iscopy++;
		}
		elsif ($ce eq "x-bzip2" or $ce eq "bzip2") {
		    require IO::Uncompress::Bunzip2;
		    my $output;
		    IO::Uncompress::Bunzip2::bunzip2($content_ref, \$output, Transparent => 0)
			or die "Can't bunzip content: $IO::Uncompress::Bunzip2::Bunzip2Error";
		    $content_ref = \$output;
		    $content_ref_iscopy++;
		}
		elsif ($ce eq "deflate") {
		    require IO::Uncompress::Inflate;
		    my $output;
		    my $status = IO::Uncompress::Inflate::inflate($content_ref, \$output, Transparent => 0);
		    my $error = $IO::Uncompress::Inflate::InflateError;
		    unless ($status) {
			# "Content-Encoding: deflate" is supposed to mean the
			# "zlib" format of RFC 1950, but Microsoft got that
			# wrong, so some servers sends the raw compressed
			# "deflate" data.  This tries to inflate this format.
			$output = undef;
			require IO::Uncompress::RawInflate;
			unless (IO::Uncompress::RawInflate::rawinflate($content_ref, \$output)) {
			    #$self->push_header("Client-Warning" =>
				#"Could not raw inflate content: $IO::Uncompress::RawInflate::RawInflateError");
			    $output = undef;
			}
		    }
		    die "Can't inflate content: $error" unless defined $output;
		    $content_ref = \$output;
		    $content_ref_iscopy++;
		}
		elsif ($ce eq "compress" || $ce eq "x-compress") {
		    die "Can't uncompress content";
		}
		elsif ($ce eq "base64") {  # not really C-T-E, but should be harmless
		    require MIME::Base64;
		    $content_ref = \MIME::Base64::decode($$content_ref);
		    $content_ref_iscopy++;
		}
		elsif ($ce eq "quoted-printable") { # not really C-T-E, but should be harmless
		    require MIME::QuotedPrint;
		    $content_ref = \MIME::QuotedPrint::decode($$content_ref);
		    $content_ref_iscopy++;
		}
		else {
		    die "Don't know how to decode Content-Encoding '$ce'";
		}
	    }
	}

	#if ($self->content_is_text || (my $is_xml = $self->content_is_xml)) {
	#    my $charset = lc(
	#        $opt{charset} ||
	#	$self->content_type_charset ||
	#	$opt{default_charset} ||
	#	$self->content_charset ||
	#	"ISO-8859-1"
	#    );
	#    if ($charset eq "none") {
	#	# leave it as is
	#    }
	#    elsif ($charset eq "us-ascii" || $charset eq "iso-8859-1") {
	#	if ($$content_ref =~ /[^\x00-\x7F]/ && defined &utf8::upgrade) {
	#	    unless ($content_ref_iscopy) {
	#		my $copy = $$content_ref;
	#		$content_ref = \$copy;
	#		$content_ref_iscopy++;
	#	    }
	#	    utf8::upgrade($$content_ref);
	#	}
	#    }
	#    else {
	#	require Encode;
	#	eval {
	#	    $content_ref = \Encode::decode($charset, $$content_ref,
	#		 ($opt{charset_strict} ? Encode::FB_CROAK() : 0) | Encode::LEAVE_SRC());
	#	};
	#	if ($@) {
	#	    my $retried;
	#	    if ($@ =~ /^Unknown encoding/) {
	#		my $alt_charset = lc($opt{alt_charset} || "");
	#		if ($alt_charset && $charset ne $alt_charset) {
	#		    # Retry decoding with the alternative charset
	#		    $content_ref = \Encode::decode($alt_charset, $$content_ref,
	#			 ($opt{charset_strict} ? Encode::FB_CROAK() : 0) | Encode::LEAVE_SRC())
	#		        unless $alt_charset eq "none";
	#		    $retried++;
	#		}
	#	    }
	#	    die unless $retried;
	#	}
	#	die "Encode::decode() returned undef improperly" unless defined $$content_ref;
	#	if ($is_xml) {
	#	    # Get rid of the XML encoding declaration if present
	#	    $$content_ref =~ s/^\x{FEFF}//;
	#	    if ($$content_ref =~ /^(\s*<\?xml[^\x00]*?\?>)/) {
	#		substr($$content_ref, 0, length($1)) =~ s/\sencoding\s*=\s*(["']).*?\1//;
	#	    }
	#	}
	#    }
	#}
    };
    #if ($@) {
	#Carp::croak($@) if $opt{raise_error};
	#return undef;
    #}

    #return $opt{ref} ? $content_ref : $$content_ref;
    return $$content_ref
}
