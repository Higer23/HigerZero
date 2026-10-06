# HZ_NAME=Self-Test
# HZ_DESC=Framework ve tüm modüller için syntax/dependency testi
module_main(){ run_self_test; }
run_self_test(){ local bad=0 f; check_dependencies||bad=1; bash -n higerzero.sh||bad=1; for f in core/*.sh modules/*.sh gui/*.sh; do bash -n "$f"||bad=1; done; ((bad==0))&&echo 'HigerZero Self-Test: PASS'||echo 'HigerZero Self-Test: FAIL'; return "$bad"; }
