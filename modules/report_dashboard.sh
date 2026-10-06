# HZ_NAME=Report Dashboard
# HZ_DESC=Rapor ve log dosyalarının hızlı özeti
module_main(){ echo 'Reports:'; find "${REPORT_DIR:-reports}" -maxdepth 1 -type f -printf '  %f\n' 2>/dev/null||true; echo 'Logs:'; find "${LOG_DIR:-logs}" -maxdepth 1 -type f -printf '  %f\n' 2>/dev/null||true; }
