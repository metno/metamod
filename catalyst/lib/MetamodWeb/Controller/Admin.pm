package MetamodWeb::Controller::Admin;
use Moose;
use namespace::autoclean;
use Metamod::mmLogView;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

MetamodWeb::Controller::Admin - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 end

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    my $mm_config = $c->stash->{ mm_config };
    my $application_id = $mm_config->get('APPLICATION_ID');
    my $application_name = $mm_config->get('APPLICATION_NAME');
    $c->stash(application_id => $application_id);
    $c->stash(application_name => $application_name);
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched MetamodWeb::Controller::Admin in Admin.');
}

=head2 menu

=cut

sub adminmenu :Path :Args(0) {
    my ( $self, $c ) = @_;

     $c->stash(template => 'admin/adminmenu.tt');
     $c->stash(current_view => 'Raw');
}

=head2 showconfig

=cut

sub showconfig :Local :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(template => 'admin/showconfig.tt');
    $c->stash(current_view => 'Raw');
    my $mm_config = $c->stash->{ mm_config };
    my $config_filename = $mm_config->{ filename };
    my $config_content;
    {
        local $/;
        open (CONFIG,$config_filename);
        $config_content = <CONFIG>;
        close (CONFIG);
    }
    $c->stash(config_content => $config_content);
}

=head2 showlog

=cut

sub showlog :Local :Args(0) {
    my ( $self, $c ) = @_;

    my $mm_config = $c->stash->{ mm_config };
    my $log_filename = $mm_config->get("LOG4ALL_SYSTEM_LOG");
    my $pars = $c->req->parameters;
    my $result = "";
    my $get_result = 0;
    my $fromdate = "";
    if (exists($pars->{'fromdate'})) {
        $fromdate = $pars->{'fromdate'};
    }
    my $todate = "";
    if (exists($pars->{'todate'})) {
        $todate = $pars->{'todate'};
    }
    if ($todate eq "") {
        $todate = $fromdate;
    }
    if ($fromdate eq "") {
        $fromdate = $todate;
    }
    my $logger = "";
    if (exists($pars->{'logger'})) {
        $logger = $pars->{'logger'};
    }
    my $level = "";
    if (exists($pars->{'level'})) {
        $level = $pars->{'level'};
    }
    my $multiline_is_checked = "";
    my $multiline = "";
    if (exists($pars->{'multiline'})) {
        $multiline = $pars->{'multiline'};
    }
    if ($multiline eq "multiline") {
        $multiline_is_checked = "checked";
    }
    my $optionstring = $multiline . " logfile=" . $log_filename . " ";
    if (exists($pars->{'summarydate'})) {
        $optionstring .= 'summarydate ';
        $fromdate = "";
        $todate = "";
        $get_result = 1;
    } elsif (exists($pars->{'summarylogger'})) {
        $optionstring .= 'summarylogger ';
        $logger = "";
        $get_result = 1;
    } elsif (exists($pars->{'summarylevel'})) {
        $optionstring .= 'summarylevel ';
        $level = "";
        $get_result = 1;
    } elsif (exists($pars->{'getmessages'})) {
        $result = mmLogView::run($optionstring);
        $get_result = 1;
    }
    if ($fromdate ne "") {
        $optionstring .= "from=" . $fromdate . " ";
    }
    if ($todate ne "") {
        $optionstring .= "to=" . $todate . " ";
    }
    if ($logger ne "") {
        $optionstring .= "logger=" . $logger . " ";
    }
    if ($level ne "") {
        $optionstring .= "level=" . $level . " ";
    }
    if ($get_result == 1) {
        $result = mmLogView::run($optionstring);
    }
    $c->stash(template => 'admin/showlog.tt');
    $c->stash(current_view => 'Raw');
    $c->stash(result => $result);
    $c->stash(optionstring => $optionstring);
    $c->stash(fromdate => $fromdate);
    $c->stash(todate => $todate);
    $c->stash(logger => $logger);
    $c->stash(level => $level);
    $c->stash(multiline_is_checked => $multiline_is_checked);
}

=head1 AUTHOR

Egil Støren

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
