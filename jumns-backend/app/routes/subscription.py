"""Routes for /api/subscription/status — stubbed for MVP (no RevenueCat)."""

from fastapi import APIRouter, Request

from app.models.responses import SubscriptionStatusResponse

router = APIRouter(prefix="/subscription", tags=["subscription"])


@router.get("/status")
async def get_subscription_status(request: Request) -> SubscriptionStatusResponse:
    """Return free-tier stub. RevenueCat integration deferred post-MVP."""
    return SubscriptionStatusResponse()  # defaults: free, not pro
