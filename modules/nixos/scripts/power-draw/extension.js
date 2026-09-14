import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';

// The composite device exists whatever the battery happens to be named
const upowerDevice = {
    name: 'org.freedesktop.UPower',
    path: '/org/freedesktop/UPower/devices/DisplayDevice',
    interface: 'org.freedesktop.UPower.Device',
};

const iconName = 'power-profile-performance-symbolic';
const charging = 1;

const PowerDrawIndicator = GObject.registerClass(
class PowerDrawIndicator extends QuickSettings.SystemIndicator {
    _init() {
        super._init();

        this._icon = this._addIndicator();
        this._icon.icon_name = iconName;

        this._label = new St.Label({
            style_class: 'power-draw-label',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this.add_child(this._label);

        this._connectToUPower();
    }

    _connectToUPower() {
        this._proxy = new Gio.DBusProxy({
            g_connection: Gio.DBus.system,
            g_name: upowerDevice.name,
            g_object_path: upowerDevice.path,
            g_interface_name: upowerDevice.interface,
        });

        this._changedId = this._proxy.connect('g-properties-changed', () => this._refresh());

        // Async so a slow bus cannot stall the shell during enable()
        this._proxy.init_async(GLib.PRIORITY_DEFAULT, null, (proxy, result) => {
            try {
                proxy.init_finish(result);
                this._refresh();
            } catch (error) {
                console.error(`power-draw: cannot reach upower: ${error.message}`);
            }
        });
    }

    _refresh() {
        const state = this._proxy.get_cached_property('State')?.unpack();
        const watts = this._proxy.get_cached_property('EnergyRate')?.unpack();

        if (!(watts >= 0)) {
            this._label.text = '';
            return;
        }

        // A leading plus marks energy going into the battery rather than system draw
        const direction = state === charging ? '+' : '';
        this._label.text = `${direction}${watts.toFixed(1)} W`;
    }

    destroy() {
        if (this._changedId)
            this._proxy.disconnect(this._changedId);
        this._proxy = null;
        super.destroy();
    }
});

export default class PowerDrawExtension extends Extension {
    enable() {
        this._indicator = new PowerDrawIndicator();
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
    }

    disable() {
        this._indicator.destroy();
        this._indicator = null;
    }
}
