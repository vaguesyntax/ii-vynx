#!/usr/bin/env fish
function toff -d "Disable touchpad"
    hyprctl keyword "device[pnp0c50:00-04f3:30aa-touchpad]:enabled false"
    hyprctl keyword "device[etps/2-elantech-touchpad]:enabled false"

    echo "Touchpad disabled."
end
