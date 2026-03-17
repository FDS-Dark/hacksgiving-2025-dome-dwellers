import { API_BASE_URL } from '@/constants/config';

export interface Task {
  id: number;
  user_id: number;
  text: string;
  completed: boolean;
  created_at: string;
  updated_at: string;
  completed_at?: string | null;
}

export interface TaskWithUser extends Task {
  user_name?: string | null;
  user_email?: string | null;
}

export interface CreateTaskRequest {
  text: string;
}

export const tasksService = {
  async getAllTasks(token: string): Promise<TaskWithUser[]> {
    const response = await fetch(`${API_BASE_URL}/tasks/all`, {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to fetch tasks: ${response.status} - ${errorText}`);
    }

    return response.json();
  },

  async getMyTasks(token: string): Promise<Task[]> {
    const response = await fetch(`${API_BASE_URL}/tasks/my`, {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to fetch my tasks: ${response.status} - ${errorText}`);
    }

    return response.json();
  },

  async createTask(token: string, text: string): Promise<Task> {
    const response = await fetch(`${API_BASE_URL}/tasks/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({ text }),
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to create task: ${response.status} - ${errorText}`);
    }

    return response.json();
  },

  async toggleTask(token: string, taskId: number): Promise<Task> {
    const response = await fetch(`${API_BASE_URL}/tasks/${taskId}/toggle`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to toggle task: ${response.status} - ${errorText}`);
    }

    return response.json();
  },

  async deleteTask(token: string, taskId: number): Promise<void> {
    const response = await fetch(`${API_BASE_URL}/tasks/${taskId}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to delete task: ${response.status} - ${errorText}`);
    }
  },
};

