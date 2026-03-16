# Memory Bank Skill Reference

Source: Way Back Home Codelabs + ADK Session State patterns

## Memory Bank Architecture

### Storage Layers
1. Session State (ephemeral): ctx.session.state — per-conversation
2. Vector Memory (persistent): S3 + faiss-cpu — cross-session
3. DynamoDB (structured): goals, tasks, reminders — domain data

### Memory Categories
- preference: user likes/dislikes, communication style
- personal_info: name, location, occupation, family
- goal_context: why they set a goal, motivation
- habit: recurring behaviors, routines
- important_date: birthdays, deadlines, anniversaries
- relationship: people mentioned, connections
- health: wellness patterns, conditions
- work: job context, projects, colleagues
- skill: things they're learning or good at
- emotional: mood patterns, stress triggers
- pattern: recurring themes across conversations
- reflection: journal insights, self-awareness moments

### Importance Levels
- critical (1.0): names, health conditions, key dates
- high (0.8): preferences, relationships, goals
- medium (0.5): habits, interests, work context
- low (0.2): casual mentions, one-off topics

## Session State Injection
Before each agent turn, inject into session.state:
- user_id, current_time, current_day
- conversation_history (last 20 messages)
- relevant_memories (top 5 by similarity)
- memory_bank_size, recent_memories
- settings, mirror_profile

## Memory Consolidation
Daily job (Echo agent):
1. Review recent memories
2. Identify recurring themes
3. Merge related memories into patterns
4. Store consolidated insights
5. Flag critical memories for quick access

## Retrieval Strategy
- Cosine similarity search via faiss-cpu
- Importance-weighted scoring (0.7 * similarity + 0.3 * importance)
- Category filtering for domain-specific queries
- Top-k retrieval with k=5 default
