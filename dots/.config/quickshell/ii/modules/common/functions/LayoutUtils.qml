import Quickshell
import qs.modules.common
pragma Singleton

// TODO: move other common layout functions here too

Singleton {
    function listCardTopRadius(index, count, radius) {
        if (count == 1 || index == 0) return radius
        return Appearance.rounding.verysmall
    }

    function listCardBottomRadius(index, count, radius) {
        if (count == 1 || index == count - 1) return radius
        return Appearance.rounding.verysmall
    }
}
