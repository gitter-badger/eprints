######################################################################
#
# EPrints Language class module
#
#  This module represents a language, and provides methods for 
#  retrieving phrases in that language (from a config file)
#
#  All errors in the Language file are in english, otherwise we could
#  get into a loop!
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


package EPrints::Language;

use EPrints::Site::General;

use strict;

# Cache for language objects NOT attached to a config.
my %LANG_CACHE = ();

######################################################################
#
# $language = fetch( $site , $langid )
#
# Return a language from the cache. If it isn't in the cache
# attempt to load and return it.
# Returns undef if it cannot be loaded.
# Uses default language if langid is undef. [STATIC]
# $site might not be defined if this is the log language and
# therefore not of any specific site.
#
######################################################################

sub fetch
{
	my( $site , $langid ) = @_;

	if( !defined $langid )
	{
		$langid = $site->getConf( "default_language" );
	}

	my $lang = EPrints::Language->new( $langid , $site );

	return $lang;

}


######################################################################
#
# $language = new( $langid, $site )
#
# Create a new language object representing the language to use, 
# loading it from a config file.
#
# $site is optional. If it exists then the language object
# will query the site specific override files.
#
######################################################################

sub new
{
	my( $class , $langid , $site ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{id} = $langid;

	$self->{sitedata} =
		read_phrases( $site->getConf( "phrases_path" )."/".$self->{id} );

	$self->{data} =
		read_phrases( $EPrints::Site::General::lang_path."/".$self->{id} );
	
	if( $site->getConf("default_language") ne $self->{id})
	{
		$self->{fallback} = EPrints::Language::fetch( 
					$site,  
					$site->getConf("default_language") );
	}

	return( $self );
}

######################################################################
#
# $phrase = phrase( $phraseid, @inserts )
#
# Return the phrase represented by phraseid in the language 
# of this object.
# Inserts the @inserts into $(1), $(2) etc...
#
######################################################################

sub phrase 
{
	my( $self , $phraseid , $inserts ) = @_;

	my @callinfo = caller();
	$callinfo[1] =~ m#[^/]+$#;
	return $self->file_phase( $& , $phraseid , $inserts );
}


sub file_phase
{
	my( $self , $file , $phraseid , $inserts ) = @_;

	if( !defined $inserts )
	{
		$inserts = {};
	}

	my( $response , $fb ) = $self->_file_phrase( $file , $phraseid , $_ );

	if( $fb )
	{
		if( $phraseid =~ m/^H:/ )
		{
			$response = "<FONT color=\"#00ff00\">$response</FONT>";
		}
		else
		{
			$response = "*".$response."*";
		}
	}

	if( defined $response )
	{
		$response =~ s/\$\(([a-z_]+)\)/$inserts->{$1}/ieg;
		return $response;
	}
	return "[- \"$file:$phraseid\" not defined for lang (".join(")(",$self->{id},values %{$inserts}).")-]";
}

sub _file_phrase
{
	my( $self, $file, $phraseid ) = @_;

	my $res = undef;

	$res = $self->{sitedata}->{MAIN}->{$phraseid};
	return $res if ( defined $res );
	$res = $self->{sitedata}->{$file}->{$phraseid};
	return $res if ( defined $res );
	if( defined $self->{fallback} )
	{
		$res = $self->{fallback}->_get_sitedata()->{MAIN}->{$phraseid};
		return ( $res , 1 ) if ( defined $res );
		$res = $self->{fallback}->_get_sitedata()->{$file}->{$phraseid};
		return ( $res , 1 ) if ( defined $res );
	}

	$res = $self->{data}->{MAIN}->{$phraseid};
	return $res if ( defined $res );
	$res = $self->{data}->{$file}->{$phraseid};
	return $res if ( defined $res );
	if( defined $self->{fallback} )
	{
		$res = $self->{fallback}->_get_data()->{MAIN}->{$phraseid};
		return ( $res , 1 ) if ( defined $res );
		$res = $self->{fallback}->_get_data()->{$file}->{$phraseid};
		return ( $res , 1 ) if ( defined $res );
	}


	return undef;
}

sub _get_data
{
	my( $self ) = @_;
	return $self->{data};
}
sub _get_sitedata
{
	my( $self ) = @_;
	return $self->{sitedata};
}
######################################################################
#
# read_phrases( $file )
#
#  read in the phrases.
#
######################################################################

sub read_phrases
{
	my( $file ) = @_;
	
	unless( open(LANG, $file) )
	{
		# can't translate yet...
		print STDERR "Can't open eprint language file: $file: $!\n";
		return {};
	}
	
	my $data = {};	

	print STDERR "opened eprint language file: $file\n";

	my $CURRENTFILE = 'MAIN';
	while( <LANG> )
	{
		chomp;
		next if /^\s*#/;
		next if /^\s*$/;
		
		if( /FILE\s*=\s*([^\s]+)/ )
		{
			$CURRENTFILE=$1;
			if( !defined $data->{$CURRENTFILE} )
			{
				$data->{$CURRENTFILE} = {};
			}
		}
		elsif( /^\s*([A-Z]:[A-Za-z0-9_]+)\s*=\s*(.*)$/ )
		{
			my ( $key , $val ) = ( $1 , $2 );
			# convert \n to actual CR's
			$val =~ s/\\n/\n/g;
			$data->{$CURRENTFILE}->{$key}=$val;
		}
		else
		{
			print STDERR "ERROR in language file: $file near:\n$_\n";
		}
	}
print STDERR "Loaded: $file\n";

	close( LANG );

	return $data;
}

1;
