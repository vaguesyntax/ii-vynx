import QtQuick
import QtQuick.Layouts
import qs.modules.common

Resource {
    id: r

    property string valueOverride: ""

        function _applyOverride() {
        if (!r.valueOverride || r.valueOverride.length === 0) return;

            function findText(item) {
            if (!item || !item.children) return null;
            for (let i = 0; i < item.children.length; i++) {
                let ch = item.children[i];
                if (ch && ch.toString && String(ch).indexOf("QQuickText") !== -1) return ch;
                let inner = findText(ch);
                if (inner) return inner;
            }
            return null;
        }

        let t = findText(r);
        if (t) t.text = r.valueOverride;
    }

    Component.onCompleted: _applyOverride()
    onValueOverrideChanged: _applyOverride()
}
