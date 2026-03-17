export interface UserProfile {
  id: number;
  auth0_user_id: string;
  email?: string;
  display_name?: string;
  name?: string;
  given_name?: string;
  family_name?: string;
  picture_url?: string;
  locale?: string;
  roles: string[];
  created_at: string;
  updated_at: string;
}

export type UserRole = 'visitor' | 'staff' | 'admin';

