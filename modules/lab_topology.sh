# HZ_NAME=Lab Topology
# HZ_DESC=Yalnızca açıkça tanımlı lab subnet için topoloji özeti
module_main(){ [[ -n "${LAB_SUBNET:-}" ]] || { echo 'Set LAB_SUBNET before lab topology discovery.'; return; }; echo "Authorized lab subnet: $LAB_SUBNET"; command -v ip >/dev/null && ip route|grep "$LAB_SUBNET"||true; }
