# HZ_NAME=RF Environment Summary
# HZ_DESC=Pasif RF arayüz ve kanal ortamı özeti
module_main(){ echo 'RF summary: passive inspection only'; command -v iw >/dev/null && iw dev 2>/dev/null|grep -E 'Interface|type' || echo 'iw not installed'; }
