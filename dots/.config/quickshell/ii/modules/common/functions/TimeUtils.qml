pragma Singleton
import Quickshell

Singleton {
    id: root

    function getTimeFormat(baseFormat, withSeconds) {
        let format = baseFormat ?? "hh:mm";
        if (withSeconds) {
            if (!format.includes("ss")) {
                format = format.replace(/mm(\s+[aApP]{1,2})/, "mm:ss$1");
                if (!format.includes("ss"))
                    format = format.replace(/mm/, "mm:ss");
            }
        } else {
            format = format.replace(":ss", "");
        }
        return format;
    }
}
