#!/bin/bash
# Toggle GameMode for Hyprland
STATE_FILE="/tmp/octagonos-gamemode-state"

if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
    pkexec octagonos-gamemode off
    notify-send -u normal -i preferences-desktop-gaming "OctagonOS GameMode" "Perfil de Juego DESACTIVADO (Modo Equilibrado)"
else
    touch "$STATE_FILE"
    pkexec octagonos-gamemode on
    notify-send -u critical -i preferences-desktop-gaming "OctagonOS GameMode" "Perfil de Juego ACTIVADO (Máximo Rendimiento)"
fi
