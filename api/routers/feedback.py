from fastapi import APIRouter, status, HTTPException, Depends, Request
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from databridge.supabase_databridge import SupabaseDatabridge
from dependencies import get_supabase_databridge
from structlog import get_logger

logger = get_logger()

router = APIRouter(prefix="/feedback", tags=["feedback"])


class FeedbackCreate(BaseModel):
    visit_rating: Optional[int] = None
    tropics_dome_rating: Optional[int] = None
    desert_dome_rating: Optional[int] = None
    show_dome_rating: Optional[int] = None
    staff_rating: Optional[int] = None
    cleanliness_rating: Optional[int] = None
    additional_comments: Optional[str] = None


class FeedbackResponse(BaseModel):
    id: int
    visit_rating: Optional[int] = None
    tropics_dome_rating: Optional[int] = None
    desert_dome_rating: Optional[int] = None
    show_dome_rating: Optional[int] = None
    staff_rating: Optional[int] = None
    cleanliness_rating: Optional[int] = None
    additional_comments: Optional[str] = None
    created_at: datetime


class FeedbackComment(BaseModel):
    id: int
    additional_comments: Optional[str] = None
    created_at: datetime


class FeedbackAnalytics(BaseModel):
    average_visit_rating: Optional[float] = None
    average_tropics_rating: Optional[float] = None
    average_desert_rating: Optional[float] = None
    average_show_rating: Optional[float] = None
    average_staff_rating: Optional[float] = None
    average_cleanliness_rating: Optional[float] = None
    total_feedback_count: int
    comments: List[FeedbackComment]


@router.post("/", response_model=FeedbackResponse, status_code=status.HTTP_201_CREATED)
async def create_feedback(
    feedback_data: FeedbackCreate,
    request: Request,
    databridge: SupabaseDatabridge = Depends(get_supabase_databridge)
):
    """
    Submit visitor feedback
    
    **Required fields:**
    - **visit_rating**: Rating for overall visit (1-5)
    
    **Optional fields:**
    - **tropics_dome_rating**: Rating for Tropics Dome (1-5)
    - **desert_dome_rating**: Rating for Desert Dome (1-5)
    - **show_dome_rating**: Rating for Show Dome (1-5)
    - **staff_rating**: Rating for staff friendliness (1-5)
    - **cleanliness_rating**: Rating for cleanliness (1-5)
    - **additional_comments**: Free-form text comments
    """
    # Validate visit_rating is required
    if feedback_data.visit_rating is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="visit_rating is required"
        )
    
    # Validate ratings are between 1-5 if provided
    ratings = [
        feedback_data.visit_rating,
        feedback_data.tropics_dome_rating,
        feedback_data.desert_dome_rating,
        feedback_data.show_dome_rating,
        feedback_data.staff_rating,
        feedback_data.cleanliness_rating,
    ]
    
    for rating in ratings:
        if rating is not None and (rating < 1 or rating > 5):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ratings must be between 1 and 5"
            )
    
    # Try to get user_id from auth token if available (optional - allows anonymous feedback)
    user_id = None
    try:
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            from dependencies import get_current_user
            try:
                db_user = await get_current_user(request)
                if db_user is not None and not db_user.empty:
                    user_id = int(db_user.iloc[0]['id'])
            except HTTPException:
                # If auth fails (401, 404, etc.), allow anonymous feedback
                pass
    except Exception as e:
        # If any other error occurs, allow anonymous feedback
        logger.debug(f"Anonymous feedback submission (error getting user): {str(e)}")
        pass
    
    try:
        # Insert feedback into database
        # Note: Only include columns that have values to avoid constraint violations
        query = """
            INSERT INTO staff.feedback (
                user_id,
                rating,
                tropics_rating,
                desert_rating,
                show_rating,
                staff_friendliness,
                cleanliness,
                additional_comments
            ) VALUES (
                :p_user_id,
                :p_rating,
                :p_tropics_rating,
                :p_desert_rating,
                :p_show_rating,
                :p_staff_friendliness,
                :p_cleanliness,
                :p_additional_comments
            )
            RETURNING 
                id,
                user_id,
                rating,
                tropics_rating,
                desert_rating,
                show_rating,
                staff_friendliness,
                cleanliness,
                additional_comments,
                created_at
        """
        params = {
            "p_user_id": user_id,
            "p_rating": feedback_data.visit_rating,
            "p_tropics_rating": feedback_data.tropics_dome_rating,
            "p_desert_rating": feedback_data.desert_dome_rating,
            "p_show_rating": feedback_data.show_dome_rating,
            "p_staff_friendliness": feedback_data.staff_rating,
            "p_cleanliness": feedback_data.cleanliness_rating,
            "p_additional_comments": feedback_data.additional_comments if feedback_data.additional_comments else None,
        }
        
        logger.info(f"Inserting feedback with params: {params}")
        result_df = await databridge.execute_query(query, params)
        
        if result_df.empty:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to save feedback"
            )
        
        # Map database columns back to API response format
        row = result_df.iloc[0].to_dict()
        feedback_response = FeedbackResponse(
            id=int(row['id']),
            visit_rating=row['rating'],
            tropics_dome_rating=row['tropics_rating'],
            desert_dome_rating=row['desert_rating'],
            show_dome_rating=row['show_rating'],
            staff_rating=row['staff_friendliness'],
            cleanliness_rating=row['cleanliness'],
            additional_comments=row['additional_comments'],
            created_at=row['created_at'],
        )
        
        logger.info(f"Feedback submitted successfully: ID {feedback_response.id}")
        return feedback_response
        
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        logger.error(f"Error saving feedback: {str(e)}")
        logger.error(f"Traceback: {error_trace}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save feedback: {str(e)}"
        )


@router.get("/analytics", response_model=FeedbackAnalytics)
async def get_feedback_analytics(
    databridge: SupabaseDatabridge = Depends(get_supabase_databridge)
):
    """
    Get feedback analytics including average ratings and comments
    
    Returns:
    - Average ratings for each category
    - Total feedback count
    - List of all comments (excluding null/empty comments)
    """
    try:
        # Get average ratings and total count
        analytics_query = """
            SELECT 
                AVG(rating) as avg_rating,
                AVG(tropics_rating) as avg_tropics_rating,
                AVG(desert_rating) as avg_desert_rating,
                AVG(show_rating) as avg_show_rating,
                AVG(staff_friendliness) as avg_staff_friendliness,
                AVG(cleanliness) as avg_cleanliness,
                COUNT(*) as total_count
            FROM staff.feedback
        """
        
        analytics_df = await databridge.execute_query(analytics_query, {})
        
        if analytics_df.empty:
            return FeedbackAnalytics(
                total_feedback_count=0,
                comments=[]
            )
        
        analytics_row = analytics_df.iloc[0].to_dict()
        
        # Get all comments (non-null and non-empty)
        comments_query = """
            SELECT 
                id,
                additional_comments,
                created_at
            FROM staff.feedback
            WHERE additional_comments IS NOT NULL 
                AND TRIM(additional_comments) != ''
            ORDER BY created_at DESC
        """
        
        comments_df = await databridge.execute_query(comments_query, {})
        
        comments = []
        if not comments_df.empty:
            for _, row in comments_df.iterrows():
                comments.append(FeedbackComment(
                    id=int(row['id']),
                    additional_comments=row['additional_comments'],
                    created_at=row['created_at']
                ))
        
        return FeedbackAnalytics(
            average_visit_rating=float(analytics_row['avg_rating']) if analytics_row['avg_rating'] is not None else None,
            average_tropics_rating=float(analytics_row['avg_tropics_rating']) if analytics_row['avg_tropics_rating'] is not None else None,
            average_desert_rating=float(analytics_row['avg_desert_rating']) if analytics_row['avg_desert_rating'] is not None else None,
            average_show_rating=float(analytics_row['avg_show_rating']) if analytics_row['avg_show_rating'] is not None else None,
            average_staff_rating=float(analytics_row['avg_staff_friendliness']) if analytics_row['avg_staff_friendliness'] is not None else None,
            average_cleanliness_rating=float(analytics_row['avg_cleanliness']) if analytics_row['avg_cleanliness'] is not None else None,
            total_feedback_count=int(analytics_row['total_count']),
            comments=comments
        )
        
    except Exception as e:
        logger.error(f"Error fetching feedback analytics: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch feedback analytics: {str(e)}"
        )

