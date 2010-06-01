<html xmlns="http://www.w3.org/1999/xhtml">

	<head>
		<title>WMS client</title>
		<link rel="stylesheet" href="../theme/default/style.css" type="text/css" />
		<!--link rel="stylesheet" href="style.css" type="text/css" /-->
		<style type="text/css">
			#warning {font-size: x-large; padding:22 22 22 22; text-decoration: blink; color: red;}
			form, .olControlPermalink {font-size: x-small; font-family: sans-serif}
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

				if (typeof wms_setup != 'undefined') {
					OpenLayers.loadURL(wms_setup, "", this, drawMap, showError);

				} else {
					alert("Missing wmssetup parameter!");
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

				//map.events.on( { changeLayer: changeLegend } );
				this.map.events.register("changelayer", this, changeLayer);

				var coastlines_url = "http://wms.met.no/maps/world.map?";
				if (map.projection == "EPSG:32661") {
					coastlines_url = "http://wms.met.no/maps/northpole.map?";
				} else if (map.projection == "EPSG:32761") {
					coastlines_url = "http://wms.met.no/maps/southpole.map?";
				}

				var coastlines = new OpenLayers.Layer.WMS(
					"Met.no kart",
					coastlines_url,
					{
						transparent: "true",
						layers: 'borders'
					},
					{
						isBaseLayer: false
					}
				);

				try {
					map.addLayer(coastlines);
				} catch (error) {
					alert(error);
					return 0;
				}

				map.addControl(layersw);
				map.addControl( new OpenLayers.Control.MousePosition() );
				map.addControl( new OpenLayers.Control.PanZoomBar() );
				map.addControl( new OpenLayers.Control.Navigation() );
				map.addControl( new OpenLayers.Control.ScaleLine() );
				map.addControl( new OpenLayers.Control.Permalink('permalink') );
				//map.addControl( new OpenLayers.Control.OverviewMap( {layers: [coastlines]} ) );

				document.getElementById('map').style.height = map.getSize().h - 60;
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
				//document.getElementById('shortdesc').appendChild(a);

				// set page headings
				//var heading = map.layers[0].name;
				//document.title = heading;
				//document.getElementById('title').appendChild( document.createTextNode(heading) );

			}

			function showError(response) {
				var b = document.createElement('b');
				b.appendChild( document.createTextNode("Could not contact WMS server! ") );
				document.getElementById('shortdesc').appendChild(b);
				document.getElementById('shortdesc').appendChild( document.createElement('br') );
				document.getElementById('shortdesc').appendChild( document.createTextNode("Error from backend is: " + response.status + " " + response.statusText) );
			}

		</script>
	</head>
	<body onload="init()">
		<img id="legend" src="../img/blank.gif"
				style="float: right; position: relative; top: 200px; z-index: 1000"> <!--fix vpos-->
		<form name="form1" action="#">
			Style:
			<select name="wmsstyle" id="wmsstyle" onChange="changeStyle(this[this.selectedIndex].value)"></select>
			<span id="shortdesc"><!--Data file (direct): --></span>
		</form>
		<div id="map" class="largemap"></div>
		<div id="docs"><p id="warning">Javascript must be enabled for WMS client to work!</p></div>
		<!--<div id="tags"></div>-->
	</body>
</html>
