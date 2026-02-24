#!/usr/bin/env fish
function ton -d "Enable touchpad"
    hyprctl keyword "device[pnp0c50:00-04f3:30aa-touchpad]:enabled true"
    hyprctl keyword "device[etps/2-elantech-touchpad]:enabled true"

    echo "Touchpad enabled."
end
