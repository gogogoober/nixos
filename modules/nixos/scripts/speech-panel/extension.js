import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as Util from 'resource:///org/gnome/shell/misc/util.js';

const runtimeDir = GLib.get_user_runtime_dir();
const monitorRateLimitMs = 100;

const toggles = [
    {
        role: 'speech-panel-dictate',
        name: 'Dictate',
        iconName: 'audio-input-microphone-symbolic',
        command: ['dictate'],
        stateFile: 'dictate.state',
        styleFor: state => ({
            recording: 'speech-panel-recording',
            transcribing: 'speech-panel-busy',
            ready: 'speech-panel-ready',
        })[state] ?? null,
    },
    {
        role: 'speech-panel-speak',
        name: 'Speak selection',
        iconName: 'audio-speakers-symbolic',
        command: ['speak-selection'],
        stateFile: 'speak-selection.pgid',
        styleFor: state => (state === null ? null : 'speech-panel-speaking'),
    },
];

function readState(path) {
    try {
        const [, bytes] = GLib.file_get_contents(path);
        return new TextDecoder().decode(bytes).trim();
    } catch {
        return null;
    }
}

function createIndicator(toggle) {
    const indicator = new PanelMenu.Button(0.0, toggle.name, true);
    const icon = new St.Icon({
        icon_name: toggle.iconName,
        style_class: 'system-status-icon',
    });
    indicator.add_child(icon);

    const click = new Clutter.ClickGesture();
    click.connect('recognize', () => Util.spawn(toggle.command));
    indicator.add_action(click);

    const path = GLib.build_filenamev([runtimeDir, toggle.stateFile]);
    let activeStyle = null;
    const refresh = () => {
        if (activeStyle)
            icon.remove_style_class_name(activeStyle);
        activeStyle = toggle.styleFor(readState(path));
        if (activeStyle)
            icon.add_style_class_name(activeStyle);
    };

    const monitor = Gio.File.new_for_path(path).monitor_file(Gio.FileMonitorFlags.NONE, null);
    monitor.set_rate_limit(monitorRateLimitMs);
    monitor.connect('changed', refresh);
    indicator.connect('destroy', () => monitor.cancel());
    refresh();

    return indicator;
}

export default class SpeechPanelExtension extends Extension {
    enable() {
        this._indicators = toggles.map((toggle, position) => {
            const indicator = createIndicator(toggle);
            Main.panel.addToStatusArea(toggle.role, indicator, position, 'right');
            return indicator;
        });
    }

    disable() {
        this._indicators.forEach(indicator => indicator.destroy());
        this._indicators = null;
    }
}
