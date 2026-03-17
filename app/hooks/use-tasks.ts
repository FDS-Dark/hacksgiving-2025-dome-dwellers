import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useAuth0 } from '@/components/Auth0Provider';
import { tasksService } from '@/services/tasks';

export const tasksKeys = {
  all: ['tasks'] as const,
  allTasks: () => [...tasksKeys.all, 'all'] as const,
  myTasks: () => [...tasksKeys.all, 'my'] as const,
};

export function useAllTasks() {
  const { accessToken } = useAuth0();
  
  return useQuery({
    queryKey: tasksKeys.allTasks(),
    queryFn: () => {
      if (!accessToken) {
        throw new Error('No access token available');
      }
      return tasksService.getAllTasks(accessToken);
    },
    enabled: !!accessToken,
  });
}

export function useMyTasks() {
  const { accessToken } = useAuth0();
  
  return useQuery({
    queryKey: tasksKeys.myTasks(),
    queryFn: () => {
      if (!accessToken) {
        throw new Error('No access token available');
      }
      return tasksService.getMyTasks(accessToken);
    },
    enabled: !!accessToken,
  });
}

export function useCreateTask() {
  const queryClient = useQueryClient();
  const { accessToken } = useAuth0();
  
  return useMutation({
    mutationFn: (text: string) => {
      if (!accessToken) {
        throw new Error('No access token available');
      }
      return tasksService.createTask(accessToken, text);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: tasksKeys.allTasks() });
      queryClient.invalidateQueries({ queryKey: tasksKeys.myTasks() });
    },
  });
}

export function useToggleTask() {
  const queryClient = useQueryClient();
  const { accessToken } = useAuth0();
  
  return useMutation({
    mutationFn: (taskId: number) => {
      if (!accessToken) {
        throw new Error('No access token available');
      }
      return tasksService.toggleTask(accessToken, taskId);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: tasksKeys.allTasks() });
      queryClient.invalidateQueries({ queryKey: tasksKeys.myTasks() });
    },
  });
}

export function useDeleteTask() {
  const queryClient = useQueryClient();
  const { accessToken } = useAuth0();
  
  return useMutation({
    mutationFn: (taskId: number) => {
      if (!accessToken) {
        throw new Error('No access token available');
      }
      return tasksService.deleteTask(accessToken, taskId);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: tasksKeys.allTasks() });
      queryClient.invalidateQueries({ queryKey: tasksKeys.myTasks() });
    },
  });
}

