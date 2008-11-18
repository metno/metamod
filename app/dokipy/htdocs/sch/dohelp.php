<table cellspacing="5" border="0"><tr><td>
<div style="float: right; padding: 10px; margin: 5px; border: 1px solid #027abb; font-size: 75%">
<p class="hhd1c" style ="text-align: center">Content</p>
<p class="hhd1c"><a href="#purpose">Purpose</a></p>
 <p class="hhd1c"><a href="#search">Search categories</a></p>
 <p class="hhd2c"><a href="#topics">Topics and variables</a></p>
<p class="hhd2c"><a href="#activity">Activity types</a></p>
<p class="hhd2c"><a href="#opstatus">Operational status</a></p>
<p class="hhd2c"><a href="#institutions">Institutions</a></p>
<p class="hhd2c"><a href="#areas">Areas</a></p>
<p class="hhd2c"><a href="#mapsearch">Map search</a></p>
<p class="hhd2c"><a href="#period">Datacollection period</a></p>
<p class="hhd1c"><a href="#combining">Combining the search criteria</a></p>
<p class="hhd1c"><a href="#operational">The operational menu</a></p>
<p class="hhd2c"><a href="#results">[Show results]</a></p>
<p class="hhd2c"><a href="#twoway">[Two-way table]</a></p>
<p class="hhd2c"><a href="#options">[Options]</a></p>
</div>
<p class="hhd1"><a name="purpose">Purpose</a></p>
<p>In this application you can define a set of <span class="emph">search criteria</span>,
and initiate a search based on this set. A table with
matching datasets and planned activity descriptons will appear. New search criteria
can then be added, or you can modify the current set. The result table will change
accordingly.</p>
<p class="hhd1"><a name="search">Search categories</a></p>
<p>The links to the left each represent one <span class="emph">search categoy</span>.
Activating one of these links brings you to an interactive page for defining/modifying
search criteria for the corresponding category.</p>
<p class="hhd2"><a name="topics">Topics and variables</a></p>
<p>The <span class="emph">Topics and variables</span> page contains a large topic
vocabulary (the <span class="emph">GCMD vocabulary</span>&sup1; from NASA) that aims to cover
all the earth sciences. The vocabulary is organized in a tree
structure where the top level represents main topics like "Athmosphere", "Oceans", "Cryosphere"
etc. Initially only these top level topics are visible in the page. To the left of each
topic name are two small boxes, the first of which contains a "+" sign. Clicking on this box
expands the corresponding topic to the next level. The second box is a checkbox. Check the
box if you want to add this topic to the search criteria you are building. You may similarly expand and
check topics on the deeper levels of the tree. Expanded levels may be collapsed by pushing
the leftmost box again (now containing a "-" sign).</p>
<p>The tree structure is three or four levels deep. The fourth level (if found) lacks the
expansion box. This level is also different because the names to the right of the checkboxes
are not GCMD topic names. They are variable names taken from the 
<span class="emph">CF standard names</span>&sup2; table. 
These names correspond to the actual names used in the netCDF files from where the dataset
metadata are taken. The same CF standard name may be found on different leaves in the
tree structure, reflecting the slight semantic differences between the GCMD and
CF vocabularies&sup3;.</p>
<p>Where the tree is only three levels deep, expansion to the fourth level will not
succeed. In this case, when the system finds no nodes on the fourth level, the leftmost
box is inactivated (no sign will be visible and the box interior takes the surrounding
background color). </p>
<p>When you have checked all the topics/variables you want, click the 
<span class="emph">[Select]</span> button to update the overall search criteria and
return to the last active page selected by the operational menu. If this page is the results
table or the two-way table, the changes due to the updated search criteria will take
immediate effect. The system will remember which boxes were checked, and the next time you
enter the <span class="emph">Topics and variables</span> page, these boxes are already
checked. Also, the same parts of the tree
structure that were earlier expanded, are still expanded. If you have made no changes
regarding which topics/variables are checked, you may return to the previous page by simply
clicking the <span class="emph">[Select]</span> button, and the checked topics/variables
will remain the same. If you, on the other hand, want to clear all settings regarding
which topic/variables are checked, you shuld click the <span class="emph">[Clear All]</span>
button.</p>
<p>The search criteria you have selected will appear as light blue boxes beneath the
<span class="emph">Topics and variables</span> link in the menu of search categories on
the left hand side.</p>
<p>A topic on a high level will correspond to a subtree of topics/variables that has
the high level topic as their common root. If the high level topic is checked, the 
checked/unchecked status of the other nodes in this subtree will have no influence on
the search results. Topics/variables that are checked in the subtree will, however, still
appear in the left hand side list of selected topics/variables.</p>
<p style="border: 1px solid black; padding: 10px"><sup>1</sup><i>Olsen, L.M., G. Major, K. Shein,
J. Scialdone, R. Vogel, S. Leicester, H. Weir, 
S. Ritz, T. Stevens, M. Meaux, C.Solomon, R. Bilodeau, M. Holland, T. Northcutt, R. A. Restrepo, 2007 .
NASA/Global Change Master Directory (GCMD) Earth Science Keywords. Version 6.0.0.0.0</i><br />
<a href="http://gcmd.nasa.gov/index.html">http://gcmd.nasa.gov/index.html</a><br /><br />
<sup>2</sup><a href="http://cf-pcmdi.llnl.gov/">http://cf-pcmdi.llnl.gov/</a><br /><br />
<sup>3</sup>GCMD - CF mapping according to "work in progress" by Roy Lowry at
British Oceanographic Data Centre (<a href="http://www.bodc.ac.uk/products/web_services/vocab/">
http://www.bodc.ac.uk/products/web_services/vocab/</a>)</p>
<p class="hhd2"><a name="activity">Activity types</a></p>
<p>The <span class="emph">Activity types</span> page contains a list of activity types
that describes methods by which data are obtained. The list contain several observational
methods as well as one method covering any type of computer simulation ("Model run"). Each
type may be checked independently, and the checked types are added to the search criteria
when the <span class="emph">[Select]</span> button is pushed. The
<span class="emph">[Clear All]</span> button will clear all selected types and remove them
from the set of search criteria. As for the <span class="emph">Topics and variables</span>
page, the status of checked/unchecked are saved between each invocation of the page, and 
selected types shows up in the left hand side list of search criteria.</p>
<p>Note: Currently, some datasets lack informaton on activity type. These datasets will
not be found if any activity type is used in the search criteria. On the other hand,
planned activity descriptions are much better in this respect.</p>
<p class="hhd2"><a name="opstatus">Operational status</a></p>
<p>The <span class="emph">Operational status</span> page allows selection of datasets
according to their operational status (Operational, Pre operational, Experimental or
Scientific). This page works just like the 
<span class="emph">Activity types</span> page.</p>
<p class="hhd2"><a name="institutions">Institutions</a></p>
<p>The <span class="emph">Institutions</span> page contains a list of institutions responsible
for collecting the data. This page works just like the 
<span class="emph">Activity types</span> page.</p>
<p class="hhd2"><a name="areas">Areas</a></p>
<p>The <span class="emph">Areas</span> page contains a list of geographical names that
represent areas in which data has been (or will be) collected or for which model simulations
has been (or will be) done. The page works just like the previous two pages (see description 
for <span class="emph">Activity types</span>).</p>
<p>Note: The list of area names is not as good as we would like. It is a mixture of a small
vocabulary and names actually used by data providers. Also, not all datasets have this
information, making them fall out from a search if <span class="emph">Areas</span> is
used in the search criteria. Also, if you search on a name representing a wide area, you
will not hit objects that are only described by names of smaller areas
inside the wide area.</p>
<p>An alternative to this category is the <span class="emph">Map search</span> category
described below. Map search will be better for finding datasets, as all datasets
contain geographical coordinates that are used in the map search. On the other hand,
no planned activity will currently be found by map search.</p>
<p class="hhd2"><a name="mapsearch">Map search</a></p>
<p>The <span class="emph">Map search</span> link brings up a map of the Arctic
where you can define a rectangular search area. Click on two points on this map.
They will constitute opposite corners in the rectangular area.
Click the <span class="emph">[OK]</span> button, and return to whatever
page was last activated in the operational menu. A smaller version of the map
will appear on the left hand side menu, with the search area emphisized in darker colors.
As for the other search categories, changes to the results page or the two-way table will
take immediate effect. 
</p>
<p class="hhd2"><a name="period">Datacollection period</a></p>
<p>The <span class="emph">Datacollection period</span> page lets you define a time period
to search for. A search on such a period will match all datasets and planned activity
descriptions that cover this period. Also objects that only partially cover the period
will match. Enter the period to search for by filling in the FROM and TO entry fields 
in the page. In each field, use the date format "YYYY-MM-DD". Just "YYYY" or "YYYY-MM"
will also be understood. Then, click the "OK" button. As for the other search category pages,
the entered information will be saved between invocations, and the selected period will show
up in the left hand side overview of selected search criteria. To remove the period from
the set of search criteria (and clear the entry fields), push the
<span class="emph">[Remove]</span> button.</p>
<p class="hhd1"><a name="combining">Combining the search criteria</a></p>
<p>Search criteria selected from the same dialog page
(activated by one of the left hand side search category links) are
implicitly combined by logical <span class="emph">OR</span>. For example, if both "Float" and
"Moored instrument" are checked in the <span class="emph">Activity types</span> page,
all objects matching either of these activity types will be selected.</p>
<p>Search criteria selected from different dialog pages are, on the other hand, implicitly
combined by logical <span class="emph">AND</span>. For example, if both "Float" from the
<span class="emph">Activity types</span> page and "2006-01-01 to 2006-05-31" from the
<span class="emph">Datacollection period</span> page are parts of the search criteria, only
objects matching both of these criteria will be selected.</p>
<p>If nothing is selected from one of the search categories, this category will not
take part in the search at all. For example, if no <span class="emph">Activity types</span>
are selected, the search will match any activity type, and also match objects for which
information about activity type are missing. But at least one of the search categories
must be used if the search is to take place at all.</p>
<p class="hhd1"><a name="operational">The operational menu</a></p>
The row of buttens with white text on a blue background is the 
<span class="emph">operational menu</span>. It is used to initiate a search based
on the current set of search criteria, and to choose how the search results are
presented. Also, this help page is activated from the operational menu. The four
buttons comprising the operational menu are: 
<span class="emph">[Show results]</span>,
<span class="emph">[Two-way tables]</span>,
<span class="emph">[Options]</span> and
<span class="emph">[Help]</span>.
<p class="hhd2"><a name="results">[Show results]</a></p>
<p>When you are satisfied with your set of search criteria, you can initiate the search by pressing
the <span class="emph">[Show results]</span>
button. This will show a table of metadata for all matching datasets and planned activities. Each
row of the table corresponds to one dataset or planned activity. The columns correspond to different
types of metadata. You can change which metadata types are shown by using the
<span class="emph">[Options]</span> button (see below).
If no search criteria are defined, no metadata will be shown.</p>
<p class="hhd2"><a name="twoway">[Two-way table]</a></p>
<p>A more compact overview of search results is obtained by pressing the
<span class="emph">[Two-way table]</span> button. This table gives an overview of
all metadata corresponding to the defined search
criteria. If the metadata are voluminous, the table presents a manageable view into the
structure of the metadata, and can be an aid for further investigation of the metadata.
The two-way table uses two different metadata types to define the headings along the upper
row and leftmost column of the table, respectively. The table cells contain a count on
datasets and planned activities that matches the metadata found at the top cell in the column
as well as the leftmost cell in the row.</p>
<p class="hhd2"><a name="options">[Options]</a></p>
<p>An <span class="emph">options dialog</span>, that let you control the presentation of
the search results, is activated by the <span class="emph">[Options]</span> 
button. The combined set of metadata in the database can be thought of as a large table with
one row for each dataset/planned activity, and one column for each metadata type that may describe
these objects. Some, but not all, of the metadata types have a corresponding search category.
In the options dialog, all metadata types are shown. You may select which of these types
shall be used in the columns in the result table. You may also select 
two of the metadata types for the horisontal and veritcal axes that define how the two-way
tables are constructed. Finally, in the options dialog you may control the font size used in the
results and two-way tables.</p>
</td></tr></table>
