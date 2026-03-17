import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ScrollView,
  SafeAreaView,
  Alert,
  Modal,
} from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { IslandHeader } from '@/components/IslandHeader';
import { CircleFooter } from '@/components/CircleFooter';

interface CalendarEvent {
  id: string;
  title: string;
  location: string;
  startTime: string;
  endTime: string;
  userId: string;
  userName: string;
  date: Date;
}

const MOCK_USERS = [
  { id: '1', name: 'You' },
  { id: '2', name: 'Alice' },
  { id: '3', name: 'Bob' },
  { id: '4', name: 'Charlie' },
];

const MOCK_EVENTS: CalendarEvent[] = [
  {
    id: '1',
    title: 'Morning Shift',
    location: 'Desert Dome',
    startTime: '09:00',
    endTime: '13:00',
    userId: '1',
    userName: 'You',
    date: new Date(2025, 11, 21), 
    },
  {
    id: '2',
    title: 'Plant Maintenance',
    location: 'Tropical Dome',
    startTime: '14:00',
    endTime: '17:00',
    userId: '2',
    userName: 'Alice',
    date: new Date(2025, 11, 22),
  },
  {
    id: '3',
    title: 'Guided Tour',
    location: 'Show Dome',
    startTime: '10:00',
    endTime: '11:30',
    userId: '3',
    userName: 'Bob',
    date: new Date(2024, 0, 16),
  },
];

const DAYS_OF_WEEK = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

export default function CalendarScreen() {
  const router = useRouter();
  const [currentDate, setCurrentDate] = useState(new Date());
  const [events, setEvents] = useState<CalendarEvent[]>(MOCK_EVENTS);
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [isAddModalVisible, setIsAddModalVisible] = useState(false);
  const [calendarView, setCalendarView] = useState<'shared' | 'personal'>('shared');
  const [newTitle, setNewTitle] = useState('');
  const [newLocation, setNewLocation] = useState('');
  const [newStartTime, setNewStartTime] = useState('');
  const [newEndTime, setNewEndTime] = useState('');
  const [newUserId, setNewUserId] = useState('1');
  
  const CURRENT_USER_ID = '1';

  const currentMonth = currentDate.getMonth();
  const currentYear = currentDate.getFullYear();

  const getDaysInMonth = (date: Date) => {
    return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
  };

  const getFirstDayOfMonth = (date: Date) => {
    return new Date(date.getFullYear(), date.getMonth(), 1).getDay();
  };

  const isToday = (day: number) => {
    const today = new Date();
    return (
      day === today.getDate() &&
      currentMonth === today.getMonth() &&
      currentYear === today.getFullYear()
    );
  };

  const isSelected = (day: number) => {
    if (!selectedDate) return false;
    return (
      day === selectedDate.getDate() &&
      currentMonth === selectedDate.getMonth() &&
      currentYear === selectedDate.getFullYear()
    );
  };


  const getFilteredEvents = () => {
    if (calendarView === 'personal') {
      return events.filter(event => event.userId === CURRENT_USER_ID);
    }
    return events;
  };

  const filteredEvents = getFilteredEvents();

  const hasEvents = (day: number) => {
    const date = new Date(currentYear, currentMonth, day);
    return filteredEvents.some(event => {
      const eventDate = new Date(event.date);
      return (
        eventDate.getDate() === date.getDate() &&
        eventDate.getMonth() === date.getMonth() &&
        eventDate.getFullYear() === date.getFullYear()
      );
    });
  };

  const getEventsForDate = (day: number) => {
    const date = new Date(currentYear, currentMonth, day);
    return filteredEvents.filter(event => {
      const eventDate = new Date(event.date);
      return (
        eventDate.getDate() === date.getDate() &&
        eventDate.getMonth() === date.getMonth() &&
        eventDate.getFullYear() === date.getFullYear()
      );
    });
  };

  const navigateMonth = (direction: 'prev' | 'next') => {
    setCurrentDate(prev => {
      const newDate = new Date(prev);
      if (direction === 'prev') {
        newDate.setMonth(prev.getMonth() - 1);
      } else {
        newDate.setMonth(prev.getMonth() + 1);
      }
      return newDate;
    });
    setSelectedDate(null);
  };

  const handleDateSelect = (day: number) => {
    const date = new Date(currentYear, currentMonth, day);
    setSelectedDate(date);
    setIsAddModalVisible(true);
    setNewTitle('');
    setNewLocation('');
    setNewStartTime('');
    setNewEndTime('');
    setNewUserId(CURRENT_USER_ID);
  };

  const handleAddEvent = () => {
    if (!selectedDate || !newTitle.trim() || !newLocation.trim() || !newStartTime.trim() || !newEndTime.trim()) {
      Alert.alert('Error', 'Please fill in all fields');
      return;
    }

    const userId = calendarView === 'personal' ? CURRENT_USER_ID : newUserId;
    const selectedUser = MOCK_USERS.find(u => u.id === userId);
    const newEvent: CalendarEvent = {
      id: Date.now().toString(),
      title: newTitle.trim(),
      location: newLocation.trim(),
      startTime: newStartTime.trim(),
      endTime: newEndTime.trim(),
      userId: userId,
      userName: selectedUser?.name || 'You',
      date: new Date(selectedDate),
    };

    setEvents([...events, newEvent].sort((a, b) => 
      new Date(a.date).getTime() - new Date(b.date).getTime()
    ));
    setIsAddModalVisible(false);
    Alert.alert('Success', 'Event added successfully!');
  };

  const formatTime = (time: string) => {
    return time;
  };

  const renderCalendar = () => {
    const daysInMonth = getDaysInMonth(currentDate);
    const firstDay = getFirstDayOfMonth(currentDate);
    const days = [];

    for (let i = 0; i < firstDay; i++) {
      days.push(<View key={`empty-${i}`} style={styles.calendarDay} />);
    }

    for (let day = 1; day <= daysInMonth; day++) {
      const dayHasEvents = hasEvents(day);
      const dayIsToday = isToday(day);
      const dayIsSelected = isSelected(day);

      days.push(
        <TouchableOpacity
          key={day}
          style={[
            styles.calendarDay,
            dayIsToday && styles.todayDay,
            dayIsSelected && styles.selectedDay,
          ]}
          onPress={() => handleDateSelect(day)}
        >
          <Text
            style={[
              styles.dayText,
              dayIsToday && styles.todayText,
              dayIsSelected && styles.selectedText,
            ]}
          >
            {day}
          </Text>
          {dayHasEvents && <View style={styles.eventDot} />}
        </TouchableOpacity>
      );
    }

    return days;
  };

  const selectedDateEvents = selectedDate ? getEventsForDate(selectedDate.getDate()) : [];

  return (
    <View style={styles.container}>
      <IslandHeader />
      <Stack.Screen
        options={{
          headerShown: false,
        }}
      />
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.header}>
          <TouchableOpacity
            style={styles.backButton}
            onPress={() => router.back()}
          >
            <Ionicons name="arrow-back" size={24} color={Palette.green900} />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Staff Calendar</Text>
          <View style={styles.placeholder} />
        </View>

        <ScrollView style={styles.scrollView} contentContainerStyle={styles.scrollContent}>
          {/* Calendar View Toggle */}
          <View style={styles.viewToggleContainer}>
            <TouchableOpacity
              style={[
                styles.viewToggleButton,
                calendarView === 'shared' && styles.viewToggleButtonActive,
              ]}
              onPress={() => setCalendarView('shared')}
            >
              <Ionicons 
                name="people" 
                size={18} 
                color={calendarView === 'shared' ? Palette.white : Palette.green900} 
              />
              <Text
                style={[
                  styles.viewToggleText,
                  calendarView === 'shared' && styles.viewToggleTextActive,
                ]}
              >
                Shared
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.viewToggleButton,
                calendarView === 'personal' && styles.viewToggleButtonActive,
              ]}
              onPress={() => setCalendarView('personal')}
            >
              <Ionicons 
                name="person" 
                size={18} 
                color={calendarView === 'personal' ? Palette.white : Palette.green900} 
              />
              <Text
                style={[
                  styles.viewToggleText,
                  calendarView === 'personal' && styles.viewToggleTextActive,
                ]}
              >
                Personal
              </Text>
            </TouchableOpacity>
          </View>

          {/* Month Navigation */}
          <View style={styles.monthNavigation}>
            <TouchableOpacity
              style={styles.navButton}
              onPress={() => navigateMonth('prev')}
            >
              <Ionicons name="chevron-back" size={24} color={Palette.green900} />
            </TouchableOpacity>
            <Text style={styles.monthYear}>
              {MONTHS[currentMonth]} {currentYear}
            </Text>
            <TouchableOpacity
              style={styles.navButton}
              onPress={() => navigateMonth('next')}
            >
              <Ionicons name="chevron-forward" size={24} color={Palette.green900} />
            </TouchableOpacity>
          </View>

          {/* Calendar Grid */}
          <View style={styles.calendarContainer}>
            {/* Day Headers */}
            <View style={styles.dayHeaders}>
              {DAYS_OF_WEEK.map(day => (
                <View key={day} style={styles.dayHeader}>
                  <Text style={styles.dayHeaderText}>{day}</Text>
                </View>
              ))}
            </View>

            {/* Calendar Days */}
            <View style={styles.calendarGrid}>
              {renderCalendar()}
            </View>
          </View>

          {/* Selected Date Events */}
          {selectedDate && (
            <View style={styles.eventsSection}>
              <Text style={styles.eventsSectionTitle}>
                {MONTHS[selectedDate.getMonth()]} {selectedDate.getDate()}, {selectedDate.getFullYear()}
              </Text>
              {selectedDateEvents.length === 0 ? (
                <View style={styles.emptyEvents}>
                  <Text style={styles.emptyEventsText}>No events scheduled</Text>
                  <Text style={styles.emptyEventsSubtext}>Tap a date to add an event</Text>
                </View>
              ) : (
                selectedDateEvents.map(event => (
                  <View key={event.id} style={styles.eventCard}>
                    <View style={styles.eventHeader}>
                      <Text style={styles.eventTitle}>{event.title}</Text>
                      <Text style={styles.eventUser}>{event.userName}</Text>
                    </View>
                    <View style={styles.eventDetails}>
                      <View style={styles.eventDetailRow}>
                        <Ionicons name="location" size={16} color={Palette.green900} />
                        <Text style={styles.eventDetailText}>{event.location}</Text>
                      </View>
                      <View style={styles.eventDetailRow}>
                        <Ionicons name="time" size={16} color={Palette.green900} />
                        <Text style={styles.eventDetailText}>
                          {event.startTime} - {event.endTime}
                        </Text>
                      </View>
                    </View>
                  </View>
                ))
              )}
            </View>
          )}

          {!selectedDate && (
            <View style={styles.instructionBox}>
              <Ionicons name="calendar-outline" size={32} color={Palette.green900} />
              <Text style={styles.instructionText}>Tap a date to view or add events</Text>
            </View>
          )}
        </ScrollView>
      </SafeAreaView>
      <CircleFooter activeRoute="user" />

      {/* Add Event Modal */}
      <Modal
        visible={isAddModalVisible}
        animationType="slide"
        transparent={true}
        onRequestClose={() => setIsAddModalVisible(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>
                {selectedDate
                  ? `Add Event - ${MONTHS[selectedDate.getMonth()]} ${selectedDate.getDate()}`
                  : 'Add Event'}
              </Text>
              <TouchableOpacity
                onPress={() => setIsAddModalVisible(false)}
                style={styles.modalCloseButton}
              >
                <Ionicons name="close" size={24} color={Palette.green900} />
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.modalScroll}>
              <View style={styles.inputGroup}>
                <Text style={styles.label}>Title</Text>
                <TextInput
                  style={styles.input}
                  placeholder="Event title"
                  placeholderTextColor={Palette.gray900}
                  value={newTitle}
                  onChangeText={setNewTitle}
                  maxLength={100}
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.label}>Location</Text>
                <TextInput
                  style={styles.input}
                  placeholder="e.g., Desert Dome, Tropical Dome"
                  placeholderTextColor={Palette.gray900}
                  value={newLocation}
                  onChangeText={setNewLocation}
                  maxLength={100}
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.label}>Start Time (HH:MM)</Text>
                <TextInput
                  style={styles.input}
                  placeholder="09:00"
                  placeholderTextColor={Palette.gray900}
                  value={newStartTime}
                  onChangeText={setNewStartTime}
                  keyboardType="numeric"
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.label}>End Time (HH:MM)</Text>
                <TextInput
                  style={styles.input}
                  placeholder="17:00"
                  placeholderTextColor={Palette.gray900}
                  value={newEndTime}
                  onChangeText={setNewEndTime}
                  keyboardType="numeric"
                />
              </View>

              {calendarView === 'shared' ? (
                <View style={styles.inputGroup}>
                  <Text style={styles.label}>Staff Member</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.userSelector}>
                    {MOCK_USERS.map(user => (
                      <TouchableOpacity
                        key={user.id}
                        style={[
                          styles.userChip,
                          newUserId === user.id && styles.userChipActive,
                        ]}
                        onPress={() => setNewUserId(user.id)}
                      >
                        <Text
                          style={[
                            styles.userChipText,
                            newUserId === user.id && styles.userChipTextActive,
                          ]}
                        >
                          {user.name}
                        </Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                </View>
              ) : (
                <View style={styles.inputGroup}>
                  <Text style={styles.label}>Staff Member</Text>
                  <View style={styles.readOnlyUserChip}>
                    <Text style={styles.readOnlyUserChipText}>
                      {MOCK_USERS.find(u => u.id === CURRENT_USER_ID)?.name || 'You'}
                    </Text>
                    <Ionicons name="lock-closed" size={16} color={Palette.gray900} />
                  </View>
                  <Text style={styles.readOnlyHint}>
                    Personal calendar events are automatically assigned to you
                  </Text>
                </View>
              )}
            </ScrollView>

            <View style={styles.modalActions}>
              <TouchableOpacity
                style={styles.cancelButton}
                onPress={() => {
                  setIsAddModalVisible(false);
                  setSelectedDate(null);
                }}
              >
                <Text style={styles.cancelButtonText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.submitButton}
                onPress={handleAddEvent}
              >
                <Text style={styles.submitButtonText}>Add Event</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
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
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: Palette.gray900,
  },
  backButton: {
    padding: 4,
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: Palette.green900,
    flex: 1,
    textAlign: 'center',
  },
  placeholder: {
    width: 36,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 100,
  },
  viewToggleContainer: {
    flexDirection: 'row',
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    padding: 4,
    marginBottom: 20,
    borderWidth: 1,
    borderColor: Palette.gray900,
  },
  viewToggleButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 8,
    gap: 8,
  },
  viewToggleButtonActive: {
    backgroundColor: Palette.green900,
  },
  viewToggleText: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
  },
  viewToggleTextActive: {
    color: Palette.white,
  },
  monthNavigation: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 20,
    paddingHorizontal: 8,
  },
  navButton: {
    padding: 8,
  },
  monthYear: {
    fontSize: 20,
    fontWeight: 'bold',
    color: Palette.green900,
  },
  calendarContainer: {
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    padding: 12,
    marginBottom: 24,
    borderWidth: 1,
    borderColor: Palette.gray900,
  },
  dayHeaders: {
    flexDirection: 'row',
    marginBottom: 8,
  },
  dayHeader: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 8,
  },
  dayHeaderText: {
    fontSize: 12,
    fontWeight: '600',
    color: Palette.green900,
  },
  calendarGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  calendarDay: {
    width: '14.28%',
    aspectRatio: 1,
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
  },
  dayText: {
    fontSize: 14,
    color: Palette.green900,
  },
  todayDay: {
    backgroundColor: Palette.green900,
    borderRadius: 8,
  },
  todayText: {
    color: Palette.white,
    fontWeight: 'bold',
  },
  selectedDay: {
    backgroundColor: Palette.gray900,
    borderRadius: 8,
  },
  selectedText: {
    fontWeight: 'bold',
  },
  eventDot: {
    position: 'absolute',
    bottom: 4,
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: Palette.green900,
  },
  eventsSection: {
    marginTop: 8,
  },
  eventsSectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: Palette.green900,
    marginBottom: 12,
  },
  emptyEvents: {
    alignItems: 'center',
    paddingVertical: 32,
  },
  emptyEventsText: {
    fontSize: 16,
    color: Palette.gray900,
    marginBottom: 4,
  },
  emptyEventsSubtext: {
    fontSize: 14,
    color: Palette.gray900,
  },
  eventCard: {
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: Palette.gray900,
  },
  eventHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  eventTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: Palette.green900,
    flex: 1,
  },
  eventUser: {
    fontSize: 14,
    color: Palette.gray900,
    fontWeight: '500',
  },
  eventDetails: {
    gap: 8,
  },
  eventDetailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  eventDetailText: {
    fontSize: 14,
    color: Palette.green900,
  },
  instructionBox: {
    alignItems: 'center',
    paddingVertical: 32,
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    marginTop: 16,
  },
  instructionText: {
    fontSize: 16,
    color: Palette.green900,
    marginTop: 12,
    textAlign: 'center',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: Palette.white,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: '90%',
    paddingBottom: 20,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: Palette.gray900,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: Palette.green900,
    flex: 1,
  },
  modalCloseButton: {
    padding: 4,
  },
  modalScroll: {
    maxHeight: 400,
  },
  inputGroup: {
    padding: 20,
    paddingBottom: 0,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 8,
  },
  input: {
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    color: Palette.green900,
    borderWidth: 1,
    borderColor: Palette.gray900,
  },
  userSelector: {
    marginTop: 8,
  },
  userChip: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: Palette.gray100,
    marginRight: 8,
    borderWidth: 1,
    borderColor: Palette.gray900,
  },
  userChipActive: {
    backgroundColor: Palette.green900,
    borderColor: Palette.green900,
  },
  userChipText: {
    fontSize: 14,
    color: Palette.green900,
    fontWeight: '500',
  },
  userChipTextActive: {
    color: Palette.white,
  },
  readOnlyUserChip: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderWidth: 1,
    borderColor: Palette.gray900,
    gap: 8,
  },
  readOnlyUserChipText: {
    fontSize: 16,
    color: Palette.green900,
    fontWeight: '500',
  },
  readOnlyHint: {
    fontSize: 12,
    color: Palette.gray900,
    marginTop: 8,
    fontStyle: 'italic',
  },
  modalActions: {
    flexDirection: 'row',
    padding: 20,
    gap: 12,
  },
  cancelButton: {
    flex: 1,
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  cancelButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
  },
  submitButton: {
    flex: 1,
    backgroundColor: Palette.green900,
    borderRadius: 12,
    paddingVertical: 14,
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
  submitButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.white,
  },
});

