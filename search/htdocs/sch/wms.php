<html xmlns="http://www.w3.org/1999/xhtml">

	<head>
		<title>WMS client</title>
		<link rel="stylesheet" href="../theme/default/style.css" type="text/css" />
		<!--link rel="stylesheet" href="style.css" type="text/css" /-->
		<style type="text/css">
			#warning {font-size: x-large; padding:22 22 22 22; text-decoration: blink; color: red;}
		</style>
		<script src="../lib/OpenLayers.js"></script>

		<script type="text/javascript">

			// making this a global variable so that it is accessible for
			// debugging/inspecting in Firebug
			var map = null;

			// configure HTTP proxy here
			//OpenLayers.ProxyHost = "/cgi/proxy.cgi?url=";
			//OpenLayers.ProxyHost = "./wmsProxy.php?url=";
			OpenLayers.ProxyHost = "/cgi-bin/gc2wmc.pl?setup=";

			//read CGI args
			var args = new OpenLayers.Util.getArgs();
			//var wms_url = args.wmsurl; // currently ignored
			//alert(wms_url);
			var wms_setup = args.wmssetup;

			var wmsCapabilities;
			var wmsLayers;
			var error;

			function init(){
				// run after document is loaded

				// remove js warning
				document.getElementById('docs').removeChild( document.getElementById('warning') );

				if (wms_setup != '') {
					// do nothing if query string is empty
					OpenLayers.loadURL(wms_setup,
						"",
						this, drawMap, showError);

				}
			}

			function buildStyleSelector(styles, layername) {
				// called every time layer or style is changed
				current = map.baseLayer.params["STYLES"] || styles[0].name;
				var sel = document.forms["form1"].wmsstyle;
				sel.length = 0;
				for (i = 0; i < styles.length; i++) {
					var opt = styles[i].name;
					var option = document.createElement('option');
					option.setAttribute('value', opt);
					option.appendChild(document.createTextNode(opt.slice(8))); // remove BOXFILL prefix
					sel.appendChild(option);
					if (opt == current) {
						//alert(opt);
						// set current option as selected
						sel.selectedIndex = i;
						// change legend URL (have to set both LAYER and LAYERS due to bug in ncWMS)
						document.getElementById('legend').src = styles[i].legend.href + '&LAYERS=' + layername;
					}
				}
			}

			function changeLayer(event) {
				// triggered when user changes layer
//				alert("layer = " + event.layer.name);
				document.getElementById('legend').src = "../img/blank.gif";
				if (event.layer.isBaseLayer && event.layer.visibility) {
					buildStyleSelector(event.layer.styles, event.layer.params.LAYERS);
				}

			}

			function changeStyle(style) {
				// triggered when user changes style
//				alert("style = " + style);
				map.baseLayer.mergeNewParams( {STYLES: style} );
			}

			function changeLegend(event) { // deprecated
				// triggered when user changes layer
				if (event.layer.isBaseLayer) {
					document.getElementById('legend').src = event.layer.legend;
				}
			}

			function old_drawMap(response) {

				//wmsParser = new OpenLayers.Format.WMSCapabilities();
				//try {
				//	// IE chokes here on bad XML, Firefox just goes on...
				//	wmsCapabilities = wmsParser.read(response.responseText);
				//} catch (error) {
				//	alert("Invalid Capabilities XML from mapserver:\n  " + error + "\nContent:\n  " + response.responseText);
				//}
				//
				//var layersw = new OpenLayers.Control.LayerSwitcher({'autoActivate': true, 'ascending': false});
				//
				//var options = {
				//		maxExtent: new OpenLayers.Bounds(-3000000,-3000000,7000000,7000000),
				//		units: 'm',
				//		projection: "EPSG:32661",
				//		controls: [
				//				new OpenLayers.Control.Navigation(),
				//				new OpenLayers.Control.PanZoomBar(),
				//				layersw,
				//				new OpenLayers.Control.Permalink(),
				//				new OpenLayers.Control.ScaleLine(),
				//				new OpenLayers.Control.Permalink('permalink'),
				//				new OpenLayers.Control.MousePosition(),
				//				//new OpenLayers.Control.OverviewMap(),
				//				new OpenLayers.Control.KeyboardDefaults()
				//		],
				//		numZoomLevels: 3,
				//		maxResolution: 10000
				//};
				//
				//// setup map and handler
				//map = new OpenLayers.Map('map', options);
				//this.map.events.register("changelayer", this, changeLegend);
				//
				//var borders = new OpenLayers.Layer.WMS(
				//		"Met.no kart",
				//		"http://wms.met.no/maps/northpole.map?",
				//		{
				//				transparent: "true",
				//				layers: 'borders'
				//		},
				//		{
				//			isBaseLayer: false
				//		}
				//);
				//
				//var layers = [];
				//
				//try {
				//	// This is where Firefox chokes on bad XML
				//	var wms_href = wmsCapabilities.capability.request.getmap.href;
				//	wmsLayers = wmsCapabilities.capability.layers;
				//} catch (error) {
				//	alert("Invalid Capabilities XML from mapserver:\n  " + error + "\nContent:\n  " + response.responseText);
				//}
				//
				//// setup layers from Capabilities doc
				//for (var i=0; i < wmsLayers.length; i++) {
				//	var legend_url = wmsLayers[i].styles[0].legend.href + '&LAYERS=' + wmsLayers[i].name;
				//	layers.push(
				//		new OpenLayers.Layer.WMS(
				//			wmsLayers[i].title,
				//			wms_href,
				//			{
				//				layers: wmsLayers[i].name,
				//				//transparent: "true",
				//				format: "image/png",
				//				styles: "BOXFILL/redblue" // + palette
				//			},
				//			{
				//				//layerObj: wmsLayers[i]
				//				legend: legend_url
				//			}
				//		)
				//	)
				//}
				//
				//layers.push(borders); // put map outlines on top
				//
				//map.addLayers(layers);
				//layersw.maximizeControl(true); // show layerselector maximized
				//map.zoomToExtent(map.maxExtent);
				//
				//// set legend URL (have to set both LAYER and LAYERS due to bug in ncWMS)
				//document.getElementById('legend').src = wmsLayers[0].styles[0].legend.href + '&LAYERS=' + wmsLayers[0].name;
				//
				//// set page headings
				//var heading = wmsCapabilities.capability.nestedLayers[0].nestedLayers[0].title;
				//document.title = heading;
				//document.getElementById('title').appendChild( document.createTextNode(heading) );

			}

			function drawMap(response) {

				wmsContext = response.responseXML;
				if (wmsContext === undefined) {
					alert("WMC is null!");
					return 0;
				}

				var layersw = new OpenLayers.Control.LayerSwitcher({'autoActivate': true, 'ascending': true});

				wmcParser = new OpenLayers.Format.WMC();
				try {
					map = wmcParser.read( wmsContext, { map: 'map' } );
				} catch (error) {
					alert("Invalid GetMapContext:\n" + error + "\n" + response.responseText);
					//return 0;
				}

				map.addControl(layersw);
				map.addControl( new OpenLayers.Control.MousePosition() );
				map.addControl( new OpenLayers.Control.PanZoomBar() );
				map.addControl( new OpenLayers.Control.Navigation() );
				map.addControl( new OpenLayers.Control.ScaleLine() );
				map.addControl( new OpenLayers.Control.Permalink('permalink') );
				map.addControl( new OpenLayers.Control.OverviewMap() );

				//map.events.on( { changeLayer: changeLegend } );
				this.map.events.register("changelayer", this, changeLayer);

				var coastlines = "http://wms.met.no/maps/world.map?";
				if (map.projection == "EPSG:32661") {
					coastlines = "http://wms.met.no/maps/northpole.map?";
				} else if (map.projection == "EPSG:32761") {
					coastlines = "http://wms.met.no/maps/southpole.map?";
				}

				try {
					map.addLayer(
						new OpenLayers.Layer.WMS(
							"Met.no kart",
							coastlines,
							{
								transparent: "true",
								layers: 'borders'
							},
							{
								isBaseLayer: false
							}
						)
					);
				} catch (error) {
					alert(error);
					return 0;
				}

				document.getElementById('map').style.height = map.getSize().h - 100;
				map.updateSize();
				//map.zoomToExtent(map.maxExtent);

				layersw.maximizeControl(true);
				var layer0 = map.layers[0].params.LAYERS;
				buildStyleSelector(map.layers[0].styles, layer0);

				// set legend URL (have to set both LAYER and LAYERS due to bug in ncWMS)
				document.getElementById('legend').src = map.layers[0].styles[0].legend.href + '&LAYERS=' + layer0;

				// Print resource link for debugging
				var a = document.createElement("a");
				//a.href = wms_url + "?service=WMS&version=1.3.0&request=GetCapabilities";
				a.href = wms_setup;
				a.appendChild( document.createTextNode(wms_setup) );
				document.getElementById('shortdesc').appendChild(a);

				// set page headings
				//var heading = map.layers[0].name;
				//document.title = heading;
				//document.getElementById('title').appendChild( document.createTextNode(heading) );

			}

			function showError(response) {
				document.getElementById('shortdesc').appendChild(document.createTextNode("Could not contact WMS server!"));
			}

		</script>
	</head>
	<body onload="init()" style="background-image:url(../img/metamod_wms_logo.png); background-repeat:no-repeat; background-position:16em 0px;">
	   <p style="margin-bottom: 30px">
		<a href="javascript:history.back()">Back to Search</a>
		</p>
		<form name="form1" action="#">
			Style:
			<select name="wmsstyle" id="wmsstyle" onChange="changeStyle(this[this.selectedIndex].value)"></select>
		</form>
		<div id="tags"></div>
		<img id="legend" src="../img/blank.gif"
				style="float: right;position:relative;top:350px;z-index:1000">
		<div id="map" class="largemap"></div>
		<div id="docs"><p id="warning">Javascript must be enabled for WMS client to work!</p></div>
		<p id="shortdesc">Data file (direct): </p>
	</body>
</html>
