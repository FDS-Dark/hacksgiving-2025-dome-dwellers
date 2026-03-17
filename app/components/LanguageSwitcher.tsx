import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Modal } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTranslation } from '@/hooks/useTranslation';
import { getAvailableLanguages } from '@/i18n';

/**
 * Optional Language Switcher Component
 * 
 * Use this component if you want to allow users to manually override
 * the automatic language detection.
 * 
 * Usage:
 * import { LanguageSwitcher } from '@/components/LanguageSwitcher';
 * 
 * <LanguageSwitcher />
 */
export const LanguageSwitcher = () => {
  const { locale, changeLanguage } = useTranslation();
  const [modalVisible, setModalVisible] = useState(false);
  const languages = getAvailableLanguages();

  const handleLanguageChange = (code: string) => {
    changeLanguage(code);
    setModalVisible(false);
  };

  const getCurrentLanguageName = () => {
    return languages.find(lang => lang.code === locale)?.name || 'English';
  };

  const getLanguageFlag = (code: string) => {
    const flags: Record<string, string> = {
      en: '🇺🇸',
      es: '🇪🇸',
      fr: '🇫🇷',
      de: '🇩🇪',
      zh: '🇨🇳',
      ru: '🇷🇺',
      uk: '🇺🇦',
      hmn: '🏳️',
      pl: '🇵🇱',
    };
    return flags[code] || '🌐';
  };

  return (
    <>
      <TouchableOpacity
        style={styles.button}
        onPress={() => setModalVisible(true)}>
        <Text style={styles.flag}>{getLanguageFlag(locale)}</Text>
        <Text style={styles.buttonText}>{getCurrentLanguageName()}</Text>
        <Ionicons name="chevron-down" size={20} color="#666" />
      </TouchableOpacity>

      <Modal
        visible={modalVisible}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setModalVisible(false)}>
        <TouchableOpacity
          style={styles.modalOverlay}
          activeOpacity={1}
          onPress={() => setModalVisible(false)}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Select Language</Text>
              <TouchableOpacity onPress={() => setModalVisible(false)}>
                <Ionicons name="close" size={24} color="#333" />
              </TouchableOpacity>
            </View>

            {languages.map((language) => (
              <TouchableOpacity
                key={language.code}
                style={[
                  styles.languageOption,
                  locale === language.code && styles.languageOptionSelected,
                ]}
                onPress={() => handleLanguageChange(language.code)}>
                <Text style={styles.languageFlag}>
                  {getLanguageFlag(language.code)}
                </Text>
                <Text
                  style={[
                    styles.languageName,
                    locale === language.code && styles.languageNameSelected,
                  ]}>
                  {language.name}
                </Text>
                {locale === language.code && (
                  <Ionicons name="checkmark" size={24} color="#2E7D32" />
                )}
              </TouchableOpacity>
            ))}
          </View>
        </TouchableOpacity>
      </Modal>
    </>
  );
};

const styles = StyleSheet.create({
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#e0e0e0',
    backgroundColor: 'white',
    gap: 8,
  },
  flag: {
    fontSize: 24,
  },
  buttonText: {
    flex: 1,
    fontSize: 16,
    color: '#333',
    fontWeight: '500',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  modalContent: {
    backgroundColor: 'white',
    borderRadius: 16,
    width: '100%',
    maxWidth: 400,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
  },
  languageOption: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
    gap: 12,
  },
  languageOptionSelected: {
    backgroundColor: '#f0f9f1',
  },
  languageFlag: {
    fontSize: 28,
  },
  languageName: {
    flex: 1,
    fontSize: 16,
    color: '#333',
    fontWeight: '500',
  },
  languageNameSelected: {
    color: '#2E7D32',
    fontWeight: 'bold',
  },
});

