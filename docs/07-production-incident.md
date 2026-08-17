# Production Incident / Debugging

Deploy'dan 20 dakika sonra feedback API yavaşladı (p95 400ms -> 9s), PostgreSQL CPU
%85'e çıktı, Sidekiq queue birikmeye başladı, error rate %2 -> %8.

## İlk yapılacaklar

- Deploy zamanı ile incident'in başlangıcı örtüşüyor mu, önce onu doğrula.
- APM'den hangi endpoint/query yavaşlamış bak.
- `pg_stat_activity` ile o an çalışan/bloke sorgulara bak.
- Son deploy'da migration veya yeni bir query pattern (N+1, eksik index) var mı kontrol et.
- Henüz canlıya dokunma, kanıt topla; rollback'e hazır ol ama basma.

## Nereye bakılır

- `pg_stat_statements`: hangi query deploy sonrası yavaşlamış.
- `pg_stat_activity`: lock wait'ler, açık kalan transaction'lar.
- Connection pool: checkout wait, pool doluluğu.
- APM trace: tek request kaç DB çağrısı yapıyor (N+1 belirtisi).
- Sidekiq queue depth ve uygulama logları.

## Rollback

- Deploy ile net zaman korelasyonu varsa ve kök neden 15 dakikada bulunamadıysa rollback.
- Migration geri dönüşü yoksa (kolon drop gibi) sadece kod rollback yeterli olmayabilir,
  forward-fix gerekebilir.

## N+1 / eksik index doğrulama

- Şüpheli query'e `EXPLAIN ANALYZE` çalıştır, `Seq Scan` görüyorsan index eksik demektir.
- Tek request'te DB çağrı sayısı request sayısıyla orantılı artıyorsa bu N+1'dir.

## Kalıcı fix sonrası

- Kritik query'ler için query-count testi ekle.
- Eksik index'i migration olarak ekle.
- Yavaş query için alarm kur.
- Deploy sonrası ilk 15-30 dakikayı özel izleyen bir "canary window" alışkanlığı ekle.
