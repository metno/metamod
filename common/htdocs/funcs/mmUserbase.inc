<?php
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
#  email: egil.storen@met.no
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
?>
<?php
#
#   Class definition
#
class MM_Userbase {
   protected $dbh;   # Database handle
   protected $pending_user_updates;   # TRUE if changes in current user are not written to
                                      # the database
   protected $pending_dataset_updates;   # TRUE if changes in current dataset are not
                                         # written to the database
   protected $pending_file_updates;   # TRUE if changes in current file are not written to 
                                      # the database
   protected $in_transaction;         # TRUE if a database transaction is in progress
   protected $transaction_triggers;   # Array with SQL commands that will start a
                                      # transaction (if not already started)
   protected $user_array;   # Accosiative array with all user attributes of the current user
   protected $file_array;   # Accosiative array with all file attributes of the current file
   protected $allusers;   # Array with u_id's for all users sorted on increasing u_id's
   protected $current_user_ix;   # Index in the allusers array containing the u_id of current user
   protected $user_ordinary_fields;   # Commaseparated list of fields in the User
                                      # database table (except u_id, a_id and u_email).
   protected $file_ordinary_fields;   # Commaseparated list of fields in the File
                                      # database table (except ds_id and f_name).
   protected $integer_fields;   # Array of field names of integer type (all tables)
   protected $users_datasets;   # Array with ds_id's for all datasets belonging to the current
                              # user. Sorted on increasing ds_id's
   protected $dataset_files;   # Array with f_name's for all files belonging to the current
                              # dataset.
   protected $current_ds_ix;   # Index in the users_datasets array representing the current
                               # dataset for the current user
   protected $current_file_ix;   # Index in the dataset_files array representing the current
                               # file for the current dataset
   protected $current_ds_id;   # ds_id of the current dataset for the current user
   protected $current_ds_name;   # ds_name of the current dataset for the current user
   protected $dataset_infotypes;   # Array with information types accepted by the system
   protected $exception_string;   # Text string containing an error message or informational
                                  # message
   protected $exception_level;   # Number representing the current exception:
                                 # 0 : Normal info, like "No more users" intended to close a loop
                                 # 1 : Error 
#   
#      Constructor function
#   
   function __construct() {   # Constructor function
      global $mmConfig;
      $this->dbh = @pg_Connect ("dbname=".$mmConfig->getVar('USERBASE_NAME').
                   " user=".$mmConfig->getVar('PG_WEB_USER')." ".$mmConfig->getVar('PG_CONNECTSTRING_PHP'));
      $this->pending_user_updates = FALSE;
      $this->pending_dataset_updates = FALSE;
      $this->pending_file_updates = FALSE;
      $this->in_transaction = FALSE;
      $this->transaction_triggers = array('INSERT','UPDATE','DELETE');
      $this->user_ordinary_fields = "u_name, u_password, u_institution, u_telephone, u_session";
      $this->dataset_infotypes = array('DSKEY','LOCATION','CATALOG','WMS_URL','WMS_XML');
      $this->file_ordinary_fields = "f_timestamp, f_size, f_status, f_errurl";
      $this->integer_fields = array('u_id', 'ds_id');
      $this->exception_string = "";
      $this->exception_level = 0;
   }
#   
#      Set the internal error text string
#   
   protected function note_exception($level, $exception_text) {
      $this->exception_string = $exception_text;
      $this->exception_level = $level;
      return TRUE;
   }
#
#      Construct a value list to be used in an SQL INSERT statement corresponding to
#      a list of field names. The values are taken from the $value_array. Except for integer
#      fields, apostrophes are added around each value. Enclosinq paranthesis are not added
#      around the resulting list. String fields are escaped using pg_escape_string that
#      changes single apostrophes in the value into two concecutive apostrophes. The database
#      system will convert these double apostrophes back to single before the values are used
#      in the database (SQL standard).
#
   protected function get_SQL_value_list($list_of_fields, $value_array) {
      $fieldnames = preg_split('/\s*,\s*/',$list_of_fields);
      $values = array();
      if (isset($value_array)) {
         foreach ($fieldnames as $field) {
            if (array_key_exists($field, $value_array) and isset($value_array[$field])) {
               if (in_array($field,$this->integer_fields)) {
                  $values[] = $value_array[$field];
               } else {
                  $values[] = "'" . pg_escape_string($value_array[$field]) . "'";
               }
            } else {
               $values[] = "NULL";
            }
         }
      } else {
         foreach ($fieldnames as $field) {
            $values[] = "NULL";
         }
      }
      $valuelist = implode(", ",$values);
      return $valuelist;
   }
#   
#      Construct a safe SQL WHERE clause combining equality conditions with AND.
#      Each field in $list_of_fields (commaseparated string) is paired with a corresponding
#      value in the $value_array. The pairing is done either by positional indices in
#      $value_array (i.e. 0,1,2,...), or by using the field name as index. String values are
#      escaped using pg_escape_string and surrounded by single apostrophes.
#   
   protected function get_SQL_WHERE_clause($list_of_fields, $value_array) {
      $fieldnames = preg_split('/\s*,\s*/',$list_of_fields);
      $where_clause = 'WHERE ';
      $i1 = 0;
      $fieldcount = count($fieldnames);
      foreach ($fieldnames as $field) {
         if ($i1 > 0 and $i1 < $fieldcount) {
            $where_clause .= ' AND ';
         }
         if (array_key_exists($i1, $value_array) and isset($value_array[$i1])) {
            $val = $value_array[$i1];
         } elseif (array_key_exists($field, $value_array) and isset($value_array[$field])) {
            $val = $value_array[$field];
         } else {
            $val = "NULL";
         }
         if ($val == "NULL") {
            $comparision_operator = ' IS ';
         } else {
            $comparision_operator = ' = ';
         }
         if (!in_array($field,$this->integer_fields) and $val != "NULL") {
            $val = "'" . pg_escape_string($val) . "'";
         }
         $where_clause .= $field . $comparision_operator . $val;
         $i1++;
      }
      return $where_clause;
   }
#   
#      Make a database query and get error string on error
#   
   protected function do_query($sql_query) {
      $sql_command = "";
      if (preg_match ('/^(\S+)\b/',$sql_query,$matches)) {
         $sql_command = $matches[1];
      }
      if (in_array($sql_command,$this->transaction_triggers) and !$this->in_transaction) {
         $qhandle = pg_query($this->dbh,'BEGIN TRANSACTION');
         if ($qhandle === FALSE) {
            $pg_error = pg_last_error($this->dbh);
            $this->note_exception(1,"Failed to begin transaction. ".$pg_error);
            return FALSE;
         }
         $this->in_transaction = TRUE;
      }
      $qhandle = @pg_query($this->dbh,$sql_query);
      if ($qhandle === FALSE) {
         $pg_error = pg_last_error($this->dbh);
         $this->note_exception(1,"pg_query returns FALSE on '".$sql_query."'. ".$pg_error);
         return FALSE;
      }
      return $qhandle;
   }
#   
#      Get last exception
#   
   public function get_exception() {
      return $this->exception_string;
   }
#   
#      Check if last exception is error
#   
   public function exception_is_error() {
      return ($this->exception_level == 1);
   }
#   
#      Close database connection
#   
   public function close() {
      if ($this->pending_file_updates) {
         if ($this->update_file() === FALSE) {
            return FALSE;
         }
      }
      if ($this->pending_user_updates) {
         if ($this->update_user() === FALSE) {
            return FALSE;
         }
      }
      if ($this->in_transaction) {
         $qhandle = $this->do_query('COMMIT');
         if ($qhandle === FALSE) {
            return FALSE;
         }
         $this->in_transaction = FALSE;
      }
      pg_close($this->dbh);
      return TRUE;
   }
#   
#      Revert any changes to the database and close the database connection
#   
   public function revert() {
      if ($this->in_transaction) {
         $qhandle = $this->do_query('ROLLBACK');
         if ($qhandle === FALSE) {
            return FALSE;
         }
         $this->in_transaction = FALSE;
      }
      pg_close($this->dbh);
      return TRUE;
   }
#   
#      Write pending changes to current user to the database
#   
   protected function update_user() {
      $sql1 = "SELECT u_id FROM UserTable\n" .
         $this->get_SQL_WHERE_clause('u_email, a_id',$this->user_array);
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount > 1) {
         $this->note_exception(1,"Multiple users (".$rowcount.") with same u_email= ".$this->user_array['u_email'].
                             " and a_id= '".$this->user_array['a_id']."'");
         return FALSE;
      }
      if ($rowcount == 0) {
         $valuelist = $this->get_SQL_value_list("a_id, u_email, " . $this->user_ordinary_fields,
                                               $this->user_array);
         $sql1 = "INSERT INTO UserTable (a_id, u_email, " . $this->user_ordinary_fields . ")\n" .
            "   VALUES (" . $valuelist . ")";
         $qhandle = $this->do_query($sql1);
         if ($qhandle === FALSE) {
            return FALSE;
         }
      } else {   # ($rowcount == 1) 
         $valuelist = $this->get_SQL_value_list($this->user_ordinary_fields,
                                               $this->user_array);
         $sql1 = "UPDATE UserTable\n" .
            "   SET (" . $this->user_ordinary_fields . ") = \n" .
            "       (" . $valuelist . ")\n" .
            $this->get_SQL_WHERE_clause('u_email, a_id',$this->user_array);
         $qhandle = $this->do_query($sql1);
         if ($qhandle === FALSE) {
            return FALSE;
         }
      }
      $this->pending_user_updates = FALSE;
      return TRUE;
   }
#   
#      Find user based on E-mail address and application id:
#   
   public function user_find($email_address, $application_id) {
      if ($this->pending_user_updates) {
         if ($this->update_user() === FALSE) {
            return FALSE;
         }
      }
      $sql1 = "SELECT u_id, " . $this->user_ordinary_fields . " FROM UserTable ".
              $this->get_SQL_WHERE_clause('u_email, a_id',array($email_address,$application_id));
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount == 0) {
        $this->note_exception(0,"No such user");
        return FALSE;
      }
      if ($rowcount != 1) {
        $this->note_exception(1,"Multiple users (".$rowcount.") with same u_email= ".$email_address.
                            " and a_id= ".$application_id);
        return FALSE;
      }
      $this->user_array = pg_fetch_assoc($qhandle,0);
      if ($this->user_array === FALSE) {
         $this->note_exception(1,"pg_fetch_assoc returns FALSE");
         return FALSE;
      }
      $this->user_array["u_email"] = $email_address;
      $this->user_array["a_id"] = $application_id;
      return TRUE;
   }
#   
#      Create new user:
#   
   public function user_create($email_address, $application_id) {
#      
#       Check if user already exists:
#      
      $sql_select_uid = "SELECT u_id FROM UserTable\n" .
         $this->get_SQL_WHERE_clause('u_email, a_id',array($email_address,$application_id));
      $qhandle = $this->do_query($sql_select_uid);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount > 0) {
         $this->note_exception(0,"User already exists in database");
         return FALSE;
      }
      if ($this->pending_user_updates) {
         if ($this->update_user() === FALSE) {
            return FALSE;
         }
      }
#      
#        Initialize the new user array and insert into UserTable:
#      
      $this->user_array = array();
      $this->user_array['u_email'] = $email_address;
      $this->user_array['a_id'] = $application_id;
      $valuelist = $this->get_SQL_value_list("a_id, u_email", $this->user_array);
      $sql2 = "INSERT INTO UserTable (a_id, u_email) VALUES (" . $valuelist . ")";
      $qhandle = $this->do_query($sql2);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $qhandle = $this->do_query($sql_select_uid);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount == 0) {
         $this->note_exception(1,"Could not find newly created user ($application_id / $email_address) in database");
         return FALSE;
      }
      $rowarr = pg_fetch_row($qhandle,0);
      $this->user_array['u_id'] = $rowarr[0];
      return TRUE;
   }
#   
#      Public member function (user_set):
#   
   public function user_set($property, $value) {
      if (!isset($this->user_array)) {
         $this->note_exception(1,"No current user");
         return FALSE;
      }
#      
#        Check if value exists in list
#      
      $fieldnames = preg_split('/\s*,\s*/',$this->user_ordinary_fields);
      if (!in_array($property, $fieldnames)) {
         $this->note_exception(1,"Property '".$property."' not known");
         return FALSE;
      }
      $this->user_array[$property] = $value;
      $this->pending_user_updates = TRUE;
      return TRUE;
   }
#   
#      Public member function (user_get):
#   
   public function user_get($property) {
      if (!isset($this->user_array)) {
         $this->note_exception(1,"No current user");
         return FALSE;
      }
      $fieldnames = preg_split('/\s*,\s*/',"u_id, u_email, a_id, " . $this->user_ordinary_fields);
      if (!in_array($property, $fieldnames)) {
         $this->note_exception(1,"Property '".$property."' not known");
         return FALSE;
      }
      return $this->user_array[$property];
   }
#
#      Get first user in u_id order. This method updates the internal 'allusers'
#      array that contains the u_id's of all users in the database.
#
   public function user_first() {
      if ($this->pending_user_updates) {
         if ($this->update_user() === FALSE) {
            return FALSE;
         }
      }
      $this->allusers = array();
      $sql1 = "SELECT u_id FROM UserTable ORDER BY u_id\n";
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount == 0) {
         $this->note_exception(0,"No users in the database");
         return FALSE;
      }
      $i1 = 0;
      while ($i1 < $rowcount) {
         $rowarr = pg_fetch_row($qhandle,$i1);
         $this->allusers[$i1] = $rowarr[0];
         $i1++;
      }
      $sql1 = "SELECT u_id, a_id, u_email, " . $this->user_ordinary_fields . " FROM UserTable WHERE u_id = ".
              $this->allusers[0]."\n";
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $this->user_array = pg_fetch_assoc($qhandle,0);
      if ($this->user_array === FALSE) {
         $this->note_exception(1,"pg_fetch_assoc returns FALSE");
         return FALSE;
      }
      $this->current_user_ix = 0;
      return TRUE;
   }
#   
#      Get next user. 
#   
   public function user_next() {
      if ($this->pending_user_updates) {
         if ($this->update_user() === FALSE) {
            return FALSE;
         }
      }
      $ix = $this->current_user_ix + 1;
      if (!array_key_exists($ix, $this->allusers)) {
         $this->note_exception(0,"No more users in the database");
         return FALSE;
      }
      $uid = $this->allusers[$ix];
      $sql1 = "SELECT u_id, a_id, u_email, " . $this->user_ordinary_fields . " FROM UserTable WHERE u_id = ".
              $uid . "\n";
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount == 0) {
         $this->note_exception(1,"User with u_id = " . $uid . " not found in the database");
         return FALSE;
      }
      $this->user_array = pg_fetch_assoc($qhandle,0);
      if ($this->user_array === FALSE) {
         $this->note_exception(1,"pg_fetch_assoc returns FALSE");
         return FALSE;
      }
      $this->current_user_ix = $ix;
      return TRUE;
   }
#
#      Create dataset entry
#
   public function dset_create($dataset_name, $dataset_key) {
      if (!isset($this->user_array)) {
         $this->note_exception(1,"No current user");
         return FALSE;
      }
      $sql_ds = "SELECT ds_id FROM DataSet " . 
         $this->get_SQL_WHERE_clause('ds_name, a_id',array($dataset_name,$this->user_array['a_id']));
      $qhandle = $this->do_query($sql_ds);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount > 0) {
         $this->note_exception(0,"DataSet " . $dataset_name . " already exists in database");
         return FALSE;
      }
      $sql1 = "INSERT INTO DataSet (u_id, a_id, ds_name)\n" .
              "   VALUES (" . $this->get_SQL_value_list('u_id, a_id', $this->user_array) .
                          ", '" . pg_escape_string($dataset_name) . "')";
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $qhandle = $this->do_query($sql_ds);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowarr = pg_fetch_row($qhandle,0);
      $this->current_ds_id = $rowarr[0];
      $this->current_ds_name = $dataset_name;
      if (!$this->info_put("DSKEY",$dataset_key)) {
         return FALSE;
      }
      return TRUE;
   }
#
#      Find a dataset in the database and make it the current dataset. Also make
#      the user that owns the dataset the current user
#
   public function dset_find($applic_id, $dataset_name) {
      $sql1 = "SELECT ds_id, u_id FROM DataSet " .
         $this->get_SQL_WHERE_clause('ds_name, a_id',array($dataset_name,$applic_id));
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount != 1) {
         $this->note_exception(0,"DataSet " . $applic_id . " / " . $dataset_name . " not found");
         return FALSE;
      }
      $rowarr = pg_fetch_row($qhandle,0);
      $dsid = $rowarr[0];
      $userid = $rowarr[1];
      if ($this->pending_user_updates) {
         if ($this->update_user() === FALSE) {
            return FALSE;
         }
      }
      $sql1 = "SELECT u_email, a_id, " . $this->user_ordinary_fields . " FROM UserTable WHERE u_id = ".
              $userid."\n";
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount == 0) {
        $this->note_exception(1,"User with u_id = " . $userid . " not found in database. " .
                           "But the DataSet table contains an entry with this u_id.");
        return FALSE;
      }
      $this->user_array = pg_fetch_assoc($qhandle,0);
      if ($this->user_array === FALSE) {
         $this->note_exception(1,"pg_fetch_assoc returns FALSE");
         return FALSE;
      }
      $this->user_array["u_id"] = $userid;
      $this->current_ds_id = $dsid;
      $this->current_ds_name = $dataset_name;
      return TRUE;
   }
#
#      Get the first dataset owned by the current user in ds_id order. This method
#      updates the internal 'users_datasets' array that contains the ds_id's of all datasets
#      owned by the current user.
#
   public function dset_first() {
      if (!isset($this->user_array)) {
         $this->note_exception(1,"No current user");
         return FALSE;
      }
      $this->users_datasets = array();
      $sql1 = "SELECT ds_id FROM DataSet WHERE u_id = " . $this->user_array['u_id'] . " ORDER BY ds_id\n";
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount == 0) {
         $this->note_exception(0,"No datasets found for current user");
         return FALSE;
      }
      $i1 = 0;
      while ($i1 < $rowcount) {
         $rowarr = pg_fetch_row($qhandle,$i1);
         $this->users_datasets[$i1] = $rowarr[0];
         $i1++;
      }
      $sql1 = "SELECT ds_name FROM DataSet WHERE ds_id = " . $this->users_datasets[0] . "\n";
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowarr = pg_fetch_row($qhandle,0);
      $this->current_ds_name = $rowarr[0];
      $this->current_ds_ix = 0;
      $this->current_ds_id = $this->users_datasets[$this->current_ds_ix];
      return TRUE;
   }
#
#      Get the next dataset owned by the current user in ds_id order.
#
   public function dset_next() {
      if (!isset($this->user_array)) {
         $this->note_exception(1,"No current user");
         return FALSE;
      }
      $ix = $this->current_ds_ix + 1;
      if (!array_key_exists($ix, $this->users_datasets)) {
         $this->note_exception(0,"No more datasets found for current user");
         return FALSE;
      }
      $dsid = $this->users_datasets[$ix];
      $sql1 = "SELECT ds_name FROM DataSet WHERE ds_id = " . $dsid . "\n";
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount == 0) {
         $this->note_exception(1,"Expected another dataset, but found no datasets with ds_id = " . $dsid);
         return FALSE;
      }
      $rowarr = pg_fetch_row($qhandle,0);
      $this->current_ds_name = $rowarr[0];
      $this->current_ds_ix = $ix;
      $this->current_ds_id = $dsid;
      return TRUE;
   }
#
#      Add or replace content fields in the current dataset
#
   public function info_put($info_type, $info_content) {
      if (!isset($this->current_ds_id)) {
         $this->note_exception(1,"No current dataset");
         return FALSE;
      }
      if (!in_array($info_type, $this->dataset_infotypes)) {
         $this->note_exception(1,"Wrong information type: " . $info_type);
         return FALSE;
      }
      $sql1 = "DELETE FROM Info WHERE ds_id = " . $this->current_ds_id . " AND i_type = '" . $info_type . "'\n";
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $sql1 = "INSERT INTO Info (ds_id, i_type, i_content)\n" .
              "   VALUES (" . $this->current_ds_id . ", '" . $info_type . "', '" . 
              pg_escape_string($info_content) . "')";
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      return TRUE;
   }
#
#      Get information from the current dataset
#
   public function info_get($info_type) {
      if (!isset($this->current_ds_id)) {
         $this->note_exception(1,"No current dataset");
         return FALSE;
      }
      if (!in_array($info_type, $this->dataset_infotypes)) {
         $this->note_exception(1,"Wrong information type: " . $info_type);
         return FALSE;
      }
      $sql1 = "SELECT i_content FROM Info WHERE ds_id = " .
              $this->current_ds_id . " AND i_type = '" . $info_type . "'\n";
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount != 1) {
         $this->note_exception(0,"No info on " . $info_type . " for dataset " . 
                             $this->current_ds_name . " in database");
         return FALSE;
      }
      $rowarr = pg_fetch_row($qhandle,0);
      return $rowarr[0];
   }
#   
#      Write pending changes to current file to the database
#   
   protected function update_file() {
      if (!isset($this->file_array)) {
         $this->note_exception(1,"update_file() found no current file");
         return FALSE;
      }
      if (!isset($this->file_array['f_name'])) {
         $this->note_exception(1,"update_file() found no f_name in file_array");
         return FALSE;
      }
      if (!isset($this->current_ds_id)) {
         $this->note_exception(1,"update_file() found no current dataset");
         return FALSE;
      }
      $sql1 = "SELECT ds_id, f_name FROM File\n" .
         $this->get_SQL_WHERE_clause('ds_id, f_name',array($this->current_ds_id,$this->file_array['f_name']));
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount > 0) {
         $this->note_exception(1,"update_file() found multiple files (".$rowcount.") with same f_name= ".
                               $this->file_array['f_name']." for dataset ".$this->current_ds_name);
         return FALSE;
      }
      if ($rowcount == 0) {
         $valuelist = $this->current_ds_id . ", ";
         $valuelist .= $this->get_SQL_value_list("f_name, " . $this->file_ordinary_fields,
                                                 $this->file_array);
         $sql1 = "INSERT INTO File (ds_id, f_name, " . $this->file_ordinary_fields . ")\n" .
            "   VALUES (" . $valuelist . ")";
         $qhandle = $this->do_query($sql1);
         if ($qhandle === FALSE) {
            return FALSE;
         }
      } else { #   ($rowcount == 1)
         $valuelist = $this->get_SQL_value_list($this->file_ordinary_fields, $this->file_array);
         $sql1 = "UPDATE File\n" .
            "   SET (" . $this->user_ordinary_fields . ") = \n" .
            "       (" . $valuelist . ")\n" .
            $this->get_SQL_WHERE_clause('ds_id, f_name',array($this->current_ds_id,$this->file_array['f_name']));
         $qhandle = $this->do_query($sql1);
         if ($qhandle === FALSE) {
            return FALSE;
         }
      }
      $this->pending_file_updates = FALSE;
      return TRUE;
   }
#   
#      Find user based on E-mail address and application id:
#   
   public function file_find($file_name) {
      if (!isset($this->current_ds_id)) {
         $this->note_exception(1,"No current dataset");
         return FALSE;
      }
      if ($this->pending_file_updates) {
         if ($this->update_file() === FALSE) {
            return FALSE;
         }
      }
      $sql1 = "SELECT f_name, " . $this->file_ordinary_fields . " FROM File ".
          $this->get_SQL_WHERE_clause('ds_id, f_name',array($this->current_ds_id,$this->file_array['f_name']));
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount == 0) {
        $this->note_exception(0,"No such file");
        return FALSE;
      }
      if ($rowcount != 1) {
        $this->note_exception(1,"Multiple files (".$rowcount.") with same f_name= ".$email_address.
                            " for dataset ".$this->current_ds_name);
        return FALSE;
      }
      $this->file_array = pg_fetch_assoc($qhandle,0);
      if ($this->file_array === FALSE) {
         $this->note_exception(1,"pg_fetch_assoc returns FALSE");
         return FALSE;
      }
      $this->file_array["ds_id"] = $this->current_ds_id;
      $this->file_array["f_name"] = $file_name;
      return TRUE;
   }
#   
#      Create new entry in the File table:
#   
   public function file_create($file_name) {
      if (!isset($this->current_ds_id)) {
         $this->note_exception(1,"No current dataset");
         return FALSE;
      }
#      
#       Check if the file entry already exists:
#      
      $sql1 = "SELECT ds_id, f_name FROM File\n" .
          $this->get_SQL_WHERE_clause('ds_id, f_name',array($this->current_ds_id,$this->file_array['f_name']));
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount > 0) {
         $this->note_exception(0,"File already exists in database");
         return FALSE;
      }
      if ($this->pending_file_updates) {
         if ($this->update_file() === FALSE) {
            return FALSE;
         }
      }
#      
#        Initialize the new file array:
#      
      $this->file_array = array();
      $this->file_array['ds_id'] = $this->current_ds_id;
      $this->file_array['f_name'] = $file_name;
      $this->pending_file_updates = TRUE;
      return TRUE;
   }
#   
#      Set file property for the current file
#   
   public function file_set($property, $value) {
      if (!isset($this->file_array)) {
         $this->note_exception(1,"No current file");
         return FALSE;
      }
#      
#        Check if value exists in list
#      
      $fieldnames = preg_split('/\s*,\s*/',$this->file_ordinary_fields);
      if (!in_array($property, $fieldnames)) {
         $this->note_exception(1,"Property '".$property."' not known");
         return FALSE;
      }
      $this->file_array[$property] = $value;
      $this->pending_file_updates = TRUE;
      return TRUE;
   }
#   
#      Get file property for the current file
#   
   public function file_get($property) {
      if (!isset($this->file_array)) {
         $this->note_exception(1,"No current file");
         return FALSE;
      }
      $fieldnames = preg_split('/\s*,\s*/',"ds_id, f_name, " . $this->file_ordinary_fields);
      if (!in_array($property, $fieldnames)) {
         $this->note_exception(1,"Property '".$property."' not known");
         return FALSE;
      }
      return $this->file_array[$property];
   }
#
#      Get first file for the current daaset. This method updates the internal 'dataset_files'
#      array that contains the f_name's of all files owned by the current dataset.
#
   public function file_first() {
      if ($this->pending_file_updates) {
         if ($this->update_file() === FALSE) {
            return FALSE;
         }
      }
      if (!isset($this->current_ds_id)) {
         $this->note_exception(1,"No current dataset");
         return FALSE;
      }
      $this->dataset_files = array();
      $sql1 = "SELECT f_name FROM File WHERE ds_id = ".$this->current_ds_id;
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount == 0) {
         $this->note_exception(0,"No files in the database for dataset ".$this->current_ds_name);
         return FALSE;
      }
      $i1 = 0;
      while ($i1 < $rowcount) {
         $rowarr = pg_fetch_row($qhandle,$i1);
         $this->dataset_files[$i1] = $rowarr[0];
         $i1++;
      }
      $sql1 = "SELECT f_name, " . $this->file_ordinary_fields . " FROM File ".
          $this->get_SQL_WHERE_clause('ds_id, f_name',array($this->current_ds_id,$this->dataset_files[0]));
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $this->file_array = pg_fetch_assoc($qhandle,0);
      if ($this->file_array === FALSE) {
         $this->note_exception(1,"pg_fetch_assoc returns FALSE");
         return FALSE;
      }
      $this->file_array['ds_id'] = $this->current_ds_id;
      $this->current_file_ix = 0;
      return TRUE;
   }
#   
#      Get next file. 
#   
   public function file_next() {
      if ($this->pending_file_updates) {
         if ($this->update_file() === FALSE) {
            return FALSE;
         }
      }
      if (!isset($this->current_ds_id)) {
         $this->note_exception(1,"No current dataset");
         return FALSE;
      }
      $ix = $this->current_file_ix + 1;
      if (!array_key_exists($ix, $this->dataset_files)) {
         $this->note_exception(0,"No more files for the current dataset");
         return FALSE;
      }
      $file_name = $this->dataset_files[$ix];
      $sql1 = "SELECT f_name, " . $this->file_ordinary_fields . " FROM File ".
          $this->get_SQL_WHERE_clause('ds_id, f_name',array($this->current_ds_id,$file_name));
      $qhandle = $this->do_query($sql1);
      if ($qhandle === FALSE) {
         return FALSE;
      }
      $rowcount = pg_num_rows($qhandle);
      if ($rowcount == 0) {
         $this->note_exception(1,"File " . $file_name . " not found in the database");
         return FALSE;
      }
      $this->file_array = pg_fetch_assoc($qhandle,0);
      if ($this->user_array === FALSE) {
         $this->note_exception(1,"pg_fetch_assoc returns FALSE");
         return FALSE;
      }
      $this->file_array['ds_id'] = $this->current_ds_id;
      $this->current_file_ix = $ix;
      return TRUE;
   }
}
?>