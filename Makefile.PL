# -*- mode: perl; c-basic-offset: 4; indent-tabs-mode: nil; -*-

#use 5.006; #weaken
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# Normalize version strings like 6.30_02 to 6.3002,
# so that we can do numerical comparisons on it.
my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

my $module = 'Net::Google::Keep';
(my $main_file = "lib/$module.pm" ) =~ s!::!/!g;
(my $distname = $module) =~ s!::!-!g;

my @tests = map { glob $_ } 't/*.t', 't/*/*.t';

my %module = (
    MIN_PERL_VERSION => '5.006',
    META_MERGE => {
        "meta-spec" => { version => 2 },
        resources => {
            repository => {
                web => "https://github.com/Corion/$distname",
                url => "git://github.com/Corion/$distname.git",
                type => 'git',
            },
            bugtracker  => {
              web    => 'http://rt.cpan.org/Public/Dist/Display.html?Name='.$distname,
              mailto => $distname.'-bugs@rt.cpan.org',
            },
            license    => ['http://dev.perl.org/licenses/'],
        },
        dynamic_config   => 0, # we promise to keep META.* up-to-date
        x_static_install => 1, # we are pure Perl and don't do anything fancy
    },
    'NAME'          => $module,
    'LICENSE'       => 'perl',
    'VERSION_FROM'  => $main_file, # finds $VERSION
    'PREREQ_PM'     => {
                        'Moo'                    => 2,
                        'Filter::signatures'     => 0.10,
                        'Encode'                 => 0,
                        'Future::HTTP'           => 0, # our HTTP transport
                        'JSON'                   => 0,
                        'WWW::Mechanize::Chrome' => 0.16, # for scraping the setup and httpgrep
                        'URI::URL'               => 0,
                      }, # e.g., Module::Name => 1.1
    ABSTRACT_FROM   => $main_file, # retrieve abstract from module
    AUTHOR          => 'Max Maischein <corion@cpan.org>',
    EXE_FILES       => [ glob 'scripts/*.pl' ],
);

sub get_module_info { %module }

if( ! caller ) {
    # I should maybe use something like Shipwright...
    regen_README($main_file);
    #regen_EXAMPLES();
    WriteMakefile1(get_module_info);
};

sub WriteMakefile1 {  #Written by Alexandr Ciornii, version 0.21. Added by eumm-upgrade.
    my %params=@_;
    
    regen_README( $params{VERSION_FROM} );
    
    my $eumm_version=$ExtUtils::MakeMaker::VERSION;
    $eumm_version=eval $eumm_version;
    die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
    die "License not specified" if not exists $params{LICENSE};
    if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
        #EUMM 6.5502 has problems with BUILD_REQUIRES
        $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
        delete $params{BUILD_REQUIRES};
    }
    delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
    delete $params{MIN_PERL_VERSION} if $eumm_version < 6.48;
    delete $params{META_MERGE} if $eumm_version < 6.46;
    delete $params{META_ADD} if $eumm_version < 6.46;
    delete $params{LICENSE} if $eumm_version < 6.31;
    delete $params{AUTHOR} if $] < 5.005;
    delete $params{ABSTRACT_FROM} if $] < 5.005;
    delete $params{BINARY_LOCATION} if $] < 5.005;

    WriteMakefile(%params);
}

sub regen_README {
    # README is the short version that just tells people what this is
    # and how to install it
    eval {
        # Get description
        my $readme = join "\n",
            pod_section($_[0], 'NAME', 'no heading' ),
            pod_section($_[0], 'DESCRIPTION' ),
            <<EOD,

INSTALLATION

This is a Perl module distribution. It should be installed with whichever
tool you use to manage your installation of Perl, e.g. any of

  cpanm .
  cpan  .
  cpanp -i .

Consult http://www.cpan.org/modules/INSTALL.html for further instruction.
Should you wish to install this module manually, the procedure is

  perl Makefile.PL
  make
  make test
  make install

EOD
            pod_section($_[0], 'REPOSITORY'),
            pod_section($_[0], 'SUPPORT'),
            pod_section($_[0], 'BUG TRACKER'),
            pod_section($_[0], 'AUTHOR'),
            pod_section($_[0], 'LICENSE' ),
            pod_section($_[0], 'COPYRIGHT' ),
    ;
        update_file( 'README', $readme );
    };
    # README.mkdn is the documentation that will be shown as the main
    # page of the repository on Github. Hence we recreate the POD here
    # as Markdown
    eval {
        require Pod::Markdown;

        my $parser = Pod::Markdown->new();

        # Read POD from Module.pm and write to README
        $parser->parse_from_file($_[0]);
        my $readme_mkdn = <<STATUS . $parser->as_markdown;

[![Build Status](https://travis-ci.org/Corion/$distname.svg?branch=master)](https://github.com/Corion/$distname)

STATUS
        update_file( 'README.mkdn', $readme_mkdn );
    };
}

sub pod_section {
    my( $filename, $section, $remove_heading ) = @_;
    open my $fh, '<', $filename
        or die "Couldn't read '$filename': $!";

    my @section =
        grep { /^=head1\s+$section/.../^=/ } <$fh>;
    pop @section if $section[-1] =~ /^=/;
    shift @section if $remove_heading;

    # Trim the section
    if( @section ) {
        pop @section
            while $section[-1] =~ /^\s*$/;
        shift @section
            while $section[0] =~ /^\s*$/;
    };

    @section = map { $_ =~ s!^=\w+\s+!!; $_ } @section;
    return join "", @section;
}

sub update_file {
    my( $filename, $new_content ) = @_;
    my $content;
    if( -f $filename ) {
        open my $fh, '<', $filename
            or die "Couldn't read '$filename': $!";
        binmode $fh;
        local $/;
        $content = <$fh>;
    };

    if( $content ne $new_content ) {
        if( open my $fh, '>', $filename ) {
            binmode $fh;
            print $fh $new_content;
        } else {
            warn "Couldn't (re)write '$filename': $!";
        };
    };
}
1;