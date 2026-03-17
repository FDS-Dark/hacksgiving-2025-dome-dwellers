import React, { useState } from 'react';
import {
  Modal,
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useAuth0 } from './Auth0Provider';
import { useTranslation } from '@/hooks/useTranslation';
import { Event } from '@/types/dome';
import { useRegisterForEvent } from '@/hooks/use-events';


interface EventRegistrationModalProps {
  visible: boolean;
  event: Event | null;
  onClose: () => void;
  onSuccess: () => void;
}

export function EventRegistrationModal({
  visible,
  event,
  onClose,
  onSuccess,
}: EventRegistrationModalProps) {
  const { t } = useTranslation();
  const { isAuthenticated, user, login } = useAuth0();
  const registerMutation = useRegisterForEvent();
  const [formData, setFormData] = useState({
    attendee_name: '',
    attendee_email: '',
    attendee_phone: '',
    notes: '',
  });

  // Pre-fill form with user data if authenticated
  React.useEffect(() => {
    if (isAuthenticated && user) {
      setFormData(prev => ({
        ...prev,
        attendee_name: user.name || prev.attendee_name,
        attendee_email: user.email || prev.attendee_email,
      }));
    }
  }, [isAuthenticated, user]);

  const handleRegister = async () => {
    // Validate required fields
    if (!formData.attendee_name.trim()) {
      Alert.alert(t('eventRegistration.error.title'), t('eventRegistration.error.nameRequired'));
      return;
    }

    if (!event) return;

    try {
      await registerMutation.mutateAsync({
        eventId: event.id,
        registrationData: {
          attendee_name: formData.attendee_name,
          attendee_email: formData.attendee_email || undefined,
          attendee_phone: formData.attendee_phone || undefined,
          notes: formData.notes || undefined,
        },
      });

      Alert.alert(
        t('eventRegistration.success.title'),
        t('eventRegistration.success.message'),
        [
          {
            text: t('common.success'),
            onPress: () => {
              onSuccess();
              onClose();
              // Reset form
              setFormData({
                attendee_name: '',
                attendee_email: '',
                attendee_phone: '',
                notes: '',
              });
            },
          },
        ]
      );
    } catch (error) {
      console.error('Registration error:', error);
      Alert.alert(
        t('eventRegistration.error.registrationFailed'),
        error instanceof Error ? error.message : t('eventRegistration.error.tryAgain')
      );
    }
  };

  const handleLoginAndRegister = async () => {
    try {
      await login();
      // After login, the form will be pre-filled via useEffect
    } catch (err) {
      console.error('Login error:', err);
      Alert.alert(t('eventRegistration.error.loginFailed'), t('eventRegistration.error.tryAgain'));
    }
  };

  if (!event) return null;

  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent={true}
      onRequestClose={onClose}
    >
      <View style={styles.modalOverlay}>
        <View style={styles.modalContent}>
          {/* Header */}
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>{t('eventRegistration.title')}</Text>
            <TouchableOpacity onPress={onClose} style={styles.closeButton}>
              <Ionicons name="close" size={28} color={Palette.green900} />
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.modalBody} showsVerticalScrollIndicator={false}>
            {/* Event Details */}
            <View style={styles.eventDetailsCard}>
              <Text style={styles.eventTitle}>{event.title}</Text>
              {event.location && (
                <View style={styles.eventDetailRow}>
                  <Ionicons name="location-outline" size={16} color={Palette.green900} />
                  <Text style={styles.eventDetailText}>{event.location}</Text>
                </View>
              )}
              <View style={styles.eventDetailRow}>
                <Ionicons name="time-outline" size={16} color={Palette.green900} />
                <Text style={styles.eventDetailText}>
                  {new Date(event.start_time).toLocaleString()}
                </Text>
              </View>
              {event.capacity && (
                <View style={styles.eventDetailRow}>
                  <Ionicons name="people-outline" size={16} color={Palette.green900} />
                  <Text style={styles.eventDetailText}>
                    {t('events.capacity', { count: event.capacity })}
                  </Text>
                </View>
              )}
            </View>

            {/* Auth Prompt for Non-Logged-In Users */}
            {!isAuthenticated && (
              <View style={styles.authPrompt}>
                <Ionicons name="information-circle-outline" size={24} color={Palette.green900} />
                <Text style={styles.authPromptText}>
                  {t('eventRegistration.signInPrompt')}
                </Text>
                <TouchableOpacity style={styles.loginButton} onPress={handleLoginAndRegister}>
                  <Text style={styles.loginButtonText}>{t('eventRegistration.signIn')}</Text>
                </TouchableOpacity>
                <Text style={styles.orText}>{t('eventRegistration.continueAsGuest')}</Text>
              </View>
            )}

            {/* Registration Form */}
            <View style={styles.formSection}>
              <Text style={styles.sectionTitle}>{t('eventRegistration.yourInformation')}</Text>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>
                  {t('eventRegistration.name')} <Text style={styles.required}>*</Text>
                </Text>
                <TextInput
                  style={styles.input}
                  value={formData.attendee_name}
                  onChangeText={(text) => setFormData({ ...formData, attendee_name: text })}
                  placeholder={t('eventRegistration.namePlaceholder')}
                  placeholderTextColor={Palette.gray900}
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>{t('eventRegistration.email')}</Text>
                <TextInput
                  style={styles.input}
                  value={formData.attendee_email}
                  onChangeText={(text) => setFormData({ ...formData, attendee_email: text })}
                  placeholder={t('eventRegistration.emailPlaceholder')}
                  placeholderTextColor={Palette.gray900}
                  keyboardType="email-address"
                  autoCapitalize="none"
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>{t('eventRegistration.phone')}</Text>
                <TextInput
                  style={styles.input}
                  value={formData.attendee_phone}
                  onChangeText={(text) => setFormData({ ...formData, attendee_phone: text })}
                  placeholder={t('eventRegistration.phonePlaceholder')}
                  placeholderTextColor={Palette.gray900}
                  keyboardType="phone-pad"
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>{t('eventRegistration.notes')}</Text>
                <TextInput
                  style={[styles.input, styles.textArea]}
                  value={formData.notes}
                  onChangeText={(text) => setFormData({ ...formData, notes: text })}
                  placeholder={t('eventRegistration.notesPlaceholder')}
                  placeholderTextColor={Palette.gray900}
                  multiline
                  numberOfLines={4}
                  textAlignVertical="top"
                />
              </View>
            </View>

            {/* Register Button */}
            <TouchableOpacity
              style={[styles.registerButton, registerMutation.isPending && styles.buttonDisabled]}
              onPress={handleRegister}
              disabled={registerMutation.isPending}
            >
              {registerMutation.isPending ? (
                <ActivityIndicator color="white" />
              ) : (
                <Text style={styles.registerButtonText}>
                  {t('eventRegistration.completeRegistration')}
                </Text>
              )}
            </TouchableOpacity>

            <Text style={styles.disclaimer}>
              {t('eventRegistration.disclaimer')}
            </Text>

            <TouchableOpacity style={styles.cancelButton} onPress={onClose}>
              <Text style={styles.cancelButtonText}>{t('common.cancel')}</Text>
            </TouchableOpacity>
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: Palette.white,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    maxHeight: '90%',
    paddingTop: 8,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: Palette.gray100,
  },
  modalTitle: {
    fontSize: 24,
    fontWeight: '700',
    color: Palette.green900,
  },
  closeButton: {
    padding: 4,
  },
  modalBody: {
    padding: 20,
  },
  eventDetailsCard: {
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    padding: 16,
    marginBottom: 24,
    borderWidth: 1,
    borderColor: Palette.gray900,
  },
  eventTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 12,
  },
  eventDetailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
  },
  eventDetailText: {
    marginLeft: 8,
    fontSize: 14,
    color: Palette.green900,
  },
  formSection: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 16,
  },
  inputGroup: {
    marginBottom: 20,
  },
  inputLabel: {
    fontSize: 14,
    fontWeight: '500',
    color: Palette.green900,
    marginBottom: 8,
  },
  required: {
    color: '#e53935',
  },
  input: {
    backgroundColor: 'white',
    borderWidth: 1,
    borderColor: Palette.gray900,
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    color: Palette.green900,
  },
  textArea: {
    height: 100,
    paddingTop: 12,
  },
  registerButton: {
    backgroundColor: Palette.green900,
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    marginBottom: 12,
  },
  registerButtonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
  buttonDisabled: {
    backgroundColor: Palette.gray900,
    opacity: 0.6,
  },
  authPrompt: {
    padding: 20,
    backgroundColor: Palette.gray100,
    alignItems: 'center',
    marginBottom: 24,
    borderRadius: 12,
  },
  authPromptText: {
    fontSize: 14,
    color: Palette.green900,
    textAlign: 'center',
    marginBottom: 12,
  },
  loginButton: {
    paddingVertical: 10,
    paddingHorizontal: 24,
    backgroundColor: Palette.green900,
    borderRadius: 20,
    marginBottom: 8,
  },
  loginButtonText: {
    color: 'white',
    fontSize: 14,
    fontWeight: '600',
  },
  orText: {
    fontSize: 12,
    color: Palette.gray900,
  },
  disclaimer: {
    fontSize: 12,
    color: Palette.gray900,
    textAlign: 'center',
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  cancelButton: {
    padding: 16,
    alignItems: 'center',
    marginBottom: 20,
  },
  cancelButtonText: {
    color: Palette.green900,
    fontSize: 16,
    fontWeight: '500',
  },
});
