package Metamod::Email;

=begin LICENSE

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

METAMOD is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with METAMOD; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

=end LICENSE

=cut

use strict;
use warnings;

use Mail::Mailer;
use Params::Validate qw(:all);

=head1 NAME

Metamod::Email - Wrapper module for sending emails.

=head1 DESCRIPTION

This

=head1 FUNCTIONS/METHODS

=cut

=head2 send_simple_email(%PARAMS)

Send a basic email with one or more recipients and a plaintext email body.

=over

=item body

The email body as a scalar.

=item bcc (optional)

An array reference with email addresses.

=item cc (optional)

An array reference with email addresses.

=item from

An email address that will be used in the from field.

=item subject

The subject of the email.

=item to

An array reference with email addresses.

=item return

Returns true on success. Dies on error.

=back

=cut

sub send_simple_email {
    my %params = validate(
        @_,
        {
            bcc     => { type => ARRAYREF, default => [] },
            body    => { type => SCALAR },
            cc      => { type => ARRAYREF, default => [] },
            from    => { type => SCALAR },
            subject => { type => SCALAR },
            to      => { type => ARRAYREF },
        }
    );

    my ( $bcc, $body, $cc, $from, $subject, $to ) = @params{qw(bcc body cc from subject to)};

    my $config = Metamod::Config->instance();
    my $logger = Log::Log4perl->get_logger('metamod.email');
    my $smtp = $config->has('SMTP_RELAY') ? $config->get('SMTP_RELAY') : undef;
    $logger->debug("Using SMTP server <$smtp>");
    #my $mailer = Mail::Mailer->new();
    my $mailer = $smtp ? Mail::Mailer->new('smtp', Server => $smtp) : Mail::Mailer->new();

    my %mail_headers = ();
    $mail_headers{From}    = $from;
    $mail_headers{To}      = $to;
    $mail_headers{Cc}      = $cc if 0 != @$cc;
    $mail_headers{Bcc}     = $bcc if 0 != @$bcc;
    $mail_headers{Subject} = $subject;

    $logger->debug("Message from $from to " . join(',', @$to) . " regarding \"$subject\":\n$body");

    $mailer->open(\%mail_headers);
    print $mailer $body;
    my $success = $mailer->close; # avoid dreaded Can't locate object method "CLOSE"... when using smtp
    if( !$success ){
        die "Could not send the email: $!";
    }

    return 1;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
