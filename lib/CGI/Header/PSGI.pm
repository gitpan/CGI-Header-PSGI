package CGI::Header::PSGI;
use 5.008_009;
use CGI::Header;
use CGI::Header::Redirect;
use Carp qw/croak/;
use Role::Tiny;

our $VERSION = '0.04';

requires qw( cache charset crlf self_url );

sub psgi_header {
    my $self = shift;
    my @args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;

    unshift @args, '-type' if @args == 1;

    return $self->_psgi_header(
        header_props => \@args,
        handler => 'CGI::Header',
    );
}

sub psgi_redirect {
    my $self = shift;
    my @args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;

    unshift @args, '-location' if @args == 1;

    return $self->_psgi_header(
        header_props => \@args,
        handler => 'CGI::Header::Redirect',
    );
}

sub _psgi_header {
    my $self = shift;
    my %args = @_;
    my $crlf = $self->crlf;

    my $header = $args{handler}->new(
        @{ $args{header_props} },
        -query => $self,
    );

    # for CGI::Simple
    if ( $self->can('no_cache') and $self->no_cache ) {
        $header->expires( 'now' ) if !$header->exists('Expires');
        $header->set( 'Pragma' => 'no-cache' ) if !$header->exists('Pragma');
    }

    my $status = $header->delete('Status') || '200';
       $status =~ s/\D*$//;

    # See Plack::Util::status_with_no_entity_body()
    if ( $status < 200 or $status == 204 or $status == 304 ) {
        $header->delete( $_ ) for qw( Content-Type Content-Length );
    }

    my @headers;
    $header->each(sub {
        my ( $field, $value ) = @_;

        # From RFC 822:
        # Unfolding is accomplished by regarding CRLF immediately
        # followed by a LWSP-char as equivalent to the LWSP-char.
        $value =~ s/$crlf(\s)/$1/g;

        # All other uses of newlines are invalid input.
        if ( $value =~ /$crlf|\015|\012/ ) {
            # shorten very long values in the diagnostic
            $value = substr($value, 0, 72) . '...' if length $value > 72;
            croak "Invalid header value contains a newline not followed by whitespace: $value";
        }

        push @headers, $field, $value;
    });

    return $status, \@headers;
}

1;

__END__

=head1 NAME

CGI::Header::PSGI - Role for generating PSGI response headers

=head1 SYNOPSIS

  use parent 'CGI';
  use Role::Tiny::With;

  with 'CGI::Header::PSGI';

  sub crlf { $CGI::CRLF }

  # psgi_header() and psgi_redirect() get imported

=head1 VERSION

This document refers to CGI::Header::PSGI 0.04.

=head1 DESCRIPTION

This module is a role to generate PSGI response headers.

=head2 REQUIRED METHODS

Your class has to implement the following methods.

=over 4

=item $query->charset

Returns the character set sent to the browser.

=item $query->self_url

=item $query->cache

=item $query->no_cache (optional)

=item $query->crlf

Returns the system specific line ending sequence.

=back

=head2 METHODS

By using this module, your class is capable of following methods.

=over 4

=item ($status_code, $headers_aref) = $query->psgi_header( %args )

Works like CGI.pm's C<header()>, but the return format is modified.
It returns an array with the status code and arrayref of header pairs
that PSGI requires.

Unlike C<header()>, this method doesn't update C<charset()>.

=item ($status_code, $headers_aref) = $query->psgi_redirect( %args )

Works like CGI.pm's C<redirect()>, but the return format is modified.
It returns an array with the status code and arrayref of header pairs
that PSGI requires.

=back

=head1 SEE ALSO

L<CGI::PSGI>, L<CGI::Emulate::PSGI>, L<CGI::Simple>

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut