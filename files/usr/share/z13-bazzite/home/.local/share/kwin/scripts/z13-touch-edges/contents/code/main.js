// Touchscreen edge swipes that KWin has no built-in action for. They open Plasma widgets through the
// global shortcuts ~/z13-ipad-edges.sh gave them (plasmashell "activate widget <id>").
// Top and bottom = show the hidden top panels and dock in tablet mode, through ~/.local/bin/z13-ipad-mode.
// Right = app switcher: KWin's Overview shortcut (Overview's own touch border didn't fire reliably).
function widget(id) {
    return function () {
        callDBus("org.kde.kglobalaccel", "/component/plasmashell", "org.kde.kglobalaccel.Component",
                 "invokeShortcut", "activate widget " + id);
    };
}
registerTouchScreenEdge(KWin.ElectricTop, function () {  // top panels
    callDBus("org.z13.IpadMode", "/org/z13/IpadMode", "org.z13.IpadMode", "ShowTopPanels");
});
registerTouchScreenEdge(KWin.ElectricLeft, widget(73));  // notifications
registerTouchScreenEdge(KWin.ElectricBottom, function () {  // dock
    callDBus("org.z13.IpadMode", "/org/z13/IpadMode", "org.z13.IpadMode", "ShowDock");
});
registerTouchScreenEdge(KWin.ElectricRight, function () {  // app switcher
    callDBus("org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component", "invokeShortcut", "Overview");
});
