
var info;

//read CGI args
var args = new OpenLayers.Util.getArgs();

OpenLayers.IMAGE_RELOAD_ATTEMPTS = 5;

$(function() { // runs after document loaded
    $('#accordion').accordion( {
        create: function(event, ui) {
            //alert('accordion!');
            //log.debug('accordion created!');
        }/*,
        change: function(event, ui) {
            log.debug('layer change: ' + ui.oldHeader.attr('id') + ' to ' + ui.newHeader.attr('id'));
            map.layers[ui.oldHeader.attr('id').slice(5)].setVisibility(false);
            map.layers[ui.newHeader.attr('id').slice(5)].setVisibility(true);
        }*/
    } );
});

function init(){
    // run after document is loaded

    var wms_setup = args.wmssetup;
    var wms_url = args.wmsurl;

    // remove "javascript not installed" message from window
    $('#docs').empty();

    if (typeof ds_id != 'undefined') {
        OpenLayers.loadURL(wmcpath, "", this, drawMap, showError);
    } else if (typeof wms_setup != 'undefined') {
        alert('wmssetup not supported - use ds_id istead!');
        //OpenLayers.ProxyHost = "/gc2wmc?wmssetup=";
        //OpenLayers.loadURL(wms_setup, "", this, drawMap, showError);
    } else if (typeof wms_url != 'undefined') {
        //alert("wmsurl = " + wms_url);
        //OpenLayers.ProxyHost = "/gc2wmc?getcap=";
        OpenLayers.loadURL(wmcpath + "?getcap=" + wms_url, "", this, drawMap, showError);
    } else {
        OpenLayers.loadURL(multiwmcpath, "", this, drawMap, showError);
        //alert("Missing ds_id or wmsurl parameter!");
    }

}

function changeFile(new_ds_id) { // DEPRECATED, not working in 2.11
    map.destroy();
    OpenLayers.loadURL(wmcpath + "?ds_id=" + new_ds_id, "", this, drawMap, showError); // also needs crs
}

function changeCRS(crs) {
    window.location.href = 'wms?ds_id=' + ds_id + '&crs=' + crs;
}

function timeHandlerFactory(layer) {
    return function() {
        var dtime = this[this.selectedIndex].value;
        log.debug("setting time to " + dtime + " for " + layer.name);
        layer.mergeNewParams( {time: dtime} );
    }
}

function styleHandlerFactory(layer, l_image) {
    return function() {
        var style = this[this.selectedIndex].value;
        layer.mergeNewParams( {STYLES: style} );
        log.debug('Style changed for ' + layer.id + ' to ' + style);
        var legend = layer.metadata.styles[this.selectedIndex].legend;
        if ( legend !== undefined ) {
            var src = fixThreddsURL( legend.href );
            log.debug('Legend: ', src);
            l_image.attr('src', src); // ncwms fix
        }
    }
}

function toggleSticky(layer, box) {
    log.debug('Setting layer ' + later + ' to ' + box.checked);
    map.layers[' + layer + '].sticky = box.checked;
}

function fixThreddsURL(url) {
    return url.replace(/LAYER=([^&]*)/, "$&&LAYERS=$1");
}

function drawMap(response) {

    wmsContext = response.responseXML;
    if (wmsContext === undefined) {
        log.fatal("WMC is null!");
        return 0;
    }

    var layersw = new OpenLayers.Control.LayerSwitcher({'autoActivate': false, 'ascending': true});

    wmcParser = new OpenLayers.Format.WMC();
    try {
        map = wmcParser.read( wmsContext, { map: { div: 'map', controls: [] } } );
    } catch (error) {
        log.fatal("Invalid GetMapContext:\n" + error + "\n" + response.responseText);
        return 0;
    }

    log.debug("Projection = " + map.projection);

    //map.addControl(layersw);
    //layersw.maximizeControl(true);
    map.addControl( new OpenLayers.Control.PanZoomBar() );
    map.addControl( new OpenLayers.Control.Navigation() );
    //map.addControl( new OpenLayers.Control.MousePosition() );
    //map.addControl( new OpenLayers.Control.ScaleLine() );
    //map.addControl( new OpenLayers.Control.Permalink('permalink') );

    var timeSliderDiv = document.getElementById('timesliderId');
    if (timeSliderDiv !== undefined) {
        map.addControl( new OpenLayers.Control.TimeSlider( {div: timeSliderDiv} ) );
    }
    $("#accordion").empty(); // remove old layers from selector

    var leds = [ // rewrite as hash... FIXME
        '../static/images/led_off.png',
        '../static/images/led_yellow.png',
        '../static/images/led_dkgreen.png',
        '../static/images/led_green.png'
    ];

    var projs = {};

    for (var i=0; i < map.layers.length; i++) {
        var layer = map.layers[i];
        var lc = '#layer' + i;
        //log.debug(lc);

        // store # of uses of all projs for later (needed by crs selector)
        for (var key in layer.srs) {
            //if ( layer.isBaseLayer && layer.srs.hasOwnProperty(key) ) { // why baselayer?
            if ( layer.srs.hasOwnProperty(key) ) {
                //log.debug(i, key);
                if (projs[key] == undefined) {
                    projs[key] = 1;
                } else {
                    projs[key]++;
                }
            }
        }

        var led_index = ( layer.isBaseLayer ? 2 : 0 );
        if ( i == 0 ) { // first layer starts open
            led_index++; // turn on led
            //map.layers[0].setVisibility(true); // trigger event so timeslider works on default layer (fixed somewhere else - try removing this later. FIXME)
            //log.debug('Setting layer 0 visible');
        };

        //var lvis = layer.isBaseLayer ?
        //    '<input name="baselayer_visible" id="' + lc + '_show" type="radio"/>' :
        //    '';
        $("#accordion").append('<h3 layer="' + i + '"><a href="#"><img class="onoff" src="'
                               + leds[led_index] + '"/> ' + layer.name + '</a></h3>');
        $("#accordion").append('<div id="layer' + i + '"></div>');
        if (layer.metadata.abstract !== undefined) {
            $(lc).append('<p>' + layer.metadata.abstract + '</p>');
        }
        if (! layer.isBaseLayer) {
            $(lc).append('<label><input name="' + lc + '_visible" id="' + lc + '_show" type="checkbox" '
            + 'onchange="map.layers[' + i + '].sticky = this.checked;"/>stay visible</label>');
            //+ '/>stay visible</label>'); // not working
            //$(lc + '_show').change = function(){ alert('changed '+i); toggleSticky(i, this); }; // this craps out too

        }

        if (layer.dimensions !== undefined && layer.dimensions.time !== undefined) {

            var times = layer.dimensions.time.values;
            var deft = layer.dimensions.time.default || times[0];

            // initialize time for all layers (needed for wmsdiana)
            layer.mergeNewParams( {time: deft} );

            // build time selector... DEPRECATED - time selector now handled by timeslider plugin
            $(lc).append('<p>Timeseries points: ' + times.length + '</p>');
        }

        if (layer.metadata.styles !== undefined && layer.metadata.styles.length > 0) {

            // build style selector
            $(lc).append('<p>Style:<br/><select id="layer' + i + '_styles"/></p>\n');
            var sty = layer.metadata.styles;
            var current = undefined;
            for (s in sty) {
                //log.debug(st);
                var tag = '<option>';
                if (sty[s].current) {
                    current = s;
                    tag = '<option selected="selected">';
                }
                $(lc + '_styles').append("\n" + tag + sty[s].name + "</option>");
            }
            log.debug('Current style for layer', i, 'is', current);
            if (current !== undefined) { // starting style defined in wmc
                if (sty[current].legend) {
                    legend_elem = '<img id="layer' + i + '_legend" src="' + fixThreddsURL( sty[current].legend.href ) + '"/>';
                    log.debug('legend:', legend_elem);
                }
            } else {
                if (sty[0].legend) { // what's this for?
                    legend_elem = '<img id="layer' + i + '_legend" src="' + fixThreddsURL( sty[0].legend.href ) + '"/>';
                    legend_elem = legend_elem.replace(/PALETTE=[^&"]+?/i, ''); // remove PALETTE param and let server decide default style
                    log.debug('legend:', legend_elem);
                }
            }
            if (typeof legend_elem != 'undefined') {
                $(lc).append(legend_elem);
                $(lc + '_styles').change( styleHandlerFactory( layer, $(lc + '_legend') ) );
            }
        }

    }

    for (var key in projs) {
        log.debug(key, 'supported by', projs[key], 'layers');
        if (key == "CRS:84") continue;
        if (projs[key] === map.layers.length) {
            var ptext = (projnames[key] !== undefined) ? key + ' (' + projnames[key] + ')': key;
            $('#crs').append( '<option value="' + key + '">' + ptext + '</option>');
        }
    }
    $('#crs').val(map.projection);

    $("#accordion").accordion("destroy");
    $("#accordion").accordion({
        fillSpace:true,
        clearStyle: true, // needed when more layers than can fit in window
        icons: false,
        create: function(event, ui) {
            //alert('accordion!');
            log.debug('accordion created!');
        },
        change: function(event, ui) {
            log.debug('layer change: ' + ui.oldHeader.attr("layer") + ' to ' + ui.newHeader.attr("layer"));
            var o_index = ui.oldHeader.attr('layer');
            var n_index = ui.newHeader.attr('layer');
            if (map.layers[o_index].isBaseLayer) {
                log.debug('layer ' + o_index + ' is baselayer');
                if (map.layers[n_index].isBaseLayer) {
                    ui.oldHeader.find('img.onoff').attr('src', leds[ 2 ]);
                    log.debug('changing to base layer ' + n_index);
                }
            } else {
                map.layers[o_index].setVisibility( map.layers[o_index].sticky );
                ui.oldHeader.find('img.onoff').attr('src', leds[ map.layers[o_index].sticky ? 1 : 0 ]);
            }
            map.layers[n_index].setVisibility(true);
            ui.newHeader.find('img.onoff').attr('src', leds[ map.layers[n_index].isBaseLayer ? 3 : 1 ]);
        }
    });
    $("#accordion").accordion("resize");

}

function showError(response) {
    errmsg = "Error from WMS server: " + response.status + " " + response.statusText;
    log.error(errmsg);
    $('#docs').append("<p id='warning'>" + errmsg + "</p>");
}
