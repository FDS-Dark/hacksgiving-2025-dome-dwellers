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
  ActivityIndicator,
} from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useAnnouncements } from '@/hooks/use-announcements';
import { useUser } from '@/hooks/use-user';

export default function AnnouncementsScreen() {
  const router = useRouter();
  const { user } = useUser();
  const { 
    announcements, 
    loading, 
    error, 
    createAnnouncement, 
    deleteAnnouncement 
  } = useAnnouncements();
  const [isAddModalVisible, setIsAddModalVisible] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newMessage, setNewMessage] = useState('');

  const handleAddAnnouncement = async () => {
    if (!newTitle.trim() || !newMessage.trim()) {
      Alert.alert('Error', 'Please fill in both title and message');
      return;
    }

    try {
      await createAnnouncement({
        title: newTitle.trim(),
        message: newMessage.trim(),
      });
      setNewTitle('');
      setNewMessage('');
      setIsAddModalVisible(false);
      Alert.alert('Success', 'Announcement added successfully!');
    } catch (err) {
      Alert.alert('Error', 'Failed to create announcement. Please try again.');
    }
  };

  const handleDeleteAnnouncement = (id: number, authorId: number) => {
    if (user?.id !== authorId) {
      Alert.alert('Error', 'You can only delete your own announcements');
      return;
    }

    Alert.alert(
      'Delete Announcement',
      'Are you sure you want to delete this announcement?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await deleteAnnouncement(id);
              Alert.alert('Success', 'Announcement deleted successfully!');
            } catch (err) {
              Alert.alert('Error', 'Failed to delete announcement. Please try again.');
            }
          },
        },
      ]
    );
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  return (
    <View style={styles.container}>
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
          <Text style={styles.headerTitle}>Announcements</Text>
          <TouchableOpacity
            style={styles.addButton}
            onPress={() => setIsAddModalVisible(true)}
          >
            <Ionicons name="add" size={24} color={Palette.white} />
          </TouchableOpacity>
        </View>

        <ScrollView style={styles.scrollView} contentContainerStyle={styles.scrollContent}>
          {loading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="large" color={Palette.green900} />
              <Text style={styles.loadingText}>Loading announcements...</Text>
            </View>
          ) : error ? (
            <View style={styles.errorContainer}>
              <Ionicons name="alert-circle-outline" size={64} color={Palette.red} />
              <Text style={styles.errorText}>Failed to load announcements</Text>
              <Text style={styles.errorSubtext}>{error}</Text>
            </View>
          ) : announcements.length === 0 ? (
            <View style={styles.emptyState}>
              <Ionicons name="megaphone-outline" size={64} color={Palette.gray900} />
              <Text style={styles.emptyStateText}>No announcements yet</Text>
              <Text style={styles.emptyStateSubtext}>
                Tap the + button to add the first announcement
              </Text>
            </View>
          ) : (
            announcements.map((announcement) => (
              <View key={announcement.id} style={styles.announcementCard}>
                <View style={styles.announcementHeader}>
                  <View style={styles.announcementHeaderLeft}>
                    <Text style={styles.announcementTitle}>{announcement.title}</Text>
                    <Text style={styles.announcementAuthor}>
                      by {announcement.author_name} • {formatDate(announcement.created_at)}
                    </Text>
                  </View>
                  {user?.id === announcement.author_id && (
                    <TouchableOpacity
                      onPress={() => handleDeleteAnnouncement(announcement.id, announcement.author_id)}
                      style={styles.deleteButton}
                    >
                      <Ionicons name="trash-outline" size={20} color={Palette.red} />
                    </TouchableOpacity>
                  )}
                </View>
                <Text style={styles.announcementMessage}>{announcement.message}</Text>
              </View>
            ))
          )}
        </ScrollView>
      </SafeAreaView>

      {/* Add Announcement Modal */}
      <Modal
        visible={isAddModalVisible}
        animationType="slide"
        transparent={true}
        onRequestClose={() => setIsAddModalVisible(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>New Announcement</Text>
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
                  placeholder="Enter announcement title"
                  placeholderTextColor={Palette.gray900}
                  value={newTitle}
                  onChangeText={setNewTitle}
                  maxLength={100}
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.label}>Message</Text>
                <TextInput
                  style={[styles.input, styles.textArea]}
                  placeholder="Enter announcement message"
                  placeholderTextColor={Palette.gray900}
                  value={newMessage}
                  onChangeText={setNewMessage}
                  multiline
                  numberOfLines={6}
                  textAlignVertical="top"
                />
              </View>
            </ScrollView>

            <View style={styles.modalActions}>
              <TouchableOpacity
                style={styles.cancelButton}
                onPress={() => {
                  setIsAddModalVisible(false);
                  setNewTitle('');
                  setNewMessage('');
                }}
              >
                <Text style={styles.cancelButtonText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.submitButton}
                onPress={handleAddAnnouncement}
              >
                <Text style={styles.submitButtonText}>Post Announcement</Text>
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
  addButton: {
    backgroundColor: Palette.green900,
    width: 36,
    height: 36,
    borderRadius: 18,
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
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 100,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 64,
  },
  emptyStateText: {
    fontSize: 18,
    fontWeight: '600',
    color: Palette.gray900,
    marginTop: 16,
  },
  emptyStateSubtext: {
    fontSize: 14,
    color: Palette.gray900,
    marginTop: 8,
    textAlign: 'center',
  },
  announcementCard: {
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: Palette.gray900,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  announcementHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  announcementHeaderLeft: {
    flex: 1,
  },
  announcementTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: Palette.green900,
    marginBottom: 4,
  },
  announcementAuthor: {
    fontSize: 12,
    color: Palette.gray900,
  },
  announcementMessage: {
    fontSize: 16,
    color: Palette.green900,
    lineHeight: 22,
  },
  deleteButton: {
    padding: 8,
  },
  loadingContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 64,
  },
  loadingText: {
    fontSize: 16,
    color: Palette.gray900,
    marginTop: 16,
  },
  errorContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 64,
  },
  errorText: {
    fontSize: 18,
    fontWeight: '600',
    color: Palette.red,
    marginTop: 16,
  },
  errorSubtext: {
    fontSize: 14,
    color: Palette.gray900,
    marginTop: 8,
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
  textArea: {
    minHeight: 120,
    paddingTop: 12,
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

