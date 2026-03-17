import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  TouchableOpacity,
  ScrollView,
  TextInput,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { API_BASE_URL } from '@/constants/config';

interface FeedbackFormProps {
  visible: boolean;
  onClose: () => void;
}

interface FeedbackData {
  visit_rating: number | null;
  tropics_dome_rating: number | null;
  desert_dome_rating: number | null;
  show_dome_rating: number | null;
  staff_rating: number | null;
  cleanliness_rating: number | null;
  additional_comments: string;
}

export const FeedbackForm = ({ visible, onClose }: FeedbackFormProps) => {
  const [feedbackData, setFeedbackData] = useState<FeedbackData>({
    visit_rating: null,
    tropics_dome_rating: null,
    desert_dome_rating: null,
    show_dome_rating: null,
    staff_rating: null,
    cleanliness_rating: null,
    additional_comments: '',
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleRatingChange = (field: keyof FeedbackData, rating: number) => {
    setFeedbackData((prev) => ({
      ...prev,
      [field]: rating,
    }));
  };

  const handleCommentsChange = (text: string) => {
    setFeedbackData((prev) => ({
      ...prev,
      additional_comments: text,
    }));
  };

  const resetForm = () => {
    setFeedbackData({
      visit_rating: null,
      tropics_dome_rating: null,
      desert_dome_rating: null,
      show_dome_rating: null,
      staff_rating: null,
      cleanliness_rating: null,
      additional_comments: '',
    });
  };

  const handleClose = () => {
    resetForm();
    onClose();
  };

  const handleSubmit = async () => {
    if (!feedbackData.visit_rating) {
      Alert.alert('Required', 'Please rate your visit');
      return;
    }

    setIsSubmitting(true);
    try {
      const response = await fetch(`${API_BASE_URL}/feedback`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(feedbackData),
      });

      if (!response.ok) {
        throw new Error('Failed to submit feedback');
      }

      // Auto-close the form after successful submission
      handleClose();
    } catch (error) {
      console.error('Error submitting feedback:', error);
      Alert.alert('Error', 'Failed to submit feedback. Please try again later.');
      setIsSubmitting(false);
    }
  };

  const RatingSection = ({
    title,
    field,
    value,
  }: {
    title: string;
    field: keyof FeedbackData;
    value: number | null;
  }) => (
    <View style={styles.ratingSection}>
      <Text style={styles.ratingTitle}>{title}</Text>
      <View style={styles.ratingContainer}>
        {[1, 2, 3, 4, 5].map((rating) => (
          <TouchableOpacity
            key={rating}
            style={[
              styles.ratingButton,
              value === rating && styles.ratingButtonActive,
            ]}
            onPress={() => handleRatingChange(field, rating)}
          >
            <Ionicons
              name={value && value >= rating ? 'star' : 'star-outline'}
              size={32}
              color={value && value >= rating ? '#FFD700' : Palette.gray900}
            />
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );

  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent={true}
      onRequestClose={handleClose}
    >
      <TouchableOpacity
        style={styles.modalOverlay}
        activeOpacity={1}
        onPress={handleClose}
      >
        <TouchableOpacity
          style={styles.modalContent}
          activeOpacity={1}
          onPress={(e) => e.stopPropagation()}
        >
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>Feedback Survey</Text>
            <TouchableOpacity onPress={handleClose} style={styles.modalCloseButton}>
              <Ionicons name="close" size={24} color={Palette.green900} />
            </TouchableOpacity>
          </View>

          <ScrollView 
            style={styles.modalBody} 
            showsVerticalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
            contentContainerStyle={styles.scrollContent}
          >
            <Text style={styles.description}>
              We value your feedback! Please take a moment to rate your experience.
            </Text>

            <RatingSection
              title="Rate your visit *"
              field="visit_rating"
              value={feedbackData.visit_rating}
            />

            <RatingSection
              title="Rate the Tropics Dome"
              field="tropics_dome_rating"
              value={feedbackData.tropics_dome_rating}
            />

            <RatingSection
              title="Rate the Desert Dome"
              field="desert_dome_rating"
              value={feedbackData.desert_dome_rating}
            />

            <RatingSection
              title="Rate the Show Dome"
              field="show_dome_rating"
              value={feedbackData.show_dome_rating}
            />

            <RatingSection
              title="Rate staff friendliness"
              field="staff_rating"
              value={feedbackData.staff_rating}
            />

            <RatingSection
              title="Rate cleanliness"
              field="cleanliness_rating"
              value={feedbackData.cleanliness_rating}
            />

            <View style={styles.commentsSection}>
              <Text style={styles.commentsTitle}>Additional Comments</Text>
              <TextInput
                style={styles.commentsInput}
                placeholder="Share any additional thoughts or suggestions..."
                placeholderTextColor={Palette.gray900}
                value={feedbackData.additional_comments}
                onChangeText={handleCommentsChange}
                multiline
                numberOfLines={4}
                textAlignVertical="top"
              />
            </View>

            {/* Blank spacers to allow scrolling above keyboard */}
            <View style={styles.spacer} />
          </ScrollView>

          <View style={styles.modalFooter}>
            <TouchableOpacity
              style={[styles.modalButton, styles.modalButtonCancel]}
              onPress={handleClose}
              disabled={isSubmitting}
            >
              <Text style={styles.modalButtonCancelText}>Cancel</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.modalButton, styles.modalButtonPrimary]}
              onPress={handleSubmit}
              disabled={isSubmitting}
            >
              {isSubmitting ? (
                <ActivityIndicator color={Palette.white} />
              ) : (
                <Text style={styles.modalButtonText}>Submit</Text>
              )}
            </TouchableOpacity>
          </View>
        </TouchableOpacity>
      </TouchableOpacity>
    </Modal>
  );
};

const styles = StyleSheet.create({
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
    borderBottomColor: Palette.gray100,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: Palette.green900,
  },
  modalCloseButton: {
    padding: 4,
  },
  modalBody: {
    padding: 20,
    maxHeight: 500,
  },
  scrollContent: {
    paddingBottom: 300,
  },
  description: {
    fontSize: 14,
    color: Palette.gray900,
    marginBottom: 24,
    lineHeight: 20,
  },
  ratingSection: {
    marginBottom: 24,
  },
  ratingTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 12,
  },
  ratingContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 8,
  },
  ratingButton: {
    padding: 4,
  },
  ratingButtonActive: {
    // Additional styling if needed
  },
  commentsSection: {
    marginBottom: 20,
  },
  commentsTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 12,
  },
  commentsInput: {
    borderWidth: 1,
    borderColor: Palette.gray900,
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    color: Palette.black,
    backgroundColor: Palette.white,
    minHeight: 100,
  },
  modalFooter: {
    flexDirection: 'row',
    gap: 12,
    padding: 20,
    borderTopWidth: 1,
    borderTopColor: Palette.gray100,
  },
  modalButton: {
    flex: 1,
    paddingVertical: 14,
    paddingHorizontal: 20,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  modalButtonCancel: {
    backgroundColor: Palette.gray900,
  },
  modalButtonCancelText: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.black,
  },
  modalButtonPrimary: {
    backgroundColor: Palette.green900,
  },
  modalButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.white,
  },
  spacer: {
    height: 50,
  },
});

