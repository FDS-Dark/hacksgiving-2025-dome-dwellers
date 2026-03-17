import { I18n } from 'i18n-js';
import { getLocales } from 'expo-localization';
import en from './locales/en';
import es from './locales/es';
import fr from './locales/fr';
import de from './locales/de';
import zh from './locales/zh';
import ru from './locales/ru';
import uk from './locales/uk';
import hmn from './locales/hmn';
import pl from './locales/pl';

// Create the i18n instance
const i18n = new I18n({
  en,
  es,
  fr,
  de,
  zh,
  ru,
  uk,
  hmn,
  pl,
});

// Set default language to English
i18n.defaultLocale = 'en';
i18n.enableFallback = true;

// Automatically detect and set the device's locale
const deviceLocale = getLocales()[0]?.languageCode || 'en';
i18n.locale = deviceLocale;

// Helper function to manually change language (optional)
export const changeLanguage = (locale: string) => {
  i18n.locale = locale;
  // Trigger a re-render by updating a timestamp or using events
  // Components using useTranslation will automatically update
};

// Helper function to get current language
export const getCurrentLanguage = () => {
  return i18n.locale;
};

// Helper function to get available languages
export const getAvailableLanguages = () => {
  return [
    { code: 'en', name: 'English' },
    { code: 'es', name: 'Español' },
    { code: 'fr', name: 'Français' },
    { code: 'de', name: 'Deutsch' },
    { code: 'zh', name: '中文' },
    { code: 'ru', name: 'Русский' },
    { code: 'uk', name: 'Українська' },
    { code: 'hmn', name: 'Hmoob' },
    { code: 'pl', name: 'Polski' },
  ];
};

export default i18n;

