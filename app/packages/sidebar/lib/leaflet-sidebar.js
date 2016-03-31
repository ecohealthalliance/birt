L.Control.Sidebar = L.Control.extend({
    includes: L.Mixin.Events,

    initialize: function (id, options) {
        var i, child;

        L.setOptions(this, options);

        // Find sidebar HTMLElement
        this._sidebar = L.DomUtil.get(id);

        // Attach touch styling if necessary
        if (L.Browser.touch)
            L.DomUtil.addClass(this._sidebar, 'leaflet-touch');

        // Find sidebar > ul.sidebar-tabs and sidebar > div.sidebar-content
        for (i = this._sidebar.children.length - 1; i >= 0; i--) {
            child = this._sidebar.children[i];
            if (child.tagName == 'UL' &&
                    L.DomUtil.hasClass(child, 'sidebar-tabs'))
                this._tabs = child;

            else if (child.tagName == 'DIV' &&
                    L.DomUtil.hasClass(child, 'sidebar-content'))
                this._container = child;
        }

        // Find sidebar > ul.sidebar-tabs > li
        this._tabitems = [];
        for (i = this._tabs.children.length - 1; i >= 0; i--) {
            child = this._tabs.children[i];
            if (child.tagName == 'LI') {
                this._tabitems.push(child);
                child._sidebar = this;
            }
        }

        // Find sidebar > div.sidebar-content > div.sidebar-pane
        this._panes = [];
        for (i = this._container.children.length - 1; i >= 0; i--) {
            child = this._container.children[i];
            if (child.tagName == 'DIV' &&
                L.DomUtil.hasClass(child, 'sidebar-pane'))
                this._panes.push(child);
        }

        this._hasTouchStart = L.Browser.touch &&
            ('ontouchstart' in document.documentElement);
    },

    addTo: function (map) {
        this._map = map;

        var e = this._hasTouchStart ? 'touchstart' : 'click';
        for (var i = this._tabitems.length - 1; i >= 0; i--) {
            var child = this._tabitems[i];
            L.DomEvent.on(child.firstChild, e, this._onClick, child);
        }

        return this;
    },

    removeFrom: function (map) {
        this._map = null;

        var e = this._hasTouchStart ? 'touchstart' : 'click';
        for (var i = this._tabitems.length - 1; i >= 0; i--) {
            var child = this._tabitems[i];
            L.DomEvent.off(child.firstChild, e, this._onClick);
        }

        return this;
    },

    open: function(id) {
        var i, child;

        // hide old active contents and show new content
        for (i = this._panes.length - 1; i >= 0; i--) {
            child = this._panes[i];
            if (child.id == id)
                L.DomUtil.addClass(child, 'active');
            else if (L.DomUtil.hasClass(child, 'active'))
                L.DomUtil.removeClass(child, 'active');
        }

        // remove old active highlights and set new highlight
        for (i = this._tabitems.length - 1; i >= 0; i--) {
            child = this._tabitems[i];
            if (child.firstChild.hash == '#' + id)
                L.DomUtil.addClass(child, 'active');
            else if (L.DomUtil.hasClass(child, 'active'))
                L.DomUtil.removeClass(child, 'active');
        }

        this.fire('content', { id: id });

        // open sidebar (if necessary)
        if (L.DomUtil.hasClass(this._sidebar, 'collapsed')) {
            this.fire('opening');
            L.DomUtil.removeClass(this._sidebar, 'collapsed');
        }

        return this;
    },

    close: function() {
        // remove old active highlights
        for (var i = this._tabitems.length - 1; i >= 0; i--) {
            var child = this._tabitems[i];
            if (L.DomUtil.hasClass(child, 'active'))
                L.DomUtil.removeClass(child, 'active');
        }

        // close sidebar
        if (!L.DomUtil.hasClass(this._sidebar, 'collapsed')) {
            this.fire('closing');
            L.DomUtil.addClass(this._sidebar, 'collapsed');
        }

        return this;
    },

    _onClick: function(e) {
      e.preventDefault();
      if (this.id === "sidebar-collapse-tab"){
        if (L.DomUtil.hasClass(this.firstChild.firstChild, 'fa-chevron-circle-left')){
          this._sidebar.close();
          L.DomUtil.removeClass(this.firstChild.firstChild, 'fa-chevron-circle-left');
          L.DomUtil.addClass(this.firstChild.firstChild, 'fa-chevron-circle-right');
        }else{
          this._sidebar.open(this.firstChild.hash.slice(1));
          L.DomUtil.removeClass(this.firstChild.firstChild, 'fa-chevron-circle-right');
          L.DomUtil.removeClass(this, 'active');
          L.DomUtil.addClass(this.firstChild.firstChild, 'fa-chevron-circle-left');
        }
      } else if (this.id === "sidebar-table-tab"){
        if (L.DomUtil.hasClass(this, 'active')){
            this._sidebar.close();
            L.DomUtil.removeClass(this.firstChild.firstChild, 'fa-angle-double-right');
            L.DomUtil.addClass(this.firstChild.firstChild, 'fa-angle-double-left');
        } else {
            this._sidebar.open(this.firstChild.hash.slice(1));
            L.DomUtil.removeClass(this.firstChild.firstChild, 'fa-angle-double-left');
            L.DomUtil.addClass(this.firstChild.firstChild, 'fa-angle-double-right');
        }
      } else {
          this._sidebar.open(this.firstChild.hash.slice(1));
          if(this.id !== "sidebar-table-tab"){
            var colLI = this.parentElement.children.namedItem("sidebar-collapse-tab");
            L.DomUtil.removeClass(colLI.firstChild.firstChild, 'fa-chevron-circle-right');
            L.DomUtil.addClass(colLI.firstChild.firstChild, 'fa-chevron-circle-left');
            L.DomUtil.removeClass(colLI, 'active');
          }
      }

    }
});

L.control.sidebar = function (sidebar, options) {
    return new L.Control.Sidebar(sidebar, options);
};
