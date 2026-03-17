import { API_BASE_URL } from '@/constants/config';
import { UserProfile } from '@/types/user';

export const userService = {
  async getCurrentUser(token: string): Promise<UserProfile> {
    const url = `${API_BASE_URL}/user/me`;
    
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to fetch user profile: ${response.statusText}`);
    }
    
    return response.json();
  },
};

