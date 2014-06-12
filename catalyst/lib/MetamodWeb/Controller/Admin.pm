package MetamodWeb::Controller::Admin;
use Moose;
use namespace::autoclean;
use Metamod::mmLogView;

BEGIN {extends 'MetamodWeb::BaseController::Base'; }

=head1 NAME

MetamodWeb::Controller::Admin - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for sysadmin functions.

=head1 METHODS

=cut


sub auto :Private {
    my ($self, $c) = @_;

    return 0 unless $self->chk_logged_in($c);

    if( !$c->check_user_roles("admin") ){

        # detach() does not work correctly in auto()
        $c->forward("Root", "unauthorized", ['admin']);
        return 0;
    }

    $c->stash(current_view => 'None');

    my $mm_config = $c->stash->{ mm_config };
    my $application_id = $mm_config->get('APPLICATION_ID');
    my $application_name = $mm_config->get('APPLICATION_NAME');
    $c->stash(application_id => $application_id);
    $c->stash(application_name => $application_name);

    return 1;
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched MetamodWeb::Controller::Admin in Admin.');
    return 1;
}

=head2 menu

=cut

sub adminmenu :Path :Args(0) {
    my ( $self, $c ) = @_;

     $c->stash(template => 'admin/adminmenu.tt');
}

=head2 showconfigfile

Read in master_config.txt from disk (before merged with defaults – not so useful)

=cut

sub showconfigfile :Local :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(template => 'admin/showconfig.tt');
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

=head2 showconfig

Show generated config as in memory after merged with defaults

=cut

sub showconfig :Local :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(template => 'admin/showconfig.tt');
}

=head2 showlog

=cut

sub showlog :Local :Args(0) {
    my ( $self, $c ) = @_;

    my $testout = '/home/egils/egil/m2test/tdamoc/webrun/testout';
    open (TESTOUT,">$testout");
    print TESTOUT "Hoy\n";

    my $mm_config = $c->stash->{ mm_config };
    my $log_filename = $mm_config->get("LOG4ALL_SYSTEM_LOG");
    my $pars = $c->req->parameters;
    my $result = "";
    my $categories = "";
    my $files = "";
    my $levels = "";
    my $msg = "";
    my $excludes = "";
    my $get_result = 0;
    my $showresult = 0;
    my $fromdate = "";
    my @clearfields = ();
    if (exists($pars->{'clear'})) {
        if (ref($pars->{'clear'}) eq "ARRAY") {
            @clearfields = @{$pars->{'clear'}};
        } else {
            @clearfields = ($pars->{'clear'});
        }
    }
    if (exists($pars->{'fromdate'}) and !grep(/dates/,@clearfields)) {
        $fromdate = $pars->{'fromdate'};
    }
    my $todate = "";
    if (exists($pars->{'todate'}) and !grep(/dates/,@clearfields)) {
        $todate = $pars->{'todate'};
    }
    if ($todate eq "") {
        $todate = $fromdate;
    }
    if ($fromdate eq "") {
        $fromdate = $todate;
    }
    my $fromtime = "";
    if (exists($pars->{'fromtime'}) and !grep(/time/,@clearfields)) {
        $fromtime = $pars->{'fromtime'};
    }
    my $totime = "";
    if (exists($pars->{'totime'}) and !grep(/time/,@clearfields)) {
        $totime = $pars->{'totime'};
    }
    if ($totime eq "") {
        $totime = $fromtime;
    }
    if ($fromtime eq "") {
        $fromtime = $totime;
    }
    my $multiline_is_checked = "";
    my $multiline = "";
    if (exists($pars->{'multiline'})) {
        $multiline = $pars->{'multiline'};
    }
    if ($multiline eq "multiline") {
        $multiline_is_checked = "checked";
    }
    my @selected_categories = ();
    if (exists($pars->{'category'}) and !grep(/categories/,@clearfields)) {
        if (ref($pars->{'category'}) eq "ARRAY") {
            @selected_categories = @{$pars->{'category'}};
        } else {
            @selected_categories = ($pars->{'category'});
        }
    }
    my @selected_files = ();
    if (exists($pars->{'files'}) and !grep(/files/,@clearfields)) {
        if (ref($pars->{'files'}) eq "ARRAY") {
            @selected_files = @{$pars->{'files'}};
        } else {
            @selected_files = ($pars->{'files'});
        }
    }
    my @selected_levels = ();
    if (exists($pars->{'levels'}) and !grep(/levels/,@clearfields)) {
        if (ref($pars->{'levels'}) eq "ARRAY") {
            @selected_levels = @{$pars->{'levels'}};
        } else {
            @selected_levels = ($pars->{'levels'});
        }
    }
    if (exists($pars->{'msg'}) and !grep(/words/,@clearfields)) {
        $msg = $pars->{'msg'};
    }
    my @exclude_sentences = ();
    if (exists($pars->{'excludesents'}) and !grep(/excludes/,@clearfields)) {
        if (ref($pars->{'excludesents'}) eq "ARRAY") {
            @exclude_sentences = @{$pars->{'excludesents'}};
        } else {
            @exclude_sentences = split(/\n/m,$pars->{'excludesents'});
        }
    }
    my $optionstring = $multiline . " logfile=" . $log_filename . " ";
    if (exists($pars->{'summarydate'})) {
        $optionstring .= 'summarydate ';
        $fromdate = "";
        $todate = "";
        $get_result = 1;
    } elsif (exists($pars->{'summarylogger'})) {
        $optionstring .= 'summarylogger ';
        $get_result = 1;
    } elsif (exists($pars->{'summarylevel'})) {
        $optionstring .= 'summarylevel ';
        $get_result = 1;
    } elsif (exists($pars->{'summaryfile'})) {
        $optionstring .= 'summaryfile ';
        $files = "";
        $get_result = 1;
    } elsif (exists($pars->{'getmessages'})) {
        $get_result = 1;
    }
    if ($fromdate ne "") {
        $optionstring .= "from=" . $fromdate . " ";
    }
    if ($todate ne "") {
        $optionstring .= "to=" . $todate . " ";
    }
    if ($fromtime ne "") {
        $optionstring .= "timefrom=" . $fromtime . " ";
    }
    if ($totime ne "") {
        $optionstring .= "timeto=" . $totime . " ";
    }
    if (scalar @selected_categories > 0 and !exists($pars->{'summarylogger'})) {
        foreach my $cat (@selected_categories) {
            $optionstring .= "logger=" . $cat . " ";
        }
    }
    if (scalar @selected_files > 0 and !exists($pars->{'summaryfile'})) {
        foreach my $cat (@selected_files) {
            $optionstring .= "file=" . $cat . " ";
        }
    }
    if (scalar @selected_levels > 0 and !exists($pars->{'summarylevel'})) {
        foreach my $cat (@selected_levels) {
            $optionstring .= "level=" . $cat . " ";
        }
    }
    if ($msg ne "") {
        my @msgarray = split(/\s+/,$msg);
        foreach my $word (@msgarray) {
            my $cat = $word;
            $cat =~ s/=/EQLXYZ/mg;
            $optionstring .= "msg=" . $cat . " ";
        }
    }
    if (scalar @exclude_sentences > 0) {
        foreach my $exclude (@exclude_sentences) {
            my $exc = $exclude;
            $exc =~ s/ /SPCXYZ/mg;
            $exc =~ s/=/EQLXYZ/mg;
            $optionstring .= "exclude=" . $exc . " ";
        }
    }
    if ($get_result == 1) {
        $result = mmLogView::run($optionstring);
        $showresult = 1;
    }
    if (exists($pars->{'summarylogger'})) {
        my @resultarr = split(/\n/,$result);
        $result = "";
        foreach my $line (@resultarr) {
            my ($name,$count) = split(/\s+/,$line);
            my $checked = "";
            if (grep(/$name/,@selected_categories)) {
                $checked = "checked";
            }
            $categories .= '<tr><td>&nbsp;</td><td><input type="checkbox" ' . $checked .
                           ' name="category" value = "' .  $name . '" />' .  $name . "</td><td>" .
                            $count . '</td><td colspan="3">&nbsp;</td></tr>' . "\n";
        }
    } elsif (scalar @selected_categories > 0) {
        foreach my $cat (@selected_categories) {
            $categories .= '<tr><td>&nbsp;</td><td>' . $cat .
                           '<input type="hidden" checked name="category" value = "' . $cat .
                           '" /></td><td colspan ="4">&nbsp;</td></tr>' . "\n";
        }
    }
    if (exists($pars->{'summaryfile'})) {
        my @resultarr = split(/\n/,$result);
        $result = "";
        foreach my $line (@resultarr) {
            my ($name,$count) = split(/\s+/,$line);
            my $checked = "";
            if (grep(/$name/,@selected_files)) {
                $checked = "checked";
            }
            $files .= '<tr><td>&nbsp;</td><td><input type="checkbox" ' . $checked .
                           ' name="files" value = "' .  $name . '" />' .  $name . "</td><td>" .
                            $count . '</td><td colspan="3">&nbsp;</td></tr>' . "\n";
        }
    } elsif (scalar @selected_files > 0) {
        foreach my $cat (@selected_files) {
            $files .= '<tr><td>&nbsp;</td><td>' . $cat .
                           '<input type="hidden" checked name="files" value = "' . $cat .
                           '" /></td><td colspan ="4">&nbsp;</td></tr>' . "\n";
        }
    }
    if (exists($pars->{'summarylevel'})) {
        my @resultarr = split(/\n/,$result);
        $result = "";
        foreach my $line (@resultarr) {
            my ($name,$count) = split(/\s+/,$line);
            my $checked = "";
            if (grep(/$name/,@selected_levels)) {
                $checked = "checked";
            }
            $levels .= '<tr><td>&nbsp;</td><td><input type="checkbox" ' . $checked .
                           ' name="levels" value = "' .  $name . '" />' .  $name . "</td><td>" .
                            $count . '</td><td colspan="3">&nbsp;</td></tr>' . "\n";
        }
    } elsif (scalar @selected_levels > 0) {
        foreach my $cat (@selected_levels) {
            $levels .= '<tr><td>&nbsp;</td><td>' . $cat .
                           '<input type="hidden" checked name="levels" value = "' . $cat .
                           '" /></td><td colspan ="4">&nbsp;</td></tr>' . "\n";
        }
    }
    if (scalar @exclude_sentences > 0) {
        foreach my $exclude (@exclude_sentences) {
            $excludes .= $exclude . "\n";
        }
    }
    $c->stash(template => 'admin/showlog.tt');
    $c->stash(result => $result);
    $c->stash(optionstring => $optionstring);
    $c->stash(fromdate => $fromdate);
    $c->stash(todate => $todate);
    $c->stash(fromtime => $fromtime);
    $c->stash(totime => $totime);
    $c->stash(levels => $levels);
    $c->stash(categories => $categories);
    $c->stash(files => $files);
    $c->stash(msg => $msg);
    $c->stash(excludes => $excludes);
    $c->stash(showresult => $showresult);
    $c->stash(multiline_is_checked => $multiline_is_checked);
    close (TESTOUT);
}

=head1 AUTHOR

Egil StE<248>ren, E<lt>egils\@met.noE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
