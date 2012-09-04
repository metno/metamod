/**
 * This class implements a OpenLayers Time selector that is displayed as
 * a slider.
 *
 * Copyright (c) 2012 Øystein Torget, The Norwegian Meteorological Institute
 *
 * See https://github.com/metno/openlayers-timeslider for complete code.
 *
 */

OpenLayers.Control.TimeSlider = OpenLayers.Class(OpenLayers.Control, {

    // mapping of the times are available.
    availableTimes : {},

    // secondary attribute updated automatically from availableTimes
    sortedTimes : [],

    visibleLayers : [],

    // jQuery UI slider object
    slider : null,

    //ids for html elements used by the slider
    sliderId : 'timeslider-slider',
    nextButtonId : 'timeslider-next',
    previousButtonId : 'timeslider-previous',
    sliderCurrentId : 'timeslider-current',
    buttonDivId : 'timeslider-button-div',

    /**
     * Method: setMap
     *
     * Properties:
     * map - {<OpenLayers.Map>}
     */
    setMap: function(map) {
        OpenLayers.Control.prototype.setMap.apply(this, arguments);

        // register callbacks for the events that we are interested in
        this.map.events.on({
            "addlayer": this.layerChange,
            "removelayer": this.layerChange,
            "changelayer": this.layerChange,
            scope: this
        });

        this.visibleLayers = [];
        for( var i = 0; i < this.map.layers.length; i++ ){
            var layer = this.map.layers[i];
            if(layer.getVisibility()){
                this.visibleLayers.push(layer);
            }
        }

        this.updateAvailableTimes();
        this.redraw();

        var defaultTime = this.map.layers[0].dimensions.time.default;
        if (defaultTime !== undefined) {
            log.debug('Default time is ' + defaultTime);
            this.timesliderSetTime(defaultTime);
        }

    },

    /**
     * Callback for when the layers change in some way. Either added, removed or altered.
     * @param event
     */
    layerChange : function (event) {

        // for change layer events we only care about changes to visibility
        if( event.type == "changelayer" && event.property != "visibility" ){
            return
        }

        this.visibleLayers = [];
        for( var i = 0; i < this.map.layers.length; i++ ){
            var layer = this.map.layers[i];
            if(layer.getVisibility()){
                this.visibleLayers.push(layer);
            }
        }

        this.updateAvailableTimes();
        this.redraw();

    },

    /**
     * Update the availableTimes attribute based on the time values from visible layers.
     */
    updateAvailableTimes : function () {

        var newTimes = {};
        var timedLayers = 0;
        for( var i = 0; i < this.visibleLayers.length; i++ ){

            var layerTimes = this.timesForLayer(this.visibleLayers[i]);
            if (layerTimes.length) {
                timedLayers++;
                for( var j = 0; j < layerTimes.length; j++ ){
                    var time = jQuery.trim(layerTimes[j]);

                    if( time in newTimes ){
                        newTimes[time] = newTimes[time] + 1;
                    } else {
                        newTimes[time] = 1;
                    }
                }
            }
        }

        this.availableTimes = newTimes;
        this.sortedTimes = this.sortTimes(this.availableTimes, timedLayers);
        //log.debug(this.sortedTimes);
    },

    /**
     * Returned the array of times for a layer
     */
    timesForLayer : function (layer) {

        var times = [];
        if (layer.dimensions !== undefined && layer.dimensions.time !== undefined) {
            times = layer.dimensions.time.values;
        }
        return times;
    },

    /**
     * Redraw the UI
     */
    redraw : function () {

        this.resetSliderUI();

        // we do not display the slider if the there are no layers with time.
        if(this.sortedTimes.length > 0){
            this.createSliderUI();
        }

    },

    /**
     * Clean up the current slider UI
     */
    resetSliderUI : function () {
        // clean up any existing slider
        if( this.slider != null ){
            this.slider.slider("destroy");
            this.slider = null;
        }

        var container = this.getDivContainer();
        container = jQuery(container);
        container.empty();
    },

    /**
     * Create the UI for the slider.
     */
    createSliderUI : function () {
        var html = this.timesliderHtml();
        var container = this.getDivContainer();
        container = jQuery(container);
        //alert(html);
        container.append(html);

        var outerThis = this;
        this.slider = jQuery('#' + this.sliderId).slider({
            min: 0,
            max : this.sortedTimes.length - 1,
            change : function (event, slider) { outerThis.timesliderValueChange(slider); }
        }
        );

        //jQuery('#' + this.previousButtonId ).on('click', function () { outerThis.timesliderPrevious(); } );
        //jQuery('#' + this.nextButtonId).on('click', function () { outerThis.timesliderNext(); } );

        //we set the value to make sure that we fire the value changed event.
        this.slider.slider("value", 0);

    },

    /**
     * Advance the slider to the next value. This method wraps around to the start.
     */
    timesliderNext : function () {
        var val = this.slider.slider("value");
        if( val < this.sortedTimes.length - 1 ){
            this.slider.slider("value", val + 1);
        } else {
            this.slider.slider("value", 0);
        }
    },

    /**
     * Move the slider to the previous value. This method wraps around to the end.
     */
    timesliderPrevious : function () {
        var val = this.slider.slider("value");
        if( val > 0 ){
            this.slider.slider("value", val - 1);
        } else {
            this.slider.slider("value", this.sortedTimes.length - 1);
        }
    },

    /**
     * Move the slider to a specific time (if exists in visible layers)
     */
    timesliderSetTime : function (time) {
        for( var i = 0; i < this.sortedTimes.length; i++ ){
            //log.debug(this.sortedTimes[i]);
            if (this.sortedTimes[i] === time) {
                log.debug('Setting slider to ' + time);
                this.slider.slider("value", i);
            }
        }
    },

    /**
     * Callback for when the slider value is changed either by the user or programmatically.
     * @param slider The jQuery UI slider
     */
    timesliderValueChange : function (slider) {

        var currentTime = this.sortedTimes[slider.value];
        jQuery('#' + this.sliderCurrentId).text( currentTime.slice(0,10) + ' ' + currentTime.slice(11) );
        this.changeLayerTime(currentTime);
    },

    /**
     * Change the time for all visible layers.
     * @param time The new time for all layers as a string.
     */
    changeLayerTime : function (time) {

        for( var i = 0; i < this.visibleLayers.length; i++ ){
            var layer = this.visibleLayers[i];
            layer.mergeNewParams( { time: time } );
            log.debug('Changing layer ' + layer.name + ' to ' + time);
        }

    },

    /**
     * @returns The div container for the timeslider.
     */
    getDivContainer : function () {

        if( this.div == null ){
            this.div = document.createElement("div");
        }
        return this.div;

    },

    /**
     * Generates the HTML required by the time slider.
     * @returns {String}
     */
    timesliderHtml : function () {
        var html = '<div id="' + this.sliderId + '">';
        html += '<span id="' + this.sliderCurrentId + '" class="timeslider-current" style="margin-left: 310px; white-space: nowrap;"></span>';
        html += '</div>';
        html += '<div id="' + this.buttonDivId + '" class="timeslider-button-div">';
        //html += '<button id="' + this.previousButtonId + '" class="timeslider-previous">Previous</button>'; // not working
        //html += '<span id="' + this.sliderCurrentId + '" class="timeslider-current"></span>';
        //html += '<button id="' + this.nextButtonId + '" class="timeslider-next">Next</button>'; // not working
        html += '</div>';
        return html;
    },


    /**
     * Sort a dictionary/hash of times as stored in the availableTime
     * optional argument limit filters out times without matching value count
     */
    sortTimes : function ( availableTimes, limit ) {

        var times = [];
        for( var time in availableTimes){
            //log.debug('>>>' + time + ': ' + availableTimes[time]);
            if (limit === undefined || availableTimes[time] === limit) {
                times.push(time);
            }
        }

        times.sort();
        return times;
    },

    CLASSNAME : "OpenLayers.Control.TimeSlider"
});

//OpenLayers.Control.TimeSlider is free software; you can redistribute it and/or
//modify it under the terms of the GNU General Public License as published by the
//Free Software Foundation; either version 2 of the License, or (at your option)
//any later version.
//
//OpenLayers.Control.TimeSlider is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
//or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
//details.
//
//You should have received a copy of the GNU General Public License along with
//OpenLayers.Control.TimeSlider; if not, write to the Free Software Foundation,
//Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
