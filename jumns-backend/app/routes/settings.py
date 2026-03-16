"""Routes for /api/user-settings — get and upsert."""

from fastapi import APIRouter, Request

from app.db.repositories.users import UsersRepository
from app.models.requests import UserSettingsRequest
from app.models.responses import UserSettingsResponse

router = APIRouter(prefix="/user-settings", tags=["settings"])


def _to_response(data: dict) -> UserSettingsResponse:
    return UserSettingsResponse(
        agent_name=data.get("agentName", "Jumns"),
        agent_behavior=data.get("agentBehavior", "Friendly & Supportive"),
        onboarding_completed=data.get("onboardingCompleted", False),
        timezone=data.get("timezone", "UTC"),
        morning_time=data.get("morningTime", "07:00"),
        evening_time=data.get("eveningTime", "21:00"),
        model=data.get("model", "gemini-2.5-flash"),
    )


@router.get("/")
async def get_settings(request: Request) -> UserSettingsResponse:
    repo = UsersRepository()
    data = repo.get_settings(request.state.user_id)
    return _to_response(data)


@router.post("/")
async def upsert_settings(
    request: Request, body: UserSettingsRequest,
) -> UserSettingsResponse:
    repo = UsersRepository()
    data = repo.upsert_settings(
        request.state.user_id, body.model_dump(exclude_none=True),
    )
    return _to_response(data)
