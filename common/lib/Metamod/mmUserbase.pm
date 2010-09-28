#----------------------------------------------------------------------------
#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2010 met.no
#
#  Contact information:
#  Norwegian Meteorological Institute
#  Box 43 Blindern
#  0313 OSLO
#  NORWAY
#  email: Egil.Storen@met.no
#
#  This file is part of METAMOD
#
#  METAMOD is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  METAMOD is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with METAMOD; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#----------------------------------------------------------------------------
use strict;
package Metamod::mmUserbase;

=head1 NAME

Metamod::mmUserbase - Perl API against the METAMOD User Database

=head1 SYNOPSIS

 # Initialize an mmUserbase object and create a new user,
 # illustrating error handling:
 my $userbase = Metamod::mmUserbase->new();
 unless ($userbase->user_create('email_address','DIRKEY')) {
     if ($userbase->exception_is_error()) {
         print '   ERROR:   ' . $userbase->get_exception() . "\n";
     } else {
         print '   INFO:   ' . $userbase->get_exception() . "\n";
     }
 }
 $userbase->close();

 # Find an existing user:
 $userbase->user_find('email_address','DIRKEY');

 # Loop through all users:
 $userbase->user_first();
 do {
     my $name = $userbase->user_get('u_name');
     $userbase->user_put('u_name','Some Other Name');
 } until (! $userbase->user_next());

 # Many more possibilities. See the METHODS paragraph.

=head1 DESCRIPTION

API for accessing and updating the METAMOD User database. The database contains information
about users, datasets and files. A user owns one or more dataset, and a dataset owns one or
more file. The database also contain information that are connected to both dataset
and user, but not neccessarily the user that owns the dataset (the infoUDS table). 

The database will contain a complete inventory of the datasets that are also found in
the Metadata database (and the XML files that are sources for the Metadata database).
The Files table in the User database will not be complete. It is only intended for users
to look at the status of recently uploaded files.

=cut

#
# Class definition according to the "inside-out" method
# described in Perl Best Practices, chapter 15.
#
use Scalar::Util;
BEGIN { *ident = \&Scalar::Util::refaddr; }
use DBI;
use POSIX qw();
use Metamod::Config;
use constant TRUE => 1;
use constant FALSE => 0;
{

    #
    #     Attribute declarations
    #
    my %dbh;                        # Database handle
    my %pending_user_updates;       # TRUE if changes in current dataset are not written to the database
    my %pending_dataset_updates;    # TRUE if changes in current dataset are not written to
    my %pending_file_updates;       # TRUE if changes in current file are not written to the database
    my %pending_infoUDS_updates;    # TRUE if changes in current infoUDS record are not written to the database
    my %in_transaction;             # TRUE if a database transaction is in progress
    my %transaction_triggers;       # Array with SQL commands that will start a transaction (if not already started)
    my %user_array;                 # Hash with all user attributes of the current user
    my %file_array;                 # Hash with all file attributes of the current file
    my %allusers;                   # Array with u_id's for all users sorted on increasing u_id's
    my %current_user_ix;            # Index in the allusers array containing the u_id of current user
    my %user_ordinary_fields
        ;    # Commaseparated list of fields in the User database table (except u_id, a_id and u_email).
    my %file_ordinary_fields;    # Commaseparated list of fields in the File database table (except u_id and f_name).
    my %integer_fields;          # Array of field names of integer type (all tables)
    my %users_datasets
        ;              # Array with ds_id's for all datasets belonging to the current user. Sorted on increasing ds_id's
    my %users_files; # Array with f_name's for all files belonging to the current user.
    my %current_ds_ix; # Index in the users_datasets array representing the current dataset for the current user
    my %current_file_ix;      # Index in the users_files array representing the current file for the current user
    my %current_ds_id;        # ds_id of the current dataset for the current user
    my %current_ds_name;      # ds_name of the current dataset for the current user
    my %current_ds_uid;       # U_id of user owning the current dataset
    my %dataset_infotypes;    # Array with information types accepted by the system
    my %infoUDS_rows;         # Array with I_id's corresponding to the current set of InfoUDS rows. For deleted rows,
                              # the I_id is substituted with NULL
    my %infoUDS_row_ix;       # Index into $infoUDS_rows corresponding to the current InfoUDS row
    my %infoUDS_record;       # Hash with all fields in the current InfoUDS row
    my %infoUDS_fields;       # Comma-separated list of all fields in the infoUDS table
    my %infoUDS_uid;          # U_id of user connected to the current set of InfoUDS rows. = -1 if the current set of
                              # InfoUDS row are only connected to a dataset
    my %infoUDS_dsid;         # DS_id of dataset connected to the current set of InfoUDS rows. -1 if the current set of
                              # InfoUDS row are only connected to a user
    my %infoUDS_itype;        # Info_type for the current set of InfoUDS rows
    my %infoUDS_infotypes;    # Array of information types accepted by the system
    my %exception_string;     # Text string containing an error message or informational message
    my %exception_level;      # Number representing the current exception:
                              # 0 : Normal info, like "No more users" intended to close a loop;
                              # 1 : Error
    my %selected_count;       # Number of rows selected by the latest SELECT query
    my %select_buffer;        # Buffer containing result of last SELECT select statement (ref to array of hash refs)

=head1 METHODS

=over

=cut

    #
    #     Constructor function:
    #
    sub new {
        my $class = shift;
        my $self  = bless \do { my $anon_scalar }, $class;
        my $ident = ident($self);

        #
        #        Set attribute values
        #
        my $config = new Metamod::Config();
        my $dbname = $config->get("USERBASE_NAME");
        my $user   = $config->get("PG_ADMIN_USER");
        $dbh{$ident} =
            DBI->connect( "dbi:Pg:dbname=" . $dbname . " " . $config->get("PG_CONNECTSTRING_PERL"), $user, "" ) or die $DBI::errstr;
        $pending_user_updates{$ident}    = FALSE();
        $pending_dataset_updates{$ident} = FALSE();
        $pending_file_updates{$ident}    = FALSE();
        $pending_infoUDS_updates{$ident} = FALSE();
        $in_transaction{$ident}          = FALSE();
        $transaction_triggers{$ident}    = [ 'INSERT', 'UPDATE', 'DELETE' ];
        $user_ordinary_fields{$ident}    = "u_name, u_password, u_loginname, u_institution, u_telephone, u_session";
        $dataset_infotypes{$ident}       = [ 'DSKEY', 'LOCATION', 'CATALOG', 'WMS_URL', 'WMS_XML' ];
        $infoUDS_infotypes{$ident}       = ['SUBSCRIPTION_XML'];
        $infoUDS_fields{$ident}          = "i_id, u_id, ds_id, i_type, i_content";
        $infoUDS_uid{$ident}             = -1;
        $infoUDS_dsid{$ident}            = -1;
        $file_ordinary_fields{$ident}    = "f_timestamp, f_size, f_status, f_errurl";
        $integer_fields{$ident}          = [ 'u_id', 'ds_id', 'i_id' ];
        $exception_string{$ident}        = "";
        $exception_level{$ident}         = 0;
        return $self;
    }

    #
    #     Method: _pg_escape_string
    #
    sub _pg_escape_string {
        my $self   = shift;
        my $ident  = ident($self);
        my $string = shift;
        $string =~ s/\'/\'\'/mg;
        return $string;
    }

    #
    #     Method: _note_exception
    #     Set the internal error text string
    #
    sub _note_exception {
        my $self  = shift;
        my $ident = ident($self);
        $exception_level{$ident}  = shift;
        $exception_string{$ident} = shift;
        return TRUE();
    }

    #
    #     Method: _get_SQL_value_list
    #     Construct a value list to be used in an SQL INSERT statement corresponding to
    #     a list of field names. The values are taken from the $value_array. Except for integer
    #     fields, apostrophes are added around each value. Enclosinq paranthesis are not added
    #     around the resulting list. String fields are escaped using _pg_escape_string that
    #     changes single apostrophes in the value into two concecutive apostrophes. The database
    #     system will convert these double apostrophes back to single before the values are used
    #     in the database (SQL standard).
    #
    #     $value_array is either reference to an array, or ref to hash with the field names used as hash keys.
    #
    sub _get_SQL_value_list {
        my $self           = shift;
        my $ident          = ident($self);
        my $integer_fields = $integer_fields{$ident};
        my $list_of_fields = shift;
        my $value_array    = shift;

        # print "FROM _get_SQL_value_list: list_of_fields='$list_of_fields'\n";
        my @fieldnames = split( /\s*,\s*/, $list_of_fields );
        my @values = ();
        if ( defined($value_array) ) {

            # print "FROM _get_SQL_value_list: value_array defined: " . ref($value_array) . "\n";
            my $i1 = 0;
            foreach my $field (@fieldnames) {
                my $val;
                if ( ref($value_array) eq "ARRAY" and $i1 < scalar @{$value_array} ) {
                    $val = $value_array->[$i1];
                } elsif ( defined( $value_array->{$field} ) ) {
                    $val = $value_array->{$field};
                } else {
                    push( @values, "NULL" );
                }
                if ( defined($val) ) {

                    # print "FROM _get_SQL_value_list: FIELD=$field, VAL=$val\n";
                    if ( grep( $_ eq $field, @{$integer_fields} ) ) {
                        push( @values, $val );
                    } else {
                        push( @values, "'" . $self->_pg_escape_string($val) . "'" );
                    }
                }
                $i1++;
            }
        } else {
            foreach my $field (@fieldnames) {
                push( @values, "NULL" );
            }
        }
        my $valuelist = join( ", ", @values );

        # print "FROM _get_SQL_value_list: Returning valuelist='$valuelist'\n";
        return $valuelist;
    }

    #
    #     Method: _get_SQL_WHERE_clause
    #     Construct a safe SQL WHERE clause combining equality conditions with AND.
    #     Each field in $list_of_fields (commaseparated string) is paired with a corresponding
    #     value in the $value_array, which is a reference to either a hash or an array. The pairing
    #     is done either by positional indices in
    #     @{$value_array}, or by using the field name as index in %{value_array}. String values are
    #     escaped using _pg_escape_string and surrounded by single apostrophes.
    #
    sub _get_SQL_WHERE_clause {

        # print "FROM _get_SQL_WHERE_clause: start\n";
        my $self           = shift;
        my $ident          = ident($self);
        my $list_of_fields = shift;
        my $value_array    = shift;
        my $integer_fields = $integer_fields{$ident};
        my @fieldnames     = split( /\s*,\s*/, $list_of_fields );
        my $where_clause   = 'WHERE ';
        my $i1             = 0;
        my $fieldcount     = scalar @fieldnames;

        # print "FROM _get_SQL_WHERE_clause: list_of_fields: $list_of_fields\n";
        foreach my $field (@fieldnames) {
            my $val = 'NULL';
            if ( $i1 > 0 and $i1 < $fieldcount ) {
                $where_clause .= ' AND ';
            }
            if ( ref($value_array) eq "ARRAY" and $i1 < scalar @{$value_array} ) {
                $val = $value_array->[$i1];
            } elsif ( ref($value_array) eq "HASH"
                and exists( $value_array->{$field} )
                and defined( $value_array->{$field} ) ) {
                $val = $value_array->{$field};
            }
            my $comparision_operator;
            if ( $val eq "NULL" ) {
                $comparision_operator = ' IS ';
            } else {
                $comparision_operator = ' = ';
            }
            if ( !grep( $_ eq $field, @{$integer_fields} ) and $val ne "NULL" ) {
                $val = "'" . $self->_pg_escape_string($val) . "'";
            }
            $where_clause .= $field . $comparision_operator . $val;
            $i1++;
        }

        # print "FROM _get_SQL_WHERE_clause: returning: $where_clause\n";
        return $where_clause;
    }

    #
    #     Method: _do_query
    #     Make a database query and get error string on error
    #     If the query is a SELECT statement, the row count value will be saved in
    #     the attribute %selected_count, and the actual rows will be saved in %select_buffer.
    #
    sub _do_query {

        # print "FROM _do_query: start\n";
        my $self                 = shift;
        my $ident                = ident($self);
        my $sql_query            = shift;
        my $transaction_triggers = $transaction_triggers{$ident};
        my $in_transaction       = $in_transaction{$ident};
        my $dbh                  = $dbh{$ident};
        my $sql_command          = "";
        if ( $sql_query =~ /^(\S+)\b/ ) {
            $sql_command = $1;    # First matching ()-expression
        }
        my $pg_error;

        # print "FROM _do_query: sql_query='$sql_query'\n";
        if ( grep( $_ eq $sql_command, @{$transaction_triggers} ) and !$in_transaction ) {
            if ( !$dbh->begin_work ) {
                $pg_error = $dbh->errstr;
                $self->_note_exception( 1, "Failed to begin transaction. " . $pg_error );
                return FALSE();
            }

            # print "FROM _do_query: Started transaction\n";
            $in_transaction{$ident} = TRUE();
        }
        my $sth = $dbh->prepare_cached($sql_query);

        # print "FROM _do_query: prepare_cached finished\n";
        my $sth_returned = $sth->execute();

        #      if (!$sth->execute())
        if ( !$sth_returned ) {
            $pg_error = $sth->errstr;
            $self->_note_exception( 1, "DBI execute method returns FALSE on '" . $sql_query . "'. " . $pg_error );
            return FALSE();
        }

        # print "FROM _do_query: execute finished, returned: $sth_returned\n";
        if ( $sql_command eq "SELECT" || ( $sql_command eq "INSERT" && index( $sql_query, ' returning ' ) > 0 ) ) {

            #
            #        Fetch the rows to an array of hash refs. Each hash ref represents one row, and
            #        the hash keys are the column names. Return a reference to the array.
            #
            # print "FROM _do_query: about to fetchall_arrayref\n";
            my $select_buffer = $sth->fetchall_arrayref( {} );
            my $errcode = $sth->err;
            if ( defined($errcode) ) {
                $self->_note_exception( 1,
                    "_do_query: fetchall_arrayref did not succeed on query '" . $sql_query . "': " . $sth->errstr );
                return FALSE();
            }

            # print "FROM _do_query: fetchall_arrayref returned " . scalar @{$select_buffer} . " rows\n";
            $selected_count{$ident} = scalar @{$select_buffer};
            $select_buffer{$ident}  = $select_buffer;
            return TRUE();
        }
        return $sth;
    }

    #
    #     Method: _fetch_row_as_hashref
    #
    sub _fetch_row_as_hashref {
        my $self           = shift;
        my $ident          = ident($self);
        my $rownum         = shift;
        my $selected_count = $selected_count{$ident};
        my $select_buffer  = $select_buffer{$ident};
        if ( $rownum < 0 or $rownum >= $selected_count ) {
            $self->_note_exception( 1, "Row number outside allowed range" );
            return FALSE();
        }
        return $select_buffer->[$rownum];
    }

=item get_exception()

Return value: A text string explaining the last exception encountered.

=cut

    sub get_exception {
        my $self  = shift;
        my $ident = ident($self);
        return $exception_string{$ident};
    }

=item exception_is_error()

Return value: TRUE if last exception was an error (and not just an info like "no more users").
Othervise FALSE.

=cut

    sub exception_is_error {
        my $self  = shift;
        my $ident = ident($self);
        return ( $exception_level{$ident} == 1 );
    }

    #
    #     Method: _delete_attributes
    #
    sub _delete_attributes {
        my $self  = shift;
        my $ident = ident($self);
        delete $dbh{$ident};
        delete $pending_user_updates{$ident};
        delete $pending_dataset_updates{$ident};
        delete $pending_file_updates{$ident};
        delete $pending_infoUDS_updates{$ident};
        delete $in_transaction{$ident};
        delete $transaction_triggers{$ident};
        delete $user_array{$ident};
        delete $file_array{$ident};
        delete $allusers{$ident};
        delete $current_user_ix{$ident};
        delete $user_ordinary_fields{$ident};
        delete $file_ordinary_fields{$ident};
        delete $integer_fields{$ident};
        delete $users_datasets{$ident};
        delete $users_files{$ident};
        delete $current_ds_ix{$ident};
        delete $current_file_ix{$ident};
        delete $current_ds_id{$ident};
        delete $current_ds_name{$ident};
        delete $current_ds_uid{$ident};
        delete $dataset_infotypes{$ident};
        delete $infoUDS_rows{$ident};
        delete $infoUDS_row_ix{$ident};
        delete $infoUDS_record{$ident};
        delete $infoUDS_fields{$ident};
        delete $infoUDS_uid{$ident};
        delete $infoUDS_dsid{$ident};
        delete $infoUDS_itype{$ident};
        delete $exception_string{$ident};
        delete $exception_level{$ident};
        delete $selected_count{$ident};
        delete $select_buffer{$ident};
    }

=item close()

Submit any pending changes to the database, then disconnect the database handle.
Return value: TRUE on success, FALSE on error.

=cut

    sub close {

        # print "FROM close: start\n";
        my $self                 = shift;
        my $ident                = ident($self);
        my $pending_file_updates = $pending_file_updates{$ident};
        my $pending_user_updates = $pending_user_updates{$ident};
        my $in_transaction       = $in_transaction{$ident};
        my $dbh                  = $dbh{$ident};
        if ($pending_file_updates) {
            if ( !( $self->_update_file() ) ) {
                return FALSE();
            }
        }

        # print "FROM close: passed pending_file_updates\n";
        if ($pending_user_updates) {
            if ( !( $self->_update_user() ) ) {
                return FALSE();
            }
        }

        # print "FROM close: passed pending_user_updates\n";
        if ($in_transaction) {

            # print "FROM close: ready to run COMMIT\n";
            if ( !$dbh->commit ) {
                my $pg_error = $dbh->errstr;
                $self->_note_exception( 1, "Failed to commit transaction. " . $pg_error );
                return FALSE();
            }
            $in_transaction{$ident} = FALSE();
        }

        # print "FROM close: disconnecting\n";
        $dbh->disconnect;

        # print "FROM close: deleting attributes\n";
        $self->_delete_attributes();
        return TRUE();
    }

=item revert()

Revert any changes to the database made by this Userbase object. Disconnect the database handle.
Return value: TRUE on success, FALSE on error.

=cut

    sub revert {
        my $self           = shift;
        my $ident          = ident($self);
        my $in_transaction = $in_transaction{$ident};
        my $dbh            = $dbh{$ident};
        if ($in_transaction) {
            if ( !$dbh->rollback ) {
                my $pg_error = $dbh->errstr;
                $self->_note_exception( 1, "Failed to rollback transaction. " . $pg_error );
                return FALSE();
            }
            $in_transaction{$ident} = FALSE();
        }
        $dbh->disconnect;
        $self->_delete_attributes();
        return TRUE();
    }

    #
    #     Method: _pg_num_rows
    #
    sub _pg_num_rows {
        my $self  = shift;
        my $ident = ident($self);
        return $selected_count{$ident};
    }

    #
    #     Method: _update_user
    #     Write pending changes to current user to the database
    #
    sub _update_user {

        # print "FROM _update_user: start\n";
        my $self                 = shift;
        my $ident                = ident($self);
        my $user_array           = $user_array{$ident};
        my $user_ordinary_fields = $user_ordinary_fields{$ident};
        my $dbh                  = $dbh{$ident};
        my $sql1 = "SELECT u_id FROM UserTable " . $self->_get_SQL_WHERE_clause( 'u_email, a_id', $user_array );

        # print "FROM _update_user: sql1=$sql1\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();

        # print "FROM _update_user: rowcount=$rowcount\n";
        if ( $rowcount > 1 ) {
            $self->_note_exception( 1,
                      "Multiple users ("
                    . $rowcount
                    . ") with same u_email= "
                    . $user_array->{"u_email"}
                    . " and a_id= '"
                    . $user_array->{"a_id"}
                    . "'" );
            return FALSE();
        }
        my $valuelist;
        my $sql2;
        if ( $rowcount == 0 ) {
            $valuelist = $self->_get_SQL_value_list( "a_id, u_email, " . $user_ordinary_fields, $user_array );
            $sql2 =
                  "INSERT INTO UserTable (a_id, u_email, "
                . $user_ordinary_fields . ")\n"
                . "   VALUES ("
                . $valuelist . ")";

            # print "FROM _update_user: sql2=$sql2\n";
            if ( !$self->_do_query($sql2) ) {
                return FALSE();
            }
        } else {
            $valuelist = $self->_get_SQL_value_list( $user_ordinary_fields, $user_array );

            # print "FROM _update_user: valuelist=$valuelist\n";
            $sql2 =
                  "UPDATE UserTable " . "SET ("
                . $user_ordinary_fields . ") = " . "("
                . $valuelist . ") "
                . $self->_get_SQL_WHERE_clause( 'u_email, a_id', $user_array );

            # print "FROM _update_user: sql2=$sql2\n";
            if ( !$self->_do_query($sql2) ) {
                return FALSE();
            }
        }
        $pending_user_updates{$ident} = FALSE();

        # print "FROM _update_user: Normal return\n";
        return TRUE();
    }

=item user_find($email_address,$application_id)

Search for an existing user in the database and make him/her the current user.

IN: User E-mail address, application id (a_id).

Return value: TRUE on success, FALSE on error.

=cut

    sub user_find {
        my $self                 = shift;
        my $ident                = ident($self);
        my $email_address        = shift;
        my $application_id       = shift;
        my $pending_user_updates = $pending_user_updates{$ident};
        my $user_ordinary_fields = $user_ordinary_fields{$ident};
        if ($pending_user_updates) {
            if ( !$self->_update_user() ) {
                return FALSE();
            }
        }
        my $sql1 =
              "SELECT u_id, "
            . $user_ordinary_fields
            . " FROM UserTable "
            . $self->_get_SQL_WHERE_clause( 'u_email, a_id', [ $email_address, $application_id ] );
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 0, "No such user" );
            return FALSE();
        }
        if ( $rowcount != 1 ) {
            $self->_note_exception( 1,
                      "Multiple users ("
                    . $rowcount
                    . ") with same u_email= "
                    . $email_address
                    . " and a_id= "
                    . $application_id );
            return FALSE();
        }
        my $user_array = $self->_fetch_row_as_hashref(0);
        if ( !$user_array ) {
            return FALSE();
        }
        $user_array->{"u_email"} = $email_address;
        $user_array->{"a_id"}    = $application_id;
        $user_array{$ident}      = $user_array;
        return TRUE();
    }

=item user_lfind($login_name,$application_id)

Search for an existing user in the database and make him/her the current user.

IN: User login name, application id (a_id).

Return value: TRUE on success, FALSE on error.

=cut

    sub user_lfind {
        my $self                 = shift;
        my $ident                = ident($self);
        my $login_name           = shift;
        my $application_id       = shift;
        my $pending_user_updates = $pending_user_updates{$ident};
        my $user_ordinary_fields = $user_ordinary_fields{$ident};
        if ($pending_user_updates) {
            if ( !$self->_update_user() ) {
                return FALSE();
            }
        }
        my $sql1 =
              "SELECT u_id, u_email, "
            . $user_ordinary_fields
            . " FROM UserTable "
            . $self->_get_SQL_WHERE_clause( 'u_loginname, a_id', [ $login_name, $application_id ] );
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 0, "No such user" );
            return FALSE();
        }
        if ( $rowcount != 1 ) {
            $self->_note_exception( 1,
                      "Multiple users ("
                    . $rowcount
                    . ") with same u_loginname= "
                    . $login_name
                    . " and a_id= "
                    . $application_id );
            return FALSE();
        }
        my $user_array = $self->_fetch_row_as_hashref(0);
        if ( !$user_array ) {
            return FALSE();
        }
        $user_array->{"a_id"}    = $application_id;
        $user_array{$ident}      = $user_array;
        return TRUE();
    }

=item user_create(email_address,application_id)

IN: User E-mail address, application id (a_id).

Create a new user and make it the current user. Initially, the value of the mandatory 
U_loginname field will be set to the E-mail address, but this can be changed using the
user_put method.

Return value: TRUE on success, FALSE on error.

=cut

    sub user_create {
        my $self                 = shift;
        my $ident                = ident($self);
        my $email_address        = shift;
        my $application_id       = shift;
        my $pending_user_updates = $pending_user_updates{$ident};
        my $sql_select_uid       = "SELECT u_id FROM UserTable "
            . $self->_get_SQL_WHERE_clause( 'u_email, a_id', [ $email_address, $application_id ] );
        if ( !$self->_do_query($sql_select_uid) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount > 0 ) {
            $self->_note_exception( 0, "User already exists in database" );
            return FALSE();
        }
        if ($pending_user_updates) {
            if ( !$self->_update_user() ) {
                return FALSE();
            }
        }

        #
        #        Initialize the new user array and insert into UserTable:
        #
        my $user_array = {};
        $user_array->{"u_email"} = $email_address;
        $user_array->{"u_loginname"} = $email_address;
        $user_array->{"a_id"}    = $application_id;
        my $valuelist = $self->_get_SQL_value_list( "a_id, u_email, u_loginname", $user_array );
        my $sql2 = "INSERT INTO UserTable (a_id, u_email, u_loginname) VALUES (" . $valuelist . ")";
        if ( !$self->_do_query($sql2) ) {
            return FALSE();
        }
        if ( !$self->_do_query($sql_select_uid) ) {
            return FALSE();
        }
        my $rowcount2 = $self->_pg_num_rows();
        if ( $rowcount2 == 0 ) {
            $self->_note_exception( 1,
                "Could not find newly created user ($application_id / $email_address) in database" );
            return FALSE();
        }
        my $href = $self->_fetch_row_as_hashref(0);
        $user_array->{"u_id"} = $href->{"u_id"};
        $user_array{$ident} = $user_array;
        return TRUE();
    }

=item user_put($property,$value)

Set user properties for the current user.

IN: Property name (one of 'u_name', 'u_password', 'u_institution', 'u_telephone', 'u_session'),
property value

Return value: TRUE on success, FALSE on error.

=cut

    sub user_put {
        my $self                 = shift;
        my $ident                = ident($self);
        my $property             = shift;
        my $value                = shift;
        my $user_array           = $user_array{$ident};
        my $user_ordinary_fields = $user_ordinary_fields{$ident};
        if ( !defined($user_array) ) {
            $self->_note_exception( 1, "No current user" );
            return FALSE();
        }
        my @fieldnames = split( /\s*,\s*/, $user_ordinary_fields );
        if ( !grep( $_ eq $property, @fieldnames ) ) {
            $self->_note_exception( 1, "Property '" . $property . "' not known" );
            return FALSE();
        }
        $user_array->{$property} = $value;
        $pending_user_updates{$ident} = TRUE();
        return TRUE();
    }

=item user_get($property)

Get user properties for the current user.

IN: Property name (one of 'u_id', 'u_email', 'a_id' 'u_name', 'u_password', 'u_loginname',
'u_institution', 'u_telephone', 'u_session')

Return value: Property value on success, FALSE on error.

=cut

    sub user_get {
        my $self                 = shift;
        my $ident                = ident($self);
        my $property             = shift;
        my $user_array           = $user_array{$ident};
        my $user_ordinary_fields = $user_ordinary_fields{$ident};
        my @fieldnames           = split( /\s*,\s*/, 'u_id, u_email, a_id, ' . $user_ordinary_fields );
        if ( !grep( $_ eq $property, @fieldnames ) ) {
            $self->_note_exception( 1, "Property '" . $property . "' not known" );
            return FALSE();
        }
        if ( defined( $user_array->{$property} ) ) {
            return $user_array->{$property};
        } else {
            $self->_note_exception( 1, "Property '" . $property . "' not set" );
            return FALSE();
        }
    }

=item user_first()

Make the first user in the database the current user.

Return value: TRUE on success, FALSE on error / no user in database.

=cut

    sub user_first {
        my $self                 = shift;
        my $ident                = ident($self);
        my $pending_user_updates = $pending_user_updates{$ident};
        my $user_ordinary_fields = $user_ordinary_fields{$ident};
        if ($pending_user_updates) {
            if ( !$self->_update_user() ) {
                return FALSE();
            }
        }
        my $allusers = [];
        my $sql1     = "SELECT u_id FROM UserTable ORDER BY u_id\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        my $i1       = 0;
        while ( $i1 < $rowcount ) {
            my $href = $self->_fetch_row_as_hashref($i1);
            $allusers->[$i1] = $href->{"u_id"};
            $i1++;
        }
        my $sql2 =
              "SELECT u_id, a_id, u_email, "
            . $user_ordinary_fields
            . " FROM UserTable WHERE u_id = "
            . $allusers->[0] . "\n";
        if ( !$self->_do_query($sql2) ) {
            return FALSE();
        }
        my $user_array = $self->_fetch_row_as_hashref(0);
        if ( !$user_array ) {
            return FALSE();
        }
        $user_array{$ident}      = $user_array;
        $allusers{$ident}        = $allusers;
        $current_user_ix{$ident} = 0;
        return TRUE();
    }

=item user_next()

Make the next user in the database the current one.

Return value: TRUE on success, FALSE on error / already last user.

=cut

    sub user_next {

        # print "FROM user_next: start\n";
        my $self                 = shift;
        my $ident                = ident($self);
        my $pending_user_updates = $pending_user_updates{$ident};
        my $user_ordinary_fields = $user_ordinary_fields{$ident};
        my $current_user_ix      = $current_user_ix{$ident};
        my $allusers             = $allusers{$ident};
        if ($pending_user_updates) {
            if ( !$self->_update_user() ) {
                return FALSE();
            }
        }
        my $ix = $current_user_ix + 1;

        # print "FROM user_next: ix=$ix\n";
        if ( $ix >= scalar @{$allusers} ) {

            # print "FROM user_next: No more users in the database\n";
            $self->_note_exception( 0, "No more users in the database" );
            return FALSE();
        }
        my $uid = $allusers->[$ix];
        my $sql1 =
            "SELECT u_id, a_id, u_email, " . $user_ordinary_fields . " FROM UserTable WHERE u_id = " . $uid . "\n";

        # print "FROM user_next: Make query: $sql1\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();

        # print "FROM user_next: Rows found: $rowcount\n";
        if ( $rowcount == 0 ) {
            $self->_note_exception( 1, "User with u_id = " . $uid . " not found in the database" );
            return FALSE();
        }
        my $user_array = $self->_fetch_row_as_hashref(0);
        if ( !$user_array ) {

            # print "FROM user_next: _fetch_row_as_hashref did not succeed\n";
            return FALSE();
        }
        $user_array{$ident}      = $user_array;
        $current_user_ix{$ident} = $ix;

        # print "FROM user_next: Returning TRUE=TRUE()\n";
        return TRUE();
    }

=item user_isync()

Make the user corresponding to the current infoUDS-row (see below) the current user.

Return value: TRUE on success, FALSE on error.

=cut

    sub user_isync {

        # print "FROM user_isync: 1\n";
        my $self                 = shift;
        my $ident                = ident($self);
        my $pending_user_updates = $pending_user_updates{$ident};
        my $user_ordinary_fields = $user_ordinary_fields{$ident};
        my $infoUDS_record       = $infoUDS_record{$ident};
        if ($pending_user_updates) {
            if ( !$self->_update_user() ) {
                return FALSE();
            }
        }

        # print "FROM user_isync: 2\n";
        if ( !defined($infoUDS_record) ) {
            $self->_note_exception( 1, "No current infoUDS record" );
            return FALSE();
        }

        # print "FROM user_isync: 3\n";
        if ( !defined( $infoUDS_record->{"u_id"} ) ) {
            $self->_note_exception( 1, "The current infoUDS record have no u_id field" );
            return FALSE();
        }

        # print "FROM user_isync: 4\n";
        my $uid = $infoUDS_record->{"u_id"};
        my $sql1 =
            "SELECT u_id, a_id, u_email, " . $user_ordinary_fields . " FROM UserTable WHERE u_id = " . $uid . "\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }

        # print "FROM user_isync: 5\n";
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 1, "User with u_id = " . $uid . " not found in the database" );
            return FALSE();
        }

        # print "FROM user_isync: 6\n";
        my $user_array = $self->_fetch_row_as_hashref(0);
        if ( !$user_array ) {
            return FALSE();
        }

        # print "FROM user_isync: 7\n";
        $user_array{$ident} = $user_array;

        # print "FROM user_isync: 8\n";
        return TRUE();
    }

=item user_dsync()

Make the user owning the current dataset the current user.

Return value: TRUE on success, FALSE on error.

=cut

    sub user_dsync {
        my $self                 = shift;
        my $ident                = ident($self);
        my $pending_user_updates = $pending_user_updates{$ident};
        my $user_ordinary_fields = $user_ordinary_fields{$ident};
        my $current_ds_uid       = $current_ds_uid{$ident};
        if ($pending_user_updates) {
            if ( !$self->_update_user() ) {
                return FALSE();
            }
        }
        my $sql1 =
              "SELECT u_id, a_id, u_email, "
            . $user_ordinary_fields
            . " FROM UserTable WHERE u_id = "
            . $current_ds_uid . "\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 1,
                      "User with u_id = "
                    . $current_ds_uid
                    . " not found in the database. "
                    . "But the DataSet table contains an entry with this u_id." );
            return FALSE();
        }
        my $user_array = $self->_fetch_row_as_hashref(0);
        if ( !$user_array ) {
            return FALSE();
        }
        $user_array{$ident} = $user_array;
        return TRUE();
    }

=item dset_create($dataset_name,$dataset_key)

Create a new dataset and make it the current dataset. The current user will be
the owner of the new dataset.

IN: Dataset name, dataset key.

Return value: TRUE on success, FALSE on error / dataset already exists.

=cut

    sub dset_create {
        my $self         = shift;
        my $ident        = ident($self);
        my $dataset_name = shift;
        my $dataset_key  = shift;
        my $user_array   = $user_array{$ident};
        if ( !defined($user_array) ) {
            $self->_note_exception( 1, "No current user" );
            return FALSE();
        }
        my $sql_ds = "SELECT ds_id FROM DataSet "
            . $self->_get_SQL_WHERE_clause( 'ds_name, a_id', [ $dataset_name, $user_array->{"a_id"} ] );
        if ( !$self->_do_query($sql_ds) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount > 0 ) {
            $self->_note_exception( 0, "DataSet " . $dataset_name . " already exists in database" );
            return FALSE();
        }
        my $sql1 =
              "INSERT INTO DataSet (u_id, a_id, ds_name)\n"
            . "   VALUES ("
            . $self->_get_SQL_value_list( 'u_id, a_id', $user_array ) . ", '"
            . $self->_pg_escape_string($dataset_name) . "')";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        if ( !$self->_do_query($sql_ds) ) {
            return FALSE();
        }
        my $href = $self->_fetch_row_as_hashref(0);
        $current_ds_id{$ident}   = $href->{"ds_id"};
        $current_ds_name{$ident} = $dataset_name;
        $current_ds_uid{$ident}  = $user_array->{"u_id"};
        if ( !$self->dset_put( "DSKEY", $dataset_key ) ) {
            return FALSE();
        }
        return TRUE();
    }

=item dset_find($applic_id,$dataset_name)

Find a dataset in the database and make it the current dataset.

IN: Application id, dataset name.

Return value: TRUE on success, FALSE on error / no such dataset.

=cut

    sub dset_find {
        my $self         = shift;
        my $ident        = ident($self);
        my $applic_id    = shift;
        my $dataset_name = shift;
        my $sql1         = "SELECT ds_id, u_id FROM DataSet "
            . $self->_get_SQL_WHERE_clause( 'ds_name, a_id', [ $dataset_name, $applic_id ] );
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount != 1 ) {
            $self->_note_exception( 0, "DataSet " . $applic_id . " / " . $dataset_name . " not found" );
            return FALSE();
        }
        my $href = $self->_fetch_row_as_hashref(0);
        $current_ds_id{$ident}   = $href->{"ds_id"};
        $current_ds_uid{$ident}  = $href->{"u_id"};
        $current_ds_name{$ident} = $dataset_name;
        return TRUE();
    }

=item dset_first()

Make the first dataset (owned by the current user) the current dataset.

Return value: TRUE on success, FALSE on error / no dataset owned by the current user.

=cut

    #     Get the first dataset owned by the current user in ds_id order. This method
    #     updates the internal 'users_datasets' array that contains the ds_id's of all datasets
    #     owned by the current user.
    #
    sub dset_first {
        my $self       = shift;
        my $ident      = ident($self);
        my $user_array = $user_array{$ident};
        if ( !defined($user_array) ) {
            $self->_note_exception( 1, "No current user" );
            return FALSE();
        }
        my $users_datasets = [];
        my $sql1           = "SELECT ds_id FROM DataSet WHERE u_id = " . $user_array->{"u_id"} . " ORDER BY ds_id\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 0, "No datasets found for current user" );
            return FALSE();
        }
        my $i1 = 0;
        while ( $i1 < $rowcount ) {
            my $href = $self->_fetch_row_as_hashref($i1);
            $users_datasets->[$i1] = $href->{"ds_id"};
            $i1++;
        }
        my $sql2 = "SELECT ds_name FROM DataSet WHERE ds_id = " . $users_datasets->[0] . "\n";
        if ( !$self->_do_query($sql2) ) {
            return FALSE();
        }
        my $href2 = $self->_fetch_row_as_hashref(0);
        $current_ds_name{$ident} = $href2->{"ds_name"};
        $current_ds_ix{$ident}   = 0;
        $current_ds_id{$ident}   = $users_datasets->[0];
        $current_ds_uid{$ident}  = $user_array->{"u_id"};
        $users_datasets{$ident}  = $users_datasets;
        return TRUE();
    }

=item dset_next()

Make the next dataset (owned by the current user) the current dataset.

Return value: TRUE on success, FALSE on error / no more datasets.

=cut

    sub dset_next {
        my $self           = shift;
        my $ident          = ident($self);
        my $user_array     = $user_array{$ident};
        my $users_datasets = $users_datasets{$ident};
        my $current_ds_ix  = $current_ds_ix{$ident};
        if ( !defined($users_datasets) ) {
            $self->_note_exception( 1, "No current set. Dset_first not called?" );
            return FALSE();
        }
        my $ix = $current_ds_ix + 1;
        if ( $ix >= scalar @{$users_datasets} ) {
            $self->_note_exception( 0, "No more datasets found for current user" );
            return FALSE();
        }
        my $dsid = $users_datasets->[$ix];
        my $sql1 = "SELECT ds_name FROM DataSet WHERE ds_id = " . $dsid . "\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 1, "Expected another dataset, but found no datasets with ds_id = " . $dsid );
            return FALSE();
        }
        my $href = $self->_fetch_row_as_hashref(0);
        $current_ds_name{$ident} = $href->{"ds_name"};
        $current_ds_ix{$ident}   = $ix;
        $current_ds_id{$ident}   = $dsid;
        return TRUE();
    }

=item dset_isync()

Make the dataset corresponding to the current infoUDS-row (see below) the current dataset.

Return value: TRUE on success, FALSE on error.

=cut

    sub dset_isync {
        my $self                 = shift;
        my $ident                = ident($self);
        my $user_ordinary_fields = $user_ordinary_fields{$ident};
        my $infoUDS_record       = $infoUDS_record{$ident};
        if ( !defined($infoUDS_record) ) {
            $self->_note_exception( 1, "No current infoUDS record" );
            return FALSE();
        }
        if ( !defined( $infoUDS_record->{"ds_id"} ) ) {
            $self->_note_exception( 1, "The current infoUDS record have no ds_id field" );
            return FALSE();
        }
        my $dsid = $infoUDS_record->{"ds_id"};
        my $sql1 = "SELECT ds_name, u_id FROM DataSet WHERE ds_id = " . $dsid . "\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 1, "Found no datasets with ds_id = " . $dsid );
            return FALSE();
        }
        my $href = $self->_fetch_row_as_hashref(0);
        if ( !$href ) {
            return FALSE();
        }
        $current_ds_name{$ident} = $href->{"ds_name"};
        $current_ds_uid{$ident}  = $href->{"u_id"};
        $current_ds_id{$ident}   = $dsid;
        return TRUE();
    }

=item dset_put($info_type,$info_content)

Add or replace content fields in the current dataset.

IN: Information type (I_type), value of I_content field (single entity or XML).

Return value: TRUE on success, FALSE on error.

=cut

    sub dset_put {
        my $self              = shift;
        my $ident             = ident($self);
        my $info_type         = shift;
        my $info_content      = shift;
        my $current_ds_id     = $current_ds_id{$ident};
        my $dataset_infotypes = $dataset_infotypes{$ident};
        if ( !defined($current_ds_id) ) {
            $self->_note_exception( 1, "No current dataset" );
            return FALSE();
        }
        if ( !grep( $_ eq $info_type, @{$dataset_infotypes} ) ) {
            $self->_note_exception( 1, "Wrong information type: " . $info_type );
            return FALSE();
        }
        my $sql1 = "DELETE FROM InfoDS WHERE ds_id = " . $current_ds_id . " AND i_type = '" . $info_type . "'\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $sql2 =
              "INSERT INTO InfoDS (ds_id, i_type, i_content)\n"
            . "   VALUES ("
            . $current_ds_id . ", '"
            . $info_type . "', '"
            . $self->_pg_escape_string($info_content) . "')";
        if ( !$self->_do_query($sql2) ) {
            return FALSE();
        }
        return TRUE();
    }

=item dset_get($info_type)

Get information from the current dataset.

IN: Information type (I_type). Currently one of 'ds_name', 'ds_id', 'u_id',
'DSKEY', 'LOCATION', 'CATALOG', 'WMS_URL', 'WMS_XML'

Return value: Value of field (single entity or XML), FALSE on error.

=cut

    sub dset_get {
        my $self              = shift;
        my $ident             = ident($self);
        my $info_type         = shift;
        my $current_ds_id     = $current_ds_id{$ident};
        my $current_ds_name   = $current_ds_name{$ident};
        my $current_ds_uid    = $current_ds_uid{$ident};
        my $dataset_infotypes = $dataset_infotypes{$ident};
        if ( !defined($current_ds_id) ) {
            $self->_note_exception( 1, "No current dataset" );
            return FALSE();
        }
        if ($info_type eq 'ds_name') {
           return $current_ds_name;
        } elsif ($info_type eq 'ds_id') {
           return $current_ds_id;
        } elsif ($info_type eq 'u_id') {
           return $current_ds_uid;
        } elsif ( !grep( $_ eq $info_type, @{$dataset_infotypes} ) ) {
            $self->_note_exception( 1, "Wrong information type: " . $info_type );
            return FALSE();
        }
        my $sql1 = "SELECT i_content FROM InfoDS WHERE ds_id = " . $current_ds_id . " AND i_type = '" . $info_type . "'\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 0,
                "No info on " . $info_type . " for dataset " . $current_ds_name . " in database" );
            return FALSE();
        }
        if ( $rowcount != 1 ) {
            $self->_note_exception( 1,
                "Multiple values for " . $info_type . " for dataset " . $current_ds_name . " in database" );
            return FALSE();
        }
        my $href = $self->_fetch_row_as_hashref(0);
        if ( !$href ) {
            return FALSE();
        }
        return $href->{"i_content"};
    }

    #
    #     Method: _infoUDS_read
    #     Read information from the current set of infoUDS rows
    #
    sub _infoUDS_read {
        my $self           = shift;
        my $ident          = ident($self);
        my $infoUDS_rows   = $infoUDS_rows{$ident};
        my $infoUDS_row_ix = $infoUDS_row_ix{$ident};
        my $infoUDS_fields = $infoUDS_fields{$ident};
        if ( !defined($infoUDS_rows) ) {
            $self->_note_exception( 1, "No set of infoUDS rows defined" );
            return FALSE();
        }
        if ( $infoUDS_row_ix < 0 || $infoUDS_row_ix >= scalar @{$infoUDS_rows} ) {
            $self->_note_exception( 1, "Current row off array limits: " . $infoUDS_row_ix );
            return FALSE();
        }
        my $iid = $infoUDS_rows->[$infoUDS_row_ix];
        my $sql1 = "SELECT " . $infoUDS_fields . " FROM InfoUDS WHERE i_id = " . $iid . "\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 1, "InfoUDS record with i_id=" . $iid . " not found" );
            return FALSE();
        }
        my $href = $self->_fetch_row_as_hashref(0);
        if ( !$href ) {
            return FALSE();
        }
        $infoUDS_record{$ident} = $href;
        return TRUE();
    }

    #
    #     Method: _infoUDS_write
    #     Write information to the current set of infoUDS rows
    #
    sub _infoUDS_write {
        my $self           = shift;
        my $ident          = ident($self);
        my $infoUDS_rows   = $infoUDS_rows{$ident};
        my $infoUDS_row_ix = $infoUDS_row_ix{$ident};
        my $infoUDS_fields = $infoUDS_fields{$ident};
        my $infoUDS_record = $infoUDS_record{$ident};
        if ( !defined($infoUDS_record) ) {
            $self->_note_exception( 1, "No infoUDS record defined" );
            return FALSE();
        }
        my $iid = $infoUDS_record->{"i_id"};
        my $sql1 = "DELETE FROM InfoUDS WHERE i_id = " . $iid . "\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $sql2 =
              "INSERT INTO InfoUDS ("
            . $infoUDS_fields . ")\n"
            . "   VALUES ("
            . $self->_get_SQL_value_list( $infoUDS_fields, $infoUDS_record ) . ")";
        if ( !$self->_do_query($sql2) ) {
            return FALSE();
        }
        $pending_infoUDS_updates{$ident} = FALSE();
        return TRUE();
    }

=item infoUDS_set($info_type,$info_span)

Define a set of rows from the InfoUDS table and set the first row as the current row.

 IN:
 1. Information type. (Currently only SUBSCRIPTION_XML).
 2. Keyword that tells how the set shall relate to the current user and/or current dataset
    (values: USER, DATASET, USER_AND_DATASET).
    DATASET: All rows pertaining to the current dataset
    USER:  All rows pertaining to the current user
    USER_AND_DATASET: All rows pertaining to both the current user and current dataset.

 Return value: Number of rows (N) in the set, or FALSE on error / empty set.

=cut

    sub infoUDS_set {
        my $self                    = shift;
        my $ident                   = ident($self);
        my $info_type               = shift;
        my $info_span               = shift;
        my $pending_infoUDS_updates = $pending_infoUDS_updates{$ident};
        my $infoUDS_infotypes       = $infoUDS_infotypes{$ident};
        my $current_ds_id           = $current_ds_id{$ident};
        my $user_array              = $user_array{$ident};

        if ($pending_infoUDS_updates) {
            if ( !$self->_infoUDS_write() ) {
                return FALSE();
            }
        }
        if ( !grep( $_ eq $info_type, @{$infoUDS_infotypes} ) ) {
            $self->_note_exception( 1, "Wrong info_type in call to infoUDS_set: " . $info_type );
            return FALSE();
        }
        if ( !grep( $_ eq $info_span, ( 'USER', 'DATASET', 'USER_AND_DATASET' ) ) ) {
            $self->_note_exception( 1, "Wrong info_span in call to infoUDS_set: " . $info_span );
            return FALSE();
        }
        my $infoUDS_dsid = -1;
        my $infoUDS_uid  = -1;
        my $whereclause  = "WHERE ";
        if ( $info_span eq 'DATASET' or $info_span eq 'USER_AND_DATASET' ) {
            if ( !defined($current_ds_id) ) {
                $self->_note_exception( 1, "No current dataset when searching for infoUDS rows" );
                return FALSE();
            }
            $infoUDS_dsid = $current_ds_id;
            $whereclause .= "ds_id = " . $infoUDS_dsid;
        }
        if ( $info_span eq 'USER' or $info_span eq 'USER_AND_DATASET' ) {
            if ( !defined($user_array) ) {
                $self->_note_exception( 1, "No current user when searching for infoUDS rows" );
                return FALSE();
            }
            if ( length($whereclause) > 7 ) {
                $whereclause .= " AND ";
            }
            $infoUDS_uid = $user_array->{"u_id"};
            $whereclause .= "u_id = " . $infoUDS_uid;
        }
        my $sql1 = "SELECT i_id FROM InfoUDS " . $whereclause . "\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        $infoUDS_uid{$ident}   = $infoUDS_uid;
        $infoUDS_dsid{$ident}  = $infoUDS_dsid;
        $infoUDS_itype{$ident} = $info_type;
        $infoUDS_rows{$ident}  = [];
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 0, "No infoUDS rows for " . $info_type . " spanning " . $info_span );
            return FALSE();
        }
        my $i1 = 0;
        while ( $i1 < $rowcount ) {
            my $href = $self->_fetch_row_as_hashref($i1);
            $infoUDS_rows{$ident}->[$i1] = $href->{"i_id"};
            $i1++;
        }
        $infoUDS_row_ix{$ident} = 0;
        if ( !$self->_infoUDS_read() ) {
            return FALSE();
        }
        return $rowcount;
    }

=item infoUDS_put($content)

Replace the content field in the current row.

IN: Value of I_content field (single entity or XML).

Return value: TRUE on success, FALSE on error.

=cut

    sub infoUDS_put {
        my $self                    = shift;
        my $ident                   = ident($self);
        my $content                 = shift;
        my $infoUDS_record          = $infoUDS_record{$ident};
        my $pending_infoUDS_updates = $pending_infoUDS_updates{$ident};
        if ( !defined($infoUDS_record) ) {
            $self->_note_exception( 1, "No infoUDS record defined" );
            return FALSE();
        }
        $infoUDS_record->{"i_content"} = $content;
        $pending_infoUDS_updates{$ident} = TRUE();
        return TRUE();
    }

=item infoUDS_get()

Get information from the current row in the current set.

Return value: Value of I_content field (single entity or XML).

=cut

    sub infoUDS_get {
        my $self           = shift;
        my $ident          = ident($self);
        my $infoUDS_record = $infoUDS_record{$ident};
        if ( !defined($infoUDS_record) ) {
            $self->_note_exception( 1, "No infoUDS record defined" );
            return FALSE();
        }
        return $infoUDS_record->{"i_content"};
    }

=item infoUDS_next()

Define the next row in the set as the current row.

Return value: TRUE on success, FALSE on error / no more rows in the set.

=cut

    sub infoUDS_next {
        my $self                    = shift;
        my $ident                   = ident($self);
        my $infoUDS_rows            = $infoUDS_rows{$ident};
        my $infoUDS_row_ix          = $infoUDS_row_ix{$ident};
        my $pending_infoUDS_updates = $pending_infoUDS_updates{$ident};
        if ( !defined($infoUDS_rows) ) {
            $self->_note_exception( 1, "No set of infoUDS rows defined" );
            return FALSE();
        }
        my $ix = $infoUDS_row_ix + 1;
        if ( $ix >= scalar @{$infoUDS_rows} ) {
            $self->_note_exception( 0, "No more rows in the set of infoUDS rows" );
            return FALSE();
        }
        if ($pending_infoUDS_updates) {
            if ( !$self->_infoUDS_write() ) {
                return FALSE();
            }
        }
        $infoUDS_row_ix{$ident} = $ix;
        if ( !$self->_infoUDS_read() ) {
            return FALSE();
        }
        return TRUE();
    }

=item infoUDS_new($content)

Create a new row in the set and define it as the current row. The row will belong to the user
and/or dataset that defines the set. If the set is only defined by user, the current dataset
will be used to connect the row to a dataset. Similarly, if the set is only defined by dataset,
the current user will be used. NOTE: The new row will be set up as the last row in the current
set. Used inside a loop with infoUDS_next, this method will accordingly break out of the
sequential visiting of rows from the set.

IN: Value of I_content field (single entity or XML).

Return value: TRUE on success, FALSE on error.

=cut

    sub infoUDS_new {
        my $self                    = shift;
        my $ident                   = ident($self);
        my $content                 = shift;
        my $infoUDS_rows            = $infoUDS_rows{$ident};
        my $infoUDS_uid             = $infoUDS_uid{$ident};
        my $infoUDS_dsid            = $infoUDS_dsid{$ident};
        my $infoUDS_itype           = $infoUDS_itype{$ident};
        my $user_array              = $user_array{$ident};
        my $current_ds_id           = $current_ds_id{$ident};
        my $pending_infoUDS_updates = $pending_infoUDS_updates{$ident};
        if ( !defined($infoUDS_rows) ) {
            $self->_note_exception( 1, "No set of infoUDS rows defined" );
            return FALSE();
        }
        my $ix = scalar @{$infoUDS_rows};
        if ($pending_infoUDS_updates) {
            if ( !$self->_infoUDS_write() ) {
                return FALSE();
            }
        }
        my $uid;
        if ( defined($infoUDS_uid) && $infoUDS_uid >= 0 ) {
            $uid = $infoUDS_uid;
        } elsif ( defined($user_array) ) {
            $uid = $user_array->{"u_id"};
        } else {
            $self->_note_exception( 1, "Not able to connect a user to the new infoUDS row" );
            return FALSE();
        }
        my $dsid;
        if ( defined($infoUDS_dsid) && $infoUDS_dsid >= 0 ) {
            $dsid = $infoUDS_dsid;
        } elsif ( defined($current_ds_id) ) {
            $dsid = $current_ds_id;
        } else {
            $self->_note_exception( 1, "Not able to connect a dataset to the new infoUDS row" );
            return FALSE();
        }
        my $fields = 'u_id, ds_id, i_type, i_content';
        my $values = $self->_get_SQL_value_list( $fields, [ $uid, $dsid, $infoUDS_itype, $content ] );
        my $sql1 = "INSERT INTO InfoUDS (" . $fields . ") VALUES (" . $values . ") returning i_id\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $href = $self->_fetch_row_as_hashref(0);
        if ( !$href ) {
            return FALSE();
        }
        my $iid            = $href->{"i_id"};
        my $infoUDS_record = {
            i_id      => $iid,
            u_id      => $uid,
            ds_id     => $dsid,
            i_type    => $infoUDS_itype,
            i_content => $content
        };
        $infoUDS_rows->[$ix]    = $iid;
        $infoUDS_rows{$ident}   = $infoUDS_rows;
        $infoUDS_row_ix{$ident} = $ix;
        return TRUE();
    }

=item infoUDS_delete()

Delete the current InfoUDS row.

Return value: TRUE on success, FALSE on error.

=cut

    sub infoUDS_delete {
        my $self           = shift;
        my $ident          = ident($self);
        my $infoUDS_rows   = $infoUDS_rows{$ident};
        my $infoUDS_record = $infoUDS_record{$ident};
        my $infoUDS_row_ix = $infoUDS_row_ix{$ident};
        if ( !defined($infoUDS_rows) ) {
            $self->_note_exception( 1, "No set of infoUDS rows defined" );
            return FALSE();
        }
        if ( !defined($infoUDS_record) ) {
            $self->_note_exception( 1, "No current infoUDS row defined" );
            return FALSE();
        }
        my $sql1 = "DELETE FROM InfoUDS WHERE i_id = " . $infoUDS_record->{'i_id'} . "\n";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        $infoUDS_record{$ident}                  = undef;
        $infoUDS_rows{$ident}->[$infoUDS_row_ix] = undef;
        $pending_infoUDS_updates{$ident}         = FALSE();
        return TRUE();
    }

    #
    #     Method: _update_file
    #     Write pending changes to current file to the database
    #
    sub _update_file {
        my $self                 = shift;
        my $ident                = ident($self);
        my $file_array           = $file_array{$ident};
        my $current_ds_id        = $current_ds_id{$ident};
        my $current_ds_name      = $current_ds_name{$ident};
        my $file_ordinary_fields = $file_ordinary_fields{$ident};
        my $user_ordinary_fields = $user_ordinary_fields{$ident};
        my $user_array           = $user_array{$ident};
        if ( !defined($file_array) ) {
            $self->_note_exception( 1, "_update_file() found no current file" );
            return FALSE();
        }
        if ( !defined( $file_array->{"f_name"} ) ) {
            $self->_note_exception( 1, "_update_file() found no f_name in file_array" );
            return FALSE();
        }
        if ( !defined($user_array) ) {
            $self->_note_exception( 1, "_update_file() No current user" );
            return FALSE();
        }
        if ( !defined( $user_array->{"u_id"} ) ) {
            $self->_note_exception( 1, "_update_file() found no u_id in user_array" );
            return FALSE();
        }
        my $sql1 = "SELECT u_id, f_name FROM File\n"
            . $self->_get_SQL_WHERE_clause( 'u_id, f_name', [ $user_array->{"u_id"}, $file_array->{'f_name'} ] );
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount > 1 ) {
            $self->_note_exception( 1,
                      "_update_file() found multiple files ("
                    . $rowcount
                    . ") with same f_name= "
                    . $file_array->{"f_name"}
                    . " for user "
                    . $user_array->{"u_id"} );
            return FALSE();
        }
        $file_array->{'f_timestamp'} = POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());
        my $valuelist;
        if ( $rowcount == 0 ) {
            $valuelist = $user_array->{"u_id"} . ", ";
            $valuelist .= $self->_get_SQL_value_list( "f_name, " . $file_ordinary_fields, $file_array );
            my $sql2 =
                "INSERT INTO File (u_id, f_name, " . $file_ordinary_fields . ")\n" . "   VALUES (" . $valuelist . ")";
            if ( !$self->_do_query($sql2) ) {
                return FALSE();
            }
        } else {    #   ($rowcount == 1)
            $valuelist = $self->_get_SQL_value_list( $file_ordinary_fields, $file_array );
            my $sql3 =
                  "UPDATE File\n"
                . "   SET ("
                . $file_ordinary_fields
                . ") = \n"
                . "       ("
                . $valuelist . ")\n"
                . $self->_get_SQL_WHERE_clause( 'u_id, f_name', [ $user_array->{"u_id"}, $file_array->{'f_name'} ] );
            if ( !$self->_do_query($sql3) ) {
                return FALSE();
            }
        }
        $pending_file_updates{$ident} = FALSE();
        return TRUE();
    }

=item file_find($file_name)

Search for an existing file (owned by the curent user) and make it the current file.

IN: File name (F_name).

Return value: TRUE on success, FALSE on error / no such file.

=cut

    sub file_find {
        my $self                 = shift;
        my $ident                = ident($self);
        my $file_name            = shift;
        my $current_ds_id        = $current_ds_id{$ident};
        my $current_ds_name      = $current_ds_name{$ident};
        my $pending_file_updates = $pending_file_updates{$ident};
        my $file_ordinary_fields = $file_ordinary_fields{$ident};
        my $user_array           = $user_array{$ident};
        if ( !defined($user_array) ) {
            $self->_note_exception( 1, "No current user" );
            return FALSE();
        }
        if ( !defined( $user_array->{"u_id"} ) ) {
            $self->_note_exception( 1, "Found no u_id in user_array" );
            return FALSE();
        }
        if ($pending_file_updates) {
            if ( !$self->_update_file() ) {
                return FALSE();
            }
        }
        my $sql1 =
              "SELECT u_id, f_name, "
            . $file_ordinary_fields
            . " FROM File "
            . $self->_get_SQL_WHERE_clause( 'u_id, f_name', [ $user_array->{"u_id"}, $file_name ] );
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 0, "No such file" );
            return FALSE();
        }
        if ( $rowcount != 1 ) {
            $self->_note_exception( 1,
                      "Multiple files ("
                    . $rowcount
                    . ") with same f_name= "
                    . $file_name
                    . " for user with u_id = "
                    . $user_array->{"u_id"} );
            return FALSE();
        }
        $file_array{$ident} = $self->_fetch_row_as_hashref(0);
        return TRUE();
    }

=item file_create($file_name)

Create a new file (for the current user) and make it the current file.

IN: File name (F_name)

Return value: TRUE on success, FALSE on error.

=cut

    sub file_create {
        my $self                 = shift;
        my $ident                = ident($self);
        my $file_name            = shift;
        my $current_ds_id        = $current_ds_id{$ident};
        my $current_ds_name      = $current_ds_name{$ident};
        my $pending_file_updates = $pending_file_updates{$ident};
        my $user_array           = $user_array{$ident};
        if ( !defined($user_array) ) {
            $self->_note_exception( 1, "No current user" );
            return FALSE();
        }
        if ( !defined( $user_array->{"u_id"} ) ) {
            $self->_note_exception( 1, "Found no u_id in user_array" );
            return FALSE();
        }
        my $sql1 = "SELECT u_id, f_name FROM File "
            . $self->_get_SQL_WHERE_clause( 'u_id, f_name', [ $user_array->{"u_id"}, $file_name ] );
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount > 0 ) {
            $self->_note_exception( 0, "File already exists in database" );
            return FALSE();
        }
        if ($pending_file_updates) {
            if ( !$self->_update_file() ) {
                return FALSE();
            }
        }
        my $file_array = {};
        $file_array->{"u_id"}        = $user_array->{"u_id"};
        $file_array->{"f_name"}       = $file_name;
        $file_array{$ident}           = $file_array;
        $pending_file_updates{$ident} = TRUE();
        return TRUE();
    }

=item file_put($property,$value)

Set file properties for the current file.

IN: Property name (one of f_timestamp, f_size, f_status, f_errurl), property value

Return value: TRUE on success, FALSE on error.

=cut

    sub file_put {
        my $self                 = shift;
        my $ident                = ident($self);
        my $property             = shift;
        my $value                = shift;
        my $file_array           = $file_array{$ident};
        my $file_ordinary_fields = $file_ordinary_fields{$ident};
        if ( !defined($file_array) ) {
            $self->_note_exception( 1, "No current file" );
            return FALSE();
        }
        my @fieldnames = split( /\s*,\s*/, $file_ordinary_fields );
        if ( !grep( $_ eq $property, @fieldnames ) ) {
            $self->_note_exception( 1, "Property '" . $property . "' not known" );
            return FALSE();
        }
        $file_array->{$property} = $value;
        $pending_file_updates{$ident} = TRUE();
        return TRUE();
    }

=item file_get($property)

Get file properties for the current file.

IN: Property name (one of f_timestamp, f_size, f_status, f_errurl).

Return value: Property value or FALSE on error.

=cut

    sub file_get {
        my $self                 = shift;
        my $ident                = ident($self);
        my $property             = shift;
        my $file_array           = $file_array{$ident};
        my $file_ordinary_fields = $file_ordinary_fields{$ident};
        if ( !defined($file_array) ) {
            $self->_note_exception( 1, "No current file" );
            return FALSE();
        }
        my @fieldnames = split( /\s*,\s*/, "ds_id, f_name, " . $file_ordinary_fields );
        if ( !grep( $_ eq $property, @fieldnames ) ) {
            $self->_note_exception( 1, "Property '" . $property . "' not known" );
            return FALSE();
        }
        return $file_array->{$property};
    }

=item file_first()

Make the first file (owned by the current user) the current file.

Return value: TRUE on success, FALSE on error / no files owned by the current dataset.

=cut

    #     This method updates the internal 'users_files'
    #     array that contains the f_name's of all files owned by the current user.
    #
    sub file_first {
        my $self                 = shift;
        my $ident                = ident($self);
        my $pending_file_updates = $pending_file_updates{$ident};
        my $current_ds_id        = $current_ds_id{$ident};
        my $current_ds_name      = $current_ds_name{$ident};
        my $file_ordinary_fields = $file_ordinary_fields{$ident};
        my $user_array           = $user_array{$ident};
        if ( !defined($user_array) ) {
            $self->_note_exception( 1, "No current user" );
            return FALSE();
        }
        if ( !defined( $user_array->{"u_id"} ) ) {
            $self->_note_exception( 1, "Found no u_id in user_array" );
            return FALSE();
        }
        if ($pending_file_updates) {
            if ( !$self->_update_file() ) {
                return FALSE();
            }
        }
        my $users_files = [];
        my $sql1 = "SELECT f_name FROM File WHERE u_id = " . $user_array->{"u_id"} .
                   " ORDER BY f_timestamp, f_name";
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 0, "No files in the database for user with u_id = " . $user_array->{"u_id"} );
            return FALSE();
        }
        my $i1 = 0;
        while ( $i1 < $rowcount ) {
            my $href = $self->_fetch_row_as_hashref($i1);
            $users_files->[$i1] = $href->{"f_name"};
            $i1++;
        }
        my $sql2 =
              "SELECT u_id, f_name, "
            . $file_ordinary_fields
            . " FROM File "
            . $self->_get_SQL_WHERE_clause( 'u_id, f_name', [ $user_array->{"u_id"}, $users_files->[0] ] );
        if ( !$self->_do_query($sql2) ) {
            return FALSE();
        }
        my $file_array = $self->_fetch_row_as_hashref(0);
        if ( !$file_array ) {
            return FALSE();
        }
        $current_file_ix{$ident} = 0;
        $file_array{$ident}      = $file_array;
        $users_files{$ident}   = $users_files;
        return TRUE();
    }

=item file_next()

Make the next file in the database the current one.

Return value: TRUE on success, FALSE on error / no more files.

=cut

    sub file_next {
        my $self                 = shift;
        my $ident                = ident($self);
        my $pending_file_updates = $pending_file_updates{$ident};
        my $users_files        = $users_files{$ident};
        my $current_ds_id        = $current_ds_id{$ident};
        my $current_file_ix      = $current_file_ix{$ident};
        my $file_ordinary_fields = $file_ordinary_fields{$ident};
        my $user_array           = $user_array{$ident};
        if ( !defined($user_array) ) {
            $self->_note_exception( 1, "No current user" );
            return FALSE();
        }
        if ( !defined( $user_array->{"u_id"} ) ) {
            $self->_note_exception( 1, "Found no u_id in user_array" );
            return FALSE();
        }
        if ($pending_file_updates) {

            if ( !$self->_update_file() ) {
                return FALSE();
            }
        }
        if ( !defined($users_files) ) {
            $self->_note_exception( 1, "No current set of files. File_first not called?" );
            return FALSE();
        }
        my $ix = $current_file_ix + 1;
        if ( $ix >= scalar @{$users_files} ) {
            $self->_note_exception( 0, "No more files for the current user" );
            return FALSE();
        }
        my $file_name = $users_files->[$ix];
        my $sql1 =
              "SELECT u_id, f_name, "
            . $file_ordinary_fields
            . " FROM File "
            . $self->_get_SQL_WHERE_clause( 'u_id, f_name', [ $user_array->{"u_id"}, $file_name ] );
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        my $rowcount = $self->_pg_num_rows();
        if ( $rowcount == 0 ) {
            $self->_note_exception( 1, "File " . $file_name . " not found in the database" );
            return FALSE();
        }
        my $file_array = $self->_fetch_row_as_hashref(0);
        if ( !$file_array ) {
            return FALSE();
        }
        $current_file_ix{$ident} = $ix;
        $file_array{$ident}      = $file_array;
        return TRUE();
    }

=item file_delete()

Delete the current file in the database.

Return value: TRUE on success, FALSE on error.

=cut

    sub file_delete {
        my $self                 = shift;
        my $ident                = ident($self);
        my $file_array           = $file_array{$ident};
        my $users_files          = $users_files{$ident};
        my $current_file_ix      = $current_file_ix{$ident};
        my $user_array           = $user_array{$ident};
        if ( !defined($user_array) ) {
            $self->_note_exception( 1, "No current user" );
            return FALSE();
        }
        if ( !defined( $user_array->{"u_id"} ) ) {
            $self->_note_exception( 1, "Found no u_id in user_array" );
            return FALSE();
        }
        if ( !defined($file_array) ) {
            $self->_note_exception( 1, "No current file" );
            return FALSE();
        }
        my $file_name = $file_array->{'f_name'};
        my $sql1 = "DELETE FROM File "
            . $self->_get_SQL_WHERE_clause( 'u_id, f_name', [ $user_array->{"u_id"}, $file_name ] );
        if ( !$self->_do_query($sql1) ) {
            return FALSE();
        }
        if (defined($users_files) and  $file_name eq $users_files->[$current_file_ix]) {
           $users_files->[$current_file_ix] = undef;
        }
        $file_array{$ident}      = undef;
        $pending_file_updates{$ident} = FALSE();
        return TRUE();
    }
}

=back

=head1 AUTHOR

Egil Støren <egil.storen@met.no>

=cut

1;
