
$(function() { // runs after document loaded
    $('#accordion').accordion( {
        create: function(event, ui) {
            alert('accordion!');
            log.debug('accordion created!');
        }/*,
        change: function(event, ui) {
            log.debug('layer change: ' + ui.oldHeader.attr('id') + ' to ' + ui.newHeader.attr('id'));
            map.layers[ui.oldHeader.attr('id').slice(5)].setVisibility(false);
            map.layers[ui.newHeader.attr('id').slice(5)].setVisibility(true);
        }*/
    } );
});

var log = log4javascript.getDefaultLogger();

OpenLayers.IMAGE_RELOAD_ATTEMPTS = 5;

function init(){
    // run after document is loaded

    //read CGI args
    var args = new OpenLayers.Util.getArgs();
    var wms_setup = args.wmssetup;
    var wms_url = args.wmsurl;

    // remove "javascript not installed" message from window
    document.getElementById('docs').removeChild( document.getElementById('warning') );

    if (typeof ds_id != 'undefined') {
        OpenLayers.loadURL(wmcpath + "?ds_id=" + ds_id, "", this, drawMap, showError);
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

function changeFile(new_ds_id) {
    map.destroy();
    OpenLayers.loadURL(wmcpath + "?ds_id=" + new_ds_id, "", this, drawMap, showError);
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
            l_image.attr('src', legend.href + '&LAYERS=' + layer.name); // ncwms fix
        }
    }
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

    $("#accordion").empty(); // remove old layers from selector

    for (var i=0; i < map.layers.length; i++) {
        var l = map.layers[i];
        var lc = '#layer' + i;

        //var lvis = l.isBaseLayer ?
        //    '<input name="baselayer_visible" id="' + lc + '_show" type="radio"/>' :
        //    '';
        $("#accordion").append('<h3 layer="' + i + '"><a href="#">' + l.name + '</a></h3>');
        $("#accordion").append('<div id="layer' + i + '"></div>');
        if (l.metadata.abstract !== undefined) {
            $(lc).append('<p>' + l.metadata.abstract + '</p>');
        }
        if (! l.isBaseLayer) {
            $(lc).append('<label><input name="' + lc + '_visible" id="' + lc + '_show" type="checkbox" '
            + 'onchange="map.layers[' + i + '].sticky = this.checked"/>stay visible</label>');
        }

        if (l.dimensions !== undefined && l.dimensions.time !== undefined) {

            var times = l.dimensions.time.values;
            var deft = l.dimensions.time.default || times[0];
            //log.debug(i + ' >>> ' + typeof times);
            //log.debug("layer " + map.layers[i].name + " has " + times.length + " timestamps")
            //log.debug(map.layers[i].name + " time: " + times[0] + ", default: " + deft);

            // initialize time for all layers (needed for wmsdiana)
            l.mergeNewParams( {time: deft} );

            // build time selector
            $(lc).append('<p>Time:<br/><select id="layer' + i + '_time"/></p>');
            for (t in times) {
                //log.debug(times[t]);
                $(lc + '_time').append("<option>" + times[t] + "</option>");
            }

            $(lc + '_time').change( timeHandlerFactory(l) );
        }


        if (l.metadata.styles !== undefined && l.metadata.styles.length > 0) {

            // build style selector
            $(lc).append('<p>Style:<br/><select id="layer' + i + '_styles"/></p>');
            var sty = l.metadata.styles;
            for (s in sty) {
                //log.debug(st);
                $(lc + '_styles').append("<option>" + sty[s].name + "</option>");
            }
            if (sty[0].legend) {
                $(lc).append('<img id="layer' + i + '_legend" src="' + sty[0].legend.href + '&LAYERS=' + l.name + '"/>');
            }

            $(lc + '_styles').change( styleHandlerFactory( l, $(lc + '_legend') ) );
        }

    }

    $("#accordion").accordion("destroy");
    $("#accordion").accordion({
        fillSpace:true,
        clearStyle: true, // needed when more layers than can fit in window
        icons: true,
        create: function(event, ui) {
            alert('accordion!');
            log.debug('accordion created!');
        },
        change: function(event, ui) {
            log.debug('layer change: ' + ui.oldHeader.attr("layer") + ' to ' + ui.newHeader.attr("layer"));
            var o_index = ui.oldHeader.attr('layer');
            var n_index = ui.newHeader.attr('layer');
            if (map.layers[o_index].isBaseLayer) {
                log.debug('layer ' + o_index + ' is baselayer');
            } else {
                map.layers[o_index].setVisibility( map.layers[o_index].sticky );
            }
            map.layers[n_index].setVisibility(true);
        }
    });
    $("#accordion").accordion("resize");

}

function showError(response) {
    var b = document.createElement('b');
    b.appendChild( document.createTextNode("Could not contact WMS server! ") );
    document.getElementById('shortdesc').appendChild(b);
    document.getElementById('shortdesc').appendChild( document.createElement('br') );
    document.getElementById('shortdesc').appendChild( document.createTextNode("Error from backend is: " + response.status + " " + response.statusText) );
}
