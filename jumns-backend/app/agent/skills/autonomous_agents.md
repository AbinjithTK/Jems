# Autonomous Agent Skill Reference

Source: Way Back Home Codelabs (Levels 1, 3, 4)

## Core Patterns

### before_agent_callback for State Injection
```python
async def inject_state(ctx) -> Content | None:
    state = ctx.session.state
    state["current_time"] = datetime.now().isoformat()
    # Inject user preferences, memory bank, etc.
    return None  # Continue normal execution
```

### Proactive Tool Use
Agents should use tools IMMEDIATELY when relevant:
- User mentions a date → create task + reminder
- User shares personal info → store as memory
- User mentions a goal → create goal + analyze timeline
- User asks "how am I doing?" → run full analysis pipeline

### Streaming Tools (AsyncGenerator)
Background monitoring tools that yield results over time:
```python
async def monitor_reminders(user_id: str) -> AsyncGenerator:
    while True:
        due = check_due_reminders(user_id)
        if due:
            yield {"reminders": due}
        await asyncio.sleep(300)  # Check every 5 min
```

### Agent-as-a-Tool Pattern
Sub-agents can be invoked as tools by the root agent:
- Noor delegates to Kai/Sage/Echo via transfer_to_agent
- Each sub-agent has its own tools and persona
- Results flow back through the root agent

### Multi-Agent Delegation
- Root agent (Noor) orchestrates
- Sub-agents handle domain-specific tasks
- before_agent_callback injects shared state
- Session state is shared across all agents in hierarchy

## Autonomy Rules
1. Act on implicit requests — don't just acknowledge
2. Use tools immediately — never describe what you could do
3. Chain tool calls — create task → create reminder → confirm
4. Proactively surface relevant information from memory
5. When detecting patterns, store them for future reference
