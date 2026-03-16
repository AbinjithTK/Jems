"""Firestore collection names — read from environment variables.

Replaces the previous DynamoDB table names.
Firestore uses subcollections under users/{userId}/ for most data,
but collection names are still configurable for flexibility.
"""

import os

# Top-level collection names
USERS_COLLECTION = os.getenv("USERS_COLLECTION", "users")
ACCESS_CODES_COLLECTION = os.getenv("ACCESS_CODES_COLLECTION", "access_codes")

# Subcollection names (nested under users/{userId}/)
MESSAGES_SUBCOLLECTION = os.getenv("MESSAGES_SUBCOLLECTION", "messages")
GOALS_SUBCOLLECTION = os.getenv("GOALS_SUBCOLLECTION", "goals")
TASKS_SUBCOLLECTION = os.getenv("TASKS_SUBCOLLECTION", "tasks")
REMINDERS_SUBCOLLECTION = os.getenv("REMINDERS_SUBCOLLECTION", "reminders")
SKILLS_SUBCOLLECTION = os.getenv("SKILLS_SUBCOLLECTION", "skills")
INSIGHTS_SUBCOLLECTION = os.getenv("INSIGHTS_SUBCOLLECTION", "insights")
CONNECTIONS_SUBCOLLECTION = os.getenv("CONNECTIONS_SUBCOLLECTION", "connections")
MCP_SERVERS_SUBCOLLECTION = os.getenv("MCP_SERVERS_SUBCOLLECTION", "mcp_servers")
JOURNAL_SUBCOLLECTION = os.getenv("JOURNAL_SUBCOLLECTION", "journal")
AGENT_CONTEXT_SUBCOLLECTION = os.getenv("AGENT_CONTEXT_SUBCOLLECTION", "agent_context")
FRIEND_MESSAGES_SUBCOLLECTION = os.getenv("FRIEND_MESSAGES_SUBCOLLECTION", "friend_messages")
