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
			OpenLayers.ProxyHost = "./wmsProxy.php?url=";

			//read CGI args
			var args = new OpenLayers.Util.getArgs();
			var wms_url = args.wmsurl;
			//alert(wms_url);

			var wmsCapabilities;
			var wmsLayers;
			var error;

			function init(){
				// run after document is loaded

				// remove js warning
				document.getElementById('docs').removeChild( document.getElementById('warning') );

				if (wms_url != '') {
					// do nothing if query string is empty
					OpenLayers.loadURL(wms_url,
						"?service=WMS&version=1.3.0&request=GetCapabilities",
						this, drawMap);
					// Print resource link for debugging
					var a = document.createElement("a");
					a.href = wms_url + "?service=WMS&version=1.3.0&request=GetCapabilities";
					a.appendChild( document.createTextNode(wms_url) );
					document.getElementById('shortdesc').appendChild(a);
				}
			}

			function changeLegend(event) {
				// triggered when user changes layer
				if (event.layer.isBaseLayer) {
					document.getElementById('legend').src = event.layer.legend;
				}
			}

			function drawMap(response) {

				wmsParser = new OpenLayers.Format.WMSCapabilities();
				try {
					// IE chokes here on bad XML, Firefox just goes on...
					wmsCapabilities = wmsParser.read(response.responseText);
				} catch (error) {
					alert("Invalid Capabilities XML from mapserver:\n  " + error + "\nContent:\n  " + response.responseText);
				}

				var layersw = new OpenLayers.Control.LayerSwitcher({'autoActivate': true, 'ascending': false});

				var options = {
						maxExtent: new OpenLayers.Bounds(-3000000,-3000000,7000000,7000000),
						units: 'm',
						projection: "EPSG:32661",
						controls: [
								new OpenLayers.Control.Navigation(),
								new OpenLayers.Control.PanZoomBar(),
								layersw,
								new OpenLayers.Control.Permalink(),
								new OpenLayers.Control.ScaleLine(),
								new OpenLayers.Control.Permalink('permalink'),
								new OpenLayers.Control.MousePosition(),
								//new OpenLayers.Control.OverviewMap(),
								new OpenLayers.Control.KeyboardDefaults()
						],
						numZoomLevels: 3,
						maxResolution: 10000
				};

				// setup map and handler
				map = new OpenLayers.Map('map', options);
				this.map.events.register("changelayer", this, changeLegend);

				var borders = new OpenLayers.Layer.WMS(
						"Met.no kart",
						"http://wms.met.no/maps/northpole.map?",
						{
								transparent: "true",
								layers: 'borders'
						},
						{
							isBaseLayer: false
						}
				);

				var layers = [];

				try {
					// This is where Firefox chokes on bad XML
					var wms_href = wmsCapabilities.capability.request.getmap.href;
					wmsLayers = wmsCapabilities.capability.layers;
				} catch (error) {
					alert("Invalid Capabilities XML from mapserver:\n  " + error + "\nContent:\n  " + response.responseText);
				}

				// setup layers from Capabilities doc
				for (var i=0; i < wmsLayers.length; i++) {
					var legend_url = wmsLayers[i].styles[0].legend.href + '&LAYERS=' + wmsLayers[i].name;
					layers.push(
						new OpenLayers.Layer.WMS(
							wmsLayers[i].title,
							wms_href,
							{
								layers: wmsLayers[i].name,
								//transparent: "true",
								format: "image/png",
								styles: "BOXFILL/redblue" // + palette
							},
							{
								//layerObj: wmsLayers[i]
								legend: legend_url
							}
						)
					)
				}

				layers.push(borders); // put map outlines on top

				map.addLayers(layers);
				layersw.maximizeControl(true); // show layerselector maximized
				map.zoomToExtent(map.maxExtent);

				// set legend URL (have to set both LAYER and LAYERS due to bug in ncWMS)
				document.getElementById('legend').src = wmsLayers[0].styles[0].legend.href + '&LAYERS=' + wmsLayers[0].name;

				// set page headings
				var heading = wmsCapabilities.capability.nestedLayers[0].nestedLayers[0].title;
				document.title = heading;
				document.getElementById('title').appendChild( document.createTextNode(heading) );

			}
		</script>
	</head>
	<body onload="init()">
		<h1 id="title" style="font-size: large">WMS Client: </h1>
		<div id="tags"></div>
		<img id="legend" src="../img/blank.gif"
				style="float: right;position:relative;top:350px;z-index:1000">
		<div id="map" class="largemap"></div>
		<div id="docs"><p id="warning">Javascript must be enabled for WMS client to work!</p></div>
		<p id="shortdesc">Data file (direct): </p>
	</body>
</html>
