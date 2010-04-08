/* Copyright (c) 2006-2008 MetaCarta, Inc., published under the Clear BSD
 * license.  See http://svn.openlayers.org/trunk/openlayers/license.txt for the
 * full text of the license. */

/**
 * @requires OpenLayers/Format/WMC.js
 * @requires OpenLayers/Format/XML.js
 */

/**
 * Class: OpenLayers.Format.WMC.v1
 * Superclass for WMC version 1 parsers.
 *
 * Inherits from:
 *  - <OpenLayers.Format.XML>
 */
OpenLayers.Format.WMC.v1 = OpenLayers.Class(OpenLayers.Format.XML, {

    /**
     * Property: namespaces
     * {Object} Mapping of namespace aliases to namespace URIs.
     */
    namespaces: {
        ol: "http://openlayers.org/context",
        wmc: "http://www.opengis.net/context",
        sld: "http://www.opengis.net/sld",
        xlink: "http://www.w3.org/1999/xlink",
        xsi: "http://www.w3.org/2001/XMLSchema-instance"
    },

    /**
     * Property: schemaLocation
     * {String} Schema location for a particular minor version.
     */
    schemaLocation: "",

    /**
     * Method: getNamespacePrefix
     * Get the namespace prefix for a given uri from the <namespaces> object.
     *
     * Returns:
     * {String} A namespace prefix or null if none found.
     */
    getNamespacePrefix: function(uri) {
        var prefix = null;
        if(uri == null) {
            prefix = this.namespaces[this.defaultPrefix];
        } else {
            for(prefix in this.namespaces) {
                if(this.namespaces[prefix] == uri) {
                    break;
                }
            }
        }
        return prefix;
    },

    /**
     * Property: defaultPrefix
     */
    defaultPrefix: "wmc",

    /**
     * Property: rootPrefix
     * {String} Prefix on the root node that maps to the context namespace URI.
     */
    rootPrefix: null,

    /**
     * Property: defaultStyleName
     * {String} Style name used if layer has no style param.  Default is "".
     */
    defaultStyleName: "",

    /**
     * Property: defaultStyleTitle
     * {String} Default style title.  Default is "Default".
     */
    defaultStyleTitle: "Default",

    /**
     * Constructor: OpenLayers.Format.WMC.v1
     * Instances of this class are not created directly.  Use the
     *     <OpenLayers.Format.WMC> constructor instead.
     *
     * Parameters:
     * options - {Object} An optional object whose properties will be set on
     *     this instance.
     */
    initialize: function(options) {
        OpenLayers.Format.XML.prototype.initialize.apply(this, [options]);
    },

    /**
     * Method: read
     * Read capabilities data from a string, and return a list of layers.
     *
     * Parameters:
     * data - {String} or {DOMElement} data to read/parse.
     *
     * Returns:
     * {Array} List of named layers.
     */
    read: function(data) {
        if(typeof data == "string") {
            data = OpenLayers.Format.XML.prototype.read.apply(this, [data]);
        }
        var root = data.documentElement;
        this.rootPrefix = root.prefix;
        var context = {
            version: root.getAttribute("version"),
            id:      root.getAttribute("id")
        };
        this.runChildNodes(context, root);
        return context;
    },

    /**
     * Method: runChildNodes
     */
    runChildNodes: function(obj, node) {
        var children = node.childNodes;
        var childNode, processor, prefix, local;
        for(var i=0, len=children.length; i<len; ++i) {
            childNode = children[i];
            if(childNode.nodeType == 1) {
                prefix = this.getNamespacePrefix(childNode.namespaceURI);
                local = childNode.nodeName.split(":").pop();
                processor = this["read_" + prefix + "_" + local];
                if(processor) {
                    processor.apply(this, [obj, childNode]);
                }
            }
        }
    },

    /**
     * Method: read_wmc_General
     */
    read_wmc_General: function(context, node) {
        this.runChildNodes(context, node);
    },

    /**
     * Method: read_wmc_Window
     */
    read_wmc_Window: function(context, node) {
        context.size = {
            w: parseInt(node.getAttribute("width")),
            h: parseInt(node.getAttribute("height"))
        };
    },

    /**
     * Method: read_wmc_BoundingBox
     */
    read_wmc_BoundingBox: function(context, node) {
        context.projection = node.getAttribute("SRS");
        context.bounds = new OpenLayers.Bounds(
            parseFloat(node.getAttribute("minx")),
            parseFloat(node.getAttribute("miny")),
            parseFloat(node.getAttribute("maxx")),
            parseFloat(node.getAttribute("maxy"))
        );
    },

    /**
     * Method: read_wmc_LayerList
     */
    read_wmc_LayerList: function(context, node) {
        context.layers = [];
        this.runChildNodes(context, node);
    },

    /**
     * Method: read_wmc_Layer
     */
    read_wmc_Layer: function(context, node) {
        var layerInfo = {
            params: this.layerParams || {},
            options: {
                visibility: (node.getAttribute("hidden") != "1"),
                queryable: (node.getAttribute("queryable") == "1")

            },
            formats: [],
            styles: []
        };
        this.runChildNodes(layerInfo, node);
        // set properties common to multiple objects on layer options/params
        layerInfo.params.layers = layerInfo.name;
        layerInfo.options.maxExtent = layerInfo.maxExtent;
        if ("dimensions" in layerInfo) {
            layerInfo.options.dimensions = layerInfo.dimensions;
        }
        layerInfo.options.styles = layerInfo.styles;
        // create the layer
        var layer = this.getLayerFromInfo(layerInfo);
        context.layers.push(layer);
    },

    /**
     * Method: getLayerFromInfo
     * Create a WMS/WFS layer from a layerInfo object.
     *
     * Parameters:
     * layerInfo - {Object} An object representing a WMS/WFS layer.
     *
     * Returns:
     * {<OpenLayers.Layer.WMS>} A WMS layer.
     */
    getLayerFromInfo: function(layerInfo) {
        var options = layerInfo.options;
        if (this.layerOptions) {
            OpenLayers.Util.applyDefaults(options, this.layerOptions);
        }
        var service = layerInfo.server.service.toUpperCase();
        var layer;
        if (service == "OGC:WFS") {
            layer = new OpenLayers.Layer.WFS(
                layerInfo.title,
                layerInfo.server.href,
                layerInfo.params,
                options
            );
        } else if (service == "OGC:WMS") {
            layer = new OpenLayers.Layer.WMS(
                layerInfo.title,
                layerInfo.server.href,
                layerInfo.params,
                options
            );
        }
        return layer;
    },

    /**
     * Method: read_wmc_Extension
     */
    read_wmc_Extension: function(obj, node) {
        this.runChildNodes(obj, node);
    },

    /**
     * Method: read_ol_minScale
     */
    read_ol_minScale: function(context, node) {
        context.minScale = parseFloat(this.getChildValue(node));
    },

    /**
     * Method: read_ol_maxScale
     */
    read_ol_maxScale: function(context, node) {
        context.maxScale = parseFloat(this.getChildValue(node));
    },

    /**
     * Method: read_ol_units
     */
    read_ol_units: function(layerInfo, node) {
        if ("options" in layerInfo) {
            layerInfo.options.units = this.getChildValue(node);
        } else {
            layerInfo.units = this.getChildValue(node);
        }
    },
    /**
     * Method: read_ol_maxExtent
     */
    read_ol_maxExtent: function(obj, node) {
        var bounds = new OpenLayers.Bounds(
            node.getAttribute("minx"), node.getAttribute("miny"),
            node.getAttribute("maxx"), node.getAttribute("maxy")
        );
        obj.maxExtent = bounds;
    },

    /**
     * Method: read_ol_transparent
     */
    read_ol_transparent: function(layerInfo, node) {
        layerInfo.params.transparent = this.getChildValue(node);
    },

    /**
     * Method: read_ol_numZoomLevels
     */
    read_ol_numZoomLevels: function(obj, node) {
        if (obj.options) {
            obj.options.numZoomLevels = parseInt(this.getChildValue(node));
        } else {
            obj.numZoomLevels = parseInt(this.getChildValue(node));
        }
    },

    /**
     * Method: read_ol_opacity
     */
    read_ol_opacity: function(layerInfo, node) {
        layerInfo.options.opacity = parseFloat(this.getChildValue(node));
    },

    /**
     * Method: read_ol_singleTile
     */
    read_ol_singleTile: function(layerInfo, node) {
        layerInfo.options.singleTile = (this.getChildValue(node) == "true");
    },

    /**
     * Method: read_ol_isBaseLayer
     */
    read_ol_isBaseLayer: function(layerInfo, node) {
        layerInfo.options.isBaseLayer = (this.getChildValue(node) == "true");
    },

    /**
     * Method: read_ol_displayInLayerSwitcher
     */
    read_ol_displayInLayerSwitcher: function(layerInfo, node) {
        layerInfo.options.displayInLayerSwitcher =
            (this.getChildValue(node) == "true");
    },

                                                    /*
    read_ol_Control: function(obj, node) {
        var classname = node.getAttribute("class");
        var attr = {};
        obj["_CONTROL"][classname] = 1;
        this.runChildNodes(attr, node);
        delete attr["_CONTROL"];

    },
                                                    */
    read_ol_Param: function(obj, node) {
        var name = node.getAttribute("name");
        var value = node.getAttribute("value");
        obj[name] = value;
    },

    /**
     * Method: read_wmc_Server
     */
    read_wmc_Server: function(layerInfo, node) {
        layerInfo.server = {
            version: node.getAttribute("version"),
            service: node.getAttribute("service"),
            title:   node.getAttribute("title")
        };
        this.runChildNodes(layerInfo.server, node);
        layerInfo.params.version = layerInfo.server.version;
    },

    /**
     * Method: read_wmc_FormatList
     */
    read_wmc_FormatList: function(layerInfo, node) {
        this.runChildNodes(layerInfo, node);
    },

    /**
     * Method: read_wmc_Format
     */
    read_wmc_Format: function(layerInfo, node) {
        var format = this.getChildValue(node);
        layerInfo.formats.push(format);
        if(node.getAttribute("current") == "1") {
            layerInfo.params.format = format;
        }
    },

    /**
     * Method: read_wmc_StyleList
     */
    read_wmc_StyleList: function(layerInfo, node) {
        this.runChildNodes(layerInfo, node);
    },

    /**
     * Method: read_wmc_Style
     */
    read_wmc_Style: function(layerInfo, node) {
        var style = {};
        this.runChildNodes(style, node);
        if(node.getAttribute("current") == "1") {
            // three style types to consider
            // 1) linked SLD
            // 2) inline SLD
            // 3) named style
            // running child nodes always gets name, optionally gets href or body
            if(style.href) {
                layerInfo.params.sld = style.href;
            } else if(style.body) {
                layerInfo.params.sld_body = style.body;
            } else {
                layerInfo.params.styles = style.name;
            }
        }
        layerInfo.styles.push(style);
    },

    /**
     * Method: read_wmc_SLD
     */
    read_wmc_SLD: function(style, node) {
        this.runChildNodes(style, node);
        // style either comes back with an href or a body property
    },

    /**
     * Method: read_sld_StyledLayerDescriptor
     */
    read_sld_StyledLayerDescriptor: function(sld, node) {
        var xml = OpenLayers.Format.XML.prototype.write.apply(this, [node]);
        sld.body = xml;
    },

    /**
     * Method: read_wmc_OnlineResource
     */
    read_wmc_OnlineResource: function(obj, node) {
        obj.href = this.getAttributeNS(
            node, this.namespaces.xlink, "href"
        );
    },

    /**
     * Method: read_wmc_Name
     */
    read_wmc_Name: function(obj, node) {
        var name = this.getChildValue(node);
        if(name) {
            obj.name = name;
        }
    },

    /**
     * Method: read_wmc_Title
     */
    read_wmc_Title: function(obj, node) {
        var title = this.getChildValue(node);
        if(title) {
            obj.title = title;
        }
    },

    /**
     * Method: read_wmc_MetadataURL
     */
    read_wmc_MetadataURL: function(layerInfo, node) {
        var metadataURL = {};
        this.runChildNodes(metadataURL, node);
        /*
        var links = node.getElementsByTagName("OnlineResource");
        if(links.length > 0) {
            this.read_wmc_OnlineResource(metadataURL, links[0]);
        }
        */
        layerInfo.options.metadataURL = metadataURL.href;

    },

    /**
     * Method: read_wmc_KeywordList
     */
    read_wmc_KeywordList: function(context, node) {
        context.keywords = [];
        this.runChildNodes(context.keywords, node);
    },

    /**
     * Method: read_wmc_Keyword
     */
    read_wmc_Keyword: function(keywords, node) {
        keywords.push(this.getChildValue(node));
    },

    /**
     * Method: read_wmc_Abstract
     */
    read_wmc_Abstract: function(obj, node) {
        var abst = this.getChildValue(node);
        if(abst) {
            obj["abstract"] = abst;
        }
    },

    /**
     * Method: read_wmc_LogoURL
     */
    read_wmc_LogoURL: function(context, node) {
        context.logo = {
            width:  node.getAttribute("width"),
            height: node.getAttribute("height"),
            format: node.getAttribute("format")
        };
        this.runChildNodes(context.logo, node);
    },

    /**
     * Method: read_wmc_DescriptionURL
     */
    read_wmc_DescriptionURL: function(context, node) {
        context.descriptionURL = {
            width:  node.getAttribute("width"),
            height: node.getAttribute("height"),
            format: node.getAttribute("format")
        };
        this.runChildNodes(context.descriptionURL, node);
    },

    /**
     * Method: read_wmc_ContactInformation
    */
    read_wmc_ContactInformation: function(context, node) {
        var contact = {};
        this.runChildNodes(contact, node);
        context.contactInformation = contact;
    },

    /**
     * Method: read_wmc_ContactPersonPrimary
     */
    read_wmc_ContactPersonPrimary: function(contact, node) {
        var personPrimary = {};
        this.runChildNodes(personPrimary, node);
        contact.personPrimary = personPrimary;
    },

    /**
     * Method: read_wmc_ContactPerson
     */
    read_wmc_ContactPerson: function(primaryPerson, node) {
        var person = this.getChildValue(node);
        if (person) {
            primaryPerson.person = person;
        }
    },

    /**
     * Method: read_wmc_ContactOrganization
     */
    read_wmc_ContactOrganization: function(primaryPerson, node) {
        var organization = this.getChildValue(node);
        if (organization) {
            primaryPerson.organization = organization;
        }
    },

    /**
     * Method: read_wmc_ContactPosition
     */
    read_wmc_ContactPosition: function(contact, node) {
        var position = this.getChildValue(node);
        if (position) {
            contact.position = position;
        }
    },

    /**
     * Method: read_wmc_ContactAddress
     */
    read_wmc_ContactAddress: function(contact, node) {
        var contactAddress = {};
        this.runChildNodes(contactAddress, node);
        contact.contactAddress = contactAddress;
    },

    /**
     * Method: read_wmc_AddressType
     */
    read_wmc_AddressType: function(contactAddress, node) {
        var type = this.getChildValue(node);
        if (type) {
            contactAddress.type = type;
        }
    },

    /**
     * Method: read_wmc_Address
     */
    read_wmc_Address: function(contactAddress, node) {
        var address = this.getChildValue(node);
        if (address) {
            contactAddress.address = address;
        }
    },

    /**
     * Method: read_wmc_City
     */
    read_wmc_City: function(contactAddress, node) {
        var city = this.getChildValue(node);
        if (city) {
            contactAddress.city = city;
        }
    },

    /**
     * Method: read_wmc_StateOrProvince
     */
    read_wmc_StateOrProvince: function(contactAddress, node) {
        var stateOrProvince = this.getChildValue(node);
        if (stateOrProvince) {
            contactAddress.stateOrProvince = stateOrProvince;
        }
    },

    /**
     * Method: read_wmc_PostCode
     */
    read_wmc_PostCode: function(contactAddress, node) {
        var postcode = this.getChildValue(node);
        if (postcode) {
            contactAddress.postcode = postcode;
        }
    },

    /**
     * Method: read_wmc_Country
     */
    read_wmc_Country: function(contactAddress, node) {
        var country = this.getChildValue(node);
        if (country) {
            contactAddress.country = country;
        }
    },

    /**
     * Method: read_wmc_ContactVoiceTelephone
     */
    read_wmc_ContactVoiceTelephone: function(contact, node) {
        var phone = this.getChildValue(node);
        if (phone) {
            contact.phone = phone;
        }
    },

    /**
     * Method: read_wmc_ContactFacsimileTelephone
     */
    read_wmc_ContactFacsimileTelephone: function(contact, node) {
        var fax = this.getChildValue(node);
        if (fax) {
            contact.fax = fax;
        }
    },

    /**
     * Method: read_wmc_ContactElectronicMailAddress
     */
    read_wmc_ContactElectronicMailAddress: function(contact, node) {
        var email = this.getChildValue(node);
        if (email) {
            contact.email = email;
        }
    },

    /**
     * Method: read_wmc_DataURL
     */
    read_wmc_DataURL: function(layerInfo, node) {
        layerInfo.dataURL = {
            width:  node.getAttribute("width"),
            height: node.getAttribute("height"),
            format: node.getAttribute("format")
        };
        this.runChildNodes(layerInfo.dataURL, node);
    },


    /**
     * Method: read_wmc_LegendURL
     */
    read_wmc_LegendURL: function(style, node) {
        var legend = {
            width:  node.getAttribute('width'),
            height: node.getAttribute('height'),
            formats: []
        };
        this.runChildNodes(legend, node);
        /*
        var links = node.getElementsByTagName("OnlineResource");
        if(links.length > 0) {
            this.read_wmc_OnlineResource(legend, links[0]);
        }
        */
        style.legend = legend;
    },

    /**
     * Method: read_wmc_SRS
     */
    read_wmc_SRS: function(layerInfo, node) {
        var srs    = this.getChildValue(node);
        if (typeof layerInfo.projections != "array") {
            layerInfo.projections = [];
        }
        if (srs.indexOf(" ")) {
            var values = srs.split(/ +/);
            layerInfo.projections = layerInfo.projections.concat(values);
        } else {
            layerInfo.projections.push(srs);
        }
    },

    /**
     * Method: read_wmc_DimensionList
     */
    read_wmc_DimensionList: function(layerInfo, node) {
        layerInfo.options.dimensions = {};
        this.runChildNodes(layerInfo.options.dimensions, node);
    },
    /**
     * Method: read_wmc_Dimension
     */
    read_wmc_Dimension: function(dimensions, node) {
        var name = node.getAttribute("name").toLowerCase();

        var dim = {
            name:        name,
            units:       node.getAttribute("units"),
            unitSymbol:  node.getAttribute("unitSymbol"),
            userValue:   node.getAttribute("userValue"),
            nearestVal:  node.getAttribute("nearestValue")   === "1",
            multipleVal: node.getAttribute("multipleValues") === "1",
            current:     node.getAttribute("current")        === "1",
            "default":   node.getAttribute("default")        ||  ""
        };
        var values = this.getChildValue(node);
        dim.values = values.split(",");

        dimensions[dim.name] = dim;
    },

    /**
     * Method: write
     *
     * Parameters:
     * context - {Object} An object representing the map context.
     * options - {Object} Optional object.
     *
     * Returns:
     * {String} A WMC document string.
     */
    write: function(context, options) {
        var root = this.createElementDefaultNS("ViewContext");
        this.setAttributes(root, {
            version: this.VERSION,
            id: (options && typeof options.id == "string") ?
                    options.id :
                    OpenLayers.Util.createUniqueID("OpenLayers_Context_")
        });

        // add schemaLocation attribute
        this.setAttributeNS(
            root, this.namespaces.xsi,
            "xsi:schemaLocation", this.schemaLocation
        );

        // required General element
        root.appendChild(this.write_wmc_General(context));

        // required LayerList element
        root.appendChild(this.write_wmc_LayerList(context));

        return OpenLayers.Format.XML.prototype.write.apply(this, [root]);
    },

    /**
     * Method: createElementDefaultNS
     * Shorthand for createElementNS with namespace from <defaultPrefix>.
     *     Can optionally be used to set attributes and a text child value.
     *
     * Parameters:
     * name - {String} The qualified node name.
     * childValue - {String} Optional value for text child node.
     * attributes - {Object} Optional object representing attributes.
     *
     * Returns:
     * {Element} An element node.
     */
    createElementDefaultNS: function(name, childValue, attributes) {
        var node = this.createElementNS(
            this.namespaces[this.defaultPrefix],
            name
        );
        if(childValue) {
            node.appendChild(this.createTextNode(childValue));
        }
        if(attributes) {
            this.setAttributes(node, attributes);
        }
        return node;
    },

    /**
     * Method: setAttributes
     * Set multiple attributes given key value pairs from an object.
     *
     * Parameters:
     * node - {Element} An element node.
     * obj - {Object} An object whose properties represent attribute names and
     *     values represent attribute values.
     */
    setAttributes: function(node, obj) {
        var value;
        for(var name in obj) {
            if (obj[name] == null) {
                continue;
            }
            value = obj[name].toString();
            if(value.match(/[A-Z]/)) {
                // safari lowercases attributes with setAttribute
                this.setAttributeNS(node, null, name, value);
            } else {
                node.setAttribute(name, value);
            }
        }
    },

    /**
     * Method: write_wmc_General
     * Create a General node given an context object.
     *
     * Parameters:
     * context - {Object} Context object.
     *
     * Returns:
     * {Element} A WMC General element node.
     */
    write_wmc_General: function(context) {
        var node = this.createElementDefaultNS("General");

        // optional Window element
        if(context.size) {
            node.appendChild(this.createElementDefaultNS(
                "Window", null,
                {
                    width: context.size.w,
                    height: context.size.h
                }
            ));
        }

        // required BoundingBox element
        var bounds = context.bounds;
        node.appendChild(this.createElementDefaultNS(
            "BoundingBox", null,
            {
                minx: bounds.left.toPrecision(10),
                miny: bounds.bottom.toPrecision(10),
                maxx: bounds.right.toPrecision(10),
                maxy: bounds.top.toPrecision(10),
                SRS: context.projection
            }
        ));

        // required Title element
        node.appendChild(this.createElementDefaultNS(
            "Title", context.title
        ));

        // Optional LogoURL element
        if ("logoURL" in context) {
            node.appendChild(this.write_wmc_URLType(context.logoURL, "LogoURL"));
        }

        // Optional DescriptionURL element
        if ("descriptionURL" in context) {
            node.appendChild(this.write_wmc_URLType(context.descriptionURL, "DescriptionURL"));
        }

        // Optional ContactInformation element
        if ("contactInformation" in context) {
            node.appendChild(this.write_wmc_ContactInformation(context));
        }

        // OpenLayers specific map properties
        node.appendChild(this.write_ol_MapExtension(context));

        return node;
    },

    /**
     * Method: write_wmc_URLType
     * Create a LogoURL/DescriptionURL/MetadataURL/LegendURL node given a object and elementName.
     *
     * Parameters:
     * obj - {Object} object.
     *
     * Returns:
     * {Element} A WMC element node.
     */
    write_wmc_URLType: function(obj, elName) {
        var node = this.createElementDefaultNS(elName);
        var attr = {};
        var optionalAttributes = ["width", "height", "format"];

        if (typeof obj == "string") {
            node.appendChild(this.write_wmc_OnlineResource(obj));
        } else if (typeof obj == "object") {
            for (var i=0; i<optionalAttributes.length; i++) {
                if (optionalAttributes[i] in obj) {
                    attr[ optionalAttributes[i] ] = obj[ optionalAttributes[i] ];
                }
            }

            this.setAttributes(node, attr);
            node.appendChild(this.write_wmc_OnlineResource(obj.href));
        }
        return node;
    },

    /**
     * Method: write_wmc_ContactInformation
     */
    write_wmc_ContactInformation: function(context) {
        var contact = context.contactInformation;
        var node = this.createElementDefaultNS("ContactInformation");

        if (contact.personPrimary) {
            node.appendChild(this.write_wmc_ContactPersonPrimary(contact.personPrimary));
        }
        if (contact.position) {
            node.appendChild(this.createElementDefaultNS(
                "ContactPosition", contact.position
            ));
        }
        if (contact.contactAddress) {
            node.appendChild(this.write_wmc_ContactAddress(contact.contactAddress));
        }
        if (contact.phone) {
            node.appendChild(this.createElementDefaultNS(
                "ContactVoiceTelephone", contact.phone
            ));
        }
        if (contact.fax) {
            node.appendChild(this.createElementDefaultNS(
                "ContactFacsimileTelephone", contact.fax
            ));
        }
        if (contact.email) {
            node.appendChild(this.createElementDefaultNS(
                "ContactElectronicMailAddress", contact.email
            ));
        }
        return node;
    },

    /**
     * Method: write_wmc_ContactPersonPrimary
     */
    write_wmc_ContactPersonPrimary: function(personPrimary) {
        var node = this.createElementDefaultNS("ContactPersonPrimary");
        if (personPrimary.person) {
            node.appendChild(this.createElementDefaultNS(
                "ContactPerson", personPrimary.person
            ));
        }
        if (personPrimary.organization) {
            node.appendChild(this.createElementDefaultNS(
                "ContactOrganization", personPrimary.organization
            ));
        }
        return node;
    },

    /**
     * Method: write_wmc_ContactAddress
     */
    write_wmc_ContactAddress: function(contactAddress) {
        var node = this.createElementDefaultNS("ContactAddress");
        if (contactAddress.type) {
            node.appendChild(this.createElementDefaultNS(
                "AddressType", contactAddress.type
            ));
        }
        if (contactAddress.address) {
            node.appendChild(this.createElementDefaultNS(
                "Address", contactAddress.address
            ));
        }
        if (contactAddress.city) {
            node.appendChild(this.createElementDefaultNS(
                "City", contactAddress.city
            ));
        }
        if (contactAddress.stateOrProvince) {
            node.appendChild(this.createElementDefaultNS(
                "StateOrProvince", contactAddress.stateOrProvince
            ));
        }
        if (contactAddress.postCode) {
            node.appendChild(this.createElementDefaultNS(
                "PostCode", contactAddress.postCode
            ));
        }
        if (contactAddress.country) {
            node.appendChild(this.createElementDefaultNS(
                "Country", contactAddress.country
            ));
        }
        return node;
    },

    /**
     * Method: write_ol_MapExtension
     */
    write_ol_MapExtension: function(context) {
        var node = this.createElementDefaultNS("Extension");

        var bounds = context.maxExtent;
        if(bounds) {
            var maxExtent = this.createElementNS(
                this.namespaces.ol, "ol:maxExtent"
            );
            this.setAttributes(maxExtent, {
                minx: bounds.left.toPrecision(10),
                miny: bounds.bottom.toPrecision(10),
                maxx: bounds.right.toPrecision(10),
                maxy: bounds.top.toPrecision(10)
            });
            node.appendChild(maxExtent);
        }

        var properties = [
                          "numZoomLevels", "minScale", "maxScale"
        ];
        var child;
        for(var i=0, len=properties.length; i<len; ++i) {
            child = this.createOLPropertyNode(context, properties[i]);
            if(child) {
                node.appendChild(child);
            }
        }

        for (var i=0, len=context.controls.length; i<len; i++) {
            child  = this.write_ol_Control(context.controls[i]);
            if(child) {
                node.appendChild(child);
            }
        }

        return node;
    },

    /**
     * Method: write_wmc_LayerList
     * Create a LayerList node given an context object.
     *
     * Parameters:
     * context - {Object} Context object.
     *
     * Returns:
     * {Element} A WMC LayerList element node.
     */
    write_wmc_LayerList: function(context) {
        var list = this.createElementDefaultNS("LayerList");

        var layer;
        for(var i=0, len=context.layers.length; i<len; ++i) {
            layer = context.layers[i];
            if(layer instanceof OpenLayers.Layer.WMS ||
               layer instanceof OpenLayers.Layer.WFS) {
                list.appendChild(this.write_wmc_Layer(layer));
            }
        }

        return list;
    },

    /**
     * Method: write_wmc_Layer
     * Create a Layer node given a layer object.
     *
     * Parameters:
     * layer - {<OpenLayers.Layer.WMS>} Layer object.
     *
     * Returns:
     * {Element} A WMC Layer element node.
     */
    write_wmc_Layer: function(layer) {
        var node = this.createElementDefaultNS(
            "Layer", null, {
                queryable: layer.queryable ? "1" : "0",
                hidden: layer.visibility ? "0" : "1"
            }
        );

        // required Server element
        node.appendChild(this.write_wmc_Server(layer));

        // required Name element
        node.appendChild(this.createElementDefaultNS(
            "Name", layer.params["LAYERS"]
        ));

        // required Title element
        node.appendChild(this.createElementDefaultNS(
            "Title", layer.name
        ));

        // optional DataURL element
        if (layer.dataURL) {
            node.appendChild(this.write_wmc_URLType(layer.dataURL, "DataURL"));
        }

        // optional MetadataURL element
        if (layer.metadataURL) {
            node.appendChild(this.write_wmc_URLType(layer.metadataURL, "MetaDataURL"));
        }

        // optional SRS element
        if (typeof layer.projections == "array") {
            for (var i=0, len=layer.projections.length; i<len; i++) {
                node.appendChild(this.write_wmc_SRS(layer.projections[i]));
            }
        }

        // optional FormatList element
        node.appendChild(this.write_wmc_FormatList(layer));

        // optional StyleList element
        node.appendChild(this.write_wmc_StyleList(layer));

        // optional DimensionList element
        if (layer.dimensions) {
            node.appendChild(this.write_wmc_DimensionList(layer));
        }

        // OpenLayers specific properties go in an Extension element
        node.appendChild(this.write_wmc_LayerExtension(layer));

        return node;
    },

    /**
     * Method: write_wmc_LayerExtension
     * Add OpenLayers specific layer parameters to an Extension element.
     *
     * Parameters:
     * layer - {<OpenLayers.Layer.WMS>} A WMS layer.
     *
     * Returns:
     * {Element} A WMC Extension element (for a layer).
     */
    write_wmc_LayerExtension: function(layer) {
        var node = this.createElementDefaultNS("Extension");

        var bounds = layer.maxExtent;
        var maxExtent = this.createElementNS(
            this.namespaces.ol, "ol:maxExtent"
        );
        this.setAttributes(maxExtent, {
            minx: bounds.left.toPrecision(10),
            miny: bounds.bottom.toPrecision(10),
            maxx: bounds.right.toPrecision(10),
            maxy: bounds.top.toPrecision(10)
        });
        node.appendChild(maxExtent);

        var param = layer.params["TRANSPARENT"];
        if(param) {
            var trans = this.createElementNS(
                this.namespaces.ol, "ol:transparent"
            );
            trans.appendChild(this.createTextNode(param));
            node.appendChild(trans);
        }

        var properties = [
            "numZoomLevels", "units", "isBaseLayer",
            "opacity", "displayInLayerSwitcher", "singleTile"
        ];
        var child;
        for(var i=0, len=properties.length; i<len; ++i) {
            child = this.createOLPropertyNode(layer, properties[i]);
            if(child) {
                node.appendChild(child);
            }
        }

        return node;
    },

    /**
     * Method: createOLPropertyNode
     * Create a node representing an OpenLayers property.  If the property is
     *     null or undefined, null will be returned.
     *
     * Parameters:
     * object - {Object} An object.
     * prop - {String} A property.
     *
     * Returns:
     * {Element} A property node.
     */
    createOLPropertyNode: function(obj, prop) {
        var node = null;
        if(obj[prop] != null) {
            node = this.createElementNS(this.namespaces.ol, "ol:" + prop);
            node.appendChild(this.createTextNode(obj[prop].toString()));
        }
        return node;
    },

    /**
     * Method: createOLParamNode
     * Create a node representing a key/value pair
     *
     * Parameters:
     * name - {String} The parameter name
     * value - {String} The parameter value
     *
     * Returns:
     * {Element} A property node.
     */
    createOLParamNode: function(name, value) {
        var node = null;
        if (value != null) {
            node = this.createElementNS(this.namespaces.ol, "ol:Param");
            if (value instanceof Element) {
                this.setAttributes(node, {
                    "name": name
                });
                node.appendChild(value);
            } else {
                this.setAttributes(node, {
                    "name": name,
                    "value": value
                });
            }
        }
        return node;
    },

    /**
     * Method: write_ol_Control
     * General method for creating nodes representing Control objects
     *
     * Parameters:
     * control  - {OpenLayers.Control} An OpenLayers Control object.
     * node     - {Element} A control node
     * args     - {Array} List of properties to copy from control object
     *
     * Returns:
     * nothing
     */
    write_ol_Control: function(control) {
        var node = null;
        var classname = control.displayClass.replace(/^olControl/, "");
        node = this.createElementNS(this.namespaces.ol, "ol:Control");
        this.setAttributes(node, {
            "class": classname
        });
        var ignore = {id: 1, CLASS_NAME: 1, displayClass: 1};

        for (var prop in control) {
            //for (var i=0, len=args.length; i<len; i++) {
            //var name = args[i];
            if (prop in ignore) {
                continue;
            }
            var value = control[ prop ];
            var type = typeof value;
            switch (typeof value) {
                case "object":
                    if (value instanceof OpenLayers.Control) {
                        var child = this.write_ol_Control(value);
                        if (child) {
                            var param = this.createOLParamNode(prop, child);
                            node.appendChild(param);
                        }
                    }
                    break;
                case "string":
                    node.appendChild(this.createOLParamNode(prop, value));
                    break;
                case "number":
                    node.appendChild(this.createOLParamNode(prop, value));
                    break;
                case "boolean":
                    node.appendChild(this.createOLParamNode(prop, Number(value)));
                    break;
                case "function":
                    break;
                case "undefined":
                    break;
                default:
                    break;
            }
        }
        return node;
    },

    /**
     * Method: write_ol_ControlNavigation
     * Create a node representing a Navigation Control object
     *
     * Parameters:
     * control - {OpenLayers.Control.Navigation} An OpenLayers Control object.
     * node    - {Element} A control node
     *
     * Returns:
     * nothing
     */
    write_ol_ControlNavigation: function(control, node) {
        var args = ["dragPan", "zoomBox", "zoomWheelEnabled", "handleRightClicks"];
        this.write_ol_Control(control, node, args);
    },

    /**
     * Method: write_ol_ControlDragPan
     * Create a node representing a Navigation Control object
     *
     * Parameters:
     * control - {OpenLayers.Control.Navigation} An OpenLayers Control object.
     * node    - {Element} A control node
     *
     * Returns:
     * nothing
     */
    write_ol_ControlDragPan: function(control, node) {
        var args = ["interval"];
        this.write_ol_Control(control, node, args);
    },

    /**
     * Method: write_ol_ControlDragPan
     * Create a node representing a Navigation Control object
     *
     * Parameters:
     * control - {OpenLayers.Control.Navigation} An OpenLayers Control object.
     * node    - {Element} A control node
     *
     * Returns:
     * nothing
     */
    write_ol_ControlZoomBox: function(control, node) {
        var args = ["out", "alwaysZoom"];
        this.write_ol_Control(control, node, args);
    },

    /**
     * Method: write_ol_ControlLayerSwitcher
     * Create a node representing a LayerSwitcher Control object
     *
     * Parameters:
     * control - {OpenLayers.Control.LayerSwitcher} An OpenLayers Control object.
     * node    - {Element} A control node
     *
     * Returns:
     * nothing
     */
    write_ol_ControlLayerSwitcher: function(control, node) {
        var args = ["activeColor", "ascending"];
        this.write_ol_Control(control, node, args);
    },

    /**
     * Method: write_ol_ControlPanZoomBar
     * Create a node representing a PanZoomBar Control object
     *
     * Parameters:
     * control - {OpenLayers.Control.PanZoomBar} An OpenLayers Control object.
     * node    - {Element} A control node
     *
     * Returns:
     * nothing
     */
    write_ol_ControlPanZoomBar: function(control, node) {
        var args = ["zoomStopWidth", "zoomStopHeight", "zoomWorldIcon"];
        this.write_ol_Control(control, node, args);
    },

    /**
     * Method: write_wmc_Server
     * Create a Server node given a layer object.
     *
     * Parameters:
     * layer - {<OpenLayers.Layer.WMS>} Layer object.
     *
     * Returns:
     * {Element} A WMC Server element node.
     */
    write_wmc_Server: function(layer) {
        var node = this.createElementDefaultNS("Server");
        if (layer instanceof OpenLayers.Layer.WMS) {
            this.setAttributes(node, {
                service: "OGC:WMS",
                version: layer.params["VERSION"]
            });
        } else if (layer instanceof OpenLayers.Layer.WFS) {
            this.setAttributes(node, {
                service: "OGC:WFS",
                version: layer.params["VERSION"]
            });
        }

        // required OnlineResource element
        node.appendChild(this.write_wmc_OnlineResource(layer.url));

        return node;
    },

    /**
     * Method: write_wmc_MetadataURL
     * Create a MetadataURL node given a layer object.
     *
     * Parameters:
     * layer - {<OpenLayers.Layer.WMS>} Layer object.
     *
     * Returns:
     * {Element} A WMC metadataURL element node.
     */
    write_wmc_MetadataURL: function(layer) {
        var node = this.createElementDefaultNS("MetadataURL");

        // required OnlineResource element
        node.appendChild(this.write_wmc_OnlineResource(layer.metadataURL));

        return node;
    },

    /**
     * Method: write_wmc_DescriptionURL
     * Create a DescriptionURL node given a layer object.
     *
     * Parameters:
     * layer - {<OpenLayers.Layer.WMS>} Layer object.
     *
     * Returns:
     * {Element} A WMC DescriptionURL element node.
     */
    write_wmc_DataURL: function(layer) {
        var node = this.createElementDefaultNS("DescriptionURL");
        var desc = layer.descriptionURL;
        var attr = {};

        if ("format" in desc) {
            attr.format = desc.format;
        }

        this.setAttributes(node, attr);

        // required OnlineResource element
        node.appendChild(this.write_wmc_OnlineResource(desc.href));

        return node;
    },

    /**
     * Method: write_wmc_DataURL
     * Create a DataURL node given a layer object.
     *
     * Parameters:
     * layer - {<OpenLayers.Layer.WMS>} Layer object.
     *
     * Returns:
     * {Element} A WMC DataURL element node.
     */
    write_wmc_DataURL: function(layer) {
        var node = this.createElementDefaultNS("DataURL");
        var dataurl = layer.dataURL;
        var attr = {};

        if ("format" in dataurl) {
            attr.format = dataurl.format;
        }

        this.setAttributes(node, attr);

        // required OnlineResource element
        node.appendChild(this.write_wmc_OnlineResource(dataurl.href));

        return node;
    },

    /**
     * Method: write_wmc_SRS
     * Create a SRS node given a layer object.
     *
     * Parameters:
     * layer - {<OpenLayers.Layer.WMS>} Layer object.
     *
     * Returns:
     * {Element} A WMC SRS element node.
     */
    write_wmc_SRS: function(projection) {
        return this.createElementDefaultNS("SRS", projection);
    },

    /**
     * Method: write_wmc_DimensionList
     */
    write_wmc_DimensionList: function(layer) {
        var node = this.createElementDefaultNS("DimensionList");

        for (var dim in layer.dimensions) {
            var attributes = {};
            var dimension = layer.dimensions[dim];
            for (var name in dimension) {
                if (typeof dimension[name] == "boolean") {
                    attributes[name] = Number(dimension[name]);
                } else {
                    attributes[name] = dimension[name];
                }
            }
            var values = attributes.values.join(",");
            delete attributes.values;

            node.appendChild(this.createElementDefaultNS(
                "Dimension", values, attributes
            ));
        }
        return node;
    },

    /**
     * Method: write_wmc_FormatList
     * Create a FormatList node given a layer.
     *
     * Parameters:
     * layer - {<OpenLayers.Layer.WMS>} Layer object.
     *
     * Returns:
     * {Element} A WMC FormatList element node.
     */
    write_wmc_FormatList: function(layer) {
        var node = this.createElementDefaultNS("FormatList");
        node.appendChild(this.createElementDefaultNS(
            "Format", layer.params["FORMAT"], {current: "1"}
        ));

        return node;
    },

    /**
     * Method: write_wmc_StyleList
     * Create a StyleList node given a layer.
     *
     * Parameters:
     * layer - {<OpenLayers.Layer.WMS>} Layer object.
     *
     * Returns:
     * {Element} A WMC StyleList element node.
     */
    write_wmc_StyleList: function(layer) {
        var node = this.createElementDefaultNS("StyleList");
        var style = this.createElementDefaultNS(
            "Style", null, {current: "1"}
        );

        // Style can come from one of three places (prioritized as below):
        // 1) an SLD parameter
        // 2) and SLD_BODY parameter
        // 3) the STYLES parameter

        if(layer.params["SLD"]) {
            // create link from SLD parameter
            var sld = this.createElementDefaultNS("SLD");
            var link = this.write_wmc_OnlineResource(layer.params["SLD"]);
            sld.appendChild(link);
            style.appendChild(sld);
        } else if(layer.params["SLD_BODY"]) {
            // include sld fragment from SLD_BODY parameter
            var sld = this.createElementDefaultNS("SLD");
            var body = layer.params["SLD_BODY"];
            // read in body as xml doc - assume proper namespace declarations
            var doc = OpenLayers.Format.XML.prototype.read.apply(this, [body]);
            // append to StyledLayerDescriptor node
            var imported = doc.documentElement;
            if(sld.ownerDocument && sld.ownerDocument.importNode) {
                imported = sld.ownerDocument.importNode(imported, true);
            }
            sld.appendChild(imported);
            style.appendChild(sld);
        } else {
            // use name(s) from STYLES parameter
            var name = layer.params["STYLES"] ?
                layer.params["STYLES"] : this.defaultStyleName;

            style.appendChild(this.createElementDefaultNS("Name", name));
            style.appendChild(this.createElementDefaultNS(
                "Title", this.defaultStyleTitle
            ));
        }
        node.appendChild(style);
        return node;
    },

    /**
     * Method: write_wmc_OnlineResource
     * Create an OnlineResource node given a URL.
     *
     * Parameters:
     * href - {String} URL for the resource.
     *
     * Returns:
     * {Element} A WMC OnlineResource element node.
     */
    write_wmc_OnlineResource: function(href) {
        var node = this.createElementDefaultNS("OnlineResource");
        this.setAttributeNS(node, this.namespaces.xlink, "xlink:type", "simple");
        this.setAttributeNS(node, this.namespaces.xlink, "xlink:href", href);
        return node;
    },

    CLASS_NAME: "OpenLayers.Format.WMC.v1"

});
