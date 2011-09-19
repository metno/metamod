package Metamod::OAI::SetDescription;

use strict;
use warnings;

use HTTP::OAI::SAXHandler qw/ :SAX /;

use base qw( HTTP::OAI::Encapsulation );

sub new {
    my ($class,%args)    = @_;
    my $self = $class->SUPER::new(%args);

    $self->{handlers} = $args{handlers};

    $self->{setDescription} = $args{setDescription} || [];
    return $self;
}

sub setDescription {
    my $self = shift;
    push(@{$self->{setDescription}}, @_);
    return @{$self->{setDescription}};
}

sub generate {
    my ($self) = @_;
    return unless defined(my $handler = $self->get_handler);
    g_start_element($handler,'http://www.openarchives.org/OAI/2.0/','setDescription',{});
    for( $self->setDescription ) {
        $_->set_handler($handler);
        $_->generate;
    }
    g_end_element($handler,'http://www.openarchives.org/OAI/2.0/','setDescription');
}

1;