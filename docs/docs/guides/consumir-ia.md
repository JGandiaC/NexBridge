# Consumir la IA local

Una vez desplegado, la IA local del OnPrem es un endpoint compatible con OpenAI dentro del clúster:

```text
http://nexbridge.nexbridge.svc.cluster.local:3000/v1
```

Desde el mismo namespace basta `http://nexbridge:3000/v1`.

## curl

```bash
curl http://nexbridge.nexbridge.svc.cluster.local:3000/v1/models

curl http://nexbridge.nexbridge.svc.cluster.local:3000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"<modelo-local>","messages":[{"role":"user","content":"Hola"}]}'
```

## Python (SDK OpenAI)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://nexbridge.nexbridge.svc.cluster.local:3000/v1",
    api_key="not-needed",  # o la key que exija la IA local
)
resp = client.chat.completions.create(
    model="<modelo-local>",
    messages=[{"role": "user", "content": "Resume este documento…"}],
)
print(resp.choices[0].message.content)
```

## NexIA

NexIA trata cualquier servidor compatible con OpenAI como proveedor **local**. Apunta su configuración al
Service del túnel (variables del provider local en el ConfigMap/Secret de NexIA):

```env
LOCAL_API_URL=http://nexbridge.nexbridge.svc.cluster.local:3000/v1
LOCAL_API_KEY=not-needed
```

Así, guardrails, presupuestos, trazas y model routing de NexIA se aplican igual a las peticiones que
acaban en la IA del OnPrem. Si aplicas la NetworkPolicy, etiqueta el namespace de NexIA:
`kubectl label ns nexia nexbridge/consumer=true`.

## Streaming

El túnel es TCP transparente: SSE (`"stream": true`) funciona sin cambios. Timeouts largos de
generación no afectan al túnel; `ServerAliveInterval` mantiene la sesión aunque no haya tráfico.
