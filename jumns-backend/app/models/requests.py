"""Pydantic request models — validated on incoming API requests."""

from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1)


class CreateGoalRequest(BaseModel):
    title: str = Field(..., min_length=1)
    category: str = "personal"
    total: int = 100
    unit: str = ""


class UpdateGoalRequest(BaseModel):
    title: str | None = None
    category: str | None = None
    progress: int | None = None
    total: int | None = None
    unit: str | None = None
    insight: str | None = None
    active_agent: str | None = Field(None, alias="activeAgent")
    completed: bool | None = None


class CreateTaskRequest(BaseModel):
    title: str = Field(..., min_length=1)
    time: str = ""
    detail: str = ""
    type: str = "task"
    goal_id: str | None = Field(None, alias="goalId")
    priority: str = "medium"
    requires_proof: bool = Field(False, alias="requiresProof")
    due_date: str | None = Field(None, alias="dueDate")


class UpdateTaskRequest(BaseModel):
    title: str | None = None
    time: str | None = None
    detail: str | None = None
    type: str | None = None
    completed: bool | None = None
    active: bool | None = None
    goal_id: str | None = Field(None, alias="goalId")
    priority: str | None = None
    due_date: str | None = Field(None, alias="dueDate")


class CompleteTaskRequest(BaseModel):
    proof_url: str | None = Field(None, alias="proofUrl")
    proof_type: str | None = Field(None, alias="proofType")


class CreateReminderRequest(BaseModel):
    title: str = Field(..., min_length=1)
    time: str = ""
    goal_id: str | None = Field(None, alias="goalId")


class UpdateReminderRequest(BaseModel):
    title: str | None = None
    time: str | None = None
    active: bool | None = None
    goal_id: str | None = Field(None, alias="goalId")


class SnoozeReminderRequest(BaseModel):
    minutes: int = Field(30, ge=5, le=1440)  # 5 min to 24 hours


class CreateSkillRequest(BaseModel):
    name: str = Field(..., min_length=1)
    type: str = "mcp"
    description: str = ""
    status: str = "inactive"
    category: str = "mcp"


class UpdateSkillRequest(BaseModel):
    name: str | None = None
    type: str | None = None
    description: str | None = None
    status: str | None = None
    category: str | None = None


class UserSettingsRequest(BaseModel):
    agent_name: str | None = Field(None, alias="agentName")
    agent_behavior: str | None = Field(None, alias="agentBehavior")
    onboarding_completed: bool | None = Field(None, alias="onboardingCompleted")
    timezone: str | None = None
    morning_time: str | None = Field(None, alias="morningTime")
    evening_time: str | None = Field(None, alias="eveningTime")
    model: str | None = None


class ActivateCodeRequest(BaseModel):
    code: str = Field(..., min_length=1)


class CreateJournalEntryRequest(BaseModel):
    content: str = Field(..., min_length=1)
    type: str = "thought"  # thought, reflection, polaroid, audio, sticky
    title: str = ""
    mood: str | None = None
    tags: list[str] = []
    shareable: bool = False
    linked_goal_id: str | None = Field(None, alias="linkedGoalId")


class UpdateJournalEntryRequest(BaseModel):
    content: str | None = None
    title: str | None = None
    mood: str | None = None
    tags: list[str] | None = None
    shareable: bool | None = None
    draft: bool | None = None


class CreateFriendMessageRequest(BaseModel):
    connection_id: str = Field(..., alias="connectionId")
    friend_user_id: str = Field(..., alias="friendUserId")
    content: str = Field(..., min_length=1)
    type: str = "text"
