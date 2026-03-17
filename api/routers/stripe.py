from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from services.stripe import StripeService
from dependencies import get_stripe_service

router = APIRouter(prefix="/stripe", tags=["stripe"])


class TicketCheckoutRequest(BaseModel):
    ticket_type: str = Field(..., description="Type of ticket (general, vip, family)")
    quantity: int = Field(..., description="Number of tickets", gt=0)
    success_url: str = Field(..., description="Success redirect URL")
    cancel_url: str = Field(..., description="Cancel redirect URL")


class DonationCheckoutRequest(BaseModel):
    amount: int = Field(..., description="Donation amount in cents", gt=0)
    success_url: str = Field(..., description="Success redirect URL")
    cancel_url: str = Field(..., description="Cancel redirect URL")
    donor_name: Optional[str] = Field(None, description="Optional donor name")


class GiftShopItem(BaseModel):
    name: str = Field(..., description="Item name")
    description: Optional[str] = Field(None, description="Item description")
    price: int = Field(..., description="Price in cents", gt=0)
    quantity: int = Field(..., description="Quantity", gt=0)
    images: Optional[List[str]] = Field(None, description="Product image URLs")


class GiftShopCheckoutRequest(BaseModel):
    items: List[GiftShopItem] = Field(..., description="List of items to purchase")
    success_url: str = Field(..., description="Success redirect URL")
    cancel_url: str = Field(..., description="Cancel redirect URL")


@router.post("/checkout/tickets")
async def create_ticket_checkout(
    request: TicketCheckoutRequest,
    stripe_service: StripeService = Depends(get_stripe_service)
):
    """Create a checkout session for ticket purchases"""
    try:
        result = await stripe_service.create_ticket_checkout(
            ticket_type=request.ticket_type,
            quantity=request.quantity,
            success_url=request.success_url,
            cancel_url=request.cancel_url
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/checkout/donation")
async def create_donation_checkout(
    request: DonationCheckoutRequest,
    stripe_service: StripeService = Depends(get_stripe_service)
):
    """Create a checkout session for donations"""
    try:
        result = await stripe_service.create_donation_checkout(
            amount=request.amount,
            success_url=request.success_url,
            cancel_url=request.cancel_url,
            donor_name=request.donor_name
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/checkout/gift-shop")
async def create_gift_shop_checkout(
    request: GiftShopCheckoutRequest,
    stripe_service: StripeService = Depends(get_stripe_service)
):
    """Create a checkout session for gift shop purchases"""
    try:
        items = [item.model_dump() for item in request.items]
        result = await stripe_service.create_gift_shop_checkout(
            items=items,
            success_url=request.success_url,
            cancel_url=request.cancel_url
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/session/{session_id}")
async def get_checkout_session(
    session_id: str,
    stripe_service: StripeService = Depends(get_stripe_service)
):
    """Retrieve a checkout session by ID"""
    try:
        result = await stripe_service.retrieve_session(session_id)
        return result
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/ticket-types")
async def get_ticket_types():
    """Get available ticket types and prices"""
    return {
        "ticket_types": [
            {
                "id": "general",
                "name": "General Admission",
                "description": "Access to all three domes",
                "price": 900,
                "currency": "usd"
            },
            {
                "id": "season_pass",
                "name": "Season Pass",
                "description": "Unlimited visits for one year",
                "price": 5000,
                "currency": "usd"
            }
        ]
    }

