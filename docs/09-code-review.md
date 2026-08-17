# Code Review

İncelenen kod:

```ruby
def create
  tenant_id = params[:tenant_id]
  feedback = Feedback.create!(params.require(:feedback).permit!)
  customer = Customer.find(feedback.customer_id)
  result = ExternalNlpClient.new.analyze(feedback.comment)
  feedback.update!(sentiment: result[:sentiment], processed: true)
  Rails.logger.info("feedback=#{feedback.attributes}")
  render json: feedback
end
```

En az 6 problem/risk, önceliklendirilmiş:

1. **Tenant güvenliği**: `tenant_id` client'tan geliyor ve hiç doğrulanmıyor. İstenen
   herhangi bir tenant adına feedback yazılabilir, `Customer.find` de tenant'a scope
   değil - başka tenant'ın customer'ına feedback bağlanabilir. `tenant_id` request
   header/API key'den (authenticated tenant) gelmeli, tüm sorgular ona scope
   edilmeli.
2. **Mass assignment**: `params.require(:feedback).permit!` her alanı olduğu gibi
   kabul ediyor - client `sentiment`, `processed` gibi sunucunun set etmesi gereken
   alanları da gönderip override edebilir. Whitelist edilmiş, açık alan listesi
   kullanılmalı.
3. **Senkron external call / timeout-retry yok**: `ExternalNlpClient` request thread'i
   içinde, timeout/retry/circuit breaker olmadan çağrılıyor. NLP servisi yavaşlarsa
   ya da down olursa request de düşer, latency'yi doğrudan client'a yansıtır. Bu iş
   async job'a taşınmalı (bu projede zaten `SentimentJob` bu amaçla var).
4. **Transaction sınırları / tutarsız state**: `Feedback.create!` ile `feedback.update!`
   arasında `Customer.find` ve external NLP call var; ikinci `update!` başarısız
   olursa feedback `processed: false` ve sentiment'siz kalır ama zaten oluşturulmuş
   olur - yarım kalmış state. Feedback create ile pipeline tetikleme tek transaction
   içinde, ağır/dış işler transaction dışında (outbox pattern) olmalı.
5. **PII logging**: `feedback.attributes` doğrudan loglanıyor - `comment` gibi serbest
   metin ve muhtemelen customer bilgisi PII içerebilir, plaintext log'a düşmemeli.
   Loglanacak alanlar whitelist edilmeli, PII redact edilmeli.
6. **Error handling**: `Customer.find` (ActiveRecord::RecordNotFound fırlatır),
   `create!`/`update!` (ActiveRecord::RecordInvalid) ve external call hiçbir yerde
   rescue edilmiyor - hepsi 500 olarak client'a sızıyor, tutarlı bir hata formatı yok.
7. **Latency**: Senkron external call + iki ayrı DB write (create + update) request
   süresini gereksiz uzatıyor; NLP servisinin p99'u API'nin p99'unu doğrudan
   belirliyor.
8. **Testability**: `ExternalNlpClient.new` action içinde doğrudan instantiate
   ediliyor - stub/mock etmek zor, service/job seviyesinde dependency injection
   olmadan test yazmak external call'a bağımlı kalır.

## Değerlendirme başlıkları (referans)

- Tenant güvenliği
- Mass assignment
- Transaction sınırları
- External dependency (senkron çağrı, timeout/retry yok)
- PII logging
- Error handling
- Latency
- Testability
