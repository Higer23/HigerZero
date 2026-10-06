# HZ_NAME=Plugin Doctor
# HZ_DESC=Modül metadata ve Bash syntax sağlık kontrolü
module_main(){ local bad=0 f; for f in modules/*.sh; do grep -q '^# HZ_NAME=' "$f"||bad=1; grep -q '^# HZ_DESC=' "$f"||bad=1; bash -n "$f"||bad=1; done; ((bad==0))&&echo 'Plugin Doctor: PASS'||echo 'Plugin Doctor: CHECK'; return "$bad"; }
