# Bidi-Streaming Skill Reference

Source: Google ADK Bidi-Streaming Dev Guide + bidi-demo sample

## Architecture
- LiveRequestQueue: upstream channel (client → model)
- Runner.run_live(): downstream async generator (model → client)
- asyncio.gather(upstream, downstream) for concurrent processing

## Key Patterns

### Session Setup
```python
from google.adk.agents.live_request_queue import LiveRequestQueue
from google.adk.agents.run_config import RunConfig, StreamingMode
from google.adk.runner import Runner

live_queue = LiveRequestQueue()
run_config = RunConfig(streaming_mode=StreamingMode.BIDI)

async for event in runner.run_live(
    user_id=user_id,
    session_id=session_id,
    live_request_queue=live_queue,
    run_config=run_config,
):
    process(event)
```

### Upstream (Client → Model)
- Text: `live_queue.send(Content(role="user", parts=[Part(text=...)]))`
- Audio: `live_queue.send(Content(role="user", parts=[Part(inline_data=Blob(...))]))`
- Close: `live_queue.close()`

### Downstream Events
- Text: event.content.parts[0].text
- Audio: event.content.parts[0].inline_data
- Turn complete: event.turn_complete == True
- Interrupted: event.interrupted == True
- Tool calls: event.function_calls
- Errors: event.error_code, event.error_message

### Session Resumption
```python
run_config = RunConfig(
    streaming_mode=StreamingMode.BIDI,
    session_resumption=SessionResumptionConfig(handle="previous_handle"),
)
```

## WebSocket Integration
- FastAPI WebSocket endpoint receives client messages
- upstream() task reads WebSocket, pushes to LiveRequestQueue
- downstream() task reads run_live() events, sends to WebSocket
- asyncio.gather(upstream(), downstream()) runs both concurrently
