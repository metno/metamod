package MetNo::NcDigest;

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

=head1 NAME

MetNo::NcDigest

=head1 SYNOPSIS

  use MetNo::NcDigest qw( digest );
  digest($pathfilename, $ownertag, $xml_metadata_path, $is_child );

=head1 DESCRIPTION

A netCDF file contains a set of global attributes and a set of variables. Each variable
may also have attributes. The global attributes, variables and variable attributes
comprise metadata that the program extracts.

In the config directory there must be a conf_digest_nc.xml file defining the
rules that complying netCDF files must obey. The extracted metadata are
formatted as XML and written to the file given by $xml_metadata_path. In this
process, some metadata may be modified and some metadata may be added. Such
modifications are regulated by the config file.

=head1 TECHNICAL DETAILS

=head2 Variable types

Variables in the netCDF files are classified into different types. Two main types
exist: "%Data" and "%Coordinate". The "%Data" variables are supposed to contain
physical entities that correspond to standard names in the CF standard names table.
The "%Coordinate" variables are variables corresponding to one of the dimensions
used by "%Data" variables, or auxilliary coordinate variables that should be
declared as such using the "coordinates" attribute for at least one of the "%Data"
variables. From these main types, various subtypes are constructed by appending
strings to the type names. The following types are hardcoded into the program
(additional types may be introduced in the config file):

    %Data             - The variable represents a physical entity and is not used
                        as a coordinate for other variables.
    %Data_grid        - A data variable with dimensions indicating a 2D grid
                        (usually combined with other dimensions).
    %Coordinate       - The variable is used as a coordinate, but the coordinate
                        type is undecided
    %Coordinate_T     - The variable is used as a time coordinate
    %Coordinate_X     - The variable is used as a coordinate for the X axis
                        (usually having name longitude or Xc).
    %Coordinate_Y     - The variable is used as a coordinate for the Y axis
                        (usually having name latitude or Yc).
    %Coordinate_Z     - Vertical coordinate

Based on CF rules, the program will try to classify the encountered variables into
one of these types. Types may also be set explicitly in the config file. The config
file may also define new subtypes based on the dimension strings of the variables.


=head2 Switches and lists

While analysing a netCDF file, the program may set switches and add values to lists
according to the content of the netCDF file and regulations in the config file.

An important class of switches are those corresponding to variable type names. For
each of the variable types, there exists a corresponding switch with the same name
as the variable type. When at least one variable of a specific type is found, the
corresponding switch is set.

In addition to these switches, switches may expicitly be introduced in the config
file, and conditions defined for when they should be set.

Lists, and conditions for adding elements to them, are also introduced in the config
file.


=head2 The config file

The topmost XML element in the config file is the <digest_nc> element, within which
all other elements are contained.

=head3 Structure elements

On the next level is one <file_structures> element containing a sequence of <structure>
elements. The structure elements are identified by a 'name' attribute. One of the
structure elements is special. It has name="default". The structure elements contain
rules that the netCDF files must obey. The default structure contains the default
rules.

The other structures contain rules that only pertain to selected datasets.
Each of these other structures has a 'regex' attribute containing a regular expression
that is matched against the xmlpath argument. If the regexp matches, then the rules
in this structure applies.

In addition, all netCDF-files must obey the default rules, if not superseded by
structure specific rules.

In addition to rules, the structure elements contain elements that have other
functions:

  - Classify the netCDF-files depending on file content
  - Set switches depending on file content
  - Extract information that are added to lists

These elements are helper elements that are used when formulating rules.

The non-default structure elements also may have elements that:

  - Explisitly set metadata values
  - Explisitly classify the netCDF-files independent of file content

=head3 Content of structure elements

    The following elements are allowed within structure elements:

    <set switch="..." />

       Set a global switch. "..." contains the name of the switch, which must start with
       a '%' character. All switches must be declared in a <global> element within the
       default structure element.

    <set_global_attribute_value name="...">
       ...
    </set_global_attribute_value>

       Set a netCDF global attribute. Used within file specific structure elements to set
       global attributes that may be missing or contain wrong values. Name="..." gives the
       name of the attribute, while its value comprise the content of the element.

    <variables_of_type name="...">
       ...
    </variables_of_type>

       Variables in the netCDF files are classified into various types. This XML element
       is used within file specific structure elements to explicitly classify a set of
       variables. The type name is given in name="...", and the set of variables is
       given in the content of the element (each variable name on a separate line).

    <global switches="..." />

       This element is used within the default structure to declare a set of global
       switches. A blank separated list of switch names is given by switches="...".
       Each name must start with a '%' character. The switches will initally be unset
       each time a new netCDF file is investigated. Other elements may set the switches
       depending on the content of the netCDF file.

       NOTE: It is not neccessary to declare switches with names equal to variable
       type names.

    <global lists="..." />

       This element is used within the default structure to declare a set of global
       lists. A blank separated list of list names is given by lists="...".
       Each name must start with a '%' character. The lists will initally be empty
       each time a new netCDF file is investigated.
       Other elements may add entities to the lists, depending on the content of the
       netCDF file.

    <investigate_data_dimensions>
       <dim rex="..." addmatches="..." extendtype="..." />
       ...
    </investigate_data_dimensions>

       This element sets up rules for classifying netCDF variables according to the
       dimensions used by the variables. Initially, the variables are already classified
       into various types. The main types are '%Data' and '%Coordinate'. Subtypes of
       these main types are also found: '%Data_grid', '%Coordinate_X', '%Coordinate_T'
       etc. ("Type" will usually refer to both main types and subtypes).

       The element contains one or more <dim> elements. The 'rex' attribute within a <dim>
       element contains a regular expression that is checked against the
       dimension string for each variable. If a match is found, the variable type is
       extended with the string given in extendtype="...". If more than one <dim> element
       matches, the first one is used. The optional attribute addmatches="..." specifies
       a blank separated list of global list names. If this attribute is used, the regular
       expression should contain one parantesised subexpression for each global list in
       the addmatches attribute. The partial matches for the subexpressions are paired
       with the global lists, and each match added to the corresponding global list.

=head3 Global attributes

    <global_attributes>
       <att name="...">
          <mandatory ... />
          <breaklines value="..." />
          <multivalue separator="..." />
          <vocabulary ... >
             ...
          </vocabulary>
          <convert>
             ...
          </convert>
       </att>
       ...
    </global_attributes>

       This element contains a sequence of <att> elements, each naming a global attribute
       for which some rules apply, or for which some value conversion is performed.
       All elements within an <att> element are optional. They are used as follows:

       <mandatory errmsg="..." />

          This element tells that the global attribute is mandatory, and gives an error
          message to use if the attribute is not found.

       <breaklines value="..." />

          This element is used to reformat an attribute value so that no single line
          in the attribute value is longer than the number given in value="...".

       <multivalue separator="..." />

          The global attribute should be interpreted as a set of values separated by
          the given separator string.

       <vocabulary ... >
          ...
       </vocabulary>

          This element contains a vocabulary against which the attribute value(s) are
          checked. Each line in the content represents one member of the vocabulary.

          Members of the vocabulary may contain escapes, each of which represents a set
          of character strings. An escape is identified by a '%' character followed by
          some alfanumeric characters. All escape identifiers must be declared in an
          "escapes" XML attribute within the <vocabulary ... > tag. This XML attribute
          contains a blank-separated list of all escapes used within the vocabulary.
          A global attribute value will match a member containing escapes if an exactly
          matching sting can be constructed from the member string by substituting all
          escapes by suitably selected character strings. For each of the escapes, this
          character string must be taken from the set of character strings that the
          escape represents.

          Se below for a list of allowed escape identifiers. In addition to this set,
          identifiers of global lists can be used as escapes. The set of character
          strings represented by a global list escape, is equal to the set of character
          strings within the list.

          Vocabulary members may also contain special keywords which also are
          identified by a '%' character followed by some alfanumeric characters. One
          such keyword is currently defined:

          %MANDATORY    This keyword marks the corresponding member as mandatory. Used
                        when the global attribute may contain multiple values (i.e.
                        when a <multivalue ...> tag is found within the <att> tag).
                        Then, one of the values must match the mandatory vocabulary
                        member.

          All such keywords are removed from a vocabulary member before any match
          against values are performed.

       <convert>
          ...
       </convert>

          This element is used for changing attribute values. Between the start and
          end tags are lines of the form:

          original_value :TO: new_value

          All attribute values matching original_value are changed to new_value.

=head3 Variables

    <variable name="..." ...>
       <mandatory ... />
       <dimensions ...>
          ...
       </dimensions>
       <att name="...">
          <mandatory ... />
          <breaklines value="..." />
          <multivalue separator="..." />
          <vocabulary ... >
             ...
          </vocabulary>
          <convert>
             ...
          </convert>
       </att>
       ...
    </variable>

       The <variable> element describes one variable or variable type. The value of
       the name="..." attribute is either a variable name or the name of a variable
       type. In the latter case, the name starts with a '%' character. The element
       contains one optional <mandatory> element, a <dimensions> element and any
       number of <att> elements:

       <mandatory ... />

          If this option is present, the variable of the given name, or at least one
          variable of the given type, is mandatory within the netCDF file. This rule
          can be made conditional by using an only_if="..." attribute. The value of
          the only_if attribute will contain the name of a global switch, which must
          be set if the rule is to be applied.

          This element should contain an errmsg="..." attribute giving an error message
          to use if the rule is not obeyed.

       <dimensions ...>
          ...
       </dimensions>

          This element contains the set of alternative dimension strings that the
          variable can use. A dimension string is the comma-separated list of
          dimensions used by the variable, as shown in a CDL-file.

          Dimension strings may contain escapes in the same manner as vocabulary
          members (explained above). All escape identifiers must be declared in an
          "escapes" XML attribute within the <dimension ... > tag. This XML attribute
          contains a blank-separated list of all escapes used within the dimension
          strings.

          This element should contain an errmsg="..." attribute giving an error message
          to use if the dimension string actually used do not match any of the
          alternatives.

          If the variable is allowed to have no dimensions (i.e. it can be a scalar),
          this can be expressed by using the escape "%NONE" all by itself, as one of
          the alternative dimension strings.

       <att name="...">
          <mandatory ... />
          <breaklines value="..." />
          <multivalue separator="..." />
          <vocabulary ... >
             ...
          </vocabulary>
          <convert>
             ...
          </convert>
       </att>

          This element defines rules and modifications applied to variable attributes.
          Any number of <att> elements are allowed. The elements within an <att> element
          are all optional, and their roles are the same as those explained for the
          global attributes (see above).

=head3 Escapes

Escapes are used within <vocabulary ... > elements (both for global and variable
attributes), and in <dimensions ... > elements.

An escape is identified by a '%' character followed by some alfanumeric characters.
Each escape represents a set of character strings. An escape having an identifier
equal to a global list name, represents the character strings found in the list.
All other escapes have fixed names, and the set of character strings they represent
are hardcoded into the program.

The following escapes with fixed names are found:

   %ANYSTRING        - Any character string.

   %ISODATE          - Date conforming to the ISO date standard, i.e.
                      having the form YYYY-MM-DD.

   %LATITUDE         - A number between -90.0 and 90.0

   %LONGITUDE        - A number between -180.0 and 180.0

   %hh               - Hour. An integer between 00 and 23

   %mm               - Minute. An integer between 00 and 59

   %ss               - Second. An integer between 00 and 59

   %i                - Any integer >= 1

   %EMAIL            - Any legal E-mail address

   %NONE             - The empty string

   %TIMEUNIT         - Any time unit accepted by the UDUNITS package. Example:
                      "seconds since 1981-01-01 00:00:00"

   %SINGLEWORD       - Any word composed of characters [a-zA-Z0-9_]

   %CF_STANDARD_NAME - A name from the CF standard names table

   %UDUNIT           - Any unit accepted by the UDUNITS package.

=head1 TODO

Rewrite as Object-oriented class

=head1 FUNCTIONS

=cut

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw( digest );

use Carp;
use Cwd;
use File::Spec;
use XML::Simple qw(:strict);
use Metamod::Dataset;
use encoding 'utf-8';
use MetNo::NcFind;

# use Data::Dump qw(dump);
use Data::Dumper;
use Fcntl qw(LOCK_SH LOCK_UN LOCK_EX);
use Metamod::Config;

#
#---------------------------------------------------------------------------------
#
# Variables for controlling test output and which parts of the program are
# to be executed. Normal operation is obtained by: $CTR_printconf = 0,
# $CTR_parseactions = 1, $CTR_parseall = 1 and $CTR_printnc = 0.
#
my $CTR_printconf    = 0;    # Prints the hash/array hierarchy constructed from the
                             # configuration file.
my $CTR_parseactions = 1;    # Construct global hashes from the configuration file.
my $CTR_parseall     = 1;    # Parse all files given in the input file (containing file
                             # pathes).
my $CTR_printnc      = 0;    # Prints variables and global attributes, as they are analyzed
my $CTR_printdump    = 0;    # Prints all gathered info about variables and global attributes
if ( $CTR_parseactions == 0 ) {    # No sense in parsing files with no global hashes
    $CTR_parseall = 0;
}

#
# Global variables:
# -----------------
my @user_errors    = ();
my $current_struct = "UNINITIALIZED";

#
# General config hashes reflecting the config file:
#
my %globlists         = ();
my %globswitches      = ();
my %attributes        = ();
my %presetattributes  = ();
my %structures        = ();
my %vocabularies      = ();
my %dimensions        = ();
my %variables         = ();
my %variabletypes     = ();
my %attribute_aliases = ();
my %conversions       = ();
my %investigatedims   = ();

#
# Hashes used for lists and switches while parsing netCDF files.
# These are reset/initialized from the general config hashes for each
# new netCDF file.
#
my %LSH_globswitches = ();
my %LSH_globlists    = ();

#
# Hashes combining default and structure specific features from the
# config file. These are constructed from the general config hashes
# each time the structure changes. Each netCDF file either belongs to
# the default structure, or a specificly named structure (recognized
# by a regular expression match against the netCDF file path).
#
my %RH_attributes        = ();
my %RH_presetattributes  = ();
my %RH_vocabularies      = ();
my %RH_dimensions        = ();
my %RH_variables         = ();
my %RH_variabletypes     = ();
my %RH_attribute_aliases = ();
my %RH_conversions       = ();

#
# Only one value needed. Reference to an array inside the XML tree:
#
my $RH_investigatedims;

#
# Hashes used by escapes:
#
my %standard_names = ();

my $manyspaces = ".  .  .  .  |  .  .  .  .  |  .  .  .  .  |  .  .  .  .  |  .  .  .  .  |  .  .  .  .  |  ";

#
#---------------------------------------------------------------------------------
#
# Action subroutines
# ------------------
#
# XML::Simple is used to construct a hash/array hierarchy corresponding
# to the XML-based configuration file. A subroutine, hloop, is defined
# that traverses this hierarchy, and activates actions triggered by hash
# keys used in the hierarchy (originating from tag names in the
# configuration file). The actions are defined as a set of subroutines
# referenced from the hash %parse_actions.
#
# Each action subroutine is called with the following parameters:
#
#   $refval     Reference to the next level in the hierarchy, which
#               will be a new hash or an array (the current level
#               corresponds to the key in the %parse_actions hash).
#
#   $path       The path of identification keys representing the
#               current node in the hierarchy. It is a sequence of
#               hash keys and array indices separated by '/'.
#
#   $level      The level of the current node. Equal to the number
#               of separate keys in $path.
#
#---------------------------------------------------------------------------------
#
my %parse_actions = (
    global                     => \&global,
    att                        => \&att,
    set                        => \&set,
    structure                  => \&structure,
    vocabulary                 => \&vocabulary,
    convert                    => \&convert,
    variable                   => \&variable,
    set_global_attribute_value => \&set_global_attribute_value,
    variables_of_type          => \&variables_of_type,
    attribute_aliases          => \&attribute_aliases,
    dim                        => \&dim,
);
$parse_actions{dimensions} = $parse_actions{"vocabulary"};

=head2 digest

Checks the content of netCDF files. All the files must belong to the same
dataset. Metadata are extracted from the files and saved into an XML file. The netCDF
files are supposed to be CF compliant.

=head3 Usage

  digest($pathfilename, $ownertag, $xml_metadata_path, $is_child );

=head3 Parameters

=over 4

=item $pathfilename

Path to input file. The first line in this file is an URL that points to where
the data will be found by users. This dataref URL will be included as metadata
in the XML file to be produced. The rest of the lines comprise the files to be
parsed, one file on each line. These files all belongs to one dataset.

=item $ownertag

Short keyword (e.g. "DAM") that will tag the data in the database as owned by a
specific project/organisation.

=item $xml_metadata_path

Path to an XML file that will receive the result of the netCDF parsing. If this
file already exists, it will contain the metadata for a previous version of the
dataset. In this case, a new version of the file will be created, comprising a
merge of the old and new metadata. The xmlpath will also define the
dataset-name: last directory parts + filename for parents, last two directory
parts + filename for children.

=item $is_child

if defined, creates a child xml-file, that is a xml-file which corresponds
exactly to one file, rather than to a set/directory of files. The content of the
old xmlpath will be ignored and just overwritten. The dataset-name will contain
of an extra directory.

=back

=cut

sub digest {
    my ( $pathfilename, $ownertag, $xml_metadata_path, $is_child ) = @_;

    # Reset global variables before starting digest.
    @user_errors    = ();
    $current_struct = "UNINITIALIZED";

    %globlists         = ();
    %globswitches      = ();
    %attributes        = ();
    %presetattributes  = ();
    %structures        = ();
    %vocabularies      = ();
    %dimensions        = ();
    %variables         = ();
    %variabletypes     = ();
    %attribute_aliases = ();
    %conversions       = ();
    %investigatedims   = ();

    %LSH_globswitches = ();
    %LSH_globlists    = ();

    %RH_attributes        = ();
    %RH_presetattributes  = ();
    %RH_vocabularies      = ();
    %RH_dimensions        = ();
    %RH_variables         = ();
    %RH_variabletypes     = ();
    %RH_attribute_aliases = ();
    %RH_conversions       = ();

    $RH_investigatedims = undef;

    %standard_names = ();

    eval {

        init_escapes();

        #
        # Read the XML configuration file.
        # This use of XMLin uses a file name as the XML source. When this is the case,
        # all HTML entities (&#nnn;) will be converted to its Latin-1 counterpart (if the
        # XML source had been a string, no such conversion would have occured).
        # Later, when pieces from this XML file is incorporated into dataset XML files,
        # the opposite conversion will be done (using the &convert_to_htmlentities routine).
        #
        my $config      = Metamod::Config->instance();
        my $config_file = $config->path_to_config_file( 'conf_digest_nc.xml', 'etc' );
        my $topconfig   = XMLin( $config_file, KeyAttr => ["name"], ForceArray => 1 );

        #
        # Recursively parse the $topconfig tree to initialize global hashes:
        #
        hloop( $topconfig, 0, "", \%parse_actions );

        if ($CTR_parseall) {
            parse_all( $pathfilename, $ownertag, $xml_metadata_path, $is_child );
        }
    };
    if ($@) {
        warn $@;    # should die unless file can be parsed - FIXME
    }

    my $usererrors_path = "nc_usererrors.out";
    open( my $USERERRORS, '>', $usererrors_path ) or confess "Cannot open usererrors log in " . getcwd();
    foreach my $line (@user_errors) {
        print $USERERRORS $line;
    }
    close($USERERRORS);

}

=head2 global

Add to the %globswitches and %globlists hashes.

=cut

sub global {
    my ( $refval, $path, $level ) = @_;
    my @patharr = split( m:/:, $path );
    if ( ref($refval) ne "ARRAY" ) {
        die '$parse_actions{"global"}: ref($refval) ne "ARRAY"';
    }
    foreach my $refvalnew (@$refval) {
        if ( ref($refvalnew) eq "HASH" ) {
            foreach my $hkey ( keys %$refvalnew ) {
                my $scalarval = $refvalnew->{$hkey};
                if ( !ref($scalarval) ) {
                    if ( $hkey eq "switches" ) {
                        foreach my $elt ( split( /\s+/, $scalarval ) ) {
                            my $gkey = $patharr[3] . ',' . $elt;
                            if ( !exists( $globswitches{$gkey} ) ) {
                                $globswitches{$gkey} = 0;
                            }
                        }
                    }
                    if ( $hkey eq "lists" ) {
                        foreach my $elt ( split( /\s+/, $scalarval ) ) {
                            if ( !exists( $globlists{$elt} ) ) {
                                $globlists{$elt} = [];
                            }
                        }
                    }
                }
            }
        } else {
            die '$parse_actions{"global"}: ref($refvalnew) ne "HASH"';
        }
    }
}

=head2 att

Add attributes to the %attributes hash using keys as:
"<structure name>,<glob_or_var>,<attribute name>" where <structure name>
is "default" or the name of another structure, and <glob_or_var> is either
"global_attributes" or the name of a variable.

=cut

sub att {
    my ( $refval, $path, $level ) = @_;
    my @patharr = split( m:/:, $path );
    if ( ref($refval) eq "HASH" ) {
        foreach my $hkey ( keys %$refval ) {
            my $refvalnew = $refval->{$hkey};
            if ( $patharr[4] eq "global_attributes" ) {
                $attributes{ $patharr[3] . ',global_attributes,' . $hkey } = $refvalnew;
            } else {
                $attributes{ $patharr[3] . ',' . $patharr[5] . ',' . $hkey } = $refvalnew;
            }
        }
    } else {
        die '$parse_actions{"att"}: ref($refval) ne "HASH"';
    }
}

=head2 set

Initialize global switch (in %globswitches) as set.

=cut

sub set {
    my ( $refval, $path, $level ) = @_;
    my @patharr = split( m:/:, $path );
    if ( ref($refval) eq "ARRAY" ) {
        foreach my $refvalnew (@$refval) {
            if ( ref($refvalnew) eq "HASH" ) {
                if ( exists( $refvalnew->{"switch"} ) ) {
                    if ( ref( $refvalnew->{"switch"} ) ) {
                        die '$parse_actions{"set"}: $refvalnew->{"switch"} not scalar';
                    }
                    my $gkey = $patharr[3] . ',' . $refvalnew->{"switch"};
                    $globswitches{$gkey} = 1;
                }
            } else {
                die '$parse_actions{"set"}: ref($refvalnew) ne "HASH"';
            }
        }
    } else {
        die '$parse_actions{"set"}: ref($refval) ne "ARRAY"';
    }
}

sub structure {

    #
    # Add to the %structures hash.
    #
    my ( $refval, $path, $level ) = @_;
    if ( ref($refval) eq "HASH" ) {
        foreach my $hkey ( keys %$refval ) {
            my $refvalnew = $refval->{$hkey};
            if ( exists( $refvalnew->{"regex"} ) ) {
                $structures{$hkey} = $refvalnew->{"regex"};
            }
        }
    } else {
        die '$parse_actions{"structure"}: ref($refval) ne "HASH"';
    }
}

=head2 vocabulary

Add to the %vocabularies hash.

The keys to this hash has the form: "<structname>,<glob_or_var>,<attributename>" where:

    <structname> is "default" or the name of another structure.
    <glob_or_var> is "global_attribute" or variable name.
    <attributename> is name of the attribute.

Each hash value is a reference to an array with five elements:

    [0]:  Reference to the @content array containing the original lines
          within the vocabulary. These are used to search for switches
          that are to be set if a line matches an attribute value.
    [1]:  Reference to the @rcontent array with regular expressions
          corresponding to each @content line. NOTE: The original line
          (in @content) must not contain any special characters used in
          regular expressions (^ $ [ ] \ ( ) ? | ? * + { } ).
    [2]:  Reference to the @mapcontent array (see below).
    [3]:  String telling what to do if value not found in vocabulary.
          Is one of: "use", "notuse" or "use_first_in_vocabulary".
    [4]:  Error message key (string) to be used if value not found
          in vocabulary. Could be an empty string.

=cut

sub vocabulary {

    my ( $refcontent, $path, $level ) = @_;
    my $ref = $refcontent->[0];
    if ( ref($ref) ne "HASH" ) {
        die '$parse_actions{"vocabulary"}: ref($ref) ne "HASH"';
    }
    my @patharr = split( m:/:, $path );
    my @escapes = ();
    if ( exists( $ref->{"escapes"} ) ) {
        my $s1 = $ref->{"escapes"};
        @escapes = split( / /, $s1 );
    }
    my @content = ();
    if ( exists( $ref->{"content"} ) ) {
        my $s1 = $ref->{"content"};
        @content = split( /\s*\n\s*/, $s1 );
    } else {
        die '$parse_actions{"vocabulary"}: $ref->{"content"} not found';
    }

    #
    #     Create two arrays:
    #
    #     @rcontent    For each $value in @content, this array will contain a corresponding
    #                  regexp where all escapes are replaced by a corresponding "(.*)" string
    #                  that matches anything that appears at this position in the $value
    #                  string.
    #
    #     @mapcontent  For each $value in @content, this array will contain a corresponding
    #                  map of the sequence of the escapes in $value. The map is a string
    #                  of blank separated escape names in the same sequence as in $value.
    #
    my @rcontent   = ();
    my @mapcontent = ();
    foreach my $value (@content) {

        #
        #       Construct the @mapcontent element. @r1 will contain escape values prepended
        #       by three digits that tells where in the $value string they appear. @r1 will
        #       be sorted, and the escape values will be put into the @mapcontent element
        #       in this sorted sequence.
        #
        my @r1 = ();
        foreach my $esc (@escapes) {
            my $j1 = 0;
            my $j2 = 0;
            while ( $j1 >= 0 ) {

                #
                #              Find location of a substring in a larger string (first position = 0):
                #              Start from position $j2
                #
                $j1 = index( $value, $esc, $j2 );
                if ( $j1 >= 0 ) {
                    my $s3 = sprintf( '%03d%-80s', $j1, $esc );
                    push( @r1, $s3 );
                }
                $j2 = $j1 + length($esc);
            }
        }

        #
        #       Sort array in lexical order:
        #
        my @r2 = sort @r1;
        my $s3 = "";
        foreach my $s2 (@r2) {
            if ( $s2 =~ /^\d\d\d(.+)\b\s*$/ ) {
                if ( length($s3) > 0 ) {
                    $s3 .= ' ';
                }
                $s3 .= $1;
            } else {
                die '$parse_actions{"vocabulary"}: Wrong element in @r2 array';
            }
        }
        push( @mapcontent, $s3 );

        #
        #       Create the @rcontent element:
        #
        my $rexval = $value;
        foreach my $esc (@escapes) {
            my $j1 = 0;
            while ( $j1 >= 0 ) {

                #
                #              Find location of a substring in a larger string (first position = 0):
                #
                $j1 = index( $rexval, $esc );
                if ( $j1 >= 0 ) {

                    #
                    #                 Replace substring in a string (first character has offset 0):
                    #
                    substr( $rexval, $j1, length($esc), "(.*)" );
                }
            }
        }
        $rexval =~ s/\s*%\w+//mg;    # Remove switches and %MANDATORY keyword
        push( @rcontent, $rexval );
    }
    my $on_error = "";
    if ( exists( $ref->{"on_error"} ) ) {
        $on_error = $ref->{"on_error"};
    }
    my $errmsg = "";
    if ( exists( $ref->{"errmsg"} ) ) {
        $errmsg = $ref->{"errmsg"};
    }

    #
    #  Add the collected information to the %vocabularies or %dimensions hash:
    #
    my $ix;
    if ( $patharr[-1] eq "vocabulary" ) {
        if ( $patharr[4] eq "global_attributes" ) {
            $ix = $patharr[3] . ',' . $patharr[4] . ',' . $patharr[7];
        } else {
            $ix = $patharr[3] . ',' . $patharr[5] . ',' . $patharr[7];
        }
        $vocabularies{$ix} = [ [@content], [@rcontent], [@mapcontent], $on_error, $errmsg ];
    } elsif ( $patharr[-1] eq "dimensions" ) {
        $ix = $patharr[3] . ',' . $patharr[5];
        $dimensions{$ix} = [ [@content], [@rcontent], [@mapcontent], $on_error, $errmsg ];
    } else {
        die 'Illegal path used in sub $parse_actions{"vocabulary"}';
    }
}

=head2 convert

Add to the %conversions hash:

=cut

sub convert {
    my ( $refval, $path, $level ) = @_;
    my @patharr = split( m:/:, $path );
    my $ref = $refval->[0];
    if ( ref($ref) ne "HASH" ) {
        die '$parse_actions{"convert"}: ref($ref) ne "HASH"';
    }
    my @content = ();
    if ( exists( $ref->{"content"} ) ) {
        my $s1 = $ref->{"content"};
        @content = split( /\s*\n\s*/, $s1 );
    } else {
        die '$parse_actions{"convert"}: $ref->{"content"} not found';
    }
    my $ix;
    if ( $patharr[4] eq "global_attributes" ) {
        $ix = $patharr[3] . ',' . $patharr[4] . ',' . $patharr[7];
    } else {
        $ix = $patharr[3] . ',' . $patharr[5] . ',' . $patharr[7];
    }
    foreach my $value (@content) {
        if ( length($value) > 0 ) {
            my @pair = split( /\s*:TO:\s*/, $value );
            my $key = $ix . ',' . $pair[0];
            $conversions{$key} = $pair[1];
        }
    }
}

=head2 variable

Add to the %variables hash:

=cut

sub variable {
    my ( $refval, $path, $level ) = @_;
    my @patharr = split( m:/:, $path );
    if ( ref($refval) eq "HASH" ) {
        foreach my $hkey ( keys %$refval ) {
            my $refvalnew = $refval->{$hkey};
            $variables{ $patharr[3] . ',' . $hkey } = $refvalnew;
        }
    } else {
        die '$parse_actions{"variable"}: ref($refval) ne "HASH"';
    }
}

=head2 set_global_attribute_value

... FIXME

=cut

sub set_global_attribute_value {
    my ( $refval, $path, $level ) = @_;
    my @patharr = split( m:/:, $path );
    if ( ref($refval) eq "HASH" ) {
        foreach my $attname ( keys %$refval ) {
            my $href = $refval->{$attname};
            my $attvalue;
            if ( ref($href) eq "HASH" ) {
                if ( !exists( $href->{"content"} ) ) {
                    die '$parse_actions{"set_global_attribute_value"}: content not found';
                }
                $attvalue = $href->{"content"};
                if ( $attvalue =~ /^[\s\n]*(.*)[\s\n]*$/ ) {
                    $attvalue = $1;
                }
                if ( ref($attvalue) ) {
                    die '$parse_actions{"set_global_attribute_value"}: $attvalue not scalar';
                }
            } else {
                die '$parse_actions{"set_global_attribute_value"}: $href not HASH ref';
            }
            $presetattributes{ $patharr[3] . ',' . $attname } = $attvalue;
        }
    } else {
        die '$parse_actions{"set_global_attribute_value"}: ref($refval) ne "HASH"';
    }
}

sub variables_of_type {

    #
    # Add to the %variabletypes hash:
    #
    my ( $refval, $path, $level ) = @_;
    my @patharr = split( m:/:, $path );
    if ( ref($refval) eq "HASH" ) {
        foreach my $typename ( keys %$refval ) {
            my $refnew = $refval->{$typename};
            if ( ref($refnew) ne "HASH" ) {
                die '$parse_actions{"variables_of_type"}: ref($refnew) ne "HASH"';
            }
            if ( !exists( $refnew->{"content"} ) ) {
                die '$parse_actions{"variables_of_type"}: content not found';
            }
            my $content = $refnew->{"content"};
            if ( ref($content) ) {
                die '$parse_actions{"variables_of_type"}: $content not scalar';
            }
            my @varnamearr = split( /\s*\n\s*/, $content );
            foreach my $varname (@varnamearr) {
                $variabletypes{ $patharr[3] . ',' . $varname } = $typename;
            }
        }
    } else {
        die '$parse_actions{"variables_of_type"}: ref($refval) ne "HASH"';
    }
}

sub attribute_aliases {

    #
    # Add to the %attribute_aliases hash:
    #
    my ( $refval, $path, $level ) = @_;
    my @patharr = split( m:/:, $path );
    if ( ref($refval) eq "HASH" ) {
        foreach my $attname ( keys %$refval ) {
            my $refnew = $refval->{$attname};
            if ( ref($refnew) ne "HASH" ) {
                die '$parse_actions{"attribute_aliases"}: ref($refnew) ne "HASH"';
            }
            if ( !exists( $refnew->{"content"} ) ) {
                die '$parse_actions{"attribute_aliases"}: content not found';
            }
            my $content = $refnew->{"content"};
            if ( ref($content) ) {
                die '$parse_actions{"attribute_aliases"}: $content not scalar';
            }
            my @aliasarr = split( /\s*\n\s*/, $content );
            foreach my $alias (@aliasarr) {
                $attribute_aliases{ $patharr[3] . ',' . $alias } = $attname;
            }
            if ( exists( $refnew->{"errmsg"} ) && defined( $refnew->{"errmsg"} ) ) {
                my $errmsg = $refnew->{"errmsg"};
                if ( ref($errmsg) ) {
                    die '$parse_actions{"attribute_aliases"}: $content not scalar';
                }
                $attribute_aliases{ $patharr[3] . ',' . $attname . ':errmsg' } = $errmsg;
            }
        }
    } else {
        die '$parse_actions{"attribute_aliases"}: ref($refval) ne "HASH"';
    }
}

sub dim {

    #
    #  The "dim" keyword is only used as tags inside the "investigate_data_dimensions"
    #  tag. So this subroutine builds the %investigatedims hash.
    #
    my ( $refval, $path, $level ) = @_;
    my @patharr = split( m:/:, $path );
    if ( $patharr[4] ne "investigate_data_dimensions" ) {
        die '$parse_actions{"dim"}: "dim" keyword used outside "investigate_data_dimensions"';
    }
    if ( ref($refval) ne "ARRAY" ) {
        die '$parse_actions{"dim"}: ref($refval) is not "ARRAY"';
    }
    $investigatedims{ $patharr[3] } = $refval;
}

sub init_escapes {

    my $config = Metamod::Config->instance();
    my $fpath = $config->path_to_config_file( 'standard_name.txt', 'etc' );
    unless ( -r $fpath ) { die "Can not read from file: $fpath\n"; }
    open( STNAMES, $fpath );
    while (<STNAMES>) {
        chomp($_);
        my $line = $_;
        $standard_names{$line} = 1;
    }
    close(STNAMES);
}

=head3 hloop($refval,$level,$path,$subrhash)

Recursively traverse the XML tree:

Split argument array into the following variables:

=over 4

=item $refval

Reference to subtree inside the larger XML tree. (can both be a HASH
reference or ARRAY reference):

=item $level

Number representing the level where the subtree is rooted.
The upmost (root) level corresponds to 0.

=item $path

String. Sequence of hash keys and array indices separated by "/"
characters. Each key/index represents a key or index in the XML
tree. The first key/index corresponds to one of the nodes identified
by the topmost (root) node. Then follows the keys and indices down
to, and including, the identifier of the current subtree.
The $path is a unique identifier of the current subtree.

=item $subrhash

Reference to the %parse_actions hash of subroutines. These subroutines
are identified by hash keywords used in the XML tree, and activated
when hloop encounters these keywords in the XML tree.

=back

=cut

sub hloop {

    my ( $refval, $level, $path, $subrhash ) = @_;

    #  Check if reference is a HASH
    if ( ref($refval) eq "HASH" ) {

        #
        #  Loop through a given level of tags rooted in a hash reference $refval.
        #  Each $refvalnew is a reference to HASH or ARRAY, or is a scalar.
        #
        foreach my $hkey ( keys %$refval ) {
            my $refvalnew = $refval->{$hkey};
            my $newpath   = $hkey;
            if ( length($path) > 0 ) {
                $newpath = $path . '/' . $hkey;
            }
            if ($CTR_printconf) { print STDOUT substr( $manyspaces, 0, 3 * $level ) }
            if ( ref($refvalnew) ) {
                if ($CTR_printconf) { print STDOUT $hkey . ":\n" }

                #
                #  If the hash keyword is also found in %$subrhash, call the subroutine
                #  identified by that hash:
                #
                if ( $CTR_parseactions && exists( $subrhash->{$hkey} ) ) {
                    my $coderef = $subrhash->{$hkey};
                    &$coderef( $refvalnew, $newpath, $level + 1 );
                }

                #  Recursive call to hloop for hash elements:

                &hloop( $refvalnew, $level + 1, $newpath, $subrhash );
            } else {
                if ($CTR_printconf) { print STDOUT $hkey . ":   " . $refvalnew . "\n" }
            }
        }
    } elsif ( ref($refval) eq "ARRAY" ) {

        #
        #  Loop through all array elements
        #  found through an array reference $refval.
        #  Each $scalarval is a scalar value
        #
        my $i1 = 0;
        foreach my $refvalnew (@$refval) {
            my $newpath = $path . '/' . $i1;
            if ($CTR_printconf) { print STDOUT substr( $manyspaces, 0, 3 * $level ) }
            if ($CTR_printconf) { print STDOUT $i1 . ":\n" }

            #  Recursive call to hloop for array elements:
            &hloop( $refvalnew, $level + 1, $newpath, $subrhash );
            $i1++;
        }
    } elsif ( ref($refval) eq "SCALAR" ) {
        if ($CTR_printconf) { print STDOUT substr( $manyspaces, 0, 3 * $level ) }
        if ($CTR_printconf) { print STDOUT ${$refval} . "\n" }
    }
    return;
}

=head2 parse_all($pathfilename, $ownertag, $xml_metadata_path, $isChild)

Loop through all files found in the $pathfilename file. Parse each
of these files. Construct two hashes. Both uses the file pathes in
$pathfilename as keys:

=over 4

=item %all_variables

References to variables found within each file.
Each reference points to a hash describing the variables
within the file.
See the %foundvars hash described in the parse_file routine.

=item %all_globatts

References to global attributes found within each file.
Each reference points to a hash describing the global
attributes of the file.
See the %foundglobatts hash described in the parse_file
routine.

=back

=cut

sub parse_all {
    my ( $pathfilename, $ownertag, $xml_metadata_path, $isChild ) = @_;
    my %all_variables = ();
    my %all_globatts  = ();
    unless ( -r $pathfilename ) { die "Can not read from file: $pathfilename\n"; }
    open( PATHLIST, $pathfilename );
    my $dataref;
    my $wmsurl;
    my $destination_path;    #destination path is only used when $isChild == 1

    while (<PATHLIST>) {
        chomp($_);
        my $fpath = $_;
        if ( !defined($dataref) ) {
            if ( $fpath =~ /(\S+)\s+(\S+)/ ) {
                $dataref = $1;
                $wmsurl  = $2;
            } else {
                $dataref = $fpath;
            }
        } else {

            # when $isChild == 1 we also receive the destination path for the file
            # so it can be added to the metadata
            if ( $fpath =~ /^(\S+)\s+(\S+)$/ ) {
                $fpath            = $1;
                $destination_path = $2;
            }

            my ( $vars, $atts ) = &parse_file( $fpath, $xml_metadata_path );
            $all_variables{$fpath} = $vars;
            $all_globatts{$fpath}  = $atts;
        }
    }
    close(PATHLIST);

    #
    #  Construct the %metadata hash which will be the basis for the XML file
    #  to write.
    #
    #  Usually, each key in %metadata will correspond to an element identifier
    #  in the XML file. Each value is a reference to an array with values. Each
    #  array element will end up as the value of a "name" attribute in an XML
    #  element having the %metadata key as element identifier.
    #
    my $ds = new Metamod::Dataset();    # initialize new one, might be overwritten by existing one

    #
    #  First, check if there already exist an XML metadata file with name
    #  $xml_metadata_path. In this case, initialize the %metadata hash with metadata
    #  from this file if it is not a child:
    #
    if ( -r $xml_metadata_path && ( !$isChild ) ) {
        $ds = Metamod::Dataset->newFromFile($xml_metadata_path);
        die "cannot read dataset $xml_metadata_path: $!\n" unless $ds;
        if ( $CTR_printdump == 1 ) {
            print STDOUT "\n----- METADATA FROM EXISTING XML FILE -----\n\n";
            my %metadata = $ds->getMetadata;
            my %info     = $ds->getInfo;
            print STDOUT Dumper( \%info, \%metadata );
        }
    }
    my %metadata = $ds->getMetadata;
    my %info     = $ds->getInfo;

    #
    #  Ensure the URL to the data is included in the metadata, and also
    #  that the metadata contains the identification string for the dataset (drpath):
    #
    if ( exists( $metadata{"dataref"} ) ) {
        my $datarefarr = $metadata{"dataref"};
        if ( grep( $_ eq $dataref, @$datarefarr ) == 0 ) {
            push( @{ $metadata{"dataref"} }, $dataref );
        }
    } else {
        $metadata{"dataref"} = [$dataref];
    }
    if ( ( !$info{name} ) or ( $info{"name"} eq '/' ) ) {    # '/' is minimal allowed name, default
        if ( $xml_metadata_path ne "TESTFILE" ) {
            my $nameReg;
            if ($isChild) {
                $nameReg = qr{/([^/]+/[^/]+/[^/]+)\.xml$}i;
            } else {
                $nameReg = qr{/([^/]+/[^/]+)\.xml$}i;
            }
            if ( $xml_metadata_path =~ /$nameReg/ ) {
                $info{"name"} = $1;
            } else {
                die "Not able to construct dataset-name from $xml_metadata_path";
            }
        } else {
            $info{"name"} = "TESTFILE";
        }
    }

    #
    #  If a wmsurl has been provided in the input file (second space-separated field
    #  in the first line), then construct a wmsxml element form this based on the
    #  WMS_XML value in master config:
    #
    my $config = Metamod::Config->instance();
    if ( defined($wmsurl) ) {
        my $wmsxml = $config->get("WMS_XML");
        if ( $wmsxml =~ / url=""/ ) {
            my $wmsfirst = $`;    # String before match
            my $wmslast  = $';    # String after match
            $wmsxml = $wmsfirst . ' url="' . $wmsurl . '"' . $wmslast;

            #
            #  Substitute '&', '<' and '>' with &amp;, &lt; and &gt; so that $wmsxml can appear as
            #  normal text in a XML dokument:
            #
            #         $wmsxml =~ s/&/&amp;/mg;
            #         $wmsxml =~ s/</&lt;/mg;
            #         $wmsxml =~ s/>/&gt;/mg;
            $info{"wmsxml"} = $wmsxml;
        }
    }

    #
    #  Preserve ownertag in an existing dataset, even if a new ownertag is
    #  provided in the input file. This is a hack so that owenrtags may easily
    #  be changed in existing datasets by editing the *.xmd file.
    #
    if ( !$info{'ownertag'} ) {
        $info{'ownertag'} = $ownertag;
    }

    #
    #  Start and stop date need special handling
    #
    {
        my $start_date = ( delete $metadata{'datacollection_period_from'} )->[0]
            if exists $metadata{'datacollection_period_from'};
        if ($start_date) {
            $metadata{'start_date'} = [$start_date];
        }
        my $stop_date = ( delete $metadata{'datacollection_period_to'} )->[0]
            if exists $metadata{'datacollection_period_to'};
        if ($stop_date) {
            $metadata{'stop_date'} = [$stop_date];
        }
    }

    #
    #  Populate the %metadata hash with values from the netCDF files.
    #
    #  XML elements <variable name="..." /> are treated specially.
    #  These elements are taken from two different sources. One source is
    #  all 'standard_name' attributes found in netCDF variables. The other is
    #  the global 'gcmd_keywords' attribute.
    #
    #  Collect global attributes from all netCDF files. Use the aggregate rules
    #  in the configuration file to construct one representative value for each
    #  global attribute.
    #
    foreach my $hkey ( grep { /^global_attributes,/ } keys %RH_attributes ) {
        my $attname = substr( $hkey, 18 );
        my $refval = $RH_attributes{$hkey};
        if ( exists( $refval->{"aggregate"} ) ) {
            if ( ref( $refval->{"aggregate"} ) ne "ARRAY" ) {
                die 'parse_all: $refval->{"aggregate"} is not a reference to ARRAY';
            }
            my $ref_aggr = $refval->{"aggregate"}->[0];
            if ( ref($ref_aggr) ne "HASH" ) {
                die 'parse_all: $refval->{"aggregate"}->[0] is not a reference to HASH';
            }
            if ( exists( $ref_aggr->{"rule"} ) ) {
                my $rule = $ref_aggr->{"rule"};
                if ( $CTR_printdump == 1 ) {
                    print STDOUT "\n----- Attribute, Rule: $attname, $rule\n";
                }
                if ( "$rule" =~ m/^all_should_be_equal/ ) {
                    &rule_all_equal( $rule, $attname, $ref_aggr, \%all_globatts, \%metadata );
                } elsif ( $rule =~ /^take_(highest|lowest)$/ ) {
                    &rule_highlow( $rule, $attname, \%all_globatts, \%metadata );
                } elsif ( $rule =~ /^take_(highest|lowest)_date$/ ) {
                    &rule_highlow_date( $rule, $attname, \%all_globatts, \%metadata );
                } elsif ( $rule eq "take_union" ) {
                    &rule_take_union( $attname, \%all_globatts, \%metadata );
                } else {
                    die 'parse_all: Global attribute with unknown aggregate rule: $rule';
                }
            } else {
                die 'parse_all: Global attribute without any aggregate rule';
            }
        }
    }

    #
    #  Initialize the %variablename hash with variable names from the
    #  existing XML file:
    #
    my %variablename = ();
    foreach my $varname ( @{ $metadata{"variable"} } ) {
        $variablename{$varname} = 1;
    }

    #
    #  Add to the %variablename hash with gcmd_keywords from the
    #  the current batch of netCDF files:
    #
    foreach my $attval ( @{ $metadata{"gcmd_keywords"} } ) {
        my $attval1;
        if ( $attval =~ /> HIDDEN$/ ) {
            $attval1 = $attval;
        } else {
            $attval1 = $attval . ' > HIDDEN';
        }
        $variablename{$attval1} = 1;
    }
    delete $metadata{"gcmd_keywords"};

    #
    #  Enter all variables having a standard_name into the %variablename hash:
    #
    foreach my $fpath ( keys %all_variables ) {
        my $refvarfound = $all_variables{$fpath};
        foreach my $varname ( keys %$refvarfound ) {
            my $refval = $refvarfound->{$varname};
            if ( ref($refval) ne "HASH" ) {
                die 'parse_all: ref($refval) ne "HASH" in $fpath->{$varname}';
            }
            if ( exists( $refval->{"type"} ) && substr( $refval->{"type"}, 0, 5 ) eq '%Data' ) {
                if ( exists( $refval->{"attributes"}->{"standard_name"} ) ) {
                    my $refval1 = $refval->{"attributes"}->{"standard_name"};
                    my $stdname = "";
                    if ( !ref($refval1) ) {
                        $stdname = $refval1;
                    } elsif ( ref($refval1) eq "ARRAY" ) {
                        $stdname = $refval1->[0];
                    } elsif ( ref($refval1) eq "SCALAR" ) {
                        $stdname = $$refval1;
                    }
                    if ( $stdname ne "" ) {
                        $variablename{$stdname} = 1;
                    }
                }
            }
        }
    }

    #  Place the list of variable names into the %metadata hash:
    $metadata{"variable"} = [ keys %variablename ];

    #
    #  Prepare output to the XML file:
    #

    $ds->removeMetadata; # clear all metadata from the dataset

    # the following might exist in metadata instead of the info
    $info{'status'}       = ( delete $metadata{'status'} )->[0]       if exists $metadata{'status'};
    $info{'creationDate'} = ( delete $metadata{'creationDate'} )->[0] if exists $metadata{'creationDate'};
    $ds->setInfo( \%info );

    #
    # Find DatasetRegin from the files, and merge
    # with existing datasetRegion if found in the xml-file
    #
    my $ncRegion = getDatasetRegion( keys %all_variables );    # get a merged region from all files
    my $dsRegion = $ds->getDatasetRegion;
    $dsRegion->addRegion($ncRegion);
    $ds->setDatasetRegion($dsRegion);

    # start and stop date need special handling
    {
        my $start_date = ( delete $metadata{'start_date'} )->[0] if exists $metadata{'start_date'};
        if ($start_date) {
            $metadata{'datacollection_period_from'} = [ substr( $start_date, 0, 10 ) ];
        }
        my $stop_date = ( delete $metadata{'stop_date'} )->[0] if exists $metadata{'stop_date'};
        if ($stop_date) {
            $metadata{'datacollection_period_to'} = [ substr( $stop_date, 0, 10 ) ];
        }
    }

    # using bounding_box instead of *_latitude, *_longitude
    my $south = ( delete $metadata{'southernmost_latitude'} )->[0] if exists $metadata{'southernmost_latitude'};
    my $north = ( delete $metadata{'northernmost_latitude'} )->[0] if exists $metadata{'northernmost_latitude'};
    my $east  = ( delete $metadata{'easternmost_longitude'} )->[0] if exists $metadata{'easternmost_longitude'};
    my $west  = ( delete $metadata{'westernmost_longitude'} )->[0] if exists $metadata{'westernmost_longitude'};
    if ( defined $south and defined $north and defined $east and defined $west ) {
        $metadata{'bounding_box'} = ["$east,$south,$west,$north"];
    }

    # Add information about the actual data file that can be used by the collection basket.
    if ( $isChild && $destination_path ) {
        $metadata{data_file_location} = [$destination_path];

        # This is an ugly assumption, but it works. Since we are in child mode
        # we know that there is only one path in %all_variables
        my $fpath          = ( keys %all_variables )[0];
        my $data_file_size = ( stat($fpath) )[7];
        $metadata{data_file_size} = [$data_file_size];
    }

    # add all metadata
    if ( $CTR_printdump == 1 ) {
        print STDOUT "\n----- NEW METADATA -----\n\n";
        print STDOUT Dumper( \%info, \%metadata );
    }
    $ds->addMetadata( \%metadata );

    # write the file
    if ( $xml_metadata_path ne "TESTFILE" ) {
        $ds->writeToFile($xml_metadata_path);
    }

    if ( $CTR_printdump == 1 ) {
        print STDOUT "\n----- VARIABLES FOUND -----\n\n";
        print STDOUT Dumper( \%all_variables );
        print STDOUT "\n\n----- GLOBAL ATTRIBUTES FOUND -----\n\n";
        print STDOUT Dumper( \%all_globatts );
        print STDOUT "\n\n=================================================\n";
    }
}

#
#---------------------------------------------------------------------------------
#
sub rule_all_equal {
    my ( $rule, $attname, $ref, $ref_all_globatts, $ref_metadata ) = @_;
    my $firstvalue;
    my $lastvalue;
    if ( exists( $ref_metadata->{$attname} ) ) {
        $firstvalue = $ref_metadata->{$attname}->[0];
        $lastvalue  = $ref_metadata->{$attname}->[0];
    }
    my $all_equal = 1;
    foreach my $fpath ( keys %$ref_all_globatts ) {
        my $attref = $ref_all_globatts->{$fpath};
        if ( exists( $attref->{$attname} ) ) {
            my $refval = $attref->{$attname};
            if ( ref($refval) ne "ARRAY" ) {
                die 'parse_all: ref($refval) ne "ARRAY" in $all_globatts{$fpath}';
            }
            if ( scalar @$refval > 0 ) {
                if ( !defined($firstvalue) ) {
                    $firstvalue = $refval->[0];
                } else {
                    if ( $firstvalue ne $refval->[0] ) {
                        $all_equal = 0;
                    }
                }
                $lastvalue = $refval->[0];
            }
        }
    }
    if ( $all_equal == 0 ) {
        if ( $rule =~ /^all_should_be_equal_IFNOT_take_/ ) {
            if ( exists( $ref->{"errmsg"} ) ) {
                &add_errmsg( "Global_attribute: $attname", $ref->{"errmsg"} );
            }
        }
    }
    if ( $all_equal == 1 || $rule eq "all_should_be_equal_IFNOT_take_first" ) {
        if ( defined($firstvalue) ) {
            $ref_metadata->{$attname} = [$firstvalue];
        }
    } elsif ( $rule eq "all_should_be_equal_IFNOT_take_last" ) {
        if ( defined($lastvalue) ) {
            $ref_metadata->{$attname} = [$lastvalue];
        }
    }
}

#
#---------------------------------------------------------------------------------
#
sub rule_highlow {
    my ( $rule, $attname, $ref_all_globatts, $ref_metadata ) = @_;
    my $selectedvalue;
    if ( exists( $ref_metadata->{$attname} ) ) {
        $selectedvalue = $ref_metadata->{$attname}->[0];
    }
    foreach my $fpath ( keys %$ref_all_globatts ) {
        my $attref = $ref_all_globatts->{$fpath};
        if ( exists( $attref->{$attname} ) ) {
            my $refval = $attref->{$attname};
            if ( ref($refval) ne "ARRAY" ) {
                die 'parse_all: ref($refval) ne "ARRAY" in $all_globatts{$fpath}';
            }
            if ( defined( $refval->[0] ) ) {
                if ( !defined($selectedvalue) ) {
                    $selectedvalue = $refval->[0];
                } else {
                    if ( $rule eq "take_highest" && $selectedvalue < $refval->[0] ) {
                        $selectedvalue = $refval->[0];
                    } elsif ( $rule eq "take_lowest" && $selectedvalue > $refval->[0] ) {
                        $selectedvalue = $refval->[0];
                    }
                }
            }
        }
    }
    if ($selectedvalue) {
        $ref_metadata->{$attname} = [$selectedvalue];
    }
}

#
#---------------------------------------------------------------------------------
#
sub rule_highlow_date {
    my ( $rule, $attname, $ref_all_globatts, $ref_metadata ) = @_;
    my @dates = ();
    my $selectedvalue;
    if ( exists( $ref_metadata->{$attname} ) ) {
        $selectedvalue = $ref_metadata->{$attname}->[0];
        push( @dates, $selectedvalue );
    }
    foreach my $fpath ( keys %$ref_all_globatts ) {
        my $attref = $ref_all_globatts->{$fpath};
        if ( exists( $attref->{$attname} ) ) {
            my $refval = $attref->{$attname};
            if ( ref($refval) ne "ARRAY" ) {
                die 'parse_all: ref($refval) ne "ARRAY" in $all_globatts{$fpath}';
            }
            if ( defined( $refval->[0] ) ) {
                push( @dates, $refval->[0] );
            }
        }
    }
    if ( scalar @dates > 0 ) {
        my @dates_sorted = sort(@dates);
        if ( $rule eq "take_highest_date" ) {
            $selectedvalue = pop(@dates_sorted);
        } else {
            $selectedvalue = shift(@dates_sorted);
        }
        $ref_metadata->{$attname} = [$selectedvalue];
    }
}

#
#---------------------------------------------------------------------------------
#
sub rule_take_union {
    my ( $attname, $ref_all_globatts, $ref_metadata ) = @_;
    my %values = ();
    if ( exists( $ref_metadata->{$attname} ) ) {
        foreach my $val ( @{ $ref_metadata->{$attname} } ) {
            $values{$val} = 1;
        }
    }
    foreach my $fpath ( keys %$ref_all_globatts ) {
        my $attref = $ref_all_globatts->{$fpath};
        if ( exists( $attref->{$attname} ) ) {
            my $refval = $attref->{$attname};
            if ( ref($refval) ne "ARRAY" ) {
                die 'parse_all: ref($refval) ne "ARRAY" in $all_globatts{$fpath}';
            }
            foreach my $val (@$refval) {
                $values{$val} = 1;
            }
        }
    }
    $ref_metadata->{$attname} = [ keys %values ];
}

#
#---------------------------------------------------------------------------------
#
sub getDatasetRegion {
    my @ncFiles = @_;
    my $region  = new Metamod::DatasetRegion();
    foreach my $f (@ncFiles) {
        my $nc = MetNo::NcFind->new($f);
        eval {
            my %bb = $nc->findBoundingBoxByGlobalAttributes(
                qw(northernmost_latitude southernmost_latitude easternmost_longitude westernmost_longitude));
            $region->extendBoundingBox( \%bb );
        };
        if ($@) {
            warn $@;
        }
        my %lonLatInfo = $nc->extractCFLonLat;
        foreach my $polygon ( @{ $lonLatInfo{polygons} } ) {
            $region->addPolygon($polygon);
        }
        foreach my $p ( @{ $lonLatInfo{points} } ) {
            $region->addPoint($p);
        }

    }
    return $region;
}

=head2 parse_file( $fpath, $xml_metadata_path )

This subroutine parses one netCDF file given by the file or URL path $fpath

=over 4

=item $fpath

=item $xml_metadata_path (optional)

=back

=cut

sub parse_file {

    my ( $fpath, $xml_metadata_path ) = @_;

    #
    #  Do any changes to the rule hashes (RH) that are prescribed for this
    #  netCDF file. Also initialize list and switch hashes (LSH).
    #
    my $found_struct = 0;
    foreach my $structname ( keys %structures ) {
        my $regex = $structures{$structname};
        if ( ref($regex) ) {
            die 'parse_file: Value in %structures hash is a reference';
        }
        if ( $xml_metadata_path =~ /$regex/ ) {
            if ( $structname ne $current_struct ) {
                &update_RH($structname);
                $current_struct = $structname;
            }
            &update_LSH($structname);
            $found_struct = 1;
            last;
        }
    }
    if ( $found_struct == 0 ) {
        if ( $current_struct ne "" ) {
            &update_RH("");
            $current_struct = "";
        }
        &update_LSH("");
    }

    #
    my %foundvars     = ();
    my %foundglobatts = ();

    #
    #  Preliminary parsing of global attributes and variables.
    #
    #  Set %foundglobatts to global attributes actually found, with keys equal to
    #  global attribute name, and values equal to values actually found.
    #
    #  Set %foundvars to variables actually found. Keys are equal to variable name.
    #  Value is a reference to a hash with the following values:
    #
    #  $founvars{}->{"attributes"}   Reference to hash of attribute names pointing
    #                                to attribute values
    #  $founvars{}->{"dimensions"}   Reference to array of dimensions containing
    #                                dimension names
    #  $founvars{}->{"type"}         Scalar string telling the varaible type.
    #                                Possible values: '%Data', '%Coordinate',
    #                                '%Coordinate_X', '%Coordinate_Y', '%Coordinate_Z',
    #                                '%Coordinate_T'.
    #  $founvars{}->{"stdname"}      Value of standard name attribute, if found
    #                                (otherwise "").
    #  $founvars{}->{"dimcount"}     Number of dimensions
    #
    #  Open new ncfind object (see ncfind.pm):
    #
    my $ncfindobj = MetNo::NcFind->new($fpath);
    foreach my $attname ( $ncfindobj->globatt_names() ) {
        my $attval = $ncfindobj->globatt_value($attname);

        #
        #  Normalise. Convert sequences of spaces and tabs to one space:
        #
        $attval =~ s/[ \t][ \t]+/ /mg;
        my $attname1 = $attname;
        if ( exists( $RH_attribute_aliases{$attname} ) ) {
            $attname1 = $RH_attribute_aliases{$attname};
            if ( exists( $RH_attribute_aliases{ $attname1 . ':errmsg' } ) ) {
                my $errmsg = $RH_attribute_aliases{ $attname1 . ':errmsg' };
                &add_errmsg( "File: $fpath\nAttribute: $attname", $errmsg );
            }
        }
        $foundglobatts{$attname1} = $attval;
        if ($CTR_printnc) {
            if ( $attname eq $attname1 ) {
                print STDOUT "Global attribute: $attname = $attval\n";
            } else {
                print STDOUT "Global attribute: $attname ($attname1) = $attval\n";
            }
        }
    }
    my @nc_variables = $ncfindobj->variables();
    foreach my $varname (@nc_variables) {
        $foundvars{$varname} = {
            attributes => {},
            dimensions => [],
            type       => "",
            stdname    => "",
            dimcount   => 0,
        };
        if ( exists( $LSH_globlists{'%LEGALVARNAME'} ) ) {
            &add_each_value_to_list( '%LEGALVARNAME', [$varname] );
        }
        foreach my $attname ( $ncfindobj->att_names($varname) ) {
            my $attval = $ncfindobj->att_value( $varname, $attname );

            #
            #  Normalise. Convert sequences of spaces and tabs to one space:
            #
            $attval =~ s/[ \t][ \t]+/ /mg;
            my $attname1 = $attname;
            if ( exists( $RH_attribute_aliases{$attname} ) ) {
                $attname1 = $RH_attribute_aliases{$attname};
                if ( exists( $RH_attribute_aliases{ $attname1 . ':errmsg' } ) ) {
                    my $errmsg = $RH_attribute_aliases{ $attname1 . ':errmsg' };
                    &add_errmsg( "File: $fpath\nVariable: $varname\nAttribute: $attname", $errmsg );
                }
            }
            $foundvars{$varname}->{"attributes"}->{$attname1} = $attval;
            if ($CTR_printnc) {
                if ( $attname eq $attname1 ) {
                    print STDOUT "Variable attribute: $varname:$attname = $attval\n";
                } else {
                    print STDOUT "Variable attribute: $varname:$attname ($attname1) = $attval\n";
                }
            }
            if ( $attname1 eq "standard_name" ) {
                $foundvars{$varname}->{"stdname"} = $attval;
            }
        }
        $foundvars{$varname}->{"dimensions"} = [];
        foreach my $dimname ( $ncfindobj->dimensions($varname) ) {
            unshift( @{ $foundvars{$varname}->{"dimensions"} }, $dimname );
        }
        $foundvars{$varname}->{"dimcount"} = scalar @{ $foundvars{$varname}->{"dimensions"} };
    }

    #
    #  Parse the global attributes. Modify values if neccessary. Add to error messages.
    #
    foreach my $attname ( keys %foundglobatts ) {
        my $attval = $foundglobatts{$attname};
        my @values_array = &extract_global_attribute( $fpath, $attname, $attval );
        $foundglobatts{$attname} = [@values_array];
    }

    #
    #  Classify variables into the following types:
    #
    #  %Data             - The variable represents a physical entity and is not used
    #                      as a coordinate for other variables.
    #  %Data_grid        - A data variable with dimensions indicating a 2D grid
    #                      (usually combined with other dimensions).
    #  %Coordinate       - The variable is used as a coordinate, but the coordinate
    #                      type is undecided
    #  %Coordinate_T     - The variable is used as a time coordinate
    #  %Coordinate_X     - The variable is used as a coordinate for the X axis
    #                      (usually having name longitude or Xc).
    #  %Coordinate_Y     - The variable is used as a coordinate for the Y axis
    #                      (usually having name latitude or Yc).
    #  %Coordinate_Z     - Vertical coordinate
    #
    my %vars_with_preset_type = ();
    foreach my $varname ( keys %foundvars ) {
        my $vref = $foundvars{$varname};
        if ( exists( $RH_variabletypes{$varname} ) ) {
            $vref->{"type"} = $RH_variabletypes{$varname};
            $vars_with_preset_type{$varname} = 1;
        } else {
            foreach my $rex ( grep { m!^/.*/$! } keys %RH_variabletypes ) {
                my $j1 = length($rex) - 2;
                my $rex1 = substr( $rex, 1, $j1 );
                if ( $varname =~ /$rex1/ ) {
                    $vref->{"type"} = $RH_variabletypes{$rex};
                    $vars_with_preset_type{$varname} = 1;
                    last;
                }
            }
        }
    }
    foreach my $varname ( keys %foundvars ) {
        my $vref = $foundvars{$varname};
        if ( exists( $vref->{"attributes"}->{"coordinates"} ) ) {
            if ( !exists( $vars_with_preset_type{$varname} ) ) {
                $vref->{"type"} = '%Data';
            }
            my $coordinates = $vref->{"attributes"}->{"coordinates"};
            foreach my $coord ( split( /\s+/, $coordinates ) ) {
                if ( exists( $foundvars{$coord} ) ) {
                    if ( substr( $foundvars{$coord}->{"type"}, 0, 5 ) eq '%Data' ) {
                        &add_errmsg( "File: $fpath\nVariable: $coord", "data_variable_used_as_coordinate" );
                    } else {
                        if ( !exists( $vars_with_preset_type{$coord} ) ) {
                            $foundvars{$coord}->{"type"} = '%Coordinate';
                        }
                    }
                } else {
                    &add_errmsg( "File: $fpath\nVariable: $varname\nCoordinate: $coord",
                        "coordinate_variable_not_found" );
                }
            }
        }
        my $dimcount           = 0;
        my $dimname_is_varname = 0;
        foreach my $dimname ( @{ $vref->{"dimensions"} } ) {
            if ( $dimname eq $varname ) {
                $dimname_is_varname = 1;
            } elsif ( exists( $foundvars{$dimname} ) ) {
                if ( substr( $foundvars{$dimname}->{"type"}, 0, 5 ) eq '%Data' ) {
                    &add_errmsg( "File: $fpath\nVariable: $dimname", "data_variable_used_as_coordinate" );
                } else {
                    if ( !exists( $vars_with_preset_type{$dimname} ) ) {
                        $foundvars{$dimname}->{"type"} = '%Coordinate';
                    }
                }
            }
            $dimcount++;
        }
        $vref->{"dimcount"} = $dimcount;
        if ( $dimname_is_varname && $dimcount == 1 ) {
            if ( substr( $vref->{"type"}, 0, 5 ) eq '%Data' ) {
                &add_errmsg( "File: $fpath\nVariable: $varname", "data_variable_used_as_coordinate" );
            } else {
                if ( !exists( $vars_with_preset_type{$varname} ) ) {
                    $vref->{"type"} = '%Coordinate';
                }
            }
        }
    }
    my $axis_from_stdname = {
        "latitude"                                    => "_Y",
        "projection_y_coordinate"                     => "_Y",
        "longitude"                                   => "_X",
        "projection_x_coordinate"                     => "_X",
        "height"                                      => "_Z",
        "geopotential_height"                         => "_Z",
        "atmosphere_hybrid_height_coordinate"         => "_Z",
        "altitude"                                    => "_Z",
        "depth"                                       => "_Z",
        "air_pressure"                                => "_Z",
        "atmosphere_hybrid_sigma_pressure_coordinate" => "_Z",
        "atmosphere_ln_pressure_coordinate"           => "_Z",
        "sea_water_pressure"                          => "_Z",
        "atmosphere_sigma_coordinate"                 => "_Z",
        "atmosphere_sleve_coordinate"                 => "_Z",
        "land_ice_sigma_coordinate"                   => "_Z",
        "ocean_s_coordinate"                          => "_Z",
        "ocean_sigma_coordinate"                      => "_Z",
    };
    foreach my $varname ( keys %foundvars ) {
        my $vref = $foundvars{$varname};
        if ( !exists( $vars_with_preset_type{$varname} ) ) {
            if ( substr( $vref->{"type"}, 0, 5 ) ne '%Data' ) {
                if ( exists( $vref->{"attributes"}->{"axis"} ) ) {
                    $vref->{"type"} = '%Coordinate_' . $vref->{"attributes"}->{"axis"};
                } elsif ( exists( $vref->{"attributes"}->{"units"} ) ) {
                    my $units = $vref->{"attributes"}->{"units"};
                    if ( &check_escape( '%TIMEUNIT', $units ) == 1 ) {
                        $vref->{"type"} = '%Coordinate_T';
                    }
                }
            }
        }
        if ( $vref->{"type"} eq "" ) {
            $vref->{"type"} = '%Data';
        }
        if ( $vref->{"type"} eq '%Coordinate' ) {
            if ( !exists( $vars_with_preset_type{$varname} ) ) {
                if ( exists( $vref->{"stdname"} ) ) {
                    my $stdname = $vref->{"stdname"};
                    if ( $vref->{"dimcount"} == 1 && exists( $axis_from_stdname->{$stdname} ) ) {
                        $vref->{"type"} .= $axis_from_stdname->{$stdname};
                    }
                }
            }
        }
    }
    foreach my $varname ( keys %foundvars ) {
        if ( !exists( $vars_with_preset_type{$varname} ) ) {
            my $vref = $foundvars{$varname};
            if ( $vref->{"type"} eq '%Data' ) {
                my $found_X = 0;
                my $found_Y = 0;
                foreach my $dimname ( @{ $vref->{"dimensions"} } ) {
                    if ( exists( $foundvars{$dimname} ) ) {
                        if ( $foundvars{$dimname}->{"type"} eq '%Coordinate_X' ) {
                            $found_X++;
                        } elsif ( $foundvars{$dimname}->{"type"} eq '%Coordinate_Y' ) {
                            $found_Y++;
                        }
                    }
                }
                if ( $found_X == 1 && $found_Y == 1 ) {
                    $vref->{"type"} = '%Data_grid';
                }
            }
        }
    }
    if ( ref($RH_investigatedims) eq "ARRAY" ) {

        #
        #     Further classification of data variables based on the %investigatedims hash:
        #
        foreach my $varname ( keys %foundvars ) {
            my $vref = $foundvars{$varname};
            if ( substr( $vref->{"type"}, 0, 5 ) eq '%Data' ) {
                my $dimstring = join( ",", @{ $vref->{"dimensions"} } );
                foreach my $href (@$RH_investigatedims) {
                    if ( ref($href) ne "HASH" ) {
                        die 'parse_file: Element in array @$RH_investigatedims not a HASH ref';
                    }
                    if ( exists( $href->{"rex"} ) ) {
                        my $rex = $href->{"rex"};
                        if ( my @matches = ( $dimstring =~ /$rex/ ) ) {
                            if ( exists( $href->{"addmatches"} ) ) {
                                my @lists = split( /\s+/, $href->{"addmatches"} );
                                foreach my $lst (@lists) {
                                    my $dimname = shift(@matches);
                                    if ( defined($dimname) ) {
                                        &add_each_value_to_list( $lst, [$dimname] );
                                    }
                                }
                            }
                            if ( exists( $href->{"extendtype"} ) ) {

                                #
                                #                       If the extention is not already there, extend the type:
                                my $len = length( $href->{"extendtype"} );
                                if ( substr( $vref->{"type"}, -$len ) ne $href->{"extendtype"} ) {
                                    $vref->{"type"} .= $href->{"extendtype"};
                                }
                            }
                            last;
                        }
                    }
                }
            }
        }
    }

    #
    #  Set global switches corresponding to the variable types found:
    #  These global switches are created here, they are not found in the
    #  %globswitches hash.
    #
    foreach my $varname ( keys %foundvars ) {
        my $vref = $foundvars{$varname};
        $LSH_globswitches{ $vref->{"type"} } = 1;
    }

    #
    #  Parse the variables. Modify attribute values if neccessary. Add to error messages.
    #
    foreach my $varname ( keys %foundvars ) {
        my $vref              = $foundvars{$varname};
        my $vartype           = $vref->{"type"};
        my $continue_varcheck = 1;
        my $name_or_type_key  = $vartype;
        if ( exists( $RH_variables{$varname} ) ) {
            $name_or_type_key = $varname;
        }
        if ( exists( $RH_variables{$name_or_type_key} ) ) {
            my $refval = $RH_variables{$name_or_type_key};
            if ( ref($refval) ne "HASH" ) {
                die 'parse_file: $RH_variables{$name_or_type_key} is not a reference to HASH';
            }
            if ( exists( $refval->{"condition"} ) ) {
                my $switch = $refval->{"condition"};
                if ( !exists( $LSH_globswitches{$switch} ) ) {
                    die 'parse_file: $LSH_globswitches{$switch} not defined';
                }
                $continue_varcheck = $LSH_globswitches{$switch};
            }
            if ( exists( $refval->{"if_in_list"} ) ) {
                my $list = $refval->{"if_in_list"};
                if ( !exists( $LSH_globlists{$list} ) ) {
                    die 'parse_file: $LSH_globslists{$list} not defined';
                }
                my $rex = '^' . $varname . '$';
                my @matches = grep( /$rex/, @{ $LSH_globlists{$list} } );
                if ( scalar @matches == 0 ) {
                    $continue_varcheck = 0;
                }
            }
        }
        if ($continue_varcheck) {
            foreach my $attname ( keys %{ $vref->{"attributes"} } ) {
                my $attval = $vref->{"attributes"}->{$attname};
                my $what   = "File: $fpath\nVariable: $varname\nAttribute: $attname";
                if ( exists( $RH_attributes{"$name_or_type_key,$attname"} ) ) {
                    my $refval       = $RH_attributes{"$name_or_type_key,$attname"};
                    my @values_array = ($attval);
                    if ( exists( $refval->{"multivalue"} ) ) {
                        @values_array = &do_multivalue( $refval->{"multivalue"}, $attval );
                    } elsif ( exists( $refval->{"breaklines"} ) ) {
                        @values_array = &do_breaklines( $refval->{"breaklines"}, $attval );
                    }
                    if ( exists( $refval->{"vocabulary"} ) ) {
                        if ( !exists( $RH_vocabularies{"$name_or_type_key,$attname"} ) ) {
                            die 'parse_file: Vocabulary missing in $RH_vocabularies';
                        }
                        my $refvocab = $RH_vocabularies{"$name_or_type_key,$attname"};
                        @values_array = &do_vocabulary( $what, $varname, $refvocab, \@values_array );
                    }
                    if ( exists( $refval->{"mandatory_values"} ) ) {
                        &check_mandatory_values( $refval->{"mandatory_values"}, \@values_array );
                    }
                    if ( exists( $refval->{"add_each_value_to_list"} ) ) {
                        &add_each_value_to_list( $refval->{"add_each_value_to_list"}, \@values_array );
                    }
                    $foundvars{$varname}->{"attributes"}->{$attname} = [@values_array];
                }
            }
        }
    }

    #
    #  Set global attributes that are hardcoded in the configuration file:
    #
    foreach my $attname ( keys %RH_presetattributes ) {
        my $attval = $RH_presetattributes{$attname};
        my @values_array = &extract_global_attribute( $fpath, $attname, $attval );
        $foundglobatts{$attname} = [@values_array];
    }
    if ( $CTR_printdump == 1 ) {
        print STDOUT "----- Content of global lists: -----\n";
        print STDOUT Dumper( \%LSH_globlists );
        print STDOUT "----- Content of global switches: -----\n";
        print STDOUT Dumper( \%LSH_globswitches );
    }

    #
    # Check that all mandatory global attributes are present:
    #
    foreach my $hkey ( grep { /^global_attributes,/ } keys %RH_attributes ) {
        my $attname     = substr( $hkey, 18 );
        my $refval      = $RH_attributes{$hkey};
        my $send_errmsg = 0;
        if ( exists( $refval->{"mandatory"} ) ) {
            if ( ref( $refval->{"mandatory"} ) ne "ARRAY" ) {
                die 'parse_file: $refval->{"mandatory"} is not a reference to ARRAY';
            }
            my $ref = $refval->{"mandatory"}->[0];
            if ( ref($ref) ne "HASH" ) {
                die 'parse_file: $refval->{"mandatory"}->[0] is not a reference to HASH';
            }
            if ( exists( $ref->{"only_if"} ) ) {
                my $switch = $ref->{"only_if"};
                my $is_set = 0;
                if ( exists( $LSH_globswitches{$switch} ) && $LSH_globswitches{$switch} == 1 ) {
                    $is_set = 1;
                }
                if ( $is_set == 1 && !exists( $foundglobatts{$attname} ) ) {
                    $send_errmsg = 1;
                }
            } else {
                if ( !exists( $foundglobatts{$attname} ) ) {
                    $send_errmsg = 1;
                }
            }
            if ( $send_errmsg == 1 ) {
                if ( exists( $ref->{"errmsg"} ) ) {
                    &add_errmsg( "File: $fpath\nGlobal_attribute: $attname", $ref->{"errmsg"} );
                }
            }
        }
    }

    #
    #   Check dimensions:
    #
    foreach my $varname ( keys %foundvars ) {
        my $vref    = $foundvars{$varname};
        my $vartype = $vref->{"type"};
        if ( exists( $RH_variabletypes{$varname} ) ) {
            $vartype = $RH_variabletypes{$varname};
        } else {
            foreach my $rex ( grep { m:^/.*/$: } keys %RH_variabletypes ) {
                my $j1 = length($rex) - 2;
                my $rex1 = substr( $rex, 1, $j1 );
                if ( $varname =~ /$rex1/ ) {
                    $vartype = $RH_variabletypes{$rex};
                    last;
                }
            }
        }
        my $name_or_type_key = $vartype;
        if ( exists( $RH_variables{$varname} ) ) {
            $name_or_type_key = $varname;
        }
        if ( exists( $RH_dimensions{$name_or_type_key} ) ) {
            my $ref       = $RH_dimensions{$name_or_type_key};
            my $dimarr    = $foundvars{$varname}->{"dimensions"};
            my $dimstring = "";
            if ( scalar @$dimarr > 0 ) {
                $dimstring = join( ",", @$dimarr );
            }
            my $what = "File: $fpath\nVariable: $varname\nDimensions: $dimstring";
            &do_dimensions( $what, $varname, $ref, $dimstring );
        }
    }

    #
    #   Check that all mandatory variables and variable types are present:
    #
    foreach my $name_or_type_key ( keys %RH_variables ) {
        my $refval = $RH_variables{$name_or_type_key};
        if ( ref($refval) ne "HASH" ) {
            die 'parse_file: $RH_variables{$name_or_type_key} is not a reference to HASH';
        }
        my $mandatory_checking = 1;
        if ( exists( $refval->{"condition"} ) ) {
            $mandatory_checking = 0;
            my $switch = $refval->{"condition"};
            if ( exists( $LSH_globswitches{$switch} ) && $LSH_globswitches{$switch} ) {
                $mandatory_checking = 1;
            }
        }
        my $is_mandatory      = 0;
        my @varnamearr        = ();
        my $var_or_type_found = 0;
        if ( substr( $name_or_type_key, 0, 1 ) eq '%' ) {
            foreach my $varname ( keys %foundvars ) {
                if ( $foundvars{$varname}->{"type"} eq $name_or_type_key ) {
                    $var_or_type_found = 1;
                    push( @varnamearr, $varname );
                }
            }
        } else {
            if ( exists( $foundvars{$name_or_type_key} ) ) {
                $var_or_type_found = 1;
                push( @varnamearr, $name_or_type_key );
            }
        }
        if ( exists( $refval->{"mandatory"} ) ) {
            if ( ref( $refval->{"mandatory"} ) ne "ARRAY" ) {
                die 'parse_file: $refval->{"mandatory"} is not an ARRAY reference';
            }
            my $ref = $refval->{"mandatory"}->[0];
            if ( ref($ref) ne "HASH" ) {
                die 'parse_file: $refval->{"mandatory"}->[0] is not a HASH reference';
            }
            if ( exists( $ref->{"only_if"} ) ) {
                my $switch = $ref->{"only_if"};
                if ( exists( $LSH_globswitches{$switch} ) && $LSH_globswitches{$switch} == 1 ) {
                    $is_mandatory = 1;
                }
            } else {
                $is_mandatory = 1;
            }
            if ( $is_mandatory == 1 && $var_or_type_found == 0 ) {
                if ( exists( $ref->{"errmsg"} ) ) {
                    &add_errmsg( "File: $fpath\nVariable/type: $name_or_type_key", $ref->{"errmsg"} );
                }
            }
        }

        #
        #   Check that all mandatory attributes in the variables are present:
        #
        my $rex = '^' . $name_or_type_key . ',';
        my $len = length($rex) - 1;
        foreach my $hkey ( grep { /$rex/ } keys %RH_attributes ) {
            my $attname = substr( $hkey, $len );
            my $refval = $RH_attributes{$hkey};
            if ( exists( $refval->{"mandatory"} ) ) {
                if ( ref( $refval->{"mandatory"} ) ne "ARRAY" ) {
                    die 'parse_file: $refval->{"mandatory"} is not a reference to ARRAY';
                }
                my $ref = $refval->{"mandatory"}->[0];
                if ( ref($ref) ne "HASH" ) {
                    die 'parse_file: $refval->{"mandatory"}->[0] is not a reference to HASH';
                }
                my $is_mandatory = 0;
                my $switch       = "";
                if ( exists( $ref->{"only_if"} ) ) {
                    $switch = $ref->{"only_if"};
                    if ( exists( $LSH_globswitches{$switch} ) && $LSH_globswitches{$switch} == 1 ) {
                        $is_mandatory = 1;
                    }
                } else {
                    $is_mandatory = 1;
                }
                if ( $is_mandatory || $switch eq "DIMNAME_IS_VARNAME" ) {
                    foreach my $varname (@varnamearr) {
                        if ( exists( $foundvars{$varname} ) ) {
                            my $vref               = $foundvars{$varname};
                            my $continue_the_check = 1;
                            if ( $switch eq "DIMNAME_IS_VARNAME" ) {
                                if ( $vref->{"dimcount"} != 1 || $varname ne $vref->{"dimensions"}->[0] ) {
                                    $continue_the_check = 0;
                                }
                            }
                            if ( $continue_the_check && !exists( $vref->{"attributes"}->{$attname} ) ) {
                                if ( exists( $ref->{"errmsg"} ) ) {
                                    my $what = "File: $fpath\nVariable: $varname\nAttribute: $attname";
                                    &add_errmsg( $what, $ref->{"errmsg"} );
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return ( \%foundvars, \%foundglobatts );
}

#
#---------------------------------------------------------------------------------
#
sub update_RH {
    my ($structname) = @_;
    my $rex          = '^' . $structname . ',';
    my $len          = length($rex) - 1;

    #
    #     Update %RH_attributes:
    #
    foreach my $hkey ( keys %RH_attributes ) {
        delete( $RH_attributes{$hkey} );
    }
    foreach my $hkey ( grep { /^default,/ } keys %attributes ) {
        my $newkey = substr( $hkey, 8 );
        $RH_attributes{$newkey} = $attributes{$hkey};
    }
    if ( $structname ne "" ) {
        foreach my $hkey ( grep { /$rex/ } keys %attributes ) {
            my $newkey = substr( $hkey, $len );
            $RH_attributes{$newkey} = $attributes{$hkey};
        }
    }

    #
    #     Update %RH_presetattributes:
    #
    foreach my $hkey ( keys %RH_presetattributes ) {
        delete( $RH_presetattributes{$hkey} );
    }
    foreach my $hkey ( grep { /^default,/ } keys %presetattributes ) {
        my $newkey = substr( $hkey, 8 );
        $RH_presetattributes{$newkey} = $presetattributes{$hkey};
    }
    if ( $structname ne "" ) {
        foreach my $hkey ( grep { /$rex/ } keys %presetattributes ) {
            my $newkey = substr( $hkey, $len );
            $RH_presetattributes{$newkey} = $presetattributes{$hkey};
        }
    }

    #
    #     Update %RH_vocabularies:
    #
    foreach my $hkey ( keys %RH_vocabularies ) {
        delete( $RH_vocabularies{$hkey} );
    }
    foreach my $hkey ( grep { /^default,/ } keys %vocabularies ) {
        my $newkey = substr( $hkey, 8 );
        $RH_vocabularies{$newkey} = $vocabularies{$hkey};
    }
    if ( $structname ne "" ) {
        foreach my $hkey ( grep { /$rex/ } keys %vocabularies ) {
            my $newkey = substr( $hkey, $len );
            $RH_vocabularies{$newkey} = $vocabularies{$hkey};
        }
    }

    #
    #     Update %RH_dimensions:
    #
    foreach my $hkey ( keys %RH_dimensions ) {
        delete( $RH_dimensions{$hkey} );
    }
    foreach my $hkey ( grep { /^default,/ } keys %dimensions ) {
        my $newkey = substr( $hkey, 8 );
        $RH_dimensions{$newkey} = $dimensions{$hkey};
    }
    if ( $structname ne "" ) {
        foreach my $hkey ( grep { /$rex/ } keys %dimensions ) {
            my $newkey = substr( $hkey, $len );
            $RH_dimensions{$newkey} = $dimensions{$hkey};
        }
    }

    #
    #     Update %RH_variables:
    #
    foreach my $hkey ( keys %RH_variables ) {
        delete( $RH_variables{$hkey} );
    }
    foreach my $hkey ( grep { /^default,/ } keys %variables ) {
        my $newkey = substr( $hkey, 8 );
        $RH_variables{$newkey} = $variables{$hkey};
    }
    if ( $structname ne "" ) {
        foreach my $hkey ( grep { /$rex/ } keys %variables ) {
            my $newkey = substr( $hkey, $len );
            $RH_variables{$newkey} = $variables{$hkey};
        }
    }

    #
    #     Update %RH_variabletypes:
    #
    foreach my $hkey ( keys %RH_variabletypes ) {
        delete( $RH_variabletypes{$hkey} );
    }
    foreach my $hkey ( grep { /^default,/ } keys %variabletypes ) {
        my $newkey = substr( $hkey, 8 );
        $RH_variabletypes{$newkey} = $variabletypes{$hkey};
    }
    if ( $structname ne "" ) {
        foreach my $hkey ( grep { /$rex/ } keys %variabletypes ) {
            my $newkey = substr( $hkey, $len );
            $RH_variabletypes{$newkey} = $variabletypes{$hkey};
        }
    }

    #
    #     Update %RH_attribute_aliases:
    #
    foreach my $hkey ( keys %RH_attribute_aliases ) {
        delete( $RH_attribute_aliases{$hkey} );
    }
    foreach my $hkey ( grep { /^default,/ } keys %attribute_aliases ) {
        my $newkey = substr( $hkey, 8 );
        $RH_attribute_aliases{$newkey} = $attribute_aliases{$hkey};
    }
    if ( $structname ne "" ) {
        foreach my $hkey ( grep { /$rex/ } keys %attribute_aliases ) {
            my $newkey = substr( $hkey, $len );
            $RH_attribute_aliases{$newkey} = $attribute_aliases{$hkey};
        }
    }

    #
    #     Update %RH_conversions:
    #
    foreach my $hkey ( keys %RH_conversions ) {
        delete( $RH_conversions{$hkey} );
    }
    foreach my $hkey ( grep { /^default,/ } keys %conversions ) {
        my $newkey = substr( $hkey, 8 );
        $RH_conversions{$newkey} = $conversions{$hkey};
    }
    if ( $structname ne "" ) {
        foreach my $hkey ( grep { /$rex/ } keys %conversions ) {
            my $newkey = substr( $hkey, $len );
            $RH_conversions{$newkey} = $conversions{$hkey};
        }
    }

    #
    #     Update $RH_investigatedims:
    #
    $RH_investigatedims = 0;
    if ( exists( $investigatedims{$structname} ) ) {
        $RH_investigatedims = $investigatedims{$structname};
    } elsif ( exists( $investigatedims{"default"} ) ) {
        $RH_investigatedims = $investigatedims{"default"};
    }
}

#
#---------------------------------------------------------------------------------
#
sub update_LSH {
    my ($structname) = @_;
    my $rex          = '^' . $structname . ',';
    my $len          = length($rex) - 1;

    #
    #   Initialize global switches:
    #
    foreach my $hkey ( keys %LSH_globswitches ) {
        delete( $LSH_globswitches{$hkey} );
    }
    foreach my $hkey ( grep { /^default,/ } keys %globswitches ) {
        my $newkey = substr( $hkey, 8 );
        $LSH_globswitches{$newkey} = $globswitches{$hkey};
    }
    if ( $structname ne "" ) {
        foreach my $hkey ( grep { /$rex/ } keys %globswitches ) {
            my $newkey = substr( $hkey, $len );
            $LSH_globswitches{$newkey} = $globswitches{$hkey};
        }
    }

    #
    #   Initialize global lists:
    #
    foreach my $list ( keys %globlists ) {
        $LSH_globlists{$list} = $globlists{$list};
    }
}

#
#---------------------------------------------------------------------------------
#
sub extract_global_attribute {
    my ( $fpath, $attname, $attval ) = @_;
    my $attkey       = "global_attributes," . $attname;
    my $what         = "File: $fpath\nGlobal_attribute: $attname";
    my @values_array = ($attval);
    if ( exists( $RH_attributes{$attkey} ) ) {
        my $refval = $RH_attributes{$attkey};
        if ( exists( $refval->{"multivalue"} ) ) {
            @values_array = &do_multivalue( $refval->{"multivalue"}, $attval );
        } elsif ( exists( $refval->{"breaklines"} ) ) {
            @values_array = &do_breaklines( $refval->{"breaklines"}, $attval );
        }
        if ( exists( $refval->{"convert"} ) ) {
            @values_array = &do_convert( $attkey, \@values_array );
        }
        if ( exists( $refval->{"vocabulary"} ) ) {
            if ( exists( $RH_vocabularies{$attkey} ) ) {
                my $refvocab = $RH_vocabularies{$attkey};
                @values_array = &do_vocabulary( $what, "global_attributes", $refvocab, \@values_array );
            } else {
                die 'parse_file: Vocabulary not found in $RH_vocabularies';
            }
        }
        if ( exists( $refval->{"add_each_value_to_list"} ) ) {
            &add_each_value_to_list( $refval->{"add_each_value_to_list"}, \@values_array );
        }
    }
    return @values_array;
}

#
#---------------------------------------------------------------------------------
#
sub do_multivalue {

    #
    #     Returns an array of values found by splitting the original value
    #     on the separator string $ref->{"separator"}.
    #
    my ( $refcontent, $origvalue ) = @_;
    if ( ref($refcontent) ne "ARRAY" ) {
        die('do_multivalue: $refcontent is not a reference to "ARRAY"');
    }
    my $ref = $refcontent->[0];
    if ( ref($ref) ne "HASH" ) {
        die('do_multivalue: $refcontent->[0] is not a reference to "HASH"');
    }
    if ( exists( $ref->{"separator"} ) ) {
        my $splitre = $ref->{"separator"};
        return grep( length($_) > 0, split( /$splitre/, $origvalue ) );
    } else {
        die("No separator in multilevel tag");
    }
}

#
#---------------------------------------------------------------------------------
#
sub do_breaklines {

    #
    #     Returns a modified version of the original value. Newlines are
    #     inserted to ensure no line is larger than the value given in the
    #     breakline tag.
    #
    my ( $refcontent, $origvalue ) = @_;
    if ( ref($refcontent) ne "ARRAY" ) {
        die('do_breaklines: $refcontent is not a reference to "ARRAY"');
    }
    my $ref = $refcontent->[0];
    if ( ref($ref) ne "HASH" ) {
        die('do_breaklines: $refcontent->[0] is not a reference to "HASH"');
    }
    my $newvalue = "";

    #
    #     Check if key exists in hash
    #
    if ( exists( $ref->{"value"} ) ) {

        #
        #       foreach value in an array
        #
        my $maxchars = $ref->{"value"};
        my $curchars = 0;
        foreach my $word ( split( / /, $origvalue ) ) {
            my $jlen = length($word);
            if ( $jlen + $curchars > $maxchars ) {
                $newvalue .= "\n";
                $curchars = 0;
            }
            $newvalue .= $word . ' ';
            $curchars += $jlen + 1;
        }
    } else {
        die "No value given in breakline tag";
    }
    return $newvalue;
}

#
#---------------------------------------------------------------------------------
#
sub do_vocabulary {

    #
    #     Check that attribute values correspond to a vocabulary.
    #     See '$parse_actions{"vocabulary"}'
    #
    #     Split argument array into variables
    #
    my ( $what, $globorvar, $refvocab, $valref ) = @_;
    if ( ref($valref) ne "ARRAY" ) {
        die('do_vocabulary: $valref is not a reference to "ARRAY"');
    }
    if ( ref($refvocab) ne "ARRAY" ) {
        die('do_vocabulary: $refvocab is not a reference to "ARRAY"');
    }
    my $contentref = $refvocab->[0];
    if ( ref($contentref) ne "ARRAY" ) {
        die('do_vocabulary: $contentref is not a reference to "ARRAY"');
    }
    my $rcontentref = $refvocab->[1];
    if ( ref($rcontentref) ne "ARRAY" ) {
        die('do_vocabulary: $rcontentref is not a reference to "ARRAY"');
    }
    my $mapcontentref = $refvocab->[2];
    if ( ref($mapcontentref) ne "ARRAY" ) {
        die('do_vocabulary: $mapcontentref is not a reference to "ARRAY"');
    }
    my $on_error = $refvocab->[3];
    if ( ref($on_error) ) {
        die('do_vocabulary: $on_error is not a scalar');
    }
    my $errmsg = $refvocab->[4];
    if ( ref($errmsg) ) {
        die('do_vocabulary: $errmsg is not a scalar');
    }
    my @values_array = ();

    #
    #     Find the number of elements in the vocabulary:
    #
    my $vcount = scalar @$contentref;

    #
    #     Create array for checking which vocabulary elements are found:
    #
    my @foundelements = ();
    for ( my $i1 = 0 ; $i1 < $vcount ; $i1++ ) {
        $foundelements[$i1] = 0;
    }

    #
    #     Foreach attribute value (usually just one):
    #
    foreach my $value (@$valref) {
        my $value_matches = 0;    # Set to 1 later if it does.

        #
        #        For each element in the vocabulary:
        #
        for ( my $i1 = 0 ; $i1 < $vcount ; $i1++ ) {
            my $matching_this_elt = 1;                     # Set to 0 later if it does not.
            my $rex               = $rcontentref->[$i1];
            if ( length( $mapcontentref->[$i1] ) > 0 ) {

                #
                #           This vocabulary element contains escapes. Ensure all escapes
                #           matches.
                #
                #           Create array containing matching ()-expressions:
                #           The string searched is in $value and the matches are put in @matches.
                #           The if-test is successful if the RE matches.
                #
                if ( my @matches = ( $value =~ /$rex/ ) ) {
                    my @map = split( / /, $mapcontentref->[$i1] );
                    my $matchcount = scalar @matches;
                    if ( $matchcount != scalar @map ) {
                        die 'do_vocabulary: Unexpected number of escapes from @mapcontent';
                    }
                    for ( my $i2 = 0 ; $i2 < $matchcount ; $i2++ ) {
                        if ( !&check_escape( $map[$i2], $matches[$i2] ) ) {
                            $matching_this_elt = 0;
                            last;
                        }
                    }
                } else {
                    $matching_this_elt = 0;
                }
            } else {

                #
                #           Vocabulary element without escapes:
                #
                if ( $value ne $rex ) {
                    $matching_this_elt = 0;
                }
            }
            if ( $matching_this_elt == 1 ) {

                #
                #           Set global switches if found:
                #
                my $rex1 = '^' . $globorvar . ',';
                foreach my $switch ( keys %LSH_globswitches ) {
                    if ( index( $contentref->[$i1], $switch ) >= 0 ) {
                        $LSH_globswitches{$switch} = 1;
                    }
                }
                $value_matches = 1;
                $foundelements[$i1] = 1;
                last;
            }
        }
        if ( $value_matches == 1 ) {
            push( @values_array, $value );
        } else {
            if ( $on_error eq "use" ) {
                push( @values_array, $value );
            } elsif ( $on_error eq "use_first_in_vocabulary" ) {
                push( @values_array, $rcontentref->[0] );
            }
            if ( $errmsg ne "" ) {
                &add_errmsg( $what . "\nValue: " . $value, $errmsg );
            }
        }
    }

    #
    #  Check that all mandatory elements are present:
    #
    for ( my $i1 = 0 ; $i1 < $vcount ; $i1++ ) {
        if ( $foundelements[$i1] == 0 && index( $contentref->[$i1], '%MANDATORY' ) >= 0 ) {
            my $attrib = $contentref->[$i1];
            $attrib =~ s/%MANDATORY//;
            if ( $errmsg ne "" ) {
                &add_errmsg( $what . "\nMandatory: " . $attrib, "missing_mandatory_attribute_value" );
            }
        }
    }
    return @values_array;
}

#
#---------------------------------------------------------------------------------
#
sub do_convert {
    my ( $attkey, $valuesref ) = @_;
    if ( ref($valuesref) ne "ARRAY" ) {
        die 'do_convert: $valuesref is not a reference to "ARRAY"';
    }
    my @values_array = ();
    foreach my $value (@$valuesref) {
        my $key = $attkey . ',' . $value;
        if ( exists( $RH_conversions{$key} ) ) {
            push( @values_array, $RH_conversions{$key} );
        } else {
            push( @values_array, $value );
        }
    }
    return @values_array;
}

#
#---------------------------------------------------------------------------------
#
sub add_each_value_to_list {
    my ( $listname, $valuesref ) = @_;
    if ( exists( $LSH_globlists{$listname} ) ) {
        my $listref = $LSH_globlists{$listname};
        if ( ref($valuesref) ne "ARRAY" ) {
            die 'add_each_value_to_list: $valuesref is not a reference to "ARRAY"';
        }
        foreach my $value (@$valuesref) {
            if ( scalar grep( $_ eq $value, @$listref ) == 0 ) {
                push( @$listref, $value );
            }
        }
    } else {
        die "add_each_value_to_list: List not found";
    }
}

#
#---------------------------------------------------------------------------------
#
sub do_dimensions {

    #
    #     Split argument array into variables
    #
    my ( $what, $varname, $refdim, $dimstring_found ) = @_;
    if ( ref($refdim) ne "ARRAY" ) {
        die('do_dimensions: $refdim is not a reference to "ARRAY"');
    }
    my $contentref = $refdim->[0];
    if ( ref($contentref) ne "ARRAY" ) {
        die('do_dimensions: $contentref is not a reference to "ARRAY"');
    }
    my $rcontentref = $refdim->[1];
    if ( ref($rcontentref) ne "ARRAY" ) {
        die('do_dimensions: $rcontentref is not a reference to "ARRAY"');
    }
    my $mapcontentref = $refdim->[2];
    if ( ref($mapcontentref) ne "ARRAY" ) {
        die('do_dimensions: $mapcontentref is not a reference to "ARRAY"');
    }
    my $on_error = $refdim->[3];
    if ( ref($on_error) ) {
        die('do_dimensions: $on_error is not a scalar');
    }
    my $errmsg = $refdim->[4];
    if ( ref($errmsg) ) {
        die('do_dimensions: $errmsg is not a scalar');
    }

    #
    #     Find the number of alternative dimension strings allowed:
    #
    my $dsetcount     = scalar @$contentref;
    my $value_matches = 0;                     # Set to 1 later if it does.

    #
    #     For each allowed dimension string:
    #
    for ( my $i1 = 0 ; $i1 < $dsetcount ; $i1++ ) {
        my $matching_this_elt = 1;                     # Set to 0 later if it does not.
        my $rex               = $rcontentref->[$i1];
        if ( length( $mapcontentref->[$i1] ) > 0 ) {

            #
            #        This dimension string contains escapes. Ensure all escapes
            #        matches.
            #
            #           Create array containing stings matching ()-expressions in $rex:
            #           The string searched is in $dimstring_found and the matching stings
            #           are put in @matches. The if-test is successful if the RE matches.
            #
            if ( my @matches = ( $dimstring_found =~ /$rex/ ) ) {
                my @map = split( / /, $mapcontentref->[$i1] );
                my $matchcount = scalar @matches;
                if ( $matchcount != scalar @map ) {
                    die "do_dimensions: Escape count mismatch";
                }
                for ( my $i2 = 0 ; $i2 < $matchcount ; $i2++ ) {
                    if ( !&check_escape( $map[$i2], $matches[$i2] ) ) {
                        $matching_this_elt = 0;
                        last;
                    }
                }
            } else {
                $matching_this_elt = 0;
            }
        } else {

            #
            #        Dimension string without escapes:
            #
            if ( $dimstring_found ne $rex ) {
                $matching_this_elt = 0;
            }
        }
        if ( $matching_this_elt == 1 ) {

            #
            #        Set global switches if found:
            #
            my $rex1 = '^' . $varname . ',';
            foreach my $switch ( keys %LSH_globswitches ) {
                if ( index( $contentref->[$i1], $switch ) >= 0 ) {
                    $LSH_globswitches{$switch} = 1;
                }
            }
            $value_matches = 1;
            last;
        }
    }
    if ( $value_matches == 0 ) {
        if ( $errmsg ne "" ) {
            &add_errmsg( $what, $errmsg );
        }
    }
}

#
#---------------------------------------------------------------------------------
#
sub convert_to_htmlentities {
    my ( $str, $conversions ) = @_;
    my @contarr = split( //, $str );
    my $result = "";
    foreach my $ch1 (@contarr) {
        if ( exists( $conversions->{$ch1} ) ) {
            $result .= $conversions->{$ch1};
        } else {
            $result .= $ch1;
        }
    }
    return $result;
}

#
#---------------------------------------------------------------------------------
#
sub add_errmsg {
    my ( $what, $errmsg ) = @_;
    push( @user_errors, $errmsg . "\n" . $what . "\n\n" );
}

#
#---------------------------------------------------------------------------------
#
sub check_escape {
    my ( $escape, $value ) = @_;
    if ( $escape eq '%ANYSTRING' ) {
        return 1;
    } elsif ( $escape eq '%NONE' ) {
        if ( $value eq "" ) {
            return 1;
        } else {
            return 0;
        }
    } elsif ( $escape eq '%SINGLEWORD' ) {
        if ( $value =~ /^\w+$/ ) {
            return 1;
        } else {
            return 0;
        }
    } elsif ( $escape eq '%ISODATE' ) {
        if ( $value =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/ ) {
            my $year  = $1;
            my $month = $2;
            my $day   = $3;
            if ( $month < 1 || $month > 12 ) {
                return 0;
            }
            if ( $day < 1 || $day > 31 ) {
                return 0;
            }
            return 1;
        } else {
            return 0;
        }
    } elsif ( $escape eq '%LATITUDE' ) {
        if ( $value =~ /^[+-]?(\d*\.\d+|\d+\.\d*|\d+)$/ ) {
            if ( $value >= -90.0 && $value <= 90.0 ) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    } elsif ( $escape eq '%LONGITUDE' ) {
        if ( $value =~ /^[+-]?(\d*\.\d+|\d+\.\d*|\d+)$/ ) {
            if ( $value >= -180.0 && $value <= 180.0 ) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    } elsif ( $escape eq '%hh' ) {
        if ( $value =~ /^\d\d$/ ) {
            if ( $value < 24 ) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    } elsif ( $escape eq '%mm' || $escape eq '%ss' ) {
        if ( $value =~ /^\d\d$/ ) {
            if ( $value < 60 ) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    } elsif ( $escape eq '%i' ) {
        if ( $value =~ /^\d+$/ ) {
            return 1;
        } else {
            return 0;
        }
    } elsif ( $escape eq '%EMAIL' ) {
    } elsif ( $escape eq '%TIMEUNIT' ) {
        if ( $value =~
/^(second|seconds|sec|secs|s|minute|minutes|min|mins|m|hour|hours|hr|hrs|h|day|days|d)\s+since\s+\d\d\d\d-\d+-\d+/
            ) {
            return 1;
        } else {
            return 0;
        }
    } elsif ( $escape eq '%CF_STANDARD_NAME' ) {
        if ( exists( $standard_names{$value} ) ) {
            return 1;
        } else {
            return 0;
        }
    } elsif ( $escape eq '%UDUNIT' ) {
    } elsif ( exists( $LSH_globlists{$escape} ) ) {
        my @matches = grep( $_ eq $value, @{ $LSH_globlists{$escape} } );
        if ( scalar @matches > 0 ) {
            return 1;
        } else {
            return 0;
        }
    }
    return 1;
}

1;

=head1 AUTHOR

Egil StE<248>ren, E<lt>egils\@met.noE<gt>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
