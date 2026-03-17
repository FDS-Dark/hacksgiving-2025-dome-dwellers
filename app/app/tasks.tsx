import React, { useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ScrollView,
  SafeAreaView,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { IslandHeader } from '@/components/IslandHeader';
import { CircleFooter } from '@/components/CircleFooter';
import { Palette } from '@/constants/theme';
import { useAllTasks, useCreateTask, useToggleTask, useDeleteTask } from '@/hooks/use-tasks';
import { useUser } from '@/hooks/use-user';

export default function TasksScreen() {
  const [newTaskText, setNewTaskText] = useState('');
  const [selectedUserFilter, setSelectedUserFilter] = useState<number | null>(null);

  const { user: currentUser } = useUser();
  const { data: allTasks = [], isLoading, error } = useAllTasks();
  const createTaskMutation = useCreateTask();
  const toggleTaskMutation = useToggleTask();
  const deleteTaskMutation = useDeleteTask();

  const addTask = async () => {
    if (newTaskText.trim()) {
      try {
        await createTaskMutation.mutateAsync(newTaskText.trim());
        setNewTaskText('');
      } catch (err) {
        console.error('Failed to create task:', err);
      }
    }
  };

  const toggleTask = async (taskId: number) => {
    try {
      await toggleTaskMutation.mutateAsync(taskId);
    } catch (err) {
      console.error('Failed to toggle task:', err);
    }
  };

  const deleteTask = async (taskId: number) => {
    try {
      await deleteTaskMutation.mutateAsync(taskId);
    } catch (err) {
      console.error('Failed to delete task:', err);
    }
  };

  const uniqueUsers = useMemo(() => {
    const userMap = new Map<number, { id: number; name: string }>();
    allTasks.forEach(task => {
      if (!userMap.has(task.user_id)) {
        userMap.set(task.user_id, {
          id: task.user_id,
          name: task.user_name || task.user_email || 'Unknown User',
        });
      }
    });
    return Array.from(userMap.values());
  }, [allTasks]);

  const filteredTasks = selectedUserFilter
    ? allTasks.filter((task) => task.user_id === selectedUserFilter)
    : allTasks;

  const currentUserId = currentUser?.id;
  const userTasks = filteredTasks.filter((task) => task.user_id === currentUserId);
  const otherUserTasks = filteredTasks.filter((task) => task.user_id !== currentUserId);

  const groupedOtherTasks = otherUserTasks.reduce((acc, task) => {
    if (!acc[task.user_id]) {
      acc[task.user_id] = [];
    }
    acc[task.user_id].push(task);
    return acc;
  }, {} as Record<number, typeof allTasks>);

  if (isLoading) {
    return (
      <View style={styles.container}>
        <IslandHeader />
        <SafeAreaView style={styles.safeArea}>
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="large" color={Palette.green900} />
            <Text style={styles.loadingText}>Loading tasks...</Text>
          </View>
        </SafeAreaView>
        <CircleFooter />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.container}>
        <IslandHeader />
        <SafeAreaView style={styles.safeArea}>
          <View style={styles.errorContainer}>
            <Ionicons name="alert-circle-outline" size={64} color="#ef4444" />
            <Text style={styles.errorText}>Failed to load tasks</Text>
            <Text style={styles.errorSubtext}>{error.message}</Text>
          </View>
        </SafeAreaView>
        <CircleFooter />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <IslandHeader />
      <SafeAreaView style={styles.safeArea}>
        <ScrollView style={styles.scrollView} contentContainerStyle={styles.scrollContent}>
          {/* Add Task Section */}
          <View style={styles.addTaskSection}>
            <Text style={styles.sectionTitle}>Add New Task</Text>
            <View style={styles.inputContainer}>
              <TextInput
                style={styles.input}
                placeholder="Enter a new task..."
                placeholderTextColor={Palette.gray900}
                value={newTaskText}
                onChangeText={setNewTaskText}
                onSubmitEditing={addTask}
              />
              <TouchableOpacity 
                style={styles.addButton} 
                onPress={addTask}
                disabled={createTaskMutation.isPending}
              >
                {createTaskMutation.isPending ? (
                  <ActivityIndicator size="small" color={Palette.white} />
                ) : (
                  <Ionicons name="add" size={24} color={Palette.white} />
                )}
              </TouchableOpacity>
            </View>
          </View>

          {/* User Filter Section */}
          <View style={styles.filterSection}>
            <Text style={styles.sectionTitle}>Filter by User</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.filterScroll}>
              <TouchableOpacity
                style={[
                  styles.filterChip,
                  selectedUserFilter === null && styles.filterChipActive,
                ]}
                onPress={() => setSelectedUserFilter(null)}
              >
                <Text
                  style={[
                    styles.filterChipText,
                    selectedUserFilter === null && styles.filterChipTextActive,
                  ]}
                >
                  All Users
                </Text>
              </TouchableOpacity>
              {uniqueUsers.map((user) => (
                <TouchableOpacity
                  key={user.id}
                  style={[
                    styles.filterChip,
                    selectedUserFilter === user.id && styles.filterChipActive,
                  ]}
                  onPress={() => setSelectedUserFilter(user.id)}
                >
                  <Text
                    style={[
                      styles.filterChipText,
                      selectedUserFilter === user.id && styles.filterChipTextActive,
                    ]}
                  >
                    {user.name}
                  </Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
          </View>

          {/* My Tasks Section */}
          {userTasks.length > 0 && (
            <View style={styles.tasksSection}>
              <Text style={styles.sectionTitle}>My Tasks</Text>
              {userTasks.map((task) => (
                <View key={task.id} style={styles.taskItem}>
                  <TouchableOpacity
                    style={styles.checkboxContainer}
                    onPress={() => toggleTask(task.id)}
                  >
                    <View
                      style={[
                        styles.checkbox,
                        task.completed && styles.checkboxChecked,
                      ]}
                    >
                      {task.completed && (
                        <Ionicons name="checkmark" size={16} color={Palette.white} />
                      )}
                    </View>
                    <Text
                      style={[
                        styles.taskText,
                        task.completed && styles.taskTextCompleted,
                      ]}
                    >
                      {task.text}
                    </Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={styles.deleteButton}
                    onPress={() => deleteTask(task.id)}
                  >
                    <Ionicons name="trash-outline" size={20} color="#ef4444" />
                  </TouchableOpacity>
                </View>
              ))}
            </View>
          )}

          {/* Other Users' Tasks Section */}
          {Object.keys(groupedOtherTasks).length > 0 && (
            <View style={styles.tasksSection}>
              <Text style={styles.sectionTitle}>Other Users' Tasks</Text>
              {Object.entries(groupedOtherTasks).map(([userId, userTaskList]) => {
                const user = uniqueUsers.find((u) => u.id === parseInt(userId));
                return (
                  <View key={userId} style={styles.otherUserSection}>
                    <Text style={styles.otherUserName}>{user?.name || 'Unknown'}'s Tasks</Text>
                    {userTaskList.map((task) => (
                      <View key={task.id} style={styles.taskItem}>
                        <View style={styles.checkboxContainer}>
                          <View
                            style={[
                              styles.checkbox,
                              styles.checkboxReadOnly,
                              task.completed && styles.checkboxChecked,
                            ]}
                          >
                            {task.completed && (
                              <Ionicons name="checkmark" size={16} color={Palette.white} />
                            )}
                          </View>
                          <Text
                            style={[
                              styles.taskText,
                              task.completed && styles.taskTextCompleted,
                            ]}
                          >
                            {task.text}
                          </Text>
                        </View>
                      </View>
                    ))}
                  </View>
                );
              })}
            </View>
          )}

          {/* Empty State */}
          {filteredTasks.length === 0 && (
            <View style={styles.emptyState}>
              <Ionicons name="checkmark-circle-outline" size={64} color={Palette.gray900} />
              <Text style={styles.emptyStateText}>No tasks found</Text>
            </View>
          )}
        </ScrollView>
      </SafeAreaView>
      <CircleFooter />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Palette.white,
  },
  safeArea: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 100,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: Palette.green900,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  errorText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#ef4444',
    marginTop: 16,
  },
  errorSubtext: {
    fontSize: 14,
    color: Palette.gray900,
    marginTop: 8,
    textAlign: 'center',
  },
  addTaskSection: {
    marginBottom: 24,
  },
  filterSection: {
    marginBottom: 24,
  },
  filterScroll: {
    marginTop: 8,
  },
  filterChip: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: Palette.gray100,
    marginRight: 8,
    borderWidth: 1,
    borderColor: Palette.gray900,
  },
  filterChipActive: {
    backgroundColor: Palette.green900,
    borderColor: Palette.green900,
  },
  filterChipText: {
    color: Palette.green900,
    fontSize: 14,
    fontWeight: '500',
  },
  filterChipTextActive: {
    color: Palette.white,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: Palette.green900,
    marginBottom: 12,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  input: {
    flex: 1,
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    color: Palette.green900,
    borderWidth: 1,
    borderColor: Palette.gray900,
  },
  addButton: {
    backgroundColor: Palette.green900,
    borderRadius: 12,
    width: 48,
    height: 48,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  tasksSection: {
    marginBottom: 24,
  },
  otherUserSection: {
    marginBottom: 16,
    paddingLeft: 8,
  },
  otherUserName: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 8,
    opacity: 0.8,
  },
  taskItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    padding: 12,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: Palette.gray900,
  },
  checkboxContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
  },
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: 6,
    borderWidth: 2,
    borderColor: Palette.green900,
    marginRight: 12,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: Palette.white,
  },
  checkboxChecked: {
    backgroundColor: Palette.green900,
    borderColor: Palette.green900,
  },
  checkboxReadOnly: {
    opacity: 0.6,
  },
  taskText: {
    flex: 1,
    fontSize: 16,
    color: Palette.green900,
  },
  taskTextCompleted: {
    textDecorationLine: 'line-through',
    opacity: 0.6,
  },
  deleteButton: {
    padding: 4,
    marginLeft: 8,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 48,
  },
  emptyStateText: {
    fontSize: 18,
    color: Palette.gray900,
    marginTop: 16,
  },
});

