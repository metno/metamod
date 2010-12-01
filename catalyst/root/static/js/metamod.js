function showSearchCriteria( categoryId ) {

	jQuery( 'div.search-criteria' ).hide();
	jQuery( '#search-criteria-' + categoryId ).show();


}

function toggleSubresult ( dsId ) {

	jQuery('#sub_result_' + dsId ).toggle();

}