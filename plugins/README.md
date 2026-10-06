# Plugin API

Tek dosya ile modül ekleyin:

```bash
# HZ_NAME=My Module
# HZ_DESC=Short description
module_main(){ echo 'Hello'; }
```

Dosyayı `modules/my_module.sh` olarak kaydedin. Yeniden başlatınca otomatik görünür. Merkezi registry yoktur. Aktif saldırı, credential harvesting ve trafik kesme modülleri kabul edilmez.
