/*
* Copyright (c) {2021} torikulhabib (https://github.com/gabutakut)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: torikulhabib <torik.habib@Gmail.com>
*/

namespace Gabut {
    public class GabutWindow : Gtk.Window {
        public signal void send_file (string url);
        public signal void stop_server ();
        public signal void restart_server ();
        public signal string get_host ();
        private Gtk.ListBox list_box;
        private Gtk.Revealer search_rev;
        private Preferences preferences = null;
        private QrCode qrcode;
        private Gtk.SearchEntry search_entry;
        private ModeButton view_mode;
        private AlertView nodown_alert;
        private int64 statusactive = 0;

        public GabutWindow (Gtk.Application application) {
            Object (application: application);
        }

        construct {
            get_style_context ().add_class ("rounded");
            nodown_alert = new AlertView (
                _("No File Download"),
                _("Insert Link, add Torrent, add Metalink, Magnet URIs."),
                "com.github.gabutakut.gabutdm"
            );
            nodown_alert.show_all ();
            list_box = new Gtk.ListBox () {
                activate_on_single_click = true,
                selection_mode = Gtk.SelectionMode.BROWSE,
                expand = true
            };
            list_box.set_placeholder (nodown_alert);

            var scrolled = new Gtk.ScrolledWindow (null, null) {
                expand = true,
            };
            scrolled.add (list_box);

            var overlay = new Gtk.Overlay ();
            overlay.add (scrolled);
    
            var frame = new Gtk.Frame (null) {
                width_request = 350,
                height_request = 350,
                expand = true
            };
            frame.add (overlay);
            var image_label = new Gtk.Grid () {
                margin_bottom = 5
            };
            var frame_header = new Gtk.Grid () {
                orientation = Gtk.Orientation.VERTICAL,
                valign = Gtk.Align.CENTER,
                width_request = 650
            };
            frame_header.get_style_context ().add_class (Gtk.STYLE_CLASS_HEADER);
            frame_header.get_style_context ().add_class ("default-decoration");
            search_rev = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN
            };
            search_rev.add (saarch_headerbar ());
            frame_header.add (build_headerbar ());
            frame_header.add (mode_headerbar ());
            frame_header.add (search_rev);
            set_titlebar (frame_header);
            add (frame);
            list_box.remove.connect ((wid)=> {
                view_status ();
            });
            Timeout.add (500,() => {
                bool statact = statusactive > 0;
                set_progress_visible.begin (!is_active && statact);
                set_badge_visible.begin (!is_active && statact);
                return true;
            });
            delete_event.connect (() => {
                if (bool.parse (get_dbsetting (DBSettings.ONBACKGROUND))) {
                    return hide_on_delete ();
                } else {
                    stop_server ();
                    return false;
                }
            });
        }

        private Gtk.HeaderBar build_headerbar () {
            var headerbar = new Gtk.HeaderBar () {
                hexpand = true,
                title = _("Gabut Download Manager"),
                has_subtitle = false,
                show_close_button = true,
                decoration_layout = "close:maximize"
            };
            headerbar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            var menu_button = new Gtk.Button.from_icon_name ("open-menu", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Open Settings")
            };
            headerbar.pack_end (menu_button);
            menu_button.clicked.connect (()=> {
                if (preferences == null && exec_aria ()) {
                    preferences = new Preferences (application);
                    preferences.restart_server.connect (()=> {
                        restart_server ();
                    });
                    preferences.show_all ();
                    preferences.max_active.connect (()=> {
                        resume_progress ();
                    });
                    preferences.destroy.connect (()=> {
                        preferences = null;
                    });
                }
            });

            var search_button = new Gtk.Button.from_icon_name ("system-search", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Search")
            };
            headerbar.pack_end (search_button);
            search_button.clicked.connect (()=> {
                search_rev.reveal_child = !search_rev.reveal_child;
            });
            search_rev.notify["child-revealed"].connect (()=> {
                view_status ();
                search_entry.text = "";
            });
            var host_button = new Gtk.Button.from_icon_name ("go-home", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Host")
            };
            headerbar.pack_end (host_button);
            host_button.clicked.connect (()=> {
                if (qrcode == null) {
                    qrcode = new QrCode (application);
                    qrcode.show_all ();
                    qrcode.get_host.connect (()=> {
                        return get_host ();
                    });
                    qrcode.destroy.connect (()=> {
                        qrcode = null;
                    });
                }
            });
            var add_button = new Gtk.Button.from_icon_name ("insert-link", Gtk.IconSize.BUTTON) {
                tooltip_text = _("add link")
            };
            add_button.clicked.connect (()=> {
                send_file ("");
            });
            headerbar.pack_start (add_button);
            var torrentbutton = new Gtk.Button.from_icon_name ("document-open", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Open .torrent file")
            };
            headerbar.pack_start (torrentbutton);
            torrentbutton.clicked.connect (()=> {
                var file = run_open_file (this, false);
                if (file != null) {
                    send_file (file[0].get_uri ());
                }
            });
            var resumeall_button = new Gtk.Button.from_icon_name ("media-playback-start", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Start All")
            };
            headerbar.pack_start (resumeall_button);
            resumeall_button.clicked.connect (start_all);

            var stopall_button = new Gtk.Button.from_icon_name ("media-playback-pause", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Pause All")
            };
            headerbar.pack_start (stopall_button);
            stopall_button.clicked.connect (()=> {
                aria_pause_all ();
                Timeout.add_seconds (1, get_active);
            });

            var removeall_button = new Gtk.Button.from_icon_name ("edit-clear", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Remove All")
            };
            headerbar.pack_start (removeall_button);
            removeall_button.clicked.connect (remove_all);
            return headerbar;
        }

        public override void destroy () {
            base.destroy ();
            var downloads = new GLib.List<DownloadRow> ();
            foreach (var row in list_box.get_children ()) {
                if (((DownloadRow) row).url == "") {
                    return;
                }
                if (!db_option_exist (((DownloadRow) row).url)) {
                    set_dboptions (((DownloadRow) row).url, ((DownloadRow) row).hashoption);
                } else {
                    update_optionts (((DownloadRow) row).url, ((DownloadRow) row).hashoption);
                }
                downloads.append ((DownloadRow) row);
            }
            set_download (downloads);
        }

        public GLib.List<string> get_dl_row (int status) {
            var strlist = new GLib.List<string> ();
            foreach (var row in list_box.get_children ()) {
                if (((DownloadRow) row).status == status) {
                    strlist.append (((DownloadRow) row).ariagid);
                }
            }
            return strlist;
        }

        public override void show () {
            base.show ();
            get_download ().foreach ((row)=> {
                if (!get_exist (row.url)) {
                    list_box.add (row);
                    row.notify_property ("status");
                    row.statuschange.connect ((ariagid)=> {
                        resume_progress (ariagid);
                        view_status ();
                    });
                    row.destroy.connect (()=> {
                        resume_progress ();
                        view_status ();
                    });
                    if (list_box.get_selected_row () == null) {
                        list_box.select_row (row);
                        list_box.row_activated (row);
                    }
                }
            });
            get_active ();
        }

        private Gtk.Box mode_headerbar () {
            var headerbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                hexpand = true
            };
            headerbar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            headerbar.get_style_context ().add_class ("default-decoration");
            view_mode = new ModeButton () {
                hexpand = false,
                margin = 2
            };
            view_mode.append_text (_("All"));
            view_mode.append_text (_("Downloading"));
            view_mode.append_text (_("Paused"));
            view_mode.append_text (_("Complete"));
            view_mode.append_text (_("Waiting"));
            view_mode.append_text (_("Error"));
            view_mode.selected = 0;
            view_mode.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            headerbar.set_center_widget (view_mode);
            view_mode.notify["selected"].connect (view_status);
            return headerbar;
        }

        private Gtk.Box saarch_headerbar () {
            var box_s = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box_s.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            box_s.get_style_context ().add_class ("default-decoration");
            search_entry = new Gtk.SearchEntry () {
                placeholder_text = _("Search Download File")
            };
            search_entry.search_changed.connect (view_status);
            box_s.set_center_widget (search_entry);
            return box_s;
        }

        public void resume_progress (string ariagid = "") {
            foreach (var row in list_box.get_children ()) {
                if (((DownloadRow) row).ariagid == ariagid) {
                    ((DownloadRow) row).add_timeout ();
                }
            }
            foreach (var row in list_box.get_children ()) {
                if (((DownloadRow) row).status == StatusMode.WAIT) {
                    aria_unpause (((DownloadRow) row).ariagid);
                    ((DownloadRow) row).add_timeout ();
                }
            }
            get_active ();
        }

        public void fast_respond (string ariagid) {
            foreach (var row in list_box.get_children ()) {
                if (((DownloadRow) row).ariagid == ariagid) {
                    ((DownloadRow) row).update_progress ();
                }
            }
            get_active ();
        }

        private bool get_active () {
            statusactive = 0;
            foreach (var row in list_box.get_children ()) {
                if (((DownloadRow) row).status == StatusMode.ACTIVE) {
                    statusactive++;
                }
            }
            set_badge.begin (statusactive);
            return false;
        }

        public void remove_all () {
            foreach (var row in list_box.get_children ()) {
                ((DownloadRow) row).remove_down ();
            }
            aria_purge_all ();
        }

        public void add_url_box (string url, Gee.HashMap<string, string> options, bool later, int linkmode) {
            if (get_exist (url)) {
                return;
            }

            var row = new DownloadRow.Url (url, options, later, linkmode);
            list_box.add (row);
            row.statuschange.connect ((ariagid)=> {
                resume_progress (ariagid);
                view_status ();
            });
            row.destroy.connect (()=> {
                resume_progress ();
                view_status ();
            });
            if (list_box.get_selected_row () == null) {
                list_box.select_row (row);
                list_box.row_activated (row);
            }
            if (!later) {
                row.download ();
                get_active ();
            }
        }

        private bool get_exist (string url) {
            bool linkexist = false;
            foreach (var row in list_box.get_children ()) {
                if (((DownloadRow) row).url == url) {
                    linkexist = true;
                }
            }
            return linkexist;
        }

        private void start_all () {
            foreach (var row in list_box.get_children ()) {
                if (((DownloadRow) row).status != StatusMode.COMPLETE) {
                    aria_unpause (((DownloadRow) row).ariagid);
                    ((DownloadRow) row).update_progress ();
                }
            }
            Timeout.add_seconds (1, get_active);
        }

        public string set_selected (string ariagid, string selected) {
            string aria_gid = "";
            foreach (var row in list_box.get_children ()) {
                if (((DownloadRow) row).ariagid == ariagid) {
                    aria_gid = ((DownloadRow) row).set_selected (selected);
                }
            }
            return aria_gid;
        }

        public bool has_visible_children () {
            foreach (var child in list_box.get_children ()) {
                if (child.get_child_visible ()) {
                    return true;
                }
            }
            return false;
        }
    
        public void view_status () {
            if (search_rev.child_revealed) {
                list_box.set_filter_func ((item) => {
                    return ((DownloadRow) item).filename.casefold ().contains (search_entry.text.casefold ());
                });
                if (!has_visible_children ()) {
                    var empty_alert = new AlertView (
                        _("No Search Found"),
                        _("Insert Link, add Torrent, add Metalink, Magnet URIs."),
                        "system-search"
                    );
                    empty_alert.show_all ();
                    list_box.set_placeholder (empty_alert);
                } else {
                    list_box.set_placeholder (null);
                }
                return;
            }
            switch (view_mode.selected) {
                case 1:
                    list_box.set_filter_func ((item) => {
                        return ((DownloadRow) item).status == StatusMode.ACTIVE;
                    });
                    var active_alert = new AlertView (
                        _("No Active Download"),
                        _("Insert Link, add Torrent, add Metalink, Magnet URIs."),
                        "com.github.gabutakut.gabutdm.active"
                    );
                    active_alert.show_all ();
                    list_box.set_placeholder (active_alert);
                    return;
                case 2:
                    list_box.set_filter_func ((item) => {
                        return ((DownloadRow) item).status == StatusMode.PAUSED;
                    });
                    var nopause_alert = new AlertView (
                        _("No Paused Download"),
                        _("Insert Link, add Torrent, add Metalink, Magnet URIs."),
                        "com.github.gabutakut.gabutdm.pause"
                    );
                    nopause_alert.show_all ();
                    list_box.set_placeholder (nopause_alert);
                    return;
                case 3:
                    list_box.set_filter_func ((item) => {
                        return ((DownloadRow) item).status == StatusMode.COMPLETE;
                    });
                    var nocomp_alerst = new AlertView (
                        _("No Complete Download"),
                        _("Insert Link, add Torrent, add Metalink, Magnet URIs."),
                        "com.github.gabutakut.gabutdm.complete"
                    );
                    nocomp_alerst.show_all ();
                    list_box.set_placeholder (nocomp_alerst);
                    return;
                case 4:
                    list_box.set_filter_func ((item) => {
                        return ((DownloadRow) item).status == StatusMode.WAIT;
                    });
                    var nowait_alert = new AlertView (
                        _("No Waiting Download"),
                        _("Insert Link, add Torrent, add Metalink, Magnet URIs."),
                        "com.github.gabutakut.gabutdm.waiting"
                    );
                    nowait_alert.show_all ();
                    list_box.set_placeholder (nowait_alert);
                    return;
                case 5:
                    list_box.set_filter_func ((item) => {
                        return ((DownloadRow) item).status == StatusMode.ERROR;
                    });
                    var noerr_alert = new AlertView (
                        _("No Error Download"),
                        _("Insert Link, add Torrent, add Metalink, Magnet URIs."),
                        "com.github.gabutakut.gabutdm.error"
                    );
                    noerr_alert.show_all ();
                    list_box.set_placeholder (noerr_alert);
                    return;
                default:
                    list_box.set_filter_func (null);
                    if (!has_visible_children ()) {
                        list_box.set_placeholder (nodown_alert);
                    }
                    break;
            }
        }
    }
}