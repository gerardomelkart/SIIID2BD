#!/usr/bin/env bash
set -euo pipefail
umask 077

# Uso: ejecutarMantenimientoGeneral.sh [simular|aplicar]
# Configuración de opc: /home/opc/.config/siiid2/mantenimiento.env
MODO_MANTENIMIENTO="${1:-simular}"
case "$MODO_MANTENIMIENTO" in
    simular) APLICAR_MANTENIMIENTO=0; ACTUALIZAR_ESTADISTICAS=0 ;;
    aplicar) APLICAR_MANTENIMIENTO=1; ACTUALIZAR_ESTADISTICAS=1 ;;
    *) echo 'Uso: ejecutarMantenimientoGeneral.sh [simular|aplicar]' >&2; exit 2 ;;
esac

CONFIG_MANTENIMIENTO="${SIIID_MANTENIMIENTO_CONFIG:-/home/opc/.config/siiid2/mantenimiento.env}"
if [[ ! -r "$CONFIG_MANTENIMIENTO" ]]; then
    echo "No se puede leer la configuración: $CONFIG_MANTENIMIENTO" >&2
    exit 2
fi
# Archivo local de confianza, propiedad del usuario que ejecuta el mantenimiento.
source "$CONFIG_MANTENIMIENTO"
: "${SQLCMD_SERVER:?Falta SQLCMD_SERVER}"
: "${SQLCMD_USER:?Falta SQLCMD_USER}"
: "${SQLCMDPASSWORD:?Falta SQLCMDPASSWORD}"
export SQLCMDPASSWORD

SQLCMD_MANTENIMIENTO="${SQLCMD_BIN:-}"
if [[ -z "$SQLCMD_MANTENIMIENTO" ]]; then
    for candidato in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd; do
        if [[ -x "$candidato" ]]; then SQLCMD_MANTENIMIENTO="$candidato"; break; fi
    done
fi
if [[ -z "$SQLCMD_MANTENIMIENTO" ]]; then
    SQLCMD_MANTENIMIENTO="$(command -v sqlcmd || true)"
fi
if [[ ! -x "$SQLCMD_MANTENIMIENTO" ]]; then
    echo 'No se encontró sqlcmd. Indique su ruta absoluta en SQLCMD_BIN.' >&2
    exit 2
fi

LOG_MANTENIMIENTO_DIR="${SIIID_MANTENIMIENTO_LOG_DIR:-/home/opc/mantenimiento_siiid2/logs}"
mkdir -p "$LOG_MANTENIMIENTO_DIR"
LOG_MANTENIMIENTO="$(mktemp "$LOG_MANTENIMIENTO_DIR/mantenimiento_$(date +%Y%m%d_%H%M%S)_XXXXXX.log")"
exec > >(tee -a "$LOG_MANTENIMIENTO") 2>&1

echo "Inicio: $(date --iso-8601=seconds). Modo: $MODO_MANTENIMIENTO. Base: siiid2."
OPCIONES_MANTENIMIENTO=(-S "$SQLCMD_SERVER" -U "$SQLCMD_USER" -d siiid2 -b -V 16 -r 1 -l 30 -t 0)
# Active únicamente si la instancia usa un certificado autofirmado conocido.
if [[ "${SQLCMD_TRUST_SERVER_CERTIFICATE:-0}" == 1 ]]; then
    OPCIONES_MANTENIMIENTO+=(-C)
fi

if "$SQLCMD_MANTENIMIENTO" "${OPCIONES_MANTENIMIENTO[@]}" \
    -Q "SET IMPLICIT_TRANSACTIONS OFF; EXEC dbo.usp_mantenimiento_general @EjecutarMantenimiento=$APLICAR_MANTENIMIENTO, @ActualizarEstadisticas=$ACTUALIZAR_ESTADISTICAS;"; then
    echo "Fin correcto: $(date --iso-8601=seconds). Registro: $LOG_MANTENIMIENTO"
else
    RESULTADO_MANTENIMIENTO=$?
    echo "ERROR: sqlcmd terminó con código $RESULTADO_MANTENIMIENTO. Registro: $LOG_MANTENIMIENTO" >&2
    exit "$RESULTADO_MANTENIMIENTO"
fi
