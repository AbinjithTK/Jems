"""Agent tools — plain functions wrapped by ADK FunctionTool.

Organized by domain and assigned to specific agents:
  - Kai (scheduler): task_tools, reminder_tools, calendar_tools, planning_tools + context_tools
  - Sage (goals): goal_tools, analysis_tools, lounge_tools + context_tools
  - Echo (memory): memory_tools, journal_tools + context_tools
  - Noor (main): utility_tools, web_tools, hub_tools + context_tools + delegates to sub-agents
"""

from app.agent.tools.goal_tools import (
    create_goal,
    delete_goal,
    get_goals,
    update_goal,
)
from app.agent.tools.task_tools import (
    complete_task,
    create_task,
    delete_task,
    get_tasks,
    update_task,
)
from app.agent.tools.reminder_tools import (
    create_reminder,
    delete_reminder,
    get_reminders,
    snooze_reminder,
    update_reminder,
)
from app.agent.tools.planning_tools import (
    adapt_plan,
    decompose_goal_into_plan,
    reschedule_failed_tasks,
)
from app.agent.tools.calendar_tools import (
    analyze_goal_timeline,
    assign_task_to_date,
    get_schedule,
)
from app.agent.tools.analysis_tools import (
    analyze_progress,
    get_daily_summary,
    smart_suggest,
)
from app.agent.tools.memory_tools import (
    recall_memories,
    remember_fact,
    search_memory,
)
from app.agent.tools.journal_tools import (
    create_journal_entry,
    generate_journal_prompt,
    get_journal_entries,
    get_mood_patterns,
)
from app.agent.tools.lounge_tools import (
    generate_social_briefing,
    get_agent_activity,
    get_social_feed,
    publish_agent_event,
)
from app.agent.tools.hub_tools import (
    get_cross_agent_summary,
    get_notification_digest,
    search_conversations,
)
from app.agent.tools.context_tools import (
    publish_context,
    read_agent_context,
)
from app.agent.tools.web_tools import web_search
from app.agent.tools.utility_tools import (
    get_current_datetime,
    query_user_data,
    search_data,
)

# Shared context tools — every agent gets these
CONTEXT_TOOLS = [read_agent_context, publish_context]

# Tools grouped by agent assignment
KAI_TOOLS = [
    get_tasks, create_task, update_task, complete_task, delete_task,
    get_reminders, create_reminder, update_reminder, snooze_reminder, delete_reminder,
    get_schedule, assign_task_to_date,
    decompose_goal_into_plan, adapt_plan, reschedule_failed_tasks,
    get_current_datetime,
    remember_fact, recall_memories,  # Kai can store/recall scheduling preferences
    *CONTEXT_TOOLS,
]

SAGE_TOOLS = [
    get_goals, create_goal, update_goal, delete_goal,
    analyze_goal_timeline,
    analyze_progress, get_daily_summary, smart_suggest,
    get_social_feed, generate_social_briefing, get_agent_activity, publish_agent_event,
    get_current_datetime,
    remember_fact, recall_memories,  # Sage can store/recall goal context
    *CONTEXT_TOOLS,
]

ECHO_TOOLS = [
    search_memory, remember_fact, recall_memories,
    get_journal_entries, create_journal_entry, generate_journal_prompt, get_mood_patterns,
    get_current_datetime,
    *CONTEXT_TOOLS,
]

NOOR_TOOLS = [
    query_user_data, search_data, get_current_datetime,
    web_search,
    search_conversations, get_cross_agent_summary, get_notification_digest,
    remember_fact, recall_memories,  # Noor can store/recall from conversations
    *CONTEXT_TOOLS,
]
