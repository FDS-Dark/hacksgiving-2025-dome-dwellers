import { useState, useEffect, useCallback, useRef } from 'react';
import i18n, { changeLanguage as changeI18nLanguage } from '@/i18n';

// Create a simple event emitter for language changes
let languageChangeListeners: Set<() => void> = new Set();

const notifyLanguageChange = () => {
  languageChangeListeners.forEach(listener => listener());
};

/**
 * Custom hook for using translations in components
 * Automatically re-renders components when language changes
 */
export const useTranslation = () => {
  const [locale, setLocale] = useState(i18n.locale);
  const [updateKey, setUpdateKey] = useState(0); // Force re-render key

  useEffect(() => {
    // Update locale when language changes
    const handleLanguageChange = () => {
      setLocale(i18n.locale);
      setUpdateKey(prev => prev + 1); // Force re-render
    };

    // Add listener
    languageChangeListeners.add(handleLanguageChange);

    // Cleanup
    return () => {
      languageChangeListeners.delete(handleLanguageChange);
    };
  }, []);

  /**
   * Translate a key with optional interpolation
   * @param key - Translation key (e.g., 'tickets.title')
   * @param options - Interpolation options (e.g., { count: 5 })
   */
  const t = useCallback((key: string, options?: any) => {
    return i18n.t(key, options);
  }, [locale, updateKey]); // Re-create when locale or updateKey changes

  /**
   * Change the app language
   * @param newLocale - Language code (e.g., 'en', 'es', 'fr', 'de')
   */
  const changeLanguage = useCallback((newLocale: string) => {
    changeI18nLanguage(newLocale);
    setLocale(newLocale);
    setUpdateKey(prev => prev + 1); // Force re-render
    notifyLanguageChange(); // Notify all listeners
  }, []);

  return {
    t,
    locale,
    changeLanguage,
  };
};

